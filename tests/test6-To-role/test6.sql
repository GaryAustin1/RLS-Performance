--Put authenticated in TO role
--remove -- in front of TO authenticated for 2nd test.

drop table if exists rlstest;
create table
    rlstest as
select x as id, 'name-' || x as name, uuid_generate_v4() as user_id, 'user' as role
from generate_series(1, 100000) x;

alter table rlstest ENABLE ROW LEVEL SECURITY;

create policy "rls_test_select" on rlstest
    --To authenticated
    using (
        auth.uid() = user_id
    );

set session role anon;
set request.jwt.claims to '{"role":"anon", "sub":"5950b438-b07c-4012-8190-6ce79e4bd8e5"}';

explain analyze SELECT count(*) FROM rlstest;
set session role postgres;

/*
Run with TO set to authenticated:

Seq Scan on rlstest  (cost=0.00..4334.00 rows=1 width=35) (actual time=170.999..170.999 rows=0 loops=1)
"  Filter: ((COALESCE(NULLIF(current_setting('request.jwt.claim.sub'::text, true), ''::text), ((NULLIF(current_setting('request.jwt.claims'::text, true), ''::text))::jsonb ->> 'sub'::text)))::uuid = user_id)"
  Rows Removed by Filter: 100000
Planning Time: 0.216 ms
Execution Time: 171.033 ms

Run with no TO role added in:

Aggregate  (cost=2936.43..2936.44 rows=1 width=8) (actual time=167.746..167.747 rows=1 loops=1)
  ->  Seq Scan on rlstest  (cost=0.00..2935.68 rows=300 width=0) (actual time=167.742..167.742 rows=0 loops=1)
"        Filter: ((COALESCE(NULLIF(current_setting('request.jwt.claim.sub'::text, true), ''::text), ((NULLIF(current_setting('request.jwt.claims'::text, true), ''::text))::jsonb ->> 'sub'::text)))::uuid = user_id)"
        Rows Removed by Filter: 100000
Planning Time: 0.194 ms
Execution Time: 167.785 ms

*/
