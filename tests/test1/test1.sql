--Test indexed column in RLS with auth.uid()
--remove -- in front of create index for second run.

drop table if exists rlstest;
create table
    rlstest as
select x as id, 'name-' || x as name, uuid_generate_v4() as user_id, 'user' as role
from generate_series(1, 100000) x;

alter table rlstest ENABLE ROW LEVEL SECURITY;

create policy "rls_test_select" on rlstest
    to authenticated
    using (
    auth.uid() = user_id
    );

--create index userid on rlstest using btree (user_id) tablespace pg_default;

set session role authenticated;
set request.jwt.claims to '{"role":"authenticated", "sub":"5950b438-b07c-4012-8190-6ce79e4bd8e5"}';

explain analyze SELECT count(*) FROM rlstest;
set session role postgres;

/*
Run with index commented out:

Seq Scan on rlstest  (cost=0.00..4334.00 rows=1 width=35) (actual time=170.999..170.999 rows=0 loops=1)
"  Filter: ((COALESCE(NULLIF(current_setting('request.jwt.claim.sub'::text, true), ''::text), ((NULLIF(current_setting('request.jwt.claims'::text, true), ''::text))::jsonb ->> 'sub'::text)))::uuid = user_id)"
  Rows Removed by Filter: 100000
Planning Time: 0.216 ms
Execution Time: 171.033 ms

Run with index added in:

Bitmap Heap Scan on rlstest  (cost=6.52..421.36 rows=500 width=84) (actual time=0.024..0.024 rows=0 loops=1)
"  Filter: ((COALESCE(NULLIF(current_setting('request.jwt.claim.sub'::text, true), ''::text), ((NULLIF(current_setting('request.jwt.claims'::text, true), ''::text))::jsonb ->> 'sub'::text)))::uuid = user_id)"
  ->  Bitmap Index Scan on userid  (cost=0.00..6.39 rows=500 width=0) (actual time=0.022..0.022 rows=0 loops=1)
"        Index Cond: (user_id = (COALESCE(NULLIF(current_setting('request.jwt.claim.sub'::text, true), ''::text), ((NULLIF(current_setting('request.jwt.claims'::text, true), ''::text))::jsonb ->> 'sub'::text)))::uuid)"
Planning Time: 0.284 ms
Execution Time: 0.054 ms

*/

