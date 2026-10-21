/*Тээврийн компаниудын гүйцэтгэлийг харуулах тайлан:
Нэр бүхий тээврийн компанийн хийсэн захиалга тээвэрлэлтийг
нийт дүнг тооцоолох udf TotalShippingCostsByShipper нэртэй
хэрэглэгчийн функц бичээрэй. Энэ функц нь @ShipperlD гэсэн 
оролтын параметртэй бөгөөд хийсэн тээвэрлэлтийн дүнгээ скаляр
утгаар буцаана. Уг функцийг ашиглан [Shippers]
хуснэгт дэх тээвэрлэгч тус бүрийн хийсэн нийт тээврийн зардлыг
тээвэрлэгч тус бүрээр харуулах spCostsReportByEveryShipper
нэртэй функц бичээрэй. (shipper_id, shipper_name, totalshippingcosts)*/

CREATE OR REPLACE FUNCTION udfTotalShippingCostsByShipper(ShipperID INT)
RETURNS NUMERIC AS $$
DECLARE
    TotalShippingCosts NUMERIC;
BEGIN
    SELECT SUM(freight)
    INTO TotalShippingCosts
    FROM orders
    WHERE ship_via = ShipperID;

    RETURN TotalShippingCosts;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION spCostsReportByEveryShipper()
RETURNS TABLE (
    shipper_id SMALLINT,
    shipper_name VARCHAR(40),
    total_shipping_costs NUMERIC
) AS $$
BEGIN
    RETURN QUERY
    SELECT s.shipper_id::SMALLINT,
           s.company_name AS shipper_name,
           udfTotalShippingCostsByShipper(s.shipper_id) AS total_shipping_costs
    FROM shippers s;
END;
$$ LANGUAGE plpgsql;


SELECT * FROM spCostsReportByEveryShipper();