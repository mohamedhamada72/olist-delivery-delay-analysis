USE Olist;
GO

-- Power BI fact table: one row per order item (delivered orders only)
-- Order-level columns (delay, review) repeat on every item row, so in Power BI always count orders with DISTINCTCOUNT(order_id)
CREATE OR ALTER VIEW dbo.vw_fact_order_items AS
SELECT
    i.order_id,
    i.order_item_id,
    i.product_id,
    i.seller_id,
    o.customer_id,
    i.price,
    i.freight_value,
    CAST(o.order_purchase_timestamp AS DATE)      AS purchase_date,
    CAST(o.order_delivered_customer_date AS DATE) AS delivered_date,
    o.order_estimated_delivery_date               AS estimated_date,
    o.delivery_days,
    o.delay_days,
    CASE WHEN o.delay_days > 0 THEN 1 ELSE 0 END  AS is_late,
    CASE
        WHEN o.delay_days <= 0             THEN 1
        WHEN o.delay_days BETWEEN 1 AND 3  THEN 2
        WHEN o.delay_days BETWEEN 4 AND 7  THEN 3
        WHEN o.delay_days BETWEEN 8 AND 14 THEN 4
        ELSE 5
    END AS delay_bucket_no,
    CASE
        WHEN o.delay_days <= 0             THEN 'On time or early'
        WHEN o.delay_days BETWEEN 1 AND 3  THEN '1-3 days late'
        WHEN o.delay_days BETWEEN 4 AND 7  THEN '4-7 days late'
        WHEN o.delay_days BETWEEN 8 AND 14 THEN '8-14 days late'
        ELSE '15+ days late'
    END AS delay_bucket,
    r.review_score,
    CASE
        WHEN r.review_score IS NULL THEN NULL
        WHEN r.review_score <= 2    THEN 1
        ELSE 0
    END AS is_negative
FROM dbo.order_items i
INNER JOIN dbo.orders_delivered o ON i.order_id = o.order_id
LEFT JOIN  dbo.reviews_clean r    ON i.order_id = r.order_id;
GO


SELECT
    COUNT(*)                                                           AS item_rows,
    COUNT(DISTINCT order_id)                                           AS orders,
    SUM(price)                                                         AS revenue,
    COUNT(DISTINCT CASE WHEN review_score IS NOT NULL THEN order_id END) AS reviewed_orders,
    COUNT(DISTINCT CASE WHEN is_late = 1 THEN order_id END)            AS late_orders
FROM dbo.vw_fact_order_items;