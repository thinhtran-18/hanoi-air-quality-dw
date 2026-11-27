-- Thu trong transaction, rollback; IDENTITY co the tang du rollback.
USE hanoi_air_dw;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
BEGIN TRY
BEGIN TRANSACTION;
DECLARE @b uniqueidentifier=NEWID();
INSERT etl.BatchLog(BatchId,SourceName) VALUES (@b,N'kiem thu buoc 7');
INSERT stg.AirQuality(BatchId,SourceId,StationId,SensorId,StationName,ObservedAtSource,Latitude,Longitude,PollutantCode,Unit,Value)
VALUES
(@b,1,2161299,1,N'Tram','2024-01-01T00:00:00+07:00',21,105,N' PM25 ',N'µg/m³',10),
(@b,2,2161299,1,N'Tram','2024-01-01T00:00:00+07:00',21,105,N'pm25',N'µg/m³',10),
(@b,3,2161299,2,N'Tram','2024-01-01T00:00:00+07:00',21,105,N'pm25',N'µg/m³',10),
(@b,4,2161299,2,N'Tram','2024-01-01T00:00:00+07:00',21,105,N'pm25',N'µg/m³',11),
(@b,5,2161299,3,N'Tram','2024-01-01T00:00:00+07:00',21,105,N'pm25',N'bad',10),
(@b,6,2161299,4,N'Tram','2024-01-01T00:00:00+07:00',21,105,N'pm25',N'µg/m³',-1),
(@b,7,2161299,5,N'Tram','2024-01-01T00:00:00.100+07:00',21,105,N'pm25',N'µg/m³',10),
(@b,8,2161299,NULL,N'Tram','2024-01-01T00:00:00+07:00',21,105,N'pm25',N'µg/m³',10),
(@b,9,2161299,6,N'Tram','2023-01-01T00:00:00+07:00',21,105,N'pm25',N'µg/m³',10),
(@b,10,2161299,7,N'Tram','2024-01-01T00:00:00+07:00',21,105,N'pm10',N'µg/m³',9999),
(@b,11,2161299,8,N'Tram','2024-01-01T00:00:00+07:00',21,105,N'pm10',N'wrong',9999);
EXEC etl.ClassifyAirQualityBatch @BatchId=@b;
IF (SELECT COUNT(*) FROM stg.vAirQualityClassified WHERE BatchId=@b AND Classification='ACCEPTED')<>2 THROW 51200,'Sai so accepted',1;
IF (SELECT COUNT(*) FROM stg.vAirQualityClassified WHERE BatchId=@b AND Classification='DUPLICATE')<>1 THROW 51201,'Sai so duplicate',1;
IF (SELECT COUNT(*) FROM stg.vAirQualityClassified WHERE BatchId=@b AND Classification='CONFLICT')<>2 THROW 51202,'Sai so conflict',1;
IF (SELECT COUNT(*) FROM stg.vAirQualityClassified WHERE BatchId=@b AND Classification='REJECTED')<>5 THROW 51203,'Sai so rejected',1;
IF (SELECT COUNT(*) FROM stg.vAirQualityClassified WHERE BatchId=@b AND Classification='EXCLUDED')<>1 THROW 51204,'Sai so excluded',1;
IF (SELECT COUNT(*) FROM etl.RejectRow WHERE BatchId=@b AND SourceId IS NOT NULL AND StageRowId IS NOT NULL)<>8 THROW 51205,'Sai lineage',1;
IF NOT EXISTS (SELECT 1 FROM stg.vAirQualityClassified WHERE BatchId=@b AND SourceId=1 AND DateKey=20240101 AND TimeKey=0 AND ObservedAtUTC='2023-12-31T17:00:00') THROW 51206,'Sai chuyen gio',1;
ROLLBACK TRANSACTION;
PRINT 'PASS: 11 dong, 5 loai, lineage, nửa dem, gia tri cao va rollback';
END TRY
BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
END CATCH;
GO
