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
       

