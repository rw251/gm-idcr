﻿--+---------------------------------------------------------------------------+
--¦ People >75 years old with haemoglobin <100 g/L or ferritin <15 ng/ml      ¦
--+---------------------------------------------------------------------------+

-------- RESEARCH DATA ENGINEER CHECK ---------

-- OUTPUT: Data with the following fields
-- Year (YYYY)
-- Month (1-12)
-- CCG (can be an anonymised id for each CCG)
-- GPPracticeId
-- NumberOfOver75WithLowHaem (integer) The number of over 75s with a haemoglobin <100 or a ferritin <15 in this year, month and for this ccg and gp
-- NumberOfOver75s (integer) The number of over 75s for this year, month, ccg and gp

-- Set the start date
DECLARE @StartDate datetime;
SET @StartDate = '2019-01-01';

--Just want the output, not the messages
SET NOCOUNT ON;

-- Create a table with all patients (ID)=========================================================================================================================
IF OBJECT_ID('tempdb..#Patients') IS NOT NULL DROP TABLE #Patients;
SELECT DISTINCT FK_Patient_Link_ID INTO #Patients FROM [RLS].vw_Patient;

-- >>> Codesets required... Inserting the code set code
--
--┌────────────────────┐
--│ Clinical code sets │
--└────────────────────┘

-- OBJECTIVE: To populate temporary tables with the existing clinical code sets.
--            See the [SQL-generation-process.md](SQL-generation-process.md) for more details.

-- INPUT: No pre-requisites

-- OUTPUT: Five temp tables as follows:
--  #AllCodes (Concept, Version, Code)
--  #CodeSets (FK_Reference_Coding_ID, Concept)
--  #SnomedSets (FK_Reference_SnomedCT_ID, FK_SNOMED_ID)
--  #VersionedCodeSets (FK_Reference_Coding_ID, Concept, Version)
--  #VersionedSnomedSets (FK_Reference_SnomedCT_ID, Version, FK_SNOMED_ID)

--!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
--!!! DO NOT EDIT THIS FILE MANUALLY !!!
--!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

IF OBJECT_ID('tempdb..#AllCodes') IS NOT NULL DROP TABLE #AllCodes;
CREATE TABLE #AllCodes (
  [Concept] [varchar](255) NOT NULL,
  [Version] INT NOT NULL,
  [Code] [varchar](20) COLLATE Latin1_General_CS_AS NOT NULL,
  [description] [varchar] (255) NULL 
);

IF OBJECT_ID('tempdb..#codesreadv2') IS NOT NULL DROP TABLE #codesreadv2;
CREATE TABLE #codesreadv2 (
  [concept] [varchar](255) NOT NULL,
  [version] INT NOT NULL,
	[code] [varchar](20) COLLATE Latin1_General_CS_AS NOT NULL,
	[term] [varchar](20) COLLATE Latin1_General_CS_AS NULL,
	[description] [varchar](255) NULL
) ON [PRIMARY];

INSERT INTO #codesreadv2
VALUES ('haemoglobin',1,'423..',NULL,'Haemoglobin estimation'),('haemoglobin',1,'423..00',NULL,'Haemoglobin estimation'),('haemoglobin',1,'423Z.',NULL,'Haemoglobin estimation NOS'),('haemoglobin',1,'423Z.00',NULL,'Haemoglobin estimation NOS'),('haemoglobin',1,'423C.',NULL,'Haemoglobin H inclusion'),('haemoglobin',1,'423C.00',NULL,'Haemoglobin H inclusion'),('haemoglobin',1,'423B.',NULL,'Haemoglobin abnormal'),('haemoglobin',1,'423B.00',NULL,'Haemoglobin abnormal')

INSERT INTO #AllCodes
SELECT [concept], [version], [code], [description] from #codesreadv2;

IF OBJECT_ID('tempdb..#codesctv3') IS NOT NULL DROP TABLE #codesctv3;
CREATE TABLE #codesctv3 (
  [concept] [varchar](255) NOT NULL,
  [version] INT NOT NULL,
	[code] [varchar](20) COLLATE Latin1_General_CS_AS NOT NULL,
	[term] [varchar](20) COLLATE Latin1_General_CS_AS NULL,
	[description] [varchar](255) NULL
) ON [PRIMARY];

INSERT INTO #codesctv3
VALUES ('haemoglobin',1,'Xa96v',NULL,'Haemoglobin concentration'),('haemoglobin',1,'XE2m6',NULL,'Haemoglobin estimation level')

INSERT INTO #AllCodes
SELECT [concept], [version], [code], [description] from #codesctv3;

IF OBJECT_ID('tempdb..#codessnomed') IS NOT NULL DROP TABLE #codessnomed;
CREATE TABLE #codessnomed (
  [concept] [varchar](255) NOT NULL,
  [version] INT NOT NULL,
	[code] [varchar](20) COLLATE Latin1_General_CS_AS NOT NULL,
	[term] [varchar](20) COLLATE Latin1_General_CS_AS NULL,
	[description] [varchar](255) NULL
) ON [PRIMARY];



INSERT INTO #AllCodes
SELECT [concept], [version], [code], [description] from #codessnomed;

IF OBJECT_ID('tempdb..#codesemis') IS NOT NULL DROP TABLE #codesemis;
CREATE TABLE #codesemis (
  [concept] [varchar](255) NOT NULL,
  [version] INT NOT NULL,
	[code] [varchar](20) COLLATE Latin1_General_CS_AS NOT NULL,
	[term] [varchar](20) COLLATE Latin1_General_CS_AS NULL,
	[description] [varchar](255) NULL
) ON [PRIMARY];



INSERT INTO #AllCodes
SELECT [concept], [version], [code], [description] from #codesemis;


IF OBJECT_ID('tempdb..#TempRefCodes') IS NOT NULL DROP TABLE #TempRefCodes;
CREATE TABLE #TempRefCodes (FK_Reference_Coding_ID BIGINT NOT NULL, concept VARCHAR(255) NOT NULL, version INT NOT NULL, [description] VARCHAR(255));

-- Read v2 codes
INSERT INTO #TempRefCodes
SELECT PK_Reference_Coding_ID, dcr.concept, dcr.[version], dcr.[description]
FROM [SharedCare].[Reference_Coding] rc
INNER JOIN #codesreadv2 dcr on dcr.code = rc.MainCode
WHERE CodingType='ReadCodeV2'
AND (dcr.term IS NULL OR dcr.term = rc.Term)
and PK_Reference_Coding_ID != -1;

-- CTV3 codes
INSERT INTO #TempRefCodes
SELECT PK_Reference_Coding_ID, dcc.concept, dcc.[version], dcc.[description]
FROM [SharedCare].[Reference_Coding] rc
INNER JOIN #codesctv3 dcc on dcc.code = rc.MainCode
WHERE CodingType='CTV3'
and PK_Reference_Coding_ID != -1;

-- EMIS codes with a FK Reference Coding ID
INSERT INTO #TempRefCodes
SELECT FK_Reference_Coding_ID, ce.concept, ce.[version], ce.[description]
FROM [SharedCare].[Reference_Local_Code] rlc
INNER JOIN #codesemis ce on ce.code = rlc.LocalCode
WHERE FK_Reference_Coding_ID != -1;

IF OBJECT_ID('tempdb..#TempSNOMEDRefCodes') IS NOT NULL DROP TABLE #TempSNOMEDRefCodes;
CREATE TABLE #TempSNOMEDRefCodes (FK_Reference_SnomedCT_ID BIGINT NOT NULL, concept VARCHAR(255) NOT NULL, [version] INT NOT NULL, [description] VARCHAR(255));

-- SNOMED codes
INSERT INTO #TempSNOMEDRefCodes
SELECT PK_Reference_SnomedCT_ID, dcs.concept, dcs.[version], dcs.[description]
FROM SharedCare.Reference_SnomedCT rs
INNER JOIN #codessnomed dcs on dcs.code = rs.ConceptID;

-- EMIS codes with a FK SNOMED ID but without a FK Reference Coding ID
INSERT INTO #TempSNOMEDRefCodes
SELECT FK_Reference_SnomedCT_ID, ce.concept, ce.[version], ce.[description]
FROM [SharedCare].[Reference_Local_Code] rlc
INNER JOIN #codesemis ce on ce.code = rlc.LocalCode
WHERE FK_Reference_Coding_ID = -1
AND FK_Reference_SnomedCT_ID != -1;

-- De-duped tables
IF OBJECT_ID('tempdb..#CodeSets') IS NOT NULL DROP TABLE #CodeSets;
CREATE TABLE #CodeSets (FK_Reference_Coding_ID BIGINT NOT NULL, concept VARCHAR(255) NOT NULL, [description] VARCHAR(255));

IF OBJECT_ID('tempdb..#SnomedSets') IS NOT NULL DROP TABLE #SnomedSets;
CREATE TABLE #SnomedSets (FK_Reference_SnomedCT_ID BIGINT NOT NULL, concept VARCHAR(255) NOT NULL, [description] VARCHAR(255));

IF OBJECT_ID('tempdb..#VersionedCodeSets') IS NOT NULL DROP TABLE #VersionedCodeSets;
CREATE TABLE #VersionedCodeSets (FK_Reference_Coding_ID BIGINT NOT NULL, Concept VARCHAR(255), [Version] INT, [description] VARCHAR(255));

IF OBJECT_ID('tempdb..#VersionedSnomedSets') IS NOT NULL DROP TABLE #VersionedSnomedSets;
CREATE TABLE #VersionedSnomedSets (FK_Reference_SnomedCT_ID BIGINT NOT NULL, Concept VARCHAR(255), [Version] INT, [description] VARCHAR(255));

INSERT INTO #VersionedCodeSets
SELECT DISTINCT * FROM #TempRefCodes;

INSERT INTO #VersionedSnomedSets
SELECT DISTINCT * FROM #TempSNOMEDRefCodes;

INSERT INTO #CodeSets
SELECT FK_Reference_Coding_ID, c.concept, [description]
FROM #VersionedCodeSets c
INNER JOIN (
  SELECT concept, MAX(version) AS maxVersion FROM #VersionedCodeSets
  GROUP BY concept)
sub ON sub.concept = c.concept AND c.version = sub.maxVersion;

INSERT INTO #SnomedSets
SELECT FK_Reference_SnomedCT_ID, c.concept, [description]
FROM #VersionedSnomedSets c
INNER JOIN (
  SELECT concept, MAX(version) AS maxVersion FROM #VersionedSnomedSets
  GROUP BY concept)
sub ON sub.concept = c.concept AND c.version = sub.maxVersion;

-- >>> Following code sets injected: haemoglobin v1


-- Create a table of all patients with haemoglobin values after the start date================================================================================================
-- All haemoglobin records
IF OBJECT_ID('tempdb..#Haemoglobin') IS NOT NULL DROP TABLE #Haemoglobin;
SELECT FK_Patient_Link_ID, EventDate, FK_Reference_Coding_ID, FK_Reference_SnomedCT_ID, Value, Units
INTO #Haemoglobin
FROM [RLS].[vw_GP_Events]
WHERE (
  FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE Concept = 'haemoglobin' AND Version = 1) OR
  FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE Concept = 'haemoglobin' AND Version = 1)
)
AND EventDate >= @StartDate AND Value IS NOT NULL;

-- Only select values as number
IF OBJECT_ID('tempdb..#HaemoglobinConvert') IS NOT NULL DROP TABLE #HaemoglobinConvert;
SELECT *, TRY_CONVERT(NUMERIC (18,5), [Value]) AS Value_new
INTO #HaemoglobinConvert
FROM #Haemoglobin
WHERE UPPER([Value]) NOT LIKE '%[A-Z]%';

-- Convert units
UPDATE
#HaemoglobinConvert
SET
Value_new = Value_new * 10
WHERE
Units = 'g(hb)/dL';

UPDATE
#HaemoglobinConvert
SET
Value_new = Value_new * 10
WHERE
Units = 'g/dL';

UPDATE
#HaemoglobinConvert
SET
Value_new = Value_new * 10
WHERE
Units = 'gm/dl';


-- Create the final table================================================================================================================================
IF OBJECT_ID('tempdb..#HaemLt100') IS NOT NULL DROP TABLE #HaemLt100;
SELECT FK_Patient_Link_ID AS PatientId, EventDate AS Date
INTO #HaemLt100
FROM #HaemoglobinConvert
WHERE Value_new > 0 AND Value_new < 100 AND 
	  (Units = 'g(hb)/dL' OR Units = 'g/dl' OR Units = 'g/L' OR Units = 'g/L (115-165) L' OR Units = 'gm/dl' OR Units = 'gm/L' OR Units = 'mmol/l');