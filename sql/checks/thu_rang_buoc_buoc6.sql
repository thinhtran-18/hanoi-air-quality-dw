-- KIEM THU KY THUAT: du lieu gia chi ton tai trong transaction, ROLLBACK tat ca.
-- Chi chay khi kho chua nap ETL. Identity co the co khoang trong sau ROLLBACK.
USE [hanoi_air_dw];
GO
SET NOCOUNT ON;
SET XACT_ABORT OFF; -- Cac loi constraint du kien khong lam hong transaction kiem thu.
IF DB_NAME()<>N'hanoi_air_dw' THROW 51100,'Sai database kiem thu.',1;
IF EXISTS(SELECT 1 FROM dbo.FactAirQuality) OR EXISTS(SELECT 1 FROM dbo.DimStation)
 OR EXISTS(SELECT 1 FROM dbo.DimPollutant) OR EXISTS(SELECT 1 FROM dbo.DimSensor)
 OR EXISTS(SELECT 1 FROM stg.AirQuality) OR EXISTS(SELECT 1 FROM etl.BatchLog) OR EXISTS(SELECT 1 FROM etl.RejectRow)
    THROW 51101,'Chi chay thu rang buoc buoc 6 tren kho chua nap ETL.',1;
DECLARE @Results TABLE (TestId varchar(60),Result varchar(4),ExpectedError int NULL,ActualError int NULL);
DECLARE @Cases TABLE (TestId varchar(60),SqlText nvarchar(max),ExpectedError int,ExpectedMarker nvarchar(128));
DECLARE @Batch uniqueidentifier=NEWID(),@OtherBatch uniqueidentifier=NEWID(),@MissingBatch uniqueidentifier=NEWID();
DECLARE @Station int,@Pollutant int,@Sensor int,@OtherSensor int,@Seed bigint;
BEGIN TRY
    BEGIN TRANSACTION;
    INSERT etl.BatchLog(BatchId,SourceName) VALUES(@Batch,N'KIEM THU - rollback'),(@OtherBatch,N'KIEM THU - rollback');
    INSERT dbo.DimStation(StationId,StationName,CityName) VALUES(2161299,N'KIEM THU - rollback',N'Hà Nội');
    SET @Station=CONVERT(int,SCOPE_IDENTITY());
    INSERT dbo.DimPollutant(PollutantCode,PollutantName,Unit) VALUES(N'pm25',N'PM2.5',N'µg/m³');
    SET @Pollutant=CONVERT(int,SCOPE_IDENTITY());
    INSERT dbo.DimSensor(SensorId,SensorDescription) VALUES(1900000001,N'KIEM THU - rollback');
    SET @Sensor=CONVERT(int,SCOPE_IDENTITY());
    INSERT dbo.DimSensor(SensorId,SensorDescription) VALUES(1900000002,N'KIEM THU - rollback');
    SET @OtherSensor=CONVERT(int,SCOPE_IDENTITY());
    INSERT dbo.FactAirQuality(DateKey,TimeKey,StationKey,PollutantKey,SensorKey,ObservedAtSource,ObservedAtUTC,ObservedAtLocal,Value,IsValid,SourceId,BatchId)
    VALUES(20240130,0,@Station,@Pollutant,@Sensor,'2024-01-29T17:00:00+00:00','2024-01-29T17:00:00','2024-01-30T00:00:00+07:00',12.5,1,1,@Batch);
    SET @Seed=SCOPE_IDENTITY();
    INSERT @Results VALUES('local_midnight_source_offset_preserved','PASS',NULL,NULL);
    INSERT dbo.FactAirQuality(DateKey,TimeKey,StationKey,PollutantKey,SensorKey,ObservedAtSource,ObservedAtUTC,ObservedAtLocal,Value,IsValid,SourceId,BatchId)
    VALUES
      (20240130,0,@Station,@Pollutant,@OtherSensor,'2024-01-30T00:00:00+07:00','2024-01-29T17:00:00','2024-01-30T00:00:00+07:00',13,1,2,@Batch),
      (20240130,10000,@Station,@Pollutant,@Sensor,'2024-01-30T01:00:00+07:00','2024-01-29T18:00:00','2024-01-30T01:00:00+07:00',NULL,0,3,@Batch),
      (20240130,20000,@Station,@Pollutant,@Sensor,'2024-01-30T02:00:00+07:00','2024-01-29T19:00:00','2024-01-30T02:00:00+07:00',-1,0,4,@Batch),
      (20240130,30000,@Station,@Pollutant,@Sensor,'2024-01-30T03:00:00+07:00','2024-01-29T20:00:00','2024-01-30T03:00:00+07:00',100000,1,5,@Batch);
    INSERT @Results VALUES('same_hour_different_sensor_allowed','PASS',NULL,NULL),
      ('null_negative_preserved_with_IsValid_0','PASS',NULL,NULL),('high_positive_not_automatically_rejected','PASS',NULL,NULL);
    INSERT stg.AirQuality(BatchId,SourceId,ObservedAtSource,Value)
    VALUES(@Batch,1,'2024-01-30T00:00:00.1234567+07:00',-1),(@Batch,1,'2024-01-30T00:00:00.1234567+07:00',-1);
    IF (SELECT COUNT(*) FROM stg.AirQuality WHERE BatchId=@Batch)<>2
      OR EXISTS(SELECT 1 FROM stg.AirQuality WHERE DATEPART(nanosecond,ObservedAtSource)<>123456700)
        THROW 51102,'Staging khong giu du dong trung/loi/phan giay.',1;
    INSERT @Results VALUES('staging_retains_duplicates_errors_fractional_seconds','PASS',NULL,NULL);

    DECLARE @Copy nvarchar(max)=N'INSERT dbo.FactAirQuality(DateKey,TimeKey,StationKey,PollutantKey,SensorKey,ObservedAtSource,ObservedAtUTC,ObservedAtLocal,Value,IsValid,SourceId,BatchId) SELECT DateKey,TimeKey,StationKey,PollutantKey,SensorKey,ObservedAtSource,ObservedAtUTC,ObservedAtLocal,Value,IsValid,SourceId,';
    INSERT @Cases VALUES
      ('duplicate_same_payload',@Copy+N'BatchId FROM dbo.FactAirQuality WHERE AirQualityKey=@Seed;',2627,N'UQ_FactAirQuality_Grain'),
      ('duplicate_new_batch',@Copy+N'@OtherBatch FROM dbo.FactAirQuality WHERE AirQualityKey=@Seed;',2627,N'UQ_FactAirQuality_Grain'),
      ('duplicate_changed_value',REPLACE(@Copy+N'BatchId FROM dbo.FactAirQuality WHERE AirQualityKey=@Seed;',N'Value,IsValid,SourceId,BatchId FROM',N'Value+1,IsValid,SourceId,BatchId FROM'),2627,N'UQ_FactAirQuality_Grain'),
      ('orphan_station',N'UPDATE dbo.FactAirQuality SET StationKey=-1 WHERE AirQualityKey=@Seed;',547,N'FK_FactAirQuality_Station'),
      ('orphan_sensor',N'UPDATE dbo.FactAirQuality SET SensorKey=-1 WHERE AirQualityKey=@Seed;',547,N'FK_FactAirQuality_Sensor'),
      ('orphan_pollutant',N'UPDATE dbo.FactAirQuality SET PollutantKey=-1 WHERE AirQualityKey=@Seed;',547,N'FK_FactAirQuality_Pollutant'),
      ('orphan_batch',N'UPDATE dbo.FactAirQuality SET BatchId=@MissingBatch WHERE AirQualityKey=@Seed;',547,N'FK_FactAirQuality_Batch'),
      ('orphan_date',N'DELETE dbo.DimDate WHERE DateKey=20240131; UPDATE dbo.FactAirQuality SET DateKey=20240131,ObservedAtSource=''2024-01-31T00:00:00+07:00'',ObservedAtUTC=''2024-01-30T17:00:00'',ObservedAtLocal=''2024-01-31T00:00:00+07:00'' WHERE AirQualityKey=@Seed;',547,N'FK_FactAirQuality_Date'),
      ('orphan_time',N'DELETE dbo.DimTime WHERE TimeKey=230000; UPDATE dbo.FactAirQuality SET TimeKey=230000,ObservedAtSource=''2024-01-30T23:00:00+07:00'',ObservedAtUTC=''2024-01-30T16:00:00'',ObservedAtLocal=''2024-01-30T23:00:00+07:00'' WHERE AirQualityKey=@Seed;',547,N'FK_FactAirQuality_Time'),
      ('stage_orphan_batch',N'INSERT stg.AirQuality(BatchId,SourceId) VALUES(@MissingBatch,1);',547,N'FK_StageAirQuality_Batch'),
      ('reject_orphan_batch',N'INSERT etl.RejectRow(BatchId,SourceId,ReasonCode,ReasonDetail) VALUES(@MissingBatch,1,N''TEST'',N''TEST'');',547,N'FK_RejectRow_Batch'),
      ('null_sensor_key',N'UPDATE dbo.FactAirQuality SET SensorKey=NULL WHERE AirQualityKey=@Seed;',515,N'SensorKey'),
      ('local_offset_not_07',N'UPDATE dbo.FactAirQuality SET ObservedAtLocal=''2024-01-30T01:00:00+08:00'',TimeKey=10000 WHERE AirQualityKey=@Seed;',547,N'CK_FactAirQuality_TimeZone'),
      ('utc_different_instant',N'UPDATE dbo.FactAirQuality SET ObservedAtUTC=DATEADD(second,1,ObservedAtUTC) WHERE AirQualityKey=@Seed;',547,N'CK_FactAirQuality_Instant'),
      ('datekey_from_UTC_instead_of_local',N'UPDATE dbo.FactAirQuality SET DateKey=20240129 WHERE AirQualityKey=@Seed;',547,N'CK_FactAirQuality_LocalKeys'),
      ('null_marked_valid',N'UPDATE dbo.FactAirQuality SET Value=NULL WHERE AirQualityKey=@Seed;',547,N'CK_FactAirQuality_Validity'),
      ('negative_marked_valid',N'UPDATE dbo.FactAirQuality SET Value=-1 WHERE AirQualityKey=@Seed;',547,N'CK_FactAirQuality_Validity'),
      ('wrong_day_of_week',N'UPDATE dbo.DimDate SET DayOfWeekISO=7 WHERE DateKey=20240130;',547,N'CK_DimDate_Calendar'),
      ('minute_requires_design_extension',N'INSERT dbo.DimTime VALUES(123000,''12:30:00'',12,30,0);',547,N'CK_DimTime_Hourly'),
      ('duplicate_station_natural_key',N'INSERT dbo.DimStation(StationId,StationName,CityName) VALUES(2161299,N''TEST'',N''Hà Nội'');',2627,N'UQ_DimStation_StationId'),
      ('duplicate_sensor_natural_key',N'INSERT dbo.DimSensor(SensorId) VALUES(1900000001);',2627,N'UQ_DimSensor_SensorId'),
      ('duplicate_pollutant_natural_key',N'INSERT dbo.DimPollutant(PollutantCode,PollutantName,Unit) VALUES(N''pm25'',N''PM2.5'',N''µg/m³'');',2627,N'UQ_DimPollutant_Code'),
      ('wrong_unit',N'UPDATE dbo.DimPollutant SET Unit=N''mg/m³'' WHERE PollutantKey=@Pollutant;',547,N'CK_DimPollutant_Domain'),
      ('success_batch_unbalanced',N'UPDATE etl.BatchLog SET ExtractedRows=1,Status=N''Success'',FinishedAtUTC=SYSUTCDATETIME() WHERE BatchId=@Batch;',547,N'CK_BatchLog_SuccessBalance');

    DECLARE @Id varchar(60),@Sql nvarchar(max),@Expected int,@Marker nvarchar(128),@Actual int,@Message nvarchar(2048);
    DECLARE probe CURSOR LOCAL FAST_FORWARD FOR SELECT TestId,SqlText,ExpectedError,ExpectedMarker FROM @Cases;
    OPEN probe;
    FETCH NEXT FROM probe INTO @Id,@Sql,@Expected,@Marker;
    WHILE @@FETCH_STATUS=0
    BEGIN
        SAVE TRANSACTION SingleProbe;
        SET @Actual=NULL; SET @Message=NULL;
        BEGIN TRY
            EXEC sys.sp_executesql @Sql,N'@Seed bigint,@OtherBatch uniqueidentifier,@MissingBatch uniqueidentifier,@Batch uniqueidentifier,@Pollutant int',@Seed,@OtherBatch,@MissingBatch,@Batch,@Pollutant;
        END TRY
        BEGIN CATCH
            SELECT @Actual=ERROR_NUMBER(),@Message=ERROR_MESSAGE();
        END CATCH;
        IF XACT_STATE()<>1 THROW 51103,'Transaction kiem thu khong con rollback ve savepoint duoc.',1;
        ROLLBACK TRANSACTION SingleProbe;
        INSERT @Results VALUES(@Id,CASE WHEN @Actual=@Expected AND CHARINDEX(@Marker,@Message)>0 THEN 'PASS' ELSE 'FAIL' END,@Expected,@Actual);
        FETCH NEXT FROM probe INTO @Id,@Sql,@Expected,@Marker;
    END;
    CLOSE probe; DEALLOCATE probe;
    ROLLBACK TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
    SET XACT_ABORT ON;
    THROW;
END CATCH;
SET XACT_ABORT ON;
IF EXISTS(SELECT 1 FROM dbo.FactAirQuality) OR EXISTS(SELECT 1 FROM dbo.DimStation)
 OR EXISTS(SELECT 1 FROM dbo.DimPollutant) OR EXISTS(SELECT 1 FROM dbo.DimSensor)
 OR EXISTS(SELECT 1 FROM stg.AirQuality) OR EXISTS(SELECT 1 FROM etl.BatchLog) OR EXISTS(SELECT 1 FROM etl.RejectRow)
 OR (SELECT COUNT(*) FROM dbo.DimDate)<>366 OR (SELECT COUNT(*) FROM dbo.DimTime)<>24
    THROW 51104,'Du lieu kiem thu chua duoc rollback day du.',1;
INSERT @Results VALUES('rollback_all_test_data_calendar_unchanged','PASS',NULL,NULL);
SELECT * FROM @Results ORDER BY TestId;
IF EXISTS(SELECT 1 FROM @Results WHERE Result<>'PASS') THROW 51105,'Co ca thu rang buoc khong dat.',1;
SELECT COUNT(*) AS PassedTests,N'PASS; all synthetic rows rolled back' AS Result FROM @Results;
GO
