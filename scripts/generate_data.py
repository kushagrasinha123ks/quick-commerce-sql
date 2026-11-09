"""Regenerate the fictional SwiftBasket CSVs and matching MySQL seed."""

import csv
from calendar import monthrange
from datetime import date, datetime, timedelta
from decimal import Decimal
from pathlib import Path
from random import Random

ROOT = Path(__file__).resolve().parents[1]
YEAR = 2025
RNG = Random(202501)

# Store name, city, relative traffic, baseline monthly sales plan.
STORE_PROFILES = [
    ("Indiranagar", "Bengaluru", 1.35, 11000),
    ("Whitefield", "Bengaluru", 1.05, 9200),
    ("Andheri", "Mumbai", 1.20, 9900),
    ("Powai", "Mumbai", 0.95, 7900),
    ("Madhapur", "Hyderabad", 0.90, 7900),
    ("Gachibowli", "Hyderabad", 0.90, 8400),
    ("Kothrud", "Pune", 0.85, 7300),
    ("Viman Nagar", "Pune", 0.75, 7000),
]

# Fictional catalogue. Prices and costs are in INR per unit.
CATALOGUE = {
    "Produce": [
        ("Bananas 6 pc", 65, 42), ("Tomatoes 500 g", 38, 25),
        ("Onions 1 kg", 54, 39), ("Apples 4 pc", 145, 102),
        ("Baby Spinach 200 g", 56, 35),
    ],
    "Dairy & Eggs": [
        ("Toned Milk 1 L", 68, 55), ("Eggs 6 pc", 79, 59),
        ("Plain Curd 400 g", 57, 40), ("Paneer 200 g", 105, 74),
        ("Butter 100 g", 61, 47),
    ],
    "Pantry": [
        ("Basmati Rice 1 kg", 175, 113), ("Toor Dal 500 g", 102, 73),
        ("Sunflower Oil 1 L", 149, 116), ("Rolled Oats 500 g", 132, 82),
        ("Whole Wheat Atta 1 kg", 74, 55),
    ],
    "Snacks": [
        ("Snack Mix Chilli 150 g", 72, 40), ("Snack Mix Classic 150 g", 65, 37),
        ("Snack Mix Trial Pack 75 g", 39, 22), ("Snack Mix Herb 150 g", 76, 44),
        ("Chocolate Biscuits 120 g", 50, 29), ("Potato Crisps 100 g", 60, 34),
    ],
    "Beverages": [
        ("Orange Juice 1 L", 142, 93), ("Coconut Water 250 ml", 58, 36),
        ("Cold Coffee 250 ml", 89, 56), ("Soda Water 750 ml", 34, 21),
        ("Iced Tea 300 ml", 55, 32),
    ],
    "Home Care": [
        ("Dishwashing Liquid 500 ml", 139, 85), ("Laundry Detergent 1 kg", 219, 141),
        ("Floor Cleaner 500 ml", 119, 72), ("Kitchen Towels 2 rolls", 155, 96),
        ("Hand Wash 250 ml", 99, 58),
    ],
}


def build_fixture():
    stores = [(i, name, city) for i, (name, city, _, _) in enumerate(STORE_PROFILES, 1)]
    products = [
        (category, name, price, cost)
        for category, items in CATALOGUE.items() for name, price, cost in items
    ]
    product_rows = [(i, name, category) for i, (category, name, _, _) in enumerate(products, 1)]
    customers, customer_weights = [], {}
    for city in sorted({row[2] for row in stores}):
        for _ in range(90):
            month = RNG.choices([1, 2, 3, 4, 5, 6], [50, 12, 10, 10, 9, 9])[0]
            customer_id = len(customers) + 1
            customers.append((customer_id, city, date(YEAR, month, 1)))
            customer_weights[customer_id] = RNG.uniform(0.3, 2.0)

    orders, order_items, targets = [], [], []
    for month, order_count in enumerate([200, 220, 240, 260, 280, 300], 1):
        month_start = date(YEAR, month, 1)
        for store_id, (_, _, _, plan) in enumerate(STORE_PROFILES, 1):
            if (store_id, month) != (4, 5):  # An intentionally missing sales plan.
                target = plan * (100 + 10 * (month - 1)) // 100
                targets.append((store_id, month_start, target))

        # Viman Nagar has a January plan but starts receiving orders in February.
        store_weights = [profile[2] for profile in STORE_PROFILES]
        if month == 1:
            store_weights[-1] = 0
        for store_id in RNG.choices(range(1, 9), store_weights, k=order_count):
            _, city, _, _ = STORE_PROFILES[store_id - 1]
            buyers = [c[0] for c in customers if c[1] == city and c[2] <= month_start]
            customer_id = RNG.choices(buyers, [customer_weights[i] for i in buyers])[0]
            ordered_at = datetime(
                YEAR, month, RNG.randint(1, monthrange(YEAR, month)[1]),
                RNG.randint(7, 22), RNG.randint(0, 59),
            )
            promised = RNG.choice([15, 20, 25])
            cancelled = RNG.random() < (0.13 if store_id in (4, 8) else 0.055)
            duration = max(5, round(RNG.gauss(promised - (1 if store_id in (4, 8) else 5), 5)))
            delivered_at = None if cancelled else ordered_at + timedelta(minutes=duration)
            order_id = len(orders) + 1
            orders.append((
                order_id, customer_id, store_id, ordered_at,
                "CANCELLED" if cancelled else "DELIVERED", promised, delivered_at,
            ))

            eligible = [
                i for i, (_, name, _, _) in enumerate(products, 1)
                if "Trial Pack" not in name and (month <= 3 or "Snack Mix Herb" not in name)
            ]
            basket_size = RNG.choices([1, 2, 3, 4, 5, 6], [8, 20, 29, 24, 13, 6])[0]
            discount_pct = RNG.choices([0, 5, 8, 10, 15, 18, 20], [26, 14, 14, 18, 12, 9, 7])[0]
            for product_id in sorted(RNG.sample(eligible, basket_size)):
                _, _, price, cost = products[product_id - 1]
                qty = RNG.choices([1, 2, 3], [76, 20, 4])[0]
                refund_qty = 1 if not cancelled and RNG.random() < 0.024 else 0
                order_items.append((
                    order_id, product_id, qty, price, cost,
                    Decimal(price * discount_pct).scaleb(-2), refund_qty,
                ))

    return [
        ("stores", "store_id store_name city", stores),
        ("customers", "customer_id city signup_date", customers),
        ("products", "product_id product_name category", product_rows),
        ("orders", "order_id customer_id store_id ordered_at status promised_minutes delivered_at", orders),
        ("order_items", "order_id product_id quantity unit_price unit_cost unit_discount refunded_qty", order_items),
        ("store_monthly_targets", "store_id month_start net_sales_target", targets),
    ]


def sql_literal(value):
    if value is None:
        return "NULL"
    if isinstance(value, (int, Decimal)):
        return str(value)
    return "'" + str(value).replace("'", "''") + "'"


def main():
    (ROOT / "data").mkdir(exist_ok=True)
    statements = ["-- Generated from the same fixture as the CSV files.", "START TRANSACTION;"]
    for table, columns, rows in build_fixture():
        columns = columns.split()
        with (ROOT / "data" / f"{table}.csv").open("w", encoding="utf-8", newline="") as file:
            writer = csv.writer(file, lineterminator="\n")
            writer.writerow(columns)
            writer.writerows(rows)
        for start in range(0, len(rows), 250):
            values = [f"    ({', '.join(map(sql_literal, row))})" for row in rows[start:start + 250]]
            statements.append(
                f"INSERT INTO {table} ({', '.join(columns)}) VALUES\n" + ",\n".join(values) + ";"
            )
    statements.append("COMMIT;")
    (ROOT / "seed.sql").write_text("\n\n".join(statements) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
