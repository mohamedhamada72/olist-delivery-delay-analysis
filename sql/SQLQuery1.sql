USE Olist;
SELECT 'vw_fact_order_items' AS obj, COUNT(*) AS n FROM dbo.vw_fact_order_items
UNION ALL SELECT 'vw_customer_retention', COUNT(*) FROM dbo.vw_customer_retention
UNION ALL SELECT 'vw_seller_scorecard', COUNT(*) FROM dbo.vw_seller_scorecard;