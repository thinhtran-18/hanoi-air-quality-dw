USE hanoi_air_dw;
GO
-- Dice: đổi các biến theo nhu cầu; thời gian local; trả dòng fact và SourceId để truy vết.
DECLARE @from date='2024-01-01',@to date='2025-01-01',@station int=2161299,@pollutant nvarchar(20)=N'pm25';
SELECT d.FullDate,t.FullTime,s.StationName,p.PollutantCode,p.Unit,f.SensorKey,f.ObservedAtSource,f.ObservedAtUTC,f.Value,f.SourceId,f.BatchId FROM dbo.FactAirQuality f JOIN dbo.DimDate d ON d.DateKey=f.DateKey JOIN dbo.DimTime t ON t.TimeKey=f.TimeKey JOIN dbo.DimStation s ON s.StationKey=f.StationKey JOIN dbo.DimPollutant p ON p.PollutantKey=f.PollutantKey WHERE f.IsValid=1 AND f.Value IS NOT NULL AND d.FullDate>=@from AND d.FullDate<@to AND s.StationId=@station AND p.PollutantCode=@pollutant ORDER BY d.FullDate,t.FullTime,f.SensorKey;
GO
