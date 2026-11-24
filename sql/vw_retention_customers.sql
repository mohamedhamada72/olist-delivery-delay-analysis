USE Olist;
GO

CREATE OR ALTER VIEW dbo.vw_retention_customers AS
WITH all_orders AS (              
    SELECT
        c.customer_unique_id,
        c.customer_state,
        o.order_id,
        o.order_purchase_timestamp  AS purchase_ts,
        o.order_delivered_customer_date AS delivered_ts,
        o.delay_days,
        ROW_NUMBER() OVER (
            PARTITION BY c.customer_unique_id
            ORDER BY o.order_purchase_timestamp, o.order_id
        ) AS rn
    FROM dbo.orders_delivered o
    INNER JOIN dbo.customers c ON o.customer_id = c.customer_id
),
first_orders AS (                
    SELECT *
    FROM all_orders
    WHERE rn = 1
      AND delivered_ts IS NOT NULL
),
bounds AS (                       
    SELECT MAX(purchase_ts) AS last_purchase
    FROM all_orders
)
SELECT
    f.customer_unique_id,
    f.customer_state,
    YEAR(f.purchase_ts) AS first_order_year,
    CASE WHEN f.delay_days > 0 THEN 'Late' ELSE 'On time' END AS first_order_status,
    CASE WHEN EXISTS (            
        SELECT 1
        FROM all_orders a
        WHERE a.customer_unique_id = f.customer_unique_id
          AND a.rn > 1
          AND a.purchase_ts > f.delivered_ts
          AND a.purchase_ts <= DATEADD(DAY, 180, f.delivered_ts)
    ) THEN 1 ELSE 0 END AS returned_180d
FROM first_orders f
CROSS JOIN bounds b
WHERE DATEADD(DAY, 180, f.delivered_ts) <= b.last_purchase;   
GO



--test
SELECT first_order_status, COUNT(*) AS customers,
       SUM(returned_180d) AS returned,
       CAST(100.0 * SUM(returned_180d) / COUNT(*) AS DECIMAL(5,2)) AS pct
FROM dbo.vw_retention_customers
GROUP BY first_order_status;