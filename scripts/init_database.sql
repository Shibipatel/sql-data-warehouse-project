use master;

-- create the 'datawarehouse' database

go 
create database Datawarehouse; 
go
use Datawarehouse
go

-- create schema

create schema bronze;
go
create schema silver;
go
create schema gold;
