-- Ca thu ky thuat trong transaction; rollback, khong sua nguon.
USE hanoi_air_dw;
GO
SET NOCOUNT ON;
DECLARE @batch uniqueidentifier=NEWID(), @lock int, @caught int=0;
DECLARE @before bigint=(SELECT COUNT_BIG(*) FROM dbo.FactAirQuality);
BEGIN TRY
 BEGIN TRANSACTION;
 EXEC @lock=sys.sp_getapplock @Resource='hanoi_air_dw_etl',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
 IF @lock<0 THROW 51800,'Khong lay duoc khoa',1;
 IF EXISTS(SELECT 1 FROM dbo.DimSensor WHERE SensorId=2147483646) THROW 51801,'Ma sensor test da ton tai',1;
 INSERT etl.BatchLog(BatchId,SourceName) VALUES(@batch,N'test thieu dimension');
 INSERT stg.AirQuality(BatchId,SourceId,StationId,SensorId,StationName,ObservedAtSource,Latitude,Longitude,PollutantCode,Unit,Value)
 SELECT TOP(1) @batch,id,location_id,2147483646,location_name,observed_at,latitude,longitude,parameter,unit,value FROM hanoi_air_vn.dbo.air_quality_hourly WHERE parameter IN (N'pm25',N'pm10') ORDER BY id;
 EXEC etl.ClassifyAirQualityBatch @BatchId=@batch;
 IF NOT EXISTS(SELECT 1 FROM stg.vAirQualityClassified WHERE BatchId=@batch AND Classification='ACCEPTED') THROW 51802,'Du lieu test khong hop le',1;
 BEGIN TRY EXEC etl.usp_LoadFact @BatchId=@batch; END TRY BEGIN CATCH SET @caught=ERROR_NUMBER(); END CATCH;
 IF @caught<>51305 THROW 51803,'Khong phat hien dimension thieu',1;
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 IF (SELECT COUNT_BIG(*) FROM dbo.FactAirQuality)<>@before THROW 51804,'Fact thay doi',1;
 SELECT 'PASS: thieu sensor dimension bi chan, fact khong doi' AS KetQua;
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO
