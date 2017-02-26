CREATE FUNCTION [dbo].[RegExSplit]
(@Pattern NVARCHAR (4000), @Input NVARCHAR (MAX), @Options INT)
RETURNS 
     TABLE (
        [Match] NVARCHAR (MAX) NULL)
AS
 EXTERNAL NAME [RegexFunction].[SimpleTalk.Phil.Factor.RegularExpressionFunctions].[RegExSplit]

