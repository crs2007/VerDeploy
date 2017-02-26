# Version Deploy
Version Deploy is a set of scripts by Rimer Sharon.
All SQL script that you would like to run on databases, should be at a path that the SQL Server can retch to.
If you are working with TFS, SVN, Git or any other CI.
Please make sure that you can build a solution that can get all desired file into your path (local or network).

### Prerequisite
1.	[Database Mail](https://msdn.microsoft.com/en-us/library/hh245116.aspx)
2.	[CLR Integration](https://msdn.microsoft.com/en-us/library/ms131048.aspx)

### Installation
Installation should be a snap, just build this project as-is and deploy it on your SQL Server.

### Security Configuration
Make sure you have system administrator privilege on the SQL server instance.

### Projects in Use
[CLR Assembly RegEx Functions for SQL Server](https://www.simple-talk.com/sql/t-sql-programming/clr-assembly-regex-functions-for-sql-server-by-example) by Phil Factor ([t](https://twitter.com/Phil_Factor)|[b](https://www.simple-talk.com/author/phil-factor))

### License
Version Deploy is licensed under the [MIT License](http://opensource.org/licenses/MIT).

## How to use this solution
### How etch SQL script file should look like?
Every script should have 2 line of comments. Etch line should start and end with triple (-).
The first line supposed to be the version mark and look like this
```sql
 --- Script for version ____________ ---
```
The second line will be for the script remark: 
```sql
--- ________________________ ---
```
Both 2 lines will stored in user table - [VerDeploy].TextFromAFile, this will be showed in the summery mail at the end of the run.

### Batch Separator-
Hard Coded –“GO”  
Etch script is disassemble to several parts depends on the “batch separator” count.  
Etch batch will run separately.   
TODO – In the future the “Batch Separator” will be configure by the user.

### CLR Integration – 
This solution is working with 2 assemblies.
1. CLR_Util – Assembly that Contains usp_clr_ExecuteByDotNet - clr Stored Procedure that run script and catch if there is any errors to a table. The main use is to run scripts that get error 111. That’s in the case of create\alter a new View\SP\UFN\etc...
2. RegexFunction - Assembly that Contains RegExSplit - clr Table valued function that can separate text into several rows by regular excretion https://en.wikipedia.org/wiki/Regular_expression syntax.
This assembly has been created by Phil Factor ([t] (https://twitter.com/Phil_Factor)| [b] (https://www.simple-talk.com/author/phil-factor)). 
[More info] ()https://www.simple-talk.com/sql/t-sql-programming/clr-assembly-regex-functions-for-sql-server-by-example)

### Schema Information

1.	**VerDeploy.usp_Setup_RunScripts**(Stored Procedure)– Main Procedure
#### Parameters:
	@DatabaseName (sysname)	    -- The Database name that you want to run your scrupt on.
	@ScriptPath (NVARCHAR(255))	-- Optional Local Path (Group 1 – At list one).
	@MapPath (NVARCHAR(255)) 	-- Optional Network Path(Group 1 – At list one).
	@debug (BIT)			    -- Print Info massages.
	@IsAllFolder (BIT) 	        -- Run all scripts within the specified folder and sub folders.
	@MailRecipiants (NVARCHAR(255)) -- Mailing addresss to send results.
2.	**VerDeploy.usp_Util_SetAGToAsync**(Stored Procedure)- Set Always on availability groups to Asynchronous
	If you are planning to run some scripts that will create indexes or will change indexes, the best practice is to change availability groups to asynchronous.
	Recommendations for Index Maintenance with [AlwaysOn Availability Groups](https://blogs.msdn.microsoft.com/alwaysonpro/2015/03/03/recommendations-for-index-maintenance-with-alwayson-availability-groups)
3.	**VerDeploy.usp_Util_SetAGToSync**(Stored Procedure)- Set Always on availability groups to Synchronous.
4.	**VerDeploy.usp_Util_GetVersionRemarks**(Stored Procedure)- Get 2 First lines (comments) from etch SQL script and stored it in VerDeploy.TextFromAFile(USER_TABLE).
5.	**VerDeploy.usp_Util_RunScript**(Stored Procedure)-Run Script Within transaction
	1.	**VerDeploy.usp_Util_INNER_RunScriptFromFileTable**(Stored Procedure)- 
		1.	**VerDeploy.usp_clr_ExecuteByDotNet**(CLR Stored Procedure)
		2.	**RegExSplit**(CLR – Function)
6.	**VerDeploy.usp_SendMail**(Stored Procedure)-Send summery mail to recipient.
7.	**VerDeploy.usp_Util_MapNetworkDrive**(Stored Procedure)- Map network drive in case that the SQL script are located in network shred path.
8.	**VerDeploy.usp_Util_UnMapNetworkDrive**(Stored Procedure)- UnMap network drive if a drive have been mapped before.
9.	**VerDeploy.usp_Util_CheckFolderExists**(Stored Procedure)- Check if root folder exists. 
10.	**VerDeploy.StoredConfigServerData**(USER_TABLE) – Save sp_configure state.
11.	**VerDeploy.TextFromAFile**(USER_TABLE)- Stored texts from SQL file.
12.	**VerDeploy.RunScriptLog**(USER_TABLE)- Stored log events for etch run.