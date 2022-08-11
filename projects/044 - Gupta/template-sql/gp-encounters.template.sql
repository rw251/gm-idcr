--┌─────────────────────────────────────────────────────────┐
--│ Dates of GP Encounters for multimorbidity cohort        │
--└─────────────────────────────────────────────────────────┘

---- RESEARCH DATA ENGINEER CHECK ----
-- 1st July 2022 - Richard Williams --
--------------------------------------

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

IF OBJECT_ID('tempdb..#PatientsToInclude') IS NOT NULL DROP TABLE #PatientsToInclude;
SELECT FK_Patient_Link_ID INTO #PatientsToInclude
FROM RLS.vw_Patient_GP_History
GROUP BY FK_Patient_Link_ID
HAVING MIN(StartDate) < '2022-06-01';

--------------------------------------------------------------------------------------------------------
----------------------------------- DEFINE MAIN COHORT -- ----------------------------------------------
--------------------------------------------------------------------------------------------------------

-- Set the date variables for the LTC code

DECLARE @IndexDate datetime;
DECLARE @MinDate datetime;
SET @IndexDate = '2022-05-01';
SET @MinDate = '1900-01-01';

--> EXECUTE query-patient-ltcs-date-range.sql 
--> EXECUTE query-patient-ltcs-number-of.sql

-- FIND ALL PATIENTS WITH A MENTAL CONDITION

IF OBJECT_ID('tempdb..#PatientsWithMentalCondition') IS NOT NULL DROP TABLE #PatientsWithMentalCondition;
SELECT DISTINCT FK_Patient_Link_ID 
INTO #PatientsWithMentalCondition
FROM #PatientsWithLTCs
WHERE LTC IN ('Anorexia Or Bulimia', 'Anxiety And Other Somatoform Disorders', 'Dementia', 'Depression', 'Schizophrenia Or Bipolar')
	AND FirstDate < '2020-03-01'
--872,174

-- FIND ALL PATIENTS WITH 2 OR MORE CONDITIONS, INCLUDING A MENTAL CONDITION

IF OBJECT_ID('tempdb..#2orMoreLTCsIncludingMental') IS NOT NULL DROP TABLE #2orMoreLTCsIncludingMental;
SELECT DISTINCT FK_Patient_Link_ID
INTO #2orMoreLTCsIncludingMental
FROM #NumLTCs 
WHERE NumberOfLTCs = 2
AND FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #PatientsWithMentalCondition)
--677,226


--> EXECUTE query-patient-year-of-birth.sql
--> EXECUTE query-patients-with-covid.sql start-date:2020-01-01 gp-events-table:RLS.vw_GP_Events all-patients:false

------------------------------------ CREATE COHORT -------------------------------------
	-- REGISTERED WITH A GM GP
	-- OVER  18
	-- HAD A COVID19 INFECTION
	-- 2 OR MORE LTCs INCLUDING ONE MENTAL CONDITION

IF OBJECT_ID('tempdb..#Cohort') IS NOT NULL DROP TABLE #Cohort;
SELECT p.FK_Patient_Link_ID, 
	EthnicMainGroup,
	DeathDate,
	yob.YearOfBirth
INTO #Cohort
FROM #Patients p
LEFT OUTER JOIN #PatientYearOfBirth yob ON yob.FK_Patient_Link_ID = p.FK_Patient_Link_ID
WHERE YEAR(@StartDate) - YearOfBirth >= 19 														 -- Over 18
	AND p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #CovidPatientsMultipleDiagnoses) -- had at least one covid19 infection
	AND p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #2orMoreLTCsIncludingMental)     -- at least 2 LTCs including one mental
	AND p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #PatientsToInclude) 			 -- exclude new patients processed post-COPI notice


-- REDUCE THE #Patients TABLE SO THAT IT ONLY INCLUDES THE COHORT, AND REUSABLE QUERIES CAN USE IT TO BE RUN QUICKER 

DELETE FROM #Patients
WHERE FK_Patient_Link_ID NOT IN (SELECT FK_Patient_Link_ID FROM #Cohort)

--------------------- IDENTIFY GP ENCOUNTERS -------------------------

--> EXECUTE query-patient-gp-encounters.sql all-patients:false gp-events-table:RLS.vw_GP_Events start-date:'2018-01-01' end-date:'2022-05-01'

------------ FIND ALL GP ENCOUNTERS FOR COHORT
SELECT 
	PatientId = FK_Patient_Link_ID,
	EncounterDate
FROM #GPEncounters
ORDER BY FK_Patient_Link_ID, EncounterDate