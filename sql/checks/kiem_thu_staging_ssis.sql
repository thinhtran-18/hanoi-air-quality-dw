-- Kiem thu tren kho hien tai da nap buoc 8. Tao batch test va de lai log de kiem chung.
USE hanoi_air_dw;
GO
SET NOCOUNT ON;
DECLARE @b uniqueidentifier, @before bigint=(SELECT COUNT_BIG(*) FROM dbo.FactAirQuality);
DECLARE @start TABLE (BatchId varchar(36));
INSERT @start EXEC etl.usp_StartSSISBatch;
SELECT @b=TRY_CONVERT(uniqueidentifier,BatchId) FROM @start;
IF @b IS NULL THROW 51605,'StartSSISBatch khong tra GUID hop le.',1;
INSERT stg.AirQuality(BatchId,SourceId,StationId,SensorId,StationName,ObservedAtSource,Latitude,Longitude,PollutantCode,Unit,Value)
SELECT @b,id,location_id,sensor_id,location_name,observed_at,latitude,longitude,parameter,unit,value
FROM hanoi_air_vn.dbo.air_quality_hourly WHERE LOWER(LTRIM(RTRIM(parameter))) IN (N'pm25',N'pm10');
EXEC etl.usp_ProcessStagedBatch @b;
IF NOT EXISTS(SELECT 1 FROM etl.BatchLog WHERE BatchId=@b AND Status='Success' AND ExtractedRows=11500 AND ExistingRows=11500 AND InsertedRows=0) THROW 51600,'Test nap lai khong dat.',1;
IF (SELECT COUNT_BIG(*) FROM dbo.FactAirQuality)<>@before THROW 51601,'Fact thay doi bat thuong.',1;
SELECT 'PASS nap lai staging' AS Test,Status,ExtractedRows,InsertedRows,ExistingRows FROM etl.BatchLog WHERE BatchId=@b;
DECLARE @bad uniqueidentifier, @caught int=0;
EXEC etl.usp_StartBatch @bad OUTPUT;
INSERT stg.AirQuality(BatchId,SourceId,StationId,SensorId,StationName,ObservedAtSource,Latitude,Longitude,PollutantCode,Unit,Value)
SELECT TOP(1) @bad,id,location_id,sensor_id,location_name,observed_at,latitude,longitude,parameter,unit,value+1
FROM hanoi_air_vn.dbo.air_quality_hourly WHERE parameter IN (N'pm25',N'pm10') ORDER BY id;
BEGIN TRY EXEC etl.usp_ProcessStagedBatch @bad; END TRY BEGIN CATCH SET @caught=ERROR_NUMBER(); END CATCH;
IF @caught<>51306 OR NOT EXISTS(SELECT 1 FROM etl.BatchLog WHERE BatchId=@bad AND Status='Failed') THROW 51602,'Test xung dot hoac log loi khong dat.',1;
IF (SELECT COUNT_BIG(*) FROM dbo.FactAirQuality)<>@before THROW 51603,'Fact thay doi sau xung dot.',1;
SELECT 'PASS xung dot' AS Test,Status,ErrorMessage FROM etl.BatchLog WHERE BatchId=@bad;
DECLARE @fail uniqueidentifier;
EXEC etl.usp_StartBatch @fail OUTPUT;
EXEC etl.usp_FailStagedBatch @fail,N'Test loi Data Flow';
IF NOT EXISTS(SELECT 1 FROM etl.BatchLog WHERE BatchId=@fail AND Status='Failed' AND ErrorMessage=N'Test loi Data Flow') THROW 51604,'Test log loi Data Flow khong dat.',1;
SELECT 'PASS danh dau Data Flow loi' AS Test,Status,ErrorMessage FROM etl.BatchLog WHERE BatchId=@fail;
SELECT COUNT_BIG(*) AS FactRows FROM dbo.FactAirQuality;
GO
