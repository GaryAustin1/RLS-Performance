-- Testing wrapping SQL around a security definer function getting role based on auth.uid() from a 2nd table.
-- Change using() between commented policies 1MILLON ROWS add/remove index by comment
-- Many minutes without wrapping the function.  Adding index does not help on its own without wrapping.

drop table if exists rlstest;
create table
    rlstest as
select x as id, 'name-' || x as name, uuid_generate_v4() as user_id, 'user' as role, x as team_id
from generate_series(1, 1000000) x;
alter table rlstest ENABLE ROW LEVEL SECURITY;

create index team on rlstest using btree (user_id) tablespace pg_default;

drop table if exists rlstest_team_user;
create table
    rlstest_team_user as
select x as id, 'name-' || x as name, uuid_generate_v4() as user_id,x as team_id
from generate_series(1, 1000) x;
update rlstest_team_user set user_id = '70225db6-b0ba-4116-9b08-6b25f33bb70a' where id <100 ;

--create index teams2 on rlstest_team_user using btree (user_id,team_id) tablespace pg_default;

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
drop policy rls_test_select on rlstest;
create policy "rls_test_select" on rlstest
    to authenticated
    using (
    --    team_id in (1,2,3,4,5,6,7,8,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100)
   team_id = any ( array(select rlstest_user_teams()))
   --team_id = any(rlstest_user_teams())  --VERY VERY LONG
    );

set session role authenticated;
set request.jwt.claims to '{"role":"authenticated", "sub":"70225db6-b0ba-4116-9b08-6b25f33bb70a"}';

 explain analyse select * FROM rlstest order by id  limit 1000;

set session role postgres;

/*
--Hardcoding:100teams
Gather  (cost=1000.25..19078.68 rows=99 width=40) (actual time=0.282..142.843 rows=99 loops=1)
  Workers Planned: 1
  Workers Launched: 0
  ->  Parallel Seq Scan on rlstest  (cost=0.25..18068.78 rows=58 width=40) (actual time=0.053..142.518 rows=99 loops=1)
"        Filter: (team_id = ANY ('{1,2,3,4,5,6,7,8,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40,41,42,43,44,45,46,47,48,49,50,51,52,53,54,55,56,57,58,59,60,61,62,63,64,65,66,67,68,69,70,71,72,73,74,75,76,77,78,79,80,81,82,83,84,85,86,87,88,89,90,91,92,93,94,95,96,97,98,99,100}'::integer[]))"
        Rows Removed by Filter: 999901
Planning Time: 0.163 ms
Execution Time: 142.872 ms

--100teams
Seq Scan on rlstest  (cost=0.26..31745.26 rows=10 width=40) (actual time=2.136..721.356 rows=2 loops=1)
  Filter: (team_id = ANY ($0))
  Rows Removed by Filter: 999998
  InitPlan 1 (returns $0)
    ->  Result  (cost=0.00..0.26 rows=1 width=32) (actual time=2.092..2.092 rows=1 loops=1)
Planning Time: 0.093 ms
Execution Time: 721.392 ms

--100 teams indexed main table on team_id...
Bitmap Heap Scan on rlstest  (cost=534.11..10879.13 rows=48890 width=88) (actual time=3.147..3.150 rows=2 loops=1)
  Recheck Cond: (team_id = ANY ($0))
  Heap Blocks: exact=1
  InitPlan 1 (returns $0)
    ->  Result  (cost=0.00..0.26 rows=1 width=32) (actual time=2.528..2.528 rows=1 loops=1)
  ->  Bitmap Index Scan on team  (cost=0.00..521.62 rows=48890 width=0) (actual time=3.128..3.128 rows=2 loops=1)
        Index Cond: (team_id = ANY ($0))
Planning Time: 0.939 ms
Execution Time: 3.189 ms

--10k team table, user in 1000 teams (ANY has 1000 entries), indexed main on team_id...
Index Scan using team on rlstest  (cost=0.69..16.79 rows=10 width=40) (actual time=17.623..24.358 rows=999 loops=1)
  Index Cond: (team_id = ANY ($0))
  InitPlan 1 (returns $0)
    ->  Result  (cost=0.00..0.26 rows=1 width=32) (actual time=17.579..17.579 rows=1 loops=1)
Planning Time: 0.820 ms
Execution Time: 24.442 ms

-- 1k team table, 100 teams, add compound index to teams table, no index on main, and no wrap
Limit  (cost=187328.11..187330.61 rows=1000 width=88) (actual time=60922.988..60923.003 rows=99 loops=1)
  ->  Sort  (cost=187328.11..187407.20 rows=31639 width=88) (actual time=60922.987..60922.994 rows=99 loops=1)
        Sort Key: id
        Sort Method: quicksort  Memory: 32kB
        ->  Seq Scan on rlstest  (cost=0.00..185593.38 rows=31639 width=88) (actual time=2.812..60922.954 rows=99 loops=1)
              Filter: (team_id = ANY (rlstest_user_teams()))
              Rows Removed by Filter: 999901
Planning Time: 0.156 ms
Execution Time: 60923.091 ms

--1k team table, 100 teams, compound index on teams and team_id index on rlstest, no wrap
Limit  (cost=284425.59..284428.09 rows=1000 width=88) (actual time=57184.204..57184.219 rows=99 loops=1)
  ->  Sort  (cost=284425.59..284547.81 rows=48890 width=88) (actual time=57184.202..57184.209 rows=99 loops=1)
        Sort Key: id
        Sort Method: quicksort  Memory: 32kB
        ->  Seq Scan on rlstest  (cost=0.00..281745.00 rows=48890 width=88) (actual time=0.473..57184.171 rows=99 loops=1)
              Filter: (team_id = ANY (rlstest_user_teams()))
              Rows Removed by Filter: 999901
Planning Time: 1.008 ms
Execution Time: 57184.305 ms


--Indexed Row only with 100 and 500 teams just calling function
Times out

*/
