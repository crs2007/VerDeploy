-- =============================================
-- Author:      Sharon Rimer
-- Create date: 15/02/2017
-- Update date: 18/10/2017 Sharon Rimer @Environment as posability to ignored
--				12/11/2017 Sharon Rimer Add to [VerDeploy].[RunScriptLog] [Database] column
--										Fix UTF-8 with BOM. into UTF-8 without BOM. https://stackoverflow.com/questions/18845976/whats-%C3%AF-sign-at-the-beginning-of-my-source-file
--				15/11/2017 Sharon Rimer Add @RunningScript.
--				06/12/2017 Sharon Rimer Add SET @Print = CONCAT(@FileName,' run successfully.');
--				10/12/2017 Sharon Rimer Remove @Environment (Amit will deal on the PowerShell)
-- Description: Run Script on DB 
--              1. From Net falder by PowerShell.(@MapPath)
--              2. From local falder. (@ScriptPath)
-- =============================================
CREATE PROCEDURE [VerDeploy].[usp_Setup_RunScripts]
    @DatabaseName sysname ,
    @ScriptPath NVARCHAR(255) ,--Local Path
    @MapPath NVARCHAR(255) ,--Network Path
    @debug BIT = 0 ,
    @IsAllFolder BIT = 0 ,
    @MailRecipients NVARCHAR(255) = ''
WITH EXECUTE AS CALLER
AS
BEGIN  
    SET NOCOUNT ON;

	DECLARE @RunningScript NVARCHAR(max);
	SELECT @RunningScript = CONCAT(N'
--Server:: ',@@SERVERNAME,'(',TRY_CONVERT(sysname,SERVERPROPERTY('MachineName')),') | Host Name: ',HOST_NAME(),'
DECLARE @DatabaseName sysname = ''',ISNULL(@DatabaseName,'NULL'),''';
DECLARE @ScriptPath nvarchar(255) = ''',ISNULL(@ScriptPath,'NULL'),''';
DECLARE @MapPath nvarchar(255) = ''',ISNULL(@MapPath,'NULL'),''';
DECLARE @debug BIT = ',ISNULL(@debug,'NULL'),';
DECLARE @IsAllFolder BIT = ',ISNULL(@IsAllFolder,'NULL'),';
DECLARE @MailRecipients nvarchar(255) = ''',ISNULL(@MailRecipients,'NULL'),''';

EXECUTE [DBA].[VerDeploy].[usp_Setup_RunScripts] 
   @DatabaseName
  ,@ScriptPath
  ,@MapPath
  ,@debug
  ,@IsAllFolder
  ,@MailRecipients');
    DECLARE @error NVARCHAR(2048);
    DECLARE @Print NVARCHAR(4000);
    DECLARE @sql NVARCHAR(MAX);
	DECLARE @CRLF NVARCHAR(10) = N'
';
    DECLARE @ServerName sysname = @@SERVERNAME;
    DECLARE @RunGUID UNIQUEIDENTIFIER = NEWID();
	DECLARE @IsAGChangeToASync BIT = 0;
	DECLARE @Path VARCHAR(2000);
	DECLARE @VersionRemarks NVARCHAR(MAX) ,
		    @Version NVARCHAR(50);
	DECLARE @FileName VARCHAR(2000);
	DECLARE @Help VARCHAR(4000);
	SET @Help = '
@DatabaseName (sysname)			-- The Database name that you want to run your scrupt on.
@ScriptPath (NVARCHAR(255))		-- Optional Local Path (Group 1 – At list one).
@MapPath (NVARCHAR(255)) 		-- Optional Network Path(Group 1 – At list one).
@debug (BIT)					-- Print Info massages.
@IsAllFolder (BIT)				-- Run all scripts within the specified folder and sub folders.
@MailRecipients (NVARCHAR(255))	-- Mailing addresss to send results.';
	

	SET @Print = CONCAT('Start running with guid - ',@RunGUID);
	RAISERROR (@Print,10,1) WITH NOWAIT;

    IF NOT EXISTS ( SELECT TOP 1 1 FROM sys.databases WHERE [name] COLLATE DATABASE_DEFAULT = @DatabaseName )
    BEGIN
        IF @DatabaseName IS NULL
            SET @error = CONCAT('@DatabaseName have null value.',@CRLF,N'Please provid a database name from the current server - ', @@SERVICENAME);
		INSERT  [VerDeploy].RunScriptLog  ([RunGUID] ,[Line],Error,[Database]) SELECT  @RunGUID , 'Database :',@error,ISNULL(@DatabaseName,'No @DatabaseName input!');
        RAISERROR(@error,16,1);
		PRINT @Help;
        RETURN -1;
    END;
	
    DECLARE @dirOutput TABLE
        (
            subdirectory sysname NULL ,
            depth INT NULL
        );
		 
	IF @ScriptPath IS NOT NULL AND RIGHT(@ScriptPath, 1) != '\'
        SET @ScriptPath = @ScriptPath + N'\';


	--Mail Declaration
    IF CHARINDEX('@', @MailRecipients) = 0
        SELECT  @MailRecipients = '';--TODO::	Build mailing boxs; CONCAT([Jobs].[ufn_Mail_GetMailRecipiantByProcedureName](OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID)), ';' + @AdditionlMailRecipiants);
    
	DECLARE @configData TABLE
        (
            name sysname ,
            minimum INT ,
            maximum INT ,
            config_value INT ,
            run_value INT
        );
    DECLARE @config_value INT;

	-- Location of the files to run    
    DECLARE @DeviceName CHAR(2) = NULL;
	
	--creating a temporary table for xp_cmdshell output
    DECLARE @output TABLE ( line VARCHAR(255) );
	--get xp_cmdshell config data
    INSERT @configData EXEC sp_configure 'xp_cmdshell';

	--change xp_cmdshell if needed
    IF EXISTS ( SELECT TOP 1 1 FROM @configData WHERE   run_value = 0 )
    BEGIN
        IF NOT EXISTS ( SELECT TOP 1 1 FROM [VerDeploy].StoredConfigServerData WHERE [name] = 'xp_cmdshell' )
			INSERT  [VerDeploy].StoredConfigServerData SELECT  * FROM @configData;
        EXEC sp_configure 'xp_cmdshell', 1;
        RECONFIGURE WITH OVERRIDE;
		IF @debug = 1 
		BEGIN
		    SET @Print = 'Turn on xp_cmdshell';
			RAISERROR (@Print,10,1) WITH NOWAIT;
		END
    END;

    IF @ScriptPath IS NULL
    BEGIN --From Net falder. (@MapPath)
        EXEC [VerDeploy].[usp_Util_MapNetworkDrive] @MapPath, @Path OUTPUT;
    END;
    ELSE --From local falder. (@ScriptPath)
    BEGIN
        SELECT  @DeviceName = RIGHT(@ScriptPath, 1) + ':';
        SELECT  @Path = @ScriptPath;
    END;
            
	-- check if root folder exists
    DECLARE @rc INT = 0 ;
	EXEC @rc = [VerDeploy].[usp_Util_CheckFolderExists] @Path;
	
    IF @rc = 0
    BEGIN
		SET @error = N'Root folder dosen''t exists.';
        INSERT  [VerDeploy].RunScriptLog( [RunGUID] ,[Line] ,[FileName],[Error],[Database])
        SELECT  @RunGUID , N'CheckFolderExists', CONCAT(ISNULL(@ScriptPath, @MapPath), @Path), @error,@DatabaseName; 
		SET @error = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID) , '.' , OBJECT_NAME(@@PROCID) , ' :: ',@error);
		RAISERROR (@error, 16, 1);
		GOTO CleanUp;
    END;      

    --Log
    DECLARE @Log_StartDate DATETIME = GETDATE();
    DECLARE @Log_Duration INT = 0;
----------------------------------          Run Scripts         -----------------------------------
    DECLARE @NumberOfFiles INT = 0;
    IF OBJECT_ID('tempdb..#DirTree') IS NOT NULL DROP TABLE #DirTree;
    CREATE TABLE #DirTree
        (
            ID INT IDENTITY(1, 1) ,
            [FileName] NVARCHAR(255) ,
            Depth SMALLINT ,
            FileFlag BIT ,
            [Path] NVARCHAR(255) NULL
        );

    IF OBJECT_ID('tempdb..#Result') IS NOT NULL DROP TABLE #Result;
    CREATE TABLE #Result
        (
            ID INT IDENTITY(1, 1) ,
            line NVARCHAR(255) ,
            [FileName] NVARCHAR(255)
        );

    --Get all files in Location
    DECLARE @subdirectory sysname;
    IF @IsAllFolder = 1/*			Run all scripts within the specified folder and sub folders         */
    BEGIN
                        
        INSERT  @dirOutput EXEC xp_dirtree @Path, 1, 0; -- path, level , dir/file/both (Folders)

        UPDATE  @dirOutput
        SET     subdirectory = CONCAT(IIF(RIGHT(@Path, 1) = '\', @Path, @Path + '\'), subdirectory, '\');
		
		--Clean Cursor
		IF (SELECT CURSOR_STATUS('LOCAL','cSubDirectory')) >= -1
		 BEGIN
		  IF (SELECT CURSOR_STATUS('LOCAL','cSubDirectory')) > -1
		   BEGIN
			CLOSE cSubDirectory;
		   END
		 DEALLOCATE cSubDirectory;
		END
        DECLARE cSubDirectory CURSOR LOCAL FAST_FORWARD READ_ONLY
        FOR
            SELECT  subdirectory
            FROM    @dirOutput
            ORDER BY subdirectory;
                        
        OPEN cSubDirectory;
                        
        FETCH NEXT FROM cSubDirectory INTO @subdirectory;
                        
        WHILE @@FETCH_STATUS = 0
        BEGIN /* cursor logic */
            INSERT  #DirTree ( [FileName] , Depth , FileFlag )
                    EXEC master..xp_dirtree @subdirectory, 1, 1; -- Files

            --Update script file path
            UPDATE  #DirTree
            SET     [Path] = @subdirectory
            WHERE   [Path] IS NULL;

            FETCH NEXT FROM cSubDirectory INTO @subdirectory;
        END;
                        
        CLOSE cSubDirectory;
        DEALLOCATE cSubDirectory;
    END;
            
    /*		Run all scripts from witin the path        */
    INSERT  #DirTree ( FileName, Depth, FileFlag )
            EXEC master..xp_dirtree @Path, 1, 1;

    --Update script file path
    UPDATE  #DirTree
    SET     [Path] = IIF(RIGHT(@Path, 1) = '\', @Path, @Path + '\')
    WHERE   [Path] IS NULL;

	
	SELECT	dt.FileName ,FileFlag,RIGHT(dt.FileName, 4) [Extention],[Path]
	INTO	#FilteredDirTree
	FROM	#DirTree dt

	--Count Only *.sql files
    SELECT  @NumberOfFiles = COUNT(1)
    FROM    #FilteredDirTree
    WHERE   FileFlag = 1
            AND [Extention] = '.sql';
	
	--Prefix:: declare veriable
	DECLARE @FPath VARCHAR(2000);

    IF @NumberOfFiles > 0
    BEGIN
		DECLARE curScriptFile CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
		--Insert text from sql file into [VerDeploy].TextFromAFile, default code page as ASCII (varchar)
		SELECT	CONCAT('INSERT [VerDeploy].TextFromAFile ([RunGUID],[Script],[FileName]) SELECT @RunGUID,BulkColumn,''',[FileName],''' FROM OPENROWSET(BULK N''',[Path],[FileName],''',SINGLE_CLOB)SQLScriptFile;') [Script],CONCAT([Path],[FileName]) [Path],[FileName]
		FROM    #FilteredDirTree
        WHERE   FileFlag = 1
                AND [Extention] = '.sql'
        ORDER BY [Path] ,FileName;
		OPEN curScriptFile
		
		FETCH NEXT FROM curScriptFile INTO @sql,@FPath,@FileName;
		
		WHILE @@FETCH_STATUS = 0
		BEGIN
			IF @debug = 1 
			BEGIN
				SET @Print = @sql;
				RAISERROR (@Print,10,1) WITH NOWAIT;
			END
		    BEGIN TRY
				
				EXEC sys.sp_executesql @sql, N'@RunGUID UNIQUEIDENTIFIER', @RunGUID = @RunGUID;
			END TRY
			BEGIN CATCH
				IF ERROR_NUMBER() = 4806 --SINGLE_CLOB requires a double-byte character set (DBCS) (char) input file. The file specified is Unicode.
				BEGIN
				    SET @sql = REPLACE(@sql,'SINGLE_CLOB','SINGLE_NCLOB');
					IF @debug = 1 
					BEGIN
						SET @Print = @sql;
						RAISERROR (@Print,10,1) WITH NOWAIT;
					END
					EXEC sys.sp_executesql @sql, N'@RunGUID UNIQUEIDENTIFIER', @RunGUID = @RunGUID;
				END
				ELSE
                BEGIN
                    SET @error = ERROR_MESSAGE();
				
					INSERT  [VerDeploy].RunScriptLog( [RunGUID] ,[Line] ,[FileName],[Error],[Database])
					SELECT  @RunGUID , N'Insert script Text into DB', CONCAT(ISNULL(@ScriptPath, @MapPath), @FPath),@error,@DatabaseName ; 
					SET @error = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID) , '.' , OBJECT_NAME(@@PROCID) , ' :: ',@error);
					RAISERROR (@error, 16, 1);
					GOTO CleanUp;
                END
			END CATCH

			IF @debug = 1 
			BEGIN
				SET @Print = 'Start usp_Util_GetVersionRemarks';
				RAISERROR (@Print,10,1) WITH NOWAIT;
			END

			--Fix UTF-8 with BOM. into UTF-8 without BOM.
			UPDATE VerDeploy.TextFromAFile
			SET Script = REPLACE(Script,'ï»¿','')
			WHERE	RunGUID = @RunGUID
					AND Script LIKE '%ï»¿%';

			BEGIN TRY				
				EXEC VerDeploy.usp_Util_GetVersionRemarks @FPath,@VersionRemarks OUTPUT,@Version OUTPUT;
				
				UPDATE	[VerDeploy].TextFromAFile
				SET		VersionRemarks = @VersionRemarks, [Version] = @Version
				WHERE	[FileName] = @FileName
						AND RunGUID = @RunGUID;
			END TRY
			BEGIN CATCH
				SET @error = ERROR_MESSAGE();
				
				INSERT  [VerDeploy].RunScriptLog( [RunGUID] ,[Line] ,[FileName],[Error],[Database])
				SELECT  @RunGUID , N'Update script version Text into DB', CONCAT(ISNULL(@ScriptPath, @MapPath), @FPath),@error,@DatabaseName ; 
				SET @error = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID) , '.' , OBJECT_NAME(@@PROCID) , ' :: ',@error);
				RAISERROR (@error, 16, 1);
				GOTO CleanUp;
			END CATCH
		    FETCH NEXT FROM curScriptFile INTO @sql,@FPath,@FileName;
		END
		
		CLOSE curScriptFile
		DEALLOCATE curScriptFile
	
	----1---
	--Make AG A-Sync
	IF EXISTS (
		SELECT	TOP 1 1
		FROM	[VerDeploy].TextFromAFile
		WHERE	[RunGUID] = @RunGUID
				AND [Script] LIKE '% INDEX %')
	BEGIN
		BEGIN TRY
		
			IF @debug = 1 
			BEGIN
				SET @Print = 'Start usp_Util_SetAGToAsync';
				RAISERROR (@Print,10,1) WITH NOWAIT;
			END
			INSERT  [VerDeploy].RunScriptLog ([RunGUID] ,[Line],RunDateTime,[Database]) SELECT  @RunGUID ,'Set Always On Availability Groups To Async.',GETDATE(),@DatabaseName;
			EXEC [VerDeploy].[usp_Util_SetAGToAsync] @DatabaseName,@IsAGChangeToASync;
			UPDATE [VerDeploy].RunScriptLog SET EndDateTime = GETDATE() WHERE RunGUID = @RunGUID AND Line = 'Set Always On Availability Groups To Async.';
		END TRY
		BEGIN CATCH
			SET @error = ERROR_MESSAGE();
			UPDATE [VerDeploy].RunScriptLog SET EndDateTime = GETDATE(), Error = @error WHERE RunGUID = @RunGUID AND Line = 'Set Always On Availability Groups To Async.';
			SET @error = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID) , '.' , OBJECT_NAME(@@PROCID) , ' :: ',@error);
			RAISERROR (@error, 16, 1);
			GOTO CleanUp;
		END CATCH		
	END
	


	--Log
    INSERT  [VerDeploy].RunScriptLog ( [RunGUID] , [Line] , [FileName],RunDateTime,[Database] )   SELECT  @RunGUID , N'Running ' + CONVERT(NVARCHAR(255), @NumberOfFiles) + N' Files.' , ISNULL(@ScriptPath, @MapPath),GETDATE(),@DatabaseName;
	SET @FileName  = NULL;
	--Clean Cursor
	IF (SELECT CURSOR_STATUS('LOCAL','curRunSQLScript')) >= -1
	 BEGIN
	  IF (SELECT CURSOR_STATUS('LOCAL','curRunSQLScript')) > -1
	   BEGIN
		CLOSE curRunSQLScript
	   END
	 DEALLOCATE curRunSQLScript
	END
	DECLARE curRunSQLScript CURSOR LOCAL FAST_FORWARD READ_ONLY FOR 
	SELECT	[FileName],[Version],VersionRemarks
	FROM	[VerDeploy].TextFromAFile
	WHERE	[RunGUID] = @RunGUID
	ORDER BY [FileName] ASC;
	
	OPEN curRunSQLScript
	
	FETCH NEXT FROM curRunSQLScript INTO @FileName,@Version,@VersionRemarks
	
	WHILE @@FETCH_STATUS = 0
	BEGIN
	    
		BEGIN TRY
		
			IF @debug = 1 
			BEGIN
				SET @Print = CONCAT('Exec file.',@FileName);
				RAISERROR (@Print,10,1) WITH NOWAIT;
			END
			INSERT  [VerDeploy].RunScriptLog ([RunGUID] ,[Line],[FileName],[Database]) SELECT  @RunGUID ,'Exec file.',@FileName,@DatabaseName;
			EXEC [VerDeploy].[usp_Util_RunScript] @RunGUID,@FileName,@DatabaseName,@Version,@VersionRemarks,@debug;
			UPDATE	[VerDeploy].RunScriptLog SET [EndDateTime] = GETDATE() WHERE [RunGUID] = RunGUID AND [Line] = 'Exec file.' AND [FileName] = @FileName;
			SET @Print = CONCAT(@FileName,' run successfully.');
			PRINT @Print;
		END TRY
		BEGIN CATCH	
			SET @error = ERROR_MESSAGE();		
			UPDATE	[VerDeploy].RunScriptLog SET [EndDateTime] = GETDATE(),Error = @error WHERE [RunGUID] = RunGUID AND [Line] = 'Exec file.' AND [FileName] = @FileName;
			SET @error = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID) , '.' , OBJECT_NAME(@@PROCID) , ' :: ',@error);
			RAISERROR (@error, 16, 1);
			GOTO CleanUp;
		END CATCH


	    FETCH NEXT FROM curRunSQLScript INTO @FileName,@Version,@VersionRemarks
	END
	
	CLOSE curRunSQLScript
	DEALLOCATE curRunSQLScript

	UPDATE  [VerDeploy].RunScriptLog SET EndDateTime = GETDATE()WHERE RunGUID =  @RunGUID AND Line  = N'Running ' + CONVERT(NVARCHAR(255), @NumberOfFiles) + N' Files.';

	IF @IsAGChangeToASync = 1
	BEGIN
		IF @debug = 1 
		BEGIN
			SET @Print = 'Start usp_Util_SetAGToSync';
			RAISERROR (@Print,10,1) WITH NOWAIT;
		END
		
		EXEC [VerDeploy].[usp_Util_SetAGToSync] @DatabaseName, @IsAGChangeToASync;
	END

	END
	ELSE --@NumberOfFiles <= 0 -- No Files in Dir.
	BEGIN
		SET @error = N'No Files in Dir.';	
	    INSERT  [VerDeploy].RunScriptLog ([RunGUID] ,[Line],Error,[Database]) SELECT  @RunGUID ,@error,@error,@DatabaseName;
		SET @error = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID) , '.' , OBJECT_NAME(@@PROCID) , ' :: ',@error);
		RAISERROR (@error, 16, 1);
		GOTO CleanUp;
	END

------------------------


CleanUp:
	---------------------------------------------------------------------------------------------------
	-------------------------------------   Drop Temp Tables   ----------------------------------------        
    IF OBJECT_ID('tempdb..#DirTree') IS NOT NULL
        DROP TABLE #DirTree;
	IF OBJECT_ID('tempdb..#FilteredDirTree') IS NOT NULL
        DROP TABLE #FilteredDirTree;
    IF OBJECT_ID('tempdb..#Result') IS NOT NULL
        DROP TABLE #Result;
    ---------------------------------------------------------------------------------------------------
    -------------------------------     DisConnect network drive      ---------------------------------
	IF @ScriptPath IS NULL
    BEGIN --From Net falder. (@MapPath)
            --drop map if needed
        EXEC [VerDeploy].[usp_Util_UnMapNetworkDrive] @Path;
    END;
    ---------------------------------------------------------------------------------------------------
    ------------------------   reset xp_cmdshell to original required state   -------------------------   
	IF @config_value != ( SELECT TOP 1 ISNULL(config_value, 0) FROM @configData )
    BEGIN
        SELECT  @config_value = ISNULL(config_value, 0)
        FROM    @configData;
        EXEC sp_configure 'xp_cmdshell', @config_value;
        RECONFIGURE WITH OVERRIDE;
		DELETE FROM [VerDeploy].StoredConfigServerData WHERE [name] = 'xp_cmdshell';
    END;
	
	UPDATE	[VerDeploy].RunScriptLog SET [EndDateTime] = GETDATE() WHERE [RunGUID] = @RunGUID AND [FileName] = ISNULL(@ScriptPath, @MapPath) AND [Line] LIKE 'Running %';
SendMail:
	EXEC [VerDeploy].[usp_SendMail] @RunGUID,@MailRecipients,@RunningScript,@debug;
END;