-- ============================================================
-- 03_queries_vanessa.sql
-- Author: Vanessa Quiroz
-- Theme:  Seller & Product Performance
-- ============================================================


-- Q09: Who are the top sellers by total revenue?
-- TODO
WITH seller_performance AS (
    SELECT 
        oi.seller_id,
        SUM(oi.price) AS total_revenue,
        COUNT(DISTINCT oi.order_id) AS total_orders,
        SUM(oi.price) * 1.0 / COUNT(DISTINCT oi.order_id) AS avg_order_value
    FROM order_items oi
    GROUP BY oi.seller_id
),
ranked_sellers AS (
    SELECT 
        seller_id,
        total_revenue,
        total_orders,
        avg_order_value,
        RANK() OVER (ORDER BY total_revenue DESC) AS Revenue_rank
    FROM seller_performance
)

SELECT 
    CONCAT('Seller ', Revenue_rank) AS Seller_Alias,
    total_revenue,
    total_orders,
    avg_order_value
FROM ranked_sellers
WHERE Revenue_rank <= 10
ORDER BY Revenue_rank ASC;


-- Q10: Which product categories are most popular by volume?
-- TODO
SELECT TOP 10
    ISNULL(p.product_category_name, 'Unknown') AS Category,

    CASE 
        WHEN p.product_category_name = 'cama_mesa_banho' THEN 'Bed, Bath & Table'
        WHEN p.product_category_name = 'beleza_saude' THEN 'Beauty & Health'
        WHEN p.product_category_name = 'esporte_lazer' THEN 'Sports & Leisure'
        WHEN p.product_category_name = 'moveis_decoracao' THEN 'Furniture & Decor'
        WHEN p.product_category_name = 'informatica_acessorios' THEN 'Computers & Accessories'
        WHEN p.product_category_name = 'utilidades_domesticas' THEN 'Home Essentials'
        WHEN p.product_category_name = 'relogios_presentes' THEN 'Watches & Gifts'
        WHEN p.product_category_name = 'telefonia' THEN 'Phone'
        WHEN p.product_category_name = 'ferramentas_jardim' THEN 'Garden Tools'
        WHEN p.product_category_name = 'automotivo' THEN 'Automotive'
        ELSE 'Unknown'
    END AS Category_English,
    COUNT(*) AS Total_items_sold
FROM order_items oi
JOIN products p
    ON oi.product_id = p.product_id
GROUP BY p.product_category_name
ORDER BY Total_items_sold DESC;

-- Q11: What does the conversion from qualified leads to closed deals look like by lead source?
-- TODO

SELECT 
    lq.origin,
    COUNT(DISTINCT lq.mql_id) AS converted_leads
FROM leads_qualified lq
INNER JOIN leads_closed lc
    ON lq.mql_id = lc.mql_id
GROUP BY lq.origin
ORDER BY converted_leads DESC;


-- Q12a: Is there a relationship between product weight and freight cost?
-- TODO
-- Aggregated in Buckets
SELECT
   CASE
       WHEN p.product_weight_g < 500 THEN '< 500 g'
       WHEN p.product_weight_g BETWEEN 500 AND 1999 THEN '500 g - 2 kg'
       WHEN p.product_weight_g BETWEEN 2000 AND 4999 THEN '2 - 5 kg'
       ELSE '5 kg +'
   END AS weight_bucket,
   COUNT(*) AS item_count,
   CAST(AVG(p.product_weight_g * 1.0) AS DECIMAL(10,0)) AS avg_weight_g,
   CAST(AVG(oi.freight_value)         AS DECIMAL(10,2)) AS avg_freight_value
FROM order_items oi
JOIN products p ON p.product_id = oi.product_id
WHERE p.product_weight_g IS NOT NULL
GROUP BY
   CASE
       WHEN p.product_weight_g < 500 THEN '< 500 g'
       WHEN p.product_weight_g BETWEEN 500 AND 1999 THEN '500 g - 2 kg'
       WHEN p.product_weight_g BETWEEN 2000 AND 4999 THEN '2 - 5 kg'
       ELSE '5 kg +'
   END
ORDER BY avg_weight_g;

-- Q12b: Is there a relationship between product weight and freight cost?
-- TODO
-- Raw relationship
SELECT 
    p.product_weight_g,
    oi.freight_value
FROM order_items oi
JOIN products p 
    ON p.product_id = oi.product_id
WHERE p.product_weight_g IS NOT NULL
  AND oi.freight_value IS NOT NULL
  ORDER BY oi.freight_value DESC;





