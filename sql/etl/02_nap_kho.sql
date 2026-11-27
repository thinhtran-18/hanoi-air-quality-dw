-- Buoc 8: chay qua etl.usp_RunBatch; cac procedure con dung chung transaction.
USE hanoi_air_dw;
GO
CREATE OR ALTER PROCEDURE etl.usp_StartBatch @BatchId uniqueidentifier OUTPUT AS
BEGIN
 SET NOCOUNT ON;
 IF @@TRANCOUNT<>0 THROW 51300,'Khong goi tu transaction ben ngoai.',1;
 SET @BatchId=NEWID();
 INSERT etl.BatchLog(BatchId,SourceName) VALUES(@BatchId,N'hanoi_air_vn.dbo.air_quality_hourly');
END;
GO
CREATE OR ALTER PROCEDURE etl.usp_ValidateStage @BatchId uniqueidentifier AS
BEGIN
 SET NOCOUNT ON;
 IF @@TRANCOUNT=0 OR APPLOCK_MODE('public','hanoi_air_dw_etl','Transaction')<>'Exclusive'
   THROW 51301,'Phai goi qua usp_RunBatch trong transaction va giu khoa ETL.',1;
 INSERT stg.AirQuality(BatchId,SourceId,StationId,SensorId,StationName,ObservedAtSource,Latitude,Longitude,PollutantCode,Unit,Value)
 SELECT @BatchId,id,location_id,sensor_id,location_name,observed_at,latitude,longitude,parameter,unit,value
 FROM hanoi_air_vn.dbo.air_quality_hourly
 WHERE LOWER(LTRIM(RTRIM(parameter))) IN (N'pm25',N'pm10');
 EXEC etl.ClassifyAirQualityBatch @BatchId=@BatchId;
 IF EXISTS (SELECT 1 FROM stg.vAirQualityClassified WHERE BatchId=@BatchId AND Classification='CONFLICT')
   THROW 51302,'Xung dot grain trong batch; dung nap.',1;
 IF EXISTS (SELECT StationId FROM stg.vAirQualityClassified WHERE BatchId=@BatchId AND Classification='ACCEPTED'
    GROUP BY StationId HAVING COUNT(DISTINCT CONCAT(NameNormalized,N'|',COALESCE(CONVERT(nvarchar(50),Latitude),N'<NULL>'),N'|',COALESCE(CONVERT(nvarchar(50),Longitude),N'<NULL>'))) > 1)
   THROW 51303,'Metadata tram khong nhat quan trong batch.',1;
 IF EXISTS (SELECT SensorId FROM stg.vAirQualityClassified WHERE BatchId=@BatchId AND Classification='ACCEPTED'
    GROUP BY SensorId HAVING COUNT(DISTINCT StationId)>1 OR COUNT(DISTINCT CodeNormalized)>1)
   THROW 51304,'Cam bien gan nhieu tram hoac chat; can xac minh metadata.',1;
END;
GO
CREATE OR ALTER PROCEDURE etl.usp_LoadDimensions @BatchId uniqueidentifier AS
BEGIN
 SET NOCOUNT ON;
 IF @@TRANCOUNT=0 OR APPLOCK_MODE('public','hanoi_air_dw_etl','Transaction')<>'Exclusive' THROW 51301,'Phai goi qua usp_RunBatch.',1;
 DECLARE @updates TABLE (StationId int, OldName nvarchar(160), NewName nvarchar(160), OldLatitude decimal(10,6), NewLatitude decimal(10,6), OldLongitude decimal(10,6), NewLongitude decimal(10,6));
 ;WITH stations AS (SELECT StationId,MAX(NameNormalized) StationName,MAX(Latitude) Latitude,MAX(Longitude) Longitude FROM stg.vAirQualityClassified WHERE BatchId=@BatchId AND Classification='ACCEPTED' GROUP BY StationId)
 UPDATE d SET StationName=s.StationName, Latitude=COALESCE(s.Latitude,d.Latitude), Longitude=COALESCE(s.Longitude,d.Longitude)
 OUTPUT inserted.StationId,deleted.StationName,inserted.StationName,deleted.Latitude,inserted.Latitude,deleted.Longitude,inserted.Longitude INTO @updates
 FROM dbo.DimStation d JOIN stations s ON s.StationId=d.StationId
 WHERE EXISTS (SELECT d.StationName,d.Latitude,d.Longitude EXCEPT SELECT s.StationName,COALESCE(s.Latitude,d.Latitude),COALESCE(s.Longitude,d.Longitude));
 UPDATE etl.BatchLog SET MetadataUpdatesJSON=(SELECT * FROM @updates FOR JSON PATH,INCLUDE_NULL_VALUES) WHERE BatchId=@BatchId;
 INSERT dbo.DimStation(StationId,StationName,Latitude,Longitude,CityName,DistrictName)
 SELECT s.StationId,MAX(s.NameNormalized),MAX(s.Latitude),MAX(s.Longitude),N'Hà Nội',NULL
 FROM stg.vAirQualityClassified s WHERE s.BatchId=@BatchId AND s.Classification='ACCEPTED' AND NOT EXISTS (SELECT 1 FROM dbo.DimStation d WHERE d.StationId=s.StationId) GROUP BY s.StationId;
 INSERT dbo.DimSensor(SensorId,SensorDescription)
 SELECT DISTINCT s.SensorId,NULL FROM stg.vAirQualityClassified s WHERE s.BatchId=@BatchId AND s.Classification='ACCEPTED'
 AND NOT EXISTS (SELECT 1 FROM dbo.DimSensor d WHERE d.SensorId=s.SensorId);
 INSERT dbo.DimPollutant(PollutantCode,PollutantName,Unit)
 SELECT DISTINCT s.CodeNormalized,CASE s.CodeNormalized WHEN N'pm25' THEN N'PM2.5' ELSE N'PM10' END,N'µg/m³'
 FROM stg.vAirQualityClassified s WHERE s.BatchId=@BatchId AND s.Classification='ACCEPTED'
 AND NOT EXISTS (SELECT 1 FROM dbo.DimPollutant d WHERE d.PollutantCode=s.CodeNormalized);
END;
GO
CREATE OR ALTER PROCEDURE etl.usp_LoadFact @BatchId uniqueidentifier AS
BEGIN
 SET NOCOUNT ON;
 IF @@TRANCOUNT=0 OR APPLOCK_MODE('public','hanoi_air_dw_etl','Transaction')<>'Exclusive' THROW 51301,'Phai goi qua usp_RunBatch.',1;
 SELECT c.*, ds.StationKey,dp.PollutantKey,dn.SensorKey
 INTO #ready FROM stg.vAirQualityClassified c
 LEFT JOIN dbo.DimStation ds ON ds.StationId=c.StationId
 LEFT JOIN dbo.DimPollutant dp ON dp.PollutantCode=c.CodeNormalized
 LEFT JOIN dbo.DimSensor dn ON dn.SensorId=c.SensorId
 WHERE c.BatchId=@BatchId AND c.Classification='ACCEPTED';
 IF EXISTS (SELECT 1 FROM #ready r LEFT JOIN dbo.DimDate d ON d.DateKey=r.DateKey LEFT JOIN dbo.DimTime t ON t.TimeKey=r.TimeKey
   WHERE r.StationKey IS NULL OR r.PollutantKey IS NULL OR r.SensorKey IS NULL OR d.DateKey IS NULL OR t.TimeKey IS NULL)
   THROW 51305,'Khong tra duoc dimension; dung nap.',1;
 -- So sanh payload nguon luu trong staging goc cua fact (tranh coi thay doi metadata la giong het).
 IF EXISTS (
   SELECT 1 FROM #ready r JOIN dbo.FactAirQuality f ON f.StationKey=r.StationKey AND f.SensorKey=r.SensorKey AND f.ObservedAtUTC=r.ObservedAtUTC AND f.PollutantKey=r.PollutantKey
   LEFT JOIN stg.AirQuality original ON original.BatchId=f.BatchId AND original.SourceId=f.SourceId
   WHERE original.StageRowId IS NULL OR EXISTS (
     SELECT r.NameNormalized,r.Latitude,r.Longitude,r.UnitNormalized,r.Value,CONVERT(nvarchar(50),r.ObservedAtSource,127)
     EXCEPT SELECT LTRIM(RTRIM(original.StationName)),original.Latitude,original.Longitude,LTRIM(RTRIM(original.Unit)),original.Value,CONVERT(nvarchar(50),original.ObservedAtSource,127)))
   THROW 51306,'Xung dot payload voi fact da co hoac thieu lineage; dung nap.',1;
 DECLARE @existing bigint=(SELECT COUNT_BIG(*) FROM #ready r JOIN dbo.FactAirQuality f ON f.StationKey=r.StationKey AND f.SensorKey=r.SensorKey AND f.ObservedAtUTC=r.ObservedAtUTC AND f.PollutantKey=r.PollutantKey);
 INSERT dbo.FactAirQuality(DateKey,TimeKey,StationKey,PollutantKey,SensorKey,ObservedAtSource,ObservedAtUTC,ObservedAtLocal,Value,IsValid,SourceId,BatchId)
 SELECT r.DateKey,r.TimeKey,r.StationKey,r.PollutantKey,r.SensorKey,r.ObservedAtSource,r.ObservedAtUTC,r.ObservedAtLocal,r.Value,1,r.SourceId,@BatchId
 FROM #ready r WHERE NOT EXISTS (SELECT 1 FROM dbo.FactAirQuality f WHERE f.StationKey=r.StationKey AND f.SensorKey=r.SensorKey AND f.ObservedAtUTC=r.ObservedAtUTC AND f.PollutantKey=r.PollutantKey);
 DECLARE @inserted bigint=@@ROWCOUNT;
 UPDATE etl.BatchLog SET InsertedRows=@inserted,ExistingRows=@existing WHERE BatchId=@BatchId;
END;
GO
CREATE OR ALTER PROCEDURE etl.usp_FinishBatch @BatchId uniqueidentifier AS
BEGIN
 SET NOCOUNT ON;
 IF @@TRANCOUNT=0 OR APPLOCK_MODE('public','hanoi_air_dw_etl','Transaction')<>'Exclusive' THROW 51301,'Phai goi qua usp_RunBatch.',1;
 UPDATE etl.BatchLog SET Status='Success',FinishedAtUTC=SYSUTCDATETIME() WHERE BatchId=@BatchId AND Status='Running';
 IF @@ROWCOUNT<>1 THROW 51307,'Batch khong Running.',1;
END;
GO
CREATE OR ALTER PROCEDURE etl.usp_RunBatch @BatchId uniqueidentifier OUTPUT AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51300,'Khong goi tu transaction ben ngoai.',1;
 EXEC etl.usp_StartBatch @BatchId OUTPUT;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @lockresult int;
  EXEC @lockresult=sys.sp_getapplock @Resource='hanoi_air_dw_etl',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
  IF @lockresult<0 THROW 51308,'ETL khac dang chay hoac khong lay duoc khoa.',1;
  -- Khoa staging toi het transaction de du lieu khong doi sau phan loai.
  DECLARE @lockrows bigint; SELECT @lockrows=COUNT_BIG(*) FROM stg.AirQuality WITH (TABLOCKX,HOLDLOCK);
  EXEC etl.usp_ValidateStage @BatchId;
  EXEC etl.usp_LoadDimensions @BatchId;
  EXEC etl.usp_LoadFact @BatchId;
  EXEC etl.usp_FinishBatch @BatchId;
  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  DECLARE @err nvarchar(2048)=ERROR_MESSAGE();
  IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
  UPDATE etl.BatchLog SET Status='Failed',FinishedAtUTC=SYSUTCDATETIME(),ErrorMessage=@err WHERE BatchId=@BatchId AND Status='Running';
  THROW;
 END CATCH;
 SELECT BatchId,Status,ExtractedRows,InsertedRows,ExistingRows,RejectedRows,DuplicateRows,ExcludedRows,ConflictRows FROM etl.BatchLog WHERE BatchId=@BatchId;
END;
GO
