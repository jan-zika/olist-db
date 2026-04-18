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
    review_score, 
    COUNT(*) AS TotalReviews,
    REPLICATE(N'★', review_score) AS Stars
FROM order_reviews
GROUP BY review_score
ORDER BY review_score DESC;

-- Q07: How many customers have placed more than one order?
SELECT COUNT(*) AS RepeatCustomerCount
FROM (
    SELECT c.customer_unique_id
    FROM Customers c
    JOIN orders o ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
    HAVING COUNT(o.order_id) > 1
) AS RepeatCustomers;

-- Q08: What is the breakdown of all orders by their current status?
SELECT 
    order_status, 
    COUNT(*) AS TotalOrders
FROM orders
GROUP BY order_status
ORDER BY TotalOrders DESC;
