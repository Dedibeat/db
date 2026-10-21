/*Нийлүүлэгчийн бараа бүтээгдэхүүний үнийг шинэчлэх:
Өгөгдсөн нийлуулэгчээс нийлүүлдэг бараа бүтээгдэхүүний 
үнийн өсөлтийг өгөгдсөн хувиар өсгөх функц утгатай 
udfCalculateNewPrice хэрэглэгчийн тодорхойлсон функц бичээрэй. 
Функц нь @SupplierID, @IncreasePercentage оролтын параметрүүдтэй. 
Богоод шинэ үнийг дараах томьёогоор бодно.
Шинэ үнэ = Нэгжийн үнэ * (1 + IncreasePercentage/100)
Энэ функцийг ашиглан нийлүүлэгчийн нийлүүлдэг бүх 
бараа бүтээгдэхүүнийг үнийн дунг шинэчлэх 
spUpdateProductPricesBySupplier процедур бичээрэй.
Процедур нь @SupplierID, @IncreasePercentage оролтын параметрүүдтэй.*/

-- Fixed: price each product by its own unit_price (old LIMIT 1 gave every product the same price)
CREATE OR REPLACE FUNCTION udfCalculateNewPrice(prod_id INT, increase_pct NUMERIC)
RETURNS NUMERIC AS $$
BEGIN
    RETURN (SELECT unit_price * (1 + increase_pct / 100)
            FROM products WHERE product_id = prod_id);
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE spUpdateProductPricesBySupplier(sup_id INT, increase_pct NUMERIC) AS $$
BEGIN
    UPDATE products
    SET unit_price = udfCalculateNewPrice(product_id, increase_pct)
    WHERE supplier_id = sup_id;
END; $$ LANGUAGE plpgsql;

CALL spUpdateProductPricesBySupplier(1, 10);
SELECT * FROM products WHERE supplier_id = 1;
