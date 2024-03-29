﻿CREATE PROC [ME_Stage].[sp_DynamicStageLoad] @PARTITIONSTRING [VARCHAR](100),@DatasetID [INT] AS
BEGIN
	/*DEBUG
		SET @PARTITIONSTRING='2021/01/07/15/23'
		SET @DatasetID=25
*/
	/*DECLARE GLOBALS*/
	DECLARE @TARGETSCHEMA VARCHAR(100)
		,@STORAGE_ACCOUNT VARCHAR(500)
	
	
	/*SET GLOBAL PARAMETERS*/
	SET @STORAGE_ACCOUNT =(SELECT TOP 1 AttributeValue	FROM ME_Config.GLOBALS WHERE [Attribute]='STORAGE_ACCOUNT')
	SET @TARGETSCHEMA = (SELECT TOP 1 AttributeValue	FROM ME_Config.GLOBALS WHERE [Attribute]='STAGE_SCHEMA')

	/*DECLARE LOCAL PARAMETERS*/
	DECLARE @SQLCREATESTAGETABLE VARCHAR(MAX);
	DECLARE @SQLCOPYINTO VARCHAR(MAX);
	DECLARE @SQLSCHEMACREATE VARCHAR(MAX);
	DECLARE @SourceConnnectionName VARCHAR(250)
	

	/*Get Source Database / Connection Name for use in target table name*/
	SET @SourceConnnectionName = (
			SELECT TOP 1 [ConnectionName]
			FROM ME_CONFIG.Connection c
			INNER JOIN ME_Config.Dataset D ON D.ConnectionID = C.ID
				AND D.ID = @DatasetID
			)
	


	/*Ensure Stage schema exists as defined in MF_Config.Globals*/
	SET @SQLSCHEMACREATE = (SELECT REPLACE('BEGIN TRY DECLARE @X AS VARCHAR(4000) SET @X=¬CREATE SCHEMA '+@TARGETSCHEMA+' AUTHORIZATION dbo¬ EXEC (@X) END TRY BEGIN CATCH PRINT 1 END CATCH' ,'¬',''''))
	/*Flush Out Temp Tables*/
	
	BEGIN TRY
		DROP TABLE #TTBaseData
	END TRY

	BEGIN CATCH
		PRINT 1
	END CATCH
	
	/*Build out main metadata for dynamic SQL*/

	SELECT DISTINCT o.[Id]
		,o.[EntityId]
		,o.[DataSetID]
		,o.[MetadataObjectName]
		,o.[MetadataObjectOrder]
		,o.[MetadataObjectHash]
		,o.[MetadataObjectRefreshUTCTimeStamp]
		,o.[RecordProcessTimestamp]
		,o.[CreatedUTCTimestamp]
		,e.[TargetLake]
		,e.[LakeFolder]
		,e.[SchemaName]
		,EntityName = e.[Name]
		,[ObjectDataType] = DT.[Value]
		,[ObjectDataTypeSize] = DTL.[Value]
		,[ObjectDataTypePrecision] = DTP.[Value]
		,[ObjectDataTypeScale] = DTPS.[Value]
		,DATATYPE = [ME_Config].[fnGetDatatypedeff](DS.[DataSetType], DT.[Value], DTL.[Value], DTP.[Value], DTPS.[Value])
	INTO #TTBaseData
	FROM [Metadata].[Object] O
	INNER JOIN [ME_Config].[DataSet] DS ON O.DataSetId = DS.ID
	INNER JOIN Metadata.Entity E ON O.EntityId = E.id
		AND E.DatasetId = @DatasetID
	INNER JOIN [Metadata].[Attribute] DT ON o.id = DT.ObjectID
		AND DT.EntityId = E.id
		AND DT.[KEY] = 'ObjectDataType'
	INNER JOIN [Metadata].[Attribute] DTL ON o.id = DTL.ObjectID
		AND DTL.EntityId = E.id
		AND DTL.[KEY] = 'ObjectDataTypeSize'
	INNER JOIN [Metadata].[Attribute] DTP ON o.id = DTP.ObjectID
		AND DTP.EntityId = E.id
		AND DTP.[KEY] = 'ObjectDataTypePrecision'
	INNER JOIN [Metadata].[Attribute] DTPS ON o.id = DTPS.ObjectID
		AND DTP.EntityId = E.id
		AND DTPS.[KEY] = 'ObjectDataTypeScale'

/*Build out Copy Into Statement*/
	SET @SQLCOPYINTO = (
			SELECT TOP 1 REPLACE('COPY INTO [' + @TARGETSCHEMA + '].[' + @SourceConnnectionName + '_' + SchemaName + '_' + EntityName + ']
  
  FROM  ¬https://' + @STORAGE_ACCOUNT + '.dfs.core.windows.net/' + LOWER([TargetLake]) + CASE WHEN LEN([LakeFolder])=0 THEN '' ELSE '/' END + LOWER(REPLACE([LakeFolder], '\', '/')) + CASE WHEN LEN(@PARTITIONSTRING)=0 THEN'' ELSE '/' END + LOWER(REPLACE(@PARTITIONSTRING, '\', '/')) + '/*.parquet¬
  WITH
(
	FILE_TYPE = ¬PARQUET¬
	,MAXERRORS = 0
	,COMPRESSION = ¬snappy¬
	,IDENTITY_INSERT = ¬OFF¬
)

  ', '¬', '''')
			FROM #TTBaseData
			)
	
	/*Build Out Drop and Recreate of StageTable*/
	SET @SQLCREATESTAGETABLE = (
			SELECT 'BEGIN TRY DROP TABLE [' + @TARGETSCHEMA + '].[' + @SourceConnnectionName + '_' + SchemaName + '_' + EntityName + '] END TRY BEGIN CATCH PRINT 1 END CATCH 
		CREATE TABLE [' + @TARGETSCHEMA + '].[' + @SourceConnnectionName + '_' + SchemaName + '_' + EntityName + '] 
		( 
		' + CONVERT(NVARCHAR(MAX), (
						(
							STRING_AGG('[' + o.[MetadataObjectName] + '] ' + o.[DATATYPE] + ' ', ',') WITHIN GROUP (
									ORDER BY o.[MetadataObjectOrder] ASC
									)
							)
						)) + ') WITH
			(
			DISTRIBUTION = ROUND_ROBIN,
			/*CLUSTERED COLUMNSTORE INDEX*/
	  		HEAP
			)
			
			'
			FROM #TTBaseData o
			GROUP BY SchemaName
				,EntityName
			)


/*Execute Dynamic SQL in sequence*/


	PRINT 'Creating Stage Table'
print @SQLCREATESTAGETABLE
	EXEC (@SQLCREATESTAGETABLE)

	PRINT 'Loading Stage Table'

	EXEC (@SQLCOPYINTO)

	BEGIN TRY
		DROP TABLE #TTBaseData
	END TRY

	BEGIN CATCH
		PRINT 1
	END CATCH

	EXEC ME_Stage.sp_ProcessLiveData @DatasetID
END