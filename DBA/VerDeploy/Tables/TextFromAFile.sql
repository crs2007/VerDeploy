CREATE TABLE [VerDeploy].[TextFromAFile] (
    [RunGUID]        UNIQUEIDENTIFIER NOT NULL,
    [Script]         NVARCHAR (MAX)   NULL,
    [FileName]       VARCHAR (2000)   NULL,
    [VersionRemarks] NVARCHAR (MAX)   NULL,
    [Version]        NVARCHAR (50)    NULL
);


GO
CREATE NONCLUSTERED INDEX [IX_TextFromAFile]
    ON [VerDeploy].[TextFromAFile]([RunGUID] ASC);

