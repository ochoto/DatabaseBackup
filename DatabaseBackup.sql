/*

-- Habilitar XP_CMDSHELL si no lo está

-- http://msdn.microsoft.com/en-us/library/ms190693(v=sql.90).aspx

-- To allow advanced options to be changed.
EXEC sp_configure 'show advanced options', 1
GO
-- To update the currently configured value for advanced options.
RECONFIGURE
GO
-- To enable the feature.
EXEC sp_configure 'xp_cmdshell', 1
GO
-- To update the currently configured value for this feature.
RECONFIGURE
GO

SELECT CONVERT(INT, ISNULL(value, value_in_use)) AS config_value
FROM  sys.configurations
WHERE  name = 'xp_cmdshell' ;


declare @comando nvarchar(max);
SET @comando = 'xp_cmdshell ''c:\msbp\msbp.exe backup "db(database=_DBA_BBDD_Administration_v2;COPY_ONLY;CHECKSUM;buffercount=100;maxtransfersize=4194304)" "gzip(level=1)" "local(path=\\centcseg01\SQL06\PRE\CENTSQLD07\Usuario\_DBA_BBDD_Administration_v2\_DBA_BBDD_Administration_v2_FULL_20130613_195731_1_of_2.bak.gz;path=\\centcseg01\SQL06\PRE\CENTSQLD07\Usuario\_DBA_BBDD_Administration_v2\_DBA_BBDD_Administration_v2_FULL_20130613_195731_2_of_2.bak.gz;)"''';
execute(@comando);
select @@ERROR;


*/


USE [_DBA_BBDD_Administration_v2]
GO

IF  EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[DatabaseBackup]') AND type in (N'P', N'PC'))
DROP PROCEDURE [dbo].[DatabaseBackup]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[DatabaseBackup]

@Databases nvarchar(max),
@Directory nvarchar(max) = NULL,
@BackupType nvarchar(max),
@Verify nvarchar(max) = 'N',
@CleanupTime int = NULL,
@Compress nvarchar(max) = NULL,
@CopyOnly nvarchar(max) = 'N',
@ChangeBackupType nvarchar(max) = 'N',
@BackupSoftware nvarchar(max) = NULL,
@CheckSum nvarchar(max) = 'N',
@BlockSize int = NULL,
@BufferCount int = NULL,
@MaxTransferSize int = NULL,
@NumberOfFiles int = NULL,
@CompressionLevel int = NULL,
@Description nvarchar(max) = NULL,
@Threads int = NULL,
@Throttle int = NULL,
@Encrypt nvarchar(max) = 'N',
@EncryptionType nvarchar(max) = NULL,
@EncryptionKey nvarchar(max) = NULL,
@ReadWriteFileGroups nvarchar(max) = 'N',
@LogToTable nvarchar(max) = 'N',
@Execute nvarchar(max) = 'Y'

/**/
,@BackupSplitSize smallint = 100
,@FixVLF bit = 0
/**/

AS

BEGIN

  ----------------------------------------------------------------------------------------------------
  --// Source: http://ola.hallengren.com                                                          //--
  ----------------------------------------------------------------------------------------------------

  SET NOCOUNT ON

  DECLARE @StartMessage nvarchar(max)
  DECLARE @EndMessage nvarchar(max)
  DECLARE @DatabaseMessage nvarchar(max)
  DECLARE @ErrorMessage nvarchar(max)

  DECLARE @Version numeric(18,10)

  DECLARE @Cluster nvarchar(max)

  DECLARE @DefaultDirectory nvarchar(4000)

  DECLARE @CurrentRootDirectoryID int
  DECLARE @CurrentRootDirectoryPath nvarchar(4000)

  DECLARE @CurrentDBID int
  DECLARE @CurrentDatabaseID int
  DECLARE @CurrentDatabaseName nvarchar(max)
  DECLARE @CurrentBackupType nvarchar(max)
  DECLARE @CurrentFileExtension nvarchar(max)
  DECLARE @CurrentFileNumber int
  DECLARE @CurrentDifferentialBaseLSN numeric(25,0)
  DECLARE @CurrentDifferentialBaseIsSnapshot bit
  DECLARE @CurrentLogLSN numeric(25,0)
  DECLARE @CurrentLatestBackup datetime
  DECLARE @CurrentDatabaseNameFS nvarchar(max)
  DECLARE @CurrentDirectoryID int
  DECLARE @CurrentDirectoryPath nvarchar(max)
  DECLARE @CurrentFilePath nvarchar(max)
  DECLARE @CurrentDate datetime
  DECLARE @CurrentCleanupDate datetime
  DECLARE @CurrentIsDatabaseAccessible bit
  DECLARE @CurrentAvailabilityGroup nvarchar(max)
  DECLARE @CurrentAvailabilityGroupRole nvarchar(max)
  DECLARE @CurrentIsPreferredBackupReplica bit
  DECLARE @CurrentDatabaseMirroringRole nvarchar(max)
  DECLARE @CurrentLogShippingRole nvarchar(max)
  
/**/
  DECLARE @CurrentDBSize int
  DECLARE @CurrentDBBackupFiles smallint
  DECLARE @CurrentDBEncryptionState int
/**/ 

  DECLARE @CurrentCommand01 nvarchar(max)
  DECLARE @CurrentCommand02 nvarchar(max)
  DECLARE @CurrentCommand03 nvarchar(max)
  DECLARE @CurrentCommand04 nvarchar(max)
  DECLARE @CurrentCommand05 nvarchar(max)
  DECLARE @CurrentCommand06 nvarchar(max)
  DECLARE @CurrentCommand07 nvarchar(max)
  DECLARE @CurrentCommand08 nvarchar(max)
  DECLARE @CurrentCommand09 nvarchar(max)
  DECLARE @VLFquery nvarchar(max)

  DECLARE @CurrentCommandOutput01 int
  DECLARE @CurrentCommandOutput02 int
  DECLARE @CurrentCommandOutput03 int
  DECLARE @CurrentCommandOutput04 int
  DECLARE @CurrentCommandOutput05 int
  DECLARE @CurrentCommandOutput06 int
  DECLARE @CurrentCommandOutput07 int
  DECLARE @CurrentCommandOutput08 int
  DECLARE @CurrentCommandOutput09 int

  DECLARE @CurrentCommandType01 nvarchar(max)
  DECLARE @CurrentCommandType02 nvarchar(max)
  DECLARE @CurrentCommandType03 nvarchar(max)
  DECLARE @CurrentCommandType04 nvarchar(max)
  DECLARE @CurrentCommandType05 nvarchar(max)
  DECLARE @CurrentCommandType06 nvarchar(max)
  DECLARE @CurrentCommandType07 nvarchar(max)
  DECLARE @CurrentCommandType08 nvarchar(max)
  DECLARE @CurrentCommandType09 nvarchar(max)

  DECLARE @Directories TABLE (ID int PRIMARY KEY,
                              DirectoryPath nvarchar(max),
                              Completed bit)

  DECLARE @DirectoryInfo TABLE (FileExists bit,
                                FileIsADirectory bit,
                                ParentDirectoryExists bit)

  DECLARE @tmpDatabases TABLE (ID int IDENTITY,
                               DatabaseName nvarchar(max),
                               DatabaseNameFS nvarchar(max),
                               DatabaseType nvarchar(max),
                               Selected bit,
                               Completed bit,
                               PRIMARY KEY(Selected, Completed, ID))

  DECLARE @SelectedDatabases TABLE (DatabaseName nvarchar(max),
                                    DatabaseType nvarchar(max),
                                    Selected bit)

  DECLARE @CurrentDirectories TABLE (ID int PRIMARY KEY,
                                     DirectoryPath nvarchar(max),
                                     CreateCompleted bit,
                                     CleanupCompleted bit,
                                     CreateOutput int,
                                     CleanupOutput int)

  DECLARE @CurrentFiles TABLE (CurrentFilePath nvarchar(max))

  DECLARE @VLF_table TABLE (
		FileID      INT
	  , FileSize    BIGINT
	  , StartOffset BIGINT
	  , FSeqNo      BIGINT
	  , [Status]    BIGINT
	  , Parity      BIGINT
	  , CreateLSN   NUMERIC(38)
	);
  DECLARE 	@file_name sysname,
			@file_size int,
			@shrink_command nvarchar(max),
			@alter_command nvarchar(max)
		
  DECLARE @Error int
  DECLARE @ReturnCode int
  DECLARE @VLF_count int

  SET @Error = 0
  SET @ReturnCode = 0

  SET @Version = CAST(LEFT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)),CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - 1) + '.' + REPLACE(RIGHT(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)), LEN(CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max))) - CHARINDEX('.',CAST(SERVERPROPERTY('ProductVersion') AS nvarchar(max)))),'.','') AS numeric(18,10))

  ----------------------------------------------------------------------------------------------------
  --// Log initial information                                                                    //--
  ----------------------------------------------------------------------------------------------------

  SET @StartMessage = 'Date and time: ' + CONVERT(nvarchar,GETDATE(),120) + CHAR(13) + CHAR(10)
  SET @StartMessage = @StartMessage + 'Server: ' + CAST(SERVERPROPERTY('ServerName') AS nvarchar) + CHAR(13) + CHAR(10)
  SET @StartMessage = @StartMessage + 'Version: ' + CAST(SERVERPROPERTY('ProductVersion') AS nvarchar) + CHAR(13) + CHAR(10)
  SET @StartMessage = @StartMessage + 'Edition: ' + CAST(SERVERPROPERTY('Edition') AS nvarchar) + CHAR(13) + CHAR(10)
  SET @StartMessage = @StartMessage + 'Procedure: ' + QUOTENAME(DB_NAME(DB_ID())) + '.' + (SELECT QUOTENAME(schemas.name) FROM sys.schemas schemas INNER JOIN sys.objects objects ON schemas.[schema_id] = objects.[schema_id] WHERE [object_id] = @@PROCID) + '.' + QUOTENAME(OBJECT_NAME(@@PROCID)) + CHAR(13) + CHAR(10)
  SET @StartMessage = @StartMessage + 'Parameters: @Databases = ' + ISNULL('''' + REPLACE(@Databases,'''','''''') + '''','NULL')
  SET @StartMessage = @StartMessage + ', @Directory = ' + ISNULL('''' + REPLACE(@Directory,'''','''''') + '''','NULL')
  SET @StartMessage = @StartMessage + ', @BackupType = ' + ISNULL('''' + REPLACE(@BackupType,'''','''''') + '''','NULL')
  SET @StartMessage = @StartMessage + ', @Verify = ' + ISNULL('''' + REPLACE(@Verify,'''','''''') + '''','NULL')
  SET @StartMessage = @StartMessage + ', @CleanupTime = ' + ISNULL(CAST(@CleanupTime AS nvarchar),'NULL')
  SET @StartMessage = @StartMessage + ', @Compress = ' + ISNULL('''' + REPLACE(@Compress,'''','''''') + '''','NULL')
  SET @StartMessage = @StartMessage + ', @CopyOnly = ' + ISNULL('''' + REPLACE(@CopyOnly,'''','''''') + '''','NULL')
  SET @StartMessage = @StartMessage + ', @ChangeBackupType = ' + ISNULL('''' + REPLACE(@ChangeBackupType,'''','''''') + '''','NULL')
  SET @StartMessage = @StartMessage + ', @BackupSoftware = ' + ISNULL('''' + REPLACE(@BackupSoftware,'''','''''') + '''','NULL')
  SET @StartMessage = @StartMessage + ', @CheckSum = ' + ISNULL('''' + REPLACE(@CheckSum,'''','''''') + '''','NULL')
  SET @StartMessage = @StartMessage + ', @BlockSize = ' + ISNULL(CAST(@BlockSize AS nvarchar),'NULL')
  SET @StartMessage = @StartMessage + ', @BufferCount = ' + ISNULL(CAST(@BufferCount AS nvarchar),'NULL')
  SET @StartMessage = @StartMessage + ', @MaxTransferSize = ' + ISNULL(CAST(@MaxTransferSize AS nvarchar),'NULL')
  SET @StartMessage = @StartMessage + ', @NumberOfFiles = ' + ISNULL(CAST(@NumberOfFiles AS nvarchar),'NULL')
  SET @StartMessage = @StartMessage + ', @CompressionLevel = ' + ISNULL(CAST(@CompressionLevel AS nvarchar),'NULL')
  SET @StartMessage = @StartMessage + ', @Description = ' + ISNULL('''' + REPLACE(@Description,'''','''''') + '''','NULL')
  SET @StartMessage = @StartMessage + ', @Threads = ' + ISNULL(CAST(@Threads AS nvarchar),'NULL')
  SET @StartMessage = @StartMessage + ', @Throttle = ' + ISNULL(CAST(@Throttle AS nvarchar),'NULL')
  SET @StartMessage = @StartMessage + ', @Encrypt = ' + ISNULL('''' + REPLACE(@Encrypt,'''','''''') + '''','NULL')
  SET @StartMessage = @StartMessage + ', @EncryptionType = ' + ISNULL('''' + REPLACE(@EncryptionType,'''','''''') + '''','NULL')
  SET @StartMessage = @StartMessage + ', @EncryptionKey = ' + ISNULL('''' + REPLACE(@EncryptionKey,'''','''''') + '''','NULL')
  SET @StartMessage = @StartMessage + ', @ReadWriteFileGroups = ' + ISNULL('''' + REPLACE(@ReadWriteFileGroups,'''','''''') + '''','NULL')
  SET @StartMessage = @StartMessage + ', @LogToTable = ' + ISNULL('''' + REPLACE(@LogToTable,'''','''''') + '''','NULL')
  SET @StartMessage = @StartMessage + ', @Execute = ' + ISNULL('''' + REPLACE(@Execute,'''','''''') + '''','NULL') + CHAR(13) + CHAR(10)
  SET @StartMessage = @StartMessage + 'Source: http://ola.hallengren.com' + CHAR(13) + CHAR(10)
  SET @StartMessage = REPLACE(@StartMessage,'%','%%') + ' '
  RAISERROR(@StartMessage,10,1) WITH NOWAIT

  ----------------------------------------------------------------------------------------------------
  --// Check core requirements                                                                    //--
  ----------------------------------------------------------------------------------------------------

  IF NOT EXISTS (SELECT * FROM sys.objects objects INNER JOIN sys.schemas schemas ON objects.[schema_id] = schemas.[schema_id] WHERE objects.[type] = 'P' AND schemas.[name] = 'dbo' AND objects.[name] = 'CommandExecute')
  BEGIN
    SET @ErrorMessage = 'The stored procedure CommandExecute is missing. Download http://ola.hallengren.com/scripts/CommandExecute.sql.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF EXISTS (SELECT * FROM sys.objects objects INNER JOIN sys.schemas schemas ON objects.[schema_id] = schemas.[schema_id] WHERE objects.[type] = 'P' AND schemas.[name] = 'dbo' AND objects.[name] = 'CommandExecute' AND (OBJECT_DEFINITION(objects.[object_id]) NOT LIKE '%@LogToTable%' OR OBJECT_DEFINITION(objects.[object_id]) LIKE '%LOCK_TIMEOUT%'))
  BEGIN
    SET @ErrorMessage = 'The stored procedure CommandExecute needs to be updated. Download http://ola.hallengren.com/scripts/CommandExecute.sql.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @LogToTable = 'Y' AND NOT EXISTS (SELECT * FROM sys.objects objects INNER JOIN sys.schemas schemas ON objects.[schema_id] = schemas.[schema_id] WHERE objects.[type] = 'U' AND schemas.[name] = 'dbo' AND objects.[name] = 'CommandLog')
  BEGIN
    SET @ErrorMessage = 'The table CommandLog is missing. Download http://ola.hallengren.com/scripts/CommandLog.sql.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @Error <> 0
  BEGIN
    SET @ReturnCode = @Error
    GOTO Logging
  END;

  ----------------------------------------------------------------------------------------------------
  --// Select databases                                                                           //--
  ----------------------------------------------------------------------------------------------------

  SET @Databases = REPLACE(@Databases, ', ', ',');

  WITH Databases1 (StartPosition, EndPosition, DatabaseItem) AS
  (
  SELECT 1 AS StartPosition,
         ISNULL(NULLIF(CHARINDEX(',', @Databases, 1), 0), LEN(@Databases) + 1) AS EndPosition,
         SUBSTRING(@Databases, 1, ISNULL(NULLIF(CHARINDEX(',', @Databases, 1), 0), LEN(@Databases) + 1) - 1) AS DatabaseItem
  WHERE @Databases IS NOT NULL
  UNION ALL
  SELECT CAST(EndPosition AS int) + 1 AS StartPosition,
         ISNULL(NULLIF(CHARINDEX(',', @Databases, EndPosition + 1), 0), LEN(@Databases) + 1) AS EndPosition,
         SUBSTRING(@Databases, EndPosition + 1, ISNULL(NULLIF(CHARINDEX(',', @Databases, EndPosition + 1), 0), LEN(@Databases) + 1) - EndPosition - 1) AS DatabaseItem
  FROM Databases1
  WHERE EndPosition < LEN(@Databases) + 1
  ),
  Databases2 (DatabaseItem, Selected) AS
  (
  SELECT CASE WHEN DatabaseItem LIKE '-%' THEN RIGHT(DatabaseItem,LEN(DatabaseItem) - 1) ELSE DatabaseItem END AS DatabaseItem,
         CASE WHEN DatabaseItem LIKE '-%' THEN 0 ELSE 1 END AS Selected
  FROM Databases1
  ),
  Databases3 (DatabaseItem, DatabaseType, Selected) AS
  (
  SELECT CASE WHEN DatabaseItem IN('ALL_DATABASES','SYSTEM_DATABASES','USER_DATABASES') THEN '%' ELSE DatabaseItem END AS DatabaseItem,
         CASE WHEN DatabaseItem = 'SYSTEM_DATABASES' THEN 'S' WHEN DatabaseItem = 'USER_DATABASES' THEN 'U' ELSE NULL END AS DatabaseType,
         Selected
  FROM Databases2
  ),
  Databases4 (DatabaseName, DatabaseType, Selected) AS
  (
  SELECT CASE WHEN LEFT(DatabaseItem,1) = '[' AND RIGHT(DatabaseItem,1) = ']' THEN PARSENAME(DatabaseItem,1) ELSE DatabaseItem END AS DatabaseItem,
         DatabaseType,
         Selected
  FROM Databases3
  )
  INSERT INTO @SelectedDatabases (DatabaseName, DatabaseType, Selected)
  SELECT DatabaseName,
         DatabaseType,
         Selected
  FROM Databases4
  OPTION (MAXRECURSION 0)

  INSERT INTO @tmpDatabases (DatabaseName, DatabaseNameFS, DatabaseType, Selected, Completed)
  SELECT [name] AS DatabaseName,
         REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE([name],'\',''),'/',''),':',''),'*',''),'?',''),'"',''),'<',''),'>',''),'|',''),' ','') AS DatabaseNameFS,
         CASE WHEN name IN('master','msdb','model') THEN 'S' ELSE 'U' END AS DatabaseType,
         0 AS Selected,
         0 AS Completed
  FROM sys.databases
  WHERE [name] <> 'tempdb'
  AND source_database_id IS NULL
  ORDER BY [name] ASC

  UPDATE tmpDatabases
  SET tmpDatabases.Selected = SelectedDatabases.Selected
  FROM @tmpDatabases tmpDatabases
  INNER JOIN @SelectedDatabases SelectedDatabases
  ON tmpDatabases.DatabaseName LIKE REPLACE(SelectedDatabases.DatabaseName,'_','[_]')
  AND (tmpDatabases.DatabaseType = SelectedDatabases.DatabaseType OR SelectedDatabases.DatabaseType IS NULL)
  WHERE SelectedDatabases.Selected = 1

  UPDATE tmpDatabases
  SET tmpDatabases.Selected = SelectedDatabases.Selected
  FROM @tmpDatabases tmpDatabases
  INNER JOIN @SelectedDatabases SelectedDatabases
  ON tmpDatabases.DatabaseName LIKE REPLACE(SelectedDatabases.DatabaseName,'_','[_]')
  AND (tmpDatabases.DatabaseType = SelectedDatabases.DatabaseType OR SelectedDatabases.DatabaseType IS NULL)
  WHERE SelectedDatabases.Selected = 0

  IF @Databases IS NULL OR NOT EXISTS(SELECT * FROM @SelectedDatabases) OR EXISTS(SELECT * FROM @SelectedDatabases WHERE DatabaseName IS NULL OR DatabaseName = '')
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @Databases is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END;

  ----------------------------------------------------------------------------------------------------
  --// Check database names                                                                       //--
  ----------------------------------------------------------------------------------------------------

  SET @ErrorMessage = ''
  SELECT @ErrorMessage = @ErrorMessage + QUOTENAME(DatabaseName) + ', '
  FROM @tmpDatabases
  WHERE Selected = 1
  AND DatabaseNameFS = ''
  ORDER BY DatabaseName ASC
  IF @@ROWCOUNT > 0
  BEGIN
    SET @ErrorMessage = 'The names of the following databases are not supported: ' + LEFT(@ErrorMessage,LEN(@ErrorMessage)-1) + '.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  SET @ErrorMessage = ''
  SELECT @ErrorMessage = @ErrorMessage + QUOTENAME(DatabaseName) + ', '
  FROM @tmpDatabases
  WHERE UPPER(DatabaseNameFS) IN(SELECT UPPER(DatabaseNameFS) FROM @tmpDatabases GROUP BY UPPER(DatabaseNameFS) HAVING COUNT(*) > 1)
  AND UPPER(DatabaseNameFS) IN(SELECT UPPER(DatabaseNameFS) FROM @tmpDatabases WHERE Selected = 1)
  AND DatabaseNameFS <> ''
  ORDER BY DatabaseName ASC
  OPTION (RECOMPILE)
  IF @@ROWCOUNT > 0
  BEGIN
    SET @ErrorMessage = 'The names of the following databases are not unique in the file system: ' + LEFT(@ErrorMessage,LEN(@ErrorMessage)-1) + '.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  ----------------------------------------------------------------------------------------------------
  --// Select directories                                                                         //--
  ----------------------------------------------------------------------------------------------------

	IF @Directory IS NULL
	BEGIN
		IF EXISTS(SELECT Value FROM DBA_Options WHERE Opt LIKE 'FullBackupPath%') and @BackupType='FULL'
			INSERT INTO @Directories (ID, DirectoryPath, Completed)
			--SELECT 1, Value, 0 FROM DBA_Options WHERE Opt='FullBackupPath'
			SELECT ROW_NUMBER() OVER (ORDER BY opt ASC), Value, 0 FROM DBA_Options WHERE Opt like 'FullBackupPath%'
		ELSE
			IF EXISTS(SELECT Value FROM DBA_Options WHERE Opt LIKE 'DiffBackupPath%') and @BackupType='DIFF'
				INSERT INTO @Directories (ID, DirectoryPath, Completed)
				--SELECT 1, Value, 0 FROM DBA_Options WHERE Opt='DiffBackupPath'
				SELECT ROW_NUMBER() OVER (ORDER BY opt ASC), Value, 0 FROM DBA_Options WHERE Opt like 'DiffBackupPath%'
			ELSE
				IF EXISTS(SELECT Value FROM DBA_Options WHERE Opt LIKE 'LogBackupPath%') and @BackupType='LOG'
					INSERT INTO @Directories (ID, DirectoryPath, Completed)
					--SELECT 1, Value, 0 FROM DBA_Options WHERE Opt='LogBackupPath'
					SELECT ROW_NUMBER() OVER (ORDER BY opt ASC), Value, 0 FROM DBA_Options WHERE Opt like 'LogBackupPath%'
				ELSE
					IF EXISTS(SELECT Value FROM DBA_Options WHERE Opt = 'BackupPath')
						INSERT INTO @Directories (ID, DirectoryPath, Completed)
						--SELECT 1, Value, 0 FROM DBA_Options WHERE Opt='BackupPath'
						SELECT ROW_NUMBER() OVER (ORDER BY opt ASC) AS ID, Value, 0 FROM DBA_Options WHERE Opt like 'BackupPath%'
					ELSE
					BEGIN	
						EXECUTE [master].dbo.xp_instance_regread N'HKEY_LOCAL_MACHINE', N'SOFTWARE\Microsoft\MSSQLServer\MSSQLServer', N'BackupDirectory', @DefaultDirectory OUTPUT

						INSERT INTO @Directories (ID, DirectoryPath, Completed)
						SELECT 1, @DefaultDirectory, 0
					END
	END
  ELSE
  BEGIN
     SET @Directory = REPLACE(@Directory, ', ', ',');

    WITH Directories (StartPosition, EndPosition, Directory) AS
    (
    SELECT 1 AS StartPosition,
           ISNULL(NULLIF(CHARINDEX(',', @Directory, 1), 0), LEN(@Directory) + 1) AS EndPosition,
           SUBSTRING(@Directory, 1, ISNULL(NULLIF(CHARINDEX(',', @Directory, 1), 0), LEN(@Directory) + 1) - 1) AS Directory
    WHERE @Directory IS NOT NULL
    UNION ALL
    SELECT CAST(EndPosition AS int) + 1 AS StartPosition,
           ISNULL(NULLIF(CHARINDEX(',', @Directory, EndPosition + 1), 0), LEN(@Directory) + 1) AS EndPosition,
           SUBSTRING(@Directory, EndPosition + 1, ISNULL(NULLIF(CHARINDEX(',', @Directory, EndPosition + 1), 0), LEN(@Directory) + 1) - EndPosition - 1) AS Directory
    FROM Directories
    WHERE EndPosition < LEN(@Directory) + 1
    )
    INSERT INTO @Directories (ID, DirectoryPath, Completed)
    SELECT ROW_NUMBER() OVER(ORDER BY StartPosition ASC) AS ID,
           Directory,
           0
    FROM Directories
    OPTION (MAXRECURSION 0)
  END

  ----------------------------------------------------------------------------------------------------
  --// Check directories                                                                          //--
  ----------------------------------------------------------------------------------------------------
  IF EXISTS(SELECT * FROM @Directories WHERE NOT (DirectoryPath LIKE '_:' OR DirectoryPath LIKE '_:\%' OR DirectoryPath LIKE '\\%\%') OR DirectoryPath IS NULL OR LEFT(DirectoryPath,1) = ' ' OR RIGHT(DirectoryPath,1) = ' ') OR EXISTS (SELECT * FROM @Directories GROUP BY DirectoryPath HAVING COUNT(*) <> 1)
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @Directory is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END
  ELSE
  BEGIN
    WHILE EXISTS(SELECT * FROM @Directories WHERE Completed = 0)
    BEGIN
      SELECT TOP 1 @CurrentRootDirectoryID = ID,
                   @CurrentRootDirectoryPath = DirectoryPath
      FROM @Directories
      WHERE Completed = 0
      ORDER BY ID ASC
/*
      INSERT INTO @DirectoryInfo (FileExists, FileIsADirectory, ParentDirectoryExists)
      EXECUTE [master].dbo.xp_fileexist @CurrentRootDirectoryPath

      IF NOT EXISTS (SELECT * FROM @DirectoryInfo WHERE FileExists = 0 AND FileIsADirectory = 1 AND ParentDirectoryExists = 1)
      BEGIN
        SET @ErrorMessage = 'The directory ' + @CurrentRootDirectoryPath + ' does not exist.' + CHAR(13) + CHAR(10) + ' '
        RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
        SET @Error = @@ERROR
      END
*/
      UPDATE @Directories
      SET Completed = 1
      WHERE ID = @CurrentRootDirectoryID

      SET @CurrentRootDirectoryID = NULL
      SET @CurrentRootDirectoryPath = NULL

      DELETE FROM @DirectoryInfo
    END
  END

  ----------------------------------------------------------------------------------------------------
  --// Get default compression                                                                    //--
  ----------------------------------------------------------------------------------------------------

  IF @Compress IS NULL
  BEGIN
    SELECT @Compress = CASE
    WHEN @BackupSoftware IS NULL AND EXISTS(SELECT * FROM sys.configurations WHERE name = 'backup compression default' AND value_in_use = 1) THEN 'Y'
    WHEN @BackupSoftware IS NULL AND NOT EXISTS(SELECT * FROM sys.configurations WHERE name = 'backup compression default' AND value_in_use = 1) THEN 'N'
    WHEN @BackupSoftware IS NOT NULL AND (@CompressionLevel IS NULL OR @CompressionLevel > 0)  THEN 'Y'
    WHEN @BackupSoftware IS NOT NULL AND @CompressionLevel = 0  THEN 'N'
    END
  END

  ----------------------------------------------------------------------------------------------------
  --// Get number of files                                                                        //--
  ----------------------------------------------------------------------------------------------------

  IF @NumberOfFiles IS NULL
  BEGIN
    SELECT @NumberOfFiles = (SELECT COUNT(*) FROM @Directories)
  END

  ----------------------------------------------------------------------------------------------------
  --// Check input parameters                                                                     //--
  ----------------------------------------------------------------------------------------------------

  IF @BackupType NOT IN ('FULL','DIFF','LOG') OR @BackupType IS NULL
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @BackupType is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @Verify NOT IN ('Y','N') OR @Verify IS NULL OR (@BackupSoftware = 'SQLSAFE' AND @Encrypt = 'Y' AND @Verify = 'Y')
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @Verify is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @CleanupTime < 0
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @CleanupTime is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @Compress NOT IN ('Y','N') OR @Compress IS NULL OR (@Compress = 'Y' AND @BackupSoftware IS NULL AND NOT ((@Version >= 10 AND @Version < 10.5 AND SERVERPROPERTY('EngineEdition') = 3) OR (@Version >= 10.5 AND (SERVERPROPERTY('EngineEdition') = 3 OR SERVERPROPERTY('EditionID') IN (-1534726760, 284895786))))) OR (@Compress = 'N' AND @BackupSoftware IS NOT NULL AND (@CompressionLevel IS NULL OR @CompressionLevel >= 1)) OR (@Compress = 'Y' AND @BackupSoftware IS NOT NULL AND @CompressionLevel = 0)
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @Compress is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @CopyOnly NOT IN ('Y','N') OR @CopyOnly IS NULL
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @CopyOnly is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @ChangeBackupType NOT IN ('Y','N') OR @ChangeBackupType IS NULL
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @ChangeBackupType is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @BackupSoftware NOT IN ('LITESPEED','SQLBACKUP','HYPERBAC','SQLSAFE','MSBP')
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @BackupSoftware is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @BackupSoftware = 'LITESPEED' AND NOT EXISTS (SELECT * FROM [master].sys.objects WHERE [type] = 'X' AND [name] = 'xp_backup_database')
  BEGIN
    SET @ErrorMessage = 'NetVault LiteSpeed for SQL Server is not installed. Download http://www.quest.com/litespeed-for-sql-server/.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @BackupSoftware = 'SQLBACKUP' AND NOT EXISTS (SELECT * FROM [master].sys.objects WHERE [type] = 'X' AND [name] = 'sqlbackup')
  BEGIN
    SET @ErrorMessage = 'Red Gate SQL Backup is not installed. Download http://www.red-gate.com/products/dba/sql-backup/.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @BackupSoftware = 'SQLSAFE' AND NOT EXISTS (SELECT * FROM [master].sys.objects WHERE [type] = 'X' AND [name] = 'xp_ss_backup')
  BEGIN
    SET @ErrorMessage = 'Idera SQL safe backup is not installed. Download http://www.idera.com/Products/SQL-Server/SQL-safe-backup/.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @BackupSoftware = 'MSBP'
  BEGIN
    INSERT INTO @DirectoryInfo (FileExists, FileIsADirectory, ParentDirectoryExists)
    EXECUTE [master].dbo.xp_fileexist 'c:\msbp\msbp.exe'

    IF NOT EXISTS (SELECT * FROM @DirectoryInfo WHERE FileExists = 1 AND FileIsADirectory = 0)
    BEGIN
        SET @ErrorMessage = 'The file c:\msbp\msbp.exe does not exist.' + CHAR(13) + CHAR(10) + ' '
        RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
        SET @Error = @@ERROR
    END
  END

  IF @CheckSum NOT IN ('Y','N') OR @CheckSum IS NULL
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @CheckSum is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @BlockSize NOT IN (512,1024,2048,4096,8192,16384,32768,65536) OR (@BlockSize IS NOT NULL AND @BackupSoftware = 'SQLBACKUP') OR (@BlockSize IS NOT NULL AND @BackupSoftware = 'SQLSAFE')
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @BlockSize is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @BufferCount <= 0 OR @BufferCount > 2147483647 OR (@BufferCount IS NOT NULL AND @BackupSoftware = 'SQLBACKUP') OR (@BufferCount IS NOT NULL AND @BackupSoftware = 'SQLSAFE')
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @BufferCount is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @MaxTransferSize < 65536 OR @MaxTransferSize > 4194304 OR @MaxTransferSize % 65536 > 0 OR (@MaxTransferSize > 1048576 AND @BackupSoftware = 'SQLBACKUP') OR (@MaxTransferSize IS NOT NULL AND @BackupSoftware = 'SQLSAFE')
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @MaxTransferSize is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @NumberOfFiles < 1 OR @NumberOfFiles > 64 OR (@NumberOfFiles > 32 AND @BackupSoftware = 'SQLBACKUP') OR @NumberOfFiles IS NULL OR @NumberOfFiles < (SELECT COUNT(*) FROM @Directories) OR @NumberOfFiles % (SELECT COUNT(*) FROM @Directories) > 0
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @NumberOfFiles is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF (@BackupSoftware IS NULL AND @CompressionLevel IS NOT NULL) OR (@BackupSoftware = 'HYPERBAC' AND @CompressionLevel IS NOT NULL) OR (@BackupSoftware = 'LITESPEED' AND (@CompressionLevel < 0 OR @CompressionLevel > 8)) OR (@BackupSoftware = 'SQLBACKUP' AND (@CompressionLevel < 0 OR @CompressionLevel > 4)) OR (@BackupSoftware = 'SQLSAFE' AND (@CompressionLevel < 1 OR @CompressionLevel > 4)) OR (@BackupSoftware = 'MSBP' AND (@CompressionLevel < 1 OR @CompressionLevel > 9))
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @CompressionLevel is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF LEN(@Description) > 255 OR (@BackupSoftware = 'LITESPEED' AND LEN(@Description) > 128)
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @Description is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @Threads IS NOT NULL AND (@BackupSoftware NOT IN('LITESPEED','SQLBACKUP','SQLSAFE','MSBP') OR @BackupSoftware IS NULL) OR @Threads < 2 OR @Threads > 32
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @Threads is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @Throttle IS NOT NULL AND (@BackupSoftware NOT IN('LITESPEED') OR @BackupSoftware IS NULL) OR @Throttle < 1 OR @Throttle > 100
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @Throttle is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @Encrypt NOT IN('Y','N') OR @Encrypt IS NULL OR (@Encrypt = 'Y' AND @BackupSoftware IS NULL)
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @Encrypt is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF (@EncryptionType IS NOT NULL AND @BackupSoftware IS NULL) OR (@EncryptionType IS NOT NULL AND @BackupSoftware = 'HYPERBAC') OR (@EncryptionType IS NOT NULL AND @Encrypt = 'N') OR ((@EncryptionType NOT IN('RC2-40','RC2-56','RC2-112','RC2-128','3DES-168','RC4-128','AES-128','AES-192','AES-256') OR @EncryptionType IS NULL) AND @Encrypt = 'Y' AND @BackupSoftware = 'LITESPEED') OR ((@EncryptionType NOT IN('AES-128','AES-256') OR @EncryptionType IS NULL) AND @Encrypt = 'Y' AND @BackupSoftware = 'SQLBACKUP') OR ((@EncryptionType NOT IN('AES-128','AES-256') OR @EncryptionType IS NULL) AND @Encrypt = 'Y' AND @BackupSoftware = 'SQLSAFE')
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @EncryptionType is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF (@EncryptionKey IS NOT NULL AND @BackupSoftware IS NULL) OR (@EncryptionKey IS NOT NULL AND @BackupSoftware = 'HYPERBAC') OR (@EncryptionKey IS NOT NULL AND @Encrypt = 'N') OR (@EncryptionKey IS NULL AND @Encrypt = 'Y' AND @BackupSoftware IN('LITESPEED','SQLBACKUP','SQLSAFE'))
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @EncryptionKey is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @ReadWriteFileGroups NOT IN('Y','N') OR @ReadWriteFileGroups IS NULL OR (@ReadWriteFileGroups = 'Y' AND @BackupType = 'LOG')
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @ReadWriteFileGroups is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @LogToTable NOT IN('Y','N') OR @LogToTable IS NULL
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @LogToTable is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

  IF @Execute NOT IN('Y','N') OR @Execute IS NULL
  BEGIN
    SET @ErrorMessage = 'The value for the parameter @Execute is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END

/**/
  IF @BackupSplitSize < 1
  BEGIN
    SET @ErrorMessage = 'The value for parameter @BackupSplitSize is not supported.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @Error = @@ERROR
  END
/**/

  IF @Error <> 0
  BEGIN
    SET @ErrorMessage = 'The documentation is available at http://ola.hallengren.com/sql-server-backup.html.' + CHAR(13) + CHAR(10) + ' '
    RAISERROR(@ErrorMessage,16,1) WITH NOWAIT
    SET @ReturnCode = @Error
    GOTO Logging
  END

  ----------------------------------------------------------------------------------------------------
  --// Check Availability Group cluster name                                                      //--
  ----------------------------------------------------------------------------------------------------

  IF @Version >= 11
  BEGIN
    SELECT @Cluster = cluster_name
    FROM sys.dm_hadr_cluster
  END

  ----------------------------------------------------------------------------------------------------
  --// Execute backup commands                                                                    //--
  ----------------------------------------------------------------------------------------------------

  WHILE EXISTS (SELECT * FROM @tmpDatabases WHERE Selected = 1 AND Completed = 0)
  BEGIN

    SELECT TOP 1 @CurrentDBID = ID,
                 @CurrentDatabaseName = DatabaseName,
                 @CurrentDatabaseNameFS = DatabaseNameFS
    FROM @tmpDatabases
    WHERE Selected = 1
    AND Completed = 0
    ORDER BY ID ASC

    SET @CurrentDatabaseID = DB_ID(@CurrentDatabaseName)

/**/  
	IF (@NumberOfFiles=1) and (not @BackupSplitSize is null) and (@BackupType='FULL')
	BEGIN
		SELECT @CurrentDBSize=(((sum(size)*8)/1024)/1024) FROM sys.master_files WHERE DB_NAME(database_id) = @CurrentDatabaseName
		SET @CurrentDBBackupFiles=round((convert(float,@CurrentDBSize)/convert(float,@BackupSplitSize))+0.5,0)
		IF @CurrentDBBackupFiles=0
			SET @CurrentDBBackupFiles=1
	END
	ELSE
		SET @CurrentDBBackupFiles=@NumberOfFiles
/**/ 

    IF DATABASEPROPERTYEX(@CurrentDatabaseName,'Status') = 'ONLINE'
    BEGIN
      IF EXISTS (SELECT * FROM sys.database_recovery_status WHERE database_id = @CurrentDatabaseID AND database_guid IS NOT NULL)
      BEGIN
        SET @CurrentIsDatabaseAccessible = 1
      END
      ELSE
      BEGIN
        SET @CurrentIsDatabaseAccessible = 0
      END
    END
    ELSE
    BEGIN
      SET @CurrentIsDatabaseAccessible = 0
    END

    SELECT @CurrentDifferentialBaseLSN = differential_base_lsn
    FROM sys.master_files
    WHERE database_id = @CurrentDatabaseID
    AND [type] = 0
    AND [file_id] = 1

    -- Workaround for a bug in SQL Server 2005
    IF @Version >= 9 AND @Version < 10
    AND EXISTS(SELECT * FROM sys.master_files WHERE database_id = @CurrentDatabaseID AND [type] = 0 AND [file_id] = 1 AND differential_base_lsn IS NOT NULL AND differential_base_guid IS NOT NULL AND differential_base_time IS NULL)
    BEGIN
      SET @CurrentDifferentialBaseLSN = NULL
    END

    SELECT @CurrentDifferentialBaseIsSnapshot = is_snapshot
    FROM msdb.dbo.backupset
    WHERE database_name = @CurrentDatabaseName
    AND [type] = 'D'
    AND checkpoint_lsn = @CurrentDifferentialBaseLSN

    IF DATABASEPROPERTYEX(@CurrentDatabaseName,'Status') = 'ONLINE'
    BEGIN
      SELECT @CurrentLogLSN = last_log_backup_lsn
      FROM sys.database_recovery_status
      WHERE database_id = @CurrentDatabaseID
    END

    SET @CurrentBackupType = @BackupType

    IF @ChangeBackupType = 'Y'
    BEGIN
      IF @CurrentBackupType = 'LOG' AND DATABASEPROPERTYEX(@CurrentDatabaseName,'Recovery') <> 'SIMPLE' AND @CurrentLogLSN IS NULL AND @CurrentDatabaseName <> 'master'
      BEGIN
        SET @CurrentBackupType = 'DIFF'
      END
      IF @CurrentBackupType = 'DIFF' AND @CurrentDifferentialBaseLSN IS NULL AND @CurrentDatabaseName <> 'master'
      BEGIN
        SET @CurrentBackupType = 'FULL'
      END
    END

    IF @CurrentBackupType = 'LOG'
    BEGIN
      SELECT @CurrentLatestBackup = MAX(backup_finish_date)
      FROM msdb.dbo.backupset
      WHERE [type] IN('D','I')
      AND is_damaged = 0
      AND database_name = @CurrentDatabaseName
    END

    IF @Version >= 11 AND @Cluster IS NOT NULL
    BEGIN
      SELECT @CurrentAvailabilityGroup = availability_groups.name,
             @CurrentAvailabilityGroupRole = dm_hadr_availability_replica_states.role_desc
      FROM sys.databases databases
      INNER JOIN sys.availability_databases_cluster availability_databases_cluster ON databases.group_database_id = availability_databases_cluster.group_database_id
      INNER JOIN sys.availability_groups availability_groups ON availability_databases_cluster.group_id = availability_groups.group_id
      INNER JOIN sys.dm_hadr_availability_replica_states dm_hadr_availability_replica_states ON availability_groups.group_id = dm_hadr_availability_replica_states.group_id AND databases.replica_id = dm_hadr_availability_replica_states.replica_id
      WHERE databases.name = @CurrentDatabaseName
    END

    IF @Version >= 11 AND @Cluster IS NOT NULL AND @CurrentAvailabilityGroup IS NOT NULL
    BEGIN
      SELECT @CurrentIsPreferredBackupReplica = sys.fn_hadr_backup_is_preferred_replica(@CurrentDatabaseName)
    END

    SELECT @CurrentDatabaseMirroringRole = UPPER(mirroring_role_desc)
    FROM sys.database_mirroring
    WHERE database_id = @CurrentDatabaseID

    IF EXISTS (SELECT * FROM msdb.dbo.log_shipping_primary_databases WHERE primary_database = @CurrentDatabaseName)
    BEGIN
      SET @CurrentLogShippingRole = 'PRIMARY'
    END
    ELSE
    IF EXISTS (SELECT * FROM msdb.dbo.log_shipping_secondary_databases WHERE secondary_database = @CurrentDatabaseName)
    BEGIN
      SET @CurrentLogShippingRole = 'SECONDARY'
    END

    -- Set database message
    SET @DatabaseMessage = 'Date and time: ' + CONVERT(nvarchar,GETDATE(),120) + CHAR(13) + CHAR(10)
    SET @DatabaseMessage = @DatabaseMessage + 'Database: ' + QUOTENAME(@CurrentDatabaseName) + CHAR(13) + CHAR(10)
    SET @DatabaseMessage = @DatabaseMessage + 'Status: ' + CAST(DATABASEPROPERTYEX(@CurrentDatabaseName,'Status') AS nvarchar) + CHAR(13) + CHAR(10)
    SET @DatabaseMessage = @DatabaseMessage + 'Standby: ' + CASE WHEN DATABASEPROPERTYEX(@CurrentDatabaseName,'IsInStandBy') = 1 THEN 'Yes' ELSE 'No' END + CHAR(13) + CHAR(10)
    SET @DatabaseMessage = @DatabaseMessage + 'Updateability: ' + CAST(DATABASEPROPERTYEX(@CurrentDatabaseName,'Updateability') AS nvarchar) + CHAR(13) + CHAR(10)
    SET @DatabaseMessage = @DatabaseMessage + 'User access: ' + CAST(DATABASEPROPERTYEX(@CurrentDatabaseName,'UserAccess') AS nvarchar) + CHAR(13) + CHAR(10)
    SET @DatabaseMessage = @DatabaseMessage + 'Is accessible: ' + CASE WHEN @CurrentIsDatabaseAccessible = 1 THEN 'Yes' ELSE 'No' END + CHAR(13) + CHAR(10)
    SET @DatabaseMessage = @DatabaseMessage + 'Recovery model: ' + CAST(DATABASEPROPERTYEX(@CurrentDatabaseName,'Recovery') AS nvarchar) + CHAR(13) + CHAR(10)
    IF @CurrentAvailabilityGroup IS NOT NULL SET @DatabaseMessage = @DatabaseMessage + 'Availability group: ' + @CurrentAvailabilityGroup + CHAR(13) + CHAR(10)
    IF @CurrentAvailabilityGroup IS NOT NULL SET @DatabaseMessage = @DatabaseMessage + 'Availability group role: ' + @CurrentAvailabilityGroupRole + CHAR(13) + CHAR(10)
    IF @CurrentAvailabilityGroup IS NOT NULL SET @DatabaseMessage = @DatabaseMessage + 'Is preferred backup replica: ' + CASE WHEN @CurrentIsPreferredBackupReplica = 1 THEN 'Yes' WHEN @CurrentIsPreferredBackupReplica = 0 THEN 'No' ELSE 'N/A' END + CHAR(13) + CHAR(10)
    IF @CurrentDatabaseMirroringRole IS NOT NULL SET @DatabaseMessage = @DatabaseMessage + 'Database mirroring role: ' + @CurrentDatabaseMirroringRole + CHAR(13) + CHAR(10)
    IF @CurrentLogShippingRole IS NOT NULL SET @DatabaseMessage = @DatabaseMessage + 'Log shipping role: ' + @CurrentLogShippingRole + CHAR(13) + CHAR(10)
    SET @DatabaseMessage = @DatabaseMessage + 'Differential base LSN: ' + ISNULL(CAST(@CurrentDifferentialBaseLSN AS nvarchar),'N/A') + CHAR(13) + CHAR(10)
    SET @DatabaseMessage = @DatabaseMessage + 'Differential base is snapshot: ' + CASE WHEN @CurrentDifferentialBaseIsSnapshot = 1 THEN 'Yes' WHEN @CurrentDifferentialBaseIsSnapshot = 0 THEN 'No' ELSE 'N/A' END + CHAR(13) + CHAR(10)
    SET @DatabaseMessage = @DatabaseMessage + 'Last log backup LSN: ' + ISNULL(CAST(@CurrentLogLSN AS nvarchar),'N/A') + CHAR(13) + CHAR(10)
    SET @DatabaseMessage = REPLACE(@DatabaseMessage,'%','%%') + ' '
    RAISERROR(@DatabaseMessage,10,1) WITH NOWAIT

    IF DATABASEPROPERTYEX(@CurrentDatabaseName,'Status') = 'ONLINE'
    AND NOT (DATABASEPROPERTYEX(@CurrentDatabaseName,'UserAccess') = 'SINGLE_USER' AND @CurrentIsDatabaseAccessible = 0)
    AND DATABASEPROPERTYEX(@CurrentDatabaseName,'IsInStandBy') = 0
    AND NOT (@CurrentBackupType = 'LOG' AND (DATABASEPROPERTYEX(@CurrentDatabaseName,'Recovery') = 'SIMPLE' OR @CurrentLogLSN IS NULL))
    AND NOT (@CurrentBackupType = 'DIFF' AND @CurrentDifferentialBaseLSN IS NULL)
    AND NOT (@CurrentBackupType IN('DIFF','LOG') AND @CurrentDatabaseName = 'master')
    AND NOT (@CurrentAvailabilityGroup IS NOT NULL AND @CurrentBackupType = 'FULL' AND @CopyOnly = 'N' AND (@CurrentAvailabilityGroupRole <> 'PRIMARY' OR @CurrentAvailabilityGroupRole IS NULL))
    AND NOT (@CurrentAvailabilityGroup IS NOT NULL AND @CurrentBackupType = 'FULL' AND @CopyOnly = 'Y' AND (@CurrentIsPreferredBackupReplica <> 1 OR @CurrentIsPreferredBackupReplica IS NULL))
    AND NOT (@CurrentAvailabilityGroup IS NOT NULL AND @CurrentBackupType = 'DIFF' AND (@CurrentAvailabilityGroupRole <> 'PRIMARY' OR @CurrentAvailabilityGroupRole IS NULL))
    AND NOT (@CurrentAvailabilityGroup IS NOT NULL AND @CurrentBackupType = 'LOG' AND @CopyOnly = 'N' AND (@CurrentIsPreferredBackupReplica <> 1 OR @CurrentIsPreferredBackupReplica IS NULL))
    AND NOT (@CurrentAvailabilityGroup IS NOT NULL AND @CurrentBackupType = 'LOG' AND @CopyOnly = 'Y' AND (@CurrentAvailabilityGroupRole <> 'PRIMARY' OR @CurrentAvailabilityGroupRole IS NULL))
    AND NOT ((@CurrentLogShippingRole = 'PRIMARY' AND @CurrentLogShippingRole IS NOT NULL) AND @CurrentBackupType = 'LOG')
    BEGIN

      -- Set variables
      SET @CurrentDate = GETDATE()

      IF @CleanupTime IS NULL OR (@CurrentBackupType = 'LOG' AND @CurrentLatestBackup IS NULL) OR @CurrentBackupType <> @BackupType
      BEGIN
        SET @CurrentCleanupDate = NULL
      END
      ELSE
      IF @CurrentBackupType = 'LOG'
      BEGIN
        SET @CurrentCleanupDate = (SELECT MIN([Date]) FROM(SELECT DATEADD(hh,-(@CleanupTime),@CurrentDate) AS [Date] UNION SELECT @CurrentLatestBackup AS [Date]) Dates)
      END
      ELSE
      BEGIN
        SET @CurrentCleanupDate = DATEADD(hh,-(@CleanupTime),@CurrentDate)
      END

      SELECT @CurrentFileExtension = CASE
      WHEN @BackupSoftware IS NULL AND @CurrentBackupType = 'FULL' THEN 'bak'
      WHEN @BackupSoftware IS NULL AND @CurrentBackupType = 'DIFF' THEN 'dif'
      WHEN @BackupSoftware IS NULL AND @CurrentBackupType = 'LOG' THEN 'trn'
      WHEN @BackupSoftware = 'LITESPEED' AND @CurrentBackupType = 'FULL' THEN 'bak'
      WHEN @BackupSoftware = 'LITESPEED' AND @CurrentBackupType = 'DIFF' THEN 'bak'
      WHEN @BackupSoftware = 'LITESPEED' AND @CurrentBackupType = 'LOG' THEN 'trn'
      WHEN @BackupSoftware = 'SQLBACKUP' AND @CurrentBackupType = 'FULL' THEN 'sqb'
      WHEN @BackupSoftware = 'SQLBACKUP' AND @CurrentBackupType = 'DIFF' THEN 'sqb'
      WHEN @BackupSoftware = 'SQLBACKUP' AND @CurrentBackupType = 'LOG' THEN 'sqb'
      WHEN @BackupSoftware = 'HYPERBAC' AND @CurrentBackupType = 'FULL' AND @Encrypt = 'N' THEN 'hbc'
      WHEN @BackupSoftware = 'HYPERBAC' AND @CurrentBackupType = 'DIFF' AND @Encrypt = 'N' THEN 'hbc'
      WHEN @BackupSoftware = 'HYPERBAC' AND @CurrentBackupType = 'LOG' AND @Encrypt = 'N' THEN 'hbc'
      WHEN @BackupSoftware = 'HYPERBAC' AND @CurrentBackupType = 'FULL' AND @Encrypt = 'Y' THEN 'hbe'
      WHEN @BackupSoftware = 'HYPERBAC' AND @CurrentBackupType = 'DIFF' AND @Encrypt = 'Y' THEN 'hbe'
      WHEN @BackupSoftware = 'HYPERBAC' AND @CurrentBackupType = 'LOG' AND @Encrypt = 'Y' THEN 'hbe'
      WHEN @BackupSoftware = 'SQLSAFE' AND @CurrentBackupType = 'FULL' THEN 'safe'
      WHEN @BackupSoftware = 'SQLSAFE' AND @CurrentBackupType = 'DIFF' THEN 'safe'
      WHEN @BackupSoftware = 'SQLSAFE' AND @CurrentBackupType = 'LOG' THEN 'safe'
      WHEN @BackupSoftware = 'MSBP' AND @CurrentBackupType = 'FULL' THEN 'bak.gz'
      WHEN @BackupSoftware = 'MSBP' AND @CurrentBackupType = 'DIFF' THEN 'dif.gz'
      WHEN @BackupSoftware = 'MSBP' AND @CurrentBackupType = 'LOG' THEN 'trn.gz'
      END

	  --SET @CurrentDirectory = @Directory + CASE WHEN RIGHT(@Directory,1) = '\' THEN '' ELSE '\' END + CASE (CHARINDEX(REPLACE(CAST(SERVERPROPERTY('servername') AS nvarchar),'\','$'),@Directory,1)) WHEN 0 THEN REPLACE(CAST(SERVERPROPERTY('servername') AS nvarchar),'\','$') + '\' ELSE '' END  + CASE UPPER(@Databases) WHEN 'SYSTEM_DATABASES' THEN 'Sistema' ELSE 'Usuario' END + '\' + @CurrentDatabaseNameFS 

      INSERT INTO @CurrentDirectories (ID, DirectoryPath, CreateCompleted, CleanupCompleted)
      --SELECT ROW_NUMBER() OVER (ORDER BY ID), DirectoryPath + CASE WHEN RIGHT(DirectoryPath,1) = '\' THEN '' ELSE '\' END + CASE WHEN @CurrentAvailabilityGroup IS NOT NULL THEN @Cluster + '$' + @CurrentAvailabilityGroup ELSE REPLACE(CAST(SERVERPROPERTY('servername') AS nvarchar),'\','$') END + '\' + @CurrentDatabaseNameFS + '\' + UPPER(@CurrentBackupType) + CASE WHEN @ReadWriteFileGroups = 'Y' THEN '_PARTIAL' ELSE '' END + CASE WHEN @CopyOnly = 'Y' THEN '_COPY_ONLY' ELSE '' END, 0, 0
      SELECT ROW_NUMBER() OVER (ORDER BY ID), DirectoryPath + CASE WHEN RIGHT(DirectoryPath,1) = '\' THEN '' ELSE '\' END + CASE WHEN @CurrentAvailabilityGroup IS NOT NULL THEN @Cluster + '$' + @CurrentAvailabilityGroup ELSE CASE (CHARINDEX(REPLACE(CAST(SERVERPROPERTY('servername') AS nvarchar),'\','$'),DirectoryPath,1)) WHEN 0 THEN REPLACE(CAST(SERVERPROPERTY('servername') AS nvarchar),'\','$') + '\' ELSE '' END  + CASE UPPER(@Databases) WHEN 'SYSTEM_DATABASES' THEN 'Sistema' ELSE 'Usuario' END + '\' + @CurrentDatabaseNameFS END, 0, 0
      FROM @Directories
      ORDER BY ID ASC

      SET @CurrentFileNumber = 0

      --WHILE @CurrentFileNumber < @NumberOfFiles
      WHILE @CurrentFileNumber < @CurrentDBBackupFiles
      BEGIN
        SET @CurrentFileNumber = @CurrentFileNumber + 1

        SELECT @CurrentDirectoryPath = DirectoryPath
        FROM @CurrentDirectories
        WHERE @CurrentFileNumber >= (ID - 1) * (SELECT @NumberOfFiles / COUNT(*) FROM @CurrentDirectories) + 1
        AND @CurrentFileNumber <= ID * (SELECT @NumberOfFiles / COUNT(*) FROM @CurrentDirectories)

        --SET @CurrentFilePath = @CurrentDirectoryPath + '\' + CASE WHEN @CurrentAvailabilityGroup IS NOT NULL THEN @Cluster + '$' + @CurrentAvailabilityGroup ELSE REPLACE(CAST(SERVERPROPERTY('servername') AS nvarchar),'\','$') END + '_' + @CurrentDatabaseNameFS + '_' + UPPER(@CurrentBackupType) + CASE WHEN @ReadWriteFileGroups = 'Y' THEN '_PARTIAL' ELSE '' END + CASE WHEN @CopyOnly = 'Y' THEN '_COPY_ONLY' ELSE '' END + '_' + REPLACE(REPLACE(REPLACE((CONVERT(nvarchar,@CurrentDate,120)),'-',''),' ','_'),':','') + CASE WHEN @NumberOfFiles > 1 AND @NumberOfFiles <= 9 THEN '_' + CAST(@CurrentFileNumber AS nvarchar) WHEN @NumberOfFiles >= 10 THEN '_' + RIGHT('0' + CAST(@CurrentFileNumber AS nvarchar),2) ELSE '' END + '.' + @CurrentFileExtension
        SET @CurrentFilePath = @CurrentDirectoryPath + '\' + @CurrentDatabaseNameFS + '_' + UPPER(@CurrentBackupType) + CASE WHEN @ReadWriteFileGroups = 'Y' THEN '_PARTIAL' ELSE '' END + CASE WHEN @CopyOnly = 'Y' THEN '_COPY_ONLY' ELSE '' END + '_' + REPLACE(REPLACE(REPLACE((CONVERT(nvarchar,@CurrentDate,120)),'-',''),' ','_'),':','') + CASE WHEN @CurrentDBBackupFiles > 1 AND @CurrentDBBackupFiles <= 9 THEN '_' + CAST(@CurrentFileNumber AS nvarchar) + '_of_' + CAST(@CurrentDBBackupFiles AS nvarchar) WHEN @CurrentDBBackupFiles >= 10 THEN '_' + RIGHT('0' + CAST(@CurrentFileNumber AS nvarchar),2) + '_of_' + RIGHT('0' + CAST(@CurrentDBBackupFiles AS nvarchar),2) ELSE '' END + '.' + @CurrentFileExtension

        IF LEN(@CurrentFilePath) > 259
        BEGIN
          --SET @CurrentFilePath = @CurrentDirectoryPath + '\' + CASE WHEN @CurrentAvailabilityGroup IS NOT NULL THEN @Cluster + '$' + @CurrentAvailabilityGroup ELSE REPLACE(CAST(SERVERPROPERTY('servername') AS nvarchar),'\','$') END + '_' + LEFT(@CurrentDatabaseNameFS,CASE WHEN (LEN(@CurrentDatabaseNameFS) + 259 - LEN(@CurrentFilePath) - 3) < 20 THEN 20 ELSE (LEN(@CurrentDatabaseNameFS) + 259 - LEN(@CurrentFilePath) - 3) END) + '...' + '_' + UPPER(@CurrentBackupType) + CASE WHEN @ReadWriteFileGroups = 'Y' THEN '_PARTIAL' ELSE '' END + CASE WHEN @CopyOnly = 'Y' THEN '_COPY_ONLY' ELSE '' END + '_' + REPLACE(REPLACE(REPLACE((CONVERT(nvarchar,@CurrentDate,120)),'-',''),' ','_'),':','') + CASE WHEN @NumberOfFiles > 1 AND @NumberOfFiles <= 9 THEN '_' + CAST(@CurrentFileNumber AS nvarchar) WHEN @NumberOfFiles >= 10 THEN '_' + RIGHT('0' + CAST(@CurrentFileNumber AS nvarchar),2) ELSE '' END + '.' + @CurrentFileExtension
          SET @CurrentFilePath = @CurrentDirectoryPath + '\' + LEFT(@CurrentDatabaseNameFS,CASE WHEN (LEN(@CurrentDatabaseNameFS) + 259 - LEN(@CurrentFilePath) - 3) < 20 THEN 20 ELSE (LEN(@CurrentDatabaseNameFS) + 259 - LEN(@CurrentFilePath) - 3) END) + '...' + '_' + UPPER(@CurrentBackupType) + '_' + REPLACE(REPLACE(REPLACE((CONVERT(nvarchar,@CurrentDate,120)),'-',''),' ','_'),':','') + CASE WHEN @CurrentDBBackupFiles > 1 AND @CurrentDBBackupFiles <= 9 THEN '_' + CAST(@CurrentFileNumber AS nvarchar)+ '_of_' + CAST(@CurrentDBBackupFiles AS nvarchar) WHEN @CurrentDBBackupFiles >= 10 THEN '_' + RIGHT('0' + CAST(@CurrentFileNumber AS nvarchar),2) + '_of_' + RIGHT('0' + CAST(@CurrentDBBackupFiles AS nvarchar),2) ELSE '' END + '.' + @CurrentFileExtension
        END

        INSERT INTO @CurrentFiles (CurrentFilePath)
        SELECT @CurrentFilePath

        IF @NumberOfFiles>1 
			SET @CurrentDirectoryPath = NULL
        SET @CurrentFilePath = NULL
      END

      -- Create directory
      WHILE EXISTS (SELECT * FROM @CurrentDirectories WHERE CreateCompleted = 0)
      BEGIN
        SELECT TOP 1 @CurrentDirectoryID = ID,
                     @CurrentDirectoryPath = DirectoryPath
        FROM @CurrentDirectories
        WHERE CreateCompleted = 0
        ORDER BY ID ASC

        SET @CurrentCommandType01 = 'xp_create_subdir'
        SET @CurrentCommand01 = 'DECLARE @ReturnCode int EXECUTE @ReturnCode = [master].dbo.xp_create_subdir N''' + REPLACE(@CurrentDirectoryPath,'''','''''') + ''' IF @ReturnCode <> 0 RAISERROR(''Error creating directory.'', 16, 1)'
        EXECUTE @CurrentCommandOutput01 = [dbo].[CommandExecute] @Command = @CurrentCommand01, @CommandType = @CurrentCommandType01, @Mode = 1, @DatabaseName = @CurrentDatabaseName, @LogToTable = @LogToTable, @Execute = @Execute
        SET @Error = @@ERROR
        IF @Error <> 0 SET @CurrentCommandOutput01 = @Error
        IF @CurrentCommandOutput01 <> 0 SET @ReturnCode = @CurrentCommandOutput01

        UPDATE @CurrentDirectories
        SET CreateCompleted = 1,
            CreateOutput = @CurrentCommandOutput01
        WHERE ID = @CurrentDirectoryID

        SET @CurrentDirectoryID = NULL
        SET @CurrentDirectoryPath = NULL

        SET @CurrentCommand01 = NULL

        SET @CurrentCommandOutput01 = NULL

        SET @CurrentCommandType01 = NULL
      END

	  -- Check VLF
	  IF (@FixVLF =1) and (@CurrentBackupType='FULL')
	  BEGIN
	  
		SET @VLFquery = 'DBCC loginfo (' + '''' + @CurrentDatabaseName + ''') WITH NO_INFOMSGS'
		INSERT INTO @VLF_table
		EXEC (@VLFquery)

		SELECT @VLF_count = count(*) from @VLF_table
		IF @VLF_count>= 50
		BEGIN
			IF (DATABASEPROPERTYEX(@CurrentDatabaseName,'Recovery') <> 'SIMPLE')
			BEGIN
				SET @CurrentCommandType06 = 'FixVLF'
				SET @CurrentCommand06 = 'BACKUP LOG ' + QUOTENAME(@CurrentDatabaseName) + ' TO'
		SELECT @CurrentDirectoryPath=Value FROM DBA_Options WHERE Opt = 'BackupPath'
        SET @CurrentFilePath = @CurrentDirectoryPath + CASE WHEN RIGHT(@CurrentDirectoryPath,1) = '\' THEN '' ELSE '\' END + CASE WHEN @CurrentAvailabilityGroup IS NOT NULL THEN @Cluster + '$' + @CurrentAvailabilityGroup ELSE CASE (CHARINDEX(REPLACE(CAST(SERVERPROPERTY('servername') AS nvarchar),'\','$'),@CurrentDirectoryPath,1)) WHEN 0 THEN REPLACE(CAST(SERVERPROPERTY('servername') AS nvarchar),'\','$') + '\' ELSE '' END  +  'Usuario'  + '\' + @CurrentDatabaseNameFS END + '\' + @CurrentDatabaseNameFS + '_' + UPPER(@CurrentBackupType) + CASE WHEN @ReadWriteFileGroups = 'Y' THEN '_PARTIAL' ELSE '' END + '_' + REPLACE(REPLACE(REPLACE((CONVERT(nvarchar,@CurrentDate,120)),'-',''),' ','_'),':','') + '.trn' 
				
				SET @CurrentCommand06 = @CurrentCommand06 + ' DISK = N''' + REPLACE(REPLACE(REPLACE(@CurrentFilePath,'''',''''''),'bak','trn'),'FULL','LOG') + '''' 


				SET @CurrentCommand06 = @CurrentCommand06 + ' WITH '
				IF @CheckSum = 'Y' SET @CurrentCommand06 = @CurrentCommand06 + 'CHECKSUM'
				IF @CheckSum = 'N' SET @CurrentCommand06 = @CurrentCommand06 + 'NO_CHECKSUM'
				IF @Compress = 'Y' SET @CurrentCommand06 = @CurrentCommand06 + ', COMPRESSION'
				IF @Compress = 'N' AND @Version >= 10 SET @CurrentCommand06 = @CurrentCommand06 + ', NO_COMPRESSION'
				IF @BlockSize IS NOT NULL SET @CurrentCommand06 = @CurrentCommand06 + ', BLOCKSIZE = ' + CAST(@BlockSize AS nvarchar)
				IF @BufferCount IS NOT NULL SET @CurrentCommand06 = @CurrentCommand06 + ', BUFFERCOUNT = ' + CAST(@BufferCount AS nvarchar)
				IF @MaxTransferSize IS NOT NULL SET @CurrentCommand06 = @CurrentCommand06 + ', MAXTRANSFERSIZE = ' + CAST(@MaxTransferSize AS nvarchar)
				IF @Description IS NOT NULL SET @CurrentCommand06 = @CurrentCommand06 + ', DESCRIPTION = N''' + REPLACE(@Description,'''','''''') + ''''

				EXECUTE @CurrentCommandOutput06 = [dbo].[CommandExecute] @Command = @CurrentCommand06, @CommandType = @CurrentCommandType06, @Mode = 1, @DatabaseName = @CurrentDatabaseName, @LogToTable = @LogToTable, @Execute = @Execute
				SET @Error = @@ERROR
				IF @Error <> 0 SET @CurrentCommandOutput06 = @Error
				IF @CurrentCommandOutput06 <> 0 SET @ReturnCode = @CurrentCommandOutput06
			END

			SELECT  @file_name = name,
					@file_size = (size / 128)
			FROM    sys.master_files
			WHERE   type_desc = 'log' and database_id=DB_ID(@CurrentDatabaseName)
	
			SET @CurrentCommandType07 = 'SHRINKFILE TRUNCATEONLY'
			SET @CurrentCommand07 =  'USE ' + QUOTENAME(@CurrentDatabaseName) + '; DBCC SHRINKFILE (N''' + @file_name + ''' , 0, TRUNCATEONLY) WITH NO_INFOMSGS' 
			EXECUTE @CurrentCommandOutput07 = [dbo].[CommandExecute] @Command = @CurrentCommand07, @CommandType = @CurrentCommandType07, @Mode = 1, @DatabaseName = @CurrentDatabaseName, @LogToTable = @LogToTable, @Execute = @Execute
			SET @Error = @@ERROR
			IF @Error <> 0 SET @CurrentCommandOutput07 = @Error
			IF @CurrentCommandOutput07 <> 0 SET @ReturnCode = @CurrentCommandOutput07

			SET @CurrentCommandType08 = 'SHRINKFILE'
			SET @CurrentCommand08 =  'USE ' + QUOTENAME(@CurrentDatabaseName) + '; DBCC SHRINKFILE (N''' + @file_name + ''' , 0) WITH NO_INFOMSGS' 
			EXECUTE @CurrentCommandOutput08 = [dbo].[CommandExecute] @Command = @CurrentCommand08, @CommandType = @CurrentCommandType08, @Mode = 1, @DatabaseName = @CurrentDatabaseName, @LogToTable = @LogToTable, @Execute = @Execute
			SET @Error = @@ERROR
			IF @Error <> 0 SET @CurrentCommandOutput08 = @Error
			IF @CurrentCommandOutput08 <> 0 SET @ReturnCode = @CurrentCommandOutput08

			SET @CurrentCommandType09 = 'ALTER_LOG_FILE_SIZE'
			SET @CurrentCommand09 =  'ALTER DATABASE ' + QUOTENAME(@CurrentDatabaseName) + ' MODIFY FILE (NAME = N''' + @file_name + ''', SIZE = ' + CAST(@file_size AS nvarchar) + 'MB)'
			EXECUTE @CurrentCommandOutput09 = [dbo].[CommandExecute] @Command = @CurrentCommand09, @CommandType = @CurrentCommandType09, @Mode = 1, @DatabaseName = @CurrentDatabaseName, @LogToTable = @LogToTable, @Execute = @Execute
			SET @Error = @@ERROR
			IF @Error <> 0 SET @CurrentCommandOutput09 = @Error
			IF @CurrentCommandOutput09 <> 0 SET @ReturnCode = @CurrentCommandOutput09

		END

		DELETE FROM  @VLF_table
	  END

      -- Perform a backup
      IF NOT EXISTS (SELECT * FROM @CurrentDirectories WHERE CreateOutput <> 0 OR CreateOutput IS NULL)
      BEGIN
        IF @BackupSoftware IS NULL
        BEGIN
          SELECT @CurrentCommandType02 = CASE
          WHEN @CurrentBackupType IN('DIFF','FULL') THEN 'BACKUP_DATABASE'
          WHEN @CurrentBackupType = 'LOG' THEN 'BACKUP_LOG'
          END

          SELECT @CurrentCommand02 = CASE
          WHEN @CurrentBackupType IN('DIFF','FULL') THEN 'BACKUP DATABASE ' + QUOTENAME(@CurrentDatabaseName)
          WHEN @CurrentBackupType = 'LOG' THEN 'BACKUP LOG ' + QUOTENAME(@CurrentDatabaseName)
          END

          IF @ReadWriteFileGroups = 'Y' SET @CurrentCommand02 = @CurrentCommand02 + ' READ_WRITE_FILEGROUPS'

          SET @CurrentCommand02 = @CurrentCommand02 + ' TO'

          SELECT @CurrentCommand02 = @CurrentCommand02 + ' DISK = N''' + REPLACE(CurrentFilePath,'''','''''') + '''' + CASE WHEN ROW_NUMBER() OVER (ORDER BY CurrentFilePath ASC) <> @CurrentDBBackupFiles THEN ',' ELSE '' END
          FROM @CurrentFiles
          ORDER BY CurrentFilePath ASC

          SET @CurrentCommand02 = @CurrentCommand02 + ' WITH '
          IF @CheckSum = 'Y' SET @CurrentCommand02 = @CurrentCommand02 + 'CHECKSUM'
          IF @CheckSum = 'N' SET @CurrentCommand02 = @CurrentCommand02 + 'NO_CHECKSUM'
          IF @Compress = 'Y' SET @CurrentCommand02 = @CurrentCommand02 + ', COMPRESSION'
          IF @Compress = 'N' AND @Version >= 10 SET @CurrentCommand02 = @CurrentCommand02 + ', NO_COMPRESSION'
          IF @CurrentBackupType = 'DIFF' SET @CurrentCommand02 = @CurrentCommand02 + ', DIFFERENTIAL'
          IF @CopyOnly = 'Y' SET @CurrentCommand02 = @CurrentCommand02 + ', COPY_ONLY'
          IF @BlockSize IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', BLOCKSIZE = ' + CAST(@BlockSize AS nvarchar)
          IF @BufferCount IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', BUFFERCOUNT = ' + CAST(@BufferCount AS nvarchar)
          IF @MaxTransferSize IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', MAXTRANSFERSIZE = ' + CAST(@MaxTransferSize AS nvarchar)
          IF @Description IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', DESCRIPTION = N''' + REPLACE(@Description,'''','''''') + ''''
        END

        IF @BackupSoftware = 'LITESPEED'
        BEGIN
          SELECT @CurrentCommandType02 = CASE
          WHEN @CurrentBackupType IN('DIFF','FULL') THEN 'xp_backup_database'
          WHEN @CurrentBackupType = 'LOG' THEN 'xp_backup_log'
          END

          SELECT @CurrentCommand02 = CASE
          WHEN @CurrentBackupType IN('DIFF','FULL') THEN 'DECLARE @ReturnCode int EXECUTE @ReturnCode = [master].dbo.xp_backup_database @database = N''' + REPLACE(@CurrentDatabaseName,'''','''''') + ''''
          WHEN @CurrentBackupType = 'LOG' THEN 'DECLARE @ReturnCode int EXECUTE @ReturnCode = [master].dbo.xp_backup_log @database = N''' + REPLACE(@CurrentDatabaseName,'''','''''') + ''''
          END

          SELECT @CurrentCommand02 = @CurrentCommand02 + ', @filename = N''' + REPLACE(CurrentFilePath,'''','''''') + ''''
          FROM @CurrentFiles
          ORDER BY CurrentFilePath ASC

          SET @CurrentCommand02 = @CurrentCommand02 + ', @with = '''
          IF @CheckSum = 'Y' SET @CurrentCommand02 = @CurrentCommand02 + 'CHECKSUM'
          IF @CheckSum = 'N' SET @CurrentCommand02 = @CurrentCommand02 + 'NO_CHECKSUM'
          IF @CurrentBackupType = 'DIFF' SET @CurrentCommand02 = @CurrentCommand02 + ', DIFFERENTIAL'
          IF @CopyOnly = 'Y' SET @CurrentCommand02 = @CurrentCommand02 + ', COPY_ONLY'
          IF @BlockSize IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', BLOCKSIZE = ' + CAST(@BlockSize AS nvarchar)
          SET @CurrentCommand02 = @CurrentCommand02 + ''''
          IF @ReadWriteFileGroups = 'Y' SET @CurrentCommand02 = @CurrentCommand02 + ', @read_write_filegroups = 1'
          IF @CompressionLevel IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', @compressionlevel = ' + CAST(@CompressionLevel AS nvarchar)
          IF @BufferCount IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', @buffercount = ' + CAST(@BufferCount AS nvarchar)
          IF @MaxTransferSize IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', @maxtransfersize = ' + CAST(@MaxTransferSize AS nvarchar)
          IF @Threads IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', @threads = ' + CAST(@Threads AS nvarchar)
          IF @Throttle IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', @throttle = ' + CAST(@Throttle AS nvarchar)
          IF @Description IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', @desc = N''' + REPLACE(@Description,'''','''''') + ''''

          IF @EncryptionType IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', @cryptlevel = ' + CASE
          WHEN @EncryptionType = 'RC2-40' THEN '0'
          WHEN @EncryptionType = 'RC2-56' THEN '1'
          WHEN @EncryptionType = 'RC2-112' THEN '2'
          WHEN @EncryptionType = 'RC2-128' THEN '3'
          WHEN @EncryptionType = '3DES-168' THEN '4'
          WHEN @EncryptionType = 'RC4-128' THEN '5'
          WHEN @EncryptionType = 'AES-128' THEN '6'
          WHEN @EncryptionType = 'AES-192' THEN '7'
          WHEN @EncryptionType = 'AES-256' THEN '8'
          END

          IF @EncryptionKey IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', @encryptionkey = N''' + REPLACE(@EncryptionKey,'''','''''') + ''''
          SET @CurrentCommand02 = @CurrentCommand02 + ' IF @ReturnCode <> 0 RAISERROR(''Error performing LiteSpeed backup.'', 16, 1)'
        END

        IF @BackupSoftware = 'SQLBACKUP'
        BEGIN
          SET @CurrentCommandType02 = 'sqlbackup'

          SELECT @CurrentCommand02 = CASE
          WHEN @CurrentBackupType IN('DIFF','FULL') THEN 'BACKUP DATABASE ' + QUOTENAME(@CurrentDatabaseName)
          WHEN @CurrentBackupType = 'LOG' THEN 'BACKUP LOG ' + QUOTENAME(@CurrentDatabaseName)
          END

          IF @ReadWriteFileGroups = 'Y' SET @CurrentCommand02 = @CurrentCommand02 + ' READ_WRITE_FILEGROUPS'

          SET @CurrentCommand02 = @CurrentCommand02 + ' TO'

          SELECT @CurrentCommand02 = @CurrentCommand02 + ' DISK = N''' + REPLACE(CurrentFilePath,'''','''''') + '''' + CASE WHEN ROW_NUMBER() OVER (ORDER BY CurrentFilePath ASC) <> @CurrentDBBackupFiles THEN ',' ELSE '' END
          FROM @CurrentFiles
          ORDER BY CurrentFilePath ASC

          SET @CurrentCommand02 = @CurrentCommand02 + ' WITH '
          IF @CheckSum = 'Y' SET @CurrentCommand02 = @CurrentCommand02 + 'CHECKSUM'
          IF @CheckSum = 'N' SET @CurrentCommand02 = @CurrentCommand02 + 'NO_CHECKSUM'
          IF @CurrentBackupType = 'DIFF' SET @CurrentCommand02 = @CurrentCommand02 + ', DIFFERENTIAL'
          IF @CopyOnly = 'Y' SET @CurrentCommand02 = @CurrentCommand02 + ', COPY_ONLY'
          IF @CompressionLevel IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', COMPRESSION = ' + CAST(@CompressionLevel AS nvarchar)
          IF @Threads IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', THREADCOUNT = ' + CAST(@Threads AS nvarchar)
          IF @MaxTransferSize IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', MAXTRANSFERSIZE = ' + CAST(@MaxTransferSize AS nvarchar)
          IF @Description IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', DESCRIPTION = N''' + REPLACE(@Description,'''','''''') + ''''

          IF @EncryptionType IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', KEYSIZE = ' + CASE
          WHEN @EncryptionType = 'AES-128' THEN '128'
          WHEN @EncryptionType = 'AES-256' THEN '256'
          END

          IF @EncryptionKey IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', PASSWORD = N''' + REPLACE(@EncryptionKey,'''','''''') + ''''
          SET @CurrentCommand02 = 'DECLARE @ReturnCode int EXECUTE @ReturnCode = [master].dbo.sqlbackup N''-SQL "' + REPLACE(@CurrentCommand02,'''','''''') + '"''' + ' IF @ReturnCode <> 0 RAISERROR(''Error performing SQLBackup backup.'', 16, 1)'
        END

        IF @BackupSoftware = 'HYPERBAC'
        BEGIN
          SET @CurrentCommandType02 = 'BACKUP_DATABASE'

          SELECT @CurrentCommand02 = CASE
          WHEN @CurrentBackupType IN('DIFF','FULL') THEN 'BACKUP DATABASE ' + QUOTENAME(@CurrentDatabaseName)
          WHEN @CurrentBackupType = 'LOG' THEN 'BACKUP LOG ' + QUOTENAME(@CurrentDatabaseName)
          END

          IF @ReadWriteFileGroups = 'Y' SET @CurrentCommand02 = @CurrentCommand02 + ' READ_WRITE_FILEGROUPS'

          SET @CurrentCommand02 = @CurrentCommand02 + ' TO'

          SELECT @CurrentCommand02 = @CurrentCommand02 + ' DISK = N''' + REPLACE(CurrentFilePath,'''','''''') + '''' + CASE WHEN ROW_NUMBER() OVER (ORDER BY CurrentFilePath ASC) <> @CurrentDBBackupFiles THEN ',' ELSE '' END
          FROM @CurrentFiles
          ORDER BY CurrentFilePath ASC

          SET @CurrentCommand02 = @CurrentCommand02 + ' WITH '
          IF @CheckSum = 'Y' SET @CurrentCommand02 = @CurrentCommand02 + 'CHECKSUM'
          IF @CheckSum = 'N' SET @CurrentCommand02 = @CurrentCommand02 + 'NO_CHECKSUM'
          IF @CurrentBackupType = 'DIFF' SET @CurrentCommand02 = @CurrentCommand02 + ', DIFFERENTIAL'
          IF @CopyOnly = 'Y' SET @CurrentCommand02 = @CurrentCommand02 + ', COPY_ONLY'
          IF @BlockSize IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', BLOCKSIZE = ' + CAST(@BlockSize AS nvarchar)
          IF @BufferCount IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', BUFFERCOUNT = ' + CAST(@BufferCount AS nvarchar)
          IF @MaxTransferSize IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', MAXTRANSFERSIZE = ' + CAST(@MaxTransferSize AS nvarchar)
          IF @Description IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', DESCRIPTION = N''' + REPLACE(@Description,'''','''''') + ''''
        END

        IF @BackupSoftware = 'SQLSAFE'
        BEGIN
          SET @CurrentCommandType02 = 'xp_ss_backup'

          SET @CurrentCommand02 = 'DECLARE @ReturnCode int EXECUTE @ReturnCode = [master].dbo.xp_ss_backup @database = N''' + REPLACE(@CurrentDatabaseName,'''','''''') + ''''

          SELECT @CurrentCommand02 = @CurrentCommand02 + ', ' + CASE WHEN ROW_NUMBER() OVER (ORDER BY CurrentFilePath ASC) = 1 THEN '@filename' ELSE '@backupfile' END + ' = N''' + REPLACE(CurrentFilePath,'''','''''') + ''''
          FROM @CurrentFiles
          ORDER BY CurrentFilePath ASC

          SET @CurrentCommand02 = @CurrentCommand02 + ', @backuptype = ' + CASE WHEN @CurrentBackupType = 'FULL' THEN '''Full''' WHEN @CurrentBackupType = 'DIFF' THEN '''Differential''' WHEN @CurrentBackupType = 'LOG' THEN '''Log''' END
          IF @ReadWriteFileGroups = 'Y' SET @CurrentCommand02 = @CurrentCommand02 + ', @readwritefilegroups = 1'
          SET @CurrentCommand02 = @CurrentCommand02 + ', @checksum = ' + CASE WHEN @CheckSum = 'Y' THEN '1' WHEN @CheckSum = 'N' THEN '0' END
          SET @CurrentCommand02 = @CurrentCommand02 + ', @copyonly = ' + CASE WHEN @CopyOnly = 'Y' THEN '1' WHEN @CopyOnly = 'N' THEN '0' END
          IF @CompressionLevel IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', @compressionlevel = ' + CAST(@CompressionLevel AS nvarchar)
          IF @Threads IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', @threads = ' + CAST(@Threads AS nvarchar)
          IF @Description IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', @desc = N''' + REPLACE(@Description,'''','''''') + ''''

          IF @EncryptionType IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', @encryptiontype = N''' + CASE
          WHEN @EncryptionType = 'AES-128' THEN 'AES128'
          WHEN @EncryptionType = 'AES-256' THEN 'AES256'
          END + ''''

          IF @EncryptionKey IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', @encryptedbackuppassword = N''' + REPLACE(@EncryptionKey,'''','''''') + ''''
          SET @CurrentCommand02 = @CurrentCommand02 + ' IF @ReturnCode <> 0 RAISERROR(''Error performing SQLsafe backup.'', 16, 1)'
        END

        IF @BackupSoftware = 'MSBP'
        BEGIN

          SELECT @CurrentCommandType02 = CASE
          WHEN @CurrentBackupType IN('DIFF','FULL') THEN 'BACKUP_DATABASE'
          WHEN @CurrentBackupType = 'LOG' THEN 'BACKUP_LOG'
          END

          SET @CurrentCommand02 = 'xp_cmdshell ''c:\msbp\msbp.exe backup "db(database=' + @CurrentDatabaseName + ';'

          IF @CurrentBackupType = 'FULL' SET @CurrentCommand02 = @CurrentCommand02 + 'backuptype=full;'
          IF @CurrentBackupType = 'DIFF' SET @CurrentCommand02 = @CurrentCommand02 + 'backuptype=differential;'
          IF @CurrentBackupType = 'LOG' SET @CurrentCommand02 = @CurrentCommand02 + 'backuptype=log;'

          IF @ReadWriteFileGroups = 'Y' SET @CurrentCommand02 = @CurrentCommand02 + 'READ_WRITE_FILEGROUPS;'
          IF @CheckSum = 'Y' SET @CurrentCommand02 = @CurrentCommand02 + 'CHECKSUM;'
          IF @CheckSum = 'N' SET @CurrentCommand02 = @CurrentCommand02 + 'NO_CHECKSUM;'
          
          IF @CopyOnly = 'Y' SET @CurrentCommand02 = @CurrentCommand02 + 'COPY_ONLY;'
          IF @BufferCount IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + 'buffercount=' + CAST(@BufferCount AS nvarchar) + ';'
          IF @MaxTransferSize IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + 'maxtransfersize=' + CAST(@MaxTransferSize AS nvarchar) + ';'

          -- Actualmente no soportado

          --IF @BlockSize IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', BLOCKSIZE = ' + CAST(@BlockSize AS nvarchar)                 
          --IF @Description IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + ', DESCRIPTION = N''' + REPLACE(@Description,'''','''''') + ''''
          
          IF @Compress = 'Y' 
          BEGIN
            SET @CurrentCommand02 = @CurrentCommand02 + ')" "gzip('
            IF @CompressionLevel IS NOT NULL SET @CurrentCommand02 = @CurrentCommand02 + 'level='+ CAST(@CompressionLevel AS nvarchar)
            SET @CurrentCommand02 = @CurrentCommand02 + ')"'
          END

          SET @CurrentCommand02 = @CurrentCommand02 + ' "local('

          SELECT @CurrentCommand02 = @CurrentCommand02 + 'path=' + REPLACE(CurrentFilePath,'''','''''') + CASE WHEN ROW_NUMBER() OVER (ORDER BY CurrentFilePath ASC) <> @CurrentDBBackupFiles THEN ';' ELSE '' END
          FROM @CurrentFiles
          ORDER BY CurrentFilePath ASC

          SET @CurrentCommand02 = @CurrentCommand02 + ')"'''


        END

        EXECUTE @CurrentCommandOutput02 = [dbo].[CommandExecute] @Command = @CurrentCommand02, @CommandType = @CurrentCommandType02, @Mode = 1, @DatabaseName = @CurrentDatabaseName, @LogToTable = @LogToTable, @Execute = @Execute
        SET @Error = @@ERROR
        IF @Error <> 0 SET @CurrentCommandOutput02 = @Error
        IF @CurrentCommandOutput02 <> 0 SET @ReturnCode = @CurrentCommandOutput02
      END

	--Generate the resore script
     IF @CurrentCommandOutput02 = 0
      BEGIN
        IF @BackupSoftware IS NULL
        BEGIN
		  IF @Databases = 'SYSTEM_DATABASES'
			SET @CurrentCommandType05='RESTORE_SYSTEM_DATABASE'
		  ELSE
			  SELECT @CurrentCommandType05 = CASE
			  WHEN @CurrentBackupType = 'FULL' THEN 'RESTORE_DATABASE' 
			  WHEN @CurrentBackupType = 'DIFF' THEN 'RESTORE_DIFFERENTIAL' 
			  WHEN @CurrentBackupType = 'LOG'  THEN 'RESTORE_LOG' 
			  END

          SELECT @CurrentCommand05= CASE
          WHEN @CurrentBackupType IN('DIFF','FULL') THEN 'RESTORE DATABASE ' + QUOTENAME(@CurrentDatabaseName) + ' FROM'
          WHEN @CurrentBackupType = 'LOG' THEN 'RESTORE LOG ' + QUOTENAME(@CurrentDatabaseName) + ' FROM'
          END

          SELECT @CurrentCommand05 = @CurrentCommand05 + ' DISK = N''' + REPLACE(CurrentFilePath,'''','''''') + '''' + CASE WHEN ROW_NUMBER() OVER (ORDER BY CurrentFilePath ASC) <> @CurrentDBBackupFiles THEN ',' ELSE '' END
          FROM @CurrentFiles
          ORDER BY CurrentFilePath ASC

          SET @CurrentCommand05 = @CurrentCommand05 + ' WITH FILE = 1, NORECOVERY,' + CASE when ((upper(@CurrentBackupType)='FULL')) then ' REPLACE,' else '' end + ' NOUNLOAD'
          IF @CheckSum = 'Y' SET @CurrentCommand05 = @CurrentCommand05 + ' ,CHECKSUM'

          SELECT @CurrentCommand05=@CurrentCommand05 + ' ,MOVE N''' + name + ''' TO N''' + 
					CASE 
/* Data file*/			WHEN type=0 then dbo.MoveDBfile(physical_name, '')
/* Log file*/			WHEN type=1 then dbo.MoveDBfile(physical_name, '') 
/* Filestream file*/	WHEN type=2 then dbo.MoveDBfile(physical_name, '') 
/* Full Text file*/		WHEN type=4 then dbo.MoveDBfile(physical_name, '') 
					END
			+ ''''
          FROM sys.master_files
          WHERE database_id=@CurrentDatabaseID
        END

        IF @BackupSoftware = 'MSBP'
        BEGIN
          IF @Databases = 'SYSTEM_DATABASES'
          SET @CurrentCommandType05='RESTORE_SYSTEM_DATABASE'
        ELSE
          SELECT @CurrentCommandType05 = CASE
          WHEN @CurrentBackupType = 'FULL' THEN 'RESTORE_DATABASE' 
          WHEN @CurrentBackupType = 'DIFF' THEN 'RESTORE_DIFFERENTIAL' 
          WHEN @CurrentBackupType = 'LOG'  THEN 'RESTORE_LOG' 
          END


          SET @CurrentCommand05 = 'xp_cmdshell ''c:\msbp\msbp.exe restore'

          SET @CurrentCommand05 = @CurrentCommand05 + ' "local('

          SELECT @CurrentCommand05 = @CurrentCommand05 + 'path=' + REPLACE(CurrentFilePath,'''','''''') + CASE WHEN ROW_NUMBER() OVER (ORDER BY CurrentFilePath ASC) <> @CurrentDBBackupFiles THEN ';' ELSE '' END
          FROM @CurrentFiles
          ORDER BY CurrentFilePath ASC

          SET @CurrentCommand05 = @CurrentCommand05 + ')"'

          IF @Compress = 'Y' SET @CurrentCommand05 = @CurrentCommand05 + ' "gzip()"'

            -- FILE=1 ???

          SET @CurrentCommand05 = @CurrentCommand05 + ' "db(database=' + @CurrentDatabaseName + ';NORECOVERY;'
          IF @CurrentBackupType = 'FULL' SET @CurrentCommand05 = @CurrentCommand05 + 'replace;restoretype=database;'
          IF @CurrentBackupType = 'DIFF' SET @CurrentCommand05 = @CurrentCommand05 + 'restoretype=database;'
          IF @CurrentBackupType = 'LOG' SET @CurrentCommand05 = @CurrentCommand05 + 'restoretype=log;'
          IF @CheckSum = 'Y' SET @CurrentCommand05 = @CurrentCommand05 + 'CHECKSUM;'
          IF @CheckSum = 'N' SET @CurrentCommand05 = @CurrentCommand05 + 'NO_CHECKSUM;'

          SELECT @CurrentCommand05=@CurrentCommand05 + 'MOVE=''''' + name + '''''TO''''' + 
          CASE 
/* Data file*/      WHEN type=0 then dbo.MoveDBfile(physical_name, '')    + ''''';'
/* Log file*/     WHEN type=1 then dbo.MoveDBfile(physical_name, '')      + ''''';'
/* Filestream file*/  WHEN type=2 then dbo.MoveDBfile(physical_name, '')  + ''''';'
/* Full Text file*/   WHEN type=4 then dbo.MoveDBfile(physical_name, '')  + ''''';'
          END
          FROM sys.master_files
          WHERE database_id=@CurrentDatabaseID
        END
        
        SET @CurrentCommand05 = @CurrentCommand05 + ')"'''

        EXECUTE @CurrentCommandOutput05 = [dbo].[CommandExecute] @Command = @CurrentCommand05, @CommandType = @CurrentCommandType05, @Mode = 1, @DatabaseName = @CurrentDatabaseName, @LogToTable = @LogToTable, @Execute = 'N'
        SET @Error = @@ERROR
        IF @Error <> 0 SET @CurrentCommandOutput05 = @Error
        IF @CurrentCommandOutput05 <> 0 SET @ReturnCode = @CurrentCommandOutput05
        
      END

      -- Verify the backup
      IF @CurrentCommandOutput02 = 0 AND @Verify = 'Y'
      BEGIN
        IF @BackupSoftware IS NULL
        BEGIN
          SET @CurrentCommandType03 = 'RESTORE_VERIFYONLY'

          SET @CurrentCommand03 = 'RESTORE VERIFYONLY FROM'

          SELECT @CurrentCommand03 = @CurrentCommand03 + ' DISK = N''' + REPLACE(CurrentFilePath,'''','''''') + '''' + CASE WHEN ROW_NUMBER() OVER (ORDER BY CurrentFilePath ASC) <> @CurrentDBBackupFiles THEN ',' ELSE '' END
          FROM @CurrentFiles
          ORDER BY CurrentFilePath ASC

          SET @CurrentCommand03 = @CurrentCommand03 + ' WITH '
          IF @CheckSum = 'Y' SET @CurrentCommand03 = @CurrentCommand03 + 'CHECKSUM'
          IF @CheckSum = 'N' SET @CurrentCommand03 = @CurrentCommand03 + 'NO_CHECKSUM'
        END

        IF @BackupSoftware = 'LITESPEED'
        BEGIN
          SET @CurrentCommandType03 = 'xp_restore_verifyonly'

          SET @CurrentCommand03 = 'DECLARE @ReturnCode int EXECUTE @ReturnCode = [master].dbo.xp_restore_verifyonly'

          SELECT @CurrentCommand03 = @CurrentCommand03 + ' @filename = N''' + REPLACE(CurrentFilePath,'''','''''') + '''' + CASE WHEN ROW_NUMBER() OVER (ORDER BY CurrentFilePath ASC) <> @CurrentDBBackupFiles THEN ',' ELSE '' END
          FROM @CurrentFiles
          ORDER BY CurrentFilePath ASC

          SET @CurrentCommand03 = @CurrentCommand03 + ', @with = '''
          IF @CheckSum = 'Y' SET @CurrentCommand03 = @CurrentCommand03 + 'CHECKSUM'
          IF @CheckSum = 'N' SET @CurrentCommand03 = @CurrentCommand03 + 'NO_CHECKSUM'
          SET @CurrentCommand03 = @CurrentCommand03 + ''''
          IF @EncryptionKey IS NOT NULL SET @CurrentCommand03 = @CurrentCommand03 + ', @encryptionkey = N''' + REPLACE(@EncryptionKey,'''','''''') + ''''

          SET @CurrentCommand03 = @CurrentCommand03 + ' IF @ReturnCode <> 0 RAISERROR(''Error verifying LiteSpeed backup.'', 16, 1)'
        END

        IF @BackupSoftware = 'SQLBACKUP'
        BEGIN
          SET @CurrentCommandType03 = 'sqlbackup'

          SET @CurrentCommand03 = 'RESTORE VERIFYONLY FROM'

          SELECT @CurrentCommand03 = @CurrentCommand03 + ' DISK = N''' + REPLACE(CurrentFilePath,'''','''''') + '''' + CASE WHEN ROW_NUMBER() OVER (ORDER BY CurrentFilePath ASC) <> @CurrentDBBackupFiles THEN ',' ELSE '' END
          FROM @CurrentFiles
          ORDER BY CurrentFilePath ASC

          SET @CurrentCommand03 = @CurrentCommand03 + ' WITH '
          IF @CheckSum = 'Y' SET @CurrentCommand03 = @CurrentCommand03 + 'CHECKSUM'
          IF @CheckSum = 'N' SET @CurrentCommand03 = @CurrentCommand03 + 'NO_CHECKSUM'
          IF @EncryptionKey IS NOT NULL SET @CurrentCommand03 = @CurrentCommand03 + ', PASSWORD = N''' + REPLACE(@EncryptionKey,'''','''''') + ''''

          SET @CurrentCommand03 = 'DECLARE @ReturnCode int EXECUTE @ReturnCode = [master].dbo.sqlbackup N''-SQL "' + REPLACE(@CurrentCommand03,'''','''''') + '"''' + ' IF @ReturnCode <> 0 RAISERROR(''Error verifying SQLBackup backup.'', 16, 1)'
        END

        IF @BackupSoftware = 'HYPERBAC'
        BEGIN
          SET @CurrentCommandType03 = 'RESTORE_VERIFYONLY'

          SET @CurrentCommand03 = 'RESTORE VERIFYONLY FROM'

          SELECT @CurrentCommand03 = @CurrentCommand03 + ' DISK = N''' + REPLACE(CurrentFilePath,'''','''''') + '''' + CASE WHEN ROW_NUMBER() OVER (ORDER BY CurrentFilePath ASC) <> @CurrentDBBackupFiles THEN ',' ELSE '' END
          FROM @CurrentFiles
          ORDER BY CurrentFilePath ASC

          SET @CurrentCommand03 = @CurrentCommand03 + ' WITH '
          IF @CheckSum = 'Y' SET @CurrentCommand03 = @CurrentCommand03 + 'CHECKSUM'
          IF @CheckSum = 'N' SET @CurrentCommand03 = @CurrentCommand03 + 'NO_CHECKSUM'
        END

        IF @BackupSoftware = 'MSBP'
        BEGIN
          SET @CurrentCommandType03 = 'RESTORE_VERIFYONLY'

          SET @CurrentCommand03 = 'xp_cmdshell ''c:\msbp\msbp.exe restore'

          SET @CurrentCommand03 = @CurrentCommand03 + ' "local('

          SELECT @CurrentCommand03 = @CurrentCommand03 + 'path=' + REPLACE(CurrentFilePath,'''','''''') + CASE WHEN ROW_NUMBER() OVER (ORDER BY CurrentFilePath ASC) <> @CurrentDBBackupFiles THEN ';' ELSE '' END
          FROM @CurrentFiles
          ORDER BY CurrentFilePath ASC

          SET @CurrentCommand03 = @CurrentCommand03 + ')"'

          IF @Compress = 'Y' SET @CurrentCommand03 = @CurrentCommand03 + ' "gzip()"'

          SET @CurrentCommand03 = @CurrentCommand03 + ' "db(database=' + @CurrentDatabaseName + ';'
          SET @CurrentCommand03 = @CurrentCommand03 + 'restoretype=verifyonly;'
          IF @CheckSum = 'Y' SET @CurrentCommand03 = @CurrentCommand03 + 'CHECKSUM;'
          IF @CheckSum = 'N' SET @CurrentCommand03 = @CurrentCommand03 + 'NO_CHECKSUM;'

          SET @CurrentCommand03 = @CurrentCommand03 + ')"'''

        END

        IF @BackupSoftware = 'SQLSAFE'
        BEGIN
          SET @CurrentCommandType03 = 'xp_ss_verify'

          SET @CurrentCommand03 = 'DECLARE @ReturnCode int EXECUTE @ReturnCode = [master].dbo.xp_ss_verify @database = N''' + REPLACE(@CurrentDatabaseName,'''','''''') + ''''

          SELECT @CurrentCommand03 = @CurrentCommand03 + ', ' + CASE WHEN ROW_NUMBER() OVER (ORDER BY CurrentFilePath ASC) = 1 THEN '@filename' ELSE '@backupfile' END + ' = N''' + REPLACE(CurrentFilePath,'''','''''') + ''''
          FROM @CurrentFiles
          ORDER BY CurrentFilePath ASC

          SET @CurrentCommand03 = @CurrentCommand03 + ' IF @ReturnCode <> 0 RAISERROR(''Error verifying SQLsafe backup.'', 16, 1)'
        END

        EXECUTE @CurrentCommandOutput03 = [dbo].[CommandExecute] @Command = @CurrentCommand03, @CommandType = @CurrentCommandType03, @Mode = 1, @DatabaseName = @CurrentDatabaseName, @LogToTable = @LogToTable, @Execute = @Execute
        SET @Error = @@ERROR
        IF @Error <> 0 SET @CurrentCommandOutput03 = @Error
        IF @CurrentCommandOutput03 <> 0 SET @ReturnCode = @CurrentCommandOutput03
      END




      -- Delete old backup files
      IF (@CurrentCommandOutput02 = 0 AND @Verify = 'N' AND @CurrentCleanupDate IS NOT NULL)
      OR (@CurrentCommandOutput02 = 0 AND @Verify = 'Y' AND @CurrentCommandOutput03 = 0 AND @CurrentCleanupDate IS NOT NULL)
      BEGIN
        WHILE EXISTS (SELECT * FROM @CurrentDirectories WHERE CleanupCompleted = 0)
        BEGIN
          SELECT TOP 1 @CurrentDirectoryID = ID,
                       @CurrentDirectoryPath = DirectoryPath
          FROM @CurrentDirectories
          WHERE CleanupCompleted = 0
          ORDER BY ID ASC

          IF @BackupSoftware IS NULL or @BackupSoftware = 'MSBP'
          BEGIN
            SET @CurrentCommandType04 = 'xp_delete_file'

            SET @CurrentCommand04 = 'DECLARE @ReturnCode int EXECUTE @ReturnCode = [master].dbo.xp_delete_file 0, N''' + REPLACE(@CurrentDirectoryPath,'''','''''') + ''', ''' + @CurrentFileExtension + ''', ''' + CONVERT(nvarchar(19),@CurrentCleanupDate,126) + ''' IF @ReturnCode <> 0 RAISERROR(''Error deleting files.'', 16, 1)'
          END

          IF @BackupSoftware = 'LITESPEED'
          BEGIN
            SET @CurrentCommandType04 = 'xp_slssqlmaint'

            SET @CurrentCommand04 = 'DECLARE @ReturnCode int EXECUTE @ReturnCode = [master].dbo.xp_slssqlmaint N''-MAINTDEL -DELFOLDER "' + REPLACE(@CurrentDirectoryPath,'''','''''') + '" -DELEXTENSION "' + @CurrentFileExtension + '" -DELUNIT "' + CAST(DATEDIFF(mi,@CurrentCleanupDate,GETDATE()) + 1 AS nvarchar) + '" -DELUNITTYPE "minutes" -DELUSEAGE'' IF @ReturnCode <> 0 RAISERROR(''Error deleting LiteSpeed backup files.'', 16, 1)'
          END

          IF @BackupSoftware = 'SQLBACKUP'
          BEGIN
            SET @CurrentCommandType04 = 'sqbutility'

            SET @CurrentCommand04 = 'DECLARE @ReturnCode int EXECUTE @ReturnCode = [master].dbo.sqbutility 1032, N''' + REPLACE(@CurrentDatabaseName,'''','''''') + ''', N''' + REPLACE(@CurrentDirectoryPath,'''','''''') + ''', ''' + CASE WHEN @CurrentBackupType = 'FULL' THEN 'D' WHEN @CurrentBackupType = 'DIFF' THEN 'I' WHEN @CurrentBackupType = 'LOG' THEN 'L' END + ''', ''' + CAST(DATEDIFF(hh,@CurrentCleanupDate,GETDATE()) + 1 AS nvarchar) + 'h'', ' + ISNULL('''' + REPLACE(@EncryptionKey,'''','''''') + '''','NULL') + ' IF @ReturnCode <> 0 RAISERROR(''Error deleting SQLBackup backup files.'', 16, 1)'
          END

          IF @BackupSoftware = 'HYPERBAC'
          BEGIN
            SET @CurrentCommandType04 = 'xp_delete_file'

            SET @CurrentCommand04 = 'DECLARE @ReturnCode int EXECUTE @ReturnCode = [master].dbo.xp_delete_file 0, N''' + REPLACE(@CurrentDirectoryPath,'''','''''') + ''', ''' + @CurrentFileExtension + ''', ''' + CONVERT(nvarchar(19),@CurrentCleanupDate,126) + ''' IF @ReturnCode <> 0 RAISERROR(''Error deleting files.'', 16, 1)'
          END

          IF @BackupSoftware = 'SQLSAFE'
          BEGIN
            SET @CurrentCommandType04 = 'xp_ss_delete'

            SET @CurrentCommand04 = 'DECLARE @ReturnCode int EXECUTE @ReturnCode = [master].dbo.xp_ss_delete @filename = N''' + REPLACE(@CurrentDirectoryPath,'''','''''') + '\*.' + @CurrentFileExtension + ''', @age = ''' + CAST(DATEDIFF(mi,@CurrentCleanupDate,GETDATE()) + 1 AS nvarchar) + 'Minutes'' IF @ReturnCode <> 0 RAISERROR(''Error deleting SQLsafe backup files.'', 16, 1)'
          END

          EXECUTE @CurrentCommandOutput04 = [dbo].[CommandExecute] @Command = @CurrentCommand04, @CommandType = @CurrentCommandType04, @Mode = 1, @DatabaseName = @CurrentDatabaseName, @LogToTable = @LogToTable, @Execute = @Execute
          SET @Error = @@ERROR
          IF @Error <> 0 SET @CurrentCommandOutput04 = @Error
          IF @CurrentCommandOutput04 <> 0 SET @ReturnCode = @CurrentCommandOutput04

          UPDATE @CurrentDirectories
          SET CleanupCompleted = 1,
              CleanupOutput = @CurrentCommandOutput04
          WHERE ID = @CurrentDirectoryID

          SET @CurrentDirectoryID = NULL
          SET @CurrentDirectoryPath = NULL

          SET @CurrentCommand04 = NULL

          SET @CurrentCommandOutput04 = NULL

          SET @CurrentCommandType04 = NULL
        END
      END
    END

    -- Update that the database is completed
    UPDATE @tmpDatabases
    SET Completed = 1
    WHERE Selected = 1
    AND Completed = 0
    AND ID = @CurrentDBID

    -- Clear variables
    SET @CurrentDBID = NULL
    SET @CurrentDatabaseID = NULL
    SET @CurrentDatabaseName = NULL
    SET @CurrentBackupType = NULL
    SET @CurrentFileExtension = NULL
    SET @CurrentFileNumber = NULL
    SET @CurrentDifferentialBaseLSN = NULL
    SET @CurrentDifferentialBaseIsSnapshot = NULL
    SET @CurrentLogLSN = NULL
    SET @CurrentLatestBackup = NULL
    SET @CurrentDatabaseNameFS = NULL
    SET @CurrentDate = NULL
    SET @CurrentCleanupDate = NULL
    SET @CurrentIsDatabaseAccessible = NULL
    SET @CurrentAvailabilityGroup = NULL
    SET @CurrentAvailabilityGroupRole = NULL
    SET @CurrentIsPreferredBackupReplica = NULL
    SET @CurrentDatabaseMirroringRole = NULL
    SET @CurrentLogShippingRole = NULL

/**/
  SET @CurrentDBSize = NULL
  SET @CurrentDBBackupFiles = NULL
  SET @CurrentDBEncryptionState = NULL 
/**/  

    SET @CurrentCommand02 = NULL
    SET @CurrentCommand03 = NULL
    SET @CurrentCommand05 = NULL

    SET @CurrentCommandOutput02 = NULL
    SET @CurrentCommandOutput03 = NULL
    SET @CurrentCommandOutput05 = NULL

    SET @CurrentCommandType02 = NULL
    SET @CurrentCommandType03 = NULL
    SET @CurrentCommandType05 = NULL

    DELETE FROM @CurrentDirectories
    DELETE FROM @CurrentFiles

  END

  ----------------------------------------------------------------------------------------------------
  --// Log completing information                                                                 //--
  ----------------------------------------------------------------------------------------------------

  Logging:
  SET @EndMessage = 'Date and time: ' + CONVERT(nvarchar,GETDATE(),120)
  SET @EndMessage = REPLACE(@EndMessage,'%','%%')
  RAISERROR(@EndMessage,10,1) WITH NOWAIT

  IF @ReturnCode <> 0
  BEGIN
    RETURN @ReturnCode
  END

  ----------------------------------------------------------------------------------------------------

END

GO

