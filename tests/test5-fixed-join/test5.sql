-- Always try and do joins on a table to get fixed results for all rows.

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

CREATE OR REPLACE FUNCTION user_teams()
    RETURNS table(id int) as
    $$
    begin
        return query select team_id from rlstest_team_user where auth.uid() = user_id;
    end;
    $$ language plpgsql security definer;

create policy "rls_test_select" on rlstest
    to authenticated
    using (
        --auth.uid() in (
        --   select user_id from rlstest_team_user where rlstest_team_user.team_id = rlstest.team_id
        --  )
        team_id in (
            select team_id from rlstest_team_user where user_id = auth.uid()
            )
        --team_id in (select user_teams())

    );

set session role authenticated;
set request.jwt.claims to '{"role":"authenticated", "sub":"70225db6-b0ba-4116-9b08-6b25f33bb70a"}';

explain analyze SELECT * FROM rlstest;

set session role postgres;


/*
With auth.uid() in....:

Seq Scan on rlstest  (cost=0.00..1356636.52 rows=29190 width=88) (actual time=0.137..8948.499 rows=2 loops=1)
  Filter: (SubPlan 1)
  Rows Removed by Filter: 99998
  SubPlan 1
    ->  Seq Scan on rlstest_team_user  (cost=0.00..46.38 rows=1 width=16) (actual time=0.089..0.089 rows=0 loops=100000)
"          Filter: ((team_id = rlstest.team_id) AND ((COALESCE(NULLIF(current_setting('request.jwt.claim.sub'::text, true), ''::text), ((NULLIF(current_setting('request.jwt.claims'::text, true), ''::text))::jsonb ->> 'sub'::text)))::uuid = user_id))"
          Rows Removed by Filter: 1000
Planning Time: 0.528 ms
Execution Time: 8948.541 ms


With team_id in....:

Seq Scan on rlstest  (cost=68.20..1631.95 rows=29190 width=88) (actual time=1.801..19.629 rows=2 loops=1)
  Filter: (hashed SubPlan 1)
  Rows Removed by Filter: 99998
  SubPlan 1
    ->  Seq Scan on rlstest_team_user  (cost=0.00..68.20 rows=1 width=4) (actual time=0.240..1.783 rows=2 loops=1)
"          Filter: (((COALESCE(NULLIF(current_setting('request.jwt.claim.sub'::text, true), ''::text), ((NULLIF(current_setting('request.jwt.claims'::text, true), ''::text))::jsonb ->> 'sub'::text)))::uuid = user_id) AND (user_id = (COALESCE(NULLIF(current_setting('request.jwt.claim.sub'::text, true), ''::text), ((NULLIF(current_setting('request.jwt.claims'::text, true), ''::text))::jsonb ->> 'sub'::text)))::uuid))"
          Rows Removed by Filter: 998
Planning Time: 0.273 ms
Execution Time: 19.676 ms


*/

