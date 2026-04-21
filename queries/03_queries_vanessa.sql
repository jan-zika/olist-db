-- ============================================================
-- 03_queries_vanessa.sql
-- Author: Vanessa Quiroz
-- Theme:  Seller & Product Performance
-- ============================================================


-- Q09: Who are the top sellers by total revenue?
-- TODO
SELECT Top 10
    oi.seller_id,
    SUM(oi.price) AS total_revenue,
    COUNT(DISTINCT oi.order_id) AS total_orders
FROM dbo.order_items oi
GROUP BY oi.seller_id
ORDER BY total_revenue DESC;

-- Q10: Which product categories receive the most orders?
-- TODO
SELECT 
    ISNULL(p.product_category_name, 'Unknown') AS Category,
    COUNT(*) AS Total_items_sold
FROM dbo.order_items oi
JOIN dbo.products p
    ON oi.product_id = p.product_id
GROUP BY p.product_category_name
ORDER BY total_items_sold DESC;

-- Q11: What does the conversion from qualified leads to closed deals look like by lead source?
-- TODO

SELECT 
    	lq.origin AS lead_source,
        	COUNT(DISTINCT lq.mql_id) AS total_leads,
    	COUNT(DISTINCT lc.mql_id) AS converted_leads,
    	COUNT(DISTINCT lq.mql_id) - COUNT(DISTINCT lc.mql_id) AS non_converted_leads,
CAST(
    COUNT(DISTINCT lc.mql_id) * 1.0 
    / NULLIF(COUNT(DISTINCT lq.mql_id), 0)
    AS DECIMAL(5,2)
) AS conversion_rateFROM leads_qualified lq
LEFT JOIN leads_closed lc
    ON lq.mql_id = lc.mql_id
GROUP BY lq.origin
ORDER BY conversion_rate DESC;


-- Q12: Is there a relationship between product weight and freight cost?
-- TODO

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

