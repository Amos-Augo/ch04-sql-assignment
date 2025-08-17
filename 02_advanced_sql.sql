-- Section 2 – Advanced SQL Techniques

-- Q6: CTE: average sales per customer, then customers whose total sales are above that average.
WITH per_customer AS (
  SELECT customer_id, SUM(total_sales) AS total_spent
  FROM sales
  GROUP BY customer_id
),
avg_spend AS (
  SELECT AVG(total_spent) AS avg_total 
  FROM per_customer
)
SELECT c.full_name, pc.total_spent
FROM per_customer pc
JOIN customer_info c ON c.customer_id = pc.customer_id
CROSS JOIN avg_spend a
WHERE pc.total_spent > a.avg_total
ORDER BY pc.total_spent DESC;

-- Q7: Window function ranking products by total sales in descending order (using CTE)
WITH per_product AS (
  SELECT p.product_id, p.product_name, SUM(s.total_sales) AS total_sales
  FROM products p
  JOIN sales s ON s.product_id = p.product_id
  GROUP BY p.product_id, p.product_name
)
SELECT
  product_name,
  total_sales,
  RANK() OVER (ORDER BY total_sales DESC) AS rnk
FROM per_product
ORDER BY rnk;

--Alternatively (including product_id)
SELECT p.product_name, 
  p.product_id, 
	SUM(s.total_sales) AS total, 
	RANK() OVER (ORDER BY SUM(s.total_sales) DESC)
FROM products p
JOIN sales s ON p.product_id  = s.product_id 
GROUP BY p.product_name, p.product_id;

-- Q8: View listing customers with total sales > 15,000.
CREATE VIEW high_value_customers AS
SELECT
  c.customer_id,
  c.full_name,
  c.location,
  SUM(s.total_sales) AS total_spent
FROM customer_info c
JOIN sales s ON s.customer_id = c.customer_id
GROUP BY c.customer_id, c.full_name, c.location
HAVING SUM(s.total_sales) > 15000;

-- Q9: Stored Procedure to accept a location and return customers + total spending
-- MySQL implementation

CREATE PROCEDURE get_customers_spending_by_location(IN p_location VARCHAR(90))
BEGIN
  SELECT c.full_name, COALESCE(SUM(s.total_sales), 0) AS total_spent
  FROM customer_info c
  LEFT JOIN sales s ON s.customer_id = c.customer_id
  WHERE c.location = p_location
  GROUP BY c.full_name
  ORDER BY total_spent DESC;
END;

-- Usage:
CALL get_customers_spending_by_location('Nairobi');

-- Q10: Recursive query to display all sales ordered by sales_id with a running total.
-- This query calculates a running total of sales by sales_id using a recursive CTE.
-- Using ROW_NUMBER() to order sales ensures we can calculate the running total even if sales_id is not sequential.

-- PostgreSQL implementation
WITH RECURSIVE ordered_sales AS (
  SELECT sales_id, total_sales,
         ROW_NUMBER() OVER (ORDER BY sales_id) AS rn
  FROM sales
),
running AS (
  SELECT sales_id, total_sales, rn, total_sales AS running_total
  FROM ordered_sales
  WHERE rn = 1

  UNION ALL

  SELECT os.sales_id, os.total_sales, os.rn, r.running_total + os.total_sales
  FROM ordered_sales os
  JOIN running r ON os.rn = r.rn + 1
)
SELECT sales_id, total_sales, running_total
FROM running
ORDER BY sales_id;

--Assuming the sales_id is sequential, we can also use a simpler approach without ROW_NUMBER():
WITH RECURSIVE running_total AS (
  SELECT sales_id, total_sales, total_sales AS running_total
  FROM sales
  WHERE sales_id = (SELECT MIN(sales_id) FROM sales)

  UNION ALL

  SELECT s.sales_id, s.total_sales, rt.running_total + s.total_sales
  FROM sales s
  JOIN running_total rt ON s.sales_id = rt.sales_id + 1
)
SELECT sales_id, total_sales, running_total
FROM running_total
ORDER BY sales_id;  