USE Olist;
GO

-- View 1: one row per seller (delivered orders only)
-- Assumption: in multi-seller orders, delay and review are attributed to EACH seller involved.
CREATE OR ALTER VIEW dbo.vw_seller_stats AS
WITH seller_orders AS (
    SELECT i.seller_id, i.order_id, SUM(i.price) AS revenue
    FROM dbo.order_items i
    INNER JOIN dbo.orders_delivered o ON i.order_id = o.order_id
    GROUP BY i.seller_id, i.order_id
)
SELECT
    so.seller_id,
    COUNT(*)                                                         AS orders,
    CAST(SUM(so.revenue) AS DECIMAL(12,2))                           AS revenue,
    SUM(CASE WHEN o.delay_days > 0 THEN 1 ELSE 0 END)                AS late_orders,
    CAST(100.0 * SUM(CASE WHEN o.delay_days > 0 THEN 1 ELSE 0 END)
          / COUNT(*) AS DECIMAL(5,1))                                AS late_pct,
    CAST(AVG(CAST(r.review_score AS FLOAT)) AS DECIMAL(3,2))         AS avg_score,
    COUNT(r.review_score)                                            AS reviewed_orders
FROM seller_orders so
INNER JOIN dbo.orders_delivered o ON so.order_id = o.order_id
LEFT JOIN dbo.reviews_clean r     ON so.order_id = r.order_id
GROUP BY so.seller_id;
GO

-- View 2: scorecard = stats + tier + revenue rank
-- Tier thresholds are a first version: adjust after looking at the tier summary below.
CREATE OR ALTER VIEW dbo.vw_seller_scorecard AS
SELECT
    s.seller_id,
    s.orders,
    s.revenue,
    s.late_orders,
    s.late_pct,
    s.avg_score,
    s.reviewed_orders,
    CASE
        WHEN s.orders < 50                                THEN 'Insufficient data'
        WHEN s.avg_score < 3.5 OR s.late_pct > 15         THEN 'Risk'
        WHEN s.avg_score < 4.0 OR s.late_pct > 10         THEN 'Watch'
        WHEN s.avg_score >= 4.3 AND s.late_pct <= 6.8     THEN 'Star'
        ELSE 'Standard'
    END AS tier,
    RANK() OVER (ORDER BY s.revenue DESC) AS revenue_rank
FROM dbo.vw_seller_stats s;
GO


-- Check 1: must match step 1 -> 2,970 sellers / 97,811 orders / 13,220,248.93
SELECT COUNT(*) AS sellers, SUM(orders) AS total_orders, SUM(revenue) AS total_revenue
FROM dbo.vw_seller_stats;
GO

-- Check 2: data distribution (helps justify the 50-order minimum)
SELECT
    COUNT(*)                                          AS sellers,
    SUM(CASE WHEN orders < 10  THEN 1 ELSE 0 END)     AS under_10_orders,
    SUM(CASE WHEN orders < 50  THEN 1 ELSE 0 END)     AS under_50_orders,
    SUM(CASE WHEN orders >= 100 THEN 1 ELSE 0 END)    AS over_100_orders,
    CAST(100.0 * SUM(CASE WHEN orders < 50 THEN revenue ELSE 0 END)
          / SUM(revenue) AS DECIMAL(5,1))             AS revenue_pct_of_sellers_under_50
FROM dbo.vw_seller_stats;
GO

-- Pareto: how many sellers generate 80% of revenue?
WITH ranked AS (
    SELECT
        seller_id,
        revenue,
        ROW_NUMBER() OVER (ORDER BY revenue DESC)                                   AS rn,
        SUM(revenue) OVER (ORDER BY revenue DESC ROWS UNBOUNDED PRECEDING)          AS running_revenue,
        SUM(revenue) OVER ()                                                        AS total_revenue
    FROM dbo.vw_seller_stats
)
SELECT
    MIN(rn)                                                           AS sellers_for_80pct,
    (SELECT COUNT(*) FROM ranked)                                     AS total_sellers,
    CAST(100.0 * MIN(rn) / (SELECT COUNT(*) FROM ranked) AS DECIMAL(5,1)) AS pct_of_sellers
FROM ranked
WHERE running_revenue >= 0.8 * total_revenue;
GO

-- Tier summary: how many sellers and how much revenue in each tier
SELECT
    tier,
    COUNT(*)      AS sellers,
    SUM(orders)   AS orders,
    SUM(revenue)  AS revenue,
    CAST(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER () AS DECIMAL(5,1)) AS revenue_pct
FROM dbo.vw_seller_scorecard
GROUP BY tier
ORDER BY revenue DESC;
GO

-- Priority list: high-revenue sellers that are in Risk or Watch
SELECT TOP 15
    revenue_rank, seller_id, orders, revenue, late_pct, avg_score, tier
FROM dbo.vw_seller_scorecard
WHERE tier IN ('Risk', 'Watch')
ORDER BY revenue DESC;