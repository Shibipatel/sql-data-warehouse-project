Exec silver.load_silver;

create or alter procedure silver.load_silver as
begin
    declare @start_time datetime, @end_time datetime, @batch_start_time datetime, @batch_end_time datetime;
    begin try
    set @batch_start_time=GETDATE();
    print '------------------------------------'
    print 'loading silver layer';
    print '------------------------------------'
    print 'loading CRM Tables';
    print '------------------------------------'

    -- loading silver.crm_cust_info'
    set @start_time=GETDATE()
    print '>> truncating table:silver.crm_cust_info'
    truncate table silver.crm_cust_info;
    print '>> insert data into silver.crm_cust_info'
    insert into silver.crm_cust_info(cst_id, cst_key,cst_firstname,cst_lastname,cst_marital_status,cst_gndr,cst_create_date)
    select cst_id, cst_key
          ,trim(cst_firstname) as cst_firstname 
          ,trim(cst_lastname) as cst_lastname
          ,case when upper(trim(cst_marital_status))='M' then 'Married'
                when upper(trim(cst_marital_status))='S' then 'Single'
                else 'n/a'
           end cst_marital_status
          ,case when upper(trim(cst_gndr))='M' then 'Male'
                when upper(trim(cst_gndr))='F' then 'Female'
                else 'n/a'
           end cst_gndr
          ,cst_create_date
    from (
          select * , ROW_NUMBER() over(partition by cst_id order by cst_create_date desc) as flag
          from bronze.crm_cust_info
          where cst_id is not null)t where flag=1;
          set @end_time=GETDATE();
          print '>>loading duration:' + cast(datediff(second,@start_time,@end_time) as nvarchar)+'seconds';
          print '>> ----------------------------------------------';

    -- loading silver.crm_prd_info'
    set @start_time=GETDATE()
    print '>> truncating table: silver.crm_prd_info'
    truncate table silver.crm_prd_info;
    print '>> insert data into: silver.crm_prd_info'
    insert into silver.crm_prd_info (prd_id,cat_id ,prd_key	,prd_nm ,prd_cost ,prd_line ,prd_start_dt ,prd_end_dt)
    select prd_id
          ,replace(LEFT(prd_key,5),'-','_') as cat_id
          ,SUBSTRING(prd_key,7,LEN(prd_key)) as prd_key
          ,prd_nm
          ,isnull(prd_cost,0) as prd_cost
          ,case 
           when upper(trim(prd_line))='R' then 'Road' 
           when upper(trim(prd_line))='M' then 'Mountain' 
           when upper(trim(prd_line))='S' then 'other sales' 
           when upper(trim(prd_line))='T' then 'Touring' 
           else 'n/a'
           end as prd_line
          ,cast (prd_start_dt as date) as prd_start_dt,
          cast(lead (prd_start_dt) over(partition by prd_key order by prd_start_dt)-1 as date) as prd_end_dt 
          from bronze.crm_prd_info;
          set @end_time=GETDATE();
          print '>>loading duration:' + cast(datediff(second,@start_time,@end_time) as nvarchar)+' seconds';
          print '>> ----------------------------------------------';

    
    -- loading silver.crm_sales_details'
    set @start_time=GETDATE()
    print '>> truncating table:silver.crm_sales_details'
    truncate table silver.crm_sales_details;
    print '>> insert data into: silver.crm_sales_details'
    insert into silver.crm_sales_details (sls_ord_num,sls_prd_key,sls_cust_id,sls_order_dt ,sls_ship_dt,sls_due_dt ,sls_sales ,sls_quantity,sls_price)
    SELECT sls_ord_num
          ,sls_prd_key
          ,sls_cust_id
          ,case when sls_order_dt=0 or len(sls_order_dt)!=8 then null else cast(cast(sls_order_dt as varchar) as date)
           end as sls_order_dt
          ,case when sls_ship_dt = 0 or len(sls_ship_dt)!=8 then null else cast(cast(sls_ship_dt as varchar) as date) end as sls_ship_dt
          ,case when sls_due_dt = 0 or len(sls_due_dt)!=8 then null else cast(cast(sls_due_dt as varchar) as date) end as sls_due_dt
          ,case when sls_sales<=0 or sls_sales is null or sls_sales!=abs(sls_price)*sls_quantity then abs(sls_price)*sls_quantity
          else sls_sales end as sls_sales
          ,sls_quantity,
          case when sls_price<=0 or sls_price is null then sls_sales/nullif(sls_quantity,0) else sls_price end as sls_price 
      FROM bronze.crm_sales_details
      set @end_time=GETDATE()
      print'>>loading duration:' + cast(datediff(second,@start_time,@end_time) as nvarchar)+' seconds';
          print '>> ----------------------------------------------';

    --loading erp_cust_az12
    set @start_time=GETDATE();
    print '>> truncating table:silver.erp_cust_az12'
    truncate table silver.erp_cust_az12;
    print '>> insert data into: silver.erp_cust_az12'
    insert into silver.erp_cust_az12 (CID,BDATE ,GEN )
    SELECT 
    case when CID like 'NAS%' THEN SUBSTRING(CID,4,LEN(CID)) else CID end as CID,
    CASE when BDATE > GETDATE() then null else BDATE END as bdate,
    case when upper(trim(gen)) in ('F','FEMALE') then 'Female'
	     when upper(trim(gen)) in ('M','MALE') then 'Male'
    else 'n/a' end as GEN
     FROM bronze.erp_cust_az12
     set @end_time=GETDATE()
     print'>>loading duration:' + cast(datediff(second,@start_time,@end_time) as nvarchar)+' seconds';
     print '>> ----------------------------------------------';

     --loading erp_loc_a101
     set @start_time=GETDATE()
    print '>> truncating table:silver.erp_loc_a101'
    truncate table silver.erp_loc_a101;
    print '>> insert data into: silver.erp_loc_a101'
    INSERT into silver.erp_loc_a101 (CID,CNTRY)
    SELECT replace(CID,'-','') cid,
    case when upper(trim(CNTRY)) in ('DE','GERMANY') then 'Germany'
	     when upper(trim(CNTRY)) in ('US','USA','UNITED STATES') then 'United States'
	     when trim(CNTRY)='' or CNTRY is null then 'n/a'
    else trim(CNTRY)
    end as CNTRY
      FROM bronze.erp_loc_a101
     set @end_time=GETDATE()
     print'>>loading duration:' + cast(datediff(second,@start_time,@end_time) as nvarchar)+' seconds';
     print '>> ----------------------------------------------';

    --loading erp_px_cat_g1v2
    set @start_time=GETDATE()
    print '>> truncating table:silver.erp_px_cat_g1v2'
    truncate table silver.erp_px_cat_g1v2;
    print '>> insert data into: silver.erp_px_cat_g1v2'
    insert into silver.erp_px_cat_g1v2 (ID,CAT,SUBCAT,MAINTENANCE)
    SELECT ID,CAT,SUBCAT,MAINTENANCE
      FROM bronze.erp_px_cat_g1v2;
      set @end_time=GETDATE()
     print'>>loading duration:' + cast(datediff(second,@start_time,@end_time) as nvarchar)+' seconds';
     print '>> ----------------------------------------------';

     set @batch_end_time=GETDATE()
     print '---------------------------------------'
     print 'loading silver layer is completed';
     print 'total load duration:' + cast(datediff(second,@batch_start_time,@batch_end_time) as nvarchar) + ' seconds';
     print '---------------------------------------'

     end try
	begin catch
		print '======================================================='
		print 'error occured during loading silver layer'
		print 'error msg' + error_message();
		print '======================================================='
	end catch
end
