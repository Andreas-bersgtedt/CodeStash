CREATE PROC [ME_Config].[sp_GENERATE_DynamicRMDBS_discoverSQL] AS
BEGIN
  SELECT SQLQuery     = [ME_Config].[fnGetConfigurationSQLQuery](C.[Connectiontype], C.[Id]),
         DataSetType  = C.Connectiontype, 
         DBServerName = C.[ConnectionString],
         DBName       = C.[ConnectionName],
         SQLKVName    = C.[ConnectionKVSecret],
         SqlUserName  = C.[ConnetionUserName],
         DLContainer  = 'metadata',
         DLFolder     = 'me_config_dataset',
         DLFileName   = LOWER(CONCAT(C.[ConnectionName], '_', C.[ConnectionKVSecret]))
    FROM [ME_Config].[Connection] C
   Where C.[id] not in (SELECT [ConnectionId] From [ME_Config].[DataSet]) and
         C.[Connectiontype] IN ('MSSQL','MYSQL','AzMYSQL', 'ORACLE')
END