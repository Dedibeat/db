# Past Midterm Queries — Cheat Sheet

From `lib/` (PostgreSQL, Northwind). Every task = **one helper UDF + one wrapper** (view / function / procedure).

## Templates

```sql
-- Scalar UDF
CREATE OR REPLACE FUNCTION udfX(p INT) RETURNS NUMERIC AS $$
DECLARE r NUMERIC;
BEGIN
    SELECT SUM(...) INTO r FROM ... WHERE col = p;
    RETURN r;
END; $$ LANGUAGE plpgsql;

-- Table-valued UDF
CREATE OR REPLACE FUNCTION fnX(p TEXT)
RETURNS TABLE (id INT, name TEXT, total NUMERIC) AS $$
BEGIN
    RETURN QUERY SELECT a::INT, b::TEXT, SUM(c)::NUMERIC FROM ... GROUP BY a, b;
END; $$ LANGUAGE plpgsql;

-- Procedure (no result set; use CALL)
CREATE OR REPLACE PROCEDURE spX(p INT) AS $$
BEGIN
    UPDATE ... ;            -- or RAISE NOTICE '%: %', a, b;
END; $$ LANGUAGE plpgsql;
```

Call: `SELECT udfX(1);` · `SELECT * FROM fnX('x');` · `CALL spX(1);`

## The 7 tasks

| File | Helper | Wrapper | Core |
| --- | --- | --- | --- |
| beverage | `udfCalculateTotalSalesByCategory(cat_id)` scalar | view `vwSalesByCategory` | `products → order_details`, `WHERE p.category_id = ...` |
| argentina / kk | `udfTotalSalesByCountry(country)` scalar | `spTotalSalesByCountries` | `customers → orders → order_details`, `c.country ILIKE ...` |
| shipper | `udfTotalShippingCostsByShipper(id)` scalar | `spCostsReportByEveryShipper()` table fn | `SUM(freight) FROM orders WHERE ship_via = id` |
| orderid / d1 | — | `fnEmployeeSalesReport(emp, start, end)` table fn | `GROUP BY order_id, order_date`, `order_date BETWEEN` |
| newyork / d2 | `udfCalculateSalesByEmployeeAndTerritory(name)` table fn | `spSalesPerformanceReportByTerritory` | needs `employee_territories` |
| percentage / d3 | `udfCalculateNewPrice(...)` scalar | proc `spUpdateProductPricesBySupplier(sup, pct)` | new = `unit_price * (1 + pct/100)` |

**"Report per X" wrapper — the short way** (no loop, no temp table):

```sql
CREATE OR REPLACE FUNCTION spTotalSalesByCountries()
RETURNS TABLE (country TEXT, total_sales NUMERIC) AS $$
BEGIN
    RETURN QUERY SELECT DISTINCT c.country::TEXT, udfTotalSalesByCountry(c.country)
                 FROM customers c ORDER BY 1;
END; $$ LANGUAGE plpgsql;
```

## Bugs in the lib/ answers — write it this way instead

**Territory (d2/newyork):** `t.territory_id = t.territory_id` joins nothing; `territory_id` is VARCHAR, not SMALLINT.

```sql
FROM employees e
JOIN orders o         ON o.employee_id = e.employee_id
JOIN order_details od ON od.order_id = o.order_id
WHERE e.employee_id IN (SELECT et.employee_id
                        FROM employee_territories et
                        JOIN territories t ON t.territory_id = et.territory_id
                        WHERE TRIM(t.territory_description) ILIKE territory_name)
GROUP BY e.employee_id
-- IN (...) not JOIN: 'New York' has 2 territory_ids, a JOIN would list each employee twice
```

**New price (d3/percentage):** `LIMIT 1` gives every product the *first* product's price. Price it per product:

```sql
CREATE OR REPLACE FUNCTION udfCalculateNewPrice(ProductID INT, Pct NUMERIC)
RETURNS NUMERIC AS $$
    SELECT unit_price * (1 + Pct/100) FROM products WHERE product_id = ProductID;
$$ LANGUAGE sql;

CREATE OR REPLACE PROCEDURE spUpdateProductPricesBySupplier(SupplierID INT, Pct NUMERIC) AS $$
BEGIN
    UPDATE products SET unit_price = udfCalculateNewPrice(product_id, Pct)
    WHERE supplier_id = SupplierID;
END; $$ LANGUAGE plpgsql;
```

## Gotchas

- Column types in `RETURNS TABLE` must match exactly → cast: `::INT`, `::TEXT`, `::NUMERIC`.
- Output column names = variables inside the function → qualify columns (`o.order_id`) to avoid "ambiguous".
- Changing a function's return type → `DROP FUNCTION` first; `CREATE OR REPLACE` won't do it.
- `PROCEDURE` can't return rows; if the task says "report", use a table function (or `RAISE NOTICE`).
- `ILIKE` = case-insensitive match; `||` concatenates names.
- Wrap a test of an UPDATE proc in `BEGIN; CALL ...; ROLLBACK;`.
