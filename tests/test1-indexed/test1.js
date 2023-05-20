// Test of auth.uid() = user_id.  Depends on SQL running first.
const result = await supabase1
        .from('rlstest',{head:true})
        .select()
        .explain({ analyze: true })
console.log('explain test', result)

/*
With no index on user_id:

Aggregate  (cost=2940.18..2940.21 rows=1 width=112) (actual time=731.615..731.616 rows=1 loops=1)
  ->  Limit  (cost=0.00..2935.68 rows=300 width=84) (actual time=731.605..731.605 rows=0 loops=1)
        ->  Seq Scan on rlstest  (cost=0.00..2935.68 rows=300 width=84) (actual time=731.603..731.604 rows=0 loops=1)
              Filter: ((COALESCE(NULLIF(current_setting('request.jwt.claim.sub'::text, true), ''::text), ((NULLIF(current_setting('request.jwt.claims'::text, true), ''::text))::jsonb ->> 'sub'::text)))::uuid = user_id)
              Rows Removed by Filter: 100000
Planning Time: 0.351 ms
Execution Time: 731.663 ms


With index on user_id:

Aggregate  (cost=2.67..2.70 rows=1 width=112) (actual time=0.041..0.042 rows=1 loops=1)
  ->  Limit  (cost=0.44..2.66 rows=1 width=35) (actual time=0.035..0.036 rows=0 loops=1)
        ->  Index Scan using userid on rlstest  (cost=0.44..2.66 rows=1 width=35) (actual time=0.035..0.035 rows=0 loops=1)
              Index Cond: (user_id = (COALESCE(NULLIF(current_setting('request.jwt.claim.sub'::text, true), ''::text), ((NULLIF(current_setting('request.jwt.claims'::text, true), ''::text))::jsonb ->> 'sub'::text)))::uuid)
Planning Time: 0.202 ms
Execution Time: 0.085 ms
*/
