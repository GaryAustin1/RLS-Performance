-- Testing wrapping SQL around two functions
-- Change using() with commented options


drop table if exists rlstest;
create table
    rlstest as
select x as id, 'name-' || x as name, uuid_generate_v4() as user_id, 'user' as role
from generate_series(1, 100000) x;
update rlstest set (user_id,role) = ('70225db6-b0ba-4116-9b08-6b25f33bb70a','admin') where id = 1;
alter table rlstest ENABLE ROW LEVEL SECURITY;

drop table if exists rlstest_roles;
create table
    rlstest_roles as
select x as id, 'name-' || x as name, uuid_generate_v4() as user_id, 'user' as role
from generate_series(1, 1000) x;
update rlstest_roles set (user_id,role) = ('70225db6-b0ba-4116-9b08-6b25f33bb70a','user') where id = 1;
alter table rlstest_roles ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION rlstest_is_admin()
    RETURNS boolean as
$$
begin
    return exists(select from rlstest_roles where auth.uid() = user_id and role = 'admin');
end;
$$ language plpgsql security definer;

create policy "rls_test_select" on rlstest
    to authenticated
    using (
    --(select (rlstest_is_admin() OR auth.uid() = user_id)) -- very slow
    --rlstest_is_admin() OR auth.uid() = user_id  --very slow1
    (select rlstest_is_admin()) OR (select auth.uid()) = user_id --fast
    );

set session role authenticated;
set request.jwt.claims to '{"role":"authenticated", "sub":"70225db6-b0ba-4116-9b08-6b25f33bb70a"}';

explain analyze SELECT count(*) FROM rlstest;

set session role postgres;


/*
With is_admin() or auth.uid() = user_id as RLS:
Note adding select (is_admin() or auth.uid() = user_id gets same result.

Aggregate  (cost=18623.22..18623.23 rows=1 width=8) (actual time=11785.022..11785.023 rows=1 loops=1)
  ->  Seq Scan on rlstest  (cost=0.00..18548.16 rows=30024 width=0) (actual time=11785.017..11785.018 rows=1 loops=1)
        Filter: (SubPlan 1)
        Rows Removed by Filter: 99999
        SubPlan 1
          ->  Result  (cost=0.00..0.29 rows=1 width=1) (actual time=0.117..0.117 rows=1 loops=100000)
Planning Time: 0.180 ms
Execution Time: 11785.109 ms


With (select is_admin()) OR (select auth.uid) = user_id as RLS:

Aggregate  (cost=1660.33..1660.34 rows=1 width=8) (actual time=9.999..10.001 rows=1 loops=1)
  InitPlan 1 (returns $0)
    ->  Result  (cost=0.00..0.26 rows=1 width=1) (actual time=0.356..0.356 rows=1 loops=1)
  InitPlan 2 (returns $1)
    ->  Result  (cost=0.00..0.03 rows=1 width=16) (actual time=0.005..0.006 rows=1 loops=1)
  ->  Seq Scan on rlstest  (cost=0.00..1584.60 rows=30174 width=0) (actual time=9.992..9.993 rows=1 loops=1)
        Filter: ($0 OR ($1 = user_id))
        Rows Removed by Filter: 99999
Planning Time: 0.173 ms
Execution Time: 10.049 ms

*/
