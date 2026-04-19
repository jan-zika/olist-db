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


-- Q11: What does the conversion from qualified leads to closed deals look like by lead source?
-- TODO


-- Q12: Is there a relationship between product weight and freight cost?
-- TODO
