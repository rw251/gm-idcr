--┌─────────────┐
--│ Medications │
--└─────────────┘

-------- RESEARCH DATA ENGINEER CHECK ---------
-- Richard Williams	2021-11-26	Review complete

-- All prescriptions of medications for type 2 diabetes patients.

-- OUTPUT: Data with the following fields
-- 	-   PatientId (int)
--	-	MedicationCategory
--	-	PrescriptionDate (YYYY-MM-DD)

-- Set the start date
DECLARE @StartDate datetime;
SET @StartDate = '2019-07-09';

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

--> CODESET diabetes-type-ii:1 polycystic-ovarian-syndrome:1 gestational-diabetes:1
--> CODESET bnf-cardiovascular-meds:1 bnf-cns-meds:1 bnf-endocrine-meds:1

--> EXECUTE query-patient-sex.sql
--> EXECUTE query-patient-year-of-birth.sql

-- FIND PATIENTS WITH A DIAGNOSIS OF POLYCYSTIC OVARY SYNDROME OR GESTATIONAL DIABETES, TO EXCLUDE

IF OBJECT_ID('tempdb..#exclusions') IS NOT NULL DROP TABLE #exclusions;
SELECT DISTINCT gp.FK_Patient_Link_ID
INTO #exclusions
FROM [RLS].[vw_GP_Events] gp
LEFT OUTER JOIN #Patients p ON p.FK_Patient_Link_ID = gp.FK_Patient_Link_ID
WHERE (SuppliedCode IN 
	(SELECT [Code] FROM #AllCodes WHERE [Concept] IN 
		('polycystic-ovarian-syndrome', 'gestational-diabetes') AND [Version] = 1
			AND EventDate BETWEEN '2018-07-09' AND '2022-03-31')) 
    
---- CREATE TABLE OF ALL PATIENTS THAT HAVE ANY LIFETIME DIAGNOSES OF T2D AS OF 2019-07-01

IF OBJECT_ID('tempdb..#diabetes2_diagnoses') IS NOT NULL DROP TABLE #diabetes2_diagnoses;
SELECT gp.FK_Patient_Link_ID, 
		YearOfBirth, 
		Sex,
		EventDate,
		SuppliedCode
INTO #diabetes2_diagnoses
FROM [RLS].[vw_GP_Events] gp
LEFT OUTER JOIN #Patients p ON p.FK_Patient_Link_ID = gp.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientYearOfBirth yob ON yob.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientSex sex ON sex.FK_Patient_Link_ID = p.FK_Patient_Link_ID
WHERE (SuppliedCode IN 
	(SELECT [Code] FROM #AllCodes WHERE [Concept] IN ('diabetes-type-ii') AND [Version] = 1)) 
    AND gp.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
    AND gp.FK_Patient_Link_ID NOT IN (SELECT FK_Patient_Link_ID FROM #exclusions) -- exclude patients with polycystic ovary syndrome or gestational diabetes
	AND (gp.EventDate) <= '2019-07-09'
	AND DATEDIFF(YEAR, yob.YearOfBirth, '2019-07-09') >= 18


-- Define the main cohort to be matched
IF OBJECT_ID('tempdb..#MainCohort') IS NOT NULL DROP TABLE #MainCohort;
SELECT DISTINCT FK_Patient_Link_ID, 
		YearOfBirth, 
		Sex
INTO #MainCohort
FROM #diabetes2_diagnoses
--WHERE FK_Patient_Link_ID IN (#####INTERVENTION_TABLE) -- only get patients that had a diabetes intervention


/*

-- Define the population of potential matches for the cohort
IF OBJECT_ID('tempdb..#PotentialMatches') IS NOT NULL DROP TABLE #PotentialMatches;
SELECT DISTINCT p.FK_Patient_Link_ID, Sex, YearOfBirth
INTO #PotentialMatches
FROM #diabetes2_diagnoses
WHERE p.FK_Patient_Link_ID NOT IN (SELECT FK_Patient_Link_ID FROM #MainCohort)


--> EXECUTE query-cohort-matching-yob-sex-alt.sql yob-flex:1 num-matches:20


-- Get the matched cohort detail - same as main cohort
IF OBJECT_ID('tempdb..#MatchedCohort') IS NOT NULL DROP TABLE #MatchedCohort;
SELECT 
  c.MatchingPatientId AS FK_Patient_Link_ID,
  Sex,
  MatchingYearOfBirth,
  EthnicMainGroup,
  PatientId AS PatientWhoIsMatched
INTO #MatchedCohort
FROM #CohortStore c
LEFT OUTER JOIN #Patients p ON p.FK_Patient_Link_ID = c.MatchingPatientId
WHERE c.PatientId IN (SELECT FK_Patient_Link_ID FROM #Patients);

-- Define a table with all the patient ids for the main cohort and the matched cohort
IF OBJECT_ID('tempdb..#PatientIds') IS NOT NULL DROP TABLE #PatientIds;
SELECT PatientId AS FK_Patient_Link_ID INTO #PatientIds FROM #CohortStore
UNION
SELECT MatchingPatientId FROM #CohortStore;

*/


-- FIX ISSUE WITH DUPLICATE MEDICATIONS, CAUSED BY SOME CODES APPEARING MULTIPLE TIMES IN #VersionedCodeSets and #VersionedSnomedSets

IF OBJECT_ID('tempdb..#VersionedCodeSets_1') IS NOT NULL DROP TABLE #VersionedCodeSets_1;
SELECT DISTINCT FK_Reference_Coding_ID, Concept, [Version] INTO #VersionedCodeSets_1 FROM #VersionedCodeSets

IF OBJECT_ID('tempdb..#VersionedSnomedSets_1') IS NOT NULL DROP TABLE #VersionedSnomedSets_1;
SELECT DISTINCT FK_Reference_SnomedCT_ID, Concept, [Version] INTO #VersionedSnomedSets_1 FROM #VersionedSnomedSets


-- RX OF MEDS SINCE 09.07.19 FOR PATIENTS WITH T2D, WITH A FLAG FOR THE CATEGORY (CARDIOVASCULAR, ENDOCRINE, CNS)

IF OBJECT_ID('tempdb..#meds') IS NOT NULL DROP TABLE #meds;
SELECT 
	 m.FK_Patient_Link_ID,
	 CAST(MedicationDate AS DATE) as PrescriptionDate,
	 [concept] = CASE WHEN s.[concept] IS NOT NULL THEN s.[concept] ELSE c.[concept] END
INTO #meds
FROM RLS.vw_GP_Medications m
LEFT OUTER JOIN #VersionedSnomedSets_1 s ON s.FK_Reference_SnomedCT_ID = m.FK_Reference_SnomedCT_ID
LEFT OUTER JOIN #VersionedCodeSets_1 c ON c.FK_Reference_Coding_ID = m.FK_Reference_Coding_ID
WHERE m.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #diabetes2_diagnoses)
AND m.MedicationDate > '2019-07-09' 
AND (m.FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets_1) OR
	m.FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets_1))
AND UPPER(SourceTable) NOT LIKE '%REPMED%'  -- exclude duplicate prescriptions 
AND RepeatMedicationFlag = 'N' 				-- exclude duplicate prescriptions 

-- Produce final table of all medication prescriptions for T2D patients
SELECT PatientId = FK_Patient_Link_ID, 
	MedicationCategory = concept,
	PrescriptionDate
FROM #meds
ORDER BY PatientId,
	concept,
	PrescriptionDate



