-- Test xung dot voi fact: du lieu thu va batch rollback; identity co the tang.
USE hanoi_air_dw;
GO
SET NOCOUNT ON;
DECLARE @b uniqueidentifier=NEWID(), @l int, @caught bit=0, @before bigint=(SELECT COUNT_BIG(*) FROM dbo.FactAirQuality);
BEGIN TRY
 BEGIN TRANSACTION;
 EXEC @l=sys.sp_getapplock @Resource='hanoi_air_dw_etl',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
 IF @l<0 THROW 51400,'Khong lay duoc khoa test.',1;
 INSERT etl.BatchLog(BatchId,SourceName) VALUES (@b,N'test xung dot');
 INSERT stg.AirQuality(BatchId,SourceId,StationId,SensorId,StationName,ObservedAtSource,Latitude,Longitude,PollutantCode,Unit,Value)
 SELECT TOP(1) @b,id,location_id,sensor_id,location_name,observed_at,latitude,longitude,parameter,unit,value+1
 FROM hanoi_air_vn.dbo.air_quality_hourly WHERE parameter IN (N'pm25',N'pm10') ORDER BY id;
 EXEC etl.ClassifyAirQualityBatch @BatchId=@b;
 BEGIN TRY
  EXEC etl.usp_LoadDimensions @b;
  EXEC etl.usp_LoadFact @b;
 END TRY
 BEGIN CATCH
  IF ERROR_NUMBER()=51306 SET @caught=1;
  ELSE THROW;
 END CATCH;
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 IF @caught<>1 THROW 51401,'Khong phat hien xung dot voi fact.',1;
 IF (SELECT COUNT_BIG(*) FROM dbo.FactAirQuality)<>@before THROW 51402,'Fact thay doi sau thu.',1;
 PRINT 'PASS: payload khac tren cung grain bi chan, fact khong doi';
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO
