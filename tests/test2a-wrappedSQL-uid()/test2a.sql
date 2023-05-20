--Wrapping a postgres function in a select.  Auth.uid() example.  (indexed is better way for this)
--Change using() commented values for tests

drop table if exists rlstest;
create table
    rlstest as
select x as id, 'name-' || x as name, uuid_generate_v4() as user_id, 'user' as role
from generate_series(1, 100000) x;
update rlstest set (user_id,role) = ('70225db6-b0ba-4116-9b08-6b25f33bb70a','admin') where id = 1;
alter table rlstest ENABLE ROW LEVEL SECURITY;

create policy "rls_test_select" on rlstest
    to authenticated
    using (
        (select(auth.uid())) = user_id
        --auth.uid() = user_id
    );

set session role authenticated;
set request.jwt.claims to '{"role":"authenticated", "sub":"70225db6-b0ba-4116-9b08-6b25f33bb70a"}';

explain analyze SELECT count(*) FROM rlstest;

set session role postgres;

/*
Run with just auth.uid() = user_id:

Aggregate  (cost=2936.43..2936.44 rows=1 width=8) (actual time=179.368..179.369 rows=1 loops=1)
  ->  Seq Scan on rlstest  (cost=0.00..2935.68 rows=300 width=0) (actual time=179.362..179.363 rows=1 loops=1)
"        Filter: ((COALESCE(NULLIF(current_setting('request.jwt.claim.sub'::text, true), ''::text), ((NULLIF(current_setting('request.jwt.claims'::text, true), ''::text))::jsonb ->> 'sub'::text)))::uuid = user_id)"
        Rows Removed by Filter: 99999
Planning Time: 0.180 ms
Execution Time: 179.408 ms

Run with added filter in query:

Aggregate  (cost=1585.38..1585.38 rows=1 width=8) (actual time=8.709..8.710 rows=1 loops=1)
  ->  Result  (cost=0.02..1584.62 rows=300 width=0) (actual time=8.701..8.702 rows=1 loops=1)
"        One-Time Filter: ((COALESCE(NULLIF(current_setting('request.jwt.claim.sub'::text, true), ''::text), ((NULLIF(current_setting('request.jwt.claims'::text, true), ''::text))::jsonb ->> 'sub'::text)))::uuid = '5950b438-b07c-4012-8190-6ce79e4bd8e5'::uuid)"
        ->  Seq Scan on rlstest  (cost=0.02..1584.62 rows=300 width=0) (actual time=8.686..8.687 rows=1 loops=1)
              Filter: (user_id = '5950b438-b07c-4012-8190-6ce79e4bd8e5'::uuid)
              Rows Removed by Filter: 99999
Planning Time: 0.176 ms
Execution Time: 8.759 ms

*/
