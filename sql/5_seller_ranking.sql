USE Olist;
GO

-- Q6 step 1: one row per (seller, delivered order) with the seller's revenue in that order
-- Revenue = SUM(price) only; freight_value is excluded (shipping is not product revenue)
WITH seller_orders AS (
    SELECT
        i.seller_id,
        i.order_id,
        SUM(i.price) AS revenue
    FROM dbo.order_items i
    INNER JOIN dbo.orders_delivered o
        ON i.order_id = o.order_id
    GROUP BY i.seller_id, i.order_id
)
SELECT
    COUNT(*)                  AS seller_order_rows,
    COUNT(DISTINCT order_id)  AS distinct_orders,
    COUNT(DISTINCT seller_id) AS distinct_sellers,
    SUM(revenue)              AS total_revenue
FROM seller_orders;
GO

-- Direct check (no grouping): must match total_revenue above
SELECT SUM(i.price) AS total_revenue_direct
FROM dbo.order_items i
INNER JOIN dbo.orders_delivered o
    ON i.order_id = o.order_id;