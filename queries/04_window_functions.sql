-- Q09 | How did each store perform against the previous month?
-- LEAD shows the next observed month for comparison.
WITH sales_sequence AS (
    SELECT
        store_id,
        month_start,
        net_sales,
        LAG(net_sales) OVER by_month AS previous_month_sales,
        LEAD(net_sales) OVER by_month AS next_month_sales
    FROM store_month_sales
    WINDOW by_month AS (PARTITION BY store_id ORDER BY month_start)
)
SELECT
    s.store_name,
    q.month_start,
    q.net_sales,
    q.previous_month_sales,
    q.next_month_sales,
    ROUND(100 * (q.net_sales - q.previous_month_sales)
        / NULLIF(q.previous_month_sales, 0), 2) AS mom_growth_pct
FROM sales_sequence AS q
JOIN stores AS s ON s.store_id = q.store_id
ORDER BY s.store_id, q.month_start;

-- Q10 | How much did each store change from January to June?
-- Give LAST_VALUE the full partition so it sees June on every row.
WITH endpoints AS (
    SELECT
        store_id,
        FIRST_VALUE(net_sales) OVER full_period AS opening_month_sales,
        LAST_VALUE(net_sales) OVER full_period AS closing_month_sales
    FROM store_month_sales
    WINDOW full_period AS (
        PARTITION BY store_id ORDER BY month_start
        ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING
    )
)
SELECT DISTINCT
    s.store_id,
    s.store_name,
    e.opening_month_sales,
    e.closing_month_sales,
    e.closing_month_sales - e.opening_month_sales AS sales_change,
    ROUND(100 * (e.closing_month_sales - e.opening_month_sales)
        / NULLIF(e.opening_month_sales, 0), 2) AS growth_pct
FROM endpoints AS e
JOIN stores AS s ON s.store_id = e.store_id
ORDER BY sales_change DESC, s.store_id;

-- Q11 | Which stores ranked in the top three each month?
-- RANK keeps ties and leaves gaps. DENSE_RANK keeps ties without gaps.
-- ROW_NUMBER gives exactly three rows when at least three stores exist.
WITH ranked_stores AS (
    SELECT
        store_id,
        month_start,
        net_sales,
        RANK() OVER (PARTITION BY month_start ORDER BY net_sales DESC) AS sales_rank,
        DENSE_RANK() OVER (PARTITION BY month_start ORDER BY net_sales DESC) AS dense_sales_rank,
        ROW_NUMBER() OVER (PARTITION BY month_start ORDER BY net_sales DESC, store_id) AS row_position
    FROM store_month_sales
)
SELECT
    r.month_start, s.store_name, s.city, r.net_sales,
    r.sales_rank, r.dense_sales_rank, r.row_position
FROM ranked_stores AS r
JOIN stores AS s ON s.store_id = r.store_id
WHERE r.row_position <= 3
ORDER BY r.month_start, r.row_position;

-- Q12 | How much sales comes from the top customer spending quartile?
-- NTILE balances group sizes and can split customers tied on spend.
WITH buyer_totals AS (
    SELECT customer_id, COUNT(*) AS delivered_orders, SUM(net_sales) AS net_sales
    FROM order_sales
    WHERE status = 'DELIVERED'
    GROUP BY customer_id
), buyer_quartiles AS (
    SELECT *, NTILE(4) OVER (ORDER BY net_sales DESC, customer_id) AS spend_quartile
    FROM buyer_totals
), quartile_totals AS (
    SELECT
        spend_quartile,
        COUNT(*) AS buyers,
        SUM(delivered_orders) AS delivered_orders,
        SUM(net_sales) AS net_sales
    FROM buyer_quartiles
    GROUP BY spend_quartile
)
SELECT
    spend_quartile,
    buyers,
    delivered_orders,
    net_sales,
    ROUND(100 * net_sales / NULLIF(SUM(net_sales) OVER (), 0), 2) AS share_of_net_sales_pct
FROM quartile_totals
ORDER BY spend_quartile;
