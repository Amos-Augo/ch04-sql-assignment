# ch04-sql-assignment

This repository contains solutions for essential **SQL**  queries based on the base schema provided in the `schema.sql` file. It includes SQL scripts, views, window functions, a recursive CTE, stored procedures, and data modeling artifacts (3NF redesign and a star schema).

---

## Repo Structure

```
ch04-sql-assignment/
├── README.md
├── schema.sql
├── 01_core_sql.sql
├── 02_advanced_sql.sql
├── 03_optimization.sql
├── 04_data_modeling.sql
```

- **schema.sql**: Original tables from the assignment prompt.
- **01_core_sql.sql**: Q1–Q5.
- **02_advanced_sql.sql**: Q6–Q10 (CTE, window functions, view, recursive CTE).
- **03_optimization.sql**: Q11–Q12 (indexes and EXPLAIN).
- **04_data_modeling.sql**: Q13–Q15 (3NF redesign, star schema, denormalization).

---
## Task-by-Task Reasoning

### Q1: List all customers located in Nairobi. Show only full_name and location.
Filtering by `location = 'Nairobi'` and projecting only the requested columns to minimize I/O.

```sql
SELECT full_name, location
FROM customer_info
WHERE location = 'Nairobi';
```

### Q2: Display each customer along with the products they purchased.
Joining `sales → customer_info → products` to reflect actual purchases. This captures which products were bought by which customers.

```sql
SELECT c.full_name, p.product_name, p.price
FROM sales s
JOIN customer_info c ON c.customer_id = s.customer_id
JOIN products p      ON p.product_id = s.product_id
ORDER BY c.full_name, p.product_name;
```

### Q3: Total sales amount for each customer (descending).
Aggregating `sales.total_sales` per customer and sorting descending to identify high spenders.

```sql
SELECT c.full_name, SUM(s.total_sales) AS total_spent
FROM customer_info c
JOIN sales s ON s.customer_id = c.customer_id
GROUP BY c.full_name
ORDER BY total_spent DESC;
```

### Q4: All customers who purchased products priced above 10,000.
Filtering by product price threshold and using `DISTINCT` to avoid listing the same customer multiple times for multiple qualifying purchases.

```sql
SELECT DISTINCT c.full_name, c.location
FROM sales s
JOIN customer_info c ON c.customer_id = s.customer_id
JOIN products p      ON p.product_id = s.product_id
WHERE p.price > 10000
ORDER BY c.full_name;
```

### Q5: Top 3 customers with the highest total sales.
Same as Q3, but limited to the top three customers after sorting by total spend.

```sql
SELECT c.full_name, SUM(s.total_sales) AS total_spent
FROM customer_info c
JOIN sales s ON s.customer_id = c.customer_id
GROUP BY c.full_name
ORDER BY total_spent DESC
LIMIT 3;
```

### Q6: CTE
- First, we compute each customer’s total in a CTE. 
- Cross-join to the overall average, then filter customers whose total exceeds the average. 

```sql
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
```

### Q7: Window Function
Aggregate per product, then use `RANK()` window function over the totals. Window functions allow keeping aggregated values and rankings in the same result.

Using a CTE:
```sql
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
```

Alternatively (including product_id):
```sql
SELECT p.product_name, 
  p.product_id, 
	SUM(s.total_sales) AS total, 
	RANK() OVER (ORDER BY SUM(s.total_sales) DESC)
FROM products p
JOIN sales s ON p.product_id  = s.product_id 
GROUP BY p.product_name, p.product_id;
```

### Q8: View
Encapsulate the “high value” threshold (15,000) in a view. This makes the logic reusable and consistent across consumers.

```sql
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
```

### Q9: Stored Procedure
MySQL implementation
We write a procedure that:
i. accepts a location parameter.
ii. aggregates total spending per customer in that location, and
iii. returns the full name and total spending, ordered by total spending descending.

```sql
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
```
### Q10: Recursive
This query calculates a running total of sales by sales_id using a recursive CTE.
It also uses ROW_NUMBER() to order sales ensuring we can calculate the running total even if sales_id is not sequential.

PostgreSQL implementation
```SQL
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
```

Assuming the sales_id is sequential, we can also use a simpler approach without ROW_NUMBER():
```SQL
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
```

### Q11: Optimization
- Create an index on `sales(total_sales)` to accelerate range conditions.
- Project necessary columns instead of `*`. Consider using `DECIMAL` for monetary values for precision and potentially better selectivity.

```sql
-- Creating the index (PostgreSQL/MySQL compatible syntax):
CREATE INDEX IF NOT EXISTS idx_sales_total_sales ON sales(total_sales);

-- Optimized query (projecting only necessary columns):
EXPLAIN
SELECT sales_id, total_sales, product_id, customer_id
FROM sales
WHERE total_sales > 5000;
```

### Q12: Index on location
Indexing `customer_info(location)` accelerates equality filters by location. Use `EXPLAIN` to confirm index selection.
```sql
CREATE INDEX IF NOT EXISTS idx_customer_info_location ON customer_info(location);

-- Testing the query using EXPLAIN to confirm index usage:
EXPLAIN
SELECT full_name
FROM customer_info
WHERE location = 'Nairobi';
```

### Q13: 3NF
Separate entities (customers, products, sales headers, and line items). 
Eliminate the dependency of `products` on a customer and avoid storing derived totals; compute from line items instead.

Customers:
```sql
CREATE TABLE customers (
  customer_id INT PRIMARY KEY,
  full_name   VARCHAR(120) NOT NULL,
  location    VARCHAR(90)
);
```

Products:
```sql
CREATE TABLE products (
  product_id   INT PRIMARY KEY,
  product_name VARCHAR(120) NOT NULL,
  list_price   DECIMAL(12,2)  -- List price (may differ from sale unit_price at time of sale)
);
```
Sales (one row per sale/transaction):
```sql
CREATE TABLE sales (
  sales_id    INT PRIMARY KEY,
  customer_id INT NOT NULL,
  sale_date   DATE DEFAULT CURRENT_DATE,
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);
```
We can then create a sales line items table allows one row per product in a sale. This allows multiple products per sale, with quantity and unit price at time of sale.
It avoids storing `total_sales` directly in `sale`.
Instead, `total_sales` is derived from line items (`quantity` * `unit_price`).

```sql
CREATE TABLE sales_line_item (
  line_id    INT PRIMARY KEY,
  sales_id   INT NOT NULL,
  product_id INT NOT NULL,
  quantity   INT NOT NULL CHECK (quantity > 0),
  unit_price DECIMAL(12,2) NOT NULL, -- price at time of sale
  FOREIGN KEY (sales_id) REFERENCES sales (sales_id),
  FOREIGN KEY (product_id) REFERENCES products (product_id)
);
```

Totals can then be computed from line items instead of storing them redundantly

```sql
CREATE OR REPLACE VIEW sales_totals AS
SELECT
  s.sales_id,
  SUM(li.quantity * li.unit_price) AS total_sales
FROM sales 
JOIN sales_line_item li ON li.sales_id = s.sales_id
GROUP BY s.sales_id;
```

### Q14: Star Schema
Create dimensions (`dim_customer`, `dim_product`, `dim_location`, `dim_date`) with surrogate keys, and a `fact_sales` table storing measures (quantity, prices, totals).
We use surrogate keys for dimensions and a fact table with numeric measures.
A surrogate key is a unique identifier for each row in a dimension table, often an auto-incrementing integer.

```sql
-- Dimension tables
CREATE TABLE dim_customer (
  customer_key SERIAL PRIMARY KEY,
  customer_id  INT UNIQUE,
  full_name    VARCHAR(120),
  location     VARCHAR(90)
);

CREATE TABLE dim_product (
  product_key  SERIAL PRIMARY KEY,
  product_id   INT UNIQUE,
  product_name VARCHAR(120)
);

CREATE TABLE dim_location (
  location_key SERIAL PRIMARY KEY,
  location     VARCHAR(90) UNIQUE
);

CREATE TABLE dim_date (
  date_key     INT PRIMARY KEY, -- e.g., 20250815
  date_value   DATE,
  year         INT,
  quarter      INT,
  month        INT,
  day          INT
);

-- Fact table
CREATE TABLE fact_sales (
  sales_id     INT,
  date_key     INT REFERENCES dim_date(date_key),
  customer_key INT REFERENCES dim_customer(customer_key),
  product_key  INT REFERENCES dim_product(product_key),
  location_key INT REFERENCES dim_location(location_key),
  quantity     INT,
  unit_price   DECIMAL(12,2),
  total_sales  DECIMAL(12,2),
  PRIMARY KEY (sales_id, product_key)
);
```

### Q15: Denormalization
*Scenario*: Reporting dashboards frequently query total spending per customer and location.
To speed up these aggregate-heavy dashboards, maintain a denormalized aggregate table
(e.g., via nightly ETL or materialized view refresh).

-- Example denormalized aggregate table

```sql
CREATE TABLE denorm_customer_location_totals (
  customer_id INT,
  full_name   VARCHAR(120),
  location    VARCHAR(90),
  total_spent DECIMAL(14,2),
  last_refresh TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (customer_id, location)
);
```
