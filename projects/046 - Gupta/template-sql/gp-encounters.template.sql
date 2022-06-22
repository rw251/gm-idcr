--┌─────────────────────────────────────────────────────────┐
--│ Dates of GP Encounters for diabetes cohort              │
--└─────────────────────────────────────────────────────────┘

------------ RESEARCH DATA ENGINEER CHECK ------------
------------------------------------------------------

-- OUTPUT: Data with the following fields
-- Patient Id
-- EncounterDate (DD-MM-YYYY)

-- Set the start date
DECLARE @StartDate datetime;
DECLARE @EndDate datetime;
SET @StartDate = '2018-01-01';
SET @EndDate = '2022-05-01';

--Just want the output, not the messages
SET NOCOUNT ON;

-- Find all patients alive at start date
IF OBJECT_ID('tempdb..#PossiblePatients') IS NOT NULL DROP TABLE #PossiblePatients;
SELECT PK_Patient_Link_ID as FK_Patient_Link_ID, EthnicMainGroup, DeathDate INTO #PossiblePatients FROM [RLS].vw_Patient_Link
WHERE (DeathDate IS NULL OR DeathDate >= @StartDate);

-- Find all patients registered with a GP
IF OBJECT_ID('tempdb..#PatientsWithGP') IS NOT NULL DROP TABLE #PatientsWithGP;
SELECT DISTINCT FK_Patient_Link_ID INTO #PatientsWithGP FROM [RLS].vw_Patient
where FK_Reference_Tenancy_ID = 2;

-- Make cohort from patients alive at start date and registered with a GP
IF OBJECT_ID('tempdb..#Patients') IS NOT NULL DROP TABLE #Patients;
SELECT pp.* INTO #Patients FROM #PossiblePatients pp
INNER JOIN #PatientsWithGP gp on gp.FK_Patient_Link_ID = pp.FK_Patient_Link_ID;



------------------------------------ CREATE COHORT -------------------------------------
	-- REGISTERED WITH A GM GP
	-- OVER  18
	-- DIABETES DIAGNOSIS

--> EXECUTE query-patient-year-of-birth.sql


IF OBJECT_ID('tempdb..#DiabetesT1Patients') IS NOT NULL DROP TABLE #DiabetesT1Patients;
SELECT 
	FK_Patient_Link_ID,
	SuppliedCode,
	EventDate
INTO #DiabetesT1Patients
FROM [RLS].[vw_GP_Events]
WHERE (
    FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE Concept IN ('diabetes-type-i') AND Version = 1) OR
    FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE Concept IN ('diabetes-type-i') AND Version = 1)
	)
	AND FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)

SELECT FK_Patient_Link_ID, MIN(EventDate) AS MinDate
INTO #T1Min
FROM #DiabetesT2Patients

IF OBJECT_ID('tempdb..#DiabetesT2Patients') IS NOT NULL DROP TABLE #DiabetesT2Patients;
SELECT 
	FK_Patient_Link_ID,
	SuppliedCode,
	EventDate
INTO #DiabetesT2Patients
FROM [RLS].[vw_GP_Events]
WHERE (
    FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE Concept IN ('diabetes-type-ii') AND Version = 1) OR
    FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE Concept IN ('diabetes-type-ii') AND Version = 1)
	)
	AND FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)

SELECT FK_Patient_Link_ID, MIN(EventDate) AS MinDate
INTO #T2Min
FROM #DiabetesT2Patients


IF OBJECT_ID('tempdb..#Cohort') IS NOT NULL DROP TABLE #Cohort;
SELECT p.FK_Patient_Link_ID, 
	EthnicMainGroup,
	DeathDate,
	yob.YearOfBirth,
	DiabetesT1 = CASE WHEN t1.FK_Patient_Link_ID IS NOT NULL THEN 1 ELSE 0 END,
	DiabetesT1_EarliestDiagnosis = CASE WHEN t1.FK_Patient_Link_ID IS NOT NULL THEN MinDate ELSE NULL END,
	DiabetesT2 = CASE WHEN t2.FK_Patient_Link_ID IS NOT NULL THEN 1 ELSE 0 END,
	DiabetesT2_EarliestDiagnosis = CASE WHEN t2.FK_Patient_Link_ID IS NOT NULL THEN MinDate ELSE NULL END
INTO #Cohort
FROM #Patients p
LEFT OUTER JOIN #PatientYearOfBirth yob ON yob.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #T1Min t1 ON t1.FK_Patient_Link_ID = c.FK_Patient_Link_ID 
LEFT OUTER JOIN #T2Min t2 ON t2.FK_Patient_Link_ID = c.FK_Patient_Link_ID
WHERE YEAR(@StartDate) - YearOfBirth >= 19 														 -- Over 18
	AND (
		p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #DiabetesT1Patients)  OR			 -- Diabetes T1 diagnosis
		p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #DiabetesT2Patients) 			     -- Diabetes T2 diagnosis
		)

----------------------------------------------------------------------------------------


--------------------- IDENTIFY GP ENCOUNTERS -------------------------

-- Create a table with all GP encouters ========================================================================================================
SELECT 'Face2face' AS EncounterType, PK_Reference_Coding_ID, FK_Reference_SnomedCT_ID
INTO #CodingClassifier
FROM SharedCare.Reference_Coding
WHERE CodingType='ReadCodeV2'
AND (
	MainCode like '1%'
	or MainCode like '2%'
	or MainCode in ('6A2..','6A9..','6AA..','6AB..','662d.','662e.','66AS.','66AS0','66AT.','66BB.','66f0.','66YJ.','66YM.','661Q.','66480','6AH..','6A9..','66p0.','6A2..','66Ay.','66Az.','69DC.')
	or MainCode like '6A%'
	or MainCode like '65%'
	or MainCode like '8B31[356]%'
	or MainCode like '8B3[3569ADEfilOqRxX]%'
	or MainCode in ('8BS3.')
	or MainCode like '8H[4-8]%' 
	or MainCode like '94Z%'
	or MainCode like '9N1C%' 
	or MainCode like '9N21%'
	or MainCode in ('9kF1.','9kR..','9HB5.')
	or MainCode like '9H9%'
);

-- INSERT INTO #CodingClassifier
-- SELECT 'A+E', PK_Reference_Coding_ID, FK_Reference_SnomedCT_ID
-- FROM SharedCare.Reference_Coding
-- WHERE CodingType='ReadCodeV2'
-- AND (
-- 	MainCode like '8H2%'
-- 	or MainCode like '8H[1-3]%'
-- 	or MainCode in ('9N19.','8HJA.','8HC..','8Hu..','8HC1.','ZL91.','9b00.','9b8D.','9b61.','8Hd1.','ZLD2100','8HE8.','8HJ..','8HJJ.','ZLE1.','ZL51.')
-- );

INSERT INTO #CodingClassifier
SELECT 'Telephone', PK_Reference_Coding_ID, FK_Reference_SnomedCT_ID
FROM SharedCare.Reference_Coding
WHERE CodingType='ReadCodeV2'
AND (
	MainCode like '8H9%'
	or MainCode like '9N31%'
	or MainCode like '9N3A%'
);

-- INSERT INTO #CodingClassifier
-- SELECT 'Hospital', PK_Reference_Coding_ID, FK_Reference_SnomedCT_ID
-- FROM SharedCare.Reference_Coding
-- WHERE CodingType='ReadCodeV2'
-- AND (
-- 	MainCode like '7%'
-- 	or MainCode like '8H[1-3]%'
-- 	or MainCode like '9N%' 
-- );

-- Add the equivalent CTV3 codes
INSERT INTO #CodingClassifier
SELECT 'Face2face', PK_Reference_Coding_ID, FK_Reference_SnomedCT_ID FROM SharedCare.Reference_Coding
WHERE FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #CodingClassifier WHERE EncounterType='Face2face' AND FK_Reference_SnomedCT_ID != -1)
AND CodingType='CTV3';
-- INSERT INTO #CodingClassifier
-- SELECT 'A+E', PK_Reference_Coding_ID, FK_Reference_SnomedCT_ID FROM SharedCare.Reference_Coding
-- WHERE FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #CodingClassifier WHERE EncounterType='A+E' AND FK_Reference_SnomedCT_ID != -1)
-- AND CodingType='CTV3';
INSERT INTO #CodingClassifier
SELECT 'Telephone', PK_Reference_Coding_ID, FK_Reference_SnomedCT_ID FROM SharedCare.Reference_Coding
WHERE FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #CodingClassifier WHERE EncounterType='Telephone' AND FK_Reference_SnomedCT_ID != -1)
AND CodingType='CTV3';
-- INSERT INTO #CodingClassifier
-- SELECT 'Hospital', PK_Reference_Coding_ID, FK_Reference_SnomedCT_ID FROM SharedCare.Reference_Coding
-- WHERE FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #CodingClassifier WHERE EncounterType='Hospital' AND FK_Reference_SnomedCT_ID != -1)
-- AND CodingType='CTV3';

-- Add the equivalent EMIS codes
INSERT INTO #CodingClassifier
SELECT 'Face2face', FK_Reference_Coding_ID, FK_Reference_SnomedCT_ID FROM SharedCare.Reference_Local_Code
WHERE (
	FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #CodingClassifier WHERE EncounterType='Face2face' AND FK_Reference_SnomedCT_ID != -1) OR
	FK_Reference_Coding_ID IN (SELECT PK_Reference_Coding_ID FROM #CodingClassifier WHERE EncounterType='Face2face' AND PK_Reference_Coding_ID != -1)
);
-- INSERT INTO #CodingClassifier
-- SELECT 'A+E', FK_Reference_Coding_ID, FK_Reference_SnomedCT_ID FROM SharedCare.Reference_Local_Code
-- WHERE (
-- 	FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #CodingClassifier WHERE EncounterType='A+E' AND FK_Reference_SnomedCT_ID != -1) OR
-- 	FK_Reference_Coding_ID IN (SELECT PK_Reference_Coding_ID FROM #CodingClassifier WHERE EncounterType='A+E' AND PK_Reference_Coding_ID != -1)
-- );
INSERT INTO #CodingClassifier
SELECT 'Telephone', FK_Reference_Coding_ID, FK_Reference_SnomedCT_ID FROM SharedCare.Reference_Local_Code
WHERE (
	FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #CodingClassifier WHERE EncounterType='Telephone' AND FK_Reference_SnomedCT_ID != -1) OR
	FK_Reference_Coding_ID IN (SELECT PK_Reference_Coding_ID FROM #CodingClassifier WHERE EncounterType='Telephone' AND PK_Reference_Coding_ID != -1)
);
-- INSERT INTO #CodingClassifier
-- SELECT 'Hospital', FK_Reference_Coding_ID, FK_Reference_SnomedCT_ID FROM SharedCare.Reference_Local_Code
-- WHERE (
-- 	FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #CodingClassifier WHERE EncounterType='Hospital' AND FK_Reference_SnomedCT_ID != -1) OR
-- 	FK_Reference_Coding_ID IN (SELECT PK_Reference_Coding_ID FROM #CodingClassifier WHERE EncounterType='Hospital' AND PK_Reference_Coding_ID != -1)
-- );

-- All above takes ~30s

-- Below is split up, because doing it without the date filter led to 
-- an out of memory exception.

SELECT DISTINCT FK_Patient_Link_ID, CAST(EventDate AS DATE) AS EncounterDate
INTO #Encounters
FROM RLS.vw_GP_Events
WHERE FK_Reference_Coding_ID IN (SELECT PK_Reference_Coding_ID FROM #CodingClassifier)
AND FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Cohort)
AND EventDate >= '2018-01-01'
AND EventDate < '2022-05-01';
-- 26,573,504 records, 6m26

-- INSERT INTO #Encounters
-- SELECT DISTINCT FK_Patient_Link_ID, CAST(EventDate AS DATE) AS EntryDate
-- FROM RLS.vw_GP_Events
-- WHERE FK_Reference_Coding_ID IN (SELECT PK_Reference_Coding_ID FROM #CodingClassifier)
-- AND EventDate >= '2019-01-01'
-- AND EventDate < '2020-01-01';
-- -- 26,573,504 records, 6m26

-- INSERT INTO #Encounters
-- SELECT DISTINCT FK_Patient_Link_ID, CAST(EventDate AS DATE) AS EntryDate
-- FROM RLS.vw_GP_Events
-- WHERE FK_Reference_Coding_ID IN (SELECT PK_Reference_Coding_ID FROM #CodingClassifier)
-- AND EventDate >= '2020-01-01'
-- AND EventDate < '2021-01-01';
-- -- 21,971,922 records, 5m28

-- INSERT INTO #Encounters
-- SELECT DISTINCT FK_Patient_Link_ID, CAST(EventDate AS DATE) AS EntryDate
-- FROM RLS.vw_GP_Events
-- WHERE FK_Reference_Coding_ID IN (SELECT PK_Reference_Coding_ID FROM #CodingClassifier)
-- AND EventDate >= '2021-01-01'
-- AND EventDate < '2022-01-01';
-- -- 25,879,476 records, 5m23

-- INSERT INTO #Encounters
-- SELECT DISTINCT FK_Patient_Link_ID, CAST(EventDate AS DATE) AS EntryDate
-- FROM RLS.vw_GP_Events
-- WHERE FK_Reference_Coding_ID IN (SELECT PK_Reference_Coding_ID FROM #CodingClassifier)
-- AND EventDate >= '2022-01-01'
-- AND EventDate < '2022-05-01';
-- --5,488,868 records, 18m 54

-- IF OBJECT_ID('tempdb..#GPEncounter') IS NOT NULL DROP TABLE #GPEncounter;
-- SELECT DISTINCT FK_Patient_Link_ID, EntryDate AS EncounterDate
-- INTO #GPEncounter
-- FROM #Encounters



------------ FIND ALL GP ENCOUNTERS FOR COHORT
SELECT *
FROM #Encounters
ORDER BY FK_Patient_Link_ID, EncounterDate