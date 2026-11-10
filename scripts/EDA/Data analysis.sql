--sales over time
select year(order_date) as order_year,
MONTH(order_date) as order_mnth,
sum(sales_amount) as total_sales, 
COUNT(distinct customer_key) as total_customer,
sum(quantity) as total_qty
from gold.fact_sales 
where order_date is not null
group by year(order_date),MONTH(order_date)
order by year(order_date),MONTH(order_date);

select format(datetrunc(MONTH,order_date),'yyyy-MM') as date, 
sum(sales_amount) as total_sales, 
COUNT(distinct customer_key) as total_customer,
sum(quantity) as total_qty
from gold.fact_sales
where order_date is not null
group by datetrunc(MONTH,order_date)
order by datetrunc(MONTH,order_date)

-- cumulative analysis- agg data progressively over time
-- total sales per month and running total of sales over time

select order_date,total_sales,avg_price,
sum(total_sales) over(order by order_date) as run_sales, SUM(avg_price) over(order by order_date) as run_avg 
from(
select datetrunc(year,order_date) as order_date, 
sum(sales_amount) as total_sales,
AVG(price) as avg_price
from gold.fact_sales
where order_date is not null
group by datetrunc(year,order_date))t

--performance analysis- comparing the current value to a terget value

with cte_1 as (
select year(f.order_date) as years,sum(f.sales_amount) as totalsales,p.product_name
from gold.fact_sales f
left join gold.dim_products p
on f.product_key=p.product_key
where order_date is not null
group by year(f.order_date), p.product_name)
 
select product_name, years, totalsales,
AVG(totalsales) over(partition by product_name) as avg_sales,
totalsales-AVG(totalsales) over(partition by product_name) as diff_avg,
case when totalsales-AVG(totalsales) over(partition by product_name)>0 then 'above avg'
	 when totalsales-AVG(totalsales) over(partition by product_name)<0 then 'below avg'
	 else 'avg' end avg_change,
Lag(totalsales,1) over(partition by product_name order by years) as prevsales,
totalsales-Lag(totalsales,1) over(partition by product_name order by years) as diff_py,
case when totalsales-Lag(totalsales,1) over(partition by product_name order by years)>0 then 'increase'
	 when totalsales-Lag(totalsales,1) over(partition by product_name order by years)<0 then 'decrease'
	 else 'no change' end py_change
from cte_1
order by product_name, years

-- part to whole analysis - how an individual part is performing compared to the overall
-- which categories contribute the most to overall sales?

select *, sum(totalsales) over() as overallsales,
concat(round((cast(totalsales as float)/sum(totalsales) over())*100,2),'%') as per_of_total
from (
select p.category,sum(s.sales_amount) as totalsales
from gold.fact_sales as s left join gold.dim_products as p
on p.product_key=s.product_key 
group by p.category)t
order by totalsales desc

-- data segmentation- group data based on a specific range, helps understand the correlation between 2 measures.
-- segment products into cost ranges and count how many products fall into each segment

select cost_range,count(product_key) as total_products
from (
select product_key,cost, 
case when cost<100 then 'below 100'
	 when cost between 100 and 500 then '100-500'
	 when cost between 500 and 1000 then '500-1000'
	 else 'above 1000'
end cost_range
from gold.dim_products)t
group by cost_range
order by total_products desc

-- group customer into 3 segments based on their spending behavioue:
--vip(12 or more months of history and spending > 5000), regular(12 or more months of history and spending <= 5000), new (life span less than 12 months)

with cte_custspend as(
select c.customer_key,sum(s.sales_amount) as total_spending, 
min(s.order_date) as firstorder,MAX(s.order_date) as last_order,
DATEDIFF(month, min(s.order_date),MAX(s.order_date) ) as lifespan
from gold.fact_sales as s
left join gold.dim_customer as c
on s.customer_key=c.customer_key
group by c.customer_key)

select Customer_segment,count(customer_key) as total_customer
from(
select customer_key,
case 
when lifespan>=12 and total_spending>5000 then 'VIP'
when lifespan>=12 and total_spending<=5000 then 'Regular'
else 'New'
end Customer_segment
from cte_custspend)t
group by Customer_segment;
