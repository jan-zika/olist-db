-- ============================================================
-- queries_jan.sql
-- Author: Jan Zika
-- Theme:  Sales & Revenue
-- ============================================================


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


-- Q02: Which payment methods are most popular, and what is the average number of installments for each?
SELECT
    payment_type,
    COUNT(DISTINCT order_id)                                    AS order_count,
    CAST(AVG(CAST(payment_installments AS FLOAT)) AS DECIMAL(4,1)) AS avg_installments,
    SUM(payment_value)                                          AS total_revenue
FROM order_payments
WHERE payment_type IS NOT NULL
GROUP BY payment_type
ORDER BY order_count DESC;


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
    COUNT(DISTINCT o.order_id)                               AS order_count,
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
