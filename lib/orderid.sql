/*Ажилтны борлуулалтын тайлан харуулах:
Энэхуу процедур нь егегдсен хугацаанд өгөгдсөн ID бүхий ажилтны
хийсэн борлуулалтын тайланг гаргах юм. Уг процедур нь 
@EmployeeID, @StartDate, @EndDate гэсэн оролтын 
параметруудтэй бөгөөд өгөгдсөн хугацаанд тухайн ажилтны
гүйцэтгэсэн бүх борлуулалтыг харуулах байна. Энд захиалга тус
бүрийн дүнг бодох ба үр дүнг борлуулалтын тайланг дараах 
(order_id, order_date, totalsales) гэж харуулах ёстой.*/

CREATE OR REPLACE FUNCTION fnEmployeeSalesReport(
    EmployeeID INT,
    StartDate DATE,
    EndDate DATE
)
RETURNS TABLE (
    order_id INT,
    order_date DATE,
    total_sales NUMERIC
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY 
    SELECT o.order_id::INT, o.order_date, 
           SUM(od.unit_price * od.quantity)::NUMERIC AS total_sales
    FROM orders o
    JOIN order_details od ON o.order_id = od.order_id
    WHERE o.employee_id = EmployeeID
    AND o.order_date BETWEEN StartDate AND EndDate
    GROUP BY o.order_id, o.order_date;
END;
$$;



SELECT * FROM employees;
SELECT * FROM order_details;
SELECT * FROM orders;

SELECT * FROM fnEmployeeSalesReport(4, '1996-07-04', '1996-07-31');
