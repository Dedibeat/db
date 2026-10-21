# DB Midterm Cheat Sheet

Covers labs 1–4: CTEs, views, temporary tables and UDFs, stored procedures.
Live, editable version: https://claude.ai/artifact/MUmKMydnPzqzw8GUbZqwjC

## Exam at a glance

All four labs ran on PostgreSQL 16 against Northwind (labs 1–4) and Pubs (lab 4), so write PostgreSQL unless a question says SQL Server.

- **Line revenue (Northwind):** `od.unit_price * od.quantity * (1 - od.discount)`. Round with `ROUND(SUM(...)::numeric, 2)`.
- **Sale amount (Pubs):** `s.qty * t.price`, because `sales` has no price column. One Pubs order = the pair `(stor_id, ord_num)`.
- **Terms:** харагдац = view · материалчлагдсан харагдац = materialized view · түр хүснэгт = temp table · UDF = user-defined function · хадгалагдсан процедур = stored procedure · цонхны функц = window function.

| Table | Key columns | Joins to |
| --- | --- | --- |
| customers | customer_id (text, e.g. 'ALFKI'), company_name, contact_name, city, country | orders.customer_id |
| orders | order_id, customer_id, employee_id, order_date, required_date, shipped_date, ship_via, freight, ship_name, ship_country | order_details.order_id; shippers.shipper_id = orders.ship_via |
| order_details | order_id, product_id, unit_price, quantity, discount | products.product_id |
| products | product_id, product_name, supplier_id, category_id, unit_price, units_in_stock, units_on_order, reorder_level, discontinued (0/1) | categories, suppliers |
| categories / suppliers / shippers | category_id, category_name / supplier_id, company_name / shipper_id, company_name | products, orders |
| employees | employee_id, first_name, last_name, title, birth_date, hire_date, reports_to | reports_to → employee_id (self-join, recursive CTE) |
| Pubs: titles | title_id, title, type, pub_id, price, pubdate | titleauthor, sales, publishers |
| Pubs: authors | au_id, au_fname, au_lname, city, state | titleauthor.au_id |
| Pubs: titleauthor | au_id, title_id (PK both) | bridge table: authors ↔ titles (many-to-many) |
| Pubs: sales | stor_id, ord_num, ord_date, qty, payterms, title_id (PK stor_id + ord_num + title_id) | stores.stor_id, titles.title_id |
| Pubs: stores / publishers | stor_id, stor_name, city / pub_id, pub_name | sales / titles |

## Lab 1 — CTEs (WITH … AS)

A CTE is a named result set that exists only for the one statement right after it; it stores nothing.

- **Syntax:** one `WITH`, CTEs separated by commas: `WITH a AS (...), b AS (...) SELECT ...`. A later CTE may read an earlier one.
- **Scope:** only the next statement. It can be referenced several times inside that statement.
- **Why over a subquery:** readability (logic named and read top-down), reuse inside the statement, and recursion. Speed is usually the same: PostgreSQL 12+ inlines a non-recursive CTE used once; force a choice with `AS MATERIALIZED` / `AS NOT MATERIALIZED`.
- **Recursive CTE:** anchor member (start rows) + `UNION ALL` + recursive member that joins back to the CTE. It stops when the recursive member returns no rows.
- **PostgreSQL vs SQL Server:** PG needs `WITH RECURSIVE`. SQL Server writes plain `WITH`, stops at 100 levels by default, change with `OPTION (MAXRECURSION n)` (0 = no limit).
- **Type gotcha:** anchor and recursive columns must have the same types. Cast: `NULL::text AS manager_name`, `(first_name || ' ' || last_name)::text AS path`.
- **Window functions cannot go in WHERE.** Compute the rank in a CTE, filter in the outer query.
- **Keep zero rows with LEFT JOIN:** put the date filter in `ON`, not `WHERE`, and wrap the sum in `COALESCE(SUM(...), 0)`.

```sql
-- Orders above the average order total
WITH order_totals AS (
    SELECT o.order_id, o.customer_id,
           SUM(od.unit_price * od.quantity * (1 - od.discount)) AS order_total
    FROM orders o
    JOIN order_details od ON od.order_id = o.order_id
    GROUP BY o.order_id, o.customer_id
)
SELECT order_id, customer_id, ROUND(order_total::numeric, 2) AS order_total
FROM order_totals
WHERE order_total > (SELECT AVG(order_total) FROM order_totals)
ORDER BY order_total DESC;

-- Top 3 employees by 1997 sales: chained CTEs + ROW_NUMBER
WITH employee_sales AS (
    SELECT e.employee_id, e.first_name, e.last_name,
           COALESCE(SUM(od.unit_price * od.quantity * (1 - od.discount)), 0) AS total_sales
    FROM employees e
    LEFT JOIN orders o ON o.employee_id = e.employee_id
         AND o.order_date >= DATE '1997-01-01' AND o.order_date < DATE '1998-01-01'
    LEFT JOIN order_details od ON od.order_id = o.order_id
    GROUP BY e.employee_id, e.first_name, e.last_name
), ranked AS (
    SELECT *, ROW_NUMBER() OVER (ORDER BY total_sales DESC) AS rn
    FROM employee_sales
)
SELECT employee_id, first_name, last_name, ROUND(total_sales::numeric, 2) AS total_sales
FROM ranked
WHERE rn <= 3;

-- Employee hierarchy: recursive CTE
WITH RECURSIVE h AS (
    SELECT employee_id, first_name, last_name, title, 0 AS level      -- anchor: the boss
    FROM employees
    WHERE reports_to IS NULL
    UNION ALL
    SELECT e.employee_id, e.first_name, e.last_name, e.title, h.level + 1  -- recursive step
    FROM employees e
    JOIN h ON e.reports_to = h.employee_id
)
SELECT * FROM h ORDER BY level, employee_id;
```

## Lab 2 — Views (харагдац)

A view is a saved SELECT that holds no rows and re-runs on every read; a materialized view stores the result and stays stale until `REFRESH`.

- **Why views:** hide join/aggregate complexity, restrict columns and rows (security), one shared definition, and the base tables can change without breaking callers.
- **`CREATE OR REPLACE VIEW`** may only add columns at the end. Renaming, removing or retyping a column needs `DROP VIEW v;` then `CREATE`. `DROP VIEW` never touches table data; `CASCADE` also drops views built on it.
- **Views on views** are fine: `v_order_lines` → `v_category_monthly` → `v_category_monthly_change` (LAG).
- **Auto-updatable view (PG):** exactly one table (or updatable view) in FROM, and no `DISTINCT`, `GROUP BY`, `HAVING`, aggregates, window functions, `LIMIT/OFFSET`, `UNION/INTERSECT/EXCEPT` or top-level `WITH`. Computed columns are read-only; plain columns stay updatable.
- **`WITH CHECK OPTION`:** an INSERT/UPDATE through the view must produce a row the view still shows. Without it, the row is saved and silently disappears from the view. Default is `CASCADED` (also checks the conditions of underlying views); `LOCAL` checks only this view.
- **Lab 2 test:** `UPDATE v_active_products SET discontinued = 1 WHERE product_id = 3;` fails with "new row violates check option for view", because the view is `WHERE discontinued = 0`.
- **Materialized view:** `CREATE MATERIALIZED VIEW` (no `OR REPLACE`). Plain `REFRESH` locks out readers. `REFRESH ... CONCURRENTLY` keeps reads working but needs a UNIQUE index on plain columns (no WHERE) and an already-populated view. `WITH NO DATA` creates it empty and unreadable until the first refresh.
- **Use a materialized view when** the query is expensive (big joins/aggregates), read far more often than data changes, and slightly old data is OK (monthly reports, dashboards).
- **SQL Server equivalent:** an indexed view (`WITH SCHEMABINDING` + unique clustered index), kept up to date automatically.

| | View | Materialized view |
| --- | --- | --- |
| Stores rows | No, only the query | Yes, a snapshot |
| Freshness | Always current | Stale until REFRESH |
| Read cost | Re-runs the query | Reads stored rows |
| Indexes | No | Yes |
| INSERT/UPDATE through it | Yes, if simple | No |
| Create | CREATE OR REPLACE VIEW | CREATE MATERIALIZED VIEW |

```sql
-- Updatable view that rejects rows leaving it
CREATE OR REPLACE VIEW v_active_products AS
SELECT product_id, product_name, unit_price, units_in_stock, discontinued
FROM products
WHERE discontinued = 0
WITH CHECK OPTION;

-- Materialized monthly sales, refreshable without blocking reads
CREATE MATERIALIZED VIEW mv_monthly_sales AS
SELECT DATE_TRUNC('month', o.order_date)::date AS year_month,
       o.ship_country AS country,
       COUNT(DISTINCT o.order_id) AS order_count,
       SUM((od.unit_price * od.quantity * (1 - od.discount))::numeric) AS total_revenue
FROM orders o
JOIN order_details od ON od.order_id = o.order_id
GROUP BY 1, 2;

CREATE UNIQUE INDEX ON mv_monthly_sales (year_month, country);
REFRESH MATERIALIZED VIEW CONCURRENTLY mv_monthly_sales;

-- Pivot with conditional aggregation (one column per category, 0 not NULL)
SELECT c.customer_id,
       SUM(CASE WHEN cat.category_name = 'Beverages'
                THEN od.unit_price * od.quantity * (1 - od.discount) ELSE 0 END) AS beverages,
       SUM(CASE WHEN cat.category_name = 'Seafood'
                THEN od.unit_price * od.quantity * (1 - od.discount) ELSE 0 END) AS seafood
FROM customers c
LEFT JOIN orders o         ON o.customer_id = c.customer_id
LEFT JOIN order_details od ON od.order_id = o.order_id
LEFT JOIN products p       ON p.product_id = od.product_id
LEFT JOIN categories cat   ON cat.category_id = p.category_id
GROUP BY c.customer_id;
```

## Lab 3 — Temporary tables and UDFs

A temp table holds real rows for one session (or one transaction) and only its own connection can see it; a UDF returns a value or a table and is called inside a query.

### Temporary tables (түр хүснэгт)

- **Two ways to create:** `CREATE TEMP TABLE t AS SELECT ...` (columns come from the query) or `CREATE TEMP TABLE t (id INT PRIMARY KEY, ...)` then `INSERT INTO t SELECT ...`.
- **Lifetime:** dropped automatically when the session ends. `ON COMMIT PRESERVE ROWS` (default) · `ON COMMIT DELETE ROWS` (empties at commit) · `ON COMMIT DROP` (dropped at commit; used inside functions).
- **Visibility:** private to the creating session, stored in its own `pg_temp` schema. A temp table hides a permanent table of the same name.
- **After `DROP TABLE low_stock`**, `SELECT * FROM low_stock` fails with `relation "low_stock" does not exist`. Another session gets the same error even before the drop.
- **Can have** a primary key, indexes and `ANALYZE`. Autovacuum skips temp tables, so run `ANALYZE` yourself. Not WAL-logged, so writes are fast but not crash-safe.
- **Re-run safety:** start with `DROP TABLE IF EXISTS t;` or use `CREATE TEMP TABLE IF NOT EXISTS`.
- **SQL Server:** `#t` = local (session), `##t` = global (all sessions, dropped when the creator disconnects and nobody uses it), `DECLARE @t TABLE (...)` = table variable (batch scope), `SELECT ... INTO #t FROM ...`.
- **Temp table vs CTE (task 10 EXPLAIN):** on small Northwind data the CTE version was faster (no create/drop cost). A temp table wins when a large intermediate result is reused by several statements or needs an index.

### User-defined functions (UDF)

- **Scalar function:** `RETURNS INT/TEXT/NUMERIC`, used like a built-in: `SELECT ship_days(order_date, shipped_date) FROM orders`.
- **Table function:** `RETURNS TABLE (col type, ...)` or `RETURNS SETOF`, used in FROM: `SELECT * FROM shipper_performance(1997) WHERE late_pct > 5`.
- **`LANGUAGE sql`:** body is one or more SQL statements, can be inlined. **`LANGUAGE plpgsql`:** adds `DECLARE`, `IF`, loops, `RAISE`, `EXCEPTION`, `RETURN QUERY`.
- **Volatility:** `IMMUTABLE` = same inputs give the same result forever, reads no tables (allowed in index expressions; `ship_days`, `pct_of`). `STABLE` = same result within one statement, may read tables but not change them (`shipper_performance`, `now()`). `VOLATILE` (default) = may change data or vary each call (`restock_products`, `random()`).
- **Parameters:** `p_` prefix (lab rule), defaults `p_min_orders INT DEFAULT 10`. Call by position `f(1997, 10)` or by name `f(p_year => 1998, p_min_orders => 80)`.
- **RETURNS TABLE types must match the SELECT exactly:** `varchar` → `::TEXT`, `COUNT(*)` is `BIGINT`, `ROUND` returns `numeric`.
- **`real` → `numeric` has no implicit cast:** call `freight_class(freight::numeric)`, otherwise "function does not exist".
- **NULL-safe math:** `date - NULL` is NULL. Use `NULLIF(p_whole, 0)` to avoid division by zero.
- **plpgsql toolkit:** `SELECT ... INTO v` · `IF NOT FOUND THEN` · `GET DIAGNOSTICS v = ROW_COUNT` · `RAISE NOTICE '%', v` · `RAISE EXCEPTION 'bad value %', p` · `EXCEPTION WHEN OTHERS THEN ... SQLERRM` · `PERFORM f()` (call, discard result) · `DO $$ ... $$` (anonymous block).
- **SQL Server UDF limits:** no side effects. No INSERT/UPDATE/DELETE on permanent tables, no `#temp`, no `TRY...CATCH`, no `THROW/RAISERROR`, no dynamic `EXEC`, no transactions; only a local `@table` variable can change. Its three kinds: scalar, inline table-valued (single `RETURN SELECT`), multi-statement table-valued (`RETURNS @t TABLE`). A PostgreSQL `VOLATILE` function can modify data, so `restock_products` works there.

```sql
-- Temp table built from a query, used twice, then dropped
DROP TABLE IF EXISTS low_stock;
CREATE TEMP TABLE low_stock AS
SELECT product_id, product_name, category_id,
       reorder_level - (units_in_stock + units_on_order) AS shortage
FROM products
WHERE units_in_stock + units_on_order < reorder_level AND discontinued = 0;

SELECT * FROM low_stock ORDER BY shortage DESC;
SELECT category_id, COUNT(*) FROM low_stock GROUP BY category_id;
DROP TABLE IF EXISTS low_stock;

-- Scalar SQL function
CREATE OR REPLACE FUNCTION ship_days(p_order_date DATE, p_shipped_date DATE)
RETURNS INT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT p_shipped_date - p_order_date;   -- NULL if not shipped
$$;

-- Table function with validation
CREATE OR REPLACE FUNCTION shipper_performance(p_year INT, p_min_orders INT DEFAULT 10)
RETURNS TABLE (shipper_name TEXT, orders_count BIGINT, late_pct NUMERIC)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    IF p_year NOT BETWEEN 1996 AND 1998 THEN
        RAISE EXCEPTION 'p_year must be 1996-1998 (got %)', p_year;
    END IF;
    RETURN QUERY
    SELECT s.company_name::TEXT,
           COUNT(*),
           ROUND(100.0 * COUNT(*) FILTER (WHERE o.shipped_date > o.required_date)
                 / NULLIF(COUNT(*), 0), 1)
    FROM orders o
    JOIN shippers s ON s.shipper_id = o.ship_via
    WHERE EXTRACT(YEAR FROM o.order_date) = p_year
    GROUP BY s.company_name
    HAVING COUNT(*) >= p_min_orders;
END;
$$;

SELECT * FROM shipper_performance(p_year => 1997) ORDER BY late_pct DESC;
```

## Lab 4 — Stored procedures

A PostgreSQL procedure (PG 11+) runs with `CALL`, cannot be used inside a SELECT, and hands results back through `INOUT` parameters or a `refcursor`.

- **Single values** (totals, counts, a status message) → `INOUT x TYPE DEFAULT NULL`. `CALL p(...)` prints them as one row.
- **A list of rows** → `INOUT p_result refcursor DEFAULT 'name'` and `OPEN p_result FOR SELECT ...`. Read it in the same transaction: `BEGIN; CALL p(...); FETCH ALL FROM name; COMMIT;` The cursor dies at the end of the transaction.
- **Transactions:** a procedure may `COMMIT`/`ROLLBACK` inside its body when called at top level; a function never can. Not allowed inside a block that has an `EXCEPTION` handler.
- **`EXCEPTION` block = implicit savepoint.** When an error is caught, every change made since that block's `BEGIN` is undone (lab task 5.4: the copies taken from store 8042 came back).
- **Two error styles from the lab:** (1) `RAISE EXCEPTION` → the CALL fails with ERROR; (2) catch it and return text: `EXCEPTION WHEN OTHERS THEN p_message := 'Error: ' || SQLERRM;` → the CALL succeeds and shows the message.
- **Named conditions:** `unique_violation` (23505, duplicate key) · `foreign_key_violation` (23503) · `not_null_violation` (23502) · `check_violation` (23514) · `string_data_right_truncation` (22001, text too long) · `numeric_value_out_of_range` (22003) · `division_by_zero` (22012) · `OTHERS`. Inside a handler: `SQLSTATE` = code, `SQLERRM` = message.
- **Patterns used:** validate first (`IF p_qty IS NULL OR p_qty <= 0 THEN RAISE ...`) · `IF NOT EXISTS (SELECT 1 FROM ...)` · lock the row: `SELECT ... FOR UPDATE` · `UPDATE ... RETURNING col INTO v` · `FOR r IN SELECT ... LOOP ... EXIT WHEN ...; END LOOP;` · `format('%s moved %s', a, b)`.
- **Optional search filters:** `WHERE (v_city IS NULL OR c.city ILIKE '%' || v_city || '%')`, with `v_city := NULLIF(btrim(p_city), '')` so an empty string counts as "not given".
- **Date ranges:** whole end day of a timestamp: `ord_date >= p_start AND ord_date < p_end + 1`. One month: `>= make_date(y, m, 1) AND < make_date(y, m, 1) + INTERVAL '1 month'`.

| Task | SQL Server (T-SQL) | PostgreSQL |
| --- | --- | --- |
| Create | `CREATE PROCEDURE spX @id INT, @total MONEY OUTPUT AS BEGIN ... END` | `CREATE OR REPLACE PROCEDURE spX(p_id INT, INOUT total NUMERIC DEFAULT NULL) LANGUAGE plpgsql AS $$ BEGIN ... END; $$;` |
| Run | `EXEC spX 5, @t OUTPUT;` | `CALL spX(5);` |
| Return rows | a plain `SELECT` inside the procedure | `OPEN refcursor FOR SELECT ...` + `FETCH ALL` |
| Variables | `DECLARE @v INT; SET @v = 1;` | `DECLARE v INT;` then `v := 1;` |
| Errors | `BEGIN TRY ... END TRY BEGIN CATCH ... END CATCH`, `THROW` / `RAISERROR` | `BEGIN ... EXCEPTION WHEN ... THEN ... END;`, `RAISE EXCEPTION` |
| Rows affected | `@@ROWCOUNT` | `GET DIAGNOSTICS v = ROW_COUNT` / `FOUND` |
| Misc. | `GETDATE()`, `ISNULL`, `TOP 5`, `+` for strings, `WITH ROLLUP`, `[Order Details]` | `now()`, `COALESCE`, `LIMIT 5`, `\|\|`, `GROUP BY ROLLUP(...)`, `order_details` |
| Types (Pubs conversion) | `BIT`, `TINYINT`, `MONEY`, `DATETIME`, `IMAGE` | `BOOLEAN`, `SMALLINT`, `NUMERIC(19,4)`, `TIMESTAMP`, `BYTEA` |

```sql
-- Single values back through INOUT, errors raised
CREATE OR REPLACE PROCEDURE spUpdateProductStock(
    p_product_id INT,
    p_quantity   INT,
    INOUT new_units_in_stock INT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_stock INT;
BEGIN
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION 'Quantity must be positive (got %)', p_quantity;
    END IF;

    SELECT units_in_stock INTO v_stock
    FROM products WHERE product_id = p_product_id
    FOR UPDATE;                                   -- lock the row

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product % not found', p_product_id;
    END IF;
    IF v_stock < p_quantity THEN
        RAISE EXCEPTION 'Only % in stock', v_stock;
    END IF;

    UPDATE products
    SET units_in_stock = units_in_stock - p_quantity
    WHERE product_id = p_product_id
    RETURNING units_in_stock INTO new_units_in_stock;
END;
$$;

BEGIN; CALL spUpdateProductStock(1, 5); ROLLBACK;   -- test without keeping the change

-- A list of rows back through a refcursor
CREATE OR REPLACE PROCEDURE spGetCustomerOrders(
    p_customer_id TEXT,
    INOUT p_result refcursor DEFAULT 'customer_orders'
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM customers WHERE customer_id = upper(p_customer_id)) THEN
        RAISE EXCEPTION 'Customer "%" not found', p_customer_id;
    END IF;
    OPEN p_result FOR
        SELECT o.order_id, o.order_date, o.ship_name
        FROM orders o
        WHERE o.customer_id = upper(p_customer_id)
        ORDER BY o.order_date;
END;
$$;

BEGIN;
CALL spGetCustomerOrders('ALFKI');
FETCH ALL FROM customer_orders;
COMMIT;

-- Catch the error and return it as text (the CALL itself succeeds)
CREATE OR REPLACE PROCEDURE spInsertNewEmployee(
    p_employee_id INT, p_first_name TEXT, p_last_name TEXT, p_birth_date DATE,
    INOUT p_message TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_birth_date > CURRENT_DATE THEN
        RAISE EXCEPTION 'Birth date % is in the future', p_birth_date;
    END IF;
    INSERT INTO employees (employee_id, first_name, last_name, birth_date)
    VALUES (p_employee_id, p_first_name, p_last_name, p_birth_date);
    p_message := 'Inserted employee ' || p_employee_id;
EXCEPTION
    WHEN unique_violation THEN
        p_message := 'Error: employee ' || p_employee_id || ' already exists';
    WHEN OTHERS THEN
        p_message := 'Error: ' || SQLERRM;
END;
$$;
```

## Theory quick-reference

Most multiple-choice questions come down to three comparisons: where intermediate results live, function vs procedure, and how ranking functions treat ties.

| | Subquery | CTE | Temp table | View | Materialized view |
| --- | --- | --- | --- | --- | --- |
| Lives for | 1 query | 1 statement | Session (or transaction) | Until DROP | Until DROP |
| Stores rows | No | No | Yes | No | Yes |
| Reusable | No | Within the statement | Many statements, same session | Any session/user | Any session/user |
| Other sessions see it | — | — | No | Yes | Yes |
| Indexes | No | No | Yes | No | Yes |
| Recursive | No | Yes | — | Via a CTE inside | Via a CTE inside |
| Data current | Yes | Yes | Snapshot at fill time | Yes | Until REFRESH |

| | Function (UDF) | Procedure |
| --- | --- | --- |
| Called with | `SELECT f(...)` or `FROM f(...)` | `CALL p(...)` |
| Returns | `RETURNS` value, `TABLE` or `SETOF` | `INOUT`/`OUT` params, refcursor |
| Inside a query | Yes | No |
| COMMIT/ROLLBACK inside | Never | Yes, at top-level call |
| Volatility label | IMMUTABLE / STABLE / VOLATILE | None |
| Changes data | PG: yes if VOLATILE; SQL Server: never | Yes |
| Best for | Computing a value or a reusable result set | Actions that change data, multi-step jobs |

| total_sales | ROW_NUMBER() | RANK() | DENSE_RANK() | NTILE(2) |
| --- | --- | --- | --- | --- |
| 100 | 1 | 1 | 1 | 1 |
| 90 | 2 | 2 | 2 | 1 |
| 90 | 3 | 2 | 2 | 2 |
| 80 | 4 | 4 | 3 | 2 |

**Facts worth memorizing:**

- Logical order: `FROM/JOIN → WHERE → GROUP BY → HAVING → SELECT (window functions) → DISTINCT → ORDER BY → LIMIT`. So a SELECT alias or a window function cannot be used in WHERE; ORDER BY can use both.
- WHERE filters rows before grouping; HAVING filters groups after it and may use aggregates.
- `COUNT(*)` counts rows; `COUNT(col)` skips NULLs. After a LEFT JOIN, `COUNT(o.order_id)` gives 0 for customers with no orders.
- Aggregates ignore NULL; `SUM` over zero rows is NULL, so wrap in `COALESCE(..., 0)`.
- `NULL = NULL` is unknown, not true: use `IS NULL`. `'a' || NULL` is NULL; `CONCAT('a', NULL)` is `'a'`.
- Integer division truncates: `5 / 2 = 2`. Write `100.0 * part / total`.
- `LIKE` is case-sensitive in PostgreSQL; `ILIKE` is not. `%` = any characters, `_` = one character.
- `UNION` removes duplicates, `UNION ALL` keeps them (faster, used in recursive CTEs). `EXCEPT` returning 0 rows proved the two lab-3 ABC versions give the same result.
- A view is a virtual table; dropping it never deletes table data.
- `$$ ... $$` is dollar quoting: the function body needs no escaped single quotes.
- `EXPLAIN` shows the plan; `EXPLAIN ANALYZE` actually runs the query and shows real times; `BUFFERS` adds cache hits/reads.

## Query-writing toolkit and gotchas

These are the building blocks that came up in every lab; check the list at the end before handing in a query.

| Need | Write | Lab |
| --- | --- | --- |
| Rank overall | `ROW_NUMBER() / RANK() / DENSE_RANK() OVER (ORDER BY total DESC)` | 1, 4 |
| Top N per group | `RANK() OVER (PARTITION BY category_id ORDER BY total DESC)`, filter `<= N` outside | 2 |
| Previous row | `LAG(revenue) OVER (PARTITION BY category_id ORDER BY month)`; NULL on the first row | 2 |
| Grand total on every row | `SUM(revenue) OVER ()` | 3 |
| Running total | `SUM(revenue) OVER (ORDER BY revenue DESC ROWS UNBOUNDED PRECEDING)` | 3 |
| Quartile score 1–4 | `NTILE(4) OVER (ORDER BY frequency)` | 3 |
| Count with a condition | `COUNT(*) FILTER (WHERE status = 'Late')` = `SUM(CASE WHEN status = 'Late' THEN 1 ELSE 0 END)` | 2, 3 |
| Labels from values | `CASE WHEN x IS NULL THEN ... WHEN x < 50 THEN ... ELSE ... END` | 2, 3, 4 |
| Safe percent | `ROUND(100.0 * part / NULLIF(total, 0), 1)` | 2, 3 |
| Month bucket | `DATE_TRUNC('month', order_date)::date` | 2 |
| Year filter | `EXTRACT(YEAR FROM order_date) = 1997`, or the faster range `>= DATE '1997-01-01' AND < DATE '1998-01-01'` | 1, 3 |
| Days between dates | `shipped_date - order_date` (integer days) | 3 |
| Full years | `EXTRACT(YEAR FROM age(hire_date))` | 3 |
| Build a date | `make_date(p_year, p_month, 1)` | 4 |
| Text search | `title ILIKE '%' \|\| btrim(p_title) \|\| '%'` | 4 |
| Unpivot columns to rows | `CROSS JOIN LATERAL (VALUES ('Beverages', p.beverages), ...) AS d(name, revenue)` | 2 |
| Undo test changes | `BEGIN; ... ROLLBACK;` | 2–4 |

**Before you submit:**

- [ ] Every non-aggregated SELECT column is in GROUP BY.
- [ ] `ROUND(x, 2)` on a real/float is cast first: `ROUND(x::numeric, 2)` (`round(double precision, integer)` does not exist).
- [ ] Need rows with no matches (0 orders, 0 sales)? LEFT JOIN, conditions in ON, `COUNT(col)` and `COALESCE(SUM(...), 0)`.
- [ ] Revenue includes the discount: `* (1 - discount)`.
- [ ] Window-function filter is in an outer query or CTE, not in WHERE.
- [ ] Ties: RANK/DENSE_RANK return extra rows at the cut-off, ROW_NUMBER does not. Pick the one the question asks for.
- [ ] Division protected with `NULLIF(..., 0)` and done in decimals (`100.0 *`).
- [ ] Function: `CREATE OR REPLACE FUNCTION`, `p_` parameters, `RETURNS`, `LANGUAGE`, volatility, `$$ ... $$`, ends with `;`.
- [ ] Procedure: `CREATE OR REPLACE PROCEDURE`, results via `INOUT`, called with `CALL`, refcursor read inside `BEGIN ... COMMIT`.
- [ ] Temp table dropped at the end with `DROP TABLE IF EXISTS`.
- [ ] Every statement ends with a semicolon.

## Practice exercises

Ten short tasks, one or two per lab. Write each on paper first, then check the Answers section; the expected results come from running the answers on the local Northwind and Pubs databases.

1. **CTE (Lab 1).** Show the categories whose average product price is above the average price of all products: category_name, product_count, avg_price (2 decimals). *Expect 3 rows, Meat/Poultry first.*
2. **CTE + ranking (Lab 1).** For each country, show the customer with the highest total revenue, keeping ties: country, company_name, revenue. *Expect 21 rows; Germany is QUICK-Stop.*
3. **Recursive CTE (Lab 1).** List everyone who reports to Andrew Fuller (employee_id 2) directly or indirectly, with level = 1 for direct reports. *Expect 8 rows, levels 1–2.*
4. **View (Lab 2).** Create `v_employee_orders` (employee_id, full_name, order_count, revenue) that keeps employees with no orders at 0. Use it to list employees with revenue above 150 000. Then: does `UPDATE v_employee_orders SET full_name = 'X' WHERE employee_id = 1` work? *Expect 4 rows.*
5. **WITH CHECK OPTION (Lab 2).** Create `v_cheap_products` = products with unit_price < 20, WITH CHECK OPTION. Chai (id 1) costs 18 and Mishi Kobe Niku (id 9) costs 97. Predict each result: (a) `SET unit_price = 15 WHERE product_id = 1`, (b) `SET unit_price = 25 WHERE product_id = 1`, (c) `SET unit_price = 10 WHERE product_id = 9`.
6. **Temp table (Lab 3).** Put the 1997 orders that shipped after their required_date into temp table `late_1997` (order_id, shipper_name, days_late). Report late orders and average days late per shipper, then drop the table. *Expect 22 rows in the table and 3 shippers.*
7. **Scalar UDF (Lab 3).** Write `line_total(p_unit_price NUMERIC, p_quantity INT, p_discount NUMERIC) RETURNS NUMERIC`, rounded to 2 decimals, with the right volatility. Use it to show the 5 largest order lines with product names. *Top line: order 10981, Côte de Blaye, 15810.00.*
8. **Table function (Lab 3).** Write `customer_orders(p_customer_id TEXT, p_year INT)` returning order_id, order_date, order_total, and accept lower-case IDs. Call it by position for ('alfki', 1997) and by name for 1998. *Expect 3 orders in 1997.*
9. **Procedure with INOUT (Lab 4, Pubs).** Write `spStoreSales(p_stor_id)` that returns order_count, books_sold and total_amount (qty × price) through INOUT parameters and raises an error for an unknown store. *Store 7066: 2 orders, 125 books, 1821.25.*
10. **Procedure with refcursor (Lab 4, Pubs).** Write `spAuthorTitles(p_last_name)` that returns author name, title and price for authors whose last name contains the text, in any case. *'ringer' gives 4 rows.*

## Answers

Every answer below ran without errors on PostgreSQL 16 (inside `BEGIN ... ROLLBACK`, so nothing was left in the databases).

- **4:** No. PostgreSQL answers "cannot update view … Views containing GROUP BY are not automatically updatable".
- **5:** (a) succeeds: 15 < 20, so the row stays in the view. (b) fails: "new row violates check option for view". (c) `UPDATE 0`, no error: product 9 is not visible through the view, so the WHERE matches nothing.
- **7:** `IMMUTABLE`: the result depends only on the arguments and reads no table.
- **8:** `STABLE`: it reads tables but changes nothing.

```sql
-- 1. CTE
WITH category_avg AS (
    SELECT c.category_name, COUNT(*) AS product_count, AVG(p.unit_price) AS avg_price
    FROM categories c
    JOIN products p ON p.category_id = c.category_id
    GROUP BY c.category_name
)
SELECT category_name, product_count, ROUND(avg_price::numeric, 2) AS avg_price
FROM category_avg
WHERE avg_price > (SELECT AVG(unit_price) FROM products)
ORDER BY avg_price DESC;

-- 2. CTE + RANK per country (RANK keeps ties)
WITH customer_revenue AS (
    SELECT c.country, c.company_name,
           SUM(od.unit_price * od.quantity * (1 - od.discount)) AS revenue
    FROM customers c
    JOIN orders o         ON o.customer_id = c.customer_id
    JOIN order_details od ON od.order_id = o.order_id
    GROUP BY c.country, c.company_name
), ranked AS (
    SELECT *, RANK() OVER (PARTITION BY country ORDER BY revenue DESC) AS rnk
    FROM customer_revenue
)
SELECT country, company_name, ROUND(revenue::numeric, 2) AS revenue
FROM ranked
WHERE rnk = 1
ORDER BY revenue DESC;

-- 3. Recursive CTE: anchor = Fuller's direct reports
WITH RECURSIVE team AS (
    SELECT employee_id, first_name || ' ' || last_name AS full_name, 1 AS level
    FROM employees
    WHERE reports_to = 2
    UNION ALL
    SELECT e.employee_id, e.first_name || ' ' || e.last_name, t.level + 1
    FROM employees e
    JOIN team t ON e.reports_to = t.employee_id
)
SELECT * FROM team ORDER BY level, employee_id;

-- 4. View with LEFT JOIN + COALESCE
CREATE OR REPLACE VIEW v_employee_orders AS
SELECT e.employee_id,
       e.first_name || ' ' || e.last_name AS full_name,
       COUNT(DISTINCT o.order_id) AS order_count,
       COALESCE(SUM((od.unit_price * od.quantity * (1 - od.discount))::numeric), 0) AS revenue
FROM employees e
LEFT JOIN orders o         ON o.employee_id = e.employee_id
LEFT JOIN order_details od ON od.order_id = o.order_id
GROUP BY e.employee_id, e.first_name, e.last_name;

SELECT employee_id, full_name, order_count, ROUND(revenue, 2) AS revenue
FROM v_employee_orders
WHERE revenue > 150000
ORDER BY revenue DESC;

-- 5. CHECK OPTION view
CREATE VIEW v_cheap_products AS
SELECT product_id, product_name, unit_price
FROM products
WHERE unit_price < 20
WITH CHECK OPTION;

-- 6. Temp table
DROP TABLE IF EXISTS late_1997;
CREATE TEMP TABLE late_1997 AS
SELECT o.order_id,
       s.company_name AS shipper_name,
       o.shipped_date - o.required_date AS days_late
FROM orders o
JOIN shippers s ON s.shipper_id = o.ship_via
WHERE o.order_date >= DATE '1997-01-01' AND o.order_date < DATE '1998-01-01'
  AND o.shipped_date > o.required_date;

SELECT shipper_name, COUNT(*) AS late_orders, ROUND(AVG(days_late), 1) AS avg_days_late
FROM late_1997
GROUP BY shipper_name
ORDER BY late_orders DESC;

DROP TABLE IF EXISTS late_1997;

-- 7. Scalar UDF (cast the real columns to numeric when calling)
CREATE OR REPLACE FUNCTION line_total(p_unit_price NUMERIC, p_quantity INT, p_discount NUMERIC)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT ROUND(p_unit_price * p_quantity * (1 - p_discount), 2);
$$;

SELECT od.order_id, p.product_name,
       line_total(od.unit_price::numeric, od.quantity, od.discount::numeric) AS line_total
FROM order_details od
JOIN products p ON p.product_id = od.product_id
ORDER BY line_total DESC
LIMIT 5;

-- 8. Table function (order_id is smallint, so cast to match RETURNS TABLE)
CREATE OR REPLACE FUNCTION customer_orders(p_customer_id TEXT, p_year INT)
RETURNS TABLE (order_id INT, order_date DATE, order_total NUMERIC)
LANGUAGE sql
STABLE
AS $$
    SELECT o.order_id::INT, o.order_date,
           ROUND(SUM((od.unit_price * od.quantity * (1 - od.discount))::numeric), 2)
    FROM orders o
    JOIN order_details od ON od.order_id = o.order_id
    WHERE o.customer_id = upper(p_customer_id)
      AND EXTRACT(YEAR FROM o.order_date) = p_year
    GROUP BY o.order_id, o.order_date
    ORDER BY o.order_date;
$$;

SELECT * FROM customer_orders('alfki', 1997);
SELECT * FROM customer_orders(p_customer_id => 'ALFKI', p_year => 1998);

-- 9. Procedure with INOUT (Pubs)
CREATE OR REPLACE PROCEDURE spStoreSales(
    p_stor_id          TEXT,
    INOUT order_count  INT     DEFAULT NULL,
    INOUT books_sold   INT     DEFAULT NULL,
    INOUT total_amount NUMERIC DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM stores WHERE stor_id = p_stor_id) THEN
        RAISE EXCEPTION 'Store % does not exist', p_stor_id;
    END IF;

    SELECT COUNT(DISTINCT s.ord_num),
           COALESCE(SUM(s.qty), 0),
           COALESCE(ROUND(SUM(s.qty * t.price), 2), 0)
    INTO order_count, books_sold, total_amount
    FROM sales s
    JOIN titles t ON t.title_id = s.title_id
    WHERE s.stor_id = p_stor_id;
END;
$$;

CALL spStoreSales('7066');   -- 2 | 125 | 1821.25
CALL spStoreSales('9999');   -- ERROR: Store 9999 does not exist

-- 10. Procedure with refcursor (Pubs)
CREATE OR REPLACE PROCEDURE spAuthorTitles(
    p_last_name    TEXT,
    INOUT p_result refcursor DEFAULT 'author_titles'
)
LANGUAGE plpgsql
AS $$
BEGIN
    OPEN p_result FOR
        SELECT a.au_fname || ' ' || a.au_lname AS author_name,
               t.title,
               t.price::NUMERIC(10,2) AS price
        FROM authors a
        JOIN titleauthor ta ON ta.au_id = a.au_id
        JOIN titles t       ON t.title_id = ta.title_id
        WHERE a.au_lname ILIKE '%' || p_last_name || '%'
        ORDER BY author_name, t.title;
END;
$$;

BEGIN;
CALL spAuthorTitles('ringer');
FETCH ALL FROM author_titles;
COMMIT;
```
