IF OBJECT_ID(N'dbo.StgUPIDistrictMonthly', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.StgUPIDistrictMonthly
    (
        ReportMonthRaw              nvarchar(20)  NULL,
        StateName                   nvarchar(100) NULL,
        DistrictName                nvarchar(150) NULL,
        TransactionValueRaw         nvarchar(50)  NULL,
        TransactionCountRaw         nvarchar(50)  NULL,
        TransactionValueSharePctRaw nvarchar(50)  NULL,
        TransactionCountSharePctRaw nvarchar(50)  NULL
    );
END;

SELECT
    OBJECT_ID(N'dbo.StgUPIDistrictMonthly', N'U') AS StagingTableObjectID;

SELECT
    c.column_id,
    c.name AS ColumnName,
    TYPE_NAME(c.user_type_id) AS DataType,
    c.is_nullable AS AllowsNulls
FROM sys.columns AS c
WHERE c.object_id = OBJECT_ID(N'dbo.StgUPIDistrictMonthly')
ORDER BY c.column_id;

IF OBJECT_ID(N'dbo.DimDistrict', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimDistrict
    (
        DistrictKey int IDENTITY(1,1) NOT NULL,
        StateName nvarchar(100) NOT NULL,
        DistrictName nvarchar(150) NOT NULL,

        CONSTRAINT PK_DimDistrict
            PRIMARY KEY (DistrictKey),

        CONSTRAINT UQ_DimDistrict_State_District
            UNIQUE (StateName, DistrictName)
    );
END;

SELECT
    OBJECT_ID(N'dbo.DimDistrict', N'U') AS DistrictTableObjectID;

IF OBJECT_ID(N'dbo.DimMonth', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.DimMonth
    (
        MonthKey int NOT NULL,
        MonthStart date NOT NULL,
        CalendarYear smallint NOT NULL,
        MonthNumber tinyint NOT NULL,
        MonthName nvarchar(20) NOT NULL,
        QuarterNumber tinyint NOT NULL,

        CONSTRAINT PK_DimMonth
            PRIMARY KEY (MonthKey),

        CONSTRAINT UQ_DimMonth_MonthStart
            UNIQUE (MonthStart),

        CONSTRAINT CK_DimMonth_MonthNumber
            CHECK (MonthNumber BETWEEN 1 AND 12),

        CONSTRAINT CK_DimMonth_QuarterNumber
            CHECK (QuarterNumber BETWEEN 1 AND 4)
    );
END;

SELECT
    OBJECT_ID(N'dbo.DimMonth', N'U') AS MonthTableObjectID;

IF OBJECT_ID(N'dbo.FactUPIDistrictMonthly', N'U') IS NULL
BEGIN
    CREATE TABLE dbo.FactUPIDistrictMonthly
    (
        MonthKey int NOT NULL,
        DistrictKey int NOT NULL,
        TransactionValue decimal(20, 2) NULL,
        TransactionCount bigint NULL,
        TransactionValueSharePct decimal(9, 4) NULL,
        TransactionCountSharePct decimal(9, 4) NULL,

        CONSTRAINT PK_FactUPIDistrictMonthly
            PRIMARY KEY (MonthKey, DistrictKey),

        CONSTRAINT FK_FactUPIDistrictMonthly_DimMonth
            FOREIGN KEY (MonthKey)
            REFERENCES dbo.DimMonth (MonthKey),

        CONSTRAINT FK_FactUPIDistrictMonthly_DimDistrict
            FOREIGN KEY (DistrictKey)
            REFERENCES dbo.DimDistrict (DistrictKey)
    );
END;

SELECT
    OBJECT_ID(N'dbo.FactUPIDistrictMonthly', N'U') AS FactTableObjectID;

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

