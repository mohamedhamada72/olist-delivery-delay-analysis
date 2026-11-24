USE Olist;
GO

-- One row per customer whose first delivery is at least 180 days before the last order in the data.
-- returned = 1 if a later order was placed after the first delivery, within 180 days.
CREATE OR ALTER VIEW dbo.vw_customer_retention AS
WITH last_day AS (
    SELECT MAX(order_purchase_timestamp) AS last_purchase
    FROM dbo.orders_delivered
),
first_orders AS (
    SELECT co.customer_unique_id, co.order_delivered_customer_date, co.delay_days
    FROM dbo.vw_customer_orders co
    CROSS JOIN last_day l
    WHERE co.rn = 1
      AND co.order_delivered_customer_date <= DATEADD(DAY, -180, l.last_purchase)
)
SELECT
    f.customer_unique_id,
    CASE WHEN f.delay_days > 0 THEN 'Late first order' ELSE 'On-time first order' END AS first_order_group,
    CASE WHEN EXISTS (
        SELECT 1
        FROM dbo.vw_customer_orders c2
        WHERE c2.customer_unique_id = f.customer_unique_id
          AND c2.rn > 1
          AND c2.order_purchase_timestamp >  f.order_delivered_customer_date
          AND c2.order_purchase_timestamp <= DATEADD(DAY, 180, f.order_delivered_customer_date)
    ) THEN 1 ELSE 0 END AS returned
FROM first_orders f;
GO

-- Check
SELECT first_order_group, COUNT(*) AS customers, SUM(returned) AS returned,
       CAST(100.0 * SUM(returned) / COUNT(*) AS DECIMAL(5,2)) AS return_rate_pct
FROM dbo.vw_customer_retention
GROUP BY first_order_group;



