USE [MF67jared.schumacher]
GO

CREATE OR ALTER PROCEDURE [dbo].[CreateNewSalesSummary]
@SalesID int, @Remarks nvarchar(255) = NULL OUTPUT
AS
BEGIN

		IF EXISTS (SELECT * FROM [dbo].[SalesSummaryTable] WHERE [SaleID] = @SalesID)
			BEGIN
				DELETE FROM [dbo].[SalesSummaryTable] WHERE [SaleID] = @SalesID
			END

		DECLARE @NumberCategories int = (SELECT COUNT(DISTINCT p.CategoryID)
			FROM [dbo].[SalesDetailsTable]	sd
			INNER JOIN [dbo].[ProductsTable] p
			ON sd.ProductID = p.ProductID
			WHERE sd.SalesID = @SalesID )

		INSERT INTO [dbo].[SalesSummaryTable]
		([SaleID], [CustomerID], [InvoiceDate], [TotalSale], [NumberSKU], [NumberUnits], [NumberCategories])

		SELECT [SalesID], [CustomerID]
		, MAX([InvoiceDate]), SUM([LineTotal]), COUNT([ProductID]), SUM([Units]), @NumberCategories
		FROM [dbo].[SalesDetailsTable]
		WHERE [SalesID] = @SalesID
		GROUP BY [SalesID], [CustomerID]

		UPDATE [dbo].[SalesDetailsTable] SET [Summarized] = 1 WHERE [SalesID] = @SalesID

		SELECT * FROM [dbo].[SalesSummaryTable] WHERE [SalesID] = @SalesID

		SET @Remarks = 'Generated and stored a new summary of invoice ' + convert(nvarchar(5), @SalesID)
		Print @Remarks

END

