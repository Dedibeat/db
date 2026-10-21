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

CREATE OR REPLACE FUNCTION udfCalculateNewPrice(SupplierID INT, IncreasePercentage NUMERIC)
RETURNS NUMERIC AS $$
DECLARE
    NewPrice NUMERIC;
BEGIN
    SELECT unit_price * (1 + IncreasePercentage/100)
    INTO NewPrice
    FROM products
    WHERE supplier_id = SupplierID
    ORDER BY product_id
    LIMIT 1;
    RETURN NewPrice;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE spUpdateProductPricesBySupplier(SupplierID INT, IncreasePercentage NUMERIC)
AS $$
DECLARE
    ProductID INT;
    NewPrice NUMERIC;
BEGIN
    FOR ProductID IN SELECT product_id FROM products WHERE supplier_id = SupplierID 
	LOOP
        NewPrice := udfCalculateNewPrice(SupplierID, IncreasePercentage);
        UPDATE products
        SET unit_price = NewPrice
        WHERE product_id = ProductID;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

CALL spUpdateProductPricesBySupplier(1, 10);

SELECT * FROM products