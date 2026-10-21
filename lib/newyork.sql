/*Өгөгдсөн бүс нутгийн хувьд борлуулалтын ажилтнуудын хийсэн гуйлгээг 
харуулах хуснэгтэн утгат udfCalculateSalesByEmployeeAndTerritory функц 
бичээрэй. Уг функц нь @TerritoryName нэртэй оролтын параметртей бегоед 
энэ параметр нь Terfitories хуснэгтийн TerritoryDescription параметртэй 
жишигдэнэ. Уг функцийн ур дунг ашиглан огогдсен бус нутаг дахь борлуулалтын 
ажилтан тус бүрийн хийсэн борлуулалтын тайлан харуулах
spSalesPerformanceReportByTerritory процедур бичээрэй.*/

CREATE OR REPLACE FUNCTION udfCalculateSalesByEmployeeAndTerritory(territory_name TEXT)
RETURNS TABLE (
    employee_id SMALLINT,
    employee_name TEXT,
    total_sales NUMERIC,
    territory_id SMALLINT,
    territory_description TEXT
) AS $$
BEGIN
    RETURN QUERY 
    SELECT e.employee_id::SMALLINT,
           e.first_name || ' ' || e.last_name AS employee_name,
           SUM(od.unit_price * od.quantity)::NUMERIC AS total_sales, 
           t.territory_id::SMALLINT,
           t.territory_description::TEXT
    FROM employees e
    JOIN orders o ON e.employee_id = o.employee_id
    JOIN order_details od ON o.order_id = od.order_id
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN territories t ON t.territory_id = t.territory_id
    WHERE t.territory_description ILIKE territory_name
    GROUP BY e.employee_id, e.first_name, e.last_name, 
             t.territory_id, t.territory_description;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION spSalesPerformanceReportByTerritory(territory_name TEXT)
RETURNS TABLE (
    employee_id SMALLINT,
    employee_name TEXT,
    total_sales NUMERIC,
    territory_id SMALLINT,
    territory_description TEXT
) AS $$
BEGIN
    RETURN QUERY 
    SELECT * FROM udfCalculateSalesByEmployeeAndTerritory(territory_name);
END;
$$ LANGUAGE plpgsql;

SELECT * FROM spSalesPerformanceReportByTerritory('New York');