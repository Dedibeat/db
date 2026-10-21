
-- ============================================================
-- 1. The 10 orders with the highest totals
-- ============================================================

CREATE OR REPLACE VIEW v_order_totals AS
SELECT
    o.order_id,
    o.customer_id,
    o.order_date,
    SUM((od.unit_price * od.quantity * (1 - od.discount))::numeric) AS order_total
FROM orders AS o
JOIN order_details AS od ON od.order_id = o.order_id
GROUP BY o.order_id, o.customer_id, o.order_date;

SELECT order_id, customer_id, order_date,
       ROUND(order_total, 2) AS order_total
FROM v_order_totals
ORDER BY order_total DESC, order_id
LIMIT 10;


-- ============================================================
-- 2. Customers whose average order is above the overall average
-- ============================================================

CREATE OR REPLACE VIEW v_customer_sales AS
SELECT
    c.customer_id,
    c.company_name,
    c.country,
    COUNT(vot.order_id) AS order_count,
    COALESCE(SUM(vot.order_total), 0::numeric) AS total_revenue,
    COALESCE(AVG(vot.order_total), 0::numeric) AS average_order_value,
    MAX(vot.order_date) AS last_order_date
FROM customers AS c
LEFT JOIN v_order_totals AS vot ON vot.customer_id = c.customer_id
GROUP BY c.customer_id, c.company_name, c.country;

SELECT customer_id, company_name, country, order_count,
       ROUND(total_revenue, 2) AS total_revenue,
       ROUND(average_order_value, 2) AS average_order_value,
       last_order_date
FROM v_customer_sales
WHERE average_order_value > (SELECT AVG(order_total) FROM v_order_totals)
ORDER BY average_order_value DESC, customer_id;


-- ============================================================
-- 3. The top 3 products by sales in every category
-- ============================================================

CREATE OR REPLACE VIEW v_product_category_rank AS
WITH product_sales AS (
    SELECT
        c.category_id,
        c.category_name,
        p.product_id,
        p.product_name,
        COALESCE(
            SUM((od.unit_price * od.quantity * (1 - od.discount))::numeric),
            0::numeric
        ) AS total_sales
    FROM categories AS c
    JOIN products AS p ON p.category_id = c.category_id
    LEFT JOIN order_details AS od ON od.product_id = p.product_id
    GROUP BY c.category_id, c.category_name, p.product_id, p.product_name
)
SELECT
    category_id,
    category_name,
    product_id,
    product_name,
    total_sales,
    RANK() OVER (
        PARTITION BY category_id
        ORDER BY total_sales DESC
    ) AS sales_rank
FROM product_sales;

SELECT category_name, product_name,
       ROUND(total_sales, 2) AS total_sales,
       sales_rank
FROM v_product_category_rank
WHERE sales_rank <= 3
ORDER BY category_name, sales_rank, product_name;


-- ============================================================
-- 4. Employee hierarchy made with a recursive CTE
-- ============================================================

CREATE OR REPLACE VIEW v_employee_hierarchy AS
WITH RECURSIVE hierarchy AS (
    -- Root employee: no manager
    SELECT
        e.employee_id,
        CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
        e.reports_to AS manager_id,
        NULL::text AS manager_name,
        0 AS depth,
        CONCAT(e.first_name, ' ', e.last_name)::text AS path
    FROM employees AS e
    WHERE e.reports_to IS NULL

    UNION ALL

    -- Add employees who report to the current level
    SELECT
        e.employee_id,
        CONCAT(e.first_name, ' ', e.last_name) AS employee_name,
        e.reports_to AS manager_id,
        h.employee_name AS manager_name,
        h.depth + 1 AS depth,
        (h.path || ' > ' || CONCAT(e.first_name, ' ', e.last_name))::text AS path
    FROM employees AS e
    JOIN hierarchy AS h ON e.reports_to = h.employee_id
)
SELECT employee_id, employee_name, manager_id, manager_name, depth, path
FROM hierarchy;

SELECT *
FROM v_employee_hierarchy
ORDER BY depth, employee_id;


-- ============================================================
-- 5. Updatable view with WITH CHECK OPTION
-- ============================================================

CREATE OR REPLACE VIEW v_active_products AS
SELECT
    product_id,
    product_name,
    supplier_id,
    category_id,
    quantity_per_unit,
    unit_price,
    units_in_stock,
    units_on_order,
    reorder_level,
    discontinued
FROM products
WHERE discontinued = 0
WITH CHECK OPTION;

-- Test updatability: INSERT and UPDATE satisfying discontinued = 0
BEGIN;

INSERT INTO v_active_products (
    product_id, product_name, unit_price, units_in_stock,
    units_on_order, reorder_level, discontinued
)
VALUES (32000, 'Lab Test Product', 10.00, 5, 0, 2, 0);

UPDATE v_active_products
SET unit_price = 12.00
WHERE product_id = 32000;

SELECT product_id, product_name, unit_price, discontinued
FROM v_active_products
WHERE product_id = 32000;

ROLLBACK;

-- UPDATE v_active_products
-- SET discontinued = 1
-- WHERE product_id = 3;

-- ============================================================
-- 6. Materialized monthly sales by country
-- ============================================================

DROP MATERIALIZED VIEW IF EXISTS mv_monthly_sales;

CREATE MATERIALIZED VIEW mv_monthly_sales AS
SELECT
    DATE_TRUNC('month', o.order_date)::date AS year_month,
    o.ship_country AS country,
    COUNT(DISTINCT o.order_id) AS order_count,
    SUM((od.unit_price * od.quantity * (1 - od.discount))::numeric) AS total_revenue
FROM orders AS o
JOIN order_details AS od ON od.order_id = o.order_id
WHERE o.order_date IS NOT NULL
  AND o.ship_country IS NOT NULL
GROUP BY DATE_TRUNC('month', o.order_date)::date, o.ship_country;

CREATE UNIQUE INDEX ux_mv_monthly_sales_year_month_country
    ON mv_monthly_sales (year_month, country);

REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_sales;

SELECT year_month, country, order_count,
       ROUND(total_revenue, 2) AS total_revenue
FROM mv_monthly_sales
ORDER BY year_month, country;


-- ============================================================
-- 7. Customer revenue pivot by product category
-- ============================================================

CREATE OR REPLACE VIEW v_customer_category_pivot AS
SELECT
    c.customer_id,
    c.company_name,
    COALESCE(SUM(CASE WHEN cat.category_name = 'Beverages'
        THEN (od.unit_price * od.quantity * (1 - od.discount))::numeric ELSE 0 END), 0) AS beverages,
    COALESCE(SUM(CASE WHEN cat.category_name = 'Condiments'
        THEN (od.unit_price * od.quantity * (1 - od.discount))::numeric ELSE 0 END), 0) AS condiments,
    COALESCE(SUM(CASE WHEN cat.category_name = 'Confections'
        THEN (od.unit_price * od.quantity * (1 - od.discount))::numeric ELSE 0 END), 0) AS confections,
    COALESCE(SUM(CASE WHEN cat.category_name = 'Dairy Products'
        THEN (od.unit_price * od.quantity * (1 - od.discount))::numeric ELSE 0 END), 0) AS dairy_products,
    COALESCE(SUM(CASE WHEN cat.category_name = 'Grains/Cereals'
        THEN (od.unit_price * od.quantity * (1 - od.discount))::numeric ELSE 0 END), 0) AS grains_cereals,
    COALESCE(SUM(CASE WHSELECT category_name, product_name,
       ROUND(total_sales, 2) AS total_sales,
       sales_rank
FROM v_product_category_rank
WHERE sales_rank <= 3
ORDER BY category_name, sales_rank, product_name;
EN cat.category_name = 'Meat/Poultry'
        THEN (od.unit_price * od.quantity * (1 - od.discount))::numeric ELSE 0 END), 0) AS meat_poultry,
    COALESCE(SUM(CASE WHEN cat.category_name = 'Produce'
        THEN (od.unit_price * od.quantity * (1 - od.discount))::numeric ELSE 0 END), 0) AS produce,
    COALESCE(SUM(CASE WHEN cat.category_name = 'Seafood'
        THEN (od.unit_price * od.quantity * (1 - od.discount))::numeric ELSE 0 END), 0) AS seafood,
    COALESCE(SUM((od.unit_price * od.quantity * (1 - od.discount))::numeric), 0) AS total_revenue
FROM customers AS c
LEFT JOIN orders AS o ON o.customer_id = c.customer_id
LEFT JOIN order_details AS od ON od.order_id = o.order_id
LEFT JOIN products AS p ON p.product_id = od.product_id
LEFT JOIN categories AS cat ON cat.category_id = p.category_id
GROUP BY c.customer_id, c.company_name;

-- Pivot table result.
SELECT
    customer_id,
    company_name,
    ROUND(beverages, 2) AS beverages,
    ROUND(condiments, 2) AS condiments,
    ROUND(confections, 2) AS confections,
    ROUND(dairy_products, 2) AS dairy_products,
    ROUND(grains_cereals, 2) AS grains_cereals,
    ROUND(meat_poultry, 2) AS meat_poultry,
    ROUND(produce, 2) AS produce,
    ROUND(seafood, 2) AS seafood,
    ROUND(total_revenue, 2) AS total_revenue
FROM v_customer_category_pivot
ORDER BY customer_id;

-- Customers receiving more than 50% of revenue from one category.
SELECT
    p.company_name,
    d.category_name AS dominant_category,
    ROUND(d.category_revenue, 2) AS dominant_revenue,
    ROUND(p.total_revenue, 2) AS total_revenue,
    ROUND(100 * d.category_revenue / p.total_revenue, 1) AS share
FROM v_customer_category_pivot AS p
CROSS JOIN LATERAL (
    VALUES
        ('Beverages', p.beverages),
        ('Condiments', p.condiments),
        ('Confections', p.confections),
        ('Dairy Products', p.dairy_products),
        ('Grains/Cereals', p.grains_cereals),
        ('Meat/Poultry', p.meat_poultry),
        ('Produce', p.produce),
        ('Seafood', p.seafood)
) AS d(category_name, category_revenue)
WHERE p.total_revenue > 0
  AND d.category_revenue > p.total_revenue * 0.50
ORDER BY share DESC, p.company_name;


-- ============================================================
-- 8. A view built from another view, with monthly change
-- ============================================================

CREATE OR REPLACE VIEW v_order_lines AS
SELECT
    o.order_id,
    o.order_date,
    p.product_id,
    p.product_name,
    c.category_id,
    c.category_name,
    od.unit_price,
    od.quantity,
    od.discount,
    (od.unit_price * od.quantity * (1 - od.discount))::numeric AS line_total
FROM orders AS o
JOIN order_details AS od ON od.order_id = o.order_id
JOIN products AS p ON p.product_id = od.product_id
JOIN categories AS c ON c.category_id = p.category_id;

CREATE OR REPLACE VIEW v_category_monthly AS
SELECT
    category_id,
    category_name,
    DATE_TRUNC('month', order_date)::date AS month,
    SUM(line_total) AS current_revenue
FROM v_order_lines
GROUP BY category_id, category_name, DATE_TRUNC('month', order_date)::date;

CREATE OR REPLACE VIEW v_category_monthly_change AS
WITH monthly_with_previous AS (
    SELECT
        category_id,
        category_name,
        month,
        current_revenue,
        LAG(current_revenue) OVER (
            PARTITION BY category_id
            ORDER BY month
        ) AS previous_revenue
    FROM v_category_monthly
)
SELECT
    category_id,
    category_name,
    month,
    previous_revenue,
    current_revenue,
    current_revenue - previous_revenue AS change_amount,
    100 * (current_revenue - previous_revenue)
        / NULLIF(previous_revenue, 0) AS change_percent
FROM monthly_with_previous;

-- The category with the largest one-month decrease.
SELECT
    category_name,
    month,
    ROUND(previous_revenue, 2) AS previous_revenue,
    ROUND(current_revenue, 2) AS current_revenue,
    ROUND(change_amount, 2) AS change_amount,
    ROUND(change_percent, 2) AS change_percent
FROM v_category_monthly_change
WHERE previous_revenue IS NOT NULL
ORDER BY change_amount ASC
LIMIT 1;


-- ============================================================
-- 9. Late-shipment analysis with CASE
-- ============================================================

CREATE OR REPLACE VIEW v_shipment_performance AS
SELECT
    o.order_id,
    o.required_date,
    o.shipped_date,
    o.shipped_date - o.required_date AS delivery_days,
    CASE
        WHEN o.shipped_date IS NULL THEN 'Not shipped'
        WHEN o.shipped_date <= o.required_date THEN 'On time'
        ELSE 'Late'
    END AS shipment_status,
    s.company_name AS shipper_name
FROM orders AS o
JOIN shippers AS s ON s.shipper_id = o.ship_via;

SELECT
    shipper_name,
    COUNT(*) FILTER (WHERE shipped_date IS NOT NULL) AS shipped_orders,
    COUNT(*) FILTER (WHERE shipment_status = 'Late') AS late_orders,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE shipment_status = 'Late')
        / NULLIF(COUNT(*) FILTER (WHERE shipped_date IS NOT NULL), 0),
        2
    ) AS late_percentage,
    ROUND(
        AVG(delivery_days) FILTER (WHERE shipment_status = 'Late'),
        2
    ) AS average_late_days
FROM v_shipment_performance
GROUP BY shipper_name
ORDER BY late_percentage DESC, average_late_days DESC;


-- ============================================================
-- 10. Product inventory status
-- ============================================================

CREATE OR REPLACE VIEW v_product_inventory_status AS
SELECT
    p.product_id,
    p.product_name,
    s.supplier_id,
    s.company_name AS supplier_name,
    c.category_name,
    p.unit_price,
    p.units_in_stock,
    p.units_on_order,
    p.reorder_level,
    (p.unit_price * p.units_in_stock)::numeric AS stock_value,
    CASE
        WHEN p.units_in_stock + p.units_on_order < p.reorder_level
            THEN 'Reorder needed'
        WHEN p.units_in_stock < p.reorder_level
            THEN 'Low'
        ELSE 'OK'
    END AS stock_status
FROM products AS p
JOIN suppliers AS s ON s.supplier_id = p.supplier_id
JOIN categories AS c ON c.category_id = p.category_id
WHERE p.discontinued = 0;

-- View result.
SELECT
    product_name,
    supplier_name,
    category_name,
    unit_price,
    units_in_stock,
    units_on_order,
    reorder_level,
    ROUND(stock_value, 2) AS stock_value,
    stock_status
FROM v_product_inventory_status
ORDER BY supplier_name, product_name;

-- Supplier summary for products that need reordering.
SELECT
    supplier_name,
    COUNT(*) FILTER (WHERE stock_status = 'Reorder needed') AS reorder_products,
    ROUND(
        SUM(stock_value) FILTER (WHERE stock_status = 'Reorder needed'),
        2
    ) AS total_stock_value
FROM v_product_inventory_status
GROUP BY supplier_id, supplier_name
HAVING COUNT(*) FILTER (WHERE stock_status = 'Reorder needed') > 0
ORDER BY reorder_products DESC, supplier_name;
