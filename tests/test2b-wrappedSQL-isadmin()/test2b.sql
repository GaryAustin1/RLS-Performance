-- Testing wrapping SQL around a typical security definer function that checks if the user has a role from a 2nd table.
-- Change using() between commented is_admin() and (select(is_admin()))
-- WARNING change is_admin function name if you have an existing function by that name

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

CREATE OR REPLACE FUNCTION is_admin()
    RETURNS boolean as
$$
begin
    return exists(select from rlstest_roles where auth.uid() = user_id and role = 'admin');
end;
$$ language plpgsql security definer;

create policy "rls_test_select" on rlstest
    to authenticated
    using (
        (select is_admin())
        --is_admin()  --very slow!
    );

set session role authenticated;
set request.jwt.claims to '{"role":"authenticated", "sub":"70225db6-b0ba-4116-9b08-6b25f33bb70a"}';

explain analyze SELECT count(*) FROM rlstest;

set session role postgres;


/*
With is_admin() as RLS:

Aggregate  (cost=16496.52..16496.53 rows=1 width=8) (actual time=11578.737..11578.738 rows=1 loops=1)
  ->  Seq Scan on rlstest  (cost=0.00..16446.48 rows=20016 width=0) (actual time=0.433..11561.735 rows=100000 loops=1)
        Filter: is_admin()
Planning Time: 0.087 ms
Execution Time: 11578.815 ms  <<<<!!!!!!   11 seconds, 100kx1000 potential iterations.

With select(is_admin()) as RLS:

Aggregate  (cost=1509.80..1509.81 rows=1 width=8) (actual time=7.387..7.388 rows=1 loops=1)
  InitPlan 1 (returns $0)
    ->  Result  (cost=0.00..0.26 rows=1 width=1) (actual time=0.520..0.521 rows=1 loops=1)
  ->  Seq Scan on rlstest  (cost=0.00..1434.48 rows=30024 width=0) (actual time=7.380..7.380 rows=0 loops=1)
        Filter: $0
        Rows Removed by Filter: 100000
Planning Time: 0.099 ms
Execution Time: 7.429 ms

*/
