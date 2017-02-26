-- =============================================
-- Author:      Sharon Rimer
-- Create date: 15/02/2017
-- Update date: 
-- Description: Map network drive
-- =============================================
CREATE PROCEDURE [VerDeploy].[usp_Util_MapNetworkDrive]
	@MapPath NVARCHAR(255) = NULL,--Network Path
	@Path NVARCHAR(255) OUTPUT
WITH EXECUTE AS OWNER
AS 
BEGIN  
    SET NOCOUNT ON;

	DECLARE @sql NVARCHAR(MAX);
	DECLARE @error NVARCHAR(2048);
	-- Location of the files to run    
    DECLARE @DeviceName CHAR(2) = NULL;
    --creating a temporary table for xp_cmdshell output
    DECLARE @output TABLE (line VARCHAR(255) );
	
	IF EXISTS(SELECT TOP 1 1 FROM sys.configurations WHERE name = 'xp_cmdshell' AND value_in_use = 0)
	BEGIN
		SET @error = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID) + ' :: Turn on xp_cmdshell.';
		RAISERROR (@error,16,1);
	    RETURN -1;
	END
	IF @MapPath IS NOT NULL AND RIGHT(@MapPath,1) = '\' SET @MapPath = LEFT(@MapPath,LEN(@MapPath)-1) ;
	BEGIN TRY
		--inserting unused drive letter 
		INSERT  @output
		EXEC master.sys.xp_cmdshell 'powershell.exe -c "[char[]](68..90)|?{@(gwmi win32_LogicalDisk|%{($_.deviceid)[0]}) -notcontains $_}"';
	END TRY
	BEGIN CATCH
		SET @error = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID) + ' :: ' + ERROR_MESSAGE();
		RAISERROR (@error,16,1);
	    RETURN -1;		
	END CATCH

    SELECT TOP 1
            @DeviceName = RIGHT(line, 1) + ':'
    FROM    @output
    WHERE   line IS NOT NULL;

    SELECT @DeviceName = ISNULL(@DeviceName,'v:');
	
    DECLARE @cmdMap NVARCHAR(255) = 'net use ' + @DeviceName + ' "' + @MapPath + '"';
	
	BEGIN TRY
		EXEC master.sys.xp_cmdshell @cmdMap, no_output;
	END TRY
	BEGIN CATCH
		SET @error = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID) + ' :: ' + ERROR_MESSAGE();
		RAISERROR (@error,16,1);
	    RETURN -1;		
	END CATCH

	SELECT @Path = @DeviceName + '\' ;
END