BEGIN;

TRUNCATE TABLE orderitems,
orders,
customers,
products RESTART IDENTITY CASCADE;

-- Smart data loading: Try private data first, fall back to demo data
-- This allows seamless switching between demo data (data/raw) and production data (data/private)
DO $ $ DECLARE products_path TEXT;

customers_path TEXT;

orders_path TEXT;

orderitems_path TEXT;

BEGIN -- Determine which data directory to use (private takes precedence)
IF EXISTS (
    SELECT
        1
    FROM
        pg_ls_dir('/workspace/data/private')
    WHERE
        pg_ls_dir = 'products.csv'
) THEN products_path := '/workspace/data/private/products.csv';

customers_path := '/workspace/data/private/customers.csv';

orders_path := '/workspace/data/private/orders.csv';

orderitems_path := '/workspace/data/private/orderitems.csv';

RAISE NOTICE 'Loading from private data directory (production data)';

ELSE products_path := '/workspace/data/raw/products.csv';

customers_path := '/workspace/data/raw/customers.csv';

orders_path := '/workspace/data/raw/orders.csv';

orderitems_path := '/workspace/data/raw/orderitems.csv';

RAISE NOTICE 'Loading from raw data directory (demo data)';

END IF;

EXECUTE format(
    'COPY products (product_id, name, price, category) FROM %L WITH (FORMAT csv, HEADER true)',
    products_path
);

EXECUTE format(
    'COPY customers (customer_id, name, email) FROM %L WITH (FORMAT csv, HEADER true)',
    customers_path
);

EXECUTE format(
    'COPY orders (order_id, customer_id, order_date) FROM %L WITH (FORMAT csv, HEADER true)',
    orders_path
);

EXECUTE format(
    'COPY orderitems (order_item_id, order_id, product_id, quantity) FROM %L WITH (FORMAT csv, HEADER true)',
    orderitems_path
);

END $ $;

COMMIT;