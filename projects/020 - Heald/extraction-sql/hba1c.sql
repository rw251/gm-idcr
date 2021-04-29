--┌────────────┐
--│ HbA1c file │
--└────────────┘

-- Cohort is diabetic patients with a positive covid test

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
  [Code] [varchar](20) COLLATE Latin1_General_CS_AS NOT NULL
);

IF OBJECT_ID('tempdb..#codesreadv2') IS NOT NULL DROP TABLE #codesreadv2;
CREATE TABLE #codesreadv2 (
  [concept] [varchar](255) NOT NULL,
  [version] INT NOT NULL,
	[code] [varchar](20) COLLATE Latin1_General_CS_AS NOT NULL,
	[description] [varchar](255) NULL
) ON [PRIMARY];

INSERT INTO #codesreadv2
VALUES ('hba1c',1,'42c..00','HbA1 - diabetic control'),('hba1c',1,'42c..','HbA1 - diabetic control'),('hba1c',1,'42c3.00','HbA1 level (DCCT aligned)'),('hba1c',1,'42c3.','HbA1 level (DCCT aligned)'),('hba1c',1,'42c2.00','HbA1 > 10% - bad control'),('hba1c',1,'42c2.','HbA1 > 10% - bad control'),('hba1c',1,'42c1.00','HbA1 7 - 10% - borderline control'),('hba1c',1,'42c1.','HbA1 7 - 10% - borderline control'),('hba1c',1,'42c0.00','HbA1 < 7% - good control'),('hba1c',1,'42c0.','HbA1 < 7% - good control'),('hba1c',1,'42W..11','Glycosylated Hb'),('hba1c',1,'42W..','Glycosylated Hb'),('hba1c',1,'42W..12','Glycated haemoglobin'),('hba1c',1,'42W..','Glycated haemoglobin'),('hba1c',1,'42W..00','Hb. A1C - diabetic control'),('hba1c',1,'42W..','Hb. A1C - diabetic control'),('hba1c',1,'42WZ.00','Hb. A1C - diabetic control NOS'),('hba1c',1,'42WZ.','Hb. A1C - diabetic control NOS'),('hba1c',1,'42W3.00','Hb. A1C > 10% - bad control'),('hba1c',1,'42W3.','Hb. A1C > 10% - bad control'),('hba1c',1,'42W2.00','Hb. A1C 7-10% - borderline'),('hba1c',1,'42W2.','Hb. A1C 7-10% - borderline'),('hba1c',1,'42W1.00','Hb. A1C < 7% - good control'),('hba1c',1,'42W1.','Hb. A1C < 7% - good control'),('hba1c',1,'42W5.00','Haemoglobin A1c level - International Federation of Clinical Chemistry and Laboratory Medicine standardised'),('hba1c',1,'42W5.','Haemoglobin A1c level - International Federation of Clinical Chemistry and Laboratory Medicine standardised'),('hba1c',1,'42W5100','HbA1c (haemoglobin A1c) level (monitoring ranges) - IFCC (International Federation of Clinical Chemistry and Laboratory Medicine) standardised'),('hba1c',1,'42W51','HbA1c (haemoglobin A1c) level (monitoring ranges) - IFCC (International Federation of Clinical Chemistry and Laboratory Medicine) standardised'),('hba1c',1,'42W5000','HbA1c (haemoglobin A1c) level (diagnostic reference range) - IFCC (International Federation of Clinical Chemistry and Laboratory Medicine) standardised'),('hba1c',1,'42W50','HbA1c (haemoglobin A1c) level (diagnostic reference range) - IFCC (International Federation of Clinical Chemistry and Laboratory Medicine) standardised'),('hba1c',1,'42W4.00','HbA1c level (DCCT aligned)'),('hba1c',1,'42W4.','HbA1c level (DCCT aligned)'),('hba1c',1,'44TL.00','Total glycosylated haemoglobin level'),('hba1c',1,'44TL.','Total glycosylated haemoglobin level'),('hba1c',1,'44TB.00','Haemoglobin A1c level'),('hba1c',1,'44TB.','Haemoglobin A1c level'),('hba1c',1,'44TB100','Haemoglobin A1c (monitoring ranges)'),('hba1c',1,'44TB1','Haemoglobin A1c (monitoring ranges)'),('hba1c',1,'44TB000','Haemoglobin A1c (diagnostic reference range)'),('hba1c',1,'44TB0','Haemoglobin A1c (diagnostic reference range)'),('hba1c',2,'42W5.00','Haemoglobin A1c level - International Federation of Clinical Chemistry and Laboratory Medicine standardised'),('hba1c',2,'42W5.','Haemoglobin A1c level - International Federation of Clinical Chemistry and Laboratory Medicine standardised'),('hba1c',2,'42W4.00','HbA1c level (DCCT aligned)'),('hba1c',2,'42W4.','HbA1c level (DCCT aligned)')

INSERT INTO #AllCodes
SELECT [concept], [version], [code] from #codesreadv2;

IF OBJECT_ID('tempdb..#codesctv3') IS NOT NULL DROP TABLE #codesctv3;
CREATE TABLE #codesctv3 (
  [concept] [varchar](255) NOT NULL,
  [version] INT NOT NULL,
	[code] [varchar](20) COLLATE Latin1_General_CS_AS NOT NULL,
	[description] [varchar](255) NULL
) ON [PRIMARY];

INSERT INTO #codesctv3
VALUES ('hba1c',1,'X772q','Haemoglobin A1c level'),('hba1c',1,'XE24t','Hb. A1C - diabetic control'),('hba1c',1,'42W1.','Hb. A1C < 7% - good control'),('hba1c',1,'42W2.','Hb. A1C 7-10% - borderline'),('hba1c',1,'42W3.','Hb. A1C > 10% - bad control'),('hba1c',1,'42WZ.','Hb. A1C - diabetic control NOS'),('hba1c',1,'X80U4','Glycosylat haemoglobin-c frac'),('hba1c',1,'XaCES','HbA1 - diabetic control'),('hba1c',1,'XaCET','HbA1 <7% - good control'),('hba1c',1,'XaCEV','HbA1 >10% - bad control'),('hba1c',1,'XaCEU','HbA1 7-10% - borderline contrl'),('hba1c',1,'XaERp','HbA1c level (DCCT aligned)'),('hba1c',1,'XaPbt','HbA1c levl - IFCC standardised'),('hba1c',1,'XabrE','HbA1c (diagnostic refrn range)'),('hba1c',1,'XabrF','HbA1c (monitoring ranges)'),('hba1c',1,'Xaezd','HbA1c(diagnos ref rnge)IFCC st'),('hba1c',1,'Xaeze','HbA1c(monitoring rnges)IFCC st'),('hba1c',1,'42W..','Hb. A1C - diabetic control'),('hba1c',1,'42W5.','Haemoglobin A1c level - International Federation of Clinical Chemistry and Laboratory Medicine standardised'),('hba1c',1,'42W51','HbA1c (haemoglobin A1c) level (monitoring ranges) - IFCC (International Federation of Clinical Chemistry and Laboratory Medicine) standardised'),('hba1c',1,'42W50','HbA1c (haemoglobin A1c) level (diagnostic reference range) - IFCC (International Federation of Clinical Chemistry and Laboratory Medicine) standardised'),('hba1c',1,'42W4.','HbA1c level (DCCT aligned)'),('hba1c',1,'44TB.','Haemoglobin A1c level'),('hba1c',1,'44TB1','Haemoglobin A1c (monitoring ranges)'),('hba1c',1,'44TB0','Haemoglobin A1c (diagnostic reference range)'),('hba1c',2,'XaERp','HbA1c level (DCCT aligned)'),('hba1c',2,'XaPbt','HbA1c levl - IFCC standardised'),('hba1c',2,'42W5.','Haemoglobin A1c level - International Federation of Clinical Chemistry and Laboratory Medicine standardised'),('hba1c',2,'42W4.','HbA1c level (DCCT aligned)')

INSERT INTO #AllCodes
SELECT [concept], [version], [code] from #codesctv3;

IF OBJECT_ID('tempdb..#codessnomed') IS NOT NULL DROP TABLE #codessnomed;
CREATE TABLE #codessnomed (
  [concept] [varchar](255) NOT NULL,
  [version] INT NOT NULL,
	[code] [varchar](20) COLLATE Latin1_General_CS_AS NOT NULL,
	[description] [varchar](255) NULL
) ON [PRIMARY];

INSERT INTO #codessnomed
VALUES ('hba1c',1,'1019431000000105','HbA1c level (Diabetes Control and Complications Trial aligned)'),('hba1c',1,'1003671000000109','Haemoglobin A1c level'),('hba1c',1,'1049301000000100','HbA1c (haemoglobin A1c) level (diagnostic reference range) - IFCC (International Federation of Clinical Chemistry and Laboratory Medicine) standardised'),('hba1c',1,'1049321000000109','HbA1c (haemoglobin A1c) level (monitoring ranges) - IFCC (International Federation of Clinical Chemistry and Laboratory Medicine) standardised'),('hba1c',1,'1107481000000106','HbA1c (haemoglobin A1c) molar concentration in blood'),('hba1c',1,'999791000000106','Haemoglobin A1c level - International Federation of Clinical Chemistry and Laboratory Medicine standardised'),('hba1c',1,'1010941000000103','Haemoglobin A1c (monitoring ranges)'),('hba1c',1,'1010951000000100','Haemoglobin A1c (diagnostic reference range)'),('hba1c',1,'165679005','Haemoglobin A1c (HbA1c) less than 7% indicating good diabetic control'),('hba1c',1,'165680008','Haemoglobin A1c (HbA1c) between 7%-10% indicating borderline diabetic control'),('hba1c',1,'165681007','Hemoglobin A1c (HbA1c) greater than 10% indicating poor diabetic control'),('hba1c',1,'365845005','Haemoglobin A1C - diabetic control finding'),('hba1c',1,'444751005','High hemoglobin A1c level'),('hba1c',1,'43396009','Hemoglobin A1c measurement (procedure)'),('hba1c',1,'313835008','Hemoglobin A1c measurement aligned to the Diabetes Control and Complications Trial'),('hba1c',1,'371981000000106','Hb A1c (Haemoglobin A1c) level - IFCC (International Federation of Clinical Chemistry and Laboratory Medicine) standardised'),('hba1c',1,'444257008','Calculation of estimated average glucose based on haemoglobin A1c'),('hba1c',1,'269823000','Haemoglobin A1C - diabetic control interpretation'),('hba1c',1,'443911005','Ordinal level of hemoglobin A1c'),('hba1c',1,'733830002','HbA1c - Glycated haemoglobin-A1c'),('hba1c',2,'1019431000000105','HbA1c level (Diabetes Control and Complications Trial aligned)'),('hba1c',2,'999791000000106','Haemoglobin A1c level - International Federation of Clinical Chemistry and Laboratory Medicine standardised')

INSERT INTO #AllCodes
SELECT [concept], [version], [code] from #codessnomed;

IF OBJECT_ID('tempdb..#codesemis') IS NOT NULL DROP TABLE #codesemis;
CREATE TABLE #codesemis (
  [concept] [varchar](255) NOT NULL,
  [version] INT NOT NULL,
	[code] [varchar](20) COLLATE Latin1_General_CS_AS NOT NULL,
	[description] [varchar](255) NULL
) ON [PRIMARY];



INSERT INTO #AllCodes
SELECT [concept], [version], [code] from #codesemis;


IF OBJECT_ID('tempdb..#TempRefCodes') IS NOT NULL DROP TABLE #TempRefCodes;
CREATE TABLE #TempRefCodes (FK_Reference_Coding_ID BIGINT NOT NULL, concept VARCHAR(255) NOT NULL, version INT NOT NULL);

-- Read v2 codes
INSERT INTO #TempRefCodes
SELECT PK_Reference_Coding_ID, dcr.concept, dcr.[version]
FROM [SharedCare].[Reference_Coding] rc
INNER JOIN #codesreadv2 dcr on dcr.code = rc.MainCode
WHERE CodingType='ReadCodeV2'
and PK_Reference_Coding_ID != -1;

-- CTV3 codes
INSERT INTO #TempRefCodes
SELECT PK_Reference_Coding_ID, dcc.concept, dcc.[version]
FROM [SharedCare].[Reference_Coding] rc
INNER JOIN #codesctv3 dcc on dcc.code = rc.MainCode
WHERE CodingType='CTV3'
and PK_Reference_Coding_ID != -1;

-- EMIS codes with a FK Reference Coding ID
INSERT INTO #TempRefCodes
SELECT FK_Reference_Coding_ID, ce.concept, ce.[version]
FROM [SharedCare].[Reference_Local_Code] rlc
INNER JOIN #codesemis ce on ce.code = rlc.LocalCode
WHERE FK_Reference_Coding_ID != -1;

IF OBJECT_ID('tempdb..#TempSNOMEDRefCodes') IS NOT NULL DROP TABLE #TempSNOMEDRefCodes;
CREATE TABLE #TempSNOMEDRefCodes (FK_Reference_SnomedCT_ID BIGINT NOT NULL, concept VARCHAR(255) NOT NULL, [version] INT NOT NULL);

-- SNOMED codes
INSERT INTO #TempSNOMEDRefCodes
SELECT PK_Reference_SnomedCT_ID, dcs.concept, dcs.[version]
FROM SharedCare.Reference_SnomedCT rs
INNER JOIN #codessnomed dcs on dcs.code = rs.ConceptID;

-- EMIS codes with a FK SNOMED ID but without a FK Reference Coding ID
INSERT INTO #TempSNOMEDRefCodes
SELECT FK_Reference_SnomedCT_ID, ce.concept, ce.[version]
FROM [SharedCare].[Reference_Local_Code] rlc
INNER JOIN #codesemis ce on ce.code = rlc.LocalCode
WHERE FK_Reference_Coding_ID = -1
AND FK_Reference_SnomedCT_ID != -1;

-- De-duped tables
IF OBJECT_ID('tempdb..#CodeSets') IS NOT NULL DROP TABLE #CodeSets;
CREATE TABLE #CodeSets (FK_Reference_Coding_ID BIGINT NOT NULL, concept VARCHAR(255) NOT NULL);

IF OBJECT_ID('tempdb..#SnomedSets') IS NOT NULL DROP TABLE #SnomedSets;
CREATE TABLE #SnomedSets (FK_Reference_SnomedCT_ID BIGINT NOT NULL, concept VARCHAR(255) NOT NULL);

IF OBJECT_ID('tempdb..#VersionedCodeSets') IS NOT NULL DROP TABLE #VersionedCodeSets;
CREATE TABLE #VersionedCodeSets (FK_Reference_Coding_ID BIGINT NOT NULL, Concept VARCHAR(255), [Version] INT);

IF OBJECT_ID('tempdb..#VersionedSnomedSets') IS NOT NULL DROP TABLE #VersionedSnomedSets;
CREATE TABLE #VersionedSnomedSets (FK_Reference_SnomedCT_ID BIGINT NOT NULL, Concept VARCHAR(255), [Version] INT);

INSERT INTO #VersionedCodeSets
SELECT DISTINCT * FROM #TempRefCodes;

INSERT INTO #VersionedSnomedSets
SELECT DISTINCT * FROM #TempSNOMEDRefCodes;

INSERT INTO #CodeSets
SELECT FK_Reference_Coding_ID, c.concept
FROM #VersionedCodeSets c
INNER JOIN (
  SELECT concept, MAX(version) AS maxVersion FROM #VersionedCodeSets
  GROUP BY concept)
sub ON sub.concept = c.concept AND c.version = sub.maxVersion;

INSERT INTO #SnomedSets
SELECT FK_Reference_SnomedCT_ID, c.concept
FROM #VersionedSnomedSets c
INNER JOIN (
  SELECT concept, MAX(version) AS maxVersion FROM #VersionedSnomedSets
  GROUP BY concept)
sub ON sub.concept = c.concept AND c.version = sub.maxVersion;


-- Get all covid positive patients as this is the population of the matched cohort
IF OBJECT_ID('tempdb..#CovidPatients') IS NOT NULL DROP TABLE #CovidPatients;
SELECT FK_Patient_Link_ID, MIN(CONVERT(DATE, [EventDate])) AS FirstCovidPositiveDate INTO #CovidPatients
FROM [RLS].[vw_COVID19]
WHERE GroupDescription = 'Confirmed'
AND EventDate > '2020-01-01'
AND EventDate <= GETDATE()
GROUP BY FK_Patient_Link_ID;

-- Get all hbA1c values for the cohort
IF OBJECT_ID('tempdb..#hba1c') IS NOT NULL DROP TABLE #hba1c;
SELECT 
	FK_Patient_Link_ID,
	CAST(EventDate AS DATE) AS EventDate,
	[Value] AS hbA1c
INTO #hba1c
FROM RLS.vw_GP_Events
WHERE (
	FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE (Concept IN ('hba1c') AND [Version]=2)) OR
  FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE (Concept IN ('hba1c') AND [Version]=2))
)
AND FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #CovidPatients)
AND EventDate > '2018-01-01'
AND [Value] IS NOT NULL
AND [Value] != '0';

-- Get 2 years of hba1c for each patient relative to covid positive test date
SELECT c.FK_Patient_Link_ID AS PatientId, EventDate, hbA1c
FROM #CovidPatients c
INNER JOIN #hba1c h 
  ON h.FK_Patient_Link_ID = c.FK_Patient_Link_ID
  AND h.EventDate <= FirstCovidPositiveDate
  AND h.EventDate >= DATEADD(year, -2, FirstCovidPositiveDate)
ORDER BY c.FK_Patient_Link_ID, EventDate;
