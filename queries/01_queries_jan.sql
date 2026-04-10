-- ============================================================
-- 01_queries_jan.sql
-- Author: Jan Zika
-- Theme:  Sales & Revenue
-- ============================================================

-- ------------------------------------------------------------
-- About the database:
-- Brazilian e-commerce marketplace (Olist)

-- Table count
SELECT COUNT(*) AS table_count
FROM INFORMATION_SCHEMA.TABLES
WHERE TABLE_TYPE = 'BASE TABLE';

-- Row count per table and overall total
SELECT
    GROUPING(table_name) AS is_total,
    COALESCE(table_name, 'TOTAL') AS table_name,
    SUM(row_count)                AS row_count
FROM (VALUES
    ('customers',                         (SELECT COUNT(*) FROM customers)),
    ('sellers',                           (SELECT COUNT(*) FROM sellers)),
    ('products',                          (SELECT COUNT(*) FROM products)),
    ('orders',                            (SELECT COUNT(*) FROM orders)),
    ('order_items',                       (SELECT COUNT(*) FROM order_items)),
    ('order_payments',                    (SELECT COUNT(*) FROM order_payments)),
    ('order_reviews',                     (SELECT COUNT(*) FROM order_reviews)),
    ('geolocation',                       (SELECT COUNT(*) FROM geolocation)),
    ('leads_qualified',                   (SELECT COUNT(*) FROM leads_qualified)),
    ('leads_closed',                      (SELECT COUNT(*) FROM leads_closed)),
    ('product_category_name_translation', (SELECT COUNT(*) FROM product_category_name_translation))
) AS t(table_name, row_count)
GROUP BY ROLLUP(table_name)
ORDER BY is_total, table_name;

-- Data time span (by order_purchase_timestamp)
SELECT
    CAST(MIN(order_purchase_timestamp) AS DATE) AS first_order,
    CAST(MAX(order_purchase_timestamp) AS DATE) AS last_order,
    DATEDIFF(YEAR,  MIN(order_purchase_timestamp), MAX(order_purchase_timestamp))      AS span_years,
    DATEDIFF(MONTH, MIN(order_purchase_timestamp), MAX(order_purchase_timestamp)) % 12 AS span_months
FROM orders;


-- ------------------------------------------------------------
-- Q01: How has total revenue changed month by month over 2016–2018?
SELECT
    YEAR(o.order_purchase_timestamp)   AS order_year,
    MONTH(o.order_purchase_timestamp)  AS order_month,
    COUNT(DISTINCT o.order_id)         AS order_count,
    SUM(oi.price + oi.freight_value)   AS total_revenue
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY
    YEAR(o.order_purchase_timestamp),
    MONTH(o.order_purchase_timestamp)
ORDER BY order_year, order_month;

-- ------------------------------------------------------------
-- Q02: Which payment methods are most popular,
-- and what is the average number of installments for each?
SELECT
    payment_type,
    COUNT(DISTINCT order_id)                                       AS order_count,
    CAST(AVG(CAST(payment_installments AS FLOAT)) AS DECIMAL(4,1)) AS avg_installments,
    SUM(payment_value)                                             AS total_revenue
FROM order_payments
WHERE payment_type IS NOT NULL
GROUP BY payment_type
ORDER BY order_count DESC;

-- ------------------------------------------------------------
-- VIEW based on Q02: vw_payment_method_breakdown
--
-- Aggregates all payment records by payment type.
-- Returns order count, average installments, and total revenue
-- per payment method across the full dataset.

GO

CREATE OR ALTER VIEW vw_payment_method_breakdown AS
SELECT
    payment_type,
    COUNT(DISTINCT order_id)                                       AS order_count,
    CAST(AVG(CAST(payment_installments AS FLOAT)) AS DECIMAL(4,1)) AS avg_installments,
    SUM(payment_value)                                             AS total_revenue
FROM order_payments
WHERE payment_type IS NOT NULL
GROUP BY payment_type;
GO

-- View usage example
SELECT * FROM vw_payment_method_breakdown ORDER BY order_count DESC;

-- ------------------------------------------------------------
-- Q03: Which Brazilian states have the highest average order value?
DECLARE @min_orders INT = 100;

-- using a CTE to map state codes to state names for better readability in the results (optional but helpful)
WITH state_names AS (
    SELECT * FROM (VALUES
        ('AC', 'Acre'),              ('AL', 'Alagoas'),
        ('AM', 'Amazonas'),          ('AP', 'Amapa'),
        ('BA', 'Bahia'),             ('CE', 'Ceara'),
        ('DF', 'Distrito Federal'),  ('ES', 'Espirito Santo'),
        ('GO', 'Goias'),             ('MA', 'Maranhao'),
        ('MG', 'Minas Gerais'),      ('MS', 'Mato Grosso do Sul'),
        ('MT', 'Mato Grosso'),       ('PA', 'Para'),
        ('PB', 'Paraiba'),           ('PE', 'Pernambuco'),
        ('PI', 'Piaui'),             ('PR', 'Parana'),
        ('RJ', 'Rio de Janeiro'),    ('RN', 'Rio Grande do Norte'),
        ('RO', 'Rondonia'),          ('RR', 'Roraima'),
        ('RS', 'Rio Grande do Sul'), ('SC', 'Santa Catarina'),
        ('SE', 'Sergipe'),           ('SP', 'Sao Paulo'),
        ('TO', 'Tocantins')
    ) AS t(state_code, state_name)
)
SELECT TOP 10
    c.customer_state,
    sn.state_name,
    COUNT(DISTINCT o.order_id)                              AS order_count,
    CAST(AVG(oi.price)                   AS DECIMAL(10,2))  AS avg_product_value,
    CAST(AVG(oi.freight_value)           AS DECIMAL(10,2))  AS avg_freight_value,
    CAST(AVG(oi.price + oi.freight_value) AS DECIMAL(10,2)) AS avg_order_value
FROM orders o
JOIN customers c    ON c.customer_id  = o.customer_id
JOIN order_items oi ON oi.order_id    = o.order_id
JOIN state_names sn ON sn.state_code  = c.customer_state
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state, sn.state_name
HAVING COUNT(DISTINCT o.order_id) >= @min_orders
ORDER BY avg_order_value DESC;

-- ------------------------------------------------------------
-- STORED PROCEDURE based on Q03: sp_avg_order_value_by_state
--
-- Returns the top N Brazilian states ranked by average order value
-- for delivered orders.
--
-- Parameters:
--   @min_orders INT = 100   Minimum delivered orders a state must have.
--                           Pass NULL to include all states with at least 1 order.
--   @top_n      INT = 10    Number of states to return.
--                           Pass NULL to return all states that meet the minimum order threshold.
--
-- IF/ELSE:
--   NULL threshold     -> @effective_min = 1 (include all states with at least 1 order).
--   Non-NULL threshold -> @effective_min = @min_orders (filter low-volume states).
--   NULL top states     -> @top_n = 27 (show all 27 states in the results).
--   Non-NULL top states -> @top_n = @top_n (show only the specified number of top states).

GO

CREATE OR ALTER PROCEDURE sp_avg_order_value_by_state
    @min_orders INT = 100,
    @top_n      INT = 10
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @effective_min INT;

    IF @min_orders IS NULL
        SET @effective_min = 1; -- threshold NULL: include all states with at least 1 order
    ELSE
        SET @effective_min = @min_orders;

    IF @top_n IS NULL
        SET @top_n = 27; -- number of states NULL: show all 27 states in the results

    WITH state_names AS (
        SELECT * FROM (VALUES
            ('AC', 'Acre'),              ('AL', 'Alagoas'),
            ('AM', 'Amazonas'),          ('AP', 'Amapa'),
            ('BA', 'Bahia'),             ('CE', 'Ceara'),
            ('DF', 'Distrito Federal'),  ('ES', 'Espirito Santo'),
            ('GO', 'Goias'),             ('MA', 'Maranhao'),
            ('MG', 'Minas Gerais'),      ('MS', 'Mato Grosso do Sul'),
            ('MT', 'Mato Grosso'),       ('PA', 'Para'),
            ('PB', 'Paraiba'),           ('PE', 'Pernambuco'),
            ('PI', 'Piaui'),             ('PR', 'Parana'),
            ('RJ', 'Rio de Janeiro'),    ('RN', 'Rio Grande do Norte'),
            ('RO', 'Rondonia'),          ('RR', 'Roraima'),
            ('RS', 'Rio Grande do Sul'), ('SC', 'Santa Catarina'),
            ('SE', 'Sergipe'),           ('SP', 'Sao Paulo'),
            ('TO', 'Tocantins')
        ) AS t(state_code, state_name)
    )
    SELECT TOP (@top_n)
        c.customer_state,
        sn.state_name,
        COUNT(DISTINCT o.order_id)                               AS order_count,
        CAST(AVG(oi.price)                    AS DECIMAL(10,2))  AS avg_product_value,
        CAST(AVG(oi.freight_value)            AS DECIMAL(10,2))  AS avg_freight_value,
        CAST(AVG(oi.price + oi.freight_value) AS DECIMAL(10,2))  AS avg_order_value
    FROM orders o
    JOIN customers c    ON c.customer_id  = o.customer_id
    JOIN order_items oi ON oi.order_id    = o.order_id
    JOIN state_names sn ON sn.state_code  = c.customer_state
    WHERE o.order_status = 'delivered'
    GROUP BY c.customer_state, sn.state_name
    HAVING COUNT(DISTINCT o.order_id) >= @effective_min
    ORDER BY avg_order_value DESC;
END;
GO

-- Stored procedure usage example:
-- call with default arguments (min_orders=100, top_n=10)
EXEC sp_avg_order_value_by_state;

-- call with a stricter minimum order threshold (min_orders=500)
EXEC sp_avg_order_value_by_state @min_orders = 500;

-- call with a stricter minimum order threshold (min_orders=500) and show up to 15 states
EXEC sp_avg_order_value_by_state @min_orders = 500, @top_n = 15;

-- call with no minimum order threshold (include all states with at least 1 order)
EXEC sp_avg_order_value_by_state @min_orders = NULL, @top_n = NULL;

-- ------------------------------------------------------------
-- Q04: Which product categories drive the most total revenue?
WITH category_revenue AS (
    SELECT
        p.product_category_name,
        SUM(oi.price + oi.freight_value) AS total_revenue
    FROM order_items oi
    JOIN products p ON p.product_id = oi.product_id
    GROUP BY p.product_category_name
)
SELECT TOP 10
    COALESCE(t.product_category_name_english, cr.product_category_name) AS category_english,
    cr.total_revenue
FROM category_revenue cr
LEFT JOIN product_category_name_translation t
    ON t.product_category_name = cr.product_category_name
ORDER BY cr.total_revenue DESC;