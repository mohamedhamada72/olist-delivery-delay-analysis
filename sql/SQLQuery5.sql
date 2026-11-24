USE Olist;
GO

-- Q5-check: orders lost by joining reviews (some delivered orders have no review)
SELECT
    COUNT(*)                   AS rows_after_join,
    COUNT(DISTINCT o.order_id) AS distinct_orders
FROM dbo.orders_delivered o
INNER JOIN dbo.reviews_clean r ON o.order_id = r.order_id;
GO

-- Q5: Review score by delay bucket (delivered orders that have a review)
-- Note: correlation, not proof of causation.
WITH bucketed AS (
    SELECT
        o.order_id,
        r.review_score,
        CASE
            WHEN o.delay_days <= 0                THEN 1
            WHEN o.delay_days BETWEEN 1 AND 3     THEN 2
            WHEN o.delay_days BETWEEN 4 AND 7     THEN 3
            WHEN o.delay_days BETWEEN 8 AND 14    THEN 4
            WHEN o.delay_days >= 15               THEN 5
        END AS bucket_no,
        CASE
            WHEN o.delay_days <= 0                THEN 'On time or early'
            WHEN o.delay_days BETWEEN 1 AND 3     THEN '1-3 days late'
            WHEN o.delay_days BETWEEN 4 AND 7     THEN '4-7 days late'
            WHEN o.delay_days BETWEEN 8 AND 14    THEN '8-14 days late'
            WHEN o.delay_days >= 15               THEN '15+ days late'
        END AS delay_bucket
    FROM dbo.orders_delivered o
    INNER JOIN dbo.reviews_clean r
        ON o.order_id = r.order_id
)
SELECT
    bucket_no,
    delay_bucket,
    COUNT(*)                                                    AS orders,
    CAST(AVG(CAST(review_score AS FLOAT)) AS DECIMAL(3,2))      AS avg_score,
    CAST(100.0 * SUM(CASE WHEN review_score <= 2 THEN 1 ELSE 0 END)
          / COUNT(*) AS DECIMAL(5,1))                           AS negative_pct,
    CAST(100.0 * SUM(CASE WHEN review_score = 5 THEN 1 ELSE 0 END)
          / COUNT(*) AS DECIMAL(5,1))                           AS five_star_pct
FROM bucketed
GROUP BY bucket_no, delay_bucket
ORDER BY bucket_no;