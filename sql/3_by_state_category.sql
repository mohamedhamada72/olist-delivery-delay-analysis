USE Olist;
GO

-- Q3-check: the JOIN must not change the number of orders (expect 96,470)
SELECT COUNT(*) AS rows_after_join
FROM dbo.orders_delivered o
INNER JOIN dbo.customers c ON o.customer_id = c.customer_id;
GO

-- Q3: Late-delivery rate by customer state (destination state)
WITH state_stats AS (
    SELECT
        c.customer_state,
        COUNT(*)                                          AS total_orders,
        SUM(CASE WHEN o.delay_days > 0 THEN 1 ELSE 0 END) AS late_orders,
        CAST(AVG(CAST(o.delivery_days AS FLOAT)) AS DECIMAL(5,1)) AS avg_delivery_days
    FROM dbo.orders_delivered o
    INNER JOIN dbo.customers c
        ON o.customer_id = c.customer_id
    GROUP BY c.customer_state
    HAVING COUNT(*) >= 100        -- drop states with too few orders
)
SELECT
    customer_state,
    total_orders,
    late_orders,
    CAST(100.0 * late_orders / total_orders AS DECIMAL(5,1)) AS late_pct,
    avg_delivery_days,
    RANK() OVER (ORDER BY 1.0 * late_orders / total_orders DESC) AS late_rank
FROM state_stats
ORDER BY late_rank;