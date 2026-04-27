-- SQL solutions (runnable in psql)
-- Source: docs/questions.md
-- 1) Adding a New Product
INSERT INTO
    products (product_id, name, price, category)
VALUES
    (
        101,
        'Bluetooth Speaker X1',
        79.99,
        'Electronics'
    ) ON CONFLICT (product_id) DO NOTHING;

-- 2) Adding a New Customer
INSERT INTO
    customers (customer_id, name, email)
VALUES
    (101, 'Amina Yusuf', 'amina.yusuf101@example.com') ON CONFLICT (customer_id) DO NOTHING;

-- 3) Updating a Customer's Email
UPDATE
    customers
SET
    email = 'amina.yusuf.updated@example.com'
WHERE
    customer_id = 101;

-- 4) Deleting a Product
BEGIN;

DELETE FROM
    orderitems
WHERE
    product_id = 101;

DELETE FROM
    products
WHERE
    product_id = 101;

COMMIT;

-- 5) Deleting Orders Before a Specific Date
BEGIN;

DELETE FROM
    orderitems
WHERE
    order_id IN (
        SELECT
            order_id
        FROM
            orders
        WHERE
            order_date < DATE '2026-02-01'
    );

DELETE FROM
    orders
WHERE
    order_date < DATE '2026-02-01';

COMMIT;

-- 6) Select Products with Specific Price Range
SELECT
    *
FROM
    products
WHERE
    price BETWEEN 20
    AND 80
ORDER BY
    price;

-- 7) Find Orders Placed on a Specific Date
SELECT
    *
FROM
    orders
WHERE
    order_date = DATE '2026-01-15';

-- 8) Find Products by Partial Name
SELECT
    *
FROM
    products
WHERE
    name ILIKE '%mouse%'
ORDER BY
    product_id;

-- 9) Search Customers By Email Domain
SELECT
    *
FROM
    customers
WHERE
    email ILIKE '%@example.com'
ORDER BY
    customer_id;

-- 10) Select Orders Within A Specific Date Range
SELECT
    *
FROM
    orders
WHERE
    order_date BETWEEN DATE '2026-01-10'
    AND DATE '2026-02-10'
ORDER BY
    order_date;

-- 11) Find Products Priced Within A Range
SELECT
    product_id,
    name,
    price,
    category
FROM
    products
WHERE
    price >= 50
    AND price <= 120
ORDER BY
    price;

-- 12) Find The Total Sales Per Category
SELECT
    p.category,
    SUM(oi.quantity * p.price) AS total_sales
FROM
    orderitems oi
    JOIN products p ON p.product_id = oi.product_id
GROUP BY
    p.category
ORDER BY
    total_sales DESC;

-- 13) Find The Highest-Selling Product
SELECT
    p.product_id,
    p.name,
    SUM(oi.quantity) AS total_units_sold,
    SUM(oi.quantity * p.price) AS total_revenue
FROM
    orderitems oi
    JOIN products p ON p.product_id = oi.product_id
GROUP BY
    p.product_id,
    p.name
ORDER BY
    total_units_sold DESC
LIMIT
    1;

-- 14) Find The Categories With More Than 10 Sales
SELECT
    p.category,
    SUM(oi.quantity) AS total_units_sold
FROM
    orderitems oi
    JOIN products p ON p.product_id = oi.product_id
GROUP BY
    p.category
HAVING
    SUM(oi.quantity) > 10
ORDER BY
    total_units_sold DESC;

-- 15) Find The Average Product Price Per Category Ordered By Price
SELECT
    category,
    AVG(price) AS avg_price
FROM
    products
GROUP BY
    category
ORDER BY
    avg_price DESC;

-- 16) Get The Products And Their Orders
SELECT
    p.product_id,
    p.name AS product_name,
    o.order_id,
    o.order_date,
    oi.quantity
FROM
    products p
    JOIN orderitems oi ON oi.product_id = p.product_id
    JOIN orders o ON o.order_id = oi.order_id
ORDER BY
    o.order_date,
    p.product_id;

-- 17) Get The Customers And Their Order
SELECT
    c.customer_id,
    c.name AS customer_name,
    c.email,
    o.order_id,
    o.order_date
FROM
    customers c
    LEFT JOIN orders o ON o.customer_id = c.customer_id
ORDER BY
    c.customer_id,
    o.order_date;

-- 18) List All Unique Customer Names And Product Names In One Column
SELECT
    name AS unique_name
FROM
    customers
UNION
SELECT
    name AS unique_name
FROM
    products
ORDER BY
    unique_name;

-- 19) Combine Customer's First And Last Names Into A Full Name
SELECT
    name AS original_name,
    SPLIT_PART(name, ' ', 1) AS first_name,
    NULLIF(TRIM(REGEXP_REPLACE(name, '^[^ ]+\s*', '')), '') AS last_name,
    CONCAT_WS(
        ' ',
        SPLIT_PART(name, ' ', 1),
        NULLIF(TRIM(REGEXP_REPLACE(name, '^[^ ]+\s*', '')), '')
    ) AS full_name
FROM
    customers;