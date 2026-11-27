-- Fact dung 13 cot theo tu dien; UNIQUE theo grain, khong theo BatchId/Value.
USE [hanoi_air_dw];
GO
IF DB_NAME() <> N'hanoi_air_dw'
    THROW 51000, 'Sai database dich; dung trien khai.', 1;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF OBJECT_ID(N'dbo.FactAirQuality', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.FactAirQuality (
            AirQualityKey bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_FactAirQuality PRIMARY KEY,
            DateKey int NOT NULL,
            TimeKey int NOT NULL,
            StationKey int NOT NULL,
            PollutantKey int NOT NULL,
            SensorKey int NOT NULL,
            ObservedAtSource datetimeoffset(0) NOT NULL,
            ObservedAtUTC datetime2(0) NOT NULL,
            ObservedAtLocal datetimeoffset(0) NOT NULL,
            Value float(53) NULL,
            IsValid bit NOT NULL,
            SourceId bigint NOT NULL,
            BatchId uniqueidentifier NOT NULL,
            CONSTRAINT UQ_FactAirQuality_Grain UNIQUE (StationKey, SensorKey, ObservedAtUTC, PollutantKey),
            CONSTRAINT FK_FactAirQuality_Date FOREIGN KEY (DateKey) REFERENCES dbo.DimDate(DateKey),
            CONSTRAINT FK_FactAirQuality_Time FOREIGN KEY (TimeKey) REFERENCES dbo.DimTime(TimeKey),
            CONSTRAINT FK_FactAirQuality_Station FOREIGN KEY (StationKey) REFERENCES dbo.DimStation(StationKey),
            CONSTRAINT FK_FactAirQuality_Pollutant FOREIGN KEY (PollutantKey) REFERENCES dbo.DimPollutant(PollutantKey),
            CONSTRAINT FK_FactAirQuality_Sensor FOREIGN KEY (SensorKey) REFERENCES dbo.DimSensor(SensorKey),
            CONSTRAINT FK_FactAirQuality_Batch FOREIGN KEY (BatchId) REFERENCES etl.BatchLog(BatchId),
            CONSTRAINT CK_FactAirQuality_TimeZone CHECK (DATEPART(tzoffset,ObservedAtLocal) = 420),
            CONSTRAINT CK_FactAirQuality_Instant CHECK (
                ObservedAtUTC = CAST(SWITCHOFFSET(ObservedAtSource,'+00:00') AS datetime2(0))
                AND ObservedAtLocal = ObservedAtSource),
            CONSTRAINT CK_FactAirQuality_LocalKeys CHECK (
                DateKey = CONVERT(int,CONVERT(char(8),ObservedAtLocal,112))
                AND TimeKey = DATEPART(hour,ObservedAtLocal) * 10000
                    + DATEPART(minute,ObservedAtLocal) * 100 + DATEPART(second,ObservedAtLocal)),
            CONSTRAINT CK_FactAirQuality_Validity CHECK (
                (IsValid = 1 AND Value IS NOT NULL AND Value >= 0)
                OR (IsValid = 0 AND (Value IS NULL OR Value < 0))),
            CONSTRAINT CK_FactAirQuality_SourceId CHECK (SourceId > 0)
        );
        CREATE INDEX IX_FactAirQuality_DateStationPollutant
            ON dbo.FactAirQuality(DateKey, StationKey, PollutantKey)
            INCLUDE (TimeKey, Value, IsValid);
        CREATE INDEX IX_FactAirQuality_SourceId ON dbo.FactAirQuality(SourceId);
    END;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
PRINT N'04: fact va rang buoc san sang; chua nap phep do.';
GO
