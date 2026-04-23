-- ============================================================
-- 02_queries_michael.sql
-- Author: Michael Amaya
-- Theme:  Customer & Delivery Behavior
-- ============================================================

-- Q05: How often are orders delivered on time versus late?
SELECT 
    CASE 
        WHEN order_delivered_customer_date <= order_estimated_delivery_date THEN 'On Time'
        WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 'Late'
        ELSE 'Not Delivered Yet' 
    END AS DeliveryStatus,
    COUNT(*) AS OrderCount,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(10,2)) AS Percentage
FROM orders
WHERE order_status = 'delivered'
GROUP BY 
    CASE 
        WHEN order_delivered_customer_date <= order_estimated_delivery_date THEN 'On Time'
        WHEN order_delivered_customer_date > order_estimated_delivery_date THEN 'Late'
        ELSE 'Not Delivered Yet' 
    END;

-- Q06: What is the distribution of customer review scores (1–5)?
SELECT 
    review_score AS ReviewScore,
    COUNT(*) AS TotalReviews, 
    REPLICATE(N'★', review_score) AS RatingLabel,
    CAST(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER() AS DECIMAL(5,2)) AS Percentage
FROM order_reviews
GROUP BY review_score
ORDER BY review_score DESC;

-- Q07: How many customers have placed more than one order?
SELECT 
    FORMAT(o.order_purchase_timestamp, 'yyyy-MM') AS OrderMonth,
    COUNT(DISTINCT c.customer_unique_id) AS TotalCustomers,
    COUNT(DISTINCT CASE 
        WHEN Repeats.customer_unique_id IS NOT NULL THEN c.customer_unique_id 
    END) AS RepeatCustomers
FROM Customers c
JOIN orders o ON c.customer_id = o.customer_id
LEFT JOIN (
    SELECT c2.customer_unique_id
    FROM Customers c2
    JOIN orders o2 ON c2.customer_id = o2.customer_id
    GROUP BY c2.customer_unique_id
    HAVING COUNT(o2.order_id) > 1
) AS Repeats ON c.customer_unique_id = Repeats.customer_unique_id
WHERE o.order_purchase_timestamp >= '2017-01-01'
  AND o.order_purchase_timestamp < '2018-09-01'
GROUP BY FORMAT(o.order_purchase_timestamp, 'yyyy-MM')
ORDER BY OrderMonth;

-- Q08: What is the breakdown of all orders by their current status?
SELECT 
    order_status, 
    COUNT(*) AS TotalOrders
FROM orders
WHERE order_status != 'delivered'
GROUP BY order_status
ORDER BY TotalOrders DESC;
