CREATE PROC [ME_Data].[sp_GetRawPartitionCurationMetadata] @PartGroup [int],@MaxPartGroup [int] AS
BEGIN
SELECT * FROM(
  Select TOP 1000000000000 RawPartitionStageID= R.ID,
  blob_account_name = LOWER(G.AttributeValue),
  blob_container_name=LOWER(E.targetLake),
  blob_relative_path=LOWER(REPLACE(E.LAKEFOLDER,'\','/')+'/'+R.partition_string+'/*.parquet'),
  target_db = LOWER(C.[BusinessDataDomainName]) ,
  target_path=lower('/delta/'+C.[BusinessDataDomainName]+'/'),
  target_container = LOWER(CZ.AttributeValue),
  target_table = LOWER(e.schemaname+'_'+e.name),
  partition_by_clause = CASE WHEN PK.Value IS NULL THEN ' ' ELSE ' PARTITIONED BY ('+PK.Value+') ' END,
  target_bk = ISNULL(BK.Value,' '),
  target_type = UPPER(CASE	WHEN TT.Value IS NOT NULL 
						THEN TT.Value 
						ELSE	CASE WHEN BK.Value IS NULL 
								THEN 'D' 
								ELSE 'I' END
						END),
  PartGroupID=(R.ID % @MaxPartGroup)+1


  from [Metadata].[Entity] E
  INNER JOIN [ME_Config].[DataSet] D ON E.DataSetID=D.ID
  INNER JOIN [ME_Config].[Connection] C ON D.ConnectionID=C.ID
  INNER JOIN [ME_Stage].[RawPartitionStage] R ON E.DataSetID=R.DataSetID
  INNER JOIN [ME_Config].[GLOBALS] G on 1=1 and g.attribute='STORAGE_ACCOUNT'
  INNER JOIN [ME_Config].[GLOBALS] CZ on 1=1 and cz.attribute='CURATED_ZONE_NAME'
  LEFT OUTER JOIN [Metadata].[Attribute] BK ON  E.DataSetID=BK.DataSetID and BK.[KEY]='EntityBusinessKey'
  LEFT OUTER JOIN [Metadata].[Attribute] PK ON  E.DataSetID=PK.DataSetID and PK.[KEY]='EntityPartitionKey'
  LEFT OUTER JOIN [Metadata].[Attribute] TT ON  E.DataSetID=TT.DataSetID and TT.[KEY]='EntityRawDataLoadType'
WHERE Status=0 
ORDER BY R.InsertTimestamp
  ) AS X WHERE PartGroupID=@PartGroup or @PartGroup = -999



  
  




END