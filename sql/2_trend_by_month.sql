USE Olist;
GO

-- Q2: Late-delivery rate by purchase month, compared with the previous month
-- Month = month the order was placed (lateness is attributed to the purchase month)
WITH monthly AS (
    SELECT
        DATEFROMPARTS(YEAR(order_purchase_timestamp), MONTH(order_purchase_timestamp), 1) AS order_month,
        COUNT(*)                                         AS total_orders,
        SUM(CASE WHEN delay_days > 0 THEN 1 ELSE 0 END)  AS late_orders
    FROM dbo.orders_delivered
    GROUP BY DATEFROMPARTS(YEAR(order_purchase_timestamp), MONTH(order_purchase_timestamp), 1)
    HAVING COUNT(*) >= 100      -- drop months with too few orders (rate would be noise)
),
rates AS (
    SELECT
        order_month,
        total_orders,
        late_orders,
        CAST(100.0 * late_orders / total_orders AS DECIMAL(5,1)) AS late_pct
    FROM monthly
)
SELECT
    order_month,
    total_orders,
    late_orders,
    late_pct,
    LAG(late_pct) OVER (ORDER BY order_month)             AS prev_month_pct,
    late_pct - LAG(late_pct) OVER (ORDER BY order_month)  AS change_pp
FROM rates
ORDER BY order_month;