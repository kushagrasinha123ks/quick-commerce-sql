-- Q01 | What were the six-month sales, basket and delivery KPIs?
SELECT
    COUNT(*) AS placed_orders,
    COUNT(CASE WHEN status = 'DELIVERED' THEN 1 END) AS delivered_orders,
    SUM(gross_sales) AS gross_sales,
    SUM(discounts) AS discounts,
    SUM(refunds) AS refunds,
    SUM(net_sales) AS net_sales,
    ROUND(AVG(CASE WHEN status = 'DELIVERED' THEN net_sales END), 2) AS average_order_value,
    SUM(gross_profit) AS gross_profit,
    ROUND(100 * SUM(gross_profit) / NULLIF(SUM(net_sales), 0), 2) AS gross_margin_pct,
    ROUND(100 * COUNT(CASE WHEN status = 'CANCELLED' THEN 1 END) / NULLIF(COUNT(*), 0), 2) AS cancellation_pct,
    ROUND(100 * AVG(on_time), 2) AS on_time_pct
FROM order_sales;

-- Q02 | How did sales, delivered volume and basket value change by month?
SELECT
    month_start,
    SUM(placed_orders) AS placed_orders,
    SUM(delivered_orders) AS delivered_orders,
    SUM(net_sales) AS net_sales,
    ROUND(SUM(net_sales) / NULLIF(SUM(delivered_orders), 0), 2) AS average_order_value
FROM store_month_sales
GROUP BY month_start
ORDER BY month_start;

-- Q03 | Which stores met target, missed target or had no target entered?
SELECT
    m.month_start,
    s.city,
    s.store_name,
    m.net_sales,
    t.net_sales_target,
    m.net_sales - t.net_sales_target AS sales_vs_target,
    ROUND(100 * m.net_sales / t.net_sales_target, 2) AS attainment_pct,
    CASE
        WHEN t.store_id IS NULL THEN 'Target missing'
        WHEN m.net_sales >= t.net_sales_target THEN 'Met'
        ELSE 'Below target'
    END AS target_status
FROM store_month_sales AS m
JOIN stores AS s ON s.store_id = m.store_id
LEFT JOIN store_monthly_targets AS t
    ON t.store_id = m.store_id AND t.month_start = m.month_start
ORDER BY m.month_start, s.city, s.store_name;
