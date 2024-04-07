use northwind;

show tables;

show create table salesorder;
desc salesorder;

ALTER table salesorder
ADD constraint emp_id_fk foreign key (employeeId) references employee(employeeId) ON DELETE SET NULL ON UPDATE CASCADE;
/*
ALTER TABLE salesorder
DROP CONSTRAINT emp_id_fk;
*/

Select * FROM employeeterritory;

-- Identify customers who placed an order but have never reordered
SELECT * FROM
(SELECT e.employeeId, COUNT(e.employeeId) as total_orders FROM 
salesorder so JOIN employee e ON so.employeeId = e.employeeId
GROUP BY e.employeeId) a
WHERE total_orders = 1;

-- Find the top 10 selling products for each category in the last quarter, excluding discontinued items
WITH cat_rank_tab AS (
SELECT p.categoryId, od.productId, COUNT(od.quantity) as total_quantity,
RANK() OVER(partition by p.categoryId order by total_quantity DESC) as cat_rank
FROM orderdetail od JOIN product p ON p.productId = od.productId 
JOIN salesorder so ON od.orderId = so.orderID
WHERE p.discontinued = 0 and YEAR(so.orderDate) = (SELECT YEAR(MAX(orderDate)) FROM salesorder) AND QUARTER(so.orderDate) = (SELECT quarter(max(orderDate)) FROM salesorder)
GROUP BY p.categoryId, od.productId
ORDER BY p.categoryId, cat_rank
)
SELECT categoryId, productId, total_quantity, cat_rank
FROM cat_rank_tab
WHERE cat_rank <=4;

-- Calculate the average order value for each employee in the Sales department, along with the total number of orders they secured
SELECT employeeId, AVG(order_value) AS avg_order_value, COUNT(orderId) as total_order FROM
(SELECT 
    e.employeeId,
    s.orderId,
    SUM(od.unitPrice * od.quantity) AS order_value
FROM
    employee e
        JOIN
    salesorder s ON s.employeeId = e.employeeId
        JOIN
    orderdetail od ON od.orderId = s.orderId
GROUP BY e.employeeId , s.orderId) a
GROUP BY employeeId
ORDER BY avg_order_value DESC;

-- Identify employees who manage departments with an average order value below the company average order value
WITH ov as
(SELECT 
    e.employeeId,
    s.orderId,
    SUM(od.unitPrice * od.quantity) AS order_value
FROM
    employee e
        JOIN
    salesorder s ON s.employeeId = e.employeeId
        JOIN
    orderdetail od ON od.orderId = s.orderId
GROUP BY e.employeeId , s.orderId)
SELECT employeeId, AVG(order_value) as avg_ov FROM
ov
GROUP BY employeeId
HAVING avg_ov  < (SELECT AVG(order_value) FROM ov)
ORDER BY avg_ov DESC;

-- Write a query that finds the ninth highest-priced order for each customer.
With or_cust AS(
SELECT 
    s.custId,
    s.orderId,
    SUM(od.unitPrice * od.quantity) AS order_value,
    RANK() OVER(partition by s.custId ORDER BY order_value DESC) as cust_order_ranking
FROM
    salesorder s
        JOIN
    orderdetail od ON od.orderId = s.orderId
GROUP BY s.custId , s.orderId)
SELECT custId,
	   orderId,
       order_value,
       cust_order_ranking
FROM or_cust
WHERE cust_order_ranking =9;
       

-- Find the top performing salespeople in the first quarter of the previous year, including total sales and number of orders.
SELECT 
    employeeid,
    SUM(quantity * unitprice) AS revenue,
    COUNT(DISTINCT s.orderid) AS total_orders
FROM
    salesorder s
        JOIN
    orderdetail od ON s.orderid = od.orderid
WHERE
    YEAR(orderdate) = (SELECT 
            YEAR(MAX(orderdate)) - 1
        FROM
            salesorder)
        AND QUARTER(orderdate) IN (1 , 2)
GROUP BY employeeid
ORDER BY revenue DESC;
-- Two oustanding performers in the 1st quarter of the previous year has the ID of 4 and 3, respectively

SELECT 
    *
FROM
    employee e
        JOIN
    emp_gender eg ON e.employeeid = eg.employeeid
WHERE
    e.employeeid in (4 , 3);
/* -> Both of them are female, which is not surprising since the majority of the comp revenue stems from them.
Another noticeable feature can be that one of them is currently a sales manager while the other is just a sales prep despite having slightly better performance over the quarter. 
*/

-- Find the number of male and female employees in the company
SET @a=0,@b=0,@c=0,@d=0;

SELECT Count(male) as male_count, count(female) as female_count FROM(
SELECT firstname, lastname, titleofcourtesy,
	CASE
		WHEN titleOfCourtesy LIKE "Ms." OR titleOfCourtesy LIKE "Mrs." THEN (@a:=@a+1)
        WHEN titleOfCourtesy LIKE "Mr." THEN (@b:=@b+1)
        ELSE (@c:=@c+1) END as count_title,
    CASE WHEN titleOfCourtesy LIKE "Ms." OR titleOfCourtesy LIKE "Mrs." THEN 1 ELSE 0 end as female,
	CASE WHEN titleOfCourtesy LIKE 'Mr.' THEN 1 ELSE 0 end as male
FROM employee) a
;

-- Find the total sales and total orders of employees grouped by gender. Is there any noticeable difference?
CREATE TEMPORARY TABLE emp_gender AS (
SELECT employeeid,
		CASE WHEN titleofcourtesy like 'Mr.' THEN 'male'
        WHEN titleofcourtesy like 'Mrs.' OR titleofcourtesy  like 'Ms.' THEN 'female'
        ELSE 'undefined' END AS gender
FROM employee);

SELECT 
    gender,
    SUM(quantity * unitprice) AS total_sales,
    COUNT(s.orderid) AS total_order
FROM
    emp_gender eg
        JOIN
    salesorder s ON s.employeeid = eg.employeeid
        JOIN
    orderdetail od ON od.orderid = s.orderid
GROUP BY gender
ORDER BY total_sales DESC;

-- -> One key insights deduced from the figures is that female employees enjoy much higher sale revenue, with their figures triple those of male's in both total orders and revenues.

-- Find the average revenue for orders categorised by gender
With order_sale as (
SELECT 
    eg.employeeid,
    eg.gender,
    s.orderid,
    SUM(quantity * unitprice) AS order_value
FROM
    emp_gender eg
        JOIN
    salesorder s ON eg.employeeid = s.employeeid
        JOIN
    orderdetail od ON od.orderid = s.orderid
GROUP BY eg.employeeid , eg.gender , s.orderid)
SELECT gender, AVG(order_value) as avg_order_value
FROM order_sale 
GROUP BY gender
ORDER BY avg_order_value DESC;
-- However, the average revenue for each order of female are slightly better than female's, disacknowledging the figure for undefined gender.


