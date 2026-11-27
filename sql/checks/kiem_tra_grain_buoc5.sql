-- Buoc 5: chi doc nguon; khong tao/nap bang kho.
USE [hanoi_air_vn];
GO
SET NOCOUNT ON;
;WITH Scope AS (
 SELECT *, SWITCHOFFSET(observed_at, '+00:00') AS utc_at
 FROM dbo.air_quality_hourly
 WHERE location_id IN (2161299,2161301) AND parameter IN (N'pm25',N'pm10')
 AND SWITCHOFFSET(observed_at,'+07:00') >= CAST('2024-01-01T00:00:00+07:00' AS datetimeoffset)
 AND SWITCHOFFSET(observed_at,'+07:00') < CAST('2025-01-01T00:00:00+07:00' AS datetimeoffset)
)
SELECT COUNT_BIG(*) AS ScopeRows, COUNT(DISTINCT location_id) AS Stations,
 COUNT(DISTINCT sensor_id) AS Sensors, COUNT(DISTINCT parameter) AS Pollutants FROM Scope;

SELECT COUNT_BIG(*) AS DuplicateGroups, COALESCE(SUM(n-1),0) AS DuplicateExtraRows
FROM (
 SELECT COUNT_BIG(*) AS n FROM dbo.air_quality_hourly
 WHERE location_id IN (2161299,2161301) AND parameter IN (N'pm25',N'pm10')
 AND YEAR(SWITCHOFFSET(observed_at,'+07:00'))=2024
 GROUP BY location_id,sensor_id,CAST(SWITCHOFFSET(observed_at,'+00:00') AS datetime2(0)),parameter
 HAVING COUNT_BIG(*)>1
) AS D;

SELECT location_id,sensor_id,parameter,observed_at,
 CAST(SWITCHOFFSET(observed_at,'+00:00') AS datetime2(0)) AS ObservedAtUTC,value
FROM dbo.air_quality_hourly
WHERE parameter IN (N'pm25',N'pm10')
 AND observed_at=CAST('2024-01-29T14:00:00+07:00' AS datetimeoffset)
ORDER BY location_id,parameter;

SELECT TOP(1) observed_at AS ObservedAtSource,
 CAST(SWITCHOFFSET(observed_at,'+00:00') AS datetime2(0)) AS ObservedAtUTC,
 SWITCHOFFSET(observed_at,'+07:00') AS ObservedAtLocal,
 CONVERT(int,CONVERT(char(8),SWITCHOFFSET(observed_at,'+07:00'),112)) AS DateKey,
 0 AS TimeKey
FROM dbo.air_quality_hourly
WHERE parameter IN (N'pm25',N'pm10')
 AND DATEPART(hour,SWITCHOFFSET(observed_at,'+07:00'))=0
ORDER BY observed_at,id;
