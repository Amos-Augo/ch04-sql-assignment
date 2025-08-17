-- Base schema provided in the assignment form
CREATE TABLE customer_info(
    customer_id INT PRIMARY KEY,
    full_name VARCHAR(120),
    location VARCHAR(90)
);

CREATE TABLE products(
    product_id INT PRIMARY KEY,
    product_name VARCHAR(120),
    price FLOAT,
    customer_id INT,
    FOREIGN KEY (customer_id) REFERENCES customer_info(customer_id)
);

CREATE TABLE sales(
    sales_id INT PRIMARY KEY,
    total_sales FLOAT,
    product_id INT,
    customer_id INT,
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    FOREIGN KEY (customer_id) REFERENCES customer_info(customer_id)
);
