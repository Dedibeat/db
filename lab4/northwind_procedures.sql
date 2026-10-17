-- Stored procedures: Northwind database
-- Author: Dugarjantsan Bilguun (23B1NUM1470)
-- Database: northwind, PostgreSQL 16 (snake_case column names)
--
-- How the procedures return results:
--   * Single values (new stock, message, yearly totals) -> INOUT parameters.
--   * Lists of rows (orders, customers)                  -> INOUT refcursor. Call it as:
--       BEGIN; CALL proc(...); FETCH ALL FROM <cursor name>; COMMIT;
-- Error examples run inside DO blocks that catch the exception and print it as a NOTICE.
-- Examples that change data run inside BEGIN ... ROLLBACK, so the Northwind data stays unchanged.


-- ============================================================
-- Task 1. spUpdateProductStock - reduce a product's stock
-- ============================================================

-- spUpdateProductStock: reduces units_in_stock of product p_product_id by p_quantity
-- and returns the new stock in new_units_in_stock.
-- A missing product, a non-positive quantity or too little stock raises an error and changes nothing.
CREATE OR REPLACE PROCEDURE spUpdateProductStock(
    p_product_id             INT,
    p_quantity               INT,
    INOUT new_units_in_stock INT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_product_name TEXT;
    v_stock        INT;
BEGIN
    -- The quantity must be positive
    IF p_quantity IS NULL OR p_quantity <= 0 THEN
        RAISE EXCEPTION 'Хасах тоо эерэг бүхэл тоо байх ёстой (өгсөн утга: %)', p_quantity;
    END IF;

    -- Find the product and lock its row against concurrent changes (FOR UPDATE)
    SELECT product_name, units_in_stock
    INTO v_product_name, v_stock
    FROM products
    WHERE product_id = p_product_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION '% дугаартай бүтээгдэхүүн олдсонгүй', p_product_id;
    END IF;

    -- Do not let the stock go negative
    IF v_stock < p_quantity THEN
        RAISE EXCEPTION '"%" бүтээгдэхүүний нөөцөд % ширхэг байгаа тул % ширхэг хасах боломжгүй',
            v_product_name, v_stock, p_quantity;
    END IF;

    -- Reduce the stock and return the new value
    UPDATE products
    SET units_in_stock = units_in_stock - p_quantity
    WHERE product_id = p_product_id
    RETURNING units_in_stock INTO new_units_in_stock;

    RAISE NOTICE '"%": % -> % ширхэг', v_product_name, v_stock, new_units_in_stock;
END;
$$;

-- Example 1.1: Reduce the stock of Chai (product_id = 1) by 5. It goes from 39 to 34.
BEGIN;
SELECT product_id, product_name, units_in_stock FROM products WHERE product_id = 1;
CALL spUpdateProductStock(1, 5);
SELECT product_id, product_name, units_in_stock FROM products WHERE product_id = 1;
ROLLBACK;

-- Example 1.2: Errors for a quantity above the stock and for a product that does not exist
DO $$
DECLARE
    v_stock INT;
BEGIN
    CALL spUpdateProductStock(1, 100, v_stock);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Алдаа: %', SQLERRM;
END;
$$;

DO $$
DECLARE
    v_stock INT;
BEGIN
    CALL spUpdateProductStock(999, 1, v_stock);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Алдаа: %', SQLERRM;
END;
$$;


-- ============================================================
-- Task 2. spInsertNewEmployee - add a new employee
-- ============================================================

-- spInsertNewEmployee: adds a new employee's employee_id, first_name, last_name and
-- birth_date to employees. The data is validated; on an error the EXCEPTION section
-- catches it and returns the message as text in p_message (the CALL itself never fails).
CREATE OR REPLACE PROCEDURE spInsertNewEmployee(
    p_employee_id   INT,
    p_first_name    TEXT,
    p_last_name     TEXT,
    p_birth_date    DATE,
    INOUT p_message TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- 1) Business rule checks
    IF p_employee_id IS NULL OR p_employee_id <= 0 THEN
        RAISE EXCEPTION 'EmployeeID эерэг бүхэл тоо байх ёстой';
    END IF;
    IF COALESCE(btrim(p_first_name), '') = '' OR COALESCE(btrim(p_last_name), '') = '' THEN
        RAISE EXCEPTION 'Нэр (FirstName) болон овог (LastName) хоосон байж болохгүй';
    END IF;
    IF p_birth_date IS NULL THEN
        RAISE EXCEPTION 'Төрсөн огноог (BirthDate) заавал оруулна';
    END IF;
    IF p_birth_date > CURRENT_DATE THEN
        RAISE EXCEPTION 'Төрсөн огноо (%) ирээдүйд байж болохгүй', p_birth_date;
    END IF;
    IF p_birth_date > CURRENT_DATE - INTERVAL '18 years' THEN
        RAISE EXCEPTION 'Ажилтан 18-аас доош настай байж болохгүй (төрсөн огноо: %)',
            p_birth_date;
    END IF;

    -- 2) Insert the employee. The database itself detects errors such as
    --    a duplicate ID or a name that is too long.
    INSERT INTO employees (employee_id, first_name, last_name, birth_date)
    VALUES (p_employee_id, btrim(p_first_name), btrim(p_last_name), p_birth_date);

    p_message := format('Амжилттай: %s %s (EmployeeID = %s) ажилтныг нэмлээ',
                        btrim(p_first_name), btrim(p_last_name), p_employee_id);
    RAISE NOTICE '%', p_message;
EXCEPTION
    -- 3) Catch each kind of error and return a clear message
    WHEN unique_violation THEN
        p_message := format('Алдаа: %s дугаартай ажилтан аль хэдийн бүртгэлтэй байна',
                            p_employee_id);
        RAISE NOTICE '%', p_message;
    WHEN string_data_right_truncation THEN
        p_message := format('Алдаа: нэр хэт урт байна (FirstName <= 10, LastName <= 20 тэмдэгт). %s',
                            SQLERRM);
        RAISE NOTICE '%', p_message;
    WHEN numeric_value_out_of_range THEN
        p_message := format('Алдаа: EmployeeID хэт их байна (%s). %s', p_employee_id, SQLERRM);
        RAISE NOTICE '%', p_message;
    WHEN OTHERS THEN
        p_message := 'Алдаа: ' || SQLERRM;
        RAISE NOTICE '%', p_message;
END;
$$;

-- Example 2.1: Add an employee with valid data (ID 10) and check it with SELECT
BEGIN;
CALL spInsertNewEmployee(10, 'Temuulen', 'Bold', '1998-04-12');
SELECT employee_id, first_name, last_name, birth_date FROM employees WHERE employee_id = 10;
ROLLBACK;

-- Example 2.2: Duplicate ID (ID 1 belongs to Nancy Davolio)
CALL spInsertNewEmployee(1, 'Anar', 'Bat', '1990-01-01');

-- Example 2.3: First name too long (first_name is VARCHAR(10))
CALL spInsertNewEmployee(11, 'Batbayarsaikhan', 'Dorj', '1995-03-15');

-- Example 2.4: Birth date in the future
CALL spInsertNewEmployee(12, 'Saraa', 'Ganbold', '2030-01-01');

-- Example 2.5: Empty first name
CALL spInsertNewEmployee(13, '', 'Dorj', '1990-01-01');


-- ============================================================
-- Task 3. spGetCustomerOrders - a customer's orders
-- ============================================================

-- spGetCustomerOrders: joins orders and customers and returns the order ID, order date
-- and ship name of every order of the given customer_id.
-- The customer_id is converted to upper case. An unknown customer raises an error.
CREATE OR REPLACE PROCEDURE spGetCustomerOrders(
    p_customer_id  TEXT,
    INOUT p_result refcursor DEFAULT 'customer_orders'
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- The customer must exist
    IF NOT EXISTS (SELECT 1 FROM customers WHERE customer_id = upper(btrim(p_customer_id))) THEN
        RAISE EXCEPTION '"%" кодтой харилцагч олдсонгүй', p_customer_id;
    END IF;

    OPEN p_result FOR
        SELECT o.order_id,
               o.order_date,
               o.ship_name,
               c.company_name
        FROM orders AS o
        JOIN customers AS c ON c.customer_id = o.customer_id
        WHERE c.customer_id = upper(btrim(p_customer_id))
        ORDER BY o.order_date, o.order_id;
END;
$$;

-- Example 3.1: Orders of customer ALFKI
BEGIN;
CALL spGetCustomerOrders('ALFKI');
FETCH ALL FROM customer_orders;
COMMIT;

-- Example 3.2: A lower-case ID ('vinet') works too
BEGIN;
CALL spGetCustomerOrders('vinet');
FETCH ALL FROM customer_orders;
COMMIT;

-- Example 3.3: Error for a customer that does not exist
DO $$
DECLARE
    v_cursor refcursor := 'missing_orders';
BEGIN
    CALL spGetCustomerOrders('XXXXX', v_cursor);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Алдаа: %', SQLERRM;
END;
$$;


-- ============================================================
-- Task 4. spYearlySalesReport - yearly sales report
-- ============================================================

-- spYearlySalesReport: returns the number of orders, the number of units sold and the
-- total sales amount (unit_price * quantity * (1 - discount)) of the given year,
-- from orders and order_details.
-- unit_price and discount are real, so the amount is calculated as numeric.
CREATE OR REPLACE PROCEDURE spYearlySalesReport(
    p_year            INT,
    INOUT order_count INT     DEFAULT NULL,
    INOUT units_sold  INT     DEFAULT NULL,
    INOUT total_sales NUMERIC DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_year IS NULL THEN
        RAISE EXCEPTION 'Оныг заавал оруулна';
    END IF;

    -- Orders from January 1 of the year up to January 1 of the next year
    SELECT COUNT(DISTINCT o.order_id),
           COALESCE(SUM(od.quantity), 0),
           COALESCE(ROUND(SUM(od.unit_price::NUMERIC * od.quantity
                              * (1 - od.discount::NUMERIC)), 2), 0)
    INTO order_count, units_sold, total_sales
    FROM orders AS o
    JOIN order_details AS od ON od.order_id = o.order_id
    WHERE o.order_date >= make_date(p_year, 1, 1)
      AND o.order_date <  make_date(p_year + 1, 1, 1);

    IF order_count = 0 THEN
        RAISE NOTICE '% онд захиалга бүртгэгдээгүй байна', p_year;
    END IF;
END;
$$;

-- Example 4.1: Report for 1996
CALL spYearlySalesReport(1996);

-- Example 4.2: Report for 1997
CALL spYearlySalesReport(1997);

-- Example 4.3: Report for 1998
CALL spYearlySalesReport(1998);


-- ============================================================
-- Task 5. spSearchCustomers - search customers
-- ============================================================

-- spSearchCustomers: searches by any one, any two or all three of company_name,
-- contact_name and city, and returns all columns of the matching customers.
-- Parameters that are not given (NULL or empty) are left out of the filter. Matching is
-- partial and ignores case (ILIKE). Giving no value at all raises an error.
CREATE OR REPLACE PROCEDURE spSearchCustomers(
    p_company_name TEXT DEFAULT NULL,
    p_contact_name TEXT DEFAULT NULL,
    p_city         TEXT DEFAULT NULL,
    INOUT p_result refcursor DEFAULT 'customers_found'
)
LANGUAGE plpgsql
AS $$
DECLARE
    -- Treat an empty string as NULL, i.e. "not given"
    v_company TEXT := NULLIF(btrim(p_company_name), '');
    v_contact TEXT := NULLIF(btrim(p_contact_name), '');
    v_city    TEXT := NULLIF(btrim(p_city), '');
BEGIN
    IF v_company IS NULL AND v_contact IS NULL AND v_city IS NULL THEN
        RAISE EXCEPTION 'company name, contact name, city-ийн дор хаяж нэгийг оруулна уу';
    END IF;

    OPEN p_result FOR
        SELECT c.*
        FROM customers AS c
        WHERE (v_company IS NULL OR c.company_name ILIKE '%' || v_company || '%')
          AND (v_contact IS NULL OR c.contact_name ILIKE '%' || v_contact || '%')
          AND (v_city    IS NULL OR c.city         ILIKE '%' || v_city    || '%')
        ORDER BY c.customer_id;
END;
$$;

-- Example 5.1: Search by city only (London)
BEGIN;
CALL spSearchCustomers(p_city => 'London');
FETCH ALL FROM customers_found;
COMMIT;

-- Example 5.2: Search by company name and contact name ('market', 'elizabeth')
BEGIN;
CALL spSearchCustomers(p_company_name => 'market', p_contact_name => 'elizabeth');
FETCH ALL FROM customers_found;
COMMIT;

-- Example 5.3: Search by all three fields ('alfreds', 'maria', 'berlin')
BEGIN;
CALL spSearchCustomers('alfreds', 'maria', 'berlin');
FETCH ALL FROM customers_found;
COMMIT;

-- Example 5.4: Error when no search value is given
DO $$
DECLARE
    v_cursor refcursor := 'no_filter';
BEGIN
    CALL spSearchCustomers(NULL, NULL, NULL, v_cursor);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Алдаа: %', SQLERRM;
END;
$$;
