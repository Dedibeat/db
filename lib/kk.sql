/*Аль нэг улсын хэрэглэгчдийн (Customers) хийсэн захиалгын нийт дунг тооцоолж 
харуулах скаляр утгатай udfTotalSalesByCountry нэртэй хэрэглэгчийн функц бичээрэй. 
Функц нь @CountryName нэртэй оролтын параметр авна. Энэ функцийг ашиглан улс 
бүрээр хэрэглэгчдийн хийсэн нийт гүйлгээний дүнгийн тайлан харуулах 
spTotalSalesByCountries нэртэй функц бичээрэй.*/

CREATE OR REPLACE FUNCTION udfTotalSalesByCountry(country_name TEXT)
RETURNS NUMERIC AS $$
BEGIN
    RETURN (SELECT SUM(od.unit_price * od.quantity)
            FROM customers c
            JOIN orders o USING (customer_id)
            JOIN order_details od USING (order_id)
            WHERE c.country ILIKE country_name);
END; $$ LANGUAGE plpgsql;

-- Procedure variant: prints the report with RAISE NOTICE
CREATE OR REPLACE PROCEDURE spTotalSalesByCountries() AS $$
DECLARE r RECORD;
BEGIN
    FOR r IN SELECT DISTINCT country FROM customers ORDER BY country LOOP
        RAISE NOTICE '%: %', r.country, udfTotalSalesByCountry(r.country);
    END LOOP;
END; $$ LANGUAGE plpgsql;

CALL spTotalSalesByCountries();
