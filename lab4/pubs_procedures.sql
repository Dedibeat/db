-- Stored procedures: Pubs database
-- Author: Dugarjantsan Bilguun (23B1NUM1470)
-- Database: pubs (converted from MS SQL Server, see pubs_postgres.sql), PostgreSQL 16
--
-- How the procedures return results:
--   * Single values (totals, counts) -> INOUT parameters, shown as one row by CALL.
--   * Lists of rows                 -> INOUT refcursor. A PostgreSQL PROCEDURE cannot
--     return a SELECT result directly, so it opens a cursor instead. Call it as:
--       BEGIN; CALL proc(...); FETCH ALL FROM <cursor name>; COMMIT;
-- Error examples run inside DO blocks that catch the exception and print it as a NOTICE.
-- Examples that change data run inside BEGIN ... ROLLBACK, so the pubs data stays unchanged.


-- ============================================================
-- Setup. Check the converted pubs database
-- ============================================================

-- Example 0.1: Row count of every table (must equal the number of INSERTs in instpubs.sql)
SELECT 'authors' AS table_name, COUNT(*) AS row_count FROM authors
UNION ALL SELECT 'discounts',   COUNT(*) FROM discounts
UNION ALL SELECT 'employee',    COUNT(*) FROM employee
UNION ALL SELECT 'jobs',        COUNT(*) FROM jobs
UNION ALL SELECT 'pub_info',    COUNT(*) FROM pub_info
UNION ALL SELECT 'publishers',  COUNT(*) FROM publishers
UNION ALL SELECT 'roysched',    COUNT(*) FROM roysched
UNION ALL SELECT 'sales',       COUNT(*) FROM sales
UNION ALL SELECT 'stores',      COUNT(*) FROM stores
UNION ALL SELECT 'titleauthor', COUNT(*) FROM titleauthor
UNION ALL SELECT 'titles',      COUNT(*) FROM titles
ORDER BY table_name;

-- Example 0.2: The converted reptq1 procedure (WITH ROLLUP -> ROLLUP) works
BEGIN;
CALL reptq1();
FETCH ALL FROM reptq1;
COMMIT;

-- Example 0.3: The converted employee_insupd trigger rejects an invalid job level (job_lvl)
DO $$
BEGIN
    -- job_id = 2 (Chief Executive Officer) allows levels 200-250, so 10 is invalid
    INSERT INTO employee (emp_id, fname, lname, job_id, job_lvl)
    VALUES ('ABC12345M', 'Test', 'User', 2, 10);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Триггер зогсоолоо: %', SQLERRM;
END;
$$;


-- ============================================================
-- Task 1. spTotalSales - total sales amount for a date range
-- ============================================================

-- spTotalSales: returns the number of orders, the number of books sold and the total sales
-- amount recorded in sales from p_start_date to p_end_date (both days included).
-- sales has no price column, so the amount is qty * titles.price.
CREATE OR REPLACE PROCEDURE spTotalSales(
    p_start_date       DATE,
    p_end_date         DATE,
    INOUT order_count  INT     DEFAULT NULL,
    INOUT total_qty    INT     DEFAULT NULL,
    INOUT total_amount NUMERIC DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Validate the input dates
    IF p_start_date IS NULL OR p_end_date IS NULL THEN
        RAISE EXCEPTION 'Эхлэх болон дуусах огноог заавал оруулна';
    END IF;
    IF p_start_date > p_end_date THEN
        RAISE EXCEPTION 'Эхлэх огноо (%) дуусах огнооноос (%) хойно байна',
            p_start_date, p_end_date;
    END IF;

    -- An order is a (stor_id, ord_num) pair. ord_date is a TIMESTAMP, so the filter
    -- "< p_end_date + 1" includes the whole end day.
    SELECT COUNT(DISTINCT (s.stor_id, s.ord_num)),
           COALESCE(SUM(s.qty), 0),
           COALESCE(ROUND(SUM(s.qty * t.price), 2), 0)
    INTO order_count, total_qty, total_amount
    FROM sales AS s
    JOIN titles AS t ON t.title_id = s.title_id
    WHERE s.ord_date >= p_start_date
      AND s.ord_date <  p_end_date + 1;
END;
$$;

-- Example 1.1: Total sales in 1993
CALL spTotalSales('1993-01-01', '1993-12-31');

-- Example 1.2: Sales on 1994-09-13 and 1994-09-14 (checks that the end day is included)
CALL spTotalSales('1994-09-13', '1994-09-14');

-- Example 1.3: A start date after the end date raises an error
DO $$
DECLARE
    v_orders INT;
    v_qty    INT;
    v_amount NUMERIC;
BEGIN
    CALL spTotalSales('1994-12-31', '1993-01-01', v_orders, v_qty, v_amount);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Алдаа: %', SQLERRM;
END;
$$;


-- ============================================================
-- Task 2. spTopAuthors - top N authors by sales
-- ============================================================

-- spTopAuthors: joins titleauthor and sales, sums each author's sales amount
-- (qty * titles.price) and returns the top N authors by that amount.
-- Sales of a co-written title count in full for every co-author.
-- RANK() is used, so authors tied with the N-th place are returned too.
CREATE OR REPLACE PROCEDURE spTopAuthors(
    p_top_n        INT,
    INOUT p_result refcursor DEFAULT 'top_authors'
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- N must be a positive integer
    IF p_top_n IS NULL OR p_top_n < 1 THEN
        RAISE EXCEPTION 'N нь 1-ээс багагүй бүхэл тоо байх ёстой (өгсөн утга: %)', p_top_n;
    END IF;

    OPEN p_result FOR
        WITH author_sales AS (
            -- Total sales amount of each author
            SELECT a.au_id                          AS author_id,
                   a.au_fname || ' ' || a.au_lname  AS author_name,
                   ROUND(SUM(s.qty * t.price), 2)   AS total_sales
            FROM titleauthor AS ta
            JOIN sales   AS s ON s.title_id = ta.title_id
            JOIN titles  AS t ON t.title_id = ta.title_id
            JOIN authors AS a ON a.au_id = ta.au_id
            GROUP BY a.au_id, a.au_fname, a.au_lname
        ),
        ranked AS (
            -- Rank the authors by amount, highest first
            SELECT RANK() OVER (ORDER BY total_sales DESC) AS sales_rank, *
            FROM author_sales
        )
        SELECT sales_rank, author_id, author_name, total_sales
        FROM ranked
        WHERE sales_rank <= p_top_n
        ORDER BY sales_rank, author_id;
END;
$$;

-- Example 2.1: Top 5 authors by sales
BEGIN;
CALL spTopAuthors(5);
FETCH ALL FROM top_authors;
COMMIT;

-- Example 2.2: N = 3. Two authors tie for 3rd place, so 4 rows are returned
BEGIN;
CALL spTopAuthors(3);
FETCH ALL FROM top_authors;
COMMIT;


-- ============================================================
-- Task 3. spSearchBooks - search books by title
-- ============================================================

-- spSearchBooks: searches book titles for the given text, ignoring case (ILIKE), and
-- returns the title, price, price range and publication date.
CREATE OR REPLACE PROCEDURE spSearchBooks(
    p_title        TEXT,
    INOUT p_result refcursor DEFAULT 'books_found'
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Reject an empty search
    IF p_title IS NULL OR btrim(p_title) = '' THEN
        RAISE EXCEPTION 'Хайх үгээ оруулна уу';
    END IF;

    OPEN p_result FOR
        SELECT t.title                AS title_name,
               t.price::NUMERIC(10,2) AS price,
               -- Put the price into one of three ranges
               CASE
                   WHEN t.price IS NULL THEN 'Үнэ тогтоогоогүй'
                   WHEN t.price < 10    THEN 'Хямд (< $10)'
                   WHEN t.price < 20    THEN 'Дунд ($10 - $19.99)'
                   ELSE                      'Үнэтэй (>= $20)'
               END                    AS price_range,
               t.pubdate::DATE        AS publication_date
        FROM titles AS t
        WHERE t.title ILIKE '%' || btrim(p_title) || '%'
        ORDER BY t.title;
END;
$$;

-- Example 3.1: Books with "computer" in the title
BEGIN;
CALL spSearchBooks('computer');
FETCH ALL FROM books_found;
COMMIT;

-- Example 3.2: Books with "cook" in the title
BEGIN;
CALL spSearchBooks('cook');
FETCH ALL FROM books_found;
COMMIT;


-- ============================================================
-- Task 4. spGenerateMonthlySalesReport - monthly sales report
-- ============================================================

-- spGenerateMonthlySalesReport: returns the total sales amount (qty * price), the number
-- of orders and the number of books sold in the given year and month, from sales.
CREATE OR REPLACE PROCEDURE spGenerateMonthlySalesReport(
    p_year                   INT,
    p_month                  INT,
    INOUT total_sales_amount NUMERIC DEFAULT NULL,
    INOUT number_of_orders   INT     DEFAULT NULL,
    INOUT books_sold         INT     DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_month_start DATE;
BEGIN
    -- Validate the year and month
    IF p_year IS NULL OR p_month IS NULL THEN
        RAISE EXCEPTION 'Он, сарыг заавал оруулна';
    END IF;
    IF p_month NOT BETWEEN 1 AND 12 THEN
        RAISE EXCEPTION 'Сар 1-12 хооронд байх ёстой (өгсөн утга: %)', p_month;
    END IF;

    -- First day of the month; every sale before the first day of the next month counts
    v_month_start := make_date(p_year, p_month, 1);

    SELECT COALESCE(ROUND(SUM(s.qty * t.price), 2), 0),
           COUNT(DISTINCT (s.stor_id, s.ord_num)),
           COALESCE(SUM(s.qty), 0)
    INTO total_sales_amount, number_of_orders, books_sold
    FROM sales AS s
    JOIN titles AS t ON t.title_id = s.title_id
    WHERE s.ord_date >= v_month_start
      AND s.ord_date <  v_month_start + INTERVAL '1 month';
END;
$$;

-- Example 4.1: Report for May 1993
CALL spGenerateMonthlySalesReport(1993, 5);

-- Example 4.2: Report for September 1994
CALL spGenerateMonthlySalesReport(1994, 9);

-- Example 4.3: A month without sales (January 1993) returns zeros
CALL spGenerateMonthlySalesReport(1993, 1);

-- Example 4.4: An invalid month (13) raises an error
DO $$
DECLARE
    v_amount NUMERIC;
    v_orders INT;
    v_books  INT;
BEGIN
    CALL spGenerateMonthlySalesReport(1994, 13, v_amount, v_orders, v_books);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Алдаа: %', SQLERRM;
END;
$$;


-- ============================================================
-- Task 5. spTransferInventory - move books from one store to another
-- ============================================================

-- spTransferInventory: moves p_qty copies of title p_title_id from store p_from_store
-- to store p_to_store. A store's number of copies is the qty in sales.
--   1) Check the input, that the title is in titleauthor, and the source store's stock.
--   2) Subtract qty from the source store's rows, starting with the latest order.
--   3) If the target store has the title, add to its qty; otherwise insert a new row.
-- If any step fails, the EXCEPTION section catches it, undoes every change and
-- returns the error message as text in p_status.
CREATE OR REPLACE PROCEDURE spTransferInventory(
    p_title_id     TEXT,
    p_from_store   TEXT,
    p_to_store     TEXT,
    p_qty          INT,
    INOUT p_status TEXT DEFAULT NULL
)
LANGUAGE plpgsql
AS $$
DECLARE
    v_available  INT;           -- copies of the title in the source store
    v_remaining  INT;           -- copies still to subtract from the source store
    v_take       INT;           -- copies subtracted from one row
    v_row        RECORD;
    v_target_ord VARCHAR(20);   -- target store's order that holds the title
BEGIN
    -- 1) Input checks
    IF p_qty IS NULL OR p_qty <= 0 THEN
        RAISE EXCEPTION 'Шилжүүлэх тоо эерэг байх ёстой (өгсөн утга: %)', p_qty;
    END IF;
    IF p_from_store = p_to_store THEN
        RAISE EXCEPTION 'Эх ба хүлээн авах дэлгүүр ижил байна (%)', p_from_store;
    END IF;

    -- The title must have an author (a row in titleauthor)
    IF NOT EXISTS (SELECT 1 FROM titleauthor WHERE title_id = p_title_id) THEN
        RAISE EXCEPTION '% ном titleauthor хүснэгтэд бүртгэлгүй байна', p_title_id;
    END IF;

    -- The source store must have enough copies
    SELECT COALESCE(SUM(qty), 0) INTO v_available
    FROM sales
    WHERE stor_id = p_from_store AND title_id = p_title_id;

    IF v_available < p_qty THEN
        RAISE EXCEPTION '% дэлгүүрт % номын % ширхэг байгаа тул % ширхэгийг шилжүүлэх боломжгүй',
            p_from_store, p_title_id, v_available, p_qty;
    END IF;

    -- 2) Subtract from the source store's rows, latest order first
    v_remaining := p_qty;
    FOR v_row IN
        SELECT ord_num, qty
        FROM sales
        WHERE stor_id = p_from_store AND title_id = p_title_id
        ORDER BY ord_date DESC, ord_num DESC
        FOR UPDATE
    LOOP
        EXIT WHEN v_remaining = 0;
        v_take := LEAST(v_row.qty, v_remaining);

        UPDATE sales
        SET qty = qty - v_take
        WHERE stor_id = p_from_store AND ord_num = v_row.ord_num AND title_id = p_title_id;

        v_remaining := v_remaining - v_take;
    END LOOP;

    -- 3) Does the target store already have this title?
    SELECT ord_num INTO v_target_ord
    FROM sales
    WHERE stor_id = p_to_store AND title_id = p_title_id
    ORDER BY ord_date DESC, ord_num DESC
    LIMIT 1;

    IF FOUND THEN
        -- It does, so add to its quantity
        UPDATE sales
        SET qty = qty + p_qty
        WHERE stor_id = p_to_store AND ord_num = v_target_ord AND title_id = p_title_id;

        p_status := format('Амжилттай: %s номын %s ширхэгийг %s -> %s дэлгүүрт шилжүүлж, '
                           '%s захиалгын тоог нэмэгдүүллээ',
                           p_title_id, p_qty, p_from_store, p_to_store, v_target_ord);
    ELSE
        -- It does not, so insert a new row. Errors from this INSERT are caught separately.
        BEGIN
            INSERT INTO sales (stor_id, ord_num, ord_date, qty, payterms, title_id)
            VALUES (p_to_store, 'TRF-' || to_char(now(), 'YYMMDDHH24MISS'), now(),
                    p_qty, 'Transfer', p_title_id)
            RETURNING ord_num INTO v_target_ord;
        EXCEPTION WHEN OTHERS THEN
            -- Keep the error code (SQLSTATE) and re-raise it with an explanatory message
            RAISE EXCEPTION USING
                ERRCODE = SQLSTATE,
                MESSAGE = format('%s дэлгүүрт %s номыг оруулах үед алдаа гарлаа: %s',
                                 p_to_store, p_title_id, SQLERRM);
        END;

        p_status := format('Амжилттай: %s номын %s ширхэгийг %s -> %s дэлгүүрт шилжүүлж, '
                           'шинэ %s мөр нэмлээ',
                           p_title_id, p_qty, p_from_store, p_to_store, v_target_ord);
    END IF;

    RAISE NOTICE '%', p_status;
EXCEPTION
    WHEN OTHERS THEN
        -- Every change made in this block is rolled back automatically (subtransaction)
        p_status := format('Алдаа (%s): %s', SQLSTATE, SQLERRM);
        RAISE NOTICE '%', p_status;
END;
$$;

-- Example 5.1: The target store has the title (7066 -> 7067, PS2091, 10 copies).
-- Order D4482 of store 7067 goes from 10 to 20, store 7066 from 75 to 65.
BEGIN;
SELECT stor_id, ord_num, qty FROM sales WHERE title_id = 'PS2091' ORDER BY stor_id;
CALL spTransferInventory('PS2091', '7066', '7067', 10);
SELECT stor_id, ord_num, qty FROM sales WHERE title_id = 'PS2091' ORDER BY stor_id;
ROLLBACK;

-- Example 5.2: The target store does not have the title (8042 -> 7896, BU1032, 4 copies).
-- Store 7896 has no BU1032, so a new row (TRF-...) is inserted.
BEGIN;
SELECT stor_id, ord_num, qty FROM sales WHERE title_id = 'BU1032' ORDER BY stor_id;
CALL spTransferInventory('BU1032', '8042', '7896', 4);
SELECT stor_id, ord_num, qty, payterms FROM sales WHERE title_id = 'BU1032' ORDER BY stor_id;
ROLLBACK;

-- Example 5.3: Not enough copies in the source store (6380 has only 3 of PS2091)
CALL spTransferInventory('PS2091', '6380', '7066', 5);

-- Example 5.4: Moving to a store that does not exist (9999) fails the INSERT's foreign key.
-- The error is caught and returned, and the copies taken from 8042 are put back.
CALL spTransferInventory('BU1032', '8042', '9999', 2);
SELECT stor_id, ord_num, qty FROM sales WHERE title_id = 'BU1032' ORDER BY stor_id;
