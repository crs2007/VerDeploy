-- =============================================
-- Author:		Sharon Rimer
-- Create date: 12/11/2017
-- Update date: 
-- Description:	Send Mail
-- =============================================
CREATE PROCEDURE [VerDeploy].[usp_GetLastSummary]
	@Database sysname,
	@MailRecipients NVARCHAR(255) = '',
	@Debug BIT = 0
WITH EXECUTE AS CALLER
AS 
BEGIN
	SET NOCOUNT ON;

	DECLARE @RunGUID UNIQUEIDENTIFIER;
	DECLARE @RC INT= 0;
	SELECT	TOP 1 @RunGUID = RunGUID
	FROM	VerDeploy.RunScriptLog
	WHERE	[Database] = @Database
	ORDER BY RunDateTime DESC;
	SET @RC = @@ROWCOUNT;

    DECLARE @MailSubject NVARCHAR(255) = N'Version Deployment Summary - Last Run';
    DECLARE @MailProfile sysname;
	SELECT TOP 1 @MailProfile = name FROM msdb.dbo.sysmail_profile;
    DECLARE @MailBodey NVARCHAR(MAX);
    DECLARE @MailTable NVARCHAR(MAX);
	DECLARE @IsError BIT = 0;

	IF @RC> 0 
	BEGIN
		SELECT	@MailTable = CONCAT(
   'Running on Server : <strong>',@@SERVERNAME,'</strong>
<br>Database		  : <strong>',RSL.[Database],'</strong>
<br>Start at		  : <strong>',CONVERT(VARCHAR(25),RSL.RunDateTime,113),'</strong>
<br><br>',RSL.Line,Sc.[Text],fSc.[Text],'
<br>Scripts path	  : ',RSL.FileName,'
<br>Total runtime	  : ',RSL.DurationInSec,' seconds.<br>',db.Line)
		FROM	[VerDeploy].RunScriptLog RSL
				OUTER APPLY (SELECT TOP 1 iDB.Line FROM [VerDeploy].RunScriptLog iDB WHERE iDB.RunGUID = @RunGUID AND iDB.Line LIKE 'Database %')db
				OUTER APPLY (SELECT CONCAT('<br><font style="color:#41A317;">&nbsp;&nbsp;&nbsp;',COUNT_BIG(1),' files run successfully.</font>')Text FROM [VerDeploy].RunScriptLog iDB WHERE iDB.RunGUID = @RunGUID AND iDB.Line = 'Exec file.' AND iDB.Error IS NULL)Sc
				OUTER APPLY (SELECT CONCAT('<br><font style="color:#990012;">&nbsp;&nbsp;&nbsp;',COUNT_BIG(1),' files failed running.</font>')Text FROM [VerDeploy].RunScriptLog iDB WHERE iDB.RunGUID = @RunGUID AND iDB.Line = 'Exec file.' AND iDB.Error IS NOT NULL)fSc
		WHERE	RSL.RunGUID = @RunGUID
				AND RSL.Line LIKE 'Running %';

        
		

		IF EXISTS(SELECT TOP 1 1 FROM [VerDeploy].RunScriptLog RSL
				LEFT JOIN [VerDeploy].TextFromAFile TFF ON TFF.RunGUID = RSL.RunGUID
					AND TFF.FileName = RSL.FileName
		WHERE	RSL.RunGUID = @RunGUID
				AND RSL.Line = 'Exec file.'
				AND RSL.Error IS NOT NULL)
		BEGIN
			SET @IsError = 1;	    
		END

		SET @MailTable += '<br>
<table class="sample">
<tr>
       <td style="background-color:#E6E6E6; color:#2E64FE; font-weight:bolder;font-size:14px;">File Name</td>
       <td style="background-color:#E6E6E6; color:#2E64FE; font-weight:bolder;font-size:14px;">Version</td>
       <td style="background-color:#E6E6E6; color:#2E64FE; font-weight:bolder;font-size:14px;">Version Remarks</td>
       ' + IIF(@IsError = 1,'<td style="background-color:#E6E6E6; color:#2E64FE; font-weight:bolder;font-size:14px;">Error</td>','') + '
       <td style="background-color:#E6E6E6; color:#2E64FE; font-weight:bolder;font-size:14px;">Duration</td>
</tr>';



		SELECT	@MailTable += CONCAT('<tr><td><B>',RSL.FileName ,
				'</B></td><td>',TFF.Version,
				'</td><td>',TFF.VersionRemarks ,IIF(@IsError = 1,
			'</td><td style="color:#990012;">' + REPLACE(RSL.Error,CHAR(10),'<br>'),''),
				'</td><td>',[dbo].[ufn_Util_ConvertTimeToHHMMSS](RSL.DurationInSec,'s')  ,'</td></tr>')
		FROM	[VerDeploy].RunScriptLog RSL
				LEFT JOIN [VerDeploy].TextFromAFile TFF ON TFF.RunGUID = RSL.RunGUID
					AND TFF.FileName = RSL.FileName
		WHERE	RSL.RunGUID = @RunGUID
				AND RSL.Line = 'Exec file.';

		SET @MailTable += '
</table>'
END
ELSE
BEGIN
    SET @MailTable = 'No script have been found that runs on that database - ' + ISNULL(@Database,'(N/A)')
END

       SET @MailBodey =
'
<!DOCTYPE html>
<html>
<body>
<style type="text/css">
table.sample {
       font-family:"Segoe UI";
       font-size:small;
       border-width: 1px;
       border-spacing: 0px;
       border-style: solid;
       border-color: gray;
       border-collapse: collapse;
       background-color: white;}
table.sample th {
       border-width: 1px;
       padding: 3px;
       border-style: solid;
       border-color: gray;
       background-color: white;
       }
table.sample td {
       font-family:Calibri;
       font-size:12px;
       border-width: 1px;
       padding: 3px;
       border-style: solid;
       border-color: gray;
       background-color: white;
       }
</style>
<font face="Segoe UI" size="2">
<H1><p style=''font-size:18.0pt;font-family:"Bradley Hand ITC"''>' + @MailSubject + N'</p></H1>
<br/>' + @MailTable  + '<br/>

</font>
</body>
</html>';

	IF @Debug = 1
	BEGIN
	    PRINT CONCAT('@MailRecipients:',@MailRecipients);
		PRINT CONCAT('@MailBodey:',@MailBodey);
	END
	EXEC msdb.dbo.sp_send_dbmail 
		@profile_name = @MailProfile,
		@recipients = @MailRecipients, 
		@subject = @MailSubject,
		@body = @MailBodey, 
		@body_format = HTML,
		@exclude_query_output = 1;
END