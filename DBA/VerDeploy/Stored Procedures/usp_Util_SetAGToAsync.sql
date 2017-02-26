-- =============================================
-- Author:      Sharon Rimer
-- Create date: 19/02/2017
-- Update date: 
-- Description: Set Always on availability groups to Async
-- =============================================
CREATE PROCEDURE [VerDeploy].[usp_Util_SetAGToAsync]
	@DatabaseName sysname = NULL,
	@IsAGChangeToASync BIT OUTPUT
WITH EXECUTE AS CALLER
AS 
BEGIN  
    SET NOCOUNT ON;
	
    DECLARE @error NVARCHAR(2048);
	DECLARE @Async NVARCHAR(MAX) = N'';

	SELECT  @Async += IIF(drs.synchronization_state = 2,'ALTER AVAILABILITY GROUP ' + QUOTENAME(ag.name) + ' MODIFY REPLICA ON N''' + ar.replica_server_name + ''' WITH (FAILOVER_MODE = MANUAL);
ALTER AVAILABILITY GROUP ' + QUOTENAME(ag.name) + ' MODIFY REPLICA ON N''' + ar.replica_server_name + ''' WITH (AVAILABILITY_MODE = ASYNCHRONOUS_COMMIT);','') 
	FROM    sys.dm_hadr_database_replica_states AS drs
			INNER JOIN sys.availability_databases_cluster AS adc ON drs.group_id = adc.group_id
																  AND drs.group_database_id = adc.group_database_id
			INNER JOIN sys.availability_groups AS ag ON ag.group_id = drs.group_id
			INNER JOIN sys.availability_replicas AS ar ON drs.group_id = ar.group_id
														  AND drs.replica_id = ar.replica_id
	WHERE	adc.database_name = @DatabaseName
	ORDER BY ag.name ,
			ar.replica_server_name ,
			adc.database_name;

	IF LEN(@Async) > 10
	BEGIN
		BEGIN TRY
			EXEC sp_executesql @Async;
	    SET @IsAGChangeToASync = 1;
		END TRY
		BEGIN CATCH
			SELECT @error = CONCAT(OBJECT_SCHEMA_NAME(@@PROCID) + '.' + OBJECT_NAME(@@PROCID),' :: ',ERROR_MESSAGE());
		
			RAISERROR(@error,16,1);
			RETURN -1;
			
		END CATCH
	END
	ELSE
	BEGIN
	    SET @IsAGChangeToASync = 0;
	END
END