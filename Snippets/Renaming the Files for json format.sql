/* =====================================================================================================================
-- Author:      SaiKarthik
-- Create date: 25-10-2020 19:40
-- Database:    USE master;
-- Description: This Script Rename the Files in the @Folder_Path.
			*** If @Execute =0; Then The Script will Only Show how the Files will be Renamed. If everything Looks Good,
					Then Proceed with setting @Execute =1.
			*** If @Execute =1; Then The Script will Rename the Files.
		Check the @HypenCount before changing the @Execute to "1".
===================================================================================================================== */
USE master;
GO

--
DECLARE @Folder_Path NVARCHAR(512) = N'C:\GitHub\SQLpromptSnippets\Snippets';
DECLARE @DEL_PreFix NVARCHAR(512) = N'dimensional-modeling-microsoft-sql-server-platform-';
DECLARE @DEL_PostFix NVARCHAR(512) = N' - Dime';--minimum common string for all files
--
DECLARE @Execute BIT = 0; --Change this Variable to "1" to execute the Real Process
--
DECLARE @HypenCount INT = (LEN(@DEL_PreFix + @DEL_PostFix) - LEN(REPLACE(@DEL_PreFix + @DEL_PostFix,'-',''))) + 1;--Included the Hypen in the Final New Name Also
SELECT @HypenCount AS DefaultHypenCount, LEN(@DEL_PostFix) AS PostFixLenght;
/* DoNot Change the Script from Here */
SET NOCOUNT ON;
SET XACT_ABORT ON;
--
/*Deleting the FileList.txt in the FolderPath "@Folder_Path"*/
DECLARE @DEL_FileList NVARCHAR(512);

SET @DEL_FileList = N'del /S "' + @Folder_Path + N'\FileList.txt"';
PRINT @DEL_FileList;
EXEC sys.xp_cmdshell @DEL_FileList;

--
/*Creating the FileList.txt in the FolderPath "@Folder_Path"*/
DECLARE @MK_FileList NVARCHAR(512);

SET @MK_FileList = N'for /F "tokens=*" %a in (''dir "' + @Folder_Path + N'\" /s /b'') do echo %~fa >>"' + @Folder_Path + N'\FileList.txt"';
PRINT @MK_FileList;
EXEC sys.xp_cmdshell @MK_FileList;

--
/*Creating sys.#Temp_FileList Table for Raw Data of FileList.txt*/
DECLARE @FileListImportString NVARCHAR(1024);

IF OBJECT_ID('tempdb..#Temp_FileList', 'U') IS NOT NULL
	DROP TABLE #Temp_FileList;

CREATE TABLE sys.#Temp_FileList (FileName VARCHAR(4096) NOT NULL) ON [PRIMARY];

--Inserting FileList Data into sys.#Temp_FileList Table.
SET @FileListImportString = N'BULK INSERT #Temp_FileList FROM ''' + @Folder_Path + N'\FileList.txt'' WITH (FIELDTERMINATOR  = '','', FIRSTROW = 1)';
PRINT @FileListImportString
EXEC sys.sp_executesql @FileListImportString;
SELECT * FROM #Temp_FileList AS TFL
--
IF OBJECT_ID('tempdb..#Final_FileList', 'U') IS NOT NULL
	DROP TABLE #Final_FileList;

;WITH _CTE
AS (
	SELECT FileName AS "Old_FileName",
REPLACE(SUBSTRING(FileName, 0, CHARINDEX('-', FileName, 0)) + '.json','C:\GitHub\SQLpromptSnippets\Snippets\','')
		 AS "New_FileName"
	FROM dbo.#Temp_FileList
	)
SELECT ROW_NUMBER() OVER (
		ORDER BY CTE.New_FileName
		) AS "Id",
	LTRIM(RTRIM(CTE.Old_FileName)) AS "Old_FileName",
	LTRIM(RTRIM(CTE.New_FileName)) AS "New_FileName"
INTO #Final_FileList
FROM _CTE AS CTE;

SELECT * FROM #Final_FileList AS FFL
--
    BEGIN TRANSACTION;
	--
		PRINT '/*Files ReNaming Process Started*/';
		PRINT '--';
		--
		DECLARE @i INT,	@n INT;
		--
		SELECT @i = MIN(Id), @n = MAX(Id)
		FROM #Final_FileList;
		--
		DECLARE @OldFileName VARCHAR(512),
			@NewFileName VARCHAR(512),
			@ReNameString NVARCHAR(4000);
		--
		WHILE @i <= @n
		BEGIN
			SELECT @OldFileName = Old_FileName,
				@NewFileName = New_FileName
			FROM #Final_FileList
			WHERE Id = @i;
			--
			SELECT @ReNameString = N'rename "' + @OldFileName + N'" "' + @NewFileName + N'"';
			--
			PRINT @ReNameString;
			--
			EXEC sys.xp_cmdshell @ReNameString;
			--
			PRINT 'Changed => ' + @ReNameString;
			PRINT '--';
			--
			SET @i = @i + 1;
		END;
		--
		PRINT '/*Files ReNaming Process Completed*/';
	--
	COMMIT TRANSACTION;