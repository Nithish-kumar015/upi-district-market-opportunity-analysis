-- Q1: How did district-reported transaction value change each month?

WITH MonthlyValue AS
(
    SELECT
        m.MonthStart,
        SUM(f.TransactionValue) AS TotalTransactionValue,
        SUM(CASE WHEN f.TransactionValue IS NULL THEN 1 ELSE 0 END)
            AS MissingValueRows
    FROM dbo.FactUPIDistrictMonthly AS f
    JOIN dbo.DimMonth AS m
        ON m.MonthKey = f.MonthKey
    GROUP BY m.MonthStart
),
ValueWithPreviousMonth AS
(

    
    SELECT
        MonthStart,
        TotalTransactionValue,
        MissingValueRows,
        LAG(TotalTransactionValue) OVER (ORDER BY MonthStart)
            AS PreviousMonthValue
    FROM MonthlyValue
)
SELECT
    MonthStart,
    TotalTransactionValue,
    PreviousMonthValue,
    TotalTransactionValue - PreviousMonthValue AS ValueChange,
    100.0 * (TotalTransactionValue - PreviousMonthValue)
        / NULLIF(PreviousMonthValue, 0) AS ValueChangePct,
    MissingValueRows
FROM ValueWithPreviousMonth
ORDER BY MonthStart;

-- Q2: How did district-reported transaction count change each month?

WITH MonthlyCount AS
(
    SELECT
        m.MonthStart,
        SUM(f.TransactionCount) AS TotalTransactionCount,
        SUM(CASE WHEN f.TransactionCount IS NULL THEN 1 ELSE 0 END)
            AS MissingCountRows
    FROM dbo.FactUPIDistrictMonthly AS f
    JOIN dbo.DimMonth AS m
        ON m.MonthKey = f.MonthKey
    GROUP BY m.MonthStart
),
CountWithPreviousMonth AS
(
    SELECT
        MonthStart,
        TotalTransactionCount,
        MissingCountRows,
        LAG(TotalTransactionCount) OVER (ORDER BY MonthStart)
            AS PreviousMonthCount
    FROM MonthlyCount
)
SELECT
    MonthStart,
    TotalTransactionCount,
    PreviousMonthCount,
    TotalTransactionCount - PreviousMonthCount AS CountChange,
    100.0 * (TotalTransactionCount - PreviousMonthCount)
        / NULLIF(PreviousMonthCount, 0) AS CountChangePct,
    MissingCountRows
FROM CountWithPreviousMonth
ORDER BY MonthStart;

-- Q3: Which month had the largest absolute month-over-month
-- drop in transaction value?

WITH MonthlyValue AS
(
    SELECT
        m.MonthStart,
        SUM(f.TransactionValue) AS TotalTransactionValue
    FROM dbo.FactUPIDistrictMonthly AS f
    JOIN dbo.DimMonth AS m
        ON m.MonthKey = f.MonthKey
    GROUP BY m.MonthStart
),
ValueChanges AS
(
    SELECT
        MonthStart,
        TotalTransactionValue,
        LAG(TotalTransactionValue) OVER (ORDER BY MonthStart)
            AS PreviousMonthValue
    FROM MonthlyValue
)
SELECT TOP (1)
    MonthStart AS DeclineMonth,
    PreviousMonthValue,
    TotalTransactionValue,
    TotalTransactionValue - PreviousMonthValue AS ValueChange,
    100.0 * (TotalTransactionValue - PreviousMonthValue)
        / NULLIF(PreviousMonthValue, 0) AS ValueChangePct
FROM ValueChanges
WHERE TotalTransactionValue < PreviousMonthValue
ORDER BY ValueChange ASC;

-- Q4: Which month had the largest percentage
-- month-over-month drop in transaction count?

WITH MonthlyCount AS
(
    SELECT
        m.MonthStart,
        SUM(f.TransactionCount) AS TotalTransactionCount
    FROM dbo.FactUPIDistrictMonthly AS f
    JOIN dbo.DimMonth AS m
        ON m.MonthKey = f.MonthKey
    GROUP BY m.MonthStart
),
CountChanges AS
(
    SELECT
        MonthStart,
        TotalTransactionCount,
        LAG(TotalTransactionCount) OVER (ORDER BY MonthStart)
            AS PreviousMonthCount
    FROM MonthlyCount
)
SELECT TOP (1)
    MonthStart AS DeclineMonth,
    PreviousMonthCount,
    TotalTransactionCount,
    TotalTransactionCount - PreviousMonthCount AS CountChange,
    100.0 * (TotalTransactionCount - PreviousMonthCount)
        / NULLIF(PreviousMonthCount, 0) AS CountChangePct
FROM CountChanges
WHERE TotalTransactionCount < PreviousMonthCount
ORDER BY CountChangePct ASC;

-- Q5: Which states contributed the most to reported
-- transaction value in the latest month?

WITH LatestMonth AS
(
    SELECT MAX(MonthStart) AS MonthStart
    FROM dbo.DimMonth
),
StateTotals AS
(
    SELECT
        m.MonthStart,
        d.StateName,
        SUM(f.TransactionValue) AS StateTransactionValue
    FROM dbo.FactUPIDistrictMonthly AS f
    JOIN dbo.DimMonth AS m
        ON m.MonthKey = f.MonthKey
    JOIN dbo.DimDistrict AS d
        ON d.DistrictKey = f.DistrictKey
    JOIN LatestMonth AS lm
        ON lm.MonthStart = m.MonthStart
    GROUP BY
        m.MonthStart,
        d.StateName
),
RankedStates AS
(
    SELECT
        MonthStart,
        StateName,
        StateTransactionValue,
        100.0 * StateTransactionValue
            / NULLIF(SUM(StateTransactionValue) OVER (), 0) AS ValueSharePct,
        RANK() OVER (ORDER BY StateTransactionValue DESC) AS ValueRank
    FROM StateTotals
)
SELECT
    MonthStart,
    StateName,
    StateTransactionValue,
    ValueSharePct,
    ValueRank
FROM RankedStates
WHERE ValueRank <= 10
ORDER BY ValueRank, StateName;

-- Q6: Which states contributed the most to reported
-- transaction count in the latest month?

WITH LatestMonth AS
(
    SELECT MAX(MonthStart) AS MonthStart
    FROM dbo.DimMonth
),
StateTotals AS
(
    SELECT
        m.MonthStart,
        d.StateName,
        SUM(f.TransactionCount) AS StateTransactionCount
    FROM dbo.FactUPIDistrictMonthly AS f
    JOIN dbo.DimMonth AS m
        ON m.MonthKey = f.MonthKey
    JOIN dbo.DimDistrict AS d
        ON d.DistrictKey = f.DistrictKey
    JOIN LatestMonth AS lm
        ON lm.MonthStart = m.MonthStart
    GROUP BY
        m.MonthStart,
        d.StateName
),
RankedStates AS
(
    SELECT
        MonthStart,
        StateName,
        StateTransactionCount,
        100.0 * StateTransactionCount
            / NULLIF(SUM(StateTransactionCount) OVER (), 0) AS CountSharePct,
        RANK() OVER (ORDER BY StateTransactionCount DESC) AS CountRank
    FROM StateTotals
)
SELECT
    MonthStart,
    StateName,
    StateTransactionCount,
    CountSharePct,
    CountRank
FROM RankedStates
WHERE CountRank <= 10
ORDER BY CountRank, StateName;

-- Q7: Which districts had the highest transaction value
-- in the latest month?

WITH LatestMonth AS
(
    SELECT MAX(MonthStart) AS MonthStart
    FROM dbo.DimMonth
),
DistrictTotals AS
(
    SELECT
        m.MonthStart,
        d.StateName,
        d.DistrictName,
        SUM(f.TransactionValue) AS DistrictTransactionValue
    FROM dbo.FactUPIDistrictMonthly AS f
    JOIN dbo.DimMonth AS m
        ON m.MonthKey = f.MonthKey
    JOIN dbo.DimDistrict AS d
        ON d.DistrictKey = f.DistrictKey
    JOIN LatestMonth AS lm
        ON lm.MonthStart = m.MonthStart
    GROUP BY
        m.MonthStart,
        d.StateName,
        d.DistrictName
),
RankedDistricts AS
(
    SELECT
        MonthStart,
        StateName,
        DistrictName,
        DistrictTransactionValue,
        100.0 * DistrictTransactionValue
            / NULLIF(SUM(DistrictTransactionValue) OVER (), 0) AS ValueSharePct,
        RANK() OVER (ORDER BY DistrictTransactionValue DESC) AS ValueRank
    FROM DistrictTotals
)
SELECT
    MonthStart,
    StateName,
    DistrictName,
    DistrictTransactionValue,
    ValueSharePct,
    ValueRank
FROM RankedDistricts
WHERE ValueRank <= 10
ORDER BY ValueRank, StateName, DistrictName;

-- Q8: Which districts had the highest transaction count
-- in the latest month?

WITH LatestMonth AS
(
    SELECT MAX(MonthStart) AS MonthStart
    FROM dbo.DimMonth
),
DistrictTotals AS
(
    SELECT
        m.MonthStart,
        d.StateName,
        d.DistrictName,
        SUM(f.TransactionCount) AS DistrictTransactionCount
    FROM dbo.FactUPIDistrictMonthly AS f
    JOIN dbo.DimMonth AS m
        ON m.MonthKey = f.MonthKey
    JOIN dbo.DimDistrict AS d
        ON d.DistrictKey = f.DistrictKey
    JOIN LatestMonth AS lm
        ON lm.MonthStart = m.MonthStart
    GROUP BY
        m.MonthStart,
        d.StateName,
        d.DistrictName
),
RankedDistricts AS
(
    SELECT
        MonthStart,
        StateName,
        DistrictName,
        DistrictTransactionCount,
        100.0 * DistrictTransactionCount
            / NULLIF(SUM(DistrictTransactionCount) OVER (), 0) AS CountSharePct,
        RANK() OVER (ORDER BY DistrictTransactionCount DESC) AS CountRank
    FROM DistrictTotals
)
SELECT
    MonthStart,
    StateName,
    DistrictName,
    DistrictTransactionCount,
    CountSharePct,
    CountRank
FROM RankedDistricts
WHERE CountRank <= 10
ORDER BY CountRank, StateName, DistrictName;


-- Q9: Which districts had the largest absolute
-- month-over-month decrease in transaction value?

WITH DistrictMonthlyTotals AS
(
    SELECT
        m.MonthStart,
        d.StateName,
        d.DistrictName,
        SUM(f.TransactionValue) AS TransactionValue
    FROM dbo.FactUPIDistrictMonthly AS f
    JOIN dbo.DimMonth AS m
        ON m.MonthKey = f.MonthKey
    JOIN dbo.DimDistrict AS d
        ON d.DistrictKey = f.DistrictKey
    GROUP BY
        m.MonthStart,
        d.StateName,
        d.DistrictName
),
DistrictHistory AS
(
    SELECT
        MonthStart,
        StateName,
        DistrictName,
        TransactionValue,
        LAG(MonthStart) OVER
            (PARTITION BY StateName, DistrictName ORDER BY MonthStart)
            AS PreviousMonth,
        LAG(TransactionValue) OVER
            (PARTITION BY StateName, DistrictName ORDER BY MonthStart)
            AS PreviousValue
    FROM DistrictMonthlyTotals
),
ValueDrops AS
(
    SELECT
        MonthStart AS DeclineMonth,
        StateName,
        DistrictName,
        PreviousValue,
        TransactionValue,
        TransactionValue - PreviousValue AS ValueChange,
        100.0 * (TransactionValue - PreviousValue)
            / NULLIF(PreviousValue, 0) AS ValueChangePct
    FROM DistrictHistory
    WHERE PreviousMonth = DATEADD(MONTH, -1, MonthStart)
      AND TransactionValue IS NOT NULL
      AND PreviousValue IS NOT NULL
      AND TransactionValue < PreviousValue
),
RankedDrops AS
(
    SELECT
        *,
        ROW_NUMBER() OVER (ORDER BY ValueChange ASC) AS DropRank
    FROM ValueDrops
)
SELECT
    DeclineMonth,
    StateName,
    DistrictName,
    PreviousValue,
    TransactionValue,
    ValueChange,
    ValueChangePct,
    DropRank
FROM RankedDrops
WHERE DropRank <= 10
ORDER BY DropRank;

-- Q10: Which districts had the largest percentage
-- month-over-month decrease in transaction count?

WITH DistrictMonthlyTotals AS
(
    SELECT
        m.MonthStart,
        d.StateName,
        d.DistrictName,
        SUM(f.TransactionCount) AS TransactionCount
    FROM dbo.FactUPIDistrictMonthly AS f
    JOIN dbo.DimMonth AS m
        ON m.MonthKey = f.MonthKey
    JOIN dbo.DimDistrict AS d
        ON d.DistrictKey = f.DistrictKey
    GROUP BY
        m.MonthStart,
        d.StateName,
        d.DistrictName
),
DistrictHistory AS
(
    SELECT
        MonthStart,
        StateName,
        DistrictName,
        TransactionCount,
        LAG(MonthStart) OVER
            (PARTITION BY StateName, DistrictName ORDER BY MonthStart)
            AS PreviousMonth,
        LAG(TransactionCount) OVER
            (PARTITION BY StateName, DistrictName ORDER BY MonthStart)
            AS PreviousCount
    FROM DistrictMonthlyTotals
),
CountDrops AS
(
    SELECT
        MonthStart AS DeclineMonth,
        StateName,
        DistrictName,
        PreviousCount,
        TransactionCount,
        TransactionCount - PreviousCount AS CountChange,
        100.0 * (TransactionCount - PreviousCount)
            / NULLIF(PreviousCount, 0) AS CountChangePct
    FROM DistrictHistory
    WHERE PreviousMonth = DATEADD(MONTH, -1, MonthStart)
      AND TransactionCount IS NOT NULL
      AND PreviousCount IS NOT NULL
      AND TransactionCount < PreviousCount
),
RankedDrops AS
(
    SELECT
        *,
        ROW_NUMBER() OVER (ORDER BY CountChangePct ASC) AS DropRank
    FROM CountDrops
)
SELECT
    DeclineMonth,
    StateName,
    DistrictName,
    PreviousCount,
    TransactionCount,
    CountChange,
    CountChangePct,
    DropRank
FROM RankedDrops
WHERE DropRank <= 10
ORDER BY DropRank;


-- Q11: Which districts grew in both transaction value and count
-- for at least three consecutive month-over-month periods?

WITH DistrictMonthlyTotals AS
(
    SELECT
        m.MonthStart,
        d.StateName,
        d.DistrictName,
        SUM(f.TransactionValue) AS TransactionValue,
        SUM(f.TransactionCount) AS TransactionCount
    FROM dbo.FactUPIDistrictMonthly AS f
    JOIN dbo.DimMonth AS m
        ON m.MonthKey = f.MonthKey
    JOIN dbo.DimDistrict AS d
        ON d.DistrictKey = f.DistrictKey
    GROUP BY
        m.MonthStart,
        d.StateName,
        d.DistrictName
),
MonthlyHistory AS
(
    SELECT
        MonthStart,
        StateName,
        DistrictName,
        TransactionValue,
        TransactionCount,
        LAG(MonthStart, 1) OVER
            (PARTITION BY StateName, DistrictName ORDER BY MonthStart) AS Month1Back,
        LAG(MonthStart, 2) OVER
            (PARTITION BY StateName, DistrictName ORDER BY MonthStart) AS Month2Back,
        LAG(MonthStart, 3) OVER
            (PARTITION BY StateName, DistrictName ORDER BY MonthStart) AS Month3Back,
        LAG(TransactionValue, 1) OVER
            (PARTITION BY StateName, DistrictName ORDER BY MonthStart) AS Value1Back,
        LAG(TransactionValue, 2) OVER
            (PARTITION BY StateName, DistrictName ORDER BY MonthStart) AS Value2Back,
        LAG(TransactionValue, 3) OVER
            (PARTITION BY StateName, DistrictName ORDER BY MonthStart) AS Value3Back,
        LAG(TransactionCount, 1) OVER
            (PARTITION BY StateName, DistrictName ORDER BY MonthStart) AS Count1Back,
        LAG(TransactionCount, 2) OVER
            (PARTITION BY StateName, DistrictName ORDER BY MonthStart) AS Count2Back,
        LAG(TransactionCount, 3) OVER
            (PARTITION BY StateName, DistrictName ORDER BY MonthStart) AS Count3Back
    FROM DistrictMonthlyTotals
)
SELECT
    StateName,
    DistrictName,
    DATEADD(MONTH, -3, MonthStart) AS GrowthPeriodStart,
    MonthStart AS GrowthPeriodEnd,
    Value3Back AS StartingTransactionValue,
    TransactionValue AS EndingTransactionValue,
    Count3Back AS StartingTransactionCount,
    TransactionCount AS EndingTransactionCount
FROM MonthlyHistory
WHERE Month1Back = DATEADD(MONTH, -1, MonthStart)
  AND Month2Back = DATEADD(MONTH, -2, MonthStart)
  AND Month3Back = DATEADD(MONTH, -3, MonthStart)
  AND TransactionValue > Value1Back
  AND Value1Back > Value2Back
  AND Value2Back > Value3Back
  AND TransactionCount > Count1Back
  AND Count1Back > Count2Back
  AND Count2Back > Count3Back
  AND TransactionValue IS NOT NULL
  AND Value1Back IS NOT NULL
  AND Value2Back IS NOT NULL
  AND Value3Back IS NOT NULL
  AND TransactionCount IS NOT NULL
  AND Count1Back IS NOT NULL
  AND Count2Back IS NOT NULL
  AND Count3Back IS NOT NULL
ORDER BY StateName, DistrictName, GrowthPeriodEnd;

-- Q12: Where did transaction value and count move
-- in opposite directions month over month?

WITH DistrictMonthlyTotals AS
(
    SELECT
        m.MonthStart,
        d.StateName,
        d.DistrictName,
        SUM(f.TransactionValue) AS TransactionValue,
        SUM(f.TransactionCount) AS TransactionCount
    FROM dbo.FactUPIDistrictMonthly AS f
    JOIN dbo.DimMonth AS m
        ON m.MonthKey = f.MonthKey
    JOIN dbo.DimDistrict AS d
        ON d.DistrictKey = f.DistrictKey
    GROUP BY
        m.MonthStart,
        d.StateName,
        d.DistrictName
),
DistrictHistory AS
(
    SELECT
        MonthStart,
        StateName,
        DistrictName,
        TransactionValue,
        TransactionCount,
        LAG(MonthStart) OVER
            (PARTITION BY StateName, DistrictName ORDER BY MonthStart)
            AS PreviousMonth,
        LAG(TransactionValue) OVER
            (PARTITION BY StateName, DistrictName ORDER BY MonthStart)
            AS PreviousValue,
        LAG(TransactionCount) OVER
            (PARTITION BY StateName, DistrictName ORDER BY MonthStart)
            AS PreviousCount
    FROM DistrictMonthlyTotals
)
SELECT
    MonthStart,
    StateName,
    DistrictName,
    PreviousValue,
    TransactionValue,
    TransactionValue - PreviousValue AS ValueChange,
    PreviousCount,
    TransactionCount,
    TransactionCount - PreviousCount AS CountChange,
    CASE
        WHEN TransactionValue > PreviousValue
         AND TransactionCount < PreviousCount
            THEN N'Value up, count down'
        WHEN TransactionValue < PreviousValue
         AND TransactionCount > PreviousCount
            THEN N'Value down, count up'
    END AS MovementPattern
FROM DistrictHistory
WHERE PreviousMonth = DATEADD(MONTH, -1, MonthStart)
  AND PreviousValue IS NOT NULL
  AND PreviousCount IS NOT NULL
  AND TransactionValue IS NOT NULL
  AND TransactionCount IS NOT NULL
  AND
  (
      (TransactionValue > PreviousValue AND TransactionCount < PreviousCount)
      OR
      (TransactionValue < PreviousValue AND TransactionCount > PreviousCount)
  )
ORDER BY MonthStart, StateName, DistrictName;

-- Q13: How did average value per reported transaction
-- vary by month and district?

WITH DistrictMonthMatched AS
(
    SELECT
        m.MonthStart,
        d.StateName,
        d.DistrictName,
        SUM(f.TransactionValue) AS TransactionValue,
        SUM(f.TransactionCount) AS TransactionCount
    FROM dbo.FactUPIDistrictMonthly AS f
    JOIN dbo.DimMonth AS m
        ON m.MonthKey = f.MonthKey
    JOIN dbo.DimDistrict AS d
        ON d.DistrictKey = f.DistrictKey
    WHERE f.TransactionValue IS NOT NULL
      AND f.TransactionCount IS NOT NULL
    GROUP BY
        m.MonthStart,
        d.StateName,
        d.DistrictName
),
MonthlyMatchedTotals AS
(
    SELECT
        MonthStart,
        SUM(TransactionValue) AS MonthlyTransactionValue,
        SUM(TransactionCount) AS MonthlyTransactionCount
    FROM DistrictMonthMatched
    GROUP BY MonthStart
),
RankedDistricts AS
(
    SELECT
        dm.MonthStart,
        dm.StateName,
        dm.DistrictName,
        dm.TransactionValue,
        dm.TransactionCount,
        1.0 * dm.TransactionValue / NULLIF(dm.TransactionCount, 0)
            AS DistrictAverageValuePerTransaction,
        1.0 * mt.MonthlyTransactionValue
            / NULLIF(mt.MonthlyTransactionCount, 0)
            AS MonthlyAverageValuePerTransaction,
        RANK() OVER
        (
            PARTITION BY dm.MonthStart
            ORDER BY 1.0 * dm.TransactionValue
                / NULLIF(dm.TransactionCount, 0) DESC
        ) AS DistrictRank
    FROM DistrictMonthMatched AS dm
    JOIN MonthlyMatchedTotals AS mt
        ON mt.MonthStart = dm.MonthStart
)
SELECT
    MonthStart,
    StateName,
    DistrictName,
    TransactionValue,
    TransactionCount,
    DistrictAverageValuePerTransaction,
    MonthlyAverageValuePerTransaction,
    DistrictRank
FROM RankedDistricts
WHERE DistrictRank <= 10
ORDER BY MonthStart, DistrictRank;

-- Q14: What share of reported value and count came from
-- the top 10 districts each month?

WITH DistrictMonthTotals AS
(
    SELECT
        m.MonthStart,
        d.StateName,
        d.DistrictName,
        SUM(f.TransactionValue) AS TransactionValue,
        SUM(f.TransactionCount) AS TransactionCount
    FROM dbo.FactUPIDistrictMonthly AS f
    JOIN dbo.DimMonth AS m
        ON m.MonthKey = f.MonthKey
    JOIN dbo.DimDistrict AS d
        ON d.DistrictKey = f.DistrictKey
    GROUP BY
        m.MonthStart,
        d.StateName,
        d.DistrictName
),
RankedDistricts AS
(
    SELECT
        MonthStart,
        StateName,
        DistrictName,
        TransactionValue,
        TransactionCount,
        ROW_NUMBER() OVER
        (
            PARTITION BY MonthStart
            ORDER BY TransactionValue DESC, StateName, DistrictName
        ) AS ValueRank,
        ROW_NUMBER() OVER
        (
            PARTITION BY MonthStart
            ORDER BY TransactionCount DESC, StateName, DistrictName
        ) AS CountRank
    FROM DistrictMonthTotals
),
MonthlyConcentration AS
(
    SELECT
        MonthStart,
        SUM(TransactionValue) AS TotalTransactionValue,
        SUM(TransactionCount) AS TotalTransactionCount,
        SUM(CASE WHEN ValueRank <= 10 THEN TransactionValue ELSE 0 END)
            AS Top10TransactionValue,
        SUM(CASE WHEN CountRank <= 10 THEN TransactionCount ELSE 0 END)
            AS Top10TransactionCount
    FROM RankedDistricts
    GROUP BY MonthStart
)
SELECT
    MonthStart,
    TotalTransactionValue,
    Top10TransactionValue,
    100.0 * Top10TransactionValue
        / NULLIF(TotalTransactionValue, 0) AS Top10ValueSharePct,
    TotalTransactionCount,
    Top10TransactionCount,
    100.0 * Top10TransactionCount
        / NULLIF(TotalTransactionCount, 0) AS Top10CountSharePct
FROM MonthlyConcentration
ORDER BY MonthStart;


-- Q15: Which districts should be shortlisted for further market research?
-- Scoring assumption: 40% activity, 40% recent growth, 20% stability.
-- Higher activity and growth score better; lower volatility scores better.
-- This is a screening rule, not a prediction of demand.

WITH DistrictMonths AS
(
    SELECT
        m.MonthStart,
        d.StateName,
        d.DistrictName,
        SUM(f.TransactionValue) AS TransactionValue,
        SUM(f.TransactionCount) AS TransactionCount
    FROM dbo.FactUPIDistrictMonthly AS f
    JOIN dbo.DimMonth AS m
        ON m.MonthKey = f.MonthKey
    JOIN dbo.DimDistrict AS d
        ON d.DistrictKey = f.DistrictKey
    GROUP BY
        m.MonthStart,
        d.StateName,
        d.DistrictName
),
DistrictHistory AS
(
    SELECT
        MonthStart,
        StateName,
        DistrictName,
        TransactionValue,
        TransactionCount,
        LAG(MonthStart) OVER
            (PARTITION BY StateName, DistrictName ORDER BY MonthStart) AS PreviousMonth,
        LAG(TransactionValue) OVER
            (PARTITION BY StateName, DistrictName ORDER BY MonthStart) AS PreviousValue,
        LAG(TransactionCount) OVER
            (PARTITION BY StateName, DistrictName ORDER BY MonthStart) AS PreviousCount
    FROM DistrictMonths
),
MonthlyChanges AS
(
    SELECT
        MonthStart,
        StateName,
        DistrictName,
        TransactionValue,
        TransactionCount,
        CASE
            WHEN PreviousMonth = DATEADD(MONTH, -1, MonthStart)
             AND TransactionValue IS NOT NULL
             AND PreviousValue IS NOT NULL
             AND PreviousValue <> 0
            THEN 100.0 * (TransactionValue - PreviousValue) / PreviousValue
        END AS ValueChangePct,
        CASE
            WHEN PreviousMonth = DATEADD(MONTH, -1, MonthStart)
             AND TransactionCount IS NOT NULL
             AND PreviousCount IS NOT NULL
             AND PreviousCount <> 0
            THEN 100.0 * (TransactionCount - PreviousCount) / PreviousCount
        END AS CountChangePct
    FROM DistrictHistory
),
ReferenceMonths AS
(
    SELECT MAX(MonthStart) AS LatestMonth
    FROM DistrictMonths
),
DistrictMetrics AS
(
    SELECT
        mc.StateName,
        mc.DistrictName,
        COUNT(DISTINCT mc.MonthStart) AS ObservedMonths,
        MAX(CASE WHEN mc.MonthStart = DATEADD(MONTH, -3, rm.LatestMonth)
                 THEN mc.TransactionValue END) AS StartValue,
        MAX(CASE WHEN mc.MonthStart = DATEADD(MONTH, -3, rm.LatestMonth)
                 THEN mc.TransactionCount END) AS StartCount,
        MAX(CASE WHEN mc.MonthStart = rm.LatestMonth
                 THEN mc.TransactionValue END) AS LatestValue,
        MAX(CASE WHEN mc.MonthStart = rm.LatestMonth
                 THEN mc.TransactionCount END) AS LatestCount,
        COUNT(mc.ValueChangePct) AS ValidValueChangeMonths,
        COUNT(mc.CountChangePct) AS ValidCountChangeMonths,
        STDEV(mc.ValueChangePct) AS ValueVolatilityPct,
        STDEV(mc.CountChangePct) AS CountVolatilityPct
    FROM MonthlyChanges AS mc
    CROSS JOIN ReferenceMonths AS rm
    GROUP BY mc.StateName, mc.DistrictName
),
EligibleDistricts AS
(
    SELECT
        *,
        100.0 * (LatestValue - StartValue) / NULLIF(StartValue, 0)
            AS ValueGrowthPct,
        100.0 * (LatestCount - StartCount) / NULLIF(StartCount, 0)
            AS CountGrowthPct
    FROM DistrictMetrics
    WHERE ObservedMonths =
          (SELECT COUNT(DISTINCT MonthStart) FROM DistrictMonths)
      AND ValidValueChangeMonths =
          (SELECT COUNT(DISTINCT MonthStart) - 1 FROM DistrictMonths)
      AND ValidCountChangeMonths =
          (SELECT COUNT(DISTINCT MonthStart) - 1 FROM DistrictMonths)
      AND StartValue IS NOT NULL
      AND StartCount IS NOT NULL
      AND LatestValue IS NOT NULL
      AND LatestCount IS NOT NULL
),
ComponentScores AS
(
    SELECT
        *,
        (
            1.0 - PERCENT_RANK() OVER (ORDER BY LatestValue DESC)
            + 1.0 - PERCENT_RANK() OVER (ORDER BY LatestCount DESC)
        ) / 2.0 AS ActivityScore,
        (
            1.0 - PERCENT_RANK() OVER (ORDER BY ValueGrowthPct DESC)
            + 1.0 - PERCENT_RANK() OVER (ORDER BY CountGrowthPct DESC)
        ) / 2.0 AS GrowthScore,
        (
            1.0 - PERCENT_RANK() OVER (ORDER BY ValueVolatilityPct ASC)
            + 1.0 - PERCENT_RANK() OVER (ORDER BY CountVolatilityPct ASC)
        ) / 2.0 AS StabilityScore
    FROM EligibleDistricts
),
FinalScores AS
(
    SELECT
        *,
        100.0 * (0.40 * ActivityScore
              + 0.40 * GrowthScore
              + 0.20 * StabilityScore) AS ShortlistScore
    FROM ComponentScores
)
SELECT TOP (20)
    StateName,
    DistrictName,
    LatestValue,
    LatestCount,
    ValueGrowthPct,
    CountGrowthPct,
    ValueVolatilityPct,
    CountVolatilityPct,
    ActivityScore * 100.0 AS ActivityScorePct,
    GrowthScore * 100.0 AS GrowthScorePct,
    StabilityScore * 100.0 AS StabilityScorePct,
    ShortlistScore
FROM FinalScores
ORDER BY ShortlistScore DESC, LatestValue DESC, StateName, DistrictName;

