-- Buoc 7: cai dat view va procedure; khong tu dong chay batch hay nap fact.
USE [hanoi_air_dw];
GO
CREATE OR ALTER VIEW stg.vAirQualityClassified AS
WITH normalized AS (
 SELECT s.*, LOWER(LTRIM(RTRIM(s.PollutantCode))) AS CodeNormalized,
        LTRIM(RTRIM(s.Unit)) AS UnitNormalized,
        LTRIM(RTRIM(s.StationName)) AS NameNormalized,
        CAST(SWITCHOFFSET(s.ObservedAtSource,'+00:00') AS datetime2(7)) AS ObservedAtUTC,
        SWITCHOFFSET(s.ObservedAtSource,'+07:00') AS ObservedAtLocal
 FROM stg.AirQuality s
), quality AS (
 SELECT n.*, CASE
   WHEN SourceId <= 0 OR StationId IS NULL OR SensorId IS NULL OR SensorId <= 0 OR ObservedAtSource IS NULL
     OR NULLIF(NameNormalized,N'') IS NULL OR NULLIF(CodeNormalized,N'') IS NULL OR NULLIF(UnitNormalized,N'') IS NULL OR Value IS NULL THEN 'MISSING_REQUIRED'
   WHEN StationId NOT IN (2161299,2161301) OR CodeNormalized COLLATE Latin1_General_100_BIN2 NOT IN (N'pm25',N'pm10')
     OR ObservedAtLocal < CAST('2024-01-01T00:00:00+07:00' AS datetimeoffset)
     OR ObservedAtLocal >= CAST('2025-01-01T00:00:00+07:00' AS datetimeoffset) THEN 'OUT_OF_SCOPE'
   WHEN UnitNormalized COLLATE Latin1_General_100_BIN2 <> N'µg/m³' THEN 'BAD_UNIT'
   WHEN Value < 0 THEN 'NEGATIVE_VALUE'
   WHEN DATEPART(minute,ObservedAtLocal)<>0 OR DATEPART(second,ObservedAtLocal)<>0 OR DATEPART(nanosecond,ObservedAtLocal)<>0 THEN 'TIME_PRECISION'
   WHEN Latitude NOT BETWEEN -90 AND 90 OR Longitude NOT BETWEEN -180 AND 180 THEN 'BAD_COORDINATES'
   ELSE 'CANDIDATE' END AS QualityCode
 FROM normalized n
), payload AS (
 SELECT q.*, CONVERT(varchar(64),HASHBYTES('SHA2_256',
   (SELECT q.NameNormalized AS StationName,q.ObservedAtSource AS ObservedAtSource,q.Latitude AS Latitude,q.Longitude AS Longitude,
           q.UnitNormalized AS Unit,q.Value AS Value FOR JSON PATH, WITHOUT_ARRAY_WRAPPER, INCLUDE_NULL_VALUES)),2) AS PayloadHash
 FROM quality q
), groups AS (
 SELECT BatchId,StationId,SensorId,ObservedAtUTC,CodeNormalized,
        COUNT(DISTINCT PayloadHash) AS PayloadVariants
 FROM payload WHERE QualityCode NOT IN ('MISSING_REQUIRED','OUT_OF_SCOPE')
 GROUP BY BatchId,StationId,SensorId,ObservedAtUTC,CodeNormalized
), ranked AS (
 SELECT p.*,g.PayloadVariants,
   ROW_NUMBER() OVER (PARTITION BY p.BatchId,p.StationId,p.SensorId,p.ObservedAtUTC,p.CodeNormalized ORDER BY CASE WHEN p.QualityCode='CANDIDATE' THEN 0 ELSE 1 END,p.StageRowId) AS rn
 FROM payload p LEFT JOIN groups g ON g.BatchId=p.BatchId AND g.StationId=p.StationId
   AND g.SensorId=p.SensorId AND g.ObservedAtUTC=p.ObservedAtUTC AND g.CodeNormalized=p.CodeNormalized
   AND p.QualityCode='CANDIDATE'
)
SELECT *, CASE WHEN Value >= 150 THEN CAST(1 AS bit) ELSE CAST(0 AS bit) END AS ReviewHigh,
 CASE WHEN QualityCode='OUT_OF_SCOPE' THEN 'EXCLUDED'
 WHEN QualityCode<>'CANDIDATE' THEN 'REJECTED'
 WHEN PayloadVariants>1 THEN 'CONFLICT'
 WHEN rn>1 THEN 'DUPLICATE' ELSE 'ACCEPTED' END AS Classification,
 CASE WHEN QualityCode<>'CANDIDATE' THEN QualityCode
 WHEN PayloadVariants>1 THEN 'CONFLICTING_PAYLOAD'
 WHEN rn>1 THEN 'DUPLICATE_PAYLOAD' ELSE 'OK' END AS ReasonCode,
 CONVERT(int,CONVERT(char(8),ObservedAtLocal,112)) AS DateKey,
 DATEPART(hour,ObservedAtLocal)*10000 + DATEPART(minute,ObservedAtLocal)*100 + DATEPART(second,ObservedAtLocal) AS TimeKey
FROM ranked;
GO
CREATE OR ALTER PROCEDURE etl.ClassifyAirQualityBatch @BatchId uniqueidentifier AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 BEGIN TRY
 BEGIN TRANSACTION;
 IF NOT EXISTS (SELECT 1 FROM etl.BatchLog WITH (UPDLOCK,HOLDLOCK) WHERE BatchId=@BatchId AND Status='Running')
   THROW 51100, 'Batch khong ton tai hoac khong Running.', 1;
 IF EXISTS (SELECT 1 FROM etl.RejectRow WHERE BatchId=@BatchId)
   THROW 51101, 'Batch da duoc phan loai; khong chay lai de tranh nhan doi minh chung.', 1;
 -- Batch chi phan loai mot lan, ke ca truong hop khong co dong reject.
 IF EXISTS (SELECT 1 FROM etl.BatchLog WHERE BatchId=@BatchId AND ExtractedRows<>0)
   THROW 51102, 'Batch da duoc phan loai.', 1;
 IF NOT EXISTS (SELECT 1 FROM stg.AirQuality WHERE BatchId=@BatchId)
   THROW 51103, 'Batch staging rong.', 1;
 SELECT * INTO #classified FROM stg.vAirQualityClassified WHERE BatchId=@BatchId;
 INSERT etl.RejectRow(BatchId,SourceId,StageRowId,ReasonCode,ReasonDetail,RawPayload)
 SELECT c.BatchId,CASE WHEN c.SourceId>0 THEN c.SourceId END,c.StageRowId,c.ReasonCode,
   CONCAT(N'Buoc 7: ',c.Classification,N' / ',c.ReasonCode),
   (SELECT c.SourceId,c.StationId,c.SensorId,c.StationName,c.ObservedAtSource,c.Latitude,c.Longitude,c.PollutantCode,c.Unit,c.Value
    FOR JSON PATH,WITHOUT_ARRAY_WRAPPER,INCLUDE_NULL_VALUES)
 FROM #classified c WHERE c.Classification IN ('REJECTED','DUPLICATE','CONFLICT');
 UPDATE etl.BatchLog SET ExtractedRows=(SELECT COUNT_BIG(*) FROM #classified),
   RejectedRows=(SELECT COUNT_BIG(*) FROM #classified WHERE Classification='REJECTED'),
   DuplicateRows=(SELECT COUNT_BIG(*) FROM #classified WHERE Classification='DUPLICATE'),
   ExcludedRows=(SELECT COUNT_BIG(*) FROM #classified WHERE Classification='EXCLUDED'),
   ConflictRows=(SELECT COUNT_BIG(*) FROM #classified WHERE Classification='CONFLICT')
 WHERE BatchId=@BatchId;
 SELECT Classification,COUNT_BIG(*) AS [RowCount] FROM #classified GROUP BY Classification ORDER BY Classification;
 COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
 END CATCH
END;
GO
CREATE OR ALTER PROCEDURE etl.ExtractAirQualityBatch @BatchId uniqueidentifier OUTPUT AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 SET @BatchId=NEWID();
 BEGIN TRY
 BEGIN TRANSACTION;
 INSERT etl.BatchLog(BatchId,SourceName) VALUES (@BatchId,N'hanoi_air_vn.dbo.air_quality_hourly');
 INSERT stg.AirQuality(BatchId,SourceId,StationId,SensorId,StationName,ObservedAtSource,Latitude,Longitude,PollutantCode,Unit,Value)
 SELECT @BatchId,id,location_id,sensor_id,location_name,observed_at,latitude,longitude,parameter,unit,value
 FROM hanoi_air_vn.dbo.air_quality_hourly
 WHERE LOWER(LTRIM(RTRIM(parameter))) IN (N'pm25',N'pm10');
 EXEC etl.ClassifyAirQualityBatch @BatchId=@BatchId;
 COMMIT TRANSACTION;
 SELECT @BatchId AS BatchId;
 END TRY
 BEGIN CATCH
 IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
 THROW;
 END CATCH
END;
GO
