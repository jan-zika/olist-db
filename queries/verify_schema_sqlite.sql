-- ============================================================
-- Schema + data profile verification
-- SQLite equivalent of verify_schema.sql
-- Produces the same 13-column output:
--   table_name, column_name, full_type, nullable,
--   null_count, distinct_count, min_val, max_val,
--   sample_1, sample_2, sample_3, extra_stat, sanity_check
-- Run against olist.sqlite
-- ============================================================

-- customers
SELECT 'customers' AS table_name, 'customer_id' AS column_name, 'TEXT' AS full_type, 0 AS nullable,
    SUM(CASE WHEN customer_id IS NULL THEN 1 ELSE 0 END) AS null_count,
    COUNT(DISTINCT customer_id) AS distinct_count,
    MIN(customer_id) AS min_val, MAX(customer_id) AS max_val,
    MIN(CASE WHEN rn=1 THEN customer_id END) AS sample_1,
    MIN(CASE WHEN rn=2 THEN customer_id END) AS sample_2,
    MIN(CASE WHEN rn=3 THEN customer_id END) AS sample_3,
    'max_len=' || MAX(LENGTH(customer_id)) AS extra_stat,
    'OK' AS sanity_check
FROM (SELECT customer_id, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM customers WHERE customer_id IS NOT NULL) x

UNION ALL
SELECT 'customers', 'customer_unique_id', 'TEXT', 1,
    SUM(CASE WHEN customer_unique_id IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT customer_unique_id),
    MIN(customer_unique_id), MAX(customer_unique_id),
    MIN(CASE WHEN rn=1 THEN customer_unique_id END),
    MIN(CASE WHEN rn=2 THEN customer_unique_id END),
    MIN(CASE WHEN rn=3 THEN customer_unique_id END),
    'max_len=' || MAX(LENGTH(customer_unique_id)), 'OK'
FROM (SELECT customer_unique_id, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM customers WHERE customer_unique_id IS NOT NULL) x

UNION ALL
SELECT 'customers', 'customer_zip_code_prefix', 'INTEGER', 1,
    SUM(CASE WHEN customer_zip_code_prefix IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT customer_zip_code_prefix),
    CAST(MIN(customer_zip_code_prefix) AS TEXT), CAST(MAX(customer_zip_code_prefix) AS TEXT),
    MIN(CASE WHEN rn=1 THEN CAST(customer_zip_code_prefix AS TEXT) END),
    MIN(CASE WHEN rn=2 THEN CAST(customer_zip_code_prefix AS TEXT) END),
    MIN(CASE WHEN rn=3 THEN CAST(customer_zip_code_prefix AS TEXT) END),
    'avg=' || CAST(ROUND(AVG(CAST(customer_zip_code_prefix AS REAL)), 4) AS TEXT), 'OK'
FROM (SELECT customer_zip_code_prefix, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM customers WHERE customer_zip_code_prefix IS NOT NULL) x

UNION ALL
SELECT 'customers', 'customer_city', 'TEXT', 1,
    SUM(CASE WHEN customer_city IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT customer_city),
    MIN(customer_city), MAX(customer_city),
    MIN(CASE WHEN rn=1 THEN customer_city END),
    MIN(CASE WHEN rn=2 THEN customer_city END),
    MIN(CASE WHEN rn=3 THEN customer_city END),
    'max_len=' || MAX(LENGTH(customer_city)), 'OK'
FROM (SELECT customer_city, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM customers WHERE customer_city IS NOT NULL) x

UNION ALL
SELECT 'customers', 'customer_state', 'TEXT', 1,
    SUM(CASE WHEN customer_state IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT customer_state),
    MIN(customer_state), MAX(customer_state),
    MIN(CASE WHEN rn=1 THEN customer_state END),
    MIN(CASE WHEN rn=2 THEN customer_state END),
    MIN(CASE WHEN rn=3 THEN customer_state END),
    'max_len=' || MAX(LENGTH(customer_state)), 'OK'
FROM (SELECT customer_state, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM customers WHERE customer_state IS NOT NULL) x

-- sellers
UNION ALL
SELECT 'sellers', 'seller_id', 'TEXT', 0,
    SUM(CASE WHEN seller_id IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT seller_id),
    MIN(seller_id), MAX(seller_id),
    MIN(CASE WHEN rn=1 THEN seller_id END),
    MIN(CASE WHEN rn=2 THEN seller_id END),
    MIN(CASE WHEN rn=3 THEN seller_id END),
    'max_len=' || MAX(LENGTH(seller_id)), 'OK'
FROM (SELECT seller_id, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM sellers WHERE seller_id IS NOT NULL) x

UNION ALL
SELECT 'sellers', 'seller_zip_code_prefix', 'INTEGER', 1,
    SUM(CASE WHEN seller_zip_code_prefix IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT seller_zip_code_prefix),
    CAST(MIN(seller_zip_code_prefix) AS TEXT), CAST(MAX(seller_zip_code_prefix) AS TEXT),
    MIN(CASE WHEN rn=1 THEN CAST(seller_zip_code_prefix AS TEXT) END),
    MIN(CASE WHEN rn=2 THEN CAST(seller_zip_code_prefix AS TEXT) END),
    MIN(CASE WHEN rn=3 THEN CAST(seller_zip_code_prefix AS TEXT) END),
    'avg=' || CAST(ROUND(AVG(CAST(seller_zip_code_prefix AS REAL)), 4) AS TEXT), 'OK'
FROM (SELECT seller_zip_code_prefix, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM sellers WHERE seller_zip_code_prefix IS NOT NULL) x

UNION ALL
SELECT 'sellers', 'seller_city', 'TEXT', 1,
    SUM(CASE WHEN seller_city IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT seller_city),
    MIN(seller_city), MAX(seller_city),
    MIN(CASE WHEN rn=1 THEN seller_city END),
    MIN(CASE WHEN rn=2 THEN seller_city END),
    MIN(CASE WHEN rn=3 THEN seller_city END),
    'max_len=' || MAX(LENGTH(seller_city)), 'OK'
FROM (SELECT seller_city, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM sellers WHERE seller_city IS NOT NULL) x

UNION ALL
SELECT 'sellers', 'seller_state', 'TEXT', 1,
    SUM(CASE WHEN seller_state IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT seller_state),
    MIN(seller_state), MAX(seller_state),
    MIN(CASE WHEN rn=1 THEN seller_state END),
    MIN(CASE WHEN rn=2 THEN seller_state END),
    MIN(CASE WHEN rn=3 THEN seller_state END),
    'max_len=' || MAX(LENGTH(seller_state)), 'OK'
FROM (SELECT seller_state, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM sellers WHERE seller_state IS NOT NULL) x

-- products
UNION ALL
SELECT 'products', 'product_id', 'TEXT', 0,
    SUM(CASE WHEN product_id IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT product_id),
    MIN(product_id), MAX(product_id),
    MIN(CASE WHEN rn=1 THEN product_id END),
    MIN(CASE WHEN rn=2 THEN product_id END),
    MIN(CASE WHEN rn=3 THEN product_id END),
    'max_len=' || MAX(LENGTH(product_id)), 'OK'
FROM (SELECT product_id, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM products WHERE product_id IS NOT NULL) x

UNION ALL
SELECT 'products', 'product_category_name', 'TEXT', 1,
    SUM(CASE WHEN product_category_name IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT product_category_name),
    MIN(product_category_name), MAX(product_category_name),
    MIN(CASE WHEN rn=1 THEN product_category_name END),
    MIN(CASE WHEN rn=2 THEN product_category_name END),
    MIN(CASE WHEN rn=3 THEN product_category_name END),
    'max_len=' || MAX(LENGTH(product_category_name)), 'OK'
FROM (SELECT product_category_name, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM products WHERE product_category_name IS NOT NULL) x

UNION ALL
SELECT 'products', 'product_weight_g', 'INTEGER', 1,
    SUM(CASE WHEN product_weight_g IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT product_weight_g),
    CAST(MIN(product_weight_g) AS TEXT), CAST(MAX(product_weight_g) AS TEXT),
    MIN(CASE WHEN rn=1 THEN CAST(product_weight_g AS TEXT) END),
    MIN(CASE WHEN rn=2 THEN CAST(product_weight_g AS TEXT) END),
    MIN(CASE WHEN rn=3 THEN CAST(product_weight_g AS TEXT) END),
    'avg=' || CAST(ROUND(AVG(CAST(product_weight_g AS REAL)), 4) AS TEXT), 'OK'
FROM (SELECT product_weight_g, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM products WHERE product_weight_g IS NOT NULL) x

-- orders
UNION ALL
SELECT 'orders', 'order_id', 'TEXT', 0,
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT order_id),
    MIN(order_id), MAX(order_id),
    MIN(CASE WHEN rn=1 THEN order_id END),
    MIN(CASE WHEN rn=2 THEN order_id END),
    MIN(CASE WHEN rn=3 THEN order_id END),
    'max_len=' || MAX(LENGTH(order_id)), 'OK'
FROM (SELECT order_id, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM orders WHERE order_id IS NOT NULL) x

UNION ALL
SELECT 'orders', 'order_status', 'TEXT', 1,
    SUM(CASE WHEN order_status IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT order_status),
    MIN(order_status), MAX(order_status),
    MIN(CASE WHEN rn=1 THEN order_status END),
    MIN(CASE WHEN rn=2 THEN order_status END),
    MIN(CASE WHEN rn=3 THEN order_status END),
    'max_len=' || MAX(LENGTH(order_status)), 'OK'
FROM (SELECT order_status, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM orders WHERE order_status IS NOT NULL) x

UNION ALL
SELECT 'orders', 'order_purchase_timestamp', 'TEXT', 1,
    SUM(CASE WHEN order_purchase_timestamp IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT order_purchase_timestamp),
    MIN(order_purchase_timestamp), MAX(order_purchase_timestamp),
    MIN(CASE WHEN rn=1 THEN order_purchase_timestamp END),
    MIN(CASE WHEN rn=2 THEN order_purchase_timestamp END),
    MIN(CASE WHEN rn=3 THEN order_purchase_timestamp END),
    'range_days=' || CAST(JULIANDAY(MAX(order_purchase_timestamp)) - JULIANDAY(MIN(order_purchase_timestamp)) AS INTEGER),
    'OK'
FROM (SELECT order_purchase_timestamp, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM orders WHERE order_purchase_timestamp IS NOT NULL) x

UNION ALL
SELECT 'orders', 'order_delivered_customer_date', 'TEXT', 1,
    SUM(CASE WHEN order_delivered_customer_date IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT order_delivered_customer_date),
    MIN(order_delivered_customer_date), MAX(order_delivered_customer_date),
    MIN(CASE WHEN rn=1 THEN order_delivered_customer_date END),
    MIN(CASE WHEN rn=2 THEN order_delivered_customer_date END),
    MIN(CASE WHEN rn=3 THEN order_delivered_customer_date END),
    'range_days=' || CAST(JULIANDAY(MAX(order_delivered_customer_date)) - JULIANDAY(MIN(order_delivered_customer_date)) AS INTEGER),
    'OK'
FROM (SELECT order_delivered_customer_date, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM orders WHERE order_delivered_customer_date IS NOT NULL) x

UNION ALL
SELECT 'orders', 'order_estimated_delivery_date', 'TEXT', 1,
    SUM(CASE WHEN order_estimated_delivery_date IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT order_estimated_delivery_date),
    MIN(order_estimated_delivery_date), MAX(order_estimated_delivery_date),
    MIN(CASE WHEN rn=1 THEN order_estimated_delivery_date END),
    MIN(CASE WHEN rn=2 THEN order_estimated_delivery_date END),
    MIN(CASE WHEN rn=3 THEN order_estimated_delivery_date END),
    'range_days=' || CAST(JULIANDAY(MAX(order_estimated_delivery_date)) - JULIANDAY(MIN(order_estimated_delivery_date)) AS INTEGER),
    'OK'
FROM (SELECT order_estimated_delivery_date, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM orders WHERE order_estimated_delivery_date IS NOT NULL) x

-- order_items
UNION ALL
SELECT 'order_items', 'order_id', 'TEXT', 0,
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT order_id),
    MIN(order_id), MAX(order_id),
    MIN(CASE WHEN rn=1 THEN order_id END),
    MIN(CASE WHEN rn=2 THEN order_id END),
    MIN(CASE WHEN rn=3 THEN order_id END),
    'max_len=' || MAX(LENGTH(order_id)), 'OK'
FROM (SELECT order_id, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM order_items WHERE order_id IS NOT NULL) x

UNION ALL
SELECT 'order_items', 'order_item_id', 'INTEGER', 0,
    SUM(CASE WHEN order_item_id IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT order_item_id),
    CAST(MIN(order_item_id) AS TEXT), CAST(MAX(order_item_id) AS TEXT),
    MIN(CASE WHEN rn=1 THEN CAST(order_item_id AS TEXT) END),
    MIN(CASE WHEN rn=2 THEN CAST(order_item_id AS TEXT) END),
    MIN(CASE WHEN rn=3 THEN CAST(order_item_id AS TEXT) END),
    'avg=' || CAST(ROUND(AVG(CAST(order_item_id AS REAL)), 4) AS TEXT), 'OK'
FROM (SELECT order_item_id, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM order_items WHERE order_item_id IS NOT NULL) x

UNION ALL
SELECT 'order_items', 'price', 'REAL', 1,
    SUM(CASE WHEN price IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT price),
    CAST(MIN(price) AS TEXT), CAST(MAX(price) AS TEXT),
    MIN(CASE WHEN rn=1 THEN CAST(price AS TEXT) END),
    MIN(CASE WHEN rn=2 THEN CAST(price AS TEXT) END),
    MIN(CASE WHEN rn=3 THEN CAST(price AS TEXT) END),
    'avg=' || CAST(ROUND(AVG(price), 4) AS TEXT), 'OK'
FROM (SELECT price, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM order_items WHERE price IS NOT NULL) x

UNION ALL
SELECT 'order_items', 'freight_value', 'REAL', 1,
    SUM(CASE WHEN freight_value IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT freight_value),
    CAST(MIN(freight_value) AS TEXT), CAST(MAX(freight_value) AS TEXT),
    MIN(CASE WHEN rn=1 THEN CAST(freight_value AS TEXT) END),
    MIN(CASE WHEN rn=2 THEN CAST(freight_value AS TEXT) END),
    MIN(CASE WHEN rn=3 THEN CAST(freight_value AS TEXT) END),
    'avg=' || CAST(ROUND(AVG(freight_value), 4) AS TEXT), 'OK'
FROM (SELECT freight_value, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM order_items WHERE freight_value IS NOT NULL) x

-- order_payments
UNION ALL
SELECT 'order_payments', 'order_id', 'TEXT', 0,
    SUM(CASE WHEN order_id IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT order_id),
    MIN(order_id), MAX(order_id),
    MIN(CASE WHEN rn=1 THEN order_id END),
    MIN(CASE WHEN rn=2 THEN order_id END),
    MIN(CASE WHEN rn=3 THEN order_id END),
    'max_len=' || MAX(LENGTH(order_id)), 'OK'
FROM (SELECT order_id, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM order_payments WHERE order_id IS NOT NULL) x

UNION ALL
SELECT 'order_payments', 'payment_type', 'TEXT', 1,
    SUM(CASE WHEN payment_type IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT payment_type),
    MIN(payment_type), MAX(payment_type),
    MIN(CASE WHEN rn=1 THEN payment_type END),
    MIN(CASE WHEN rn=2 THEN payment_type END),
    MIN(CASE WHEN rn=3 THEN payment_type END),
    'max_len=' || MAX(LENGTH(payment_type)), 'OK'
FROM (SELECT payment_type, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM order_payments WHERE payment_type IS NOT NULL) x

UNION ALL
SELECT 'order_payments', 'payment_installments', 'INTEGER', 1,
    SUM(CASE WHEN payment_installments IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT payment_installments),
    CAST(MIN(payment_installments) AS TEXT), CAST(MAX(payment_installments) AS TEXT),
    MIN(CASE WHEN rn=1 THEN CAST(payment_installments AS TEXT) END),
    MIN(CASE WHEN rn=2 THEN CAST(payment_installments AS TEXT) END),
    MIN(CASE WHEN rn=3 THEN CAST(payment_installments AS TEXT) END),
    'avg=' || CAST(ROUND(AVG(CAST(payment_installments AS REAL)), 4) AS TEXT), 'OK'
FROM (SELECT payment_installments, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM order_payments WHERE payment_installments IS NOT NULL) x

UNION ALL
SELECT 'order_payments', 'payment_value', 'REAL', 1,
    SUM(CASE WHEN payment_value IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT payment_value),
    CAST(MIN(payment_value) AS TEXT), CAST(MAX(payment_value) AS TEXT),
    MIN(CASE WHEN rn=1 THEN CAST(payment_value AS TEXT) END),
    MIN(CASE WHEN rn=2 THEN CAST(payment_value AS TEXT) END),
    MIN(CASE WHEN rn=3 THEN CAST(payment_value AS TEXT) END),
    'avg=' || CAST(ROUND(AVG(payment_value), 4) AS TEXT), 'OK'
FROM (SELECT payment_value, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM order_payments WHERE payment_value IS NOT NULL) x

-- order_reviews
UNION ALL
SELECT 'order_reviews', 'review_id', 'TEXT', 1,
    SUM(CASE WHEN review_id IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT review_id),
    MIN(review_id), MAX(review_id),
    MIN(CASE WHEN rn=1 THEN review_id END),
    MIN(CASE WHEN rn=2 THEN review_id END),
    MIN(CASE WHEN rn=3 THEN review_id END),
    'max_len=' || MAX(LENGTH(review_id)), 'OK'
FROM (SELECT review_id, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM order_reviews WHERE review_id IS NOT NULL) x

UNION ALL
SELECT 'order_reviews', 'review_score', 'INTEGER', 1,
    SUM(CASE WHEN review_score IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT review_score),
    CAST(MIN(review_score) AS TEXT), CAST(MAX(review_score) AS TEXT),
    MIN(CASE WHEN rn=1 THEN CAST(review_score AS TEXT) END),
    MIN(CASE WHEN rn=2 THEN CAST(review_score AS TEXT) END),
    MIN(CASE WHEN rn=3 THEN CAST(review_score AS TEXT) END),
    'avg=' || CAST(ROUND(AVG(CAST(review_score AS REAL)), 4) AS TEXT), 'OK'
FROM (SELECT review_score, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM order_reviews WHERE review_score IS NOT NULL) x

-- geolocation
UNION ALL
SELECT 'geolocation', 'geolocation_zip_code_prefix', 'INTEGER', 1,
    SUM(CASE WHEN geolocation_zip_code_prefix IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT geolocation_zip_code_prefix),
    CAST(MIN(geolocation_zip_code_prefix) AS TEXT), CAST(MAX(geolocation_zip_code_prefix) AS TEXT),
    MIN(CASE WHEN rn=1 THEN CAST(geolocation_zip_code_prefix AS TEXT) END),
    MIN(CASE WHEN rn=2 THEN CAST(geolocation_zip_code_prefix AS TEXT) END),
    MIN(CASE WHEN rn=3 THEN CAST(geolocation_zip_code_prefix AS TEXT) END),
    'avg=' || CAST(ROUND(AVG(CAST(geolocation_zip_code_prefix AS REAL)), 4) AS TEXT), 'OK'
FROM (SELECT geolocation_zip_code_prefix, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM geolocation WHERE geolocation_zip_code_prefix IS NOT NULL) x

UNION ALL
SELECT 'geolocation', 'geolocation_lat', 'REAL', 1,
    SUM(CASE WHEN geolocation_lat IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT geolocation_lat),
    CAST(MIN(geolocation_lat) AS TEXT), CAST(MAX(geolocation_lat) AS TEXT),
    MIN(CASE WHEN rn=1 THEN CAST(geolocation_lat AS TEXT) END),
    MIN(CASE WHEN rn=2 THEN CAST(geolocation_lat AS TEXT) END),
    MIN(CASE WHEN rn=3 THEN CAST(geolocation_lat AS TEXT) END),
    'avg=' || CAST(ROUND(AVG(geolocation_lat), 4) AS TEXT), 'OK'
FROM (SELECT geolocation_lat, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM geolocation WHERE geolocation_lat IS NOT NULL) x

UNION ALL
SELECT 'geolocation', 'geolocation_lng', 'REAL', 1,
    SUM(CASE WHEN geolocation_lng IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT geolocation_lng),
    CAST(MIN(geolocation_lng) AS TEXT), CAST(MAX(geolocation_lng) AS TEXT),
    MIN(CASE WHEN rn=1 THEN CAST(geolocation_lng AS TEXT) END),
    MIN(CASE WHEN rn=2 THEN CAST(geolocation_lng AS TEXT) END),
    MIN(CASE WHEN rn=3 THEN CAST(geolocation_lng AS TEXT) END),
    'avg=' || CAST(ROUND(AVG(geolocation_lng), 4) AS TEXT), 'OK'
FROM (SELECT geolocation_lng, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM geolocation WHERE geolocation_lng IS NOT NULL) x

-- leads_qualified
UNION ALL
SELECT 'leads_qualified', 'mql_id', 'TEXT', 0,
    SUM(CASE WHEN mql_id IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT mql_id),
    MIN(mql_id), MAX(mql_id),
    MIN(CASE WHEN rn=1 THEN mql_id END),
    MIN(CASE WHEN rn=2 THEN mql_id END),
    MIN(CASE WHEN rn=3 THEN mql_id END),
    'max_len=' || MAX(LENGTH(mql_id)), 'OK'
FROM (SELECT mql_id, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM leads_qualified WHERE mql_id IS NOT NULL) x

UNION ALL
SELECT 'leads_qualified', 'origin', 'TEXT', 1,
    SUM(CASE WHEN origin IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT origin),
    MIN(origin), MAX(origin),
    MIN(CASE WHEN rn=1 THEN origin END),
    MIN(CASE WHEN rn=2 THEN origin END),
    MIN(CASE WHEN rn=3 THEN origin END),
    'max_len=' || MAX(LENGTH(origin)), 'OK'
FROM (SELECT origin, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM leads_qualified WHERE origin IS NOT NULL) x

-- leads_closed
UNION ALL
SELECT 'leads_closed', 'mql_id', 'TEXT', 0,
    SUM(CASE WHEN mql_id IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT mql_id),
    MIN(mql_id), MAX(mql_id),
    MIN(CASE WHEN rn=1 THEN mql_id END),
    MIN(CASE WHEN rn=2 THEN mql_id END),
    MIN(CASE WHEN rn=3 THEN mql_id END),
    'max_len=' || MAX(LENGTH(mql_id)), 'OK'
FROM (SELECT mql_id, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM leads_closed WHERE mql_id IS NOT NULL) x

UNION ALL
SELECT 'leads_closed', 'declared_monthly_revenue', 'REAL', 1,
    SUM(CASE WHEN declared_monthly_revenue IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT declared_monthly_revenue),
    CAST(MIN(declared_monthly_revenue) AS TEXT), CAST(MAX(declared_monthly_revenue) AS TEXT),
    MIN(CASE WHEN rn=1 THEN CAST(declared_monthly_revenue AS TEXT) END),
    MIN(CASE WHEN rn=2 THEN CAST(declared_monthly_revenue AS TEXT) END),
    MIN(CASE WHEN rn=3 THEN CAST(declared_monthly_revenue AS TEXT) END),
    'avg=' || CAST(ROUND(AVG(declared_monthly_revenue), 4) AS TEXT), 'OK'
FROM (SELECT declared_monthly_revenue, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM leads_closed WHERE declared_monthly_revenue IS NOT NULL) x

-- product_category_name_translation
UNION ALL
SELECT 'product_category_name_translation', 'product_category_name', 'TEXT', 0,
    SUM(CASE WHEN product_category_name IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT product_category_name),
    MIN(product_category_name), MAX(product_category_name),
    MIN(CASE WHEN rn=1 THEN product_category_name END),
    MIN(CASE WHEN rn=2 THEN product_category_name END),
    MIN(CASE WHEN rn=3 THEN product_category_name END),
    'max_len=' || MAX(LENGTH(product_category_name)), 'OK'
FROM (SELECT product_category_name, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM product_category_name_translation WHERE product_category_name IS NOT NULL) x

UNION ALL
SELECT 'product_category_name_translation', 'product_category_name_english', 'TEXT', 1,
    SUM(CASE WHEN product_category_name_english IS NULL THEN 1 ELSE 0 END),
    COUNT(DISTINCT product_category_name_english),
    MIN(product_category_name_english), MAX(product_category_name_english),
    MIN(CASE WHEN rn=1 THEN product_category_name_english END),
    MIN(CASE WHEN rn=2 THEN product_category_name_english END),
    MIN(CASE WHEN rn=3 THEN product_category_name_english END),
    'max_len=' || MAX(LENGTH(product_category_name_english)), 'OK'
FROM (SELECT product_category_name_english, ROW_NUMBER() OVER (ORDER BY rowid) AS rn FROM product_category_name_translation WHERE product_category_name_english IS NOT NULL) x

ORDER BY table_name, column_name;
