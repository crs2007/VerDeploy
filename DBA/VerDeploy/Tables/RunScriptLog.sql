CREATE TABLE [VerDeploy].[RunScriptLog] (
    [RunGUID]       UNIQUEIDENTIFIER NOT NULL,
    [RunDateTime]   DATETIME         CONSTRAINT [DF_RunScriptLog_RunDateTime] DEFAULT (getdate()) NOT NULL,
    [EndDateTime]   DATETIME         NULL,
    [Line]          NVARCHAR (MAX)   NULL,
    [FileName]      VARCHAR (2000)   NULL,
    [Error]         VARCHAR (MAX)    NULL,
    [DurationInSec] AS               (datediff(second,[RunDateTime],[EndDateTime]))
);

