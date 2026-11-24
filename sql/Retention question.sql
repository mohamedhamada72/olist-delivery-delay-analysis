USE Olist;
GO

-- Q7 step 1a: orders vs unique customers (delivered orders only)
-- customer_unique_id identifies the real person; customer_id changes with every order
SELECT
    COUNT(*)                                          AS orders,
    COUNT(DISTINCT c.customer_unique_id)              AS unique_customers,
    COUNT(*) - COUNT(DISTINCT c.customer_unique_id)   AS extra_orders_from_repeat_customers
FROM dbo.orders_delivered o
INNER JOIN dbo.customers c
    ON o.customer_id = c.customer_id;
GO

-- Q7 step 1b: how many customers ordered once, twice, 3+ times
WITH per_customer AS (
    SELECT c.customer_unique_id, COUNT(*) AS n_orders
    FROM dbo.orders_delivered o
    INNER JOIN dbo.customers c
        ON o.customer_id = c.customer_id
    GROUP BY c.customer_unique_id
)
SELECT
    CASE WHEN n_orders >= 3 THEN '3+' ELSE CAST(n_orders AS VARCHAR(2)) END AS orders_per_customer,
    COUNT(*)                                                                AS customers,
    CAST(100.0 * COUNT(*) / SUM(COUNT(*)) OVER () AS DECIMAL(5,2))          AS pct
FROM per_customer
GROUP BY CASE WHEN n_orders >= 3 THEN '3+' ELSE CAST(n_orders AS VARCHAR(2)) END
ORDER BY orders_per_customer;