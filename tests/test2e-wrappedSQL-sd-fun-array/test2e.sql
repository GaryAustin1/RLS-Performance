-- Testing wrapping SQL around a security definer function getting role based on auth.uid() from a 2nd table.
-- Change using() between commented policies

drop table if exists rlstest;
create table
    rlstest as
select x as id, 'name-' || x as name, uuid_generate_v4() as user_id, 'user' as role, x as team_id
from generate_series(1, 100000) x;
alter table rlstest ENABLE ROW LEVEL SECURITY;

drop table if exists rlstest_team_user;
create table
    rlstest_team_user as
select x as id, 'name-' || x as name, uuid_generate_v4() as user_id,x as team_id
from generate_series(1, 1000) x;
update rlstest_team_user set (user_id,team_id) = ('70225db6-b0ba-4116-9b08-6b25f33bb70a',1) where id = 1;
update rlstest_team_user set (user_id,team_id) = ('70225db6-b0ba-4116-9b08-6b25f33bb70a',2) where id = 2;

alter table rlstest_team_user ENABLE ROW LEVEL SECURITY;
create policy "dummy_read_policy" on rlstest_team_user
    to authenticated using (auth.uid() = user_id );

CREATE OR REPLACE FUNCTION rlstest_user_teams()
    RETURNS int[] as
$$
begin
    return array( select team_id from rlstest_team_user where auth.uid() = user_id);
end;
$$ language plpgsql security definer;

create policy "rls_test_select" on rlstest
    to authenticated
    using (
     team_id = any ( array(select rlstest_user_teams()))
    --team_id = any(rlstest_user_teams())
    );

set session role authenticated;
set request.jwt.claims to '{"role":"authenticated", "sub":"70225db6-b0ba-4116-9b08-6b25f33bb70a"}';

explain analyze SELECT * FROM rlstest;

set session role postgres;


/*
With team_id = any(rlstest_user_teams()):

Seq Scan on rlstest  (cost=0.00..16742.55 rows=2854 width=88) (actual time=2.050..173925.695 rows=2 loops=1)
  Filter: (team_id = ANY (rlstest_user_teams()))
  Rows Removed by Filter: 99998
Planning Time: 0.171 ms
Execution Time: 173925.763 ms


With team_id = any ( array(select rlstest_user_teams()))...:


Execution Time: 19.676 ms
Seq Scan on rlstest  (cost=0.26..2147.81 rows=2854 width=88) (actual time=2.080..16.484 rows=2 loops=1)
  Filter: (team_id = ANY ($0))
  Rows Removed by Filter: 99998
  InitPlan 1 (returns $0)
    ->  Result  (cost=0.00..0.26 rows=1 width=32) (actual time=2.063..2.063 rows=1 loops=1)
Planning Time: 0.124 ms
Execution Time: 16.520 ms


*/

