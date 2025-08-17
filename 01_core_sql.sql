-- Section 1 – Core SQL Concepts 

-- Q1: List all customers located in Nairobi. Show only full_name and location.
SELECT full_name, location
FROM customer_info
WHERE location = 'Nairobi';

-- Q2: Display each customer along with the products they purchased.
-- Using the sales table to reflect actual purchases.
SELECT c.full_name, p.product_name, p.price
FROM sales s
JOIN customer_info c ON c.customer_id = s.customer_id
JOIN products p      ON p.product_id = s.product_id
ORDER BY c.full_name, p.product_name;

-- Q3: Total sales amount for each customer (descending).
SELECT c.full_name, SUM(s.total_sales) AS total_spent
FROM customer_info c
JOIN sales s ON s.customer_id = c.customer_id
GROUP BY c.full_name
ORDER BY total_spent DESC;

-- Q4: All customers who purchased products priced above 10,000.
SELECT DISTINCT c.full_name, c.location
FROM sales s
JOIN customer_info c ON c.customer_id = s.customer_id
JOIN products p      ON p.product_id = s.product_id
WHERE p.price > 10000
ORDER BY c.full_name;

-- Q5: Top 3 customers with the highest total sales.
SELECT c.full_name, SUM(s.total_sales) AS total_spent
FROM customer_info c
JOIN sales s ON s.customer_id = c.customer_id
GROUP BY c.full_name
ORDER BY total_spent DESC
LIMIT 3;
