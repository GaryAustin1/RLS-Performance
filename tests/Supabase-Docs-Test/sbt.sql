-- WARNING CleanUp does not include this test!
-- Checking RLS performance of Supabase docs RLS guide for posts/comment table
-- https://supabase.com/docs/guides/auth/row-level-security#advanced-policies
--
--  Using 100K posts and comments table with 1000 or 10000 posts for the user being tested.
--  comments > Example 204ms/773ms(JS), Method 5 43ms/43ms(JS)  100k/100k/10000
--  comments > Example 190ms, Method 5 29ms   100k/100k/1000
--  posts > Example 173ms/841ms(JS), Method 2 12ms/38ms(JS) 100K/100k/10000

drop table if exists posts cascade;
create table posts (
                       id            serial    primary key,
                       creator_id    uuid      not null,
                       title         text      not null,
                       body          text      not null,
                       publish_date  date      not null     default now(),
                       audience      uuid[]    null -- many to many table omitted for brevity
);
alter table posts ENABLE ROW LEVEL SECURITY;

drop table if exists comments;
create table comments (
                          id            serial    primary key,
                          post_id       int       not null     references posts(id)  on delete cascade,
                          user_id       uuid      not null,
                          body          text      not null,
                          comment_date  date      not null     default now()
);
alter table comments ENABLE ROW LEVEL SECURITY;

INSERT INTO posts (creator_id,title,body)
select uuid_generate_v4(),'title-'||x,'body-'||x
from generate_series(1, 100000) x;

update posts set creator_id = '70225db6-b0ba-4116-9b08-6b25f33bb70a' where id < 10000;

INSERT INTO comments (post_id,user_id,body)
select (x/10+1)::int,uuid_generate_v4(),'body-'||x
from generate_series(1, 100000) x;

create policy "Creator can see their own posts"
    on posts
    for select
    using (
         auth.uid() = posts.creator_id
        --(select auth.uid()) = posts.creator_id
    );

create policy "Users can see all comments for posts they have access to."
    on comments
    for select
    using (
      exists (select 1 from posts where posts.id = comments.post_id)  -- SB example
      --post_id in (select posts.id from posts where posts.creator_id = (select auth.uid()))
    );

set session role authenticated;
set request.jwt.claims to '{"role":"authenticated", "sub":"70225db6-b0ba-4116-9b08-6b25f33bb70a"}';

explain analyze SELECT * FROM comments;

set session role postgres;

/*
--  comments policy in SB example     exists (select 1 from posts where posts.id = comments.post_id)
--  100K posts, 100k comments, 1000 posts by user

Seq Scan on comments  (cost=0.00..195914.94 rows=38364 width=60) (actual time=173.407..189.983 rows=9989 loops=1)
  Filter: (hashed SubPlan 2)
  Rows Removed by Filter: 90011
  SubPlan 2
    ->  Seq Scan on posts  (cost=0.00..2761.20 rows=260 width=4) (actual time=171.283..173.150 rows=999 loops=1)
"          Filter: ((COALESCE(NULLIF(current_setting('request.jwt.claim.sub'::text, true), ''::text), ((NULLIF(current_setting('request.jwt.claims'::text, true), ''::text))::jsonb ->> 'sub'::text)))::uuid = creator_id)"
          Rows Removed by Filter: 99001
Planning Time: 0.305 ms
Execution Time: 190.433 ms

************
-- comments policy SB example
-- 100K posts, 100k comments, 10000 posts by user

Seq Scan on comments  (cost=0.00..195914.94 rows=38364 width=60) (actual time=176.874..201.639 rows=99989 loops=1)
  Filter: (hashed SubPlan 2)
  Rows Removed by Filter: 11
  SubPlan 2
    ->  Seq Scan on posts  (cost=0.00..3009.82 rows=283 width=4) (actual time=155.791..174.533 rows=9999 loops=1)
"          Filter: ((COALESCE(NULLIF(current_setting('request.jwt.claim.sub'::text, true), ''::text), ((NULLIF(current_setting('request.jwt.claims'::text, true), ''::text))::jsonb ->> 'sub'::text)))::uuid = creator_id)"
          Rows Removed by Filter: 90001
Planning Time: 0.312 ms
Execution Time: 205.770 ms
JS
Execution Time: 772.951 ms

***************
-- comments policy   post_id in (select id from posts where creator_id = (select auth.uid()))
-- 100k posts, 100k comments, 10000 posts by user

Seq Scan on comments  (cost=1737.20..3530.30 rows=38364 width=60) (actual time=14.159..39.396 rows=99989 loops=1)
  Filter: (hashed SubPlan 2)
  Rows Removed by Filter: 11
  SubPlan 2
    ->  Result  (cost=0.06..1736.50 rows=283 width=4) (actual time=9.894..12.173 rows=9999 loops=1)
"          One-Time Filter: ((COALESCE(NULLIF(current_setting('request.jwt.claim.sub'::text, true), ''::text), ((NULLIF(current_setting('request.jwt.claims'::text, true), ''::text))::jsonb ->> 'sub'::text)))::uuid = $0)"
          InitPlan 1 (returns $0)
            ->  Result  (cost=0.00..0.03 rows=1 width=16) (actual time=0.004..0.004 rows=1 loops=1)
          ->  Seq Scan on posts  (cost=0.06..1736.50 rows=283 width=4) (actual time=9.874..11.275 rows=9999 loops=1)
                Filter: (creator_id = $0)
                Rows Removed by Filter: 90001
Planning Time: 0.250 ms
Execution Time: 43.530 ms
JS (10K row limit)
Execution Time: 43.293 ms

*************
-- comments policy   post_id in (select posts.id from posts where posts.creator_id = (select auth.uid()))
-- 100k posts, 100k comments, 1000 posts by user

Seq Scan on comments  (cost=0.00..254584.00 rows=50000 width=38) (actual time=17.354..29.686 rows=9 loops=1)
  Filter: (hashed SubPlan 2)
  Rows Removed by Filter: 99991
  SubPlan 2
    ->  Seq Scan on posts  (cost=0.00..444.03 rows=1 width=4) (actual time=17.334..17.337 rows=1 loops=1)
"          Filter: ((COALESCE(NULLIF(current_setting('request.jwt.claim.sub'::text, true), ''::text), ((NULLIF(current_setting('request.jwt.claims'::text, true), ''::text))::jsonb ->> 'sub'::text)))::uuid = creator_id)"
          Rows Removed by Filter: 10000
Planning Time: 0.445 ms
Execution Time: 29.733 ms

********************
--  posts policy in SB example     auth.uid() = posts.creator_id
--  100K posts, 10000 posts by user

Seq Scan on posts  (cost=0.00..3009.82 rows=283 width=120) (actual time=153.847..172.398 rows=9999 loops=1)
"  Filter: ((COALESCE(NULLIF(current_setting('request.jwt.claim.sub'::text, true), ''::text), ((NULLIF(current_setting('request.jwt.claims'::text, true), ''::text))::jsonb ->> 'sub'::text)))::uuid = creator_id)"
  Rows Removed by Filter: 90001
Planning Time: 0.230 ms
Execution Time: 172.892 ms

JS
Execution Time: 841.288 ms


********
--  posts policy    (select auth.uid()) = posts.creator_id
--  100K posts, 10000 posts by user

Seq Scan on posts  (cost=0.03..1736.47 rows=283 width=120) (actual time=9.947..11.169 rows=9999 loops=1)
  Filter: ($0 = creator_id)
  Rows Removed by Filter: 90001
  InitPlan 1 (returns $0)
    ->  Result  (cost=0.00..0.03 rows=1 width=16) (actual time=0.014..0.015 rows=1 loops=1)
Planning Time: 0.198 ms
Execution Time: 11.617 ms
JS
Execution Time: 37.972 ms

*/
