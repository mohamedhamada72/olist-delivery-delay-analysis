USE Olist;
GO

-- Q6 step 2: per-seller stats
-- Assumption: in orders with several sellers, delay and review are attributed to EACH seller involved.
WITH seller_orders AS (
    SELECT
        i.seller_id,
        i.order_id,
        SUM(i.price) AS revenue
    FROM dbo.order_items i
    INNER JOIN dbo.orders_delivered o
        ON i.order_id = o.order_id
    GROUP BY i.seller_id, i.order_id
),
seller_stats AS (
    SELECT
        so.seller_id,
        COUNT(*)                                            AS orders,
        SUM(so.revenue)                                     AS revenue,
        SUM(CASE WHEN o.delay_days > 0 THEN 1 ELSE 0 END)   AS late_orders,
        AVG(CAST(r.review_score AS FLOAT))                  AS avg_score,
        COUNT(r.review_score)                               AS reviewed_orders
    FROM seller_orders so
    INNER JOIN dbo.orders_delivered o
        ON so.order_id = o.order_id
    LEFT JOIN dbo.reviews_clean r
        ON so.order_id = r.order_id
    GROUP BY so.seller_id
)
SELECT
    seller_id,
    orders,
    CAST(revenue AS DECIMAL(12,2))                          AS revenue,
    late_orders,
    CAST(100.0 * late_orders / orders AS DECIMAL(5,1))      AS late_pct,
    CAST(avg_score AS DECIMAL(3,2))                         AS avg_score,
    reviewed_orders
FROM seller_stats
ORDER BY revenue DESC;