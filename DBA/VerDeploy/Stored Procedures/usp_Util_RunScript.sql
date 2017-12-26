-- =============================================
-- Author:		Sharon Rimer
-- Create date: 19/02/2017
--				15/11/2017 Sharon Rimer Add @Database to error logger.
--				03/12/2017 Sharon Rimer Change error message.
-- Description:	Run Script Within transaction
-- =============================================
CREATE PROCEDURE [VerDeploy].[usp_Util_RunScript]
	@RunGUID UNIQUEIDENTIFIER,
	@FileName VARCHAR(2000),
	@Database sysname = NULL,
	@Version NVARCHAR(50) = NULL,
    @VersionRemarks NVARCHAR(MAX) = null,
    @debug BIT = 0 
WITH EXECUTE AS CALLER
AS 
BEGIN
	SET NOCOUNT ON;
	SET QUOTED_IDENTIFIER ON;
	SET ANSI_WARNINGS ON;
	SET ANSI_PADDING ON;
	SET ANSI_NULLS ON;
	SET XACT_ABORT ON;
    DECLARE @error NVARCHAR(2048);
    DECLARE @cmd NVARCHAR(MAX);
	DECLARE @ErrMsg nvarchar(4000), @ErrSeverity int
    DECLARE @trancount int;
	DECLARE @xstate int;
    SET @trancount = @@trancount;
	
	--- Check if the script is executed on our database (BEGIN) ---
	IF  OBJECT_ID(CONCAT(@Database + N'.',N'dbo.DatabaseVersion'),'U') IS NULL
	BEGIN
		SET @error = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID),' :: ','The table [dbo].[DatabaseVersion] does not exists in "',@Database,'" database you are running this script on, please check the database !');
		
        RAISERROR(@error,10,1);
		INSERT  [VerDeploy].RunScriptLog ( [RunGUID] , [Line] ,RunDateTime,[Error],[Database] )   SELECT  @RunGUID ,@error ,GETDATE(),@error,ISNULL(@Database,'');
		SET @cmd = CONCAT('USE ',@Database,';',CHAR(13),'CREATE TABLE [dbo].[DatabaseVersion](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Version] [nvarchar](50) NULL,
	[Remarks] [nvarchar](max) NULL,
	[ChangeDate] [datetime] NULL CONSTRAINT [DF_t_DatabaseVersion_VER_TimeStamp]  DEFAULT (getdate()),
 CONSTRAINT [PK_DatabaseVersion] PRIMARY KEY CLUSTERED 
(
	[Id] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY];');
		EXECUTE sp_executesql @cmd;



	END
	--- Check if the script is executed on our database (END) ---
	--- Change Database Version (BEGIN) ---
	BEGIN TRY
		IF @trancount = 0
			BEGIN TRANSACTION
		ELSE
			SAVE TRANSACTION usp_Util_RunScript1;
			
			SET @cmd = CONCAT('INSERT ',@Database,'.[dbo].[DatabaseVersion] (Version, Remarks) Values (@Version,  @VersionRemarks);');
			IF @debug = 1
			BEGIN
				PRINT @cmd;
				SELECT @Version [@Version] , @VersionRemarks [@VersionRemarks]
			END
			EXECUTE sp_executesql @cmd, N'@Version NVARCHAR(50),@VersionRemarks NVARCHAR(MAX)',@Version = @Version , @VersionRemarks = @VersionRemarks;
		IF @trancount = 0  COMMIT TRANSACTION
	END TRY
	BEGIN CATCH
		SET  @xstate = XACT_STATE();
		IF @xstate = -1
			ROLLBACK;
		IF @xstate = 1 and @trancount = 0
			ROLLBACK
		IF @xstate = 1 and @trancount > 0
			ROLLBACK TRANSACTION usp_Util_RunScript1;
		SET @ErrSeverity = ERROR_SEVERITY()
		SET @ErrMsg = CONCAT('Version ',@Version,' probably already exists in ',@Database,'.[dbo].[DatabaseVersion]');--,char(13),CHAR(10),'Message: ' + ERROR_MESSAGE();
		RAISERROR(@ErrMsg, @ErrSeverity, 1);
		RETURN -1;
	END CATCH
	--- Change Database Version (END) ---

	SET @error = N'';
	BEGIN TRY
		SET @error = CONCAT('Running Script ',@FileName,' On ',@Database,'.');
		RAISERROR(@error, 10, 1) WITH NOWAIT;
		EXEC [VerDeploy].[usp_Util_INNER_RunScriptFromFileTable] @RunGUID,@FileName,@Database,@debug;
	END TRY
	BEGIN CATCH
		SET  @xstate = XACT_STATE();
		SELECT  @error = ERROR_MESSAGE();
		IF @@TRANCOUNT > 0 ROLLBACK;

		SET @cmd = CONCAT('DELETE FROM ',@Database,'.[dbo].[DatabaseVersion] WHERE [Version] = @Version AND Remarks = @VersionRemarks;');
		EXECUTE sp_executesql @cmd, N'@Version NVARCHAR(50),@VersionRemarks NVARCHAR(MAX)',@Version = @Version , @VersionRemarks = @VersionRemarks;
		
		RAISERROR(@error, 16, 1)
		RETURN -1;
	END CATCH

	WHILE @@TRANCOUNT > 0 COMMIT 


	SET @error = CONCAT('Script ',@FileName,' completed successfully on "',@Database,'".');
	RAISERROR(@error, 10, 1) WITH NOWAIT;

END