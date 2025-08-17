-- Section 3 – Query Optimization & Execution Plans

/*
Q11: The query
  SELECT * FROM sales WHERE total_sales > 5000;
is slow.

Two improvements:
  1) Create an index on sales(total_sales) to accelerate range filters.
  2) Avoid SELECT * and only return needed columns. 
  Optionally, change FLOAT to DECIMAL for precision and better index selectivity if appropriate.
*/

-- Create the index (PostgreSQL/MySQL compatible syntax):
CREATE INDEX IF NOT EXISTS idx_sales_total_sales ON sales(total_sales);

-- Optimized query (project only necessary columns):
EXPLAIN
SELECT sales_id, total_sales, product_id, customer_id
FROM sales
WHERE total_sales > 5000;

-- Q12: Create an index to improve filters by customer location and test it.
CREATE INDEX IF NOT EXISTS idx_customer_info_location ON customer_info(location);

-- Test query (use EXPLAIN to confirm index usage):
EXPLAIN
SELECT full_name
FROM customer_info
WHERE location = 'Nairobi';
