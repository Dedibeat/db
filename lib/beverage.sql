/*Огогдсон ангилал дахь бараа бутээгдэхууний борлуулалтын 
дунг бодох udfCalculateTotalSalesByCategory нэртэй скаляр 
утга буцаах хэрэглэгчийн тодорхойлсон функц уусгэ. Энэ функц
нь @CategoryID оролтын параметртэй. Энэ функцийг Categories 
хуснэгтээс CategoryID, CategoryName, 
udfCalculateTotalSalesByCategory(CategoryD) мэдээллийг харуулах
vwSalesByCategory харагдац уусгэхэд ашиглана.*/

CREATE OR REPLACE FUNCTION udfCalculateTotalSalesByCategory(in_category_id integer)
RETURNS numeric AS $$
DECLARE
    total_sales numeric := 0;
BEGIN
    SELECT SUM(od.quantity * od.unit_price)
    INTO total_sales
    FROM order_details od
    JOIN products p ON od.product_id = p.product_id 
    WHERE p.category_id = in_category_id;
    
    RETURN total_sales;
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE VIEW vwSalesByCategory AS
SELECT c.category_id,
       c.category_name,
       udfCalculateTotalSalesByCategory(c.category_id) AS total_sales
FROM categories c;

SELECT * FROM vwSalesByCategory;