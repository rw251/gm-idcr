--┌────────────────────────────────────────────────────────────┐
--│ Hospital stay information for diabetes/covid cohort        │
--└────────────────────────────────────────────────────────────┘

---- RESEARCH DATA ENGINEER CHECK ----
-- 1st July 2022 - Richard Williams --
--------------------------------------

-- OUTPUT: Data with the following fields
-- Patient Id
-- AdmissionDate (DD-MM-YYYY)
-- DischargeDate (DD-MM-YYYY)
-- LengthOfStay 
-- Hospital - ANONYMOUS

-- Set the start date
DECLARE @StartDate datetime;
DECLARE @EndDate datetime;
SET @StartDate = '2020-01-01';
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

IF OBJECT_ID('tempdb..#PatientsToInclude') IS NOT NULL DROP TABLE #PatientsToInclude;
SELECT FK_Patient_Link_ID INTO #PatientsToInclude
FROM RLS.vw_Patient_GP_History
GROUP BY FK_Patient_Link_ID
HAVING MIN(StartDate) < '2022-06-01';


------------------------------------ CREATE COHORT -------------------------------------
	-- REGISTERED WITH A GM GP
	-- OVER  18
	-- DIABETES DIAGNOSIS

--> EXECUTE query-patient-year-of-birth.sql

--> CODESET diabetes-type-i:1 diabetes-type-ii:1

-- FIND ALL DIAGNOSES OF TYPE 1 DIABETES

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
	AND EventDate <= @StartDate

-- FIND ALL DIAGNOSES OF TYPE 2 DIABETES

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
	AND EventDate <= @StartDate

-- CREATE COHORT OF DIABETES PATIENTS

IF OBJECT_ID('tempdb..#Cohort') IS NOT NULL DROP TABLE #Cohort;
SELECT p.FK_Patient_Link_ID, 
	EthnicMainGroup,
	DeathDate,
	yob.YearOfBirth
INTO #Cohort
FROM #Patients p
LEFT OUTER JOIN #PatientYearOfBirth yob ON yob.FK_Patient_Link_ID = p.FK_Patient_Link_ID
WHERE YEAR(@StartDate) - YearOfBirth >= 19 														 -- Over 18
	AND (
		p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #DiabetesT1Patients)  OR			 -- Diabetes T1 diagnosis
		p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #DiabetesT2Patients) 			     -- Diabetes T2 diagnosis
		)
	AND p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #PatientsToInclude) 			 -- exclude new patients processed post-COPI notice

----------------------------------------------------------------------------------------

--> EXECUTE query-get-admissions-and-length-of-stay.sql all-patients:false
--> EXECUTE query-admissions-covid-utilisation.sql start-date:'2020-01-01' all-patients:false gp-events-table:RLS.vw_GP_Events

--bring together for final output
SELECT 
	PatientId = m.FK_Patient_Link_ID,
	l.AdmissionDate,
	l.DischargeDate
FROM #Cohort m 
LEFT JOIN #LengthOfStay l ON m.FK_Patient_Link_ID = l.FK_Patient_Link_ID
LEFT OUTER JOIN #COVIDUtilisationAdmissions c ON c.FK_Patient_Link_ID = l.FK_Patient_Link_ID AND c.AdmissionDate = l.AdmissionDate AND c.AcuteProvider = l.AcuteProvider
WHERE c.CovidHealthcareUtilisation = 'TRUE'
	AND l.AdmissionDate BETWEEN @StartDate AND @EndDate
