/*Өгөгдсөн бүс нутгийн хувьд борлуулалтын ажилтнуудын хийсэн гүйлгээг
харуулах хүснэгтэн-утгат udfCalculateSalesByEmployeeAndTerritory функц 
бичээрэй. Уг функц нь @TerritoryName  нэртэй оролтын параметртэй бөгөөд 
энэ параметр нь Territories хүснэгтийн TerritoryDescription параметртэй 
жишигдэнэ. Уг функцийн үр дүнг ашиглан өгөгдсөн бүс нутаг дахь 
борлуулалтын ажилтан тус бүрийн хийсэн борлуулалтын тайлан харуулах 
spSalesPerformanceReportByTerritory процедур бичээрэй.*/

-- Fixed: join through employee_territories (old ON t.territory_id = t.territory_id matched everything)
CREATE OR REPLACE FUNCTION udfCalculateSalesByEmployeeAndTerritory(territory_name TEXT)
RETURNS TABLE (employee_id INT, employee_name TEXT, total_sales NUMERIC) AS $$
BEGIN
    RETURN QUERY
    SELECT e.employee_id::INT, e.first_name || ' ' || e.last_name,
           SUM(od.unit_price * od.quantity)::NUMERIC
    FROM employees e
    JOIN orders o         ON o.employee_id = e.employee_id
    JOIN order_details od ON od.order_id = o.order_id
    WHERE e.employee_id IN (SELECT et.employee_id
                            FROM employee_territories et
                            JOIN territories t ON t.territory_id = et.territory_id
                            WHERE TRIM(t.territory_description) ILIKE territory_name)
    GROUP BY e.employee_id;
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION spSalesPerformanceReportByTerritory(territory_name TEXT)
RETURNS TABLE (employee_id INT, employee_name TEXT, total_sales NUMERIC) AS $$
BEGIN
    RETURN QUERY
    SELECT * FROM udfCalculateSalesByEmployeeAndTerritory(territory_name) u
    ORDER BY u.total_sales DESC;
END; $$ LANGUAGE plpgsql;

SELECT * FROM spSalesPerformanceReportByTerritory('New York');
