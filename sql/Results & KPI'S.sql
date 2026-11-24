USE Olist;
GO

-- One row per (real customer, delivered order), numbered by purchase time
-- Limitation: only delivered orders exist here, so a repeat order that was cancelled or is still in transit is not counted as a return.
CREATE OR ALTER VIEW dbo.vw_customer_orders AS
SELECT
    c.customer_unique_id,
    o.order_id,
    o.order_purchase_timestamp,
    o.order_delivered_customer_date,
    o.delay_days,
    ROW_NUMBER() OVER (
        PARTITION BY c.customer_unique_id
        ORDER BY o.order_purchase_timestamp, o.order_id
    ) AS rn
FROM dbo.orders_delivered o
INNER JOIN dbo.customers c
    ON o.customer_id = c.customer_id;
GO

SELECT
    MIN(order_purchase_timestamp)       AS first_purchase,
    MAX(order_purchase_timestamp)       AS last_purchase,
    MAX(order_delivered_customer_date)  AS last_delivery
FROM dbo.orders_delivered;
GO

WITH first_orders AS (
    SELECT * FROM dbo.vw_customer_orders WHERE rn = 1
),
returners AS (
    -- days from first delivery to the earliest later order placed AFTER that delivery
    SELECT
        f.customer_unique_id,
        DATEDIFF(DAY, f.order_delivered_customer_date, MIN(co.order_purchase_timestamp)) AS days_to_return
    FROM first_orders f
    INNER JOIN dbo.vw_customer_orders co
        ON  co.customer_unique_id = f.customer_unique_id
        AND co.rn > 1
        AND co.order_purchase_timestamp > f.order_delivered_customer_date
    GROUP BY f.customer_unique_id, f.order_delivered_customer_date
),
med AS (
    SELECT DISTINCT
        PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_to_return) OVER () AS median_days
    FROM returners
)
SELECT
    COUNT(*)                                          AS returned_customers,
    (SELECT median_days FROM med)                     AS median_days_to_return,
    SUM(CASE WHEN days_to_return <= 30  THEN 1 ELSE 0 END) AS within_30,
    SUM(CASE WHEN days_to_return <= 90  THEN 1 ELSE 0 END) AS within_90,
    SUM(CASE WHEN days_to_return <= 180 THEN 1 ELSE 0 END) AS within_180,
    SUM(CASE WHEN days_to_return <= 365 THEN 1 ELSE 0 END) AS within_365
FROM returners;
GO

DECLARE @N INT = 180;                                                    -- return window in days (adjust after Part 3)
DECLARE @last_purchase DATETIME2 = (SELECT MAX(order_purchase_timestamp) FROM dbo.orders_delivered);
DECLARE @cutoff DATETIME2 = DATEADD(DAY, -@N, @last_purchase);           -- only customers with a full N-day window

WITH first_orders AS (
    SELECT *
    FROM dbo.vw_customer_orders
    WHERE rn = 1
      AND order_delivered_customer_date <= @cutoff
),
flagged AS (
    SELECT
        f.customer_unique_id,
        CASE WHEN f.delay_days > 0 THEN 'Late first order' ELSE 'On-time first order' END AS first_order_group,
        CASE WHEN EXISTS (
            SELECT 1
            FROM dbo.vw_customer_orders co
            WHERE co.customer_unique_id = f.customer_unique_id
              AND co.rn > 1
              AND co.order_purchase_timestamp >  f.order_delivered_customer_date
              AND co.order_purchase_timestamp <= DATEADD(DAY, @N, f.order_delivered_customer_date)
        ) THEN 1 ELSE 0 END AS returned
    FROM first_orders f
)
SELECT
    first_order_group,
    COUNT(*)                                                   AS customers,
    SUM(returned)                                              AS returned_customers,
    CAST(100.0 * SUM(returned) / COUNT(*) AS DECIMAL(5,2))     AS return_rate_pct
FROM flagged
GROUP BY first_order_group
ORDER BY first_order_group;