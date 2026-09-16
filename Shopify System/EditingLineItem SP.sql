--This is the code to create or alter a stored procedure that provides line item editing and deleting functionality.
--Gives the option to increase or decrease the units for one line item. Use [dbo].[SaveLineItem] to add a new line item to the SalesDetails table

USE [MF67jared.schumacher]
GO

--Defines input parameters needed when executing SP
CREATE OR ALTER PROCEDURE [dbo].[EditingLineItems] 
@TAType nvarchar(12), @SalesID int, @ProductId int, @FinalUnitsForLI numeric(8,0) = NULL 

AS
BEGIN --Starts the beginning of the code for the script and matches to the end on line 203
	
	--Declares local variables used throughout the script
	DECLARE @ProductName nvarchar(40), @SalesPrice numeric(8,0), @QtyInStock numeric(6,0), @UnitsOnLI numeric(8,0) 
	, @IncreaseInLIUnits numeric(8,0), @DecreaseInLIUnits numeric(8,0), @StockAlreadyDeducted bit

	BEGIN --This section (line 16-73) handles the error checking 

			--Makes sure the user entered a valid transaction type (INCREASE, DECREASE, DELETE)
			IF UPPER(@TAType) NOT IN ('INCREASE', 'DECREASE', 'DELETE') 
				BEGIN
						RAISERROR('TAType must be Increase, Decrease, or Delete. Please rectify.', 16, 1);
						RETURN;
				END

			--Makes sure the user entered a valid SalesID #
			IF NOT EXISTS (SELECT * FROM [SalesDetailsTable] WHERE [SalesID] = @SalesID) 
				BEGIN
						RAISERROR('Please check SalesID #', 16, 1);
						RETURN;
				END

			--Makes sure the user entered a valid ProductID #
			IF NOT EXISTS (SELECT * FROM [ProductsTable] WHERE [ProductID] = @ProductID) 
				BEGIN
						RAISERROR('Please check ProductID #', 16, 1);
						RETURN;
				END

			--Confirms if product is actually on invoice;If not, provides list of products for the invoice
			IF NOT EXISTS (SELECT * FROM [SalesDetailsTable] WHERE [ProductID] = @ProductID AND [SalesID] = @SalesID) --
				BEGIN
						DECLARE @ProductsOnOrder nvarchar(100)

						--Creates a list of ProductID's in a subquery, then loads them into a neat list using string_agg
						SELECT @ProductsOnOrder = STRING_AGG(CONVERT(nvarchar(300), subql.ProductID), N', ')
						FROM
							(	SELECT ProductID FROM [SalesDetailsTable]
								WHERE [SalesID] = @SalesID
							) as subql

						--Retrieves product name to match the list of ProductIDs
						SET @ProductName = (SELECT [ProductName] FROM [dbo].[ProductsTable]
						WHERE [ProductID] = @ProductID)

						--Provides messages when error occurs
						PRINT 'Product # ' +CONVERT(nvarchar(20), @ProductID) + ' ' + @ProductName
						+ ' was not sold on SalesID ' + CONVERT(nvarchar(6), @SalesID) + char(13)
						+ char(13) + 'The product(s) for that invoice are '		+ @ProductsOnOrder + char(13)
						+ 'Use the SaveLineItem SP if you want to add a new product to the invoice. '
						+ char(13)

						RAISERROR('Please check the ProductID and read the error message ', 16, 1)
						RETURN
				END

			--If increasing/decreasing units, user must provide a valid positive number
			IF UPPER(@TAType) IN ('INCREASE', 'DECREASE')
				IF @FinalUnitsFORLI IS NULL OR @FinalUnitsForLI <= 0
					BEGIN
							RAISERROR('Please specify a postive number for the final unit amount. 
							If you want to set zero out (remove) the line item, then use the DELETE option.', 16, 1);
							RETURN
					END

			--Prevents the invoice from edits if already shipped
			IF EXISTS (SELECT 1 FROM [SalesDetailsTable] WHERE [SalesID] = @SalesID AND [Shipped] = 1)
					BEGIN
							RAISERROR('That invoice has already shipped. Start new invoice as needed. Processing ended.', 16, 1);
							RETURN;
					END

	END --Ends the section for error-checking


	IF UPPER(@TAType) = 'DELETE' --This section (line 76-105) handles DELETING a LI
		BEGIN

				--Checks whether stock was already deducted for this LI
				SET @StockAlreadyDeducted = (SELECT [StockDeducted] FROM [SalesDetailsTable]
							WHERE [SalesID] = @SalesID AND [ProductID] = @ProductID)

				--Grabs current unit count on LI before deleting
				SET @UnitsOnLI = (SELECT [Units] FROM [SalesDetailsTable]
							WHERE [ProductID] = @ProductID AND [SalesID] = @SalesID)

				--If stock already deducted, puts units back into stock
				IF @StockAlreadyDeducted = 1
					BEGIN
							--Updates metrics for product after deleting LI
							UPDATE [dbo].[ProductsTable]
								SET [StockQty] += @UnitsOnLI
								, [TotalUnitsSold] -= @UnitsOnLI
								, [RevenueGenerated] -= (@UnitsOnLI * [SalesPrice])
								, [TotalProfitMade] -= (@UnitsOnLI * [SalesPrice]) * .33
							WHERE [dbo].[ProductsTable].[ProductID] = @ProductID

							PRINT 'Products table inventory level and marketing metrics successfully updated
							to reflect deleted line item'
					END

			--Deletes the LI
			DELETE FROM [SalesDetailsTable] WHERE [ProductID] = @ProductID AND [SalesID] = @SalesID

			--Deletes current Sales summary for invoice and generates a new Sales Summary 
			EXEC [dbo].[CreateNewSalesSummary] @SalesID
			PRINT 'Line item deleted. Sales summary updated for invoice ' + convert(nvarchar(8), @SalesID)

			--Show updated line item
			SELECT * FROM [dbo].[SalesDetailsTable] WHERE [SalesID] = @SalesID

		END --Ends section on deleting a LI

		IF UPPER(@TAType) = 'INCREASE' --This section (line 107-168) handles INCREASING units on an existing LI
			BEGIN

					--Checks the quantity in stock for product
					SET @QtyInStock = (SELECT [StockQty] FROM [dbo].[ProductsTable] WHERE [ProductID] = @ProductID)

					--If quantity is 0, units cannot be increase
					If @QtyInStock = 0
						BEGIN
							RAISERROR('OSWO - No stock, cannot increase units for this line item.
							Keep line item unchanged. Script exited. ', 16, 1);
							RETURN;
						END

					--Grabs the current units on the LI
					SET @UnitsOnLI = (SELECT [Units] FROM [dbo].[SalesDetailsTable]
						WHERE [ProductID] = @ProductID and [SalesID] = @SalesID)

					--Prevents user decreasing units if target unit increase is lower than current #
					IF @UnitsOnLI > @FinalUnitsForLI
						BEGIN
							RAISERROR('If you want to decrease # units please use transaction type Decrease', 16, 1);
							RETURN
						END

					--Calculates how many units to be added
					SET @IncreaseInLIUnits = @FinalUnitsForLI - @UnitsOnLI

					--Prints error message if IncreaseInUnits input is null
					If @IncreaseInLIUnits IS NULL
						BEGIN 
							PRINT 'Inputs'
							RETURN
						END

					--Satisfies line increase if enough quantity in stock
					IF @QtyInStock >= @IncreaseInLIUnits
						PRINT 'Line item increased to full amount requested. Products table,
						SalesDetails table and SalesSummary tables updated.'

					--If quantity in stock is lower than requested increase, cap at what is available (partial fulfillment) 
					IF @QtyInStock < @IncreaseInLIUnits
						BEGIN
								SET @IncreaseInLIUnits = @QtyInStock

								PRINT 'Partial order - shipped short. Only ' + CONVERT(nvarchar(6), @QtyInStock)
								+ ' units in stock for product ' + CONVERT(nvarchar(20), @ProductID) + char(13)
								+ 'All available stock assigned to order.' + char(13)
								+ 'Line item updated, and product record updated. Inquire about 2nd shipment.' + char(13)
						END

							--Apply increase to LI and refresh invoice date
							UPDATE [dbo].[SalesDetailsTable]
							SET [Units] += @IncreaseInLIUnits
							, [InvoiceDate] = GETDATE()
							WHERE [ProductID] = @ProductID and [SalesID] = @SalesID

							--Updates ProductTable to show new metrics
							UPDATE [dbo].[ProductsTable]
							SET [StockQty] -= @IncreaseInLIUnits
							, [TotalUnitsSold] += @IncreaseInLIUnits
							, [RevenueGenerated] += (@IncreaseInLIUnits * [SalesPrice])
							, [TotalProfitMade] += (@IncreaseInLIUnits * [SalesPrice]) * .33
							, [LastSale] = GETDATE()
							WHERE [dbo].[ProductsTable].[ProductID] = @ProductID

							--Shows the updated invoice
							SELECT * FROM [dbo].[SalesDetailsTable] WHERE [SalesID] = @SalesID

							--Updates SalesSummary for invoice
							EXEC [dbo].[CreateNewSalesSummary] @SalesID
							PRINT 'Sales Summary updated for invoice ' + CONVERT(nvarchar(8), @SalesID)

			END --Ends section on increasing units on LI

			IF UPPER(@TAType) = 'DECREASE' --This section (line 170-201) handles DECREASING units on an existing LI
				BEGIN

						--Grabs the current units on LI
						SET @UnitsOnLI = (SELECT [Units] FROM [dbo].[SalesDetailsTable]
											WHERE [ProductID] = @ProductId AND [SalesID] = @SalesID)

						--Prevents user from increasing units if target unit increase is higher than current #
						IF @FinalUnitsForLI > @UnitsOnLI
						BEGIN
								RAISERROR('If you want to increase # units please use transaction type Increase', 16, 1);
								RETURN;
						END

						--Calculates how many units are being removed and current sales price for product
						SET @DecreaseInLIUnits = @UnitsOnLI - @FinalUnitsForLI
						SET @SalesPrice = (SELECT [SalesPrice] FROM [dbo].[ProductsTable] WHERE [ProductID] = @ProductID)

						PRINT convert(nvarchar(20), @UnitsOnLI) + ' units currently on order for product ' 
						+ convert(nvarchar(25), @ProductID) + 'Decreasing to ' + convert(nvarchar(25), @FinalUnitsForLI)

							--Updates units on LI to new #
							UPDATE [SalesDetailsTable]
							SET [Units] = @FinalUnitsForLI
							WHERE [ProductID] = @ProductID AND [SalesID] = @SalesID

							--Puts unsold units back in stock and updates metrics
							UPDATE [dbo].[ProductsTable]
							SET [StockQty] += @DecreaseInLIUnits
							, [TotalUnitsSold] -= @DecreaseInLIUnits
							, [RevenueGenerated] -= (@DecreaseInLIUnits * [SalesPrice])
							, [TotalProfitMade] -= (@DecreaseInLIUnits * [SalesPrice]) * .33
							WHERE [ProductID] = @ProductID

							--Shows updated LI
							SELECT * FROM [SalesDetailsTable] WHERE [SalesID] = @SalesID

							--Updates SalesSummary for the invoice
							EXEC [dbo].[CreateNewSalesSummary] @SalesID
							PRINT 'Sales Summary updated for invoice ' + convert(nvarchar(8), @SalesID)

					END --Ends section on decreasing units on LI

END --Ends code for SP
