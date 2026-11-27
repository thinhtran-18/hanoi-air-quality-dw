USE hanoi_air_dw;
GO
SET NOCOUNT ON;
WITH src AS (SELECT * FROM hanoi_air_vn.dbo.air_quality_hourly WHERE LOWER(LTRIM(RTRIM(parameter))) IN (N'pm25',N'pm10'))
SELECT COUNT_BIG(*) AS TongNguonPM,COUNT_BIG(f.SourceId) AS CoFact, SUM(CASE WHEN f.SourceId IS NULL THEN 1 ELSE 0 END) AS ThieuFact FROM src a LEFT JOIN dbo.FactAirQuality f ON f.SourceId=a.id;
SELECT COUNT_BIG(*) AS SaiThoiGian FROM dbo.FactAirQuality f WHERE f.ObservedAtUTC<>CAST(SWITCHOFFSET(f.ObservedAtSource,'+00:00') AS datetime2(0)) OR f.ObservedAtLocal<>SWITCHOFFSET(f.ObservedAtSource,'+07:00') OR f.DateKey<>CONVERT(int,CONVERT(char(8),SWITCHOFFSET(f.ObservedAtSource,'+07:00'),112));
SELECT s.StationName,p.PollutantCode,COUNT_BIG(*) AS SoFact,MIN(f.Value) AS MinFact,MAX(f.Value) AS MaxFact,MIN(a.value) AS MinNguon,MAX(a.value) AS MaxNguon FROM dbo.FactAirQuality f JOIN hanoi_air_vn.dbo.air_quality_hourly a ON a.id=f.SourceId JOIN dbo.DimStation s ON s.StationKey=f.StationKey JOIN dbo.DimPollutant p ON p.PollutantKey=f.PollutantKey GROUP BY s.StationName,p.PollutantCode;
WITH m AS (SELECT s.StationName,p.PollutantCode,f.SourceId,f.ObservedAtSource,f.ObservedAtUTC,f.ObservedAtLocal,f.DateKey,f.Value,a.value AS GiaTriNguon,ROW_NUMBER() OVER(PARTITION BY s.StationKey,p.PollutantKey ORDER BY f.ObservedAtLocal) AS rn FROM dbo.FactAirQuality f JOIN hanoi_air_vn.dbo.air_quality_hourly a ON a.id=f.SourceId JOIN dbo.DimStation s ON s.StationKey=f.StationKey JOIN dbo.DimPollutant p ON p.PollutantKey=f.PollutantKey)
SELECT * FROM m WHERE rn=1 ORDER BY StationName,PollutantCode;
SELECT COUNT_BIG(*) AS BatchSuccessSaiCanDoi FROM etl.BatchLog WHERE Status='Success' AND (ExtractedRows<>InsertedRows+ExistingRows+RejectedRows+DuplicateRows+ExcludedRows OR ConflictRows<>0);
GO
