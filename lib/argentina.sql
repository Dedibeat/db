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


CREATE OR REPLACE FUNCTION udfTotalSalesByCountries()
RETURNS TABLE (
    country_name TEXT,
    total_sales NUMERIC
) AS $$
BEGIN
    CREATE TEMP TABLE temp_total_sales_by_country (
        country_name TEXT,
        total_sales NUMERIC
    );
    FOR country_name IN SELECT DISTINCT country FROM customers ORDER BY country LOOP
        INSERT INTO temp_total_sales_by_country
        VALUES (country_name, udfTotalSalesByCountry(country_name));
    END LOOP;
    RETURN QUERY SELECT * FROM temp_total_sales_by_country;
    DROP TABLE IF EXISTS temp_total_sales_by_country;
END;
$$ LANGUAGE plpgsql;


SELECT * FROM udfTotalSalesByCountries();
