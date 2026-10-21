/*Ажилтны борлуулалтын тайлан харуулах:
Энэхуу процедур нь егегдсен хугацаанд өгөгдсөн ID бүхий ажилтны
хийсэн борлуулалтын тайланг гаргах юм. Уг процедур нь 
@EmployeeID, @StartDate, @EndDate гэсэн оролтын 
параметруудтэй бөгөөд өгөгдсөн хугацаанд тухайн ажилтны
гүйцэтгэсэн бүх борлуулалтыг харуулах байна. Энд захиалга тус
бүрийн дүнг бодох ба үр дүнг борлуулалтын тайланг дараах 
(order_id, order_date, totalsales) гэж харуулах ёстой.*/

CREATE OR REPLACE FUNCTION fnEmployeeSalesReport(emp_id INT, start_date DATE, end_date DATE)
RETURNS TABLE (order_id INT, order_date DATE, total_sales NUMERIC) AS $$
BEGIN
    RETURN QUERY
    SELECT o.order_id::INT, o.order_date, SUM(od.unit_price * od.quantity)::NUMERIC
    FROM orders o JOIN order_details od ON od.order_id = o.order_id
    WHERE o.employee_id = emp_id
      AND o.order_date BETWEEN start_date AND end_date
    GROUP BY o.order_id
    ORDER BY o.order_date DESC;
END; $$ LANGUAGE plpgsql;

SELECT * FROM fnEmployeeSalesReport(4, '1996-07-04', '1996-07-31');
