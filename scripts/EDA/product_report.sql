/*Product Report

Purpose:
-This report consolidates key product metrics and behaviors.

Highlights:
1. Gathers essential fields such as product name, category, subcategory, and cost.
2. Segments products by revenue to identify High-Performers, Mid-Range, or Low-Performers.
3. Aggregates product-level metrics:
  -total orders
  -total sales
  -total quantity sold
  -total customers (unique)
  -lifespan (in months)
4. Calculates valuable KPIs:
  -recency (months since last sale)
  -average order revenue (AOR)
  -average monthly revenue
*/
--create report

create view gold.report_products as 
with base_query as( 
-- 1) Base query: retrieve core columns

select s.order_number,s.order_date,s.customer_key,s.sales_amount,s.quantity,
p.product_key,p.product_name,p.category,p.subcategory,p.cost
from gold.fact_sales as s
left join gold.dim_products as p 
on s.product_key=p.product_key
where s.order_date is not null),

product_aggregation as (

-- 2) Product aggregations:summarize key metrics at the product level

select product_key,product_name,category,subcategory,cost,
max(order_date ) as last_saledate,
datediff(month,min(order_date),max(order_date)) as lifespan,
count(distinct order_number) as total_orders,
sum(sales_amount) as total_sales,
count(distinct customer_key ) as total_customers,
sum(quantity)as total_qty,
round(avg(cast(sales_amount as float)/nullif(quantity,0)),1) as avg_sellingprice
from base_query
group by product_key,product_name,category,subcategory,cost)

-- 3) final query: combine all productt results into one output

select product_key,product_name,category,subcategory,cost,last_saledate,
datediff(month,last_saledate,getdate()) as recency_in_months,
case when total_sales> 50000 then 'highperformance'
	when total_sales> 100000 then 'mid range'
	else 'low-performance'
	end as product_seg,lifespan,total_orders,total_sales,total_qty,total_customers,avg_sellingprice,
	-- avg order revenue
	case
	when total_orders=0 then 0
	else total_sales/total_orders end as avg_order_revenue,
	-- avg monthly revenue
	case
	when lifespan=0 then total_sales
	else total_sales/lifespan end as avg_monthly_rev
from product_aggregation

select * from gold.report_products
