USE Olist;
GO

-- Q1: Overview of delivery performance (delivered orders only)
WITH med AS (
    SELECT DISTINCT
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delivery_days) OVER () AS median_delivery_days
    FROM dbo.orders_delivered
)
SELECT
    COUNT(*)                                                         AS total_orders,
    SUM(CASE WHEN delay_days > 0 THEN 1 ELSE 0 END)                  AS late_orders,
    ROUND(100.0 * SUM(CASE WHEN delay_days > 0 THEN 1 ELSE 0 END)
          / COUNT(*), 1)                                             AS late_pct,
    ROUND(AVG(CAST(delivery_days AS FLOAT)), 2)                      AS avg_delivery_days,
    (SELECT median_delivery_days FROM med)                           AS median_delivery_days,
    ROUND(AVG(CAST(delay_days AS FLOAT)), 2)                         AS avg_delay_days
FROM dbo.orders_delivered;