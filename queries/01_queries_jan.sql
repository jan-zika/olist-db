-- ============================================================
-- 01_queries_jan.sql
-- Author: Jan Zika
-- Theme:  Sales & Revenue
-- ============================================================

-- ------------------------------------------------------------
-- About the database:
-- Brazilian e-commerce marketplace (Olist)

-- Table names with row count and total
SELECT
    COALESCE(t.TABLE_NAME, 'TOTAL') AS table_name,
    SUM(p.rows)                     AS row_count
FROM INFORMATION_SCHEMA.TABLES t
JOIN sys.tables     st ON st.name      = t.TABLE_NAME
JOIN sys.partitions p  ON p.object_id  = st.object_id AND p.index_id IN (0, 1)
WHERE t.TABLE_TYPE = 'BASE TABLE'
  AND t.TABLE_NAME != 'sysdiagrams'
GROUP BY ROLLUP(t.TABLE_NAME)
ORDER BY GROUPING(t.TABLE_NAME), t.TABLE_NAME;

-- Order data time span (by order_purchase_timestamp), broken down by order status
-- 'delivered (trimmed)' excludes months with fewer than 300 orders (cold-start / cut-off)
WITH monthly_delivered AS (
    SELECT
        YEAR(order_purchase_timestamp)  AS yr,
        MONTH(order_purchase_timestamp) AS mo,
        COUNT(*)                        AS order_count
    FROM orders
    WHERE order_status = 'delivered'
    GROUP BY YEAR(order_purchase_timestamp), MONTH(order_purchase_timestamp)
),
trimmed AS (
    SELECT yr, mo
    FROM monthly_delivered
    WHERE order_count >= 300
)
SELECT
    order_status,
    COUNT(*)                                                                           AS order_count,
    CAST(MIN(order_purchase_timestamp) AS DATE)                                        AS first_order,
    CAST(MAX(order_purchase_timestamp) AS DATE)                                        AS last_order,
    DATEDIFF(MONTH, MIN(order_purchase_timestamp), MAX(order_purchase_timestamp)) / 12 AS span_years,
    DATEDIFF(MONTH, MIN(order_purchase_timestamp), MAX(order_purchase_timestamp)) % 12 AS span_months
FROM orders
GROUP BY order_status

UNION ALL

SELECT
    'delivered (trimmed)'                                                              AS order_status,
    COUNT(*)                                                                           AS order_count,
    CAST(MIN(o.order_purchase_timestamp) AS DATE)                                      AS first_order,
    CAST(MAX(o.order_purchase_timestamp) AS DATE)                                      AS last_order,
    DATEDIFF(MONTH, MIN(o.order_purchase_timestamp), MAX(o.order_purchase_timestamp)) / 12 AS span_years,
    DATEDIFF(MONTH, MIN(o.order_purchase_timestamp), MAX(o.order_purchase_timestamp)) % 12 AS span_months
FROM orders o
JOIN trimmed t ON t.yr = YEAR(o.order_purchase_timestamp)
              AND t.mo = MONTH(o.order_purchase_timestamp)
WHERE o.order_status = 'delivered'

ORDER BY order_count DESC;


-- ------------------------------------------------------------
-- Q01: How has total revenue changed month by month over 2017–2018?

-- VIEW used for Q01: vw_revenue_growth
-- Monthly revenue with MoM and cumulative growth (Jan 2017 – Aug 2018, delivered orders only)
GO

CREATE OR ALTER VIEW vw_revenue_growth AS
WITH monthly AS (
    SELECT
        YEAR(o.order_purchase_timestamp)  AS order_year,
        MONTH(o.order_purchase_timestamp) AS order_month,
        COUNT(DISTINCT o.order_id)        AS order_count,
        SUM(oi.price + oi.freight_value)  AS total_revenue
    FROM orders o
    JOIN order_items oi ON oi.order_id = o.order_id
    WHERE o.order_status = 'delivered'
      AND o.order_purchase_timestamp >= '2017-01-01'
      AND o.order_purchase_timestamp  < '2018-09-01'
    GROUP BY
        YEAR(o.order_purchase_timestamp),
        MONTH(o.order_purchase_timestamp)
)
SELECT
    order_year,
    order_month,
    order_count,
    CAST(total_revenue AS DECIMAL(12,2)) AS total_revenue,
    CAST(
        (total_revenue - LAG(total_revenue) OVER (ORDER BY order_year, order_month))
        * 100.0
        / NULLIF(LAG(total_revenue) OVER (ORDER BY order_year, order_month), 0)
    AS DECIMAL(5,1)) AS mom_growth_pct,
    CAST(
        (total_revenue - FIRST_VALUE(total_revenue) OVER (ORDER BY order_year, order_month))
        * 100.0
        / NULLIF(FIRST_VALUE(total_revenue) OVER (ORDER BY order_year, order_month), 0)
    AS DECIMAL(7,1)) AS cumulative_growth_pct
FROM monthly;
GO

-- Q01a: monthly detail (use this for charts)
SELECT order_year, order_month, order_count, total_revenue, mom_growth_pct, cumulative_growth_pct
FROM vw_revenue_growth
ORDER BY order_year, order_month;

-- Q01b: summary statistics
SELECT
    'Minimum' AS stat,
    CAST(MIN(CAST(order_count AS FLOAT)) AS DECIMAL(10,0)) AS order_count,
    CAST(MIN(total_revenue)              AS DECIMAL(12,2)) AS total_revenue,
    CAST(MIN(mom_growth_pct)             AS DECIMAL(5,1))  AS mom_growth_pct,
    CAST(MIN(cumulative_growth_pct)      AS DECIMAL(7,1))  AS cumulative_growth_pct
FROM vw_revenue_growth
UNION ALL
SELECT
    'Maximum',
    CAST(MAX(CAST(order_count AS FLOAT)) AS DECIMAL(10,0)),
    CAST(MAX(total_revenue)              AS DECIMAL(12,2)),
    CAST(MAX(mom_growth_pct)             AS DECIMAL(5,1)),
    CAST(MAX(cumulative_growth_pct)      AS DECIMAL(7,1))
FROM vw_revenue_growth
UNION ALL
SELECT
    'Average',
    CAST(AVG(CAST(order_count AS FLOAT)) AS DECIMAL(10,0)),
    CAST(AVG(total_revenue)              AS DECIMAL(12,2)),
    CAST(AVG(mom_growth_pct)             AS DECIMAL(5,1)),
    CAST(AVG(cumulative_growth_pct)      AS DECIMAL(7,1))
FROM vw_revenue_growth;


-- ------------------------------------------------------------
-- Q02: Which payment methods are most popular,
-- and what is the average number of installments for each?

-- VIEW used for Q02: vw_payment_method_breakdown
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

-- View usage
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
-- Top 10 states with at least 100 delivered orders, ranked by average order value
EXEC sp_avg_order_value_by_state;

-- call with a stricter minimum order threshold (min_orders=500)
-- Top 10 states with at least 500 delivered orders, ranked by average order value
EXEC sp_avg_order_value_by_state @min_orders = 500;

-- call with a stricter minimum order threshold (min_orders=500) and show up to 15 states
-- Top 15 states with at least 500 delivered orders, ranked by average order value
EXEC sp_avg_order_value_by_state @min_orders = 500, @top_n = 15;

-- call with no minimum order threshold (include all states with at least 1 order)
-- All 27 states with at least 1 delivered order, ranked by average order value
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