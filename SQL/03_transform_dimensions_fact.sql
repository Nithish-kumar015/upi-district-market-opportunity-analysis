-- Load one row per state and district into the district dimension.
INSERT INTO dbo.DimDistrict (StateName, DistrictName)
SELECT DISTINCT
    LTRIM(RTRIM(s.StateName)),
    LTRIM(RTRIM(s.DistrictName))
FROM dbo.StgUPIDistrictMonthly AS s
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.DimDistrict AS d
    WHERE d.StateName = LTRIM(RTRIM(s.StateName))
      AND d.DistrictName = LTRIM(RTRIM(s.DistrictName))
);


-- Load one row per observed month into the month dimension.
INSERT INTO dbo.DimMonth
    (MonthKey, MonthStart, CalendarYear, MonthNumber, MonthName, QuarterNumber)
SELECT DISTINCT
    YEAR(x.MonthStart) * 100 + MONTH(x.MonthStart),
    x.MonthStart,
    YEAR(x.MonthStart),
    MONTH(x.MonthStart),
    DATENAME(MONTH, x.MonthStart),
    DATEPART(QUARTER, x.MonthStart)
FROM
(
    SELECT TRY_CONVERT(date, ReportMonthRaw, 23) AS MonthStart
    FROM dbo.StgUPIDistrictMonthly
) AS x
WHERE x.MonthStart IS NOT NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM dbo.DimMonth AS m
      WHERE m.MonthStart = x.MonthStart
  );


-- Convert raw metric text to numeric types and load the fact table.
-- Blank metric cells stay NULL.
INSERT INTO dbo.FactUPIDistrictMonthly
    (MonthKey, DistrictKey, TransactionValue, TransactionCount,
     TransactionValueSharePct, TransactionCountSharePct)
SELECT
    m.MonthKey,
    d.DistrictKey,
    TRY_CONVERT(decimal(20,2), NULLIF(LTRIM(RTRIM(s.TransactionValueRaw)), N'')),
    TRY_CONVERT(bigint, NULLIF(LTRIM(RTRIM(s.TransactionCountRaw)), N'')),
    TRY_CONVERT(decimal(9,4), NULLIF(LTRIM(RTRIM(s.TransactionValueSharePctRaw)), N'')),
    TRY_CONVERT(decimal(9,4), NULLIF(LTRIM(RTRIM(s.TransactionCountSharePctRaw)), N''))
FROM dbo.StgUPIDistrictMonthly AS s
JOIN dbo.DimMonth AS m
    ON m.MonthStart = TRY_CONVERT(date, s.ReportMonthRaw, 23)
JOIN dbo.DimDistrict AS d
    ON d.StateName = LTRIM(RTRIM(s.StateName))
   AND d.DistrictName = LTRIM(RTRIM(s.DistrictName))
WHERE NOT EXISTS
(
    SELECT 1
    FROM dbo.FactUPIDistrictMonthly AS f
    WHERE f.MonthKey = m.MonthKey
      AND f.DistrictKey = d.DistrictKey
);