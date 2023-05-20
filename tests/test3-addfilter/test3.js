// Run test3 SQL first.

// Without Filter
  const result = await supabase1
      .from('rlstest',{head:true})
      .select()
      .explain({ analyze: true })
  console.log('explain test', result)

// With filter
  const result = await supabase1
      .from('rlstest',{head:true})
      .select()
      .eq('user_id','70225db6-b0ba-4116-9b08-6b25f33bb70a')  // user id of row added in sql and signed in user id.
      .explain({ analyze: true })
  console.log('explain test', result)

/*
Without filter:

Aggregate  (cost=4334.02..4334.04 rows=1 width=112) (actual time=740.389..740.390 rows=1 loops=1)
  ->  Limit  (cost=0.00..4334.00 rows=1 width=35) (actual time=740.363..740.364 rows=1 loops=1)
        ->  Seq Scan on rlstest  (cost=0.00..4334.00 rows=1 width=35) (actual time=740.361..740.362 rows=1 loops=1)
              Filter: ((COALESCE(NULLIF(current_setting('request.jwt.claim.sub'::text, true), ''::text), ((NULLIF(current_setting('request.jwt.claims'::text, true), ''::text))::jsonb ->> 'sub'::text)))::uuid = user_id)
              Rows Removed by Filter: 99999
Planning Time: 0.172 ms
Execution Time: 740.436 ms

With filter:

Aggregate  (cost=2084.04..2084.07 rows=1 width=112) (actual time=9.564..9.565 rows=1 loops=1)
  ->  Limit  (cost=0.02..2084.03 rows=1 width=35) (actual time=9.533..9.535 rows=1 loops=1)
        ->  Result  (cost=0.02..2084.03 rows=1 width=35) (actual time=9.532..9.533 rows=1 loops=1)
              One-Time Filter: ((COALESCE(NULLIF(current_setting('request.jwt.claim.sub'::text, true), ''::text), ((NULLIF(current_setting('request.jwt.claims'::text, true), ''::text))::jsonb ->> 'sub'::text)))::uuid = '70225db6-b0ba-4116-9b08-6b25f33bb70a'::uuid)
              ->  Seq Scan on rlstest  (cost=0.02..2084.03 rows=1 width=35) (actual time=9.507..9.508 rows=1 loops=1)
                    Filter: (user_id = '70225db6-b0ba-4116-9b08-6b25f33bb70a'::uuid)
                    Rows Removed by Filter: 99999
Planning Time: 0.345 ms
Execution Time: 9.619 ms





*/
