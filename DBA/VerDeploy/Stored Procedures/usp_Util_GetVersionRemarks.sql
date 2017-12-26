-- =============================================
-- Author:      Sharon Rimer
-- Create date: 19/02/2017
-- Update date: 12/11/2017 Sharon Rimer Fix wildchars.
--										Add WHERE   ISNULL(line_number,'') <> '' AND line_contents LIKE '%---%' ORDER BY line_number ASC;
--				26/11/2017 Sharon Rimer TOP 1 for each line
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
	DECLARE @FirstLine NVARCHAR(MAX) 

    SET @new_line = CHAR(13) + CHAR(10);

	BEGIN TRY
		INSERT  @file_contents EXEC master.dbo.xp_cmdshell @cmd;
	END TRY
	BEGIN CATCH
		SET @error = OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID) + ' :: ' + ERROR_MESSAGE();
		RAISERROR (@error,16,1);
	    RETURN -1;		
	END CATCH    

    SELECT  TOP 1 @Version = CL.NewLine,@FirstLine = line_contents
    FROM    @file_contents
            CROSS APPLY (SELECT LTRIM(RTRIM(REPLACE(SUBSTRING(line_contents,CHARINDEX('--- Script for version ',line_contents) + LEN('--- Script for version '),LEN(line_contents)),
                                        '---', ''))) NewLine
                        ) CL
    WHERE   ISNULL(line_number,'') <> ''
			AND line_contents LIKE '%---%'
	ORDER BY line_number ASC;

    SELECT  TOP 1 @VersionRemarks = CL.NewLine
    FROM    @file_contents
            CROSS APPLY (SELECT LTRIM(RTRIM(REPLACE(SUBSTRING(line_contents,CHARINDEX('---',line_contents) + LEN('---'),LEN(line_contents)-3),
			 ' ---',''))) NewLine
                        ) CL
    WHERE   @FirstLine != line_contents
			AND line_contents LIKE '%---%'
	ORDER BY line_number ASC;


	--SELECT 'usp_Util_GetVersionRemarks',@Version [@Version] , @VersionRemarks [@VersionRemarks]



END;