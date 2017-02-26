-- =============================================
-- Author:		 Sharon Rimer
-- Create date: 22/02/2017
-- Description: Send Mail
-- =============================================
CREATE PROCEDURE [VerDeploy].[usp_SendMail]
	@RunGUID UNIQUEIDENTIFIER = NULL,
	@MailRecipiants NVARCHAR(255) = 'sharonr@boltinc.com'
WITH EXECUTE AS CALLER
AS 
BEGIN
	SET NOCOUNT ON;

    DECLARE @MailSubject NVARCHAR(255) = N'Version Deployment';
    DECLARE @MailProfile sysname;
	SELECT TOP 1 @MailProfile = name FROM msdb.dbo.sysmail_profile;
    DECLARE @MailBodey NVARCHAR(MAX);
    DECLARE @MailTable NVARCHAR(MAX);
	
	SELECT	@MailTable = CONCAT(
   'Running on Server : ',@@SERVERNAME,'
<br>Start at		  : ',CONVERT(VARCHAR(25),RSL.RunDateTime,113),'
<br><br>',RSL.Line,Sc.[Text],fSc.[Text],'
<br>Scripts path	  : ',RSL.FileName,'
<br>Total runtime	  : ',RSL.DurationInSec,' seconds.<br>',db.Line)
	FROM	[VerDeploy].RunScriptLog RSL
			OUTER APPLY (SELECT TOP 1 iDB.Line FROM [VerDeploy].RunScriptLog iDB WHERE iDB.RunGUID = @RunGUID AND iDB.Line LIKE 'Database %')db
			OUTER APPLY (SELECT CONCAT('<br><font style="color:#41A317;">&nbsp;&nbsp;&nbsp;',COUNT_BIG(1),' files run successfully.</font>')Text FROM [VerDeploy].RunScriptLog iDB WHERE iDB.RunGUID = @RunGUID AND iDB.Line = 'Exec file.' AND iDB.Error IS NULL)Sc
			OUTER APPLY (SELECT CONCAT('<br><font style="color:#990012;">&nbsp;&nbsp;&nbsp;',COUNT_BIG(1),' files failed running.</font>')Text FROM [VerDeploy].RunScriptLog iDB WHERE iDB.RunGUID = @RunGUID AND iDB.Line = 'Exec file.' AND iDB.Error IS NOT NULL)fSc
	WHERE	RSL.RunGUID = @RunGUID
			AND RSL.Line LIKE 'Running %';

              SET @MailTable += '<br>
<table class="sample">
<tr>
       <td style="background-color:#E6E6E6; color:#2E64FE; font-weight:bolder;font-size:14px;">File Name</td>
       <td style="background-color:#E6E6E6; color:#2E64FE; font-weight:bolder;font-size:14px;">Version</td>
       <td style="background-color:#E6E6E6; color:#2E64FE; font-weight:bolder;font-size:14px;">Version Remarks</td>
       <td style="background-color:#E6E6E6; color:#2E64FE; font-weight:bolder;font-size:14px;">Error</td>
       <td style="background-color:#E6E6E6; color:#2E64FE; font-weight:bolder;font-size:14px;">Duration</td>
</tr>';



	SELECT	@MailTable += CONCAT('<tr><td><B>',RSL.FileName ,
			'</B></td><td>',TFF.Version,
			'</td><td>',TFF.VersionRemarks ,
			'</td><td style="color:#990012;">',RSL.Error ,
			'</td><td>',RSL.DurationInSec ,'</td></tr>')
	FROM	[VerDeploy].RunScriptLog RSL
			LEFT JOIN [VerDeploy].TextFromAFile TFF ON TFF.RunGUID = RSL.RunGUID
				AND TFF.FileName = RSL.FileName
	WHERE	RSL.RunGUID = @RunGUID
			AND RSL.Line = 'Exec file.';

    SET @MailTable += '
</table>'

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


	EXEC msdb.dbo.sp_send_dbmail 
		@profile_name = @MailProfile,
		@recipients = @MailRecipiants, 
		@subject = @MailSubject,
		@body = @MailBodey, 
		@body_format = HTML,
		@exclude_query_output = 1;
END