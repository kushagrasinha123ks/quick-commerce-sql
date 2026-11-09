-- Q07 | Which delivered orders beat the average basket value for the same store?
SELECT
    o.order_id,
    s.store_name,
    o.ordered_at,
    o.net_sales
FROM order_sales AS o
JOIN stores AS s ON s.store_id = o.store_id
WHERE o.status = 'DELIVERED'
    AND o.net_sales > (
        SELECT AVG(peer.net_sales)
        FROM order_sales AS peer
        WHERE peer.store_id = o.store_id AND peer.status = 'DELIVERED'
    )
ORDER BY o.net_sales DESC, o.order_id
LIMIT 25;

-- Q08 | Which SKUs had retained units in Q1 and none in Q2?
SELECT p.product_id, p.product_name, p.category
FROM products AS p
WHERE EXISTS (
    SELECT 1
    FROM delivered_items AS i
    JOIN orders AS o ON o.order_id = i.order_id
    WHERE i.product_id = p.product_id AND i.net_units > 0
        AND o.ordered_at >= '2025-01-01' AND o.ordered_at < '2025-04-01'
)
AND NOT EXISTS (
    SELECT 1
    FROM delivered_items AS i
    JOIN orders AS o ON o.order_id = i.order_id
    WHERE i.product_id = p.product_id AND i.net_units > 0
        AND o.ordered_at >= '2025-04-01' AND o.ordered_at < '2025-07-01'
)
ORDER BY p.product_id;
