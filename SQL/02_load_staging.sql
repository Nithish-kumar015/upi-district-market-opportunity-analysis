-- Load the processed district-month CSV only when staging is empty.

IF NOT EXISTS
(
    SELECT 1
    FROM dbo.StgUPIDistrictMonthly
)
BEGIN
    BULK INSERT dbo.StgUPIDistrictMonthly
    FROM 'C:\Users\Admin\Documents\Analytics projects\UPI_payment_trends_analysis\Data\processed\upi_district_monthly.csv'
    WITH
    (
        FORMAT = 'CSV',
        FIRSTROW = 2,
        FIELDQUOTE = '"',
        CODEPAGE = '65001',
        KEEPNULLS
    );

    PRINT N'CSV import completed.';
END
ELSE
BEGIN
    PRINT N'Staging table already contains data. Import skipped.';
END;

SELECT COUNT(*) AS StageRows
FROM dbo.StgUPIDistrictMonthly;