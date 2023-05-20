//  Wrapped is_admin test()
//  Strange result 

  const result = await supabase1
      .from('rlstest',{head:true})
      .select()
      .explain({ analyze: true })
  console.log('explain test', result)

/*
Using is_admin():
Aggregate  (cost=61.94..61.97 rows=1 width=112) (actual time=2.495..2.497 rows=1 loops=1)
  CTE pgrst_source
    ->  Limit  (cost=0.26..36.94 rows=1000 width=35) (actual time=0.194..0.378 rows=1000 loops=1)
          InitPlan 1 (returns $0)
            ->  Result  (cost=0.00..0.26 rows=1 width=1) (actual time=0.182..0.183 rows=1 loops=1)
          ->  Seq Scan on rlstest  (cost=0.00..1834.00 rows=50000 width=35) (actual time=0.193..0.300 rows=1000 loops=1)
                Filter: $0
  ->  CTE Scan on pgrst_source  (cost=0.00..20.00 rows=1000 width=84) (actual time=0.196..0.549 rows=1000 loops=1)
Planning Time: 0.100 ms
Execution Time: 2.550 ms


Using wrapped (select(is_admin())):

Aggregate  (cost=61.94..61.97 rows=1 width=112) (actual time=2.906..2.907 rows=1 loops=1)
  CTE pgrst_source
    ->  Limit  (cost=0.26..36.94 rows=1000 width=35) (actual time=0.603..0.806 rows=1000 loops=1)
          InitPlan 1 (returns $0)
            ->  Result  (cost=0.00..0.26 rows=1 width=1) (actual time=0.594..0.595 rows=1 loops=1)
          ->  Seq Scan on rlstest  (cost=0.00..1834.00 rows=50000 width=35) (actual time=0.602..0.728 rows=1000 loops=1)
                Filter: $0
  ->  CTE Scan on pgrst_source  (cost=0.00..20.00 rows=1000 width=84) (actual time=0.606..0.980 rows=1000 loops=1)
Planning Time: 0.209 ms
Execution Time: 2.962 ms
*/
