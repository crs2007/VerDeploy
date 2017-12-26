-- =============================================
-- Author:		Sharon Rimer
-- Create date: 15/02/2017
-- Description:	RunScriptFromFileTable
-- =============================================
CREATE PROCEDURE [VerDeploy].[usp_Util_INNER_RunScriptFromFileTable]
	@RunGUID UNIQUEIDENTIFIER,
	@FileName VARCHAR(2000),
	@Database sysname,
    @debug BIT = 0 
WITH EXECUTE AS CALLER
AS 
BEGIN
	SET NOCOUNT ON;
	
    DECLARE @error NVARCHAR(2048);
    DECLARE @sql NVARCHAR(MAX);
    DECLARE @OrigianlSQL NVARCHAR(MAX);
	DECLARE @Duration INT;
	DECLARE @CRLF NVARCHAR(10) = N'
'
	DECLARE @rc INT;
	DECLARE @ID INT = 1;
	DECLARE @ScriptTable TABLE ([ID] [int] NOT NULL IDENTITY(1,1),Script NVARCHAR(MAX) NULL);
	DECLARE @ErrorOut TABLE (Error NVARCHAR(MAX));
    DECLARE @trancount int;
	DECLARE @xstate int;
    SET @trancount = @@trancount;

	INSERT	@ScriptTable
	SELECT	[Match]
	FROM    [VerDeploy].[TextFromAFile]
			CROSS APPLY [dbo].[RegExSplit]('\b+GO\b+',Script,1)
	WHERE   [RunGUID] = @RunGUID
			AND [FileName] = @FileName;
	SET @rc = @@ROWCOUNT;

	WHILE @rc > 0 AND @ID <= @rc
	BEGIN
		SELECT	@OrigianlSQL = Script,
				@sql = REPLACE(Script,'''','''''')
		FROM	@ScriptTable
		WHERE	ID = @ID;
		SET @ID = @ID + 1;
		SET @sql = CONCAT(N'USE ',QUOTENAME(@Database),';',@CRLF,@sql);
		
		IF @sql LIKE '%BEGIN TRAN%'
		BEGIN
			BEGIN TRY
				IF @debug = 1
				BEGIN
					PRINT '---------------------------Without Complisite Tran-----------------------------------------';
					PRINT @sql;
					PRINT '-------------------------------------------------------------------------------------------';
				END
				EXEC sp_executesql @sql;
			END TRY
			BEGIN CATCH
				SELECT @error = ERROR_MESSAGE();
				IF @debug = 1 
				BEGIN
					PRINT '-------------------------- Error ---------------------------'
					PRINT @error;
				END
				IF ERROR_NUMBER() = 111
				BEGIN
				    BEGIN TRY
						IF @debug = 1
						BEGIN
							PRINT '---------------------Without Complisite Tran (ERROR_NUMBER() = 111) -----------------------------------';
							PRINT '------------------------EXEC usp_clr_ExecuteByDotNet --------------------------------------------------';

						END
						DELETE FROM @ErrorOut;
						INSERT INTO @ErrorOut
						EXEC [VerDeploy].[usp_clr_ExecuteByDotNet] @@SERVERNAME,@Database,NULL,NULL,@OrigianlSQL,0,@Duration OUT;
						IF EXISTS(SELECT TOP 1 1 FROM @ErrorOut)
						BEGIN
							SET @error = N'usp_clr_ExecuteByDotNet :: ';
							SELECT	@error += CONCAT(Error,@CRLF)
							FROM	@ErrorOut;
							IF @debug = 1
							BEGIN
								PRINT '---------------Without Complisite Tran (ERROR_NUMBER() = 111-->> Error was found) -----------------------------';
								PRINT @error;
							END
							RAISERROR (@error,16,1);
						END
				    END TRY
				    BEGIN CATCH
						SELECT @error = ERROR_MESSAGE();
						RAISERROR(@error,16,1);
						RETURN -1; 
				    END CATCH
				END
				ELSE
                BEGIN
					RAISERROR(@error,16,1);
					RETURN -1;                    
                END
			END CATCH
		END
		ELSE
		BEGIN
			BEGIN TRY
				IF @trancount = 0
					BEGIN TRANSACTION
				ELSE
					SAVE TRANSACTION RunScriptFromFileTable;
					SET @sql = REPLACE(@sql,'''''','''');
					IF @debug = 1
					BEGIN
						PRINT '---------------------------With Complisite Tran--------------------------------------------';
						PRINT @sql;
						PRINT '-------------------------------------------------------------------------------------------';
					END
				EXEC sp_executesql @sql;
				
				IF @trancount = 0  COMMIT TRANSACTION
			END TRY
			BEGIN CATCH
				SELECT	@error = ERROR_MESSAGE(),
						@xstate = XACT_STATE();
				IF @debug = 1 
				BEGIN
					PRINT '-------------------------- Error ---------------------------'
					PRINT @error;
				END
				IF @xstate = -1
					ROLLBACK;
				IF @xstate = 1 and @trancount = 0
					ROLLBACK
				IF @xstate = 1 and @trancount > 0
					ROLLBACK TRANSACTION RunScriptFromFileTable;

				IF ERROR_NUMBER() = 111
				BEGIN
				    BEGIN TRY
						IF @debug = 1
						BEGIN
							PRINT '---------------------With Complisite Tran (ERROR_NUMBER() = 111) -----------------------------------';
							PRINT '------------------------EXEC usp_clr_ExecuteByDotNet --------------------------------------------------';
						END
						DELETE FROM @ErrorOut;
						INSERT INTO @ErrorOut
						EXEC [VerDeploy].[usp_clr_ExecuteByDotNet] @@SERVERNAME,@Database,NULL,NULL,@OrigianlSQL,0,@Duration OUT;
						IF EXISTS(SELECT TOP 1 1 FROM @ErrorOut)
						BEGIN
							SET @error = N'usp_clr_ExecuteByDotNet :: ';
							SELECT	@error += CONCAT(Error,@CRLF)
							FROM	@ErrorOut;
							IF @debug = 1
							BEGIN
								PRINT '---------------With Complisite Tran (ERROR_NUMBER() = 111-->> Error was found) -----------------------------';
								PRINT @error;
							END
							RAISERROR (@error,16,1);
						END
				    END TRY
				    BEGIN CATCH
						SELECT @error = ERROR_MESSAGE();
						RAISERROR(@error,16,1);
						RETURN -1; 
				    END CATCH
				END
				ELSE
                BEGIN
					RAISERROR(@error,16,1);
					RETURN -1;                    
                END
			END CATCH
		END
	
	END
	
END