-- =============================================
-- Author:      Sharon Rimer
-- Create date: 15/02/2017
-- Update date: 
-- Description: UnMap network drive
-- =============================================
CREATE PROCEDURE [VerDeploy].[usp_Util_UnMapNetworkDrive]
	@Path NVARCHAR(255) = NULL
WITH EXECUTE AS OWNER
AS 
BEGIN  
    SET NOCOUNT ON;
	DECLARE @DeviceName CHAR(2);
	DECLARE @error NVARCHAR(2048);
	SET @DeviceName = LEFT(@Path,2);
    --creating a temporary table for xp_cmdshell output
    DECLARE @output TABLE (line VARCHAR(255));
	
	IF EXISTS(SELECT TOP 1 1 FROM sys.configurations WHERE name = 'xp_cmdshell' AND value_in_use = 0)
	BEGIN
		SET @error = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID) + ' :: Turn on xp_cmdshell.';
		RAISERROR (@error,16,1);
	    RETURN -1;
	END
	
    DECLARE @cmdMap NVARCHAR(255) = 'net use ' + @DeviceName + ' /DELETE';
	
	BEGIN TRY
		EXEC master.sys.xp_cmdshell @cmdMap, no_output;
	END TRY
	BEGIN CATCH
		SET @error = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID) + ' :: ' + ERROR_MESSAGE();
		RAISERROR (@error,16,1);
	    RETURN -1;		
	END CATCH
END