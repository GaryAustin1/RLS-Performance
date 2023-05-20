-- Using a filter even though RLS does filter the results
-- Run this SQL before js tests

drop table if exists rlstest;
create table
    rlstest as
select x as id, 'name-' || x as name, uuid_generate_v4() as user_id, 'user' as role
from generate_series(1, 100000) x;
update rlstest set (user_id,role) = ('5950b438-b07c-4012-8190-6ce79e4bd8e5','admin') where id = 1;
alter table rlstest ENABLE ROW LEVEL SECURITY;

create policy "rls_test_select" on rlstest
    to authenticated
    using (
    auth.uid() = user_id
    );

set session role authenticated;
set request.jwt.claims to '{"role":"authenticated", "sub":"5950b438-b07c-4012-8190-6ce79e4bd8e5"}';

--explain analyze SELECT count(*) FROM rlstest;
explain analyze SELECT count(*) FROM rlstest where user_id = '5950b438-b07c-4012-8190-6ce79e4bd8e5';

set session role postgres;

/*
Run with just auth.uid() in RLS as filter:

Aggregate  (cost=2936.43..2936.44 rows=1 width=8) (actual time=171.791..171.792 rows=1 loops=1)
  ->  Seq Scan on rlstest  (cost=0.00..2935.68 rows=300 width=0) (actual time=171.784..171.784 rows=1 loops=1)
"        Filter: ((COALESCE(NULLIF(current_setting('request.jwt.claim.sub'::text, true), ''::text), ((NULLIF(current_setting('request.jwt.claims'::text, true), ''::text))::jsonb ->> 'sub'::text)))::uuid = user_id)"
        Rows Removed by Filter: 99999
Planning Time: 0.175 ms
Execution Time: 171.830 ms


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
