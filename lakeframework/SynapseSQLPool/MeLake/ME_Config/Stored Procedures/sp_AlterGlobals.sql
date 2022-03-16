﻿CREATE PROC [ME_Config].[sp_AlterGlobals] @STORAGE_ACCOUNT [VARCHAR](4000),@STAGE_SCHEMA [VARCHAR](4000) AS
BEGIN

TRUNCATE TABLE [ME_Config].[GLOBALS]

INSERT INTO [ME_Config].[GLOBALS]
SELECT Attribute='STORAGE_ACCOUNT',AttributeValue=@STORAGE_ACCOUNT
UNION ALL
SELECT Attribute='STAGE_SCHEMA',AttributeValue=@STAGE_SCHEMA
;

DECLARE @SQL VARCHAR(4000)

SET @SQL = 'CREATE SCHEMA ['+@STAGE_SCHEMA+']
    AUTHORIZATION [dbo];'


EXEC (@SQL)




END