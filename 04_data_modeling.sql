-- Section 4 – Data Modeling 

/*
Q13: Redesign the given schema into Third Normal Form (3NF).
Issues in the provided schema:
  - products(customer_id) implies a product belongs to a specific customer (not typical). In other words, products should not be tied to a customer.
  - sales.total_sales duplicates a value that should derive from line items (quantity * unit_price).

A 3NF design separates entities and removes derived/redundant data.
*/

-- Customers
CREATE TABLE customers (
  customer_id INT PRIMARY KEY,
  full_name   VARCHAR(120) NOT NULL,
  location    VARCHAR(90)
);

-- Products 
CREATE TABLE products (
  product_id   INT PRIMARY KEY,
  product_name VARCHAR(120) NOT NULL,
  list_price   DECIMAL(12,2)  -- List price (may differ from sale unit_price at time of sale)
);

-- Sales (one row per sale/transaction)
CREATE TABLE sales (
  sales_id    INT PRIMARY KEY,
  customer_id INT NOT NULL,
  sale_date   DATE DEFAULT CURRENT_DATE,
  FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

-- Sales line items (one row per product in a sale)
-- This allows multiple products per sale, with quantity and unit price at time of sale.
-- It avoids storing total_sales directly in sale.
-- Instead, total_sales is derived from line items (quantity * unit_price).

CREATE TABLE sales_line_item (
  line_id    INT PRIMARY KEY,
  sales_id   INT NOT NULL,
  product_id INT NOT NULL,
  quantity   INT NOT NULL CHECK (quantity > 0),
  unit_price DECIMAL(12,2) NOT NULL, -- price at time of sale
  FOREIGN KEY (sales_id) REFERENCES sales_header(sales_id),
  FOREIGN KEY (product_id) REFERENCES products_catalog(product_id)
);

-- A view that computes totals from line items instead of storing them redundantly
CREATE OR REPLACE VIEW sales_totals AS
SELECT
  s.sales_id,
  SUM(li.quantity * li.unit_price) AS total_sales
FROM sales 
JOIN sales_line_item li ON li.sales_id = s.sales_id
GROUP BY s.sales_id;

/*
Q14: Star Schema for analyzing sales by product and customer location.
We use surrogate keys for dimensions and a fact table with numeric measures.
A surrogate key is a unique identifier for each row in a dimension table, often an auto-incrementing integer.
*/

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

-- Q15: Denormalization scenario.
/*
Scenario: Reporting dashboards frequently query total spending per customer and location.
To speed up these aggregate-heavy dashboards, maintain a denormalized aggregate table
(e.g., via nightly ETL or materialized view refresh).
*/

-- Example denormalized aggregate table
CREATE TABLE denorm_customer_location_totals (
  customer_id INT,
  full_name   VARCHAR(120),
  location    VARCHAR(90),
  total_spent DECIMAL(14,2),
  last_refresh TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (customer_id, location)
);

