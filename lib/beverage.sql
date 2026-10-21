/*Огогдсон ангилал дахь бараа бутээгдэхууний борлуулалтын 
дунг бодох udfCalculateTotalSalesByCategory нэртэй скаляр 
утга буцаах хэрэглэгчийн тодорхойлсон функц уусгэ. Энэ функц
нь @CategoryID оролтын параметртэй. Энэ функцийг Categories 
хуснэгтээс CategoryID, CategoryName, 
udfCalculateTotalSalesByCategory(CategoryD) мэдээллийг харуулах
vwSalesByCategory харагдац уусгэхэд ашиглана.*/

CREATE OR REPLACE FUNCTION udfCalculateTotalSalesByCategory(cat_id INT)
RETURNS NUMERIC AS $$
BEGIN
    RETURN (SELECT SUM(od.unit_price * od.quantity)
            FROM order_details od JOIN products p USING (product_id)
            WHERE p.category_id = cat_id);
END; $$ LANGUAGE plpgsql;

CREATE OR REPLACE VIEW vwSalesByCategory AS
SELECT category_id, category_name,
       udfCalculateTotalSalesByCategory(category_id) AS total_sales
FROM categories;

SELECT * FROM vwSalesByCategory;
