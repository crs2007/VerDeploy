-- =============================================
-- Author:		Sharon Rimer
-- Create date: 15/02/2017
-- Description:	check if root folder exists
-- =============================================
CREATE PROCEDURE [VerDeploy].[usp_Util_CheckFolderExists]
	@Path NVARCHAR(255) = NULL
WITH EXECUTE AS CALLER
AS 
BEGIN
	SET NOCOUNT ON;
	
    DECLARE @error NVARCHAR(2048);
    --creating a temporary table for xp_cmdshell output
    DECLARE @output TABLE (line VARCHAR(255) );
	-- check if root folder exists
    DECLARE @dir VARCHAR(255) = 'dir /b ' + '"' + @Path + '"'; 
	BEGIN TRY
		INSERT  @output EXEC master.sys.xp_cmdshell @dir;
	END TRY
	BEGIN CATCH
		SELECT @error = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID),' :: ',ERROR_MESSAGE());
		
        RAISERROR(@error,16,1);
        RETURN -1;
	END CATCH
    

    IF EXISTS ( SELECT TOP 1 1 FROM @output WHERE [line] = N'The system cannot find the path specified.' )
		RETURN 0;
	RETURN 1;

END