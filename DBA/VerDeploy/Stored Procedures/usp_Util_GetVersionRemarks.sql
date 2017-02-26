-- =============================================
-- Author:      Sharon Rimer
-- Create date: 19/02/2017
-- Update date: 
-- Description: Extract 2 lines from script as Version and VersionRemarks.
-- =============================================
CREATE PROCEDURE [VerDeploy].[usp_Util_GetVersionRemarks]
	@Path NVARCHAR(255) = NULL,
    @VersionRemarks NVARCHAR(MAX) OUTPUT,
    @Version NVARCHAR(50) OUTPUT
WITH EXECUTE AS CALLER
AS
BEGIN  
    SET NOCOUNT ON;
	
    DECLARE @error NVARCHAR(2048);
	DECLARE @cmd VARCHAR(4000);
	SET @cmd = CONCAT('type "',@Path,'"')
    DECLARE @file_contents TABLE 
    (
     line_number INT IDENTITY ,
     line_contents NVARCHAR(4000)
    );

    DECLARE @new_line CHAR(2);

    SET @new_line = CHAR(13) + CHAR(10);

	BEGIN TRY
		INSERT  @file_contents EXEC master.dbo.xp_cmdshell @cmd;
	END TRY
	BEGIN CATCH
		SET @error = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID) + ' :: ' + ERROR_MESSAGE();
		RAISERROR (@error,16,1);
	    RETURN -1;		
	END CATCH
    

    SELECT  @Version = CL.NewLine
    FROM    @file_contents
            CROSS APPLY (SELECT REPLACE(SUBSTRING(line_contents,
                                                  LEN('--- Script for version ')
                                                  + 2, LEN(line_contents)),
                                        ' ---', '') NewLine
                        ) CL
    WHERE   line_number = 1;

    SELECT  @VersionRemarks = CL.NewLine
    FROM    @file_contents
            CROSS APPLY (SELECT REPLACE(SUBSTRING(line_contents,
                                                  LEN('--- ') + 1,
                                                  LEN(line_contents)), ' ---',
                                        '') NewLine
                        ) CL
    WHERE   line_number = 2;

END;