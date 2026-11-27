-- Staging giu du lieu go kieu, cho phep dong loi/trung de ETL phan loai.
-- Timestamp staging (7) giu ca phan giay de ETL phat hien truoc khi nap fact (0).
USE [hanoi_air_dw];
GO
IF DB_NAME() <> N'hanoi_air_dw'
    THROW 51000, 'Sai database dich; dung trien khai.', 1;
SET XACT_ABORT ON;
BEGIN TRY
    BEGIN TRANSACTION;
    IF OBJECT_ID(N'etl.BatchLog', N'U') IS NULL
    BEGIN
        CREATE TABLE etl.BatchLog (
            BatchId uniqueidentifier NOT NULL CONSTRAINT PK_BatchLog PRIMARY KEY,
            StartedAtUTC datetime2(7) NOT NULL CONSTRAINT DF_BatchLog_Started DEFAULT SYSUTCDATETIME(),
            FinishedAtUTC datetime2(7) NULL,
            Status nvarchar(12) NOT NULL CONSTRAINT DF_BatchLog_Status DEFAULT N'Running',
            SourceName nvarchar(160) NOT NULL,
            SourceSHA256 varchar(64) NULL,
            ExtractedRows bigint NOT NULL CONSTRAINT DF_BatchLog_Extracted DEFAULT 0,
            InsertedRows bigint NOT NULL CONSTRAINT DF_BatchLog_Inserted DEFAULT 0,
            ExistingRows bigint NOT NULL CONSTRAINT DF_BatchLog_Existing DEFAULT 0,
            RejectedRows bigint NOT NULL CONSTRAINT DF_BatchLog_Rejected DEFAULT 0,
            DuplicateRows bigint NOT NULL CONSTRAINT DF_BatchLog_Duplicate DEFAULT 0,
            ExcludedRows bigint NOT NULL CONSTRAINT DF_BatchLog_Excluded DEFAULT 0,
            ConflictRows bigint NOT NULL CONSTRAINT DF_BatchLog_Conflict DEFAULT 0,
            MetadataUpdatesJSON nvarchar(max) NULL,
            ErrorMessage nvarchar(2048) NULL,
            CONSTRAINT CK_BatchLog_Status CHECK (Status IN (N'Running', N'Success', N'Failed')),
            CONSTRAINT CK_BatchLog_Time CHECK (
                (Status = N'Running' AND FinishedAtUTC IS NULL)
                OR (Status IN (N'Success', N'Failed') AND FinishedAtUTC IS NOT NULL AND FinishedAtUTC >= StartedAtUTC)),
            CONSTRAINT CK_BatchLog_Counts CHECK (
                ExtractedRows >= 0 AND InsertedRows >= 0 AND ExistingRows >= 0
                AND RejectedRows >= 0 AND DuplicateRows >= 0 AND ExcludedRows >= 0 AND ConflictRows >= 0),
            CONSTRAINT CK_BatchLog_SuccessBalance CHECK (
                Status <> N'Success' OR (ConflictRows = 0
                AND ExtractedRows = InsertedRows + ExistingRows + RejectedRows + DuplicateRows + ExcludedRows)),
            CONSTRAINT CK_BatchLog_SourceName CHECK (LEN(LTRIM(RTRIM(SourceName))) > 0),
            CONSTRAINT CK_BatchLog_SHA256 CHECK (SourceSHA256 IS NULL OR
                (LEN(SourceSHA256) = 64 AND SourceSHA256 COLLATE Latin1_General_100_BIN2 NOT LIKE '%[^0-9a-fA-F]%')),
            CONSTRAINT CK_BatchLog_MetadataJSON CHECK (MetadataUpdatesJSON IS NULL OR ISJSON(MetadataUpdatesJSON) = 1)
        );
    END;
    IF OBJECT_ID(N'stg.AirQuality', N'U') IS NULL
    BEGIN
        CREATE TABLE stg.AirQuality (
            StageRowId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_StageAirQuality PRIMARY KEY,
            BatchId uniqueidentifier NOT NULL,
            SourceId bigint NOT NULL,
            StationId int NULL,
            SensorId int NULL,
            StationName nvarchar(160) NULL,
            ObservedAtSource datetimeoffset(7) NULL,
            Latitude decimal(10,6) NULL,
            Longitude decimal(10,6) NULL,
            PollutantCode nvarchar(20) NULL,
            Unit nvarchar(40) NULL,
            Value float(53) NULL,
            ExtractedAtUTC datetime2(7) NOT NULL CONSTRAINT DF_StageAirQuality_Extracted DEFAULT SYSUTCDATETIME(),
            CONSTRAINT FK_StageAirQuality_Batch FOREIGN KEY (BatchId) REFERENCES etl.BatchLog(BatchId)
        );
        CREATE INDEX IX_StageAirQuality_BatchSource ON stg.AirQuality(BatchId, SourceId);
    END;
    IF OBJECT_ID(N'etl.RejectRow', N'U') IS NULL
    BEGIN
        CREATE TABLE etl.RejectRow (
            RejectId bigint IDENTITY(1,1) NOT NULL CONSTRAINT PK_RejectRow PRIMARY KEY,
            BatchId uniqueidentifier NOT NULL,
            SourceId bigint NULL,
            StageRowId bigint NULL,
            ReasonCode nvarchar(50) NOT NULL,
            ReasonDetail nvarchar(1000) NOT NULL,
            RawPayload nvarchar(max) NULL,
            RejectedAtUTC datetime2(7) NOT NULL CONSTRAINT DF_RejectRow_Rejected DEFAULT SYSUTCDATETIME(),
            CONSTRAINT FK_RejectRow_Batch FOREIGN KEY (BatchId) REFERENCES etl.BatchLog(BatchId),
            CONSTRAINT CK_RejectRow_Reason CHECK (LEN(LTRIM(RTRIM(ReasonCode))) > 0 AND LEN(LTRIM(RTRIM(ReasonDetail))) > 0),
            CONSTRAINT CK_RejectRow_SourceId CHECK (SourceId IS NULL OR SourceId > 0),
            CONSTRAINT CK_RejectRow_StageRowId CHECK (StageRowId IS NULL OR StageRowId > 0),
            CONSTRAINT CK_RejectRow_PayloadJSON CHECK (RawPayload IS NULL OR ISJSON(RawPayload) = 1)
        );
        CREATE INDEX IX_RejectRow_BatchSource ON etl.RejectRow(BatchId, SourceId) INCLUDE (ReasonCode);
    END;
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
    THROW;
END CATCH;
PRINT N'02: staging va log/reject san sang; chua trich xuat hay nap phep do.';
GO
