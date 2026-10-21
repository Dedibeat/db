/*Тээврийн компаниудын гүйцэтгэлийг харуулах тайлан:
Нэр бүхий тээврийн компанийн хийсэн захиалга тээвэрлэлтийг
нийт дүнг тооцоолох udf TotalShippingCostsByShipper нэртэй
хэрэглэгчийн функц бичээрэй. Энэ функц нь @ShipperlD гэсэн 
оролтын параметртэй бөгөөд хийсэн тээвэрлэлтийн дүнгээ скаляр
утгаар буцаана. Уг функцийг ашиглан [Shippers]
хуснэгт дэх тээвэрлэгч тус бүрийн хийсэн нийт тээврийн зардлыг
тээвэрлэгч тус бүрээр харуулах spCostsReportByEveryShipper
нэртэй функц бичээрэй. (shipper_id, shipper_name, totalshippingcosts)*/

CREATE OR REPLACE FUNCTION udfTotalShippingCostsByShipper(id INT)
RETURNS NUMERIC AS $$
BEGIN
    RETURN (SELECT SUM(freight) FROM orders WHERE ship_via = id);
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION spCostsReportByEveryShipper()
RETURNS TABLE (shipper_id INT, shipper_name TEXT, total_shipping_costs NUMERIC) AS $$
BEGIN
    RETURN QUERY
    SELECT s.shipper_id::INT, s.company_name::TEXT,
           udfTotalShippingCostsByShipper(s.shipper_id)
    FROM shippers s;
END; $$ LANGUAGE plpgsql;

SELECT * FROM spCostsReportByEveryShipper();
