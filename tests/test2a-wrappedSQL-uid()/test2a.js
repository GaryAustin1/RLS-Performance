// Wrapping a function in a select.  2a with auth.uid().
//  Run SQL first

  const result = await supabase1
      .from('rlstest',{head:true})
      .select()
      .explain({ analyze: true })
  console.log('explain test', result)

/*
Just auth.uid() = user_id in RLS:

Aggregate  (cost=4334.02..4334.04 rows=1 width=112) (actual time=735.015..735.016 rows=1 loops=1)
  ->  Limit  (cost=0.00..4334.00 rows=1 width=35) (actual time=734.987..734.988 rows=1 loops=1)
        ->  Seq Scan on rlstest  (cost=0.00..4334.00 rows=1 width=35) (actual time=734.986..734.987 rows=1 loops=1)
              Filter: ((COALESCE(NULLIF(current_setting('request.jwt.claim.sub'::text, true), ''::text), ((NULLIF(current_setting('request.jwt.claims'::text, true), ''::text))::jsonb ->> 'sub'::text)))::uuid = user_id)
              Rows Removed by Filter: 99999
Planning Time: 0.416 ms
Execution Time: 735.064 ms

Using (select(auth.uid())) = user_id in RLS

Aggregate  (cost=1589.13..1589.16 rows=1 width=112) (actual time=10.373..10.374 rows=1 loops=1)
  ->  Limit  (cost=0.03..1584.63 rows=300 width=84) (actual time=10.341..10.342 rows=1 loops=1)
        InitPlan 1 (returns $0)
          ->  Result  (cost=0.00..0.03 rows=1 width=16) (actual time=0.048..0.049 rows=1 loops=1)
        ->  Seq Scan on rlstest  (cost=0.00..1584.60 rows=300 width=84) (actual time=10.339..10.340 rows=1 loops=1)
              Filter: ($0 = user_id)
              Rows Removed by Filter: 99999
Planning Time: 0.321 ms
Execution Time: 10.425 ms
*/
