-- SINH TU DONG: python tools/tao_script_buoc6_ssms.py
-- Mo file nay trong SSMS va Execute toan bo; khong can SQLCMD mode.
-- Database dich: hanoi_air_dw; khong sua/xoa nguon hanoi_air_vn.
-- Chinh cac file 01-05 / checks truoc, sau do sinh lai file nay.

-- Buoc 6: tao kho rieng; khong thay doi database nguon hanoi_air_vn.
-- Chay 01 -> 05. Ket noi bang Windows Authentication / cau hinh cuc bo.
USE [master];
GO
IF DB_ID(N'hanoi_air_dw') IS NULL
    EXEC(N'CREATE DATABASE [hanoi_air_dw]');
GO
USE [hanoi_air_dw];
GO
IF DB_NAME() <> N'hanoi_air_dw'
    THROW 51000, 'Sai database dich; dung trien khai.', 1;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF SCHEMA_ID(N'stg') IS NULL EXEC(N'CREATE SCHEMA stg AUTHORIZATION dbo;');
    IF SCHEMA_ID(N'etl') IS NULL EXEC(N'CREATE SCHEMA etl AUTHORIZATION dbo;');
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
PRINT N'01: hanoi_air_dw, stg, etl san sang.';
GO

-- Staging giu du lieu go kieu, cho phep dong loi/trung de ETL phan loai.
-- Timestamp staging (7) giu ca phan giay de ETL phat hien truoc khi nap fact (0).
USE [hanoi_air_dw];
GO
IF DB_NAME() <> N'hanoi_air_dw'
    THROW 51000, 'Sai database dich; dung trien khai.', 1;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF OBJECT_ID(N'etl.BatchLog', N'U') IS NULL
    BEGIN
        CREATE TABLE etl.BatchLog (
            BatchId uniqueidentifier NOT NULL CONSTRAINT PK_BatchLog PRIMARY KEY,
            StartedAtUTC datetime2(7) NOT NULL CONSTRAINT DF_BatchLog_Started DEFAULT SYSUTCDATETIME(),
            FinishedAtUTC datetime2(7) NULL,
            Status nvarchar(12) NOT NULL CONSTRAINT DF_BatchLog_Status DEFAULT N'Running',
            SourceName nvarchar(160) NOT NULL,
            SourceSHA256 varchar(64) NULL,
            ExtractedRows bigint NOT NULL CONSTRAINT DF_BatchLog_Extracted DEFAULT 0,
            InsertedRows bigint NOT NULL CONSTRAINT DF_BatchLog_Inserted DEFAULT 0,
            ExistingRows bigint NOT NULL CONSTRAINT DF_BatchLog_Existing DEFAULT 0,
            RejectedRows bigint NOT NULL CONSTRAINT DF_BatchLog_Rejected DEFAULT 0,
            DuplicateRows bigint NOT NULL CONSTRAINT DF_BatchLog_Duplicate DEFAULT 0,
            ExcludedRows bigint NOT NULL CONSTRAINT DF_BatchLog_Excluded DEFAULT 0,
            ConflictRows bigint NOT NULL CONSTRAINT DF_BatchLog_Conflict DEFAULT 0,
            MetadataUpdatesJSON nvarchar(max) NULL,
            ErrorMessage nvarchar(2048) NULL,
            CONSTRAINT CK_BatchLog_Status CHECK (Status IN (N'Running', N'Success', N'Failed')),
            CONSTRAINT CK_BatchLog_Time CHECK (
                (Status = N'Running' AND FinishedAtUTC IS NULL)
                OR (Status IN (N'Success', N'Failed') AND FinishedAtUTC IS NOT NULL AND FinishedAtUTC >= StartedAtUTC)),
            CONSTRAINT CK_BatchLog_Counts CHECK (
                ExtractedRows >= 0 AND InsertedRows >= 0 AND ExistingRows >= 0
                AND RejectedRows >= 0 AND DuplicateRows >= 0 AND ExcludedRows >= 0 AND ConflictRows >= 0),
            CONSTRAINT CK_BatchLog_SuccessBalance CHECK (
                Status <> N'Success' OR (ConflictRows = 0
                AND ExtractedRows = InsertedRows + ExistingRows + RejectedRows + DuplicateRows + ExcludedRows)),
            CONSTRAINT CK_BatchLog_SourceName CHECK (LEN(LTRIM(RTRIM(SourceName))) > 0),
            CONSTRAINT CK_BatchLog_SHA256 CHECK (SourceSHA256 IS NULL OR
                (LEN(SourceSHA256) = 64 AND SourceSHA256 COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^0-9a-fA-F]%')),
            CONSTRAINT CK_BatchLog_MetadataJSON CHECK (MetadataUpdatesJSON IS NULL OR ISJSON(MetadataUpdatesJSON) = 1)
        );
    END;
    IF OBJECT_ID(N'stg.AirQuality', N'U') IS NULL
    BEGIN
        CREATE TABLE stg.AirQuality (
            StageRowId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_StageAirQuality PRIMARY KEY,
            BatchId uniqueidentifier NOT NULL,
            SourceId bigint NOT NULL,
            StationId int NULL,
            SensorId int NULL,
            StationName nvarchar(160) NULL,
            ObservedAtSource datetimeoffset(7) NULL,
            Latitude decimal(10,6) NULL,
            Longitude decimal(10,6) NULL,
            PollutantCode nvarchar(20) NULL,
            Unit nvarchar(40) NULL,
            Value float(53) NULL,
            ExtractedAtUTC datetime2(7) NOT NULL CONSTRAINT DF_StageAirQuality_Extracted DEFAULT SYSUTCDATETIME(),
            CONSTRAINT FK_StageAirQuality_Batch FOREIGN KEY (BatchId) REFERENCES etl.BatchLog(BatchId)
        );
        CREATE INDEX IX_StageAirQuality_BatchSource ON stg.AirQuality(BatchId, SourceId);
    END;
    IF OBJECT_ID(N'etl.RejectRow', N'U') IS NULL
    BEGIN
        CREATE TABLE etl.RejectRow (
            RejectId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_RejectRow PRIMARY KEY,
            BatchId uniqueidentifier NOT NULL,
            SourceId bigint NULL,
            StageRowId bigint NULL,
            ReasonCode nvarchar(50) NOT NULL,
            ReasonDetail nvarchar(1000) NOT NULL,
            RawPayload nvarchar(max) NULL,
            RejectedAtUTC datetime2(7) NOT NULL CONSTRAINT DF_RejectRow_Rejected DEFAULT SYSUTCDATETIME(),
            CONSTRAINT FK_RejectRow_Batch FOREIGN KEY (BatchId) REFERENCES etl.BatchLog(BatchId),
            CONSTRAINT CK_RejectRow_Reason CHECK (LEN(LTRIM(RTRIM(ReasonCode))) > 0 AND LEN(LTRIM(RTRIM(ReasonDetail))) > 0),
            CONSTRAINT CK_RejectRow_SourceId CHECK (SourceId IS NULL OR SourceId > 0),
            CONSTRAINT CK_RejectRow_StageRowId CHECK (StageRowId IS NULL OR StageRowId > 0),
            CONSTRAINT CK_RejectRow_PayloadJSON CHECK (RawPayload IS NULL OR ISJSON(RawPayload) = 1)
        );
        CREATE INDEX IX_RejectRow_BatchSource ON etl.RejectRow(BatchId, SourceId) INCLUDE (ReasonCode);
    END;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
PRINT N'02: staging va log/reject san sang; chua trich xuat hay nap phep do.';
GO

-- Nam dimension, dung 27 cot theo tu dien Star buoc 5.
USE [hanoi_air_dw];
GO
IF DB_NAME() <> N'hanoi_air_dw'
    THROW 51000, 'Sai database dich; dung trien khai.', 1;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF OBJECT_ID(N'dbo.DimDate', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.DimDate (
            DateKey int NOT NULL CONSTRAINT PK_DimDate PRIMARY KEY,
            FullDate date NOT NULL CONSTRAINT UQ_DimDate_FullDate UNIQUE,
            DayOfMonth tinyint NOT NULL,
            MonthNumber tinyint NOT NULL,
            QuarterNumber tinyint NOT NULL,
            YearNumber smallint NOT NULL,
            DayOfWeekISO tinyint NOT NULL,
            DayName nvarchar(12) NOT NULL,
            CONSTRAINT CK_DimDate_Scope CHECK (FullDate >= CONVERT(date,'20240101',112) AND FullDate < CONVERT(date,'20250101',112)),
            CONSTRAINT CK_DimDate_Calendar CHECK (
                DateKey = CONVERT(int,CONVERT(char(8),FullDate,112))
                AND DayOfMonth = DAY(FullDate) AND MonthNumber = MONTH(FullDate)
                AND QuarterNumber = DATEPART(quarter,FullDate) AND YearNumber = YEAR(FullDate)
                AND DayOfWeekISO = DATEDIFF(day,CONVERT(date,'19000101',112),FullDate) % 7 + 1
                AND DayName = CASE DayOfWeekISO WHEN 1 THEN N'Thứ Hai' WHEN 2 THEN N'Thứ Ba'
                    WHEN 3 THEN N'Thứ Tư' WHEN 4 THEN N'Thứ Năm' WHEN 5 THEN N'Thứ Sáu'
                    WHEN 6 THEN N'Thứ Bảy' WHEN 7 THEN N'Chủ Nhật' END)
        );
    END;
    IF OBJECT_ID(N'dbo.DimTime', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.DimTime (
            TimeKey int NOT NULL CONSTRAINT PK_DimTime PRIMARY KEY,
            FullTime time(0) NOT NULL CONSTRAINT UQ_DimTime_FullTime UNIQUE,
            HourNumber tinyint NOT NULL,
            MinuteNumber tinyint NOT NULL,
            SecondNumber tinyint NOT NULL,
            CONSTRAINT CK_DimTime_Clock CHECK (
                HourNumber = DATEPART(hour,FullTime) AND MinuteNumber = DATEPART(minute,FullTime)
                AND SecondNumber = DATEPART(second,FullTime)
                AND TimeKey = HourNumber * 10000 + MinuteNumber * 100 + SecondNumber),
            CONSTRAINT CK_DimTime_Hourly CHECK (MinuteNumber = 0 AND SecondNumber = 0)
        );
    END;
    IF OBJECT_ID(N'dbo.DimStation', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.DimStation (
            StationKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimStation PRIMARY KEY,
            StationId int NOT NULL CONSTRAINT UQ_DimStation_StationId UNIQUE,
            StationName nvarchar(160) NOT NULL,
            Latitude decimal(10,6) NULL,
            Longitude decimal(10,6) NULL,
            CityName nvarchar(80) NOT NULL,
            DistrictName nvarchar(80) NULL,
            CONSTRAINT CK_DimStation_Scope CHECK (StationId IN (2161299,2161301) AND CityName = N'Hà Nội'),
            CONSTRAINT CK_DimStation_Name CHECK (LEN(LTRIM(RTRIM(StationName))) > 0),
            CONSTRAINT CK_DimStation_Coordinates CHECK (Latitude BETWEEN -90 AND 90 AND Longitude BETWEEN -180 AND 180),
            CONSTRAINT CK_DimStation_District CHECK (DistrictName IS NULL OR LEN(LTRIM(RTRIM(DistrictName))) > 0)
        );
    END;
    IF OBJECT_ID(N'dbo.DimPollutant', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.DimPollutant (
            PollutantKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimPollutant PRIMARY KEY,
            PollutantCode nvarchar(20) NOT NULL CONSTRAINT UQ_DimPollutant_Code UNIQUE,
            PollutantName nvarchar(40) NOT NULL,
            Unit nvarchar(40) NOT NULL,
            CONSTRAINT CK_DimPollutant_Domain CHECK (
                PollutantCode COLLATE Latin1_General_100_BIN2 IN (N'pm25',N'pm10')
                AND PollutantName = CASE PollutantCode WHEN N'pm25' THEN N'PM2.5' WHEN N'pm10' THEN N'PM10' END
                AND Unit COLLATE Latin1_General_100_BIN2 = N'µg/m³')
        );
    END;
    IF OBJECT_ID(N'dbo.DimSensor', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.DimSensor (
            SensorKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimSensor PRIMARY KEY,
            SensorId int NOT NULL CONSTRAINT UQ_DimSensor_SensorId UNIQUE,
            SensorDescription nvarchar(255) NULL,
            CONSTRAINT CK_DimSensor_Id CHECK (SensorId > 0)
        );
    END;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
PRINT N'03: nam dimension san sang; chua nap metadata tram/chat/cam bien.';
GO

-- Fact dung 13 cot theo tu dien; UNIQUE theo grain, khong theo BatchId/Value.
USE [hanoi_air_dw];
GO
IF DB_NAME() <> N'hanoi_air_dw'
    THROW 51000, 'Sai database dich; dung trien khai.', 1;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF OBJECT_ID(N'dbo.FactAirQuality', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.FactAirQuality (
            AirQualityKey bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactAirQuality PRIMARY KEY,
            DateKey int NOT NULL,
            TimeKey int NOT NULL,
            StationKey int NOT NULL,
            PollutantKey int NOT NULL,
            SensorKey int NOT NULL,
            ObservedAtSource datetimeoffset(0) NOT NULL,
            ObservedAtUTC datetime2(0) NOT NULL,
            ObservedAtLocal datetimeoffset(0) NOT NULL,
            Value float(53) NULL,
            IsValid bit NOT NULL,
            SourceId bigint NOT NULL,
            BatchId uniqueidentifier NOT NULL,
            CONSTRAINT UQ_FactAirQuality_Grain UNIQUE (StationKey, SensorKey, ObservedAtUTC, PollutantKey),
            CONSTRAINT FK_FactAirQuality_Date FOREIGN KEY (DateKey) REFERENCES dbo.DimDate(DateKey),
            CONSTRAINT FK_FactAirQuality_Time FOREIGN KEY (TimeKey) REFERENCES dbo.DimTime(TimeKey),
            CONSTRAINT FK_FactAirQuality_Station FOREIGN KEY (StationKey) REFERENCES dbo.DimStation(StationKey),
            CONSTRAINT FK_FactAirQuality_Pollutant FOREIGN KEY (PollutantKey) REFERENCES dbo.DimPollutant(PollutantKey),
            CONSTRAINT FK_FactAirQuality_Sensor FOREIGN KEY (SensorKey) REFERENCES dbo.DimSensor(SensorKey),
            CONSTRAINT FK_FactAirQuality_Batch FOREIGN KEY (BatchId) REFERENCES etl.BatchLog(BatchId),
            CONSTRAINT CK_FactAirQuality_TimeZone CHECK (DATEPART(tzoffset,ObservedAtLocal) = 420),
            CONSTRAINT CK_FactAirQuality_Instant CHECK (
                ObservedAtUTC = CAST(SWITCHOFFSET(ObservedAtSource,'+00:00') AS datetime2(0))
                AND ObservedAtLocal = ObservedAtSource),
            CONSTRAINT CK_FactAirQuality_LocalKeys CHECK (
                DateKey = CONVERT(int,CONVERT(char(8),ObservedAtLocal,112))
                AND TimeKey = DATEPART(hour,ObservedAtLocal) * 10000
                    + DATEPART(minute,ObservedAtLocal) * 100 + DATEPART(second,ObservedAtLocal)),
            CONSTRAINT CK_FactAirQuality_Validity CHECK (
                (IsValid = 1 AND Value IS NOT NULL AND Value >= 0)
                OR (IsValid = 0 AND (Value IS NULL OR Value < 0))),
            CONSTRAINT CK_FactAirQuality_SourceId CHECK (SourceId > 0)
        );
        CREATE INDEX IX_FactAirQuality_DateStationPollutant
            ON dbo.FactAirQuality(DateKey, StationKey, PollutantKey)
            INCLUDE (TimeKey, Value, IsValid);
        CREATE INDEX IX_FactAirQuality_SourceId ON dbo.FactAirQuality(SourceId);
    END;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
PRINT N'04: fact va rang buoc san sang; chua nap phep do.';
GO

-- Nap du lich ngay/gio, khong tao fact cho gio thieu; chay lai khong them trung.
-- Thu ISO tinh tu mot ngay Thu Hai co dinh, khong phu thuoc SET DATEFIRST.
USE [hanoi_air_dw];
GO
IF DB_NAME() <> N'hanoi_air_dw'
    THROW 51000, 'Sai database dich; dung trien khai.', 1;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    ;WITH days AS (
        SELECT CONVERT(date,'20240101',112) AS FullDate
        UNION ALL
        SELECT DATEADD(day,1,FullDate) FROM days WHERE FullDate < CONVERT(date,'20241231',112)
    ), calendar AS (
        SELECT FullDate, DATEDIFF(day,CONVERT(date,'19000101',112),FullDate) % 7 + 1 AS DayOfWeekISO
        FROM days
    )
    INSERT dbo.DimDate (DateKey, FullDate, DayOfMonth, MonthNumber, QuarterNumber, YearNumber, DayOfWeekISO, DayName)
    SELECT CONVERT(int,CONVERT(char(8),c.FullDate,112)), c.FullDate,
        DAY(c.FullDate), MONTH(c.FullDate), DATEPART(quarter,c.FullDate), YEAR(c.FullDate), c.DayOfWeekISO,
        CASE c.DayOfWeekISO WHEN 1 THEN N'Thứ Hai' WHEN 2 THEN N'Thứ Ba' WHEN 3 THEN N'Thứ Tư'
            WHEN 4 THEN N'Thứ Năm' WHEN 5 THEN N'Thứ Sáu' WHEN 6 THEN N'Thứ Bảy' WHEN 7 THEN N'Chủ Nhật' END
    FROM calendar c WHERE NOT EXISTS (SELECT 1 FROM dbo.DimDate d WHERE d.DateKey = CONVERT(int,CONVERT(char(8),c.FullDate,112)))
    OPTION (MAXRECURSION 366);
    ;WITH hours AS (
        SELECT 0 AS HourNumber UNION ALL SELECT HourNumber + 1 FROM hours WHERE HourNumber < 23
    )
    INSERT dbo.DimTime (TimeKey, FullTime, HourNumber, MinuteNumber, SecondNumber)
    SELECT h.HourNumber * 10000, TIMEFROMPARTS(h.HourNumber,0,0,0,0), h.HourNumber, 0, 0
    FROM hours h WHERE NOT EXISTS (SELECT 1 FROM dbo.DimTime t WHERE t.TimeKey = h.HourNumber * 10000);
    IF (SELECT COUNT(*) FROM dbo.DimDate) <> 366 OR (SELECT COUNT(*) FROM dbo.DimTime) <> 24
        THROW 51001, 'Lich chua du 366 ngay / 24 moc gio.', 1;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
SELECT N'DimDate' AS CalendarTable, COUNT_BIG(*) AS RowsLoaded, MIN(FullDate) AS FirstDate, MAX(FullDate) AS LastDate FROM dbo.DimDate;
SELECT N'DimTime' AS CalendarTable, COUNT_BIG(*) AS RowsLoaded, MIN(FullTime) AS FirstTime, MAX(FullTime) AS LastTime FROM dbo.DimTime;
GO

-- Chi doc kho va metadata; khong nap phep do. Dung cho SSMS / sqlcmd.
USE [hanoi_air_dw];
GO
SET NOCOUNT ON;
IF DB_NAME() <> N'hanoi_air_dw' THROW 51000, 'Sai database kiem tra.', 1;

DECLARE @ExpectedTables TABLE (SchemaName sysname, TableName sysname, ColumnCount int);
INSERT @ExpectedTables VALUES
    (N'dbo',N'DimDate',8), (N'dbo',N'DimTime',5), (N'dbo',N'DimStation',7),
    (N'dbo',N'DimPollutant',4), (N'dbo',N'DimSensor',3), (N'dbo',N'FactAirQuality',13),
    (N'stg',N'AirQuality',13), (N'etl',N'BatchLog',15), (N'etl',N'RejectRow',8);
IF EXISTS (
    SELECT 1 FROM @ExpectedTables e
    LEFT JOIN sys.schemas s ON s.name=e.SchemaName
    LEFT JOIN sys.tables t ON t.schema_id=s.schema_id AND t.name=e.TableName
    WHERE t.object_id IS NULL OR e.ColumnCount <> (SELECT COUNT(*) FROM sys.columns c WHERE c.object_id=t.object_id))
    THROW 51002, 'Thieu bang hoac sai so cot so voi dac ta buoc 6.', 1;
IF EXISTS (
    SELECT 1 FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
    WHERE t.is_ms_shipped=0 AND t.name NOT IN (N'sysdiagrams')
      AND NOT EXISTS (SELECT 1 FROM @ExpectedTables e WHERE e.SchemaName=s.name AND e.TableName=t.name))
    THROW 51003, 'Co bang ngoai pham vi Star/staging/log; can doi soat.', 1;
IF (SELECT COUNT(*) FROM sys.key_constraints k JOIN sys.tables t ON t.object_id=k.parent_object_id
    JOIN sys.schemas s ON s.schema_id=t.schema_id JOIN @ExpectedTables e ON e.SchemaName=s.name AND e.TableName=t.name WHERE k.type=N'PK') <> 9
    THROW 51004, 'Chua du PK cho chin bang.', 1;
IF (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id=OBJECT_ID(N'dbo.FactAirQuality')) <> 6
    THROW 51005, 'Fact can nam FK dimension va mot FK batch.', 1;
IF EXISTS (SELECT 1 FROM sys.foreign_keys WHERE is_disabled=1 OR is_not_trusted=1 OR delete_referential_action<>0 OR update_referential_action<>0)
    THROW 51006, 'FK khong duoc trusted/enabled hoac co cascade ngoai dac ta.', 1;
IF EXISTS (SELECT 1 FROM sys.check_constraints WHERE is_disabled=1 OR is_not_trusted=1)
    THROW 51007, 'CHECK khong duoc trusted/enabled.', 1;
IF (SELECT COUNT(*) FROM sys.foreign_keys WHERE parent_object_id IN (OBJECT_ID(N'dbo.DimStation'),OBJECT_ID(N'dbo.DimSensor'),OBJECT_ID(N'dbo.DimPollutant'))) <> 0
    THROW 51008, 'Dimension co duong noi phu ngoai Star.', 1;

DECLARE @GrainIndex int = (SELECT unique_index_id FROM sys.key_constraints
    WHERE parent_object_id=OBJECT_ID(N'dbo.FactAirQuality') AND name=N'UQ_FactAirQuality_Grain' AND type=N'UQ');
IF @GrainIndex IS NULL OR (SELECT COUNT(*) FROM sys.index_columns WHERE object_id=OBJECT_ID(N'dbo.FactAirQuality') AND index_id=@GrainIndex AND key_ordinal>0) <> 4
    THROW 51009, 'Thieu UNIQUE bon cot grain.', 1;
IF EXISTS (
    SELECT 1 FROM (VALUES (1,N'StationKey'),(2,N'SensorKey'),(3,N'ObservedAtUTC'),(4,N'PollutantKey')) e(Ordinal,ColumnName)
    LEFT JOIN sys.index_columns ic ON ic.object_id=OBJECT_ID(N'dbo.FactAirQuality') AND ic.index_id=@GrainIndex AND ic.key_ordinal=e.Ordinal
    LEFT JOIN sys.columns c ON c.object_id=ic.object_id AND c.column_id=ic.column_id
    WHERE c.name IS NULL OR c.name<>e.ColumnName)
    THROW 51010, 'UNIQUE sai cot/thu tu grain.', 1;
IF EXISTS (SELECT 1 FROM sys.columns WHERE object_id=OBJECT_ID(N'dbo.FactAirQuality') AND name<>N'Value' AND is_nullable=1)
    THROW 51011, 'Fact co cot bat buoc dang NULL.', 1;
IF EXISTS (SELECT 1 FROM sys.default_constraints WHERE parent_object_id=OBJECT_ID(N'dbo.FactAirQuality') AND parent_column_id=COLUMNPROPERTY(OBJECT_ID(N'dbo.FactAirQuality'),N'IsValid','ColumnId'))
    THROW 51012, 'Khong duoc mac dinh IsValid=1.', 1;
IF (SELECT COUNT(*) FROM dbo.DimDate) <> 366 OR (SELECT COUNT(*) FROM dbo.DimTime) <> 24
    THROW 51013, 'Lich khong du 366 ngay / 24 gio.', 1;
IF NOT EXISTS (SELECT 1 FROM dbo.DimDate WHERE DateKey=20240229 AND FullDate=CONVERT(date,'20240229',112) AND DayOfWeekISO=4)
    THROW 51014, 'Sai ngay nhuan/thu ISO.', 1;
IF (SELECT MIN(FullDate) FROM dbo.DimDate) <> CONVERT(date,'20240101',112)
    OR (SELECT MAX(FullDate) FROM dbo.DimDate) <> CONVERT(date,'20241231',112)
    OR (SELECT MIN(TimeKey) FROM dbo.DimTime) <> 0 OR (SELECT MAX(TimeKey) FROM dbo.DimTime) <> 230000
    THROW 51015, 'Sai bien lich ngay/gio.', 1;

SELECT N'PASS' AS Result, N'9 tables; Star 6 tables / 40 columns; calendar 366 / 24; constraints enabled/trusted' AS Verification;
SELECT s.name AS SchemaName,t.name AS TableName,COUNT(c.column_id) AS Columns
FROM @ExpectedTables e JOIN sys.schemas s ON s.name=e.SchemaName
JOIN sys.tables t ON t.schema_id=s.schema_id AND t.name=e.TableName JOIN sys.columns c ON c.object_id=t.object_id
GROUP BY s.name,t.name ORDER BY s.name,t.name;
SELECT N'DimDate' AS TableName,COUNT_BIG(*) AS [RowCount] FROM dbo.DimDate
UNION ALL SELECT N'DimTime',COUNT_BIG(*) FROM dbo.DimTime
UNION ALL SELECT N'DimStation',COUNT_BIG(*) FROM dbo.DimStation
UNION ALL SELECT N'DimPollutant',COUNT_BIG(*) FROM dbo.DimPollutant
UNION ALL SELECT N'DimSensor',COUNT_BIG(*) FROM dbo.DimSensor
UNION ALL SELECT N'FactAirQuality',COUNT_BIG(*) FROM dbo.FactAirQuality
UNION ALL SELECT N'stg.AirQuality',COUNT_BIG(*) FROM stg.AirQuality
UNION ALL SELECT N'etl.BatchLog',COUNT_BIG(*) FROM etl.BatchLog
UNION ALL SELECT N'etl.RejectRow',COUNT_BIG(*) FROM etl.RejectRow;
SELECT fk.name AS ForeignKeyName,OBJECT_SCHEMA_NAME(fk.parent_object_id) AS ChildSchema,
    OBJECT_NAME(fk.parent_object_id) AS ChildTable, pc.name AS ChildColumn,
    OBJECT_SCHEMA_NAME(fk.referenced_object_id) AS ParentSchema,OBJECT_NAME(fk.referenced_object_id) AS ParentTable,
    rc.name AS ParentColumn,fk.is_disabled,fk.is_not_trusted
FROM sys.foreign_keys fk JOIN sys.foreign_key_columns fc ON fc.constraint_object_id=fk.object_id
JOIN sys.columns pc ON pc.object_id=fc.parent_object_id AND pc.column_id=fc.parent_column_id
JOIN sys.columns rc ON rc.object_id=fc.referenced_object_id AND rc.column_id=fc.referenced_column_id
ORDER BY fk.name;
SELECT t.name AS TableName,c.column_id,c.name AS ColumnName,ty.name AS SqlType,
    c.max_length,c.precision,c.scale,c.is_nullable,c.is_identity
FROM sys.tables t JOIN sys.schemas s ON s.schema_id=t.schema_id
JOIN sys.columns c ON c.object_id=t.object_id JOIN sys.types ty ON ty.user_type_id=c.user_type_id
WHERE s.name=N'dbo' AND t.name IN (N'DimDate',N'DimTime',N'DimStation',N'DimPollutant',N'DimSensor',N'FactAirQuality')
ORDER BY t.name,c.column_id;
SELECT N'PK' AS ConstraintType,COUNT(*) AS ConstraintCount FROM sys.key_constraints WHERE type=N'PK'
UNION ALL SELECT N'UNIQUE',COUNT(*) FROM sys.key_constraints WHERE type=N'UQ'
UNION ALL SELECT N'FK',COUNT(*) FROM sys.foreign_keys
UNION ALL SELECT N'CHECK',COUNT(*) FROM sys.check_constraints;
GO
