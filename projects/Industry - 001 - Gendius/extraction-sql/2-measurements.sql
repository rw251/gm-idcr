--┌────────────────────────────────────┐
--│ An example SQL generation template │
--└────────────────────────────────────┘

-- OUTPUT: Data with the following fields
-- 	- PatientId (int)
--  - DateOfFirstDiagnosis (YYYY-MM-DD) 

--Just want the output, not the messages
SET NOCOUNT ON;

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

--#region Clinical code sets

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
VALUES ('hypertension',1,'G2...',NULL,'Hypertensive disease'),('hypertension',1,'G2...00',NULL,'Hypertensive disease'),('hypertension',1,'G2z..',NULL,'Hypertensive disease NOS'),('hypertension',1,'G2z..00',NULL,'Hypertensive disease NOS'),('hypertension',1,'G2y..',NULL,'Other specified hypertensive disease'),('hypertension',1,'G2y..00',NULL,'Other specified hypertensive disease'),('hypertension',1,'G28..',NULL,'Stage 2 hypertension (NICE - National Institute for Health and Clinical Excellence 2011)'),('hypertension',1,'G28..00',NULL,'Stage 2 hypertension (NICE - National Institute for Health and Clinical Excellence 2011)'),('hypertension',1,'G26..',NULL,'Severe hypertension (NICE - National Institute for Health and Clinical Excellence 2011)'),('hypertension',1,'G26..00',NULL,'Severe hypertension (NICE - National Institute for Health and Clinical Excellence 2011)'),('hypertension',1,'G25..',NULL,'Stage 1 hypertension (NICE - National Institute for Health and Clinical Excellence 2011)'),('hypertension',1,'G25..00',NULL,'Stage 1 hypertension (NICE - National Institute for Health and Clinical Excellence 2011)'),('hypertension',1,'G251.',NULL,'Stage 1 hypertension (NICE 2011) with evidence of end organ damage'),('hypertension',1,'G251.00',NULL,'Stage 1 hypertension (NICE 2011) with evidence of end organ damage'),('hypertension',1,'G250.',NULL,'Stage 1 hypertension (NICE 2011) without evidence of end organ damage'),('hypertension',1,'G250.00',NULL,'Stage 1 hypertension (NICE 2011) without evidence of end organ damage'),('hypertension',1,'G24..',NULL,'Secondary hypertension'),('hypertension',1,'G24..00',NULL,'Secondary hypertension'),('hypertension',1,'G24z.',NULL,'Secondary hypertension NOS'),('hypertension',1,'G24z.00',NULL,'Secondary hypertension NOS'),('hypertension',1,'G24zz',NULL,'Secondary hypertension NOS'),('hypertension',1,'G24zz00',NULL,'Secondary hypertension NOS'),('hypertension',1,'G24z0',NULL,'Secondary renovascular hypertension NOS'),('hypertension',1,'G24z000',NULL,'Secondary renovascular hypertension NOS'),('hypertension',1,'G244.',NULL,'Hypertension secondary to endocrine disorders'),('hypertension',1,'G244.00',NULL,'Hypertension secondary to endocrine disorders'),('hypertension',1,'G241.',NULL,'Secondary benign hypertension'),('hypertension',1,'G241.00',NULL,'Secondary benign hypertension'),('hypertension',1,'G241z',NULL,'Secondary benign hypertension NOS'),('hypertension',1,'G241z00',NULL,'Secondary benign hypertension NOS'),('hypertension',1,'G2410',NULL,'Secondary benign renovascular hypertension'),('hypertension',1,'G241000',NULL,'Secondary benign renovascular hypertension'),('hypertension',1,'G240.',NULL,'Secondary malignant hypertension'),('hypertension',1,'G240.00',NULL,'Secondary malignant hypertension'),('hypertension',1,'G240z',NULL,'Secondary malignant hypertension NOS'),('hypertension',1,'G240z00',NULL,'Secondary malignant hypertension NOS'),('hypertension',1,'G2400',NULL,'Secondary malignant renovascular hypertension'),('hypertension',1,'G240000',NULL,'Secondary malignant renovascular hypertension'),('hypertension',1,'G20..',NULL,'Essential hypertension'),('hypertension',1,'G20..00',NULL,'Essential hypertension'),('hypertension',1,'G20z.',NULL,'Essential hypertension NOS'),('hypertension',1,'G20z.00',NULL,'Essential hypertension NOS'),('hypertension',1,'G203.',NULL,'Diastolic hypertension'),('hypertension',1,'G203.00',NULL,'Diastolic hypertension'),('hypertension',1,'G202.',NULL,'Systolic hypertension'),('hypertension',1,'G202.00',NULL,'Systolic hypertension'),('hypertension',1,'G201.',NULL,'Benign essential hypertension'),('hypertension',1,'G201.00',NULL,'Benign essential hypertension'),('hypertension',1,'G200.',NULL,'Malignant essential hypertension'),('hypertension',1,'G200.00',NULL,'Malignant essential hypertension'),('hypertension',1,'Gyu2.',NULL,'[X]Hypertensive diseases'),('hypertension',1,'Gyu2.00',NULL,'[X]Hypertensive diseases'),('hypertension',1,'Gyu21',NULL,'[X]Hypertension secondary to other renal disorders'),('hypertension',1,'Gyu2100',NULL,'[X]Hypertension secondary to other renal disorders'),('hypertension',1,'Gyu20',NULL,'[X]Other secondary hypertension'),('hypertension',1,'Gyu2000',NULL,'[X]Other secondary hypertension')

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
VALUES ('hypertension',1,'G24..',NULL,'Secondary hypertension'),('hypertension',1,'G240.',NULL,'Malignant secondary hypertension'),('hypertension',1,'G241.',NULL,'Secondary benign hypertension'),('hypertension',1,'G244.',NULL,'Hypertension secondary to endocrine disorders'),('hypertension',1,'G24z.',NULL,'Secondary hypertension NOS'),('hypertension',1,'Gyu20',NULL,'[X]Other secondary hypertension'),('hypertension',1,'Gyu21',NULL,'[X]Hypertension secondary to other renal disorders'),('hypertension',1,'Xa0kX',NULL,'Hypertension due to renovascular disease'),('hypertension',1,'XE0Ub',NULL,'Systemic arterial hypertension'),('hypertension',1,'G2400',NULL,'Secondary malignant renovascular hypertension'),('hypertension',1,'G240z',NULL,'Secondary malignant hypertension NOS'),('hypertension',1,'G2410',NULL,'Secondary benign renovascular hypertension'),('hypertension',1,'G241z',NULL,'Secondary benign hypertension NOS'),('hypertension',1,'G24z0',NULL,'Secondary renovascular hypertension NOS'),('hypertension',1,'G20..',NULL,'Primary hypertension'),('hypertension',1,'G202.',NULL,'Systolic hypertension'),('hypertension',1,'G20z.',NULL,'Essential hypertension NOS'),('hypertension',1,'XE0Uc',NULL,'Primary hypertension'),('hypertension',1,'XE0W8',NULL,'Hypertension'),('hypertension',1,'XSDSb',NULL,'Diastolic hypertension'),('hypertension',1,'Xa0Cs',NULL,'Labile hypertension'),('hypertension',1,'Xa3fQ',NULL,'Malignant hypertension'),('hypertension',1,'XaZWm',NULL,'Stage 1 hypertension'),('hypertension',1,'XaZWn',NULL,'Severe hypertension'),('hypertension',1,'XaZbz',NULL,'Stage 2 hypertension (NICE - National Institute for Health and Clinical Excellence 2011)'),('hypertension',1,'XaZzo',NULL,'Nocturnal hypertension'),('hypertension',1,'G2...',NULL,'Hypertensive disease'),('hypertension',1,'G200.',NULL,'Malignant essential hypertension'),('hypertension',1,'G201.',NULL,'Benign essential hypertension'),('hypertension',1,'XE0Ud',NULL,'Essential hypertension NOS'),('hypertension',1,'Xab9L',NULL,'Stage 1 hypertension (NICE 2011) without evidence of end organ damage'),('hypertension',1,'Xab9M',NULL,'Stage 1 hypertension (NICE 2011) with evidence of end organ damage'),('hypertension',1,'G2y..',NULL,'Other specified hypertensive disease'),('hypertension',1,'G2z..',NULL,'Hypertensive disease NOS'),('hypertension',1,'Gyu2.',NULL,'[X]Hypertensive diseases'),('hypertension',1,'XM19D',NULL,'[EDTA] Renal vascular disease due to hypertension (no primary renal disease) associated with renal failure'),('hypertension',1,'XM19E',NULL,'[EDTA] Renal vascular disease due to malignant hypertension (no primary renal disease) associated with renal failure')

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

INSERT INTO #codessnomed
VALUES ('hypertension',1,'1201005',NULL,'Benign essential hypertension (disorder)'),('hypertension',1,'123799005',NULL,'Renovascular hypertension (disorder)'),('hypertension',1,'194783001',NULL,'Secondary malignant renovascular hypertension (disorder)'),('hypertension',1,'194785008',NULL,'Secondary benign hypertension (disorder)'),('hypertension',1,'194788005',NULL,'Hypertension secondary to endocrine disorders (disorder)'),('hypertension',1,'31992008',NULL,'Secondary hypertension (disorder)'),('hypertension',1,'48146000',NULL,'Diastolic hypertension (disorder)'),('hypertension',1,'56218007',NULL,'Systolic hypertension (disorder)'),('hypertension',1,'59621000',NULL,'Essential hypertension (disorder)'),('hypertension',1,'697929007',NULL,'Intermittent hypertension (disorder)'),('hypertension',1,'70272006',NULL,'Malignant hypertension (disorder)'),('hypertension',1,'73410007',NULL,'Benign secondary renovascular hypertension (disorder)'),('hypertension',1,'78975002',NULL,'Malignant essential hypertension (disorder)'),('hypertension',1,'843821000000102',NULL,'Stage 1 hypertension (National Institute for Health and Clinical Excellence 2011) (disorder)'),('hypertension',1,'843841000000109',NULL,'Severe hypertension (National Institute for Health and Clinical Excellence 2011) (disorder)'),('hypertension',1,'846371000000103',NULL,'Stage 2 hypertension (National Institute for Health and Clinical Excellence 2011) (disorder)'),('hypertension',1,'863191000000102',NULL,'Nocturnal hypertension (disorder)'),('hypertension',1,'89242004',NULL,'Malignant secondary hypertension (disorder)'),('hypertension',1,'908631000000108',NULL,'Stage 1 hypertension (National Institute for Health and Clinical Excellence 2011) without evidence of end organ damage (disorder)'),('hypertension',1,'908651000000101',NULL,'Stage 1 hypertension (National Institute for Health and Clinical Excellence 2011) with evidence of end organ damage (disorder)'),('hypertension',1,'24184005',NULL,'Finding of increased blood pressure (finding)'),('hypertension',1,'38341003',NULL,'Raised blood pressure (disorder)'),('hypertension',1,'10725009',NULL,'Benign hypertension'),('hypertension',1,'14973001',NULL,'Renal sclerosis with hypertension'),('hypertension',1,'19769006',NULL,'High-renin essential hypertension'),('hypertension',1,'46481004',NULL,'Low-renin essential hypertension'),('hypertension',1,'59720008',NULL,'Sustained diastolic hypertension'),('hypertension',1,'65518004',NULL,'Labile diastolic hypertension'),('hypertension',1,'74451002',NULL,'Secondary diastolic hypertension'),('hypertension',1,'84094009',NULL,'Rebound hypertension'),('hypertension',1,'371125006',NULL,'Labile essential hypertension'),('hypertension',1,'397748008',NULL,'Hypertension with albuminuria'),('hypertension',1,'427889009',NULL,'Hypertension associated with transplantation'),('hypertension',1,'428575007',NULL,'Hypertension secondary to kidney transplant'),('hypertension',1,'429457004',NULL,'Systolic essential hypertension'),('hypertension',1,'712832005',NULL,'Supine hypertension'),('hypertension',1,'762463000',NULL,'Diastolic hypertension co-occurrent with systolic hypertension'),('hypertension',1,'471521000000108',NULL,'[X]Hypertensive diseases'),('hypertension',1,'845891000000103',NULL,'Hypertension resistant to drug therapy'),('hypertension',1,'1078301000112109',NULL,'Multiple drug intolerant hypertension'),('hypertension',1,'16229371000119106',NULL,'Labile systemic arterial hypertension'),('hypertension',1,'766937004',NULL,'Hypertension due to gain-of-function mutation in mineralocorticoid receptor'),('hypertension',1,'871642009',NULL,'Hypertension due to aortic arch obstruction'),('hypertension',1,'71421000119105',NULL,'Hypertension in chronic kidney disease due to type 2 diabetes mellitus'),('hypertension',1,'71701000119105',NULL,'Hypertension in chronic kidney disease due to type 1 diabetes mellitus'),('hypertension',1,'140101000119109',NULL,'Hypertension in chronic kidney disease stage 5 due to type 2 diabetes mellitus'),('hypertension',1,'140111000119107',NULL,'Hypertension in chronic kidney disease stage 4 due to type 2 diabetes mellitus'),('hypertension',1,'140121000119100',NULL,'Hypertension in chronic kidney disease stage 3 due to type 2 diabetes mellitus'),('hypertension',1,'140131000119102',NULL,'Hypertension in chronic kidney disease stage 2 due to type 2 diabetes mellitus')

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

INSERT INTO #codesemis
VALUES ('hypertension',1,'EMISNQST25',NULL,'Stage 2 hypertension'),('hypertension',1,'^ESCTMA364280',NULL,'Malignant hypertension'),('hypertension',1,'EMISNQST25',NULL,'Stage 2 hypertension')

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

--#endregion

-- >>> Following code sets injected: hypertension v1
SELECT FK_Patient_Link_ID AS PatientId, MIN(EventDate) AS DateOfFirstDiagnosis FROM [RLS].[vw_GP_Events]
WHERE (
  FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE Concept = 'hypertension' AND Version = 1) OR
  FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE Concept = 'hypertension' AND Version = 1)
)
GROUP BY FK_Patient_Link_ID;