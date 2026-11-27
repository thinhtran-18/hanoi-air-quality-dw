-- Buoc 10: chi doc; xem tung result set trong SSMS.
USE hanoi_air_dw;
GO
SELECT COUNT_BIG(*) AS SoFact FROM dbo.FactAirQuality;
SELECT s.StationName,p.PollutantCode, d.YearNumber,d.MonthNumber,COUNT_BIG(*) AS SoPhepDo, MIN(f.Value) AS GiaTriNhoNhat,MAX(f.Value) AS GiaTriLonNhat
FROM dbo.FactAirQuality f JOIN dbo.DimStation s ON f.StationKey=s.StationKey JOIN dbo.DimPollutant p ON f.PollutantKey=p.PollutantKey JOIN dbo.DimDate d ON f.DateKey=d.DateKey
GROUP BY s.StationName,p.PollutantCode,d.YearNumber,d.MonthNumber ORDER BY s.StationName,p.PollutantCode,d.YearNumber,d.MonthNumber;
SELECT COUNT_BIG(*) AS SoFactMoCoi FROM dbo.FactAirQuality f
LEFT JOIN dbo.DimStation s ON s.StationKey=f.StationKey LEFT JOIN dbo.DimSensor se ON se.SensorKey=f.SensorKey LEFT JOIN dbo.DimPollutant p ON p.PollutantKey=f.PollutantKey LEFT JOIN dbo.DimDate d ON d.DateKey=f.DateKey LEFT JOIN dbo.DimTime t ON t.TimeKey=f.TimeKey LEFT JOIN etl.BatchLog b ON b.BatchId=f.BatchId
WHERE s.StationKey IS NULL OR se.SensorKey IS NULL OR p.PollutantKey IS NULL OR d.DateKey IS NULL OR t.TimeKey IS NULL OR b.BatchId IS NULL;
SELECT StationKey,SensorKey,ObservedAtUTC,PollutantKey,COUNT_BIG(*) AS SoDong FROM dbo.FactAirQuality GROUP BY StationKey,SensorKey,ObservedAtUTC,PollutantKey HAVING COUNT_BIG(*)>1;
SELECT COUNT_BIG(*) AS SoDongKhacNguon FROM dbo.FactAirQuality f LEFT JOIN hanoi_air_vn.dbo.air_quality_hourly a ON a.id=f.SourceId LEFT JOIN dbo.DimStation s ON s.StationKey=f.StationKey LEFT JOIN dbo.DimSensor se ON se.SensorKey=f.SensorKey LEFT JOIN dbo.DimPollutant p ON p.PollutantKey=f.PollutantKey WHERE a.id IS NULL OR a.location_id<>s.StationId OR a.sensor_id<>se.SensorId OR LOWER(LTRIM(RTRIM(a.parameter)))<>p.PollutantCode OR a.value<>f.Value OR a.observed_at<>f.ObservedAtSource;
SELECT TOP (20) f.SourceId,s.StationName,p.PollutantCode,f.ObservedAtSource,f.ObservedAtUTC,f.ObservedAtLocal,f.DateKey,f.Value FROM dbo.FactAirQuality f JOIN dbo.DimStation s ON s.StationKey=f.StationKey JOIN dbo.DimPollutant p ON p.PollutantKey=f.PollutantKey WHERE DATEPART(hour,f.ObservedAtLocal) IN (0,23) ORDER BY f.ObservedAtLocal;
SELECT TOP (10) BatchId,StartedAtUTC,Status,ExtractedRows,InsertedRows,ExistingRows,RejectedRows,DuplicateRows,ExcludedRows,ConflictRows,ErrorMessage FROM etl.BatchLog ORDER BY StartedAtUTC DESC;
