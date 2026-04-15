-- ============================================================
-- 04_queries_bonus.sql
-- Author: Jan Zika
-- Theme:  Geolocation
-- ============================================================

/*
- Our real world geolocation data table has multiple rows per zip code
(same zip, slightly different lat/lng coordinates from different data
collection points).
- Since geolocation_zip_code_prefix has duplicates, it can't be a PK,
nor can any other table formally reference it via a FK.
- Also on the other side, not every customer or seller zip code is guaranteed
to exist in the geolocation table, which would cause FK violations in the
other direction too.
- This a common issue with real-world datasets: the geolocation data was
collected independently and wasn't designed to be a clean lookup table.
We will address this issue in vw_geo view by using AVG(lat/lng) GROUP BY zip
in order to collapse the duplicates into one usable coordinate per zip
before joining.
*/

-- ------------------------------------------------------------
-- View: vw_geo
-- Junction view: resolves lat/lng for every order (customer + seller)
--
-- Deduplicates geolocation once (AVG per zip) and joins to both
-- customers and sellers via zip code prefix. Any analytical query
-- needing coordinates just joins this view on order_id — no need
-- to repeat the deduplication logic.
--
-- Columns available for downstream queries:
--   order_id, freight_value, order_status
--   customer_state, customer_lat, customer_lng
--   seller_state,   seller_lat,   seller_lng
--   distance_km  (Euclidean approx, sufficient for correlation analysis)
--
-- Example uses:
--   - Freight cost vs distance
--   - Late deliveries vs distance
--   - Average order value by region
--   - Seller-to-customer state flow

GO

CREATE OR ALTER VIEW vw_geo AS
WITH geo AS (
    SELECT
        geolocation_zip_code_prefix,
        AVG(geolocation_lat) AS lat,
        AVG(geolocation_lng) AS lng
    FROM geolocation
    GROUP BY geolocation_zip_code_prefix
)
SELECT
    o.order_id,
    o.order_status,
    oi.freight_value,
    c.customer_state,
    gc.lat                                    AS customer_lat,
    gc.lng                                    AS customer_lng,
    s.seller_state,
    gs.lat                                    AS seller_lat,
    gs.lng                                    AS seller_lng,
    SQRT(
        POWER((gc.lat - gs.lat) * 111.0, 2) +
        POWER((gc.lng - gs.lng) * 111.0, 2)
    )                                         AS distance_km
FROM orders o
JOIN order_items oi ON oi.order_id   = o.order_id
JOIN customers c    ON c.customer_id = o.customer_id
JOIN sellers s      ON s.seller_id   = oi.seller_id
JOIN geo gc         ON gc.geolocation_zip_code_prefix = c.customer_zip_code_prefix
JOIN geo gs         ON gs.geolocation_zip_code_prefix = s.seller_zip_code_prefix;
GO

-- ------------------------------------------------------------
-- Example query using the vw_geo view
-- BONUS QUERY: Which seller-to-customer city routes handle the most orders?
-- More granular than state-level — reveals which specific cities
-- are supply hubs vs. demand hubs across Brazil.

SELECT TOP 10
    s.seller_city   + ' (' + g.seller_state   + ')' +
    ' -> ' +
    c.customer_city + ' (' + g.customer_state + ')'   AS route,
    COUNT(*)                                          AS order_count,
    CAST(AVG(g.distance_km)          AS DECIMAL(10,1)) AS avg_distance_km,
    CAST(AVG(g.distance_km) * 0.6214 AS DECIMAL(10,1)) AS avg_distance_mi,
    CAST(AVG(g.freight_value) AS DECIMAL(10,2))       AS avg_freight_value
FROM vw_geo g
JOIN order_items oi ON oi.order_id   = g.order_id
JOIN sellers s      ON s.seller_id   = oi.seller_id
JOIN orders o       ON o.order_id    = g.order_id
JOIN customers c    ON c.customer_id = o.customer_id
WHERE g.order_status = 'delivered'
GROUP BY s.seller_city, g.seller_state, c.customer_city, g.customer_state
ORDER BY order_count DESC;