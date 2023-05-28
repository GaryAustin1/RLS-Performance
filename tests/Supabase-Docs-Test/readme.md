Did an additional test on Supabase Docs RLS guide [Advanced policies](https://supabase.com/docs/guides/auth/row-level-security#advanced-policies)

![image](https://github.com/GaryAustin1/RLS-Perfomance/assets/54564956/9939ae7a-96a8-4d98-8cb3-953b09ee6213)

Using method 5 for the comments policy and method 2 for the posts policy had significant impact.   
See https://github.com/GaryAustin1/RLS-Perfomance for methods

Tested with 100K comments, 100k posts and both 10k and 1K posts by the test user.

|Table|Example Policy|(Method) Policy|Posts by User|
|---------|--------------|-----------|--------------|
|comments|204ms/773ms(JS)|(5) 43ms/43ms(JS)|10000|
|comments|190ms |(5) 29ms |1000|
|posts|173ms/841ms(JS)|(2) 12ms/38ms(JS) |10000|

comments table policy   
Example: `exists (select 1 from posts where posts.id = comments.post_id)`  
Method 5: `post_id in (select id from posts where creator_id = (select auth.uid()))`  

posts table policy  
Example: `select auth.uid() = posts.creator_id`  
Method 2: `(select auth.uid()) = posts.creator_id`  


Notes: At some point method 5 does not make much sense as the list it builds up can get very large.
The method clearly makes sense for most cases, especially if the join table is smaller than the main table, or the row being filtered on is a small subset.
But I tested 50K Posts by the user and the optimizer still chose that method, but time was up to 80ms.
At 90K posts by the user the optimizer picked another method, but did not break.
Note this article https://www.dbi-services.com/blog/what-is-the-maximum-in-list-size-in-postgresql/ had the list up to 2M for the `in` and then at 3M ran out of memory.
So at a minimum probably need a note to think about the size of the `in` list when it is some % more of the main table rows.



