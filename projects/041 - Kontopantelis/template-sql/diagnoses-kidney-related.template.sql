--┌─────────────────────────────────────────┐
--│ Diagnoses of kidney related conditions  │
--└─────────────────────────────────────────┘

------------ RESEARCH DATA ENGINEER CHECK ------------

------------------------------------------------------

-- Set the start date
DECLARE @StartDate datetime;
DECLARE @EndDate datetime;
SET @StartDate = '2018-03-01';
SET @EndDate = '2022-03-01';

DECLARE @IndexDate datetime;
SET @IndexDate = '2020-03-01';

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


-- DEFINE COHORT
--> EXECUTE query-build-rq041-cohort.sql

-----------------------------------------------------------------------------------------------------------------------------------------
------------------- NOW COHORT HAS BEEN DEFINED, LOAD CODE SETS FOR ALL KIDNEY RELATED DIAGNOSES ----------------------------------------
-----------------------------------------------------------------------------------------------------------------------------------------

--> CODESET renal-replacement-therapy:1 acute-kidney-injury:1 polycystic-kidney-disease:1 family-history-kidney-disease:1 end-stage-renal-disease:1
--> CODESET ckd-stage-1:1 ckd-stage-2:1 ckd-stage-3:1 ckd-stage-4:1 ckd-stage-5:1 chronic-kidney-disease:1 allergy:2

-- CREATE TABLES OF DISTINCT CODES AND CONCEPTS - TO REMOVE DUPLICATES IN FINAL TABLE

IF OBJECT_ID('tempdb..#VersionedCodeSetsUnique') IS NOT NULL DROP TABLE #VersionedCodeSetsUnique;
SELECT DISTINCT V.Concept, FK_Reference_Coding_ID, V.[Version]
INTO #VersionedCodeSetsUnique
FROM #VersionedCodeSets V

IF OBJECT_ID('tempdb..#VersionedSnomedSetsUnique') IS NOT NULL DROP TABLE #VersionedSnomedSetsUnique;
SELECT DISTINCT V.Concept, FK_Reference_SnomedCT_ID, V.[Version]
INTO #VersionedSnomedSetsUnique
FROM #VersionedSnomedSets V


---- CREATE OUTPUT TABLE OF DIAGNOSES AND SYMPTOMS, FOR THE COHORT OF INTEREST, AND CODING DATES 

IF OBJECT_ID('tempdb..#DiagnosesAndSymptoms') IS NOT NULL DROP TABLE #DiagnosesAndSymptoms;
SELECT FK_Patient_Link_ID, EventDate, case when s.Concept is null then c.Concept else s.Concept end as Concept
INTO #DiagnosesAndSymptoms
FROM #PatientEventData gp
LEFT OUTER JOIN #VersionedSnomedSetsUnique s ON s.FK_Reference_SnomedCT_ID = gp.FK_Reference_SnomedCT_ID
LEFT OUTER JOIN #VersionedCodeSetsUnique c ON c.FK_Reference_Coding_ID = gp.FK_Reference_Coding_ID
WHERE gp.EventDate BETWEEN @StartDate AND @EndDate
AND (
	(gp.FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSetsUnique WHERE (Concept NOT IN ('egfr','urinary-albumin-creatinine-ratio')))) 
	OR
    (gp.FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSetsUnique WHERE (Concept NOT IN ('egfr','urinary-albumin-creatinine-ratio'))))
);


SELECT DISTINCT PatientID = FK_Patient_Link_ID, -- ASSUME THAT CODES FROM SAME CODE SET ON SAME DAY ARE DUPLICATES
	EventDate,
	Concept
FROM #DiagnosesAndSymptoms
ORDER BY FK_Patient_Link_ID, EventDate, Concept