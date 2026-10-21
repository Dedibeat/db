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

-- Report as a table (no loop / temp table needed)
CREATE OR REPLACE FUNCTION spTotalSalesByCountries()
RETURNS TABLE (country TEXT, total_sales NUMERIC) AS $$
BEGIN
    RETURN QUERY
    SELECT DISTINCT c.country::TEXT, udfTotalSalesByCountry(c.country)
    FROM customers c ORDER BY 1;
END; $$ LANGUAGE plpgsql;

SELECT * FROM spTotalSalesByCountries();
