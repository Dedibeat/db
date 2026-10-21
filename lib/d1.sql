/*Ажилтны борлуулалтын тайлан харуулах

Энэхүү процедур нь өгөгдсөн хугацаанд өгөгдсөн ID бүхий ажилтны 
хийсэн борлуулалтын тайланг гаргах юм. Уг процедур нь @EmployeeID, 
@StartDate, @EndDate гэсэн оролтын параметрүүдтэй бөгөөд өгөгдсөн 
хугацаанд тухайн ажилтны гүйцэтгэсэн бүх борлуулалтыг харуулах байна. 
Энд захиалга тус бүрийн дүнг бодох ба үр дүнг борлуулалтын тайланг 
дараах байдлаар харуулах ёстой.*/

DROP FUNCTION IF EXISTS fnEmployeeSalesReport
	(EmployeeID INT, StartDate DATE, EndDate DATE);
CREATE OR REPLACE FUNCTION fnEmployeeSalesReport
	(EmployeeID INT, StartDate DATE, EndDate DATE)
RETURNS TABLE 
	(order_id INT, order_date DATE, total_sales NUMERIC)
AS $$
BEGIN
    RETURN QUERY SELECT o.order_id::INT, o.order_date, 
    	SUM(od.unit_price*od.quantity)::NUMERIC AS total_sales
    FROM orders o
    JOIN order_details od ON o.order_id = od.order_id
    WHERE o.employee_id = EmployeeID
    AND o.order_date BETWEEN StartDate AND EndDate
    GROUP BY o.order_id, o.order_date
	ORDER BY o.order_date DESC;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM fnEmployeeSalesReport(4, '1996-10-30', '1996-12-20');