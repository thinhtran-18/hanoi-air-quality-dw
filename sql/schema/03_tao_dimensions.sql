-- Nam dimension, dung 27 cot theo tu dien Star buoc 5.
USE [hanoi_air_dw];
GO
IF DB_NAME() <> N'hanoi_air_dw'
    THROW 51000, 'Sai database dich; dung trien khai.', 1;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF OBJECT_ID(N'dbo.DimDate', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.DimDate (
            DateKey int NOT NULL CONSTRAINT PK_DimDate PRIMARY KEY,
            FullDate date NOT NULL CONSTRAINT UQ_DimDate_FullDate UNIQUE,
            DayOfMonth tinyint NOT NULL,
            MonthNumber tinyint NOT NULL,
            QuarterNumber tinyint NOT NULL,
            YearNumber smallint NOT NULL,
            DayOfWeekISO tinyint NOT NULL,
            DayName nvarchar(12) NOT NULL,
            CONSTRAINT CK_DimDate_Scope CHECK (FullDate >= CONVERT(date,'20240101',112) AND FullDate < CONVERT(date,'20250101',112)),
            CONSTRAINT CK_DimDate_Calendar CHECK (
                DateKey = CONVERT(int,CONVERT(char(8),FullDate,112))
                AND DayOfMonth = DAY(FullDate) AND MonthNumber = MONTH(FullDate)
                AND QuarterNumber = DATEPART(quarter,FullDate) AND YearNumber = YEAR(FullDate)
                AND DayOfWeekISO = DATEDIFF(day,CONVERT(date,'19000101',112),FullDate) % 7 + 1
                AND DayName = CASE DayOfWeekISO WHEN 1 THEN N'Thứ Hai' WHEN 2 THEN N'Thứ Ba'
                    WHEN 3 THEN N'Thứ Tư' WHEN 4 THEN N'Thứ Năm' WHEN 5 THEN N'Thứ Sáu'
                    WHEN 6 THEN N'Thứ Bảy' WHEN 7 THEN N'Chủ Nhật' END)
        );
    END;
    IF OBJECT_ID(N'dbo.DimTime', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.DimTime (
            TimeKey int NOT NULL CONSTRAINT PK_DimTime PRIMARY KEY,
            FullTime time(0) NOT NULL CONSTRAINT UQ_DimTime_FullTime UNIQUE,
            HourNumber tinyint NOT NULL,
            MinuteNumber tinyint NOT NULL,
            SecondNumber tinyint NOT NULL,
            CONSTRAINT CK_DimTime_Clock CHECK (
                HourNumber = DATEPART(hour,FullTime) AND MinuteNumber = DATEPART(minute,FullTime)
                AND SecondNumber = DATEPART(second,FullTime)
                AND TimeKey = HourNumber * 10000 + MinuteNumber * 100 + SecondNumber),
            CONSTRAINT CK_DimTime_Hourly CHECK (MinuteNumber = 0 AND SecondNumber = 0)
        );
    END;
    IF OBJECT_ID(N'dbo.DimStation', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.DimStation (
            StationKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimStation PRIMARY KEY,
            StationId int NOT NULL CONSTRAINT UQ_DimStation_StationId UNIQUE,
            StationName nvarchar(160) NOT NULL,
            Latitude decimal(10,6) NULL,
            Longitude decimal(10,6) NULL,
            CityName nvarchar(80) NOT NULL,
            DistrictName nvarchar(80) NULL,
            CONSTRAINT CK_DimStation_Scope CHECK (StationId IN (2161299,2161301) AND CityName = N'Hà Nội'),
            CONSTRAINT CK_DimStation_Name CHECK (LEN(LTRIM(RTRIM(StationName))) > 0),
            CONSTRAINT CK_DimStation_Coordinates CHECK (Latitude BETWEEN -90 AND 90 AND Longitude BETWEEN -180 AND 180),
            CONSTRAINT CK_DimStation_District CHECK (DistrictName IS NULL OR LEN(LTRIM(RTRIM(DistrictName))) > 0)
        );
    END;
    IF OBJECT_ID(N'dbo.DimPollutant', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.DimPollutant (
            PollutantKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimPollutant PRIMARY KEY,
            PollutantCode nvarchar(20) NOT NULL CONSTRAINT UQ_DimPollutant_Code UNIQUE,
            PollutantName nvarchar(40) NOT NULL,
            Unit nvarchar(40) NOT NULL,
            CONSTRAINT CK_DimPollutant_Domain CHECK (
                PollutantCode COLLATE Latin1_General_100_BIN2 IN (N'pm25',N'pm10')
                AND PollutantName = CASE PollutantCode WHEN N'pm25' THEN N'PM2.5' WHEN N'pm10' THEN N'PM10' END
                AND Unit COLLATE Latin1_General_100_BIN2 = N'µg/m³')
        );
    END;
    IF OBJECT_ID(N'dbo.DimSensor', N'U') IS NULL
    BEGIN
        CREATE TABLE dbo.DimSensor (
            SensorKey int IDENTITY(1,1) NOT NULL CONSTRAINT PK_DimSensor PRIMARY KEY,
            SensorId int NOT NULL CONSTRAINT UQ_DimSensor_SensorId UNIQUE,
            SensorDescription nvarchar(255) NULL,
            CONSTRAINT CK_DimSensor_Id CHECK (SensorId > 0)
        );
    END;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
PRINT N'03: nam dimension san sang; chua nap metadata tram/chat/cam bien.';
GO
