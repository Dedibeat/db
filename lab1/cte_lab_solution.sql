-- PostgreSQL solution for CTE Lab 1.
-- Run against the shared Northwind database configured for Lab 2.

-- 1. Orders with totals above the average order total.
WITH order_totals AS (
    SELECT
        o.order_id,
        o.customer_id,
        SUM(od.unit_price * od.quantity * (1 - od.discount)) AS order_total
    FROM orders AS o
    JOIN order_details AS od ON od.order_id = o.order_id
    GROUP BY o.order_id, o.customer_id
)
SELECT
    order_id,
    customer_id,
    ROUND(order_total::numeric, 2) AS order_total
FROM order_totals
WHERE order_total > (SELECT AVG(order_total) FROM order_totals)
ORDER BY order_total DESC, order_id;


-- 2. The three employees with the highest sales in 1997.
WITH employee_sales AS (
    SELECT
        e.employee_id,
        e.first_name,
        e.last_name,
        COALESCE(
            SUM(od.unit_price * od.quantity * (1 - od.discount)),
            0
        ) AS total_sales
    FROM employees AS e
    LEFT JOIN orders AS o
        ON o.employee_id = e.employee_id
       AND o.order_date >= DATE '1997-01-01'
       AND o.order_date <  DATE '1998-01-01'
    LEFT JOIN order_details AS od ON od.order_id = o.order_id
    GROUP BY e.employee_id, e.first_name, e.last_name
), ranked_employee_sales AS (
    SELECT
        employee_id,
        first_name,
        last_name,
        total_sales,
        ROW_NUMBER() OVER (ORDER BY total_sales DESC, employee_id) AS sales_rank
    FROM employee_sales
)
SELECT
    employee_id,
    first_name,
    last_name,
    ROUND(total_sales::numeric, 2) AS total_sales
FROM ranked_employee_sales
WHERE sales_rank <= 3
ORDER BY sales_rank;


-- 3. Products priced above their category's average.
WITH category_average_prices AS (
    SELECT
        c.category_id,
        AVG(p.unit_price) AS average_unit_price
    FROM categories AS c
    JOIN products AS p ON p.category_id = c.category_id
    GROUP BY c.category_id
)
SELECT
    p.product_id,
    p.product_name,
    p.category_id,
    p.unit_price
FROM products AS p
JOIN category_average_prices AS cap ON cap.category_id = p.category_id
WHERE p.unit_price > cap.average_unit_price
ORDER BY p.category_id, p.unit_price DESC, p.product_id;


-- 4. Employee reporting hierarchy, starting with employees without managers.
WITH RECURSIVE employee_hierarchy AS (
    SELECT
        e.employee_id,
        e.first_name,
        e.last_name,
        e.title,
        0 AS level
    FROM employees AS e
    WHERE e.reports_to IS NULL

    UNION ALL

    SELECT
        e.employee_id,
        e.first_name,
        e.last_name,
        e.title,
        eh.level + 1 AS level
    FROM employees AS e
    JOIN employee_hierarchy AS eh ON e.reports_to = eh.employee_id
)
SELECT employee_id, first_name, last_name, title, level
FROM employee_hierarchy
ORDER BY level, employee_id;


-- 5. Customers with more than five orders and over $10,000 in total spending.
WITH customer_order_counts AS (
    SELECT c.customer_id, COUNT(o.order_id) AS order_count
    FROM customers AS c
    LEFT JOIN orders AS o ON o.customer_id = c.customer_id
    GROUP BY c.customer_id
), customer_spending AS (
    SELECT
        c.customer_id,
        COALESCE(
            SUM(od.unit_price * od.quantity * (1 - od.discount)),
            0
        ) AS total_spent
    FROM customers AS c
    LEFT JOIN orders AS o ON o.customer_id = c.customer_id
    LEFT JOIN order_details AS od ON od.order_id = o.order_id
    GROUP BY c.customer_id
)
SELECT
    c.customer_id,
    c.company_name,
    coc.order_count,
    ROUND(cs.total_spent::numeric, 2) AS total_spent
FROM customers AS c
JOIN customer_order_counts AS coc ON coc.customer_id = c.customer_id
JOIN customer_spending AS cs ON cs.customer_id = c.customer_id
WHERE coc.order_count > 5
  AND cs.total_spent > 10000
ORDER BY cs.total_spent DESC, c.customer_id;


-- 6. Orders with a total greater than $5,000.
WITH calculated_orders AS (
    SELECT
        o.order_id,
        o.customer_id,
        SUM(od.unit_price * od.quantity * (1 - od.discount)) AS order_total
    FROM orders AS o
    JOIN order_details AS od ON od.order_id = o.order_id
    GROUP BY o.order_id, o.customer_id
)
SELECT
    order_id,
    customer_id,
    ROUND(order_total::numeric, 2) AS order_total
FROM calculated_orders
WHERE order_total > 5000
ORDER BY order_total DESC, order_id;
