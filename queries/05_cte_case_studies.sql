-- Q13 | What share of buyers returned the month after their first observed delivery?
-- First observed delivery is measured within the six-month fixture.
WITH active_months AS (
    SELECT DISTINCT customer_id, month_start
    FROM order_sales
    WHERE status = 'DELIVERED'
), first_deliveries AS (
    SELECT customer_id, MIN(month_start) AS cohort_month
    FROM active_months
    GROUP BY customer_id
), cohort_counts AS (
    SELECT
        f.cohort_month,
        COUNT(*) AS cohort_buyers,
        COUNT(a.customer_id) AS next_month_buyers
    FROM first_deliveries AS f
    LEFT JOIN active_months AS a
        ON a.customer_id = f.customer_id AND a.month_start = f.cohort_month + INTERVAL 1 MONTH
    GROUP BY f.cohort_month
), reporting_end AS (
    SELECT MAX(month_start) AS last_month
    FROM store_month_sales
)
SELECT
    c.cohort_month,
    c.cohort_buyers,
    CASE WHEN c.cohort_month < r.last_month THEN c.next_month_buyers END AS next_month_buyers,
    CASE WHEN c.cohort_month < r.last_month
        THEN ROUND(100 * c.next_month_buyers / c.cohort_buyers, 2)
    END AS next_month_retention_pct
FROM cohort_counts AS c
CROSS JOIN reporting_end AS r
ORDER BY c.cohort_month;

-- Q14 | How do basket value and margin vary by discount band?
-- These are descriptive comparisons. Order mix can differ across bands.
WITH discount_bands AS (
    SELECT
        net_sales,
        gross_profit,
        CASE
            WHEN discounts = 0 THEN 'No discount'
            WHEN discounts <= gross_sales * 0.10 THEN 'Up to 10%'
            ELSE 'Above 10%'
        END AS discount_band
    FROM order_sales
    WHERE status = 'DELIVERED'
)
SELECT
    discount_band,
    COUNT(*) AS delivered_orders,
    SUM(net_sales) AS net_sales,
    ROUND(AVG(net_sales), 2) AS average_order_value,
    ROUND(100 * SUM(gross_profit) / NULLIF(SUM(net_sales), 0), 2) AS gross_margin_pct
FROM discount_bands
GROUP BY discount_band
ORDER BY gross_margin_pct DESC;

-- Q15 | Which store-months should Sales Operations investigate?
-- Rate thresholds are illustrative. Treat flags as prompts for investigation.
WITH scorecard AS (
    SELECT
        m.store_id,
        m.month_start,
        m.net_sales,
        t.net_sales_target,
        m.net_sales - t.net_sales_target AS sales_vs_target,
        m.placed_orders,
        100 * m.cancelled_orders / NULLIF(m.placed_orders, 0) AS cancellation_pct,
        100 * m.on_time_orders / NULLIF(m.delivered_orders, 0) AS on_time_pct,
        100 * m.discounts / NULLIF(m.gross_sales, 0) AS discount_pct
    FROM store_month_sales AS m
    LEFT JOIN store_monthly_targets AS t
        ON t.store_id = m.store_id AND t.month_start = m.month_start
), flagged AS (
    SELECT
        *,
        CASE
            WHEN net_sales_target IS NULL THEN 'Target missing'
            WHEN placed_orders = 0 THEN 'No orders'
            WHEN cancellation_pct > 10 THEN 'Review cancellations'
            WHEN on_time_pct < 85 THEN 'Review late deliveries'
            WHEN discount_pct > 12 THEN 'Review discount mix'
            ELSE 'Review demand and basket size'
        END AS review_flag
    FROM scorecard
    WHERE net_sales_target IS NULL OR sales_vs_target < 0
)
SELECT
    f.month_start,
    s.city,
    s.store_name,
    f.net_sales,
    f.net_sales_target,
    f.sales_vs_target,
    ROUND(f.cancellation_pct, 2) AS cancellation_pct,
    ROUND(f.on_time_pct, 2) AS on_time_pct,
    ROUND(f.discount_pct, 2) AS discount_pct,
    f.review_flag
FROM flagged AS f
JOIN stores AS s ON s.store_id = f.store_id
ORDER BY f.sales_vs_target IS NULL, f.sales_vs_target, f.month_start, f.store_id;
