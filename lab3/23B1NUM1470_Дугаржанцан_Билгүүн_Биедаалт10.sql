-- Бие даалт 10: Түр хүснэгт (Temporary Table) ба хэрэглэгчийн тодорхойлсон функц (UDF)
-- Гүйцэтгэсэн: Дугаржанцан Билгүүн (23B1NUM1470)
-- Өгөгдлийн сан: Northwind, PostgreSQL 16


-- ============================================================
-- Даалгавар 1. Нөөц дуусах дөхсөн бүтээгдэхүүний түр хүснэгт
-- ============================================================

DROP TABLE IF EXISTS low_stock;

CREATE TEMP TABLE low_stock AS
SELECT
    product_id,
    product_name,
    category_id,
    units_in_stock,
    units_on_order,
    reorder_level,
    reorder_level - (units_in_stock + units_on_order) AS shortage
FROM products
WHERE units_in_stock + units_on_order < reorder_level
  AND discontinued = 0;

-- (а) Дутагдлаар буурах дарааллаар бүх мөр
SELECT *
FROM low_stock
ORDER BY shortage DESC;

-- (б) Ангилал тус бүрийн дутагдалтай бүтээгдэхүүний тоо
SELECT c.category_name, COUNT(*) AS product_count
FROM low_stock AS ls
JOIN categories AS c ON c.category_id = ls.category_id
GROUP BY c.category_name
ORDER BY product_count DESC, c.category_name;

DROP TABLE IF EXISTS low_stock;


-- ============================================================
-- Даалгавар 2. ship_days() - хүргэлтийн хоногийг тооцох скаляр функц
-- ============================================================

CREATE OR REPLACE FUNCTION ship_days(p_order_date DATE, p_shipped_date DATE)
RETURNS INT
LANGUAGE sql
IMMUTABLE
AS $$
    -- p_shipped_date нь NULL бол хасах үйлдэл өөрөө NULL буцаана
    SELECT p_shipped_date - p_order_date;
$$;

-- 1997 оны захиалгуудын дундаж хүргэлтийн хоног
SELECT ROUND(AVG(ship_days(order_date, shipped_date)), 1) AS avg_ship_days
FROM orders
WHERE EXTRACT(YEAR FROM order_date) = 1997;

-- 1997 оны хамгийн удаан хүргэгдсэн 5 захиалга
SELECT order_id, customer_id, order_date, shipped_date,
       ship_days(order_date, shipped_date) AS ship_days
FROM orders
WHERE EXTRACT(YEAR FROM order_date) = 1997
  AND shipped_date IS NOT NULL
ORDER BY ship_days DESC, order_id
LIMIT 5;

-- Хүргэгдээгүй захиалгын тоо
SELECT COUNT(*) AS not_shipped_orders
FROM orders
WHERE ship_days(order_date, shipped_date) IS NULL;


-- ============================================================
-- Даалгавар 3. Туршлагатай ажилтнуудын түр хүснэгт
-- ============================================================

DROP TABLE IF EXISTS senior_staff;

CREATE TEMP TABLE senior_staff (
    employee_id  INT PRIMARY KEY,
    full_name    TEXT,
    title        TEXT,
    hire_date    DATE,
    years_worked INT
);

INSERT INTO senior_staff (employee_id, full_name, title, hire_date, years_worked)
SELECT
    employee_id,
    first_name || ' ' || last_name,
    title,
    hire_date,
    EXTRACT(YEAR FROM age(hire_date))
FROM employees
WHERE hire_date < DATE '1994-01-01';

-- Ажилласан жилээр буурах дарааллаар
SELECT *
FROM senior_staff
ORDER BY years_worked DESC, employee_id;

-- Ажилласан жилийн дундаж
SELECT ROUND(AVG(years_worked), 1) AS avg_years_worked
FROM senior_staff;

DROP TABLE IF EXISTS senior_staff;


-- ============================================================
-- Даалгавар 4. freight_class() - тээврийн зардлын ангилал
-- ============================================================

CREATE OR REPLACE FUNCTION freight_class(p_freight NUMERIC)
RETURNS TEXT
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT CASE
        WHEN p_freight IS NULL THEN 'Тодорхойгүй'
        WHEN p_freight < 50    THEN 'Бага'
        WHEN p_freight <= 150  THEN 'Дунд'
        ELSE 'Өндөр'
    END;
$$;

-- freight багана real төрөлтэй тул NUMERIC параметрт ::numeric болгож дамжуулна.

-- 1997 оны захиалгууд ангилал тус бүрээр
SELECT
    freight_class(freight::numeric) AS freight_class,
    COUNT(*) AS orders_count,
    ROUND(SUM(freight::numeric), 2) AS total_freight,
    ROUND(AVG(freight::numeric), 2) AS avg_freight
FROM orders
WHERE EXTRACT(YEAR FROM order_date) = 1997
GROUP BY freight_class(freight::numeric)
ORDER BY avg_freight;

-- 1997 онд 'Өндөр' ангилалд орсон захиалга хамгийн олонтой 5 улс
SELECT ship_country, COUNT(*) AS high_freight_orders
FROM orders
WHERE EXTRACT(YEAR FROM order_date) = 1997
  AND freight_class(freight::numeric) = 'Өндөр'
GROUP BY ship_country
ORDER BY high_freight_orders DESC, ship_country
LIMIT 5;


-- ============================================================
-- Даалгавар 5. Харилцагчийн идэвхийн түр хүснэгт
-- ============================================================

DROP TABLE IF EXISTS customer_activity;

-- LEFT JOIN тул захиалгагүй харилцагч ч orders_count = 0-ээр орно
CREATE TEMP TABLE customer_activity AS
SELECT
    c.customer_id,
    COUNT(o.order_id) AS orders_count,
    MIN(o.order_date) AS first_order,
    MAX(o.order_date) AS last_order,
    COALESCE(SUM(o.freight::numeric), 0) AS total_freight
FROM customers AS c
LEFT JOIN orders AS o ON o.customer_id = c.customer_id
GROUP BY c.customer_id;

-- (а) Хамгийн олон захиалга хийсэн 10 харилцагч
SELECT ca.customer_id, c.company_name, c.country, c.city, ca.orders_count
FROM customer_activity AS ca
JOIN customers AS c ON c.customer_id = ca.customer_id
ORDER BY ca.orders_count DESC, ca.customer_id
LIMIT 10;

-- (б) 1998 онд захиалга хийгээгүй боловч өмнө нь захиалж байсан харилцагчид
SELECT ca.customer_id, c.company_name, c.country, ca.orders_count, ca.last_order
FROM customer_activity AS ca
JOIN customers AS c ON c.customer_id = ca.customer_id
WHERE ca.orders_count > 0
  AND ca.last_order < DATE '1998-01-01'
ORDER BY ca.last_order, ca.customer_id;

-- (в) Улс тус бүрийн харилцагч, идэвхтэй харилцагч, нийт freight
SELECT
    c.country,
    COUNT(*) AS customers_count,
    COUNT(*) FILTER (WHERE ca.orders_count > 0) AS active_customers,
    ROUND(SUM(ca.total_freight), 2) AS total_freight
FROM customer_activity AS ca
JOIN customers AS c ON c.customer_id = ca.customer_id
GROUP BY c.country
ORDER BY total_freight DESC, c.country;

DROP TABLE IF EXISTS customer_activity;


-- ============================================================
-- Даалгавар 6. shipper_performance(p_year) - хүснэгт буцаадаг функц
-- ============================================================

CREATE OR REPLACE FUNCTION shipper_performance(p_year INT, p_min_orders INT DEFAULT 10)
RETURNS TABLE (
    shipper_name   TEXT,
    orders_count   BIGINT,
    avg_ship_days  NUMERIC,
    late_orders    BIGINT,
    late_pct       NUMERIC
)
LANGUAGE plpgsql
STABLE
AS $$
BEGIN
    IF p_year NOT BETWEEN 1996 AND 1998 THEN
        RAISE EXCEPTION 'p_year нь 1996-1998 хооронд байх ёстой (өгсөн утга: %)', p_year;
    END IF;

    RETURN QUERY
    SELECT
        s.company_name::TEXT,
        COUNT(*),
        ROUND(AVG(ship_days(o.order_date, o.shipped_date)), 1),
        COUNT(*) FILTER (WHERE o.shipped_date > o.required_date),
        ROUND(100.0 * COUNT(*) FILTER (WHERE o.shipped_date > o.required_date)
              / NULLIF(COUNT(*), 0), 1)
    FROM orders AS o
    JOIN shippers AS s ON s.shipper_id = o.ship_via
    WHERE EXTRACT(YEAR FROM o.order_date) = p_year
    GROUP BY s.company_name
    HAVING COUNT(*) >= p_min_orders;
END;
$$;

-- Байрлалаар дуудах
SELECT *
FROM shipper_performance(1997, 10)
ORDER BY late_pct DESC;

-- Нэрээр (=>) дуудах
SELECT *
FROM shipper_performance(p_year => 1998, p_min_orders => 80)
ORDER BY orders_count DESC;

-- Үр дүнг WHERE-ээр шүүх
SELECT shipper_name, avg_ship_days, late_pct
FROM shipper_performance(1996)
WHERE late_pct > 5;

-- Буруу он өгвөл алдаа гарна. Скрипт зогсохгүйн тулд DO блокоор барьж мессежийг харуулна.
DO $$
BEGIN
    PERFORM * FROM shipper_performance(2000);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Алдаа: %', SQLERRM;
END;
$$;


-- ============================================================
-- Даалгавар 7. pct_of() функц ба ангиллын орлогын бүтэц
-- ============================================================


CREATE OR REPLACE FUNCTION pct_of(p_part NUMERIC, p_whole NUMERIC)
RETURNS NUMERIC
LANGUAGE sql
IMMUTABLE
AS $$
    -- p_whole нь 0 бол NULLIF нь NULL болгоно; NULL-д хуваавал NULL гарна
    SELECT ROUND(100 * p_part / NULLIF(p_whole, 0), 1);
$$;

DROP TABLE IF EXISTS category_revenue;

-- 1997 оны ангилал бүрийн хямдрал хассан орлого ба борлуулсан тоо ширхэг
CREATE TEMP TABLE category_revenue AS
SELECT
    c.category_name,
    ROUND(SUM((od.unit_price * od.quantity * (1 - od.discount))::numeric), 2) AS revenue,
    SUM(od.quantity) AS units_sold
FROM order_details AS od
JOIN orders AS o ON o.order_id = od.order_id
JOIN products AS p ON p.product_id = od.product_id
JOIN categories AS c ON c.category_id = p.category_id
WHERE EXTRACT(YEAR FROM o.order_date) = 1997
GROUP BY c.category_name;

-- Эзлэх хувь ба хуримтлагдсан хувь. SUM(revenue) OVER () нь нийт орлого.
SELECT
    category_name,
    revenue,
    units_sold,
    pct_of(revenue, SUM(revenue) OVER ()) AS revenue_pct,
    pct_of(SUM(revenue) OVER (ORDER BY revenue DESC), SUM(revenue) OVER ()) AS cum_pct
FROM category_revenue
ORDER BY revenue DESC;

-- Нийт орлогын 50%-ийг бүрдүүлэгч ангиллууд: өмнөх ангиллуудын хуримтлагдсан
-- хувь (cum_pct - revenue_pct) 50-д хүрээгүй бол тухайн ангилал орно.
SELECT category_name, revenue_pct, cum_pct
FROM (
    SELECT
        category_name,
        pct_of(revenue, SUM(revenue) OVER ()) AS revenue_pct,
        pct_of(SUM(revenue) OVER (ORDER BY revenue DESC), SUM(revenue) OVER ()) AS cum_pct
    FROM category_revenue
) AS t
WHERE cum_pct - revenue_pct < 50
ORDER BY cum_pct;

DROP TABLE IF EXISTS category_revenue;


-- ============================================================
-- Даалгавар 8. customer_rfm() - функц доторх түр хүснэгт, сегментчлэл
-- ============================================================

CREATE OR REPLACE FUNCTION customer_rfm(p_asof DATE DEFAULT DATE '1998-05-06')
RETURNS TABLE (
    customer_id   TEXT,
    company_name  TEXT,
    recency_days  INT,
    frequency     BIGINT,
    monetary      NUMERIC,
    r_score       INT,
    f_score       INT,
    m_score       INT,
    segment       TEXT
)
LANGUAGE plpgsql
AS $$
BEGIN
    -- Ижил transaction дотор дахин дуудахад алдаа гарахгүй
    DROP TABLE IF EXISTS rfm_base;

    -- 1-р алхам: харилцагч бүрийн R, F, M утга
    CREATE TEMP TABLE rfm_base ON COMMIT DROP AS
    SELECT
        c.customer_id::TEXT AS customer_id,
        c.company_name::TEXT AS company_name,
        p_asof - MAX(o.order_date) AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM((od.unit_price * od.quantity * (1 - od.discount))::numeric) AS monetary
    FROM customers AS c
    JOIN orders AS o ON o.customer_id = c.customer_id
    JOIN order_details AS od ON od.order_id = o.order_id
    WHERE o.order_date <= p_asof
    GROUP BY c.customer_id, c.company_name;

    -- 2-р алхам: индекс ба статистик
    CREATE INDEX ON rfm_base (customer_id);
    ANALYZE rfm_base;

    -- 3-р алхам: NTILE(4)-ээр оноо өгч, CASE-ээр сегментлэх.
    -- Recency бага байх нь сайн тул DESC эрэмбээр хамгийн шинэ нь 4 оноо авна.
    RETURN QUERY
    SELECT
        s.customer_id,
        s.company_name,
        s.recency_days,
        s.frequency,
        s.monetary,
        s.r_score,
        s.f_score,
        s.m_score,
        CASE
            WHEN s.r_score >= 3 AND s.f_score >= 3 THEN 'Champion'
            WHEN s.r_score >= 3 THEN 'New/Promising'
            WHEN s.f_score >= 3 THEN 'At risk'
            ELSE 'Hibernating'
        END
    FROM (
        SELECT
            b.*,
            NTILE(4) OVER (ORDER BY b.recency_days DESC) AS r_score,
            NTILE(4) OVER (ORDER BY b.frequency) AS f_score,
            NTILE(4) OVER (ORDER BY b.monetary) AS m_score
        FROM rfm_base AS b
    ) AS s;
END;
$$;

-- (а) Сегмент тус бүрийн харилцагчийн тоо, дундаж monetary
SELECT segment, COUNT(*) AS customers_count, ROUND(AVG(monetary), 2) AS avg_monetary
FROM customer_rfm()
GROUP BY segment
ORDER BY avg_monetary DESC;

-- (б) 'At risk' сегментийн monetary-аар эхний 10 харилцагч
SELECT customer_id, company_name, recency_days, frequency,
       ROUND(monetary, 2) AS monetary, r_score, f_score, m_score
FROM customer_rfm()
WHERE segment = 'At risk'
ORDER BY monetary DESC
LIMIT 10;


-- ============================================================
-- Даалгавар 9. restock_products() - өгөгдөл өөрчилдөг функц
-- ============================================================

CREATE OR REPLACE FUNCTION restock_products(
    p_category_name TEXT,
    p_factor        NUMERIC DEFAULT 2.0
) RETURNS INT
LANGUAGE plpgsql
AS $$
DECLARE
    v_category_id INT;
    v_count       INT;
BEGIN
    IF p_factor IS NULL OR p_factor NOT BETWEEN 1.0 AND 5.0 THEN
        RAISE EXCEPTION 'p_factor нь 1.0-5.0 хооронд байх ёстой (өгсөн утга: %)', p_factor;
    END IF;

    SELECT category_id INTO v_category_id
    FROM categories
    WHERE category_name = p_category_name;

    IF NOT FOUND THEN
        RAISE EXCEPTION '"%" нэртэй ангилал олдсонгүй', p_category_name;
    END IF;

    CREATE TEMP TABLE IF NOT EXISTS restock_log (
        product_id   INT,
        product_name TEXT,
        old_on_order INT,
        new_on_order INT,
        changed_at   TIMESTAMP
    );

    -- UPDATE ... RETURNING-ийн мөрүүдийг шууд логт оруулна.
    -- FROM products AS old нь өөрчлөгдөхөөс өмнөх утгыг өгнө.
    WITH changed AS (
        UPDATE products AS p
        SET units_on_order = CEIL(p.reorder_level * p_factor)::INT
        FROM products AS old
        WHERE old.product_id = p.product_id
          AND p.category_id = v_category_id
          AND p.discontinued = 0
          AND p.units_in_stock < p.reorder_level
          AND p.units_on_order < CEIL(p.reorder_level * p_factor)  -- зөвхөн нэмэгдүүлнэ
        RETURNING p.product_id, p.product_name, old.units_on_order AS old_on_order,
                  p.units_on_order AS new_on_order
    )
    INSERT INTO restock_log (product_id, product_name, old_on_order, new_on_order, changed_at)
    SELECT product_id, product_name, old_on_order, new_on_order, now()
    FROM changed;

    GET DIAGNOSTICS v_count = ROW_COUNT;

    RAISE NOTICE '%: % бүтээгдэхүүний units_on_order шинэчлэгдлээ (p_factor = %)',
        p_category_name, v_count, p_factor;

    RETURN v_count;
EXCEPTION
    WHEN OTHERS THEN
        RAISE EXCEPTION 'restock_products алдаа: %', SQLERRM;
END;
$$;

-- Туршилтыг transaction дотор хийж, ROLLBACK-ээр products-ийн анхны утгыг сэргээнэ.
BEGIN;

-- 1) Амжилттай дуудлага
SELECT restock_products('Beverages', 2.0) AS updated_rows;

-- 2) p_factor = 0.5 -> алдаа
DO $$
BEGIN
    PERFORM restock_products('Beverages', 0.5);
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Алдаа: %', SQLERRM;
END;
$$;

-- 3) Байхгүй ангилал -> алдаа
DO $$
BEGIN
    PERFORM restock_products('Electronics');
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'Алдаа: %', SQLERRM;
END;
$$;

-- 4) Логийн үр дүн
SELECT * FROM restock_log ORDER BY product_id;

ROLLBACK;

DROP TABLE IF EXISTS restock_log;


-- ============================================================
-- Даалгавар 10. abc_analysis() - Парето шинжилгээ ба гүйцэтгэлийн харьцуулалт
-- ============================================================

-- 1-р хувилбар: функц доторх түр хүснэгт
CREATE OR REPLACE FUNCTION abc_analysis(p_year INT)
RETURNS TABLE (
    product_id     INT,
    product_name   TEXT,
    category_name  TEXT,
    revenue        NUMERIC,
    revenue_pct    NUMERIC,
    cum_pct        NUMERIC,
    abc_class      CHAR(1)
)
LANGUAGE plpgsql
AS $$
BEGIN
    DROP TABLE IF EXISTS product_revenue;

    -- Тухайн жилийн бүтээгдэхүүн бүрийн орлого
    CREATE TEMP TABLE product_revenue ON COMMIT DROP AS
    SELECT
        p.product_id::INT AS product_id,
        p.product_name::TEXT AS product_name,
        c.category_name::TEXT AS category_name,
        SUM((od.unit_price * od.quantity * (1 - od.discount))::numeric) AS revenue
    FROM order_details AS od
    JOIN orders AS o ON o.order_id = od.order_id
    JOIN products AS p ON p.product_id = od.product_id
    JOIN categories AS c ON c.category_id = p.category_id
    WHERE EXTRACT(YEAR FROM o.order_date) = p_year
    GROUP BY p.product_id, p.product_name, c.category_name;

    -- Эзлэх хувь, хуримтлагдсан хувь, A/B/C ангилал
    RETURN QUERY
    SELECT
        t.product_id,
        t.product_name,
        t.category_name,
        ROUND(t.revenue, 2),
        t.revenue_pct,
        t.cum_pct,
        (CASE
            WHEN t.cum_pct <= 80 THEN 'A'
            WHEN t.cum_pct <= 95 THEN 'B'
            ELSE 'C'
        END)::CHAR(1)
    FROM (
        SELECT
            r.*,
            pct_of(r.revenue, SUM(r.revenue) OVER ()) AS revenue_pct,
            pct_of(SUM(r.revenue) OVER (ORDER BY r.revenue DESC ROWS UNBOUNDED PRECEDING),
                   SUM(r.revenue) OVER ()) AS cum_pct
        FROM product_revenue AS r
    ) AS t
    ORDER BY t.revenue DESC;
END;
$$;

-- (а) A/B/C бүлэг тус бүрийн бүтээгдэхүүний тоо, нийт ба дундаж орлого
SELECT abc_class,
       COUNT(*) AS products_count,
       SUM(revenue) AS total_revenue,
       ROUND(AVG(revenue), 2) AS avg_revenue
FROM abc_analysis(1997)
GROUP BY abc_class
ORDER BY abc_class;

-- (б) 'A' бүлгийн бүтээгдэхүүнүүд ангиллаар. Эхний мөр нь хамгийн чухал ангилал.
SELECT category_name,
       COUNT(*) AS a_products,
       SUM(revenue) AS a_revenue
FROM abc_analysis(1997)
WHERE abc_class = 'A'
GROUP BY category_name
ORDER BY a_products DESC, a_revenue DESC;

-- 2-р хувилбар: ижил логик, зөвхөн CTE ашигласан (түр хүснэгтгүй)
CREATE OR REPLACE FUNCTION abc_analysis_cte(p_year INT)
RETURNS TABLE (
    product_id     INT,
    product_name   TEXT,
    category_name  TEXT,
    revenue        NUMERIC,
    revenue_pct    NUMERIC,
    cum_pct        NUMERIC,
    abc_class      CHAR(1)
)
LANGUAGE sql
STABLE
AS $$
    WITH product_revenue AS (
        SELECT
            p.product_id::INT AS product_id,
            p.product_name::TEXT AS product_name,
            c.category_name::TEXT AS category_name,
            SUM((od.unit_price * od.quantity * (1 - od.discount))::numeric) AS revenue
        FROM order_details AS od
        JOIN orders AS o ON o.order_id = od.order_id
        JOIN products AS p ON p.product_id = od.product_id
        JOIN categories AS c ON c.category_id = p.category_id
        WHERE EXTRACT(YEAR FROM o.order_date) = p_year
        GROUP BY p.product_id, p.product_name, c.category_name
    ),
    ranked AS (
        SELECT
            r.*,
            pct_of(r.revenue, SUM(r.revenue) OVER ()) AS revenue_pct,
            pct_of(SUM(r.revenue) OVER (ORDER BY r.revenue DESC ROWS UNBOUNDED PRECEDING),
                   SUM(r.revenue) OVER ()) AS cum_pct
        FROM product_revenue AS r
    )
    SELECT
        product_id,
        product_name,
        category_name,
        ROUND(revenue, 2),
        revenue_pct,
        cum_pct,
        (CASE
            WHEN cum_pct <= 80 THEN 'A'
            WHEN cum_pct <= 95 THEN 'B'
            ELSE 'C'
        END)::CHAR(1)
    FROM ranked
    ORDER BY revenue DESC;
$$;

-- Хоёр хувилбар ижил үр дүн өгч буйг шалгах (0 мөр гарвал ижил)
SELECT * FROM abc_analysis(1997)
EXCEPT
SELECT * FROM abc_analysis_cte(1997);

-- Гүйцэтгэлийн харьцуулалт: түр хүснэгттэй хувилбар
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM abc_analysis(1997);

-- Гүйцэтгэлийн харьцуулалт: CTE хувилбар
EXPLAIN (ANALYZE, BUFFERS)
SELECT * FROM abc_analysis_cte(1997);
