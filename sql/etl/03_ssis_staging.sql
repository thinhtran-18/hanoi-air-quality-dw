
-- Hop dong SSIS: Data Flow nap staging truoc; process chi phan loai/nap, KHONG trich xuat lai.
USE hanoi_air_dw;
GO
-- Ket qua 1 dong de SSIS map vao bien String User::BatchId.
CREATE OR ALTER PROCEDURE etl.usp_StartSSISBatch AS
BEGIN
 SET NOCOUNT ON;
 DECLARE @b uniqueidentifier;
 EXEC etl.usp_StartBatch @b OUTPUT;
 SELECT CONVERT(varchar(36),@b) AS BatchId;
END;
GO
CREATE OR ALTER PROCEDURE etl.usp_ValidateExistingStage @BatchId uniqueidentifier AS
BEGIN
 SET NOCOUNT ON;
 IF @@TRANCOUNT=0 OR APPLOCK_MODE('public','hanoi_air_dw_etl','Transaction')<>'Exclusive'
   THROW 51501,'Phai goi qua usp_ProcessStagedBatch.',1;
 EXEC etl.ClassifyAirQualityBatch @BatchId=@BatchId;
 IF EXISTS (SELECT 1 FROM stg.vAirQualityClassified WHERE BatchId=@BatchId AND Classification='CONFLICT')
   THROW 51502,'Xung dot grain trong batch; dung nap.',1;
 IF EXISTS (SELECT StationId FROM stg.vAirQualityClassified WHERE BatchId=@BatchId AND Classification='ACCEPTED'
  GROUP BY StationId HAVING COUNT(DISTINCT CONCAT(NameNormalized,N'|',COALESCE(CONVERT(nvarchar(50),Latitude),N'<NULL>'),N'|',COALESCE(CONVERT(nvarchar(50),Longitude),N'<NULL>')))>1)
   THROW 51503,'Metadata tram khong nhat quan.',1;
 IF EXISTS (SELECT SensorId FROM stg.vAirQualityClassified WHERE BatchId=@BatchId AND Classification='ACCEPTED'
  GROUP BY SensorId HAVING COUNT(DISTINCT StationId)>1 OR COUNT(DISTINCT CodeNormalized)>1)
   THROW 51504,'Cam bien gan nhieu tram hoac chat.',1;
END;
GO
CREATE OR ALTER PROCEDURE etl.usp_ProcessStagedBatch @BatchId uniqueidentifier AS
BEGIN
 SET NOCOUNT ON; SET XACT_ABORT ON;
 IF @@TRANCOUNT<>0 THROW 51505,'Khong goi trong transaction ben ngoai.',1;
 BEGIN TRY
  BEGIN TRANSACTION;
  DECLARE @lockresult int, @rows bigint;
  EXEC @lockresult=sys.sp_getapplock @Resource='hanoi_air_dw_etl',@LockMode='Exclusive',@LockOwner='Transaction',@LockTimeout=0;
  IF @lockresult<0 THROW 51506,'ETL khac dang chay hoac khong lay duoc khoa.',1;
  SELECT @rows=COUNT_BIG(*) FROM stg.AirQuality WITH (TABLOCKX,HOLDLOCK);
  EXEC etl.usp_ValidateExistingStage @BatchId;
  EXEC etl.usp_LoadDimensions @BatchId;
  EXEC etl.usp_LoadFact @BatchId;
  EXEC etl.usp_FinishBatch @BatchId;
  COMMIT TRANSACTION;
 END TRY
 BEGIN CATCH
  DECLARE @error nvarchar(2048)=ERROR_MESSAGE();
  IF @@TRANCOUNT>0 ROLLBACK TRANSACTION;
  UPDATE etl.BatchLog SET Status='Failed',FinishedAtUTC=SYSUTCDATETIME(),ErrorMessage=@error WHERE BatchId=@BatchId AND Status='Running';
  THROW;
 END CATCH;
 SELECT BatchId,Status,ExtractedRows,InsertedRows,ExistingRows,RejectedRows,DuplicateRows,ExcludedRows,ConflictRows FROM etl.BatchLog WHERE BatchId=@BatchId;
END;
GO
-- Danh dau that bai neu Data Flow that bai TRUOC khi ProcessStagedBatch duoc goi.
CREATE OR ALTER PROCEDURE etl.usp_FailStagedBatch @BatchId uniqueidentifier, @Reason nvarchar(2048) AS
BEGIN
 SET NOCOUNT ON;
 IF @@TRANCOUNT<>0 THROW 51507,'Ghi loi phai chay ngoai transaction.',1;
 UPDATE etl.BatchLog SET Status='Failed',FinishedAtUTC=SYSUTCDATETIME(),ErrorMessage=LEFT(COALESCE(NULLIF(@Reason,N''),N'SSIS Data Flow failed'),2048)
 WHERE BatchId=@BatchId AND Status='Running';
END;
GO
