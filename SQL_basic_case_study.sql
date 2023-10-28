create database analabs;
use analabs;

select top 10 * from [analabs].[dbo].[Customer];
select top 10 * from [dbo].[prod_cat_info];
select top 10 * from [dbo].[Transactions];

alter table Customer
add primary key (customer_Id);

-----------------DATA PREPARATION AND UNDERSTANDING-------------------------

--Q1. What is the total number of rows in each of the 3 tables in the database?
select count(*) as total_rows from [analabs].[dbo].[Customer];
select count(*) as total_rows  from [analabs].[dbo].[prod_cat_info];
select count(*) as total_rows  from [analabs].[dbo].[Transactions];

--Q2. What is the total number of transactions that have a return?
select count(*) as total_returned from ( select transaction_id, count(transaction_id) as count_of_transaction_id
from Transactions
group by transaction_id
having count(transaction_id) > 1 )as abc
;

--Q3. As you would have noticed, the dates provided across the datasets are not in a correct format. As first steps, pls convert the date variables into valid date formats before proceeding ahead
--Ans: In sql server, there was no issue with the dates. But in postgresql, I was not able to insert the data because there are two format of dates in the DOB column. So, firstly I used pandas to_datetime function to convert all the dates in the same format & saved it as a new csv. Then uploaded the new data csv to postgresql

--Q4. What is the time range of the transaction data available for analysis? Show the output in number of days, months and years simultaneously in different columns
select DATEDIFF(day, min(tran_date), max(tran_date)) as time_range_in_days
	,DATEDIFF(month, min(tran_date), max(tran_date)) as time_range_in_months
	,DATEDIFF(year, min(tran_date), max(tran_date)) as time_range_in_years
from Transactions;

--Q5. Which product category does the sub-category “DIY” belong to?
select prod_cat from [analabs].[dbo].[prod_cat_info]
where prod_subcat in ('DIY');


----------------------DATA ANALYSIS------------------------

--Q1. Which channel is most frequently used for transactions?
select TOP 1 Store_type from
(select Store_type , count(Store_type) as order_count
from Transactions
group by Store_type ) as abc
order by order_count desc
;

--Q2. What is the count of Male and Female customers in the database?
select Gender, count(*) as grp_count
from Customer
where Gender is not null
group by Gender;


--Q3. From which city do we have the maximum number of customers and how many?
select top 1 city_code, count(*) as customer_count
from Customer
group by city_code
order by customer_count desc
;

--Q4. How many sub-categories are there under the Books category?
select count(distinct(prod_sub_cat_code)) as sub_cat_count
from prod_cat_info
where prod_cat = 'Books';

--Q5. What is the maximum quantity of products ever ordered?
select abs(max(Qty)) as max_ordered_qty
from Transactions;

--Q6. What is the net total revenue generated in categories Electronics and Books?

select round(sum(total_amt),2) as net_total_revenue from Transactions where 
	prod_cat_code in  (
		select distinct(prod_cat_code) from [dbo].[prod_cat_info] where prod_cat in ('Electronics', 'Books')
	and total_amt > 0
);


--Q7. How many customers have >10 transactions with us, excluding returns?

select count(*) as cust_more_than_10_txn from (select cust_id, count(transaction_id) as txn_count from [dbo].[Transactions]  where total_amt > 0 
group by cust_id
having count(transaction_id) > 10)as abc;


--Q8. What is the combined revenue earned from the “Electronics” & “Clothing” categories, from “Flagship stores”?

select sum(total_amt) as total_revenue_Electronic_Cloth from [dbo].[Transactions] 
	where (store_type in ('Flagship store') 
	and total_amt >= 0 
	and prod_cat_code in (
		(select distinct(prod_cat_code) from [dbo].[prod_cat_info] where prod_cat in ('Clothing', 'Electronics'))
	)
);


--Q9. What is the total revenue generated from “Male” customers in “Electronics” category? Output should display total revenue by prod sub-cat

--alter table prod_cat_info  (created primary key of 2 columns to connect 2 tables {unique combination})
--add primary key (prod_cat_code, prod_sub_cat_code);


select prod_cat_info.prod_cat, prod_cat_info.prod_subcat , sum(total_amt) as total_amt from [dbo].[Transactions]
left outer join [dbo].[prod_cat_info]
on transactions.prod_cat_code = prod_cat_info.prod_cat_code 
	and transactions.prod_subcat_code = prod_cat_info.prod_sub_cat_code
where 
	(transactions.prod_cat_code in (select distinct(prod_cat_code) from prod_cat_info where prod_cat in ('Electronics'))
	and cust_id in (select customer_id from customer where gender = 'M')
	and total_amt > 0)
group by prod_cat_info.prod_cat, prod_cat_info.prod_subcat;

--note: question asks to display only by sub_cat, but if we do grouping only by sub_cat, wel will get only the numbers in the o/p. So, in order to unserstand the output as per by business perspective, the o/p is grouped in two levels.


--Q10. What is percentage of sales and returns by product sub category; display only top 5 sub categories in terms of sales?

WITH SalesReturnsCTE AS (
  SELECT
    prod_subcat_code,
    SUM(CASE WHEN total_amt >= 0 THEN total_amt ELSE 0 END) AS sales,
    SUM(CASE WHEN total_amt < 0 THEN ABS(total_amt) ELSE 0 END) AS returns
  FROM
    Transactions
  GROUP BY
    prod_subcat_code
)

SELECT TOP 5
  prod_subcat_code,
  sales,
  returns,
  ((returns / (sales + returns)) * 100) AS returns_percentage,
  ((sales / (sales + returns)) * 100) AS sales_percentage
FROM
  SalesReturnsCTE
ORDER BY
  sales DESC;


--Q11.For all customers aged between 25 to 35 years find what is the net total revenue generated by these consumers in last 30 days of transactions from max transaction date available in the data?

select customer_id from customer
where DATEDIFF(year, dob, GETDATE()) > 25 and DATEDIFF(year, dob, GETDATE()) < 35;

select round(sum(total_amt),2) as net_revenue from [dbo].[Transactions]
where (tran_date < (select DATEADD(day, -30, max(tran_date)) from Transactions))
	and cust_id in (select customer_id from Customer
                    where DATEDIFF(year, dob, GETDATE()) > 25 and 
                    DATEDIFF(year, dob, GETDATE()) < 35)
	--and total_amt >=0  {if we want only the orders without returns );


--Q12. Which product category has seen the max value of returns in the last 3 months of transactions?
	   	   	   
with max_return_cte as ( 
	   select 
       top 1
       prod_cat_code, sum(total_amt) as total_return_amt from transactions
			where (tran_date > (select DATEADD(MONTH, -3, max(tran_date))  from transactions)
	   				and transactions.total_amt < 0)
		group by prod_cat_code
		order by total_return_amt
		)
select distinct(prod_cat)
from prod_cat_info
inner join max_return_cte on max_return_cte.prod_cat_code = prod_cat_info.prod_cat_code;    
    
 
--Q13. Which store-type sells the maximum products; by value of sales amount and by quantity sold?
select 
top 1
store_type, sum(total_amt) as total_sales, sum(qty) as total_qty from transactions 
group by store_type
order by sum(total_amt) desc, sum(qty) desc
;


--Q14. What are the categories for which average revenue is above the overall average.

	   
select prod_cat_info.prod_cat , avg(total_amt) as cat_avg from transactions 
inner join prod_cat_info on transactions.prod_cat_code = prod_cat_info.prod_cat_code
group by prod_cat_info.prod_cat  
having avg(total_amt) > (select round(avg(total_amt),2) from transactions);


	   
--Q15. Find the average and total revenue by each subcategory for the categories which are among top 5 categories in terms of quantity sold	   
   
	   
with top_5_cat as (   
		select top 5 
               prod_cat_code , sum(qty) as total_qty from transactions
	  		   group by prod_cat_code 
	   		   order by total_qty desc
	    	   
),
	   cat_subcat_avg_sum as(
select transactions.prod_cat_code, transactions.prod_subcat_code, 
	   round(avg(total_amt),2) as avg_revenue, round(sum(total_amt),2) as total_revenue
	   from transactions
	   inner join top_5_cat on transactions.prod_cat_code = top_5_cat.prod_cat_code
	   group by transactions.prod_cat_code, transactions.prod_subcat_code
	   
)	 
	   
select prod_cat_info.prod_cat, prod_cat_info.prod_subcat, 
	   cat_subcat_avg_sum.avg_revenue as avg_revenue, cat_subcat_avg_sum.total_revenue as total_revenue
from cat_subcat_avg_sum
left outer join prod_cat_info on cat_subcat_avg_sum.prod_cat_code = prod_cat_info.prod_cat_code 
			and cat_subcat_avg_sum.prod_subcat_code = prod_cat_info.prod_sub_cat_code;    
    
