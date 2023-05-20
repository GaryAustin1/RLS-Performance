//  Wrapped is_admin test()
//  Run SQL first
//  Requires signed in user

  const result = await supabase1
      .from('rlstest',{head:true})
      .select()
      .explain({ analyze: true })
  console.log('explain test', result)

/*
Using is_admin():
Error timeout... canceling statement due to statement timeout


Using wrapped (select(is_admin())):

Aggregate  (cost=61.94..61.97 rows=1 width=112) (actual time=7.093..7.094 rows=1 loops=1)
  CTE pgrst_source
    ->  Limit  (cost=0.26..36.94 rows=1000 width=35) (actual time=7.081..7.081 rows=0 loops=1)
          InitPlan 1 (returns $0)
            ->  Result  (cost=0.00..0.26 rows=1 width=1) (actual time=0.628..0.628 rows=1 loops=1)
          ->  Seq Scan on rlstest  (cost=0.00..1834.00 rows=50000 width=35) (actual time=7.079..7.079 rows=0 loops=1)
                Filter: $0
                Rows Removed by Filter: 100000
  ->  CTE Scan on pgrst_source  (cost=0.00..20.00 rows=1000 width=84) (actual time=7.082..7.082 rows=0 loops=1)
Planning Time: 0.233 ms
Execution Time: 7.144 ms

*/
