-- Q04 | Which categories contribute the most net sales and gross profit?
SELECT
    p.category,
    SUM(i.net_units) AS net_units,
    COUNT(DISTINCT CASE WHEN i.net_units > 0 THEN i.order_id END) AS orders_with_retained_units,
    SUM(i.net_sales) AS net_sales,
    SUM(i.gross_profit) AS gross_profit,
    ROUND(100 * SUM(i.gross_profit) / NULLIF(SUM(i.net_sales), 0), 2) AS gross_margin_pct
FROM delivered_items AS i
JOIN products AS p ON p.product_id = i.product_id
GROUP BY p.category
HAVING SUM(i.net_units) >= 100
ORDER BY net_sales DESC, p.category;

-- Q05 | Which SKU pairs were kept together in the most delivered baskets?
-- The product ID inequality counts each unordered pair only once.
SELECT
    p1.product_name AS first_product,
    p2.product_name AS second_product,
    COUNT(DISTINCT a.order_id) AS orders_together
FROM delivered_items AS a
JOIN delivered_items AS b ON b.order_id = a.order_id AND b.product_id > a.product_id
JOIN products AS p1 ON p1.product_id = a.product_id
JOIN products AS p2 ON p2.product_id = b.product_id
WHERE a.net_units > 0 AND b.net_units > 0
GROUP BY p1.product_id, p1.product_name, p2.product_id, p2.product_name
HAVING COUNT(DISTINCT a.order_id) >= 10
ORDER BY orders_together DESC, first_product, second_product
LIMIT 10;

-- Q06 | Which Snack Mix SKUs sold, and which listed SKU had no net sales?
SELECT
    p.product_id,
    p.product_name,
    COALESCE(SUM(i.net_units), 0) AS net_units,
    COALESCE(SUM(i.net_sales), 0) AS net_sales
FROM products AS p
LEFT JOIN delivered_items AS i ON i.product_id = p.product_id
WHERE p.product_name LIKE 'Snack Mix%'
GROUP BY p.product_id, p.product_name
ORDER BY net_sales DESC, p.product_id;
