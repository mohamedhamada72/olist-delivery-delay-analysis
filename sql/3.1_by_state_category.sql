USE Olist;
GO

-- Q4-check: fan-out after joining items and products
-- rows_after_joins counts order lines, distinct_orders counts orders
SELECT
    COUNT(*)                 AS rows_after_joins,
    COUNT(DISTINCT o.order_id) AS distinct_orders
FROM dbo.orders_delivered o
INNER JOIN dbo.order_items i    ON o.order_id = i.order_id
INNER JOIN dbo.products_clean p ON i.product_id = p.product_id;
GO

-- Q4: Late-delivery rate by product category
-- Note: an order with items from 2 categories is counted once in EACH category,
-- so the sum of category order counts is higher than the number of orders.
WITH cat AS (
    SELECT
        p.product_category_name_english AS category,
        COUNT(DISTINCT o.order_id)      AS total_orders,
        COUNT(DISTINCT CASE WHEN o.delay_days > 0 THEN o.order_id END) AS late_orders
    FROM dbo.orders_delivered o
    INNER JOIN dbo.order_items i    ON o.order_id = i.order_id
    INNER JOIN dbo.products_clean p ON i.product_id = p.product_id
    GROUP BY p.product_category_name_english
    HAVING COUNT(DISTINCT o.order_id) >= 100
)
SELECT
    category,
    total_orders,
    late_orders,
    CAST(100.0 * late_orders / total_orders AS DECIMAL(5,1)) AS late_pct,
    RANK() OVER (ORDER BY 1.0 * late_orders / total_orders DESC) AS late_rank
FROM cat
ORDER BY late_rank;