# Lab 4 query results

Энэ хавтасны бүх файл нь `python scripts/save_results.py`-ээр psql-ийг бодитоор ажиллуулж хадгалсан гаралт.
`full_run_*.txt` нь .sql файлыг бүтнээр нь ажиллуулсан лог, `txt/` нь жишээ тус бүрийн гаралт (SQL, NOTICE мессеж, үр дүнгийн хүснэгт).

| Файл | Өгөгдлийн сан | Хэсэг | Жишээ |
|---|---|---|---|
| `txt/pubs_0_1.txt` | pubs | Setup. Check the converted pubs database | 0.1: Row count of every table (must equal the number of INSERTs in instpubs.sql) |
| `txt/pubs_0_2.txt` | pubs | Setup. Check the converted pubs database | 0.2: The converted reptq1 procedure (WITH ROLLUP -> ROLLUP) works |
| `txt/pubs_0_3.txt` | pubs | Setup. Check the converted pubs database | 0.3: The converted employee_insupd trigger rejects an invalid job level (job_lvl) |
| `txt/pubs_1_1.txt` | pubs | Task 1. spTotalSales - total sales amount for a date range | 1.1: Total sales in 1993 |
| `txt/pubs_1_2.txt` | pubs | Task 1. spTotalSales - total sales amount for a date range | 1.2: Sales on 1994-09-13 and 1994-09-14 (checks that the end day is included) |
| `txt/pubs_1_3.txt` | pubs | Task 1. spTotalSales - total sales amount for a date range | 1.3: A start date after the end date raises an error |
| `txt/pubs_2_1.txt` | pubs | Task 2. spTopAuthors - top N authors by sales | 2.1: Top 5 authors by sales |
| `txt/pubs_2_2.txt` | pubs | Task 2. spTopAuthors - top N authors by sales | 2.2: N = 3. Two authors tie for 3rd place, so 4 rows are returned |
| `txt/pubs_3_1.txt` | pubs | Task 3. spSearchBooks - search books by title | 3.1: Books with "computer" in the title |
| `txt/pubs_3_2.txt` | pubs | Task 3. spSearchBooks - search books by title | 3.2: Books with "cook" in the title |
| `txt/pubs_4_1.txt` | pubs | Task 4. spGenerateMonthlySalesReport - monthly sales report | 4.1: Report for May 1993 |
| `txt/pubs_4_2.txt` | pubs | Task 4. spGenerateMonthlySalesReport - monthly sales report | 4.2: Report for September 1994 |
| `txt/pubs_4_3.txt` | pubs | Task 4. spGenerateMonthlySalesReport - monthly sales report | 4.3: A month without sales (January 1993) returns zeros |
| `txt/pubs_4_4.txt` | pubs | Task 4. spGenerateMonthlySalesReport - monthly sales report | 4.4: An invalid month (13) raises an error |
| `txt/pubs_5_1.txt` | pubs | Task 5. spTransferInventory - move books from one store to another | 5.1: The target store has the title (7066 -> 7067, PS2091, 10 copies). Order D4482 of store 7067 goes from 10 to 20, store 7066 from 75 to 65. |
| `txt/pubs_5_2.txt` | pubs | Task 5. spTransferInventory - move books from one store to another | 5.2: The target store does not have the title (8042 -> 7896, BU1032, 4 copies). Store 7896 has no BU1032, so a new row (TRF-...) is inserted. |
| `txt/pubs_5_3.txt` | pubs | Task 5. spTransferInventory - move books from one store to another | 5.3: Not enough copies in the source store (6380 has only 3 of PS2091) |
| `txt/pubs_5_4.txt` | pubs | Task 5. spTransferInventory - move books from one store to another | 5.4: Moving to a store that does not exist (9999) fails the INSERT's foreign key. The error is caught and returned, and the copies taken from 8042 are put back. |
| `txt/northwind_1_1.txt` | northwind | Task 1. spUpdateProductStock - reduce a product's stock | 1.1: Reduce the stock of Chai (product_id = 1) by 5. It goes from 39 to 34. |
| `txt/northwind_1_2.txt` | northwind | Task 1. spUpdateProductStock - reduce a product's stock | 1.2: Errors for a quantity above the stock and for a product that does not exist |
| `txt/northwind_2_1.txt` | northwind | Task 2. spInsertNewEmployee - add a new employee | 2.1: Add an employee with valid data (ID 10) and check it with SELECT |
| `txt/northwind_2_2.txt` | northwind | Task 2. spInsertNewEmployee - add a new employee | 2.2: Duplicate ID (ID 1 belongs to Nancy Davolio) |
| `txt/northwind_2_3.txt` | northwind | Task 2. spInsertNewEmployee - add a new employee | 2.3: First name too long (first_name is VARCHAR(10)) |
| `txt/northwind_2_4.txt` | northwind | Task 2. spInsertNewEmployee - add a new employee | 2.4: Birth date in the future |
| `txt/northwind_2_5.txt` | northwind | Task 2. spInsertNewEmployee - add a new employee | 2.5: Empty first name |
| `txt/northwind_3_1.txt` | northwind | Task 3. spGetCustomerOrders - a customer's orders | 3.1: Orders of customer ALFKI |
| `txt/northwind_3_2.txt` | northwind | Task 3. spGetCustomerOrders - a customer's orders | 3.2: A lower-case ID ('vinet') works too |
| `txt/northwind_3_3.txt` | northwind | Task 3. spGetCustomerOrders - a customer's orders | 3.3: Error for a customer that does not exist |
| `txt/northwind_4_1.txt` | northwind | Task 4. spYearlySalesReport - yearly sales report | 4.1: Report for 1996 |
| `txt/northwind_4_2.txt` | northwind | Task 4. spYearlySalesReport - yearly sales report | 4.2: Report for 1997 |
| `txt/northwind_4_3.txt` | northwind | Task 4. spYearlySalesReport - yearly sales report | 4.3: Report for 1998 |
| `txt/northwind_5_1.txt` | northwind | Task 5. spSearchCustomers - search customers | 5.1: Search by city only (London) |
| `txt/northwind_5_2.txt` | northwind | Task 5. spSearchCustomers - search customers | 5.2: Search by company name and contact name ('market', 'elizabeth') |
| `txt/northwind_5_3.txt` | northwind | Task 5. spSearchCustomers - search customers | 5.3: Search by all three fields ('alfreds', 'maria', 'berlin') |
| `txt/northwind_5_4.txt` | northwind | Task 5. spSearchCustomers - search customers | 5.4: Error when no search value is given |
