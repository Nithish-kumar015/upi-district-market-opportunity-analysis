-- 1. Check source row and label coverage.
SELECT
    COUNT(*) AS StageRows,
    COUNT(DISTINCT ReportMonthRaw) AS MonthCount,
    MIN(TRY_CONVERT(date, ReportMonthRaw, 23)) AS FirstMonth,
    MAX(TRY_CONVERT(date, ReportMonthRaw, 23)) AS LastMonth,
    COUNT(DISTINCT StateName) AS StateCount,
    COUNT(DISTINCT CONCAT(StateName, N'|', DistrictName)) AS DistrictCount,
    SUM(CASE
            WHEN NULLIF(LTRIM(RTRIM(ReportMonthRaw)), N'') IS NULL
            THEN 1 ELSE 0
        END) AS MissingMonthRows,
    SUM(CASE
            WHEN NULLIF(LTRIM(RTRIM(StateName)), N'') IS NULL
            THEN 1 ELSE 0
        END) AS MissingStateRows,
    SUM(CASE
            WHEN NULLIF(LTRIM(RTRIM(DistrictName)), N'') IS NULL
            THEN 1 ELSE 0
        END) AS MissingDistrictRows
FROM dbo.StgUPIDistrictMonthly;


-- 2. Check for duplicate district-month rows.
-- Expected: no rows returned.
SELECT
    ReportMonthRaw,
    StateName,
    DistrictName,
    COUNT(*) AS DuplicateCount
FROM dbo.StgUPIDistrictMonthly
GROUP BY
    ReportMonthRaw,
    StateName,
    DistrictName
HAVING COUNT(*) > 1
ORDER BY
    ReportMonthRaw,
    StateName,
    DistrictName;


-- 3. Check blank metrics and failed numeric conversions.
SELECT
    SUM(CASE
            WHEN NULLIF(LTRIM(RTRIM(TransactionValueRaw)), N'') IS NULL
            THEN 1 ELSE 0
        END) AS BlankValueRows,
    SUM(CASE
            WHEN NULLIF(LTRIM(RTRIM(TransactionValueRaw)), N'') IS NOT NULL
             AND TRY_CONVERT(decimal(20,2), TransactionValueRaw) IS NULL
            THEN 1 ELSE 0
        END) AS InvalidValueRows,
    SUM(CASE
            WHEN NULLIF(LTRIM(RTRIM(TransactionCountRaw)), N'') IS NULL
            THEN 1 ELSE 0
        END) AS BlankCountRows,
    SUM(CASE
            WHEN NULLIF(LTRIM(RTRIM(TransactionCountRaw)), N'') IS NOT NULL
             AND TRY_CONVERT(bigint, TransactionCountRaw) IS NULL
            THEN 1 ELSE 0
        END) AS InvalidCountRows,
    SUM(CASE
            WHEN NULLIF(LTRIM(RTRIM(TransactionValueSharePctRaw)), N'') IS NOT NULL
             AND TRY_CONVERT(decimal(9,4), TransactionValueSharePctRaw) IS NULL
            THEN 1 ELSE 0
        END) AS InvalidValueShareRows,
    SUM(CASE
            WHEN NULLIF(LTRIM(RTRIM(TransactionCountSharePctRaw)), N'') IS NOT NULL
             AND TRY_CONVERT(decimal(9,4), TransactionCountSharePctRaw) IS NULL
            THEN 1 ELSE 0
        END) AS InvalidCountShareRows
FROM dbo.StgUPIDistrictMonthly;


-- 4. Check for negative metric values.
SELECT
    SUM(CASE
            WHEN TRY_CONVERT(decimal(20,2), TransactionValueRaw) < 0
            THEN 1 ELSE 0
        END) AS NegativeValueRows,
    SUM(CASE
            WHEN TRY_CONVERT(bigint, TransactionCountRaw) < 0
            THEN 1 ELSE 0
        END) AS NegativeCountRows,
    SUM(CASE
            WHEN TRY_CONVERT(decimal(9,4), TransactionValueSharePctRaw) < 0
            THEN 1 ELSE 0
        END) AS NegativeValueShareRows,
    SUM(CASE
            WHEN TRY_CONVERT(decimal(9,4), TransactionCountSharePctRaw) < 0
            THEN 1 ELSE 0
        END) AS NegativeCountShareRows
FROM dbo.StgUPIDistrictMonthly;


-- 5. Check which transaction metrics are present together.
WITH MetricAvailability AS
(
    SELECT
        CASE
            WHEN NULLIF(LTRIM(RTRIM(TransactionValueRaw)), N'') IS NOT NULL
             AND NULLIF(LTRIM(RTRIM(TransactionCountRaw)), N'') IS NOT NULL
                THEN N'Both present'
            WHEN NULLIF(LTRIM(RTRIM(TransactionValueRaw)), N'') IS NOT NULL
                THEN N'Value only'
            WHEN NULLIF(LTRIM(RTRIM(TransactionCountRaw)), N'') IS NOT NULL
                THEN N'Count only'
            ELSE N'Both missing'
        END AS MetricAvailability
    FROM dbo.StgUPIDistrictMonthly
)
SELECT
    MetricAvailability,
    COUNT(*) AS RowsInCategory
FROM MetricAvailability
GROUP BY MetricAvailability
ORDER BY MetricAvailability;


-- 6. Reconcile fact table coverage and missing metrics.
SELECT
    COUNT(*) AS FactRows,
    COUNT(DISTINCT MonthKey) AS MonthCount,
    COUNT(DISTINCT DistrictKey) AS DistrictCount,
    SUM(CASE WHEN TransactionValue IS NULL THEN 1 ELSE 0 END) AS MissingValueRows,
    SUM(CASE WHEN TransactionCount IS NULL THEN 1 ELSE 0 END) AS MissingCountRows
FROM dbo.FactUPIDistrictMonthly;


-- 7. Confirm fact table foreign-key relationships.
SELECT
    fk.name AS ForeignKeyName,
    OBJECT_NAME(fkc.parent_object_id) AS FactTable,
    COL_NAME(fkc.parent_object_id, fkc.parent_column_id) AS FactColumn,
    OBJECT_NAME(fkc.referenced_object_id) AS RelatedTable,
    COL_NAME(fkc.referenced_object_id, fkc.referenced_column_id) AS RelatedColumn
FROM sys.foreign_keys AS fk
JOIN sys.foreign_key_columns AS fkc
    ON fk.object_id = fkc.constraint_object_id
WHERE fk.parent_object_id = OBJECT_ID(N'dbo.FactUPIDistrictMonthly')
ORDER BY fk.name;
