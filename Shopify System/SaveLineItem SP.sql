USE [MF67jared.schumacher]
GO

CREATE OR ALTER PROCEDURE [dbo].[SaveLineItem]
@CustomerID int, @ProductID int, @Units numeric(8,0), @ExistingSaleID int = NULL
AS
BEGIN

DECLARE @SalesID int, @ProductName nvarchar(50), @SalesPrice numeric(8,2),
@QtyInStock numeric(6,0), @intCountBefore int, @intCountAfter int, @CustomerOnInvoice int

BEGIN --error checking begins

IF @Units IS NULL OR @Units <= 0 --rejects request if units is 0 or not provided
	BEGIN
		RAISERROR('Check units', 15, 1)
		RETURN
	END

IF NOT EXISTS (SELECT * FROM [dbo].[CustomersTable] WHERE [CustomerID] = @CustomerID) --rejects request if CustomerID is not in CustomersTable
	BEGIN
		RAISERROR('Check CustomerID #', 15, 1)
		RETURN
	END

IF NOT EXISTS (SELECT * FROM [dbo].[ProductsTable] WHERE [ProductID] = @ProductID) --rejects request if ProductID is not in ProductsTable
	BEGIN
		RAISERROR('Check ProductID #', 15, 1)
		RETURN
	END

SET @QtyInStock = (SELECT [StockQty] FROM [dbo].[ProductsTable] WHERE [ProductID] = @ProductID) --looks up current stock level for product

IF @QtyInStock <= 0 --rejects request if no stock quantity is 0
	BEGIN
		RAISERROR('OSWO - No stock for this product, suggest an alternative or process back-order. Program ended.', 15, 1)
		RETURN
	END

IF EXISTS (SELECT * FROM [dbo].[SalesDetailsTable] WHERE [ProductID] = @ProductID AND [SalesID] = @SalesID) --prevents duplicate line items
	BEGIN
				PRINT 'Product ' + CONVERT(nvarchar(6), @ProductID) + ' already on invoice ' 
				+ CONVERT(nvarchar(6), @SalesID) + CHAR(13)
				+ 'USE the Editing Invoice Line Items SP if you want to change units for an existing invoice line item,'
				+ CHAR(13) + 'or to delete an existing line item.' + CHAR(13)
				RETURN
	END
END

BEGIN --code belows only runs if product is not already on invoice

IF @ExistingSaleID > 0 --adds new line items to invoice and add new line items to already existing invoice
	BEGIN
			SET @CustomerOnInvoice = 
			(SELECT TOP 1 [CustomerID] FROM [dbo].[SalesDetailsTable] WHERE [SalesID] = @SalesID)

			IF @CustomerID <> @CustomerOnInvoice
				BEGIN
					PRINT 'The customer ID # provided is incorrect for this invoice, it should be CustomerID ' 
					+ CONVERT(nvarchar(5), @CustomerOnInvoice) + CHAR(13)
					RAISERROR('Sorry, that customer ID # is not correct for this invoice, please check. Processing ended.', 15, 1)
					RETURN
				END
		
			IF EXISTS (SELECT * FROM [dbo].[SalesDetailsTable] WHERE [SalesID] = @ExistingSaleID)
				BEGIN
						SET @SalesID = @ExistingSaleID
				END
	END

IF @ExistingSaleID IS NULL OR @ExistingSaleID = 0 --new invoice started if user did not specify invoice #
		BEGIN
				IF (SELECT COUNT(*) FROM [SalesDetailsTable]) IN (NULL, 0)
						SET @SalesID = 1

				IF (SELECT COUNT(*) FROM [SalesDetailsTable]) >= 1
						SET @SalesID = (SELECT MAX(SalesID) FROM [SalesDetailsTable]) + 1
		END

	IF @QtyInStock < @Units --fulfills only what's available if customer ordered more than what's in stock
			BEGIN
					PRINT 'Insufficient stock, partial fulfillment only. Order quantity reduced to ' 
					+ CONVERT(nvarchar(25), @QtyInStock) + ' units.'
					SET @Units = @QtyInStock --units reduced to what's available
			END

	
	SELECT --automatically adds product name and price 
		@ProductName = ProductName,
		@SalesPrice = SalesPrice
	FROM [dbo].[ProductsTable]
	WHERE ProductID = @ProductID;

	SET @intCountBefore = (SELECT COUNT(*) FROM [dbo].[SalesDetailsTable])

	INSERT [SalesDetailsTable]
		([SalesID], [ProductID], [ProductName], [CustomerID], [Units], [SalesPrice], [StockDeducted], [Shipped])
	VALUES
		(@SalesID, @ProductID, @ProductName, @CustomerID, @Units, @SalesPrice, 'False', 'False')

	SET @intCountAfter = (SELECT COUNT(*) FROM [dbo].[SalesDetailsTable])



		IF @intCountAfter > @intCountBefore --shows message if line item was saved or not
			PRINT 'Line Item Added'
		ELSE
			BEGIN
				PRINT 'Line Item Not Added'
				RETURN
			END

			UPDATE [dbo].[ProductsTable] --automatically updates inventory and metrics for products in ProductsTable
			SET [StockQty] -= @Units
			, [LastSale] = GETDATE()
			, [TotalUnitsSold] += @Units
			, [RevenueGenerated] += (@Units * @SalesPrice)
			, [TotalProfitMade] += (@Units * @SalesPrice) * .333
			WHERE [ProductID] = @ProductID

		UPDATE [dbo].[SalesDetailsTable]
			SET [StockDeducted] = 'True' WHERE [SalesID] = @SalesID AND [ProductID] = @ProductID

	--EXEC [dbo].[CreateNewSalesSummary] @SalesID
	--PRINT 'SalesSummary updated for invoice ' + convert(nvarchar(8), @SalesID)

			SELECT * FROM [dbo].[SalesDetailsTable] WHERE SalesID = @SalesID --shows invoice after new line item added
END

END --end of SP

