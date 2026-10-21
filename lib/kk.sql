/*Аль нэг улсын хэрэглэгчдийн (Customers) хийсэн захиалгын нийт дунг тооцоолж 
харуулах скаляр утгатай udfTotalSalesByCountry нэртэй хэрэглэгчийн функц бичээрэй. 
Функц нь @CountryName нэртэй оролтын параметр авна. Энэ функцийг ашиглан улс 
бүрээр хэрэглэгчдийн хийсэн нийт гүйлгээний дүнгийн тайлан харуулах 
spTotalSalesByCountries нэртэй функц бичээрэй.*/

CREATE OR REPLACE FUNCTION udfTotalSalesByCountry(country_name text)
RETURNS numeric AS $$
DECLARE
    total_sales numeric := 0;
BEGIN
    SELECT SUM(od.unit_price * od.quantity)
    INTO total_sales
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN order_details od ON o.order_id = od.order_id
    WHERE c.country ILIKE country_name;
    
    RETURN total_sales;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE PROCEDURE spTotalSalesByCountries()
AS $$
DECLARE
    country_record RECORD;
BEGIN
    FOR country_record IN SELECT DISTINCT country FROM customers ORDER BY country LOOP
        RAISE NOTICE 'Country: %, Total Sales: %', country_record.country, udfTotalSalesByCountry(country_record.country);
    END LOOP;
END;
$$ LANGUAGE plpgsql;


CALL spTotalSalesByCountries();