-- MySQL 8.0.31+ (including INTERSECT and EXCEPT in the query suite).
-- Run in a fresh database.

CREATE TABLE stores (
    store_id    INT PRIMARY KEY,
    store_name  VARCHAR(60) NOT NULL,
    city        VARCHAR(40) NOT NULL,
    UNIQUE KEY uq_store_city_name (city, store_name)
) ENGINE = InnoDB;

CREATE TABLE customers (
    customer_id  INT PRIMARY KEY,
    city         VARCHAR(40) NOT NULL,
    signup_date  DATE NOT NULL
) ENGINE = InnoDB;

CREATE TABLE products (
    product_id    INT PRIMARY KEY,
    product_name  VARCHAR(100) NOT NULL,
    category      VARCHAR(50) NOT NULL
) ENGINE = InnoDB;

CREATE TABLE orders (
    order_id          INT PRIMARY KEY,
    customer_id       INT NOT NULL,
    store_id          INT NOT NULL,
    ordered_at        DATETIME NOT NULL,
    status            VARCHAR(12) NOT NULL,
    promised_minutes  SMALLINT NOT NULL,
    delivered_at      DATETIME,
    CONSTRAINT fk_order_customer FOREIGN KEY (customer_id) REFERENCES customers (customer_id),
    CONSTRAINT fk_order_store FOREIGN KEY (store_id) REFERENCES stores (store_id),
    CONSTRAINT chk_order_promise CHECK (promised_minutes > 0),
    CONSTRAINT chk_order_fulfillment CHECK (
        (status = 'DELIVERED' AND delivered_at IS NOT NULL AND delivered_at >= ordered_at)
        OR (status = 'CANCELLED' AND delivered_at IS NULL)
    ),
    INDEX ix_order_store_time (store_id, ordered_at),
    INDEX ix_order_customer_time (customer_id, ordered_at)
) ENGINE = InnoDB;

CREATE TABLE order_items (
    order_id       INT NOT NULL,
    product_id     INT NOT NULL,
    quantity       SMALLINT NOT NULL,
    unit_price     DECIMAL(9,2) NOT NULL,
    unit_cost      DECIMAL(9,2) NOT NULL,
    unit_discount  DECIMAL(9,2) NOT NULL,
    refunded_qty   SMALLINT NOT NULL DEFAULT 0,
    PRIMARY KEY (order_id, product_id),
    CONSTRAINT fk_item_order FOREIGN KEY (order_id) REFERENCES orders (order_id),
    CONSTRAINT fk_item_product FOREIGN KEY (product_id) REFERENCES products (product_id),
    CONSTRAINT chk_item_qty CHECK (quantity > 0 AND refunded_qty BETWEEN 0 AND quantity),
    CONSTRAINT chk_item_price CHECK (
        unit_price > 0 AND unit_cost >= 0 AND unit_discount >= 0 AND unit_discount < unit_price
    )
) ENGINE = InnoDB;

CREATE TABLE store_monthly_targets (
    store_id          INT NOT NULL,
    month_start       DATE NOT NULL,
    net_sales_target  DECIMAL(14,2) NOT NULL,
    PRIMARY KEY (store_id, month_start),
    CONSTRAINT fk_target_store FOREIGN KEY (store_id) REFERENCES stores (store_id),
    CONSTRAINT chk_target_month CHECK (DAYOFMONTH(month_start) = 1),
    CONSTRAINT chk_target_positive CHECK (net_sales_target > 0)
) ENGINE = InnoDB;

-- Sales are recognized only on delivered items. Refunds reverse the
-- discounted selling price and cost of the refunded units.
CREATE SQL SECURITY INVOKER VIEW delivered_items AS
SELECT
    i.order_id,
    i.product_id,
    i.quantity - i.refunded_qty AS net_units,
    i.quantity * i.unit_price AS gross_sales,
    i.quantity * i.unit_discount AS discounts,
    i.refunded_qty * (i.unit_price - i.unit_discount) AS refunds,
    (i.quantity - i.refunded_qty) * (i.unit_price - i.unit_discount) AS net_sales,
    (i.quantity - i.refunded_qty) * (i.unit_price - i.unit_discount - i.unit_cost) AS gross_profit
FROM order_items AS i
JOIN orders AS o ON o.order_id = i.order_id
WHERE o.status = 'DELIVERED';

-- Aggregate the items before joining them to orders to preserve one row per order.
CREATE SQL SECURITY INVOKER VIEW order_sales AS
SELECT
    o.order_id,
    o.customer_id,
    o.store_id,
    o.status,
    o.ordered_at,
    CAST(DATE_FORMAT(o.ordered_at, '%Y-%m-01') AS DATE) AS month_start,
    o.delivered_at <= o.ordered_at + INTERVAL o.promised_minutes MINUTE AS on_time,
    COALESCE(i.gross_sales, 0) AS gross_sales,
    COALESCE(i.discounts, 0) AS discounts,
    COALESCE(i.refunds, 0) AS refunds,
    COALESCE(i.net_sales, 0) AS net_sales,
    COALESCE(i.gross_profit, 0) AS gross_profit
FROM orders AS o
LEFT JOIN (
    SELECT order_id, SUM(gross_sales) AS gross_sales, SUM(discounts) AS discounts,
           SUM(refunds) AS refunds, SUM(net_sales) AS net_sales, SUM(gross_profit) AS gross_profit
    FROM delivered_items
    GROUP BY order_id
) AS i ON i.order_id = o.order_id;

-- A full store-by-month grid retains months with no orders.
CREATE SQL SECURITY INVOKER VIEW store_month_sales AS
WITH RECURSIVE months AS (
    SELECT DATE('2025-01-01') AS month_start
    UNION ALL
    SELECT month_start + INTERVAL 1 MONTH
    FROM months
    WHERE month_start < DATE('2025-06-01')
)
SELECT
    s.store_id,
    m.month_start,
    COUNT(o.order_id) AS placed_orders,
    COUNT(CASE WHEN o.status = 'DELIVERED' THEN 1 END) AS delivered_orders,
    COUNT(CASE WHEN o.status = 'CANCELLED' THEN 1 END) AS cancelled_orders,
    COALESCE(SUM(o.on_time), 0) AS on_time_orders,
    COALESCE(SUM(o.gross_sales), 0) AS gross_sales,
    COALESCE(SUM(o.discounts), 0) AS discounts,
    COALESCE(SUM(o.net_sales), 0) AS net_sales,
    COALESCE(SUM(o.gross_profit), 0) AS gross_profit
FROM stores AS s
CROSS JOIN months AS m
LEFT JOIN order_sales AS o ON o.store_id = s.store_id AND o.month_start = m.month_start
GROUP BY s.store_id, m.month_start;
