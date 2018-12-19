-- 2. ETL
-- Chargement total depuis OLTP
Use [DWNorthwind]
Go
SET STATISTICS TIME OFF;

-- Drop ancienne FKs
Alter Table [dbo].[Dim_Employees] Drop Constraint [FK_Dim_Employees_birthDateKey];
Alter Table [dbo].[Dim_Employees] Drop Constraint [FK_Dim_Employees_hireDateKey];
Alter Table [dbo].[Dim_Employees] Drop Constraint [FK_Dim_Employees_reportsTo];
Alter Table [dbo].[Fact_Sales] Drop Constraint [FK_Fact_Sales_customerKey];
Alter Table [dbo].[Fact_Sales] Drop Constraint [FK_Fact_Sales_productKey];
Alter Table [dbo].[Fact_Sales] Drop Constraint [FK_Fact_Sales_employeeKey];
Alter Table [dbo].[Fact_Sales] Drop Constraint [FK_Fact_Sales_orderDateKey];
Alter Table [dbo].[Fact_Sales] Drop Constraint [FK_Fact_Sales_requiredDateKey];
Alter Table [dbo].[Fact_Sales] Drop Constraint [FK_Fact_Sales_shippedDateKey];
Go

-- Vider ancienne tables
Truncate Table [dbo].[Dim_Products];
Truncate Table [dbo].[Dim_Customers];
Truncate Table [dbo].[Dim_Employees];
Truncate Table [dbo].[Dim_Dates];
Truncate Table [dbo].[Fact_Sales];
Go

-- Charger Dimension Products
Insert Into Dim_Products
Select 
	productId = p.ProductID,
	productName = p.ProductName,
	categoryId = p.CategoryID,
	categoryName = c.CategoryName,
	supplierId = p.SupplierID,
	supplierName = s.CompanyName,
	quantityPerUnit = p.QuantityPerUnit,
	unitPrice = p.UnitPrice,
	reorderLevel = p.ReorderLevel,
	discontinued = p.Discontinued
From Northwind.[dbo].[Products] p
Join Northwind.[dbo].[Categories] c
On c.CategoryID = p.CategoryID
Join Northwind.[dbo].[Suppliers] s
On s.SupplierID = p.SupplierID;
Go

-- Charger Dimension Customers
Insert Into Dim_Customers
Select
	customerId = c.CustomerID,
	firstName = SUBSTRING(c.ContactName, 
						  1, 
						  CHARINDEX(' ', c.ContactName) - 1),
	lastName = SUBSTRING(c.ContactName, 
						 CHARINDEX(' ', c.ContactName) + 1, 
						 LEN(c.ContactName) - CHARINDEX(' ', c.ContactName)),
	fullName = c.ContactName,
	companyName = c.CompanyName,
	title = c.ContactTitle,
	[address] = c.[Address],
	city = c.City,
	region = Cast( isNull( c.Region, 'Unknown') as nvarchar(20) ),
	postalCode = Cast( isNull( c.PostalCode, 'Unknown') as nvarchar(20) ),
	country = c.Country,
	phone = c.Phone,
	fax = Cast( isNull( c.Fax, 'Unknown') as nvarchar(20) )
From Northwind.[dbo].[Customers] c;
Go

-- Charger Dimension Dates
SET NOCOUNT ON;
Declare @StartDate datetime = '19370101';
Declare @EndDate datetime = '20161110';
Declare @DateInProgress datetime = @StartDate;

While @DateInProgress <= @EndDate
	Begin
		Insert Into Dim_Dates Values (
			@DateInProgress,								-- datetime stock�e dans la table
			DATENAME( WEEKDAY, @DateInProgress ),			-- nom du jour
			MONTH( @DateInProgress ),						-- mois (num)
			DATENAME( MONTH, @DateInProgress ),				-- nom du mois
			DATENAME( QUARTER, @DateInProgress ),			-- le num�ro du trimestre
			'Q' + DATENAME( MONTH, @DateInProgress )		-- un nom de trimestre obtenu en concat�nant plusieurs info
				+ ' - ' + CAST( YEAR(@DateInProgress) as nvarchar(50) ),
			YEAR( @DateInProgress ),						-- annee en nombre
			CAST( YEAR( @DateInProgress ) as nvarchar(50) )	-- annee en chaine de char
		);
		-- Incremente 
		Set @DateInProgress = DATEADD( DAY, 1, @DateInProgress );
	End
SET NOCOUNT OFF;
Go

-- Date unknown (null source)
SET IDENTITY_INSERT [dbo].[Dim_Dates] ON;
Insert Into Dim_Dates (
		[dateKey],
		[date],
		[dateName],
		[month],
		[monthName],
		[quarter],
		[quarterName],
		[year],
		[yearName] )
	Select
		[dateKey] = -1,
		[date] = Cast('01/01/1900' as nvarchar(50)),
		[dateName] = Cast('Unknown Day' as nvarchar(50)),
		[month]	= -1,
		[monthName]	= Cast('Unknown Month' as nvarchar(50)),
		[quarter] = -1,
		[quarterName] = Cast('Unknown Quarter' as nvarchar(50)),
		[year] = -1,
		[yearName] = Cast('Unknown Year' as nvarchar(50))
SET IDENTITY_INSERT [dbo].[Dim_Dates] OFF;
Go

-- Charger Dimension Employees
Insert Into Dim_Employees
Select 
	employeeId = e.EmployeeID,
	firstName = e.FirstName,
	lastName = e.LastName,
	fullName = e.FirstName + ' ' + e.LastName,
	title = e.Title,
	titleOfCourtesy = e.TitleOfCourtesy,
	birthDateKey = b.dateKey,
	hireDateKey = h.dateKey,
	[address] = e.[Address],
	city = e.City,
	region = Cast( isNull( e.Region, 'Unknown') as nvarchar(20) ),
	country = e.Country,
	phone = e.HomePhone,
	extension = e.Extension,
	photo = e.Photo,
	notes = e.Notes,
	reportsTo = e.ReportsTo,
	photoPath = e.PhotoPath
From Northwind.[dbo].[Employees] e
Join Dim_Dates b
On e.BirthDate = b.[date]
Join Dim_Dates h
On e.HireDate = h.[date];
Go

-- Charger table de faits
Insert Into Fact_Sales
Select 
	orderId = d.OrderID,
	customerKey = c.customerKey,
	employeeKey = o.EmployeeID,		-- same as key
	orderDateKey = isNull( d1.dateKey, -1 ),
	requiredDateKey = isNull( d2.dateKey, -1 ),
	shippedDateKey = isNull( d3.dateKey, -1 ),
	productKey = d.ProductID,		-- same as key
	productUnitPrice = d.UnitPrice,
	productQuantity = d.Quantity,
	productDiscount = d.Discount,
	orderFreightPrice = o.Freight,
	subTotal = (d.UnitPrice * d.Quantity) - (d.UnitPrice * d.Discount)
From Northwind.[dbo].Orders o
join Dim_Customers c
on o.CustomerID = c.customerId
join Northwind.[dbo].[Order Details] d
on o.OrderID = d.OrderID
left join Dim_Dates d1
on o.OrderDate = d1.[date]
left join Dim_Dates d2
on o.RequiredDate = d2.[date]
left join Dim_Dates d3
on o.ShippedDate = d3.[date];


-- Refaire les foreign keys
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
to disk = 'C:\temp\DWNorthwind_AfterETL.bak'
Go
