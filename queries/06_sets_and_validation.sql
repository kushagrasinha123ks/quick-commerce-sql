-- Q16 | How many buyers ordered in both quarters, only Q1 or only Q2?
WITH q1_buyers AS (
    SELECT DISTINCT customer_id
    FROM order_sales
    WHERE status = 'DELIVERED' AND month_start >= '2025-01-01' AND month_start < '2025-04-01'
), q2_buyers AS (
    SELECT DISTINCT customer_id
    FROM order_sales
    WHERE status = 'DELIVERED' AND month_start >= '2025-04-01' AND month_start < '2025-07-01'
), both_quarters AS (
    SELECT customer_id FROM q1_buyers
    INTERSECT
    SELECT customer_id FROM q2_buyers
), q1_only AS (
    SELECT customer_id FROM q1_buyers
    EXCEPT
    SELECT customer_id FROM q2_buyers
), q2_only AS (
    SELECT customer_id FROM q2_buyers
    EXCEPT
    SELECT customer_id FROM q1_buyers
)
SELECT 'Both quarters' AS segment, COUNT(*) AS buyers FROM both_quarters
UNION ALL
SELECT 'Q1 only', COUNT(*) FROM q1_only
UNION ALL
SELECT 'Q2 only', COUNT(*) FROM q2_only;

-- Q17 | Are there cross-table data problems? Zero rows means no exceptions.
SELECT 'Order has no items' AS issue, o.order_id
FROM orders AS o
WHERE NOT EXISTS (SELECT 1 FROM order_items AS i WHERE i.order_id = o.order_id)

UNION ALL

SELECT DISTINCT 'Cancelled order has refunded units', o.order_id
FROM orders AS o
JOIN order_items AS i ON i.order_id = o.order_id
WHERE o.status = 'CANCELLED' AND i.refunded_qty > 0

UNION ALL

SELECT 'Order before customer signup', o.order_id
FROM orders AS o
JOIN customers AS c ON c.customer_id = o.customer_id
WHERE DATE(o.ordered_at) < c.signup_date

UNION ALL

SELECT 'Customer and store city differ', o.order_id
FROM orders AS o
JOIN customers AS c ON c.customer_id = o.customer_id
JOIN stores AS s ON s.store_id = o.store_id
WHERE c.city <> s.city

UNION ALL

SELECT 'Sales amounts do not reconcile', order_id
FROM order_sales
WHERE net_sales <> gross_sales - discounts - refunds
ORDER BY issue, order_id;
