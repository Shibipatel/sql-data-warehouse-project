/* Customer Report
Purpose:
-This report consolidates key customer metrics and behaviors
Highlights:
1. Gathers essential fields such as names, ages, and transaction details.
2. Segments customers into categories (VIP, Regular, New) and age groups.
3. Aggregates customer-level metrics:
-total orders
-total sales
-total quantity purchased
-total products
-lifespan (in months)
4. Calculates valuable KPIs:
-recency (months since last order)
-average order value
-average monthly spend
*/

-- Reporting (customer reporting)

create view gold.report_customer as 
-- 1. retrieve core columns from tables
with base_query as(
select 
s.order_number,s.product_key,s.order_date,s.sales_amount,s.quantity,c.customer_key,c.customer_number,
CONCAT(c.first_name,' ',c.last_name) as full_name,datediff(year, c.birthdate, getdate()) as age
from gold.fact_sales as s
left join gold.dim_customer as c on c.customer_key=s.customer_key
where s.order_date is not null)
--2. customer aggregations
, customer_aggregation as (
select customer_key,customer_number,full_name,age, count(distinct order_number) as total_orders,
sum(sales_amount) as total_sales, sum(quantity) as total_qty, count(distinct product_key ) as total_product,
MAX(order_date) as last_orderdate,
DATEDIFF(month, min(order_date),MAX(order_date) ) as lifespan
from base_query
group by customer_key,customer_number,full_name,age)

select 
customer_key,customer_number,full_name,age,
case 
when age<20 then 'under 20'
when age between 20 and 29 then '20-29'
when age between 30 and 39 then '30-39'
when age between 40 and 49 then '40-49'
else '50 and above'
end as age_grp,
--compute recency (months since last order)
case 
when lifespan>=12 and total_sales>5000 then 'VIP'
when lifespan>=12 and total_sales<=5000 then 'Regular'
else 'New'
end Customer_segment,last_orderdate ,datediff(month, last_orderdate,getdate()) as recency,
total_orders,total_sales,total_qty,total_product,lifespan,
--compute avg order value
case when total_orders =0 then 0
else total_sales/total_orders end as avg_ordervalue,
-- compute avg monthly spend
case when lifespan=0 then total_sales
	else total_sales/lifespan end as avg_monthlyspend
from customer_aggregation 

select * from gold.report_customer
