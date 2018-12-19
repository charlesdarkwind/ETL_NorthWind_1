-- 1. DDL
Use [master]
Go

-- Delete DW if there
if exists (select name from sys.databases where name = N'DWNorthwind')
Begin
	Alter database [DWNorthwind] set SINGLE_USER with rollback immediate;
	Drop database [DWNorthwind];
End
Go

-- Create it
Create database [DWNorthwind] on primary(
	Name = N'DWNorthwind',
	FILENAME =N'C:\temp\DWNorthwind.mdf')
Log On (
	Name = N'DWNorthwind_log',
	FILENAME =N'C:\temp\DWNorthwind_log.LDF');
Go


-- Creer Dimensions
Use [DWNorthwind]
Go

Create table Dim_Products (
	productKey int not null primary key identity,
	productId int not null, -- ancien ID == key..
	productName nvarchar(60) not null,
	categoryId int not null,
	categoryName nvarchar(60) not null,
	supplierId int not null,
	supplierName nvarchar(60) not null,
	quantityPerUnit nvarchar(60) not null,
	unitPrice decimal(6, 2) not null,
	reorderLevel int not null,
	discontinued int not null
);
Go

Create table Dim_Customers (
	customerKey int not null primary key identity,
	customerId nvarchar(10) not null,
	firstName nvarchar(40) not null,
	lastName nvarchar(40) not null,
	fullName nvarchar(60) not null,
	companyName nvarchar(60) not null,
	title nvarchar(40) not null,
	[address] nvarchar(60) not null,
	city nvarchar(40) not null,
	region nvarchar(40),
	postalCode nvarchar(12),
	country nvarchar(40) not null,
	phone nvarchar(40) not null,
	fax nvarchar(40)
);
Go

Create table Dim_Employees (
	employeeKey int not null primary key identity,
	employeeId int not null,
	firstName nvarchar(40) not null,
	lastName nvarchar(40) not null,
	fullName nvarchar(60) not null,
	title nvarchar(40) not null,
	titleOfCourtesy nvarchar(6) not null,
	birthDateKey int not null,
	hireDateKey int not null,
	[address] nvarchar(60) not null,
	city nvarchar(40) not null,
	region nvarchar(40),
	country nvarchar(40) not null,
	phone nvarchar(40) not null,
	extension int not null,
	photo image not null,
	notes nvarchar(MAX) not null,
	reportsTo int,
	photoPath nvarchar(40) not null
);
Go

Create table Dim_Dates (
	[dateKey] int not null primary key identity,
	[date] datetime NOT NULL,
	[dateName] nVarchar(50),
	[month]	int NOT NULL,
	[monthName]	nVarchar(50) NOT NULL,
	[quarter] int NOT NULL,
	[quarterName] nVarchar(50) NOT NULL,
	[year] int NOT NULL,
	[yearName] nVarchar(50) NOT NULL
);
Go

-- Creer table de fait
Create table Fact_Sales ( -- An entry for each products of an order
	saleKey int not null primary key identity,
	orderId int not null,
	customerKey int not null,
	employeeKey int not null,
	orderDateKey int not null,
	requiredDateKey int not null,
	shippedDateKey int,
	productKey int not null,
	productUnitPrice decimal(5, 2) not null,
	productQuantity int not null,
	productDiscount decimal(5, 2) not null,
	orderFreightPrice decimal(6, 2) not null,
	subTotal decimal(10, 2) not null -- total price for the sell of a product
);
Go	

-- creer les foreign keys
Alter Table [dbo].[Dim_Employees] With Check Add Constraint [FK_Dim_Employees_birthDateKey]
Foreign Key([birthDateKey]) References [dbo].[Dim_dates]([dateKey]);

Alter Table [dbo].[Dim_Employees] With Check Add Constraint [FK_Dim_Employees_hireDateKey]
Foreign Key([hireDateKey]) References [dbo].[Dim_dates]([dateKey]);

Alter Table [dbo].[Dim_Employees] With Check Add Constraint [FK_Dim_Employees_reportsTo]
Foreign Key([reportsTo]) References [dbo].[Dim_Employees]([employeeKey]);

Alter Table [dbo].[Fact_Sales] With Check Add Constraint [FK_Fact_Sales_customerKey]
Foreign Key([customerKey]) References [dbo].[Dim_Customers]([customerKey]);

Alter Table [dbo].[Fact_Sales] With Check Add Constraint [FK_Fact_Sales_productKey]
Foreign Key([productKey]) References [dbo].[Dim_Products]([productKey]);

Alter Table [dbo].[Fact_Sales] With Check Add Constraint [FK_Fact_Sales_employeeKey]
Foreign Key([employeeKey]) References [dbo].[Dim_Employees]([employeeKey]);

Alter Table [dbo].[Fact_Sales] With Check Add Constraint [FK_Fact_Sales_orderDateKey]
Foreign Key([orderDateKey]) References [dbo].[Dim_dates]([dateKey]);

Alter Table [dbo].[Fact_Sales] With Check Add Constraint [FK_Fact_Sales_requiredDateKey]
Foreign Key([requiredDateKey]) References [dbo].[Dim_dates]([dateKey]);

Alter Table [dbo].[Fact_Sales] With Check Add Constraint [FK_Fact_Sales_shippedDateKey]
Foreign Key([shippedDateKey]) References [dbo].[Dim_dates]([dateKey]);
Go

-- Create backup
backup database [DWNorthwind]
to disk = 'C:\temp\DWNorthwind_BeforeETL.bak'
go
