-- Testing wrapping SQL around a security definer function getting role based on auth.uid() from a 2nd table.
-- Change using() between commented get_role() and (select(get_role()))
-- Note it is as silly function, but was reusing tables. It could have getting user's teams to match on rows.


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
update rlstest_roles set (user_id,role) = ('70225db6-b0ba-4116-9b08-6b25f33bb70a','admin') where id = 1;
alter table rlstest_roles ENABLE ROW LEVEL SECURITY;

CREATE OR REPLACE FUNCTION get_role()
    RETURNS text as
$$
begin
    return (select role from rlstest_roles where auth.uid() = user_id);
end;
$$ language plpgsql security definer;

create policy "rls_test_select" on rlstest
    to authenticated
    using (
    --(select get_role())=role
    get_role() =role  --very slow!
    );

set session role authenticated;
set request.jwt.claims to '{"role":"authenticated", "sub":"70225db6-b0ba-4116-9b08-6b25f33bb70a"}';

explain analyze SELECT count(*) FROM rlstest;

set session role postgres;


/*
with get_role = role

Aggregate  (cost=16597.35..16597.36 rows=1 width=8) (actual time=173484.219..173484.220 rows=1 loops=1)
  ->  Seq Scan on rlstest  (cost=0.00..16596.60 rows=300 width=0) (actual time=173484.213..173484.214 rows=1 loops=1)
        Filter: (get_role() = role)
        Rows Removed by Filter: 99999
Planning Time: 0.092 ms
Execution Time: 173484.300 ms   !!!!!!!!!!!!!!!!!!!!


with (select get_role())=role

  InitPlan 1 (returns $0)
    ->  Result  (cost=0.00..0.26 rows=1 width=32) (actual time=2.047..2.047 rows=1 loops=1)
  ->  Seq Scan on rlstest  (cost=0.00..2084.00 rows=100000 width=0) (actual time=12.425..12.425 rows=1 loops=1)
        Filter: ($0 = role)
        Rows Removed by Filter: 99999
Planning Time: 0.137 ms
Execution Time: 12.475 ms


 */
