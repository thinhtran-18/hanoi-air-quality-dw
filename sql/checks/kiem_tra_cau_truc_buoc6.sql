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
SELECT N'PK' AS ConstraintType,COUNT(*) AS ConstraintCount FROM sys.key_constraints WHERE type=N'PK' AND parent_object_id<>COALESCE(OBJECT_ID(N'dbo.sysdiagrams'),-1)
UNION ALL SELECT N'UNIQUE',COUNT(*) FROM sys.key_constraints WHERE type=N'UQ' AND parent_object_id<>COALESCE(OBJECT_ID(N'dbo.sysdiagrams'),-1)
UNION ALL SELECT N'FK',COUNT(*) FROM sys.foreign_keys
UNION ALL SELECT N'CHECK',COUNT(*) FROM sys.check_constraints;
GO
