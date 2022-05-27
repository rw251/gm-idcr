--┌─────────────────────────────────────┐
--│ Patient information for main cohort │
--└─────────────────────────────────────┘

------------ RESEARCH DATA ENGINEER CHECK ------------

------------------------------------------------------

-- PatientID
-- registration date with the general practice
-- Month and year of birth (YYYY-MM)
-- Month and year of death (YYYY-MM)
-- Sex at birth (male/female)
-- Ethnicity (white/black/asian/mixed/other)
-- CCG of registered GP practice
-- LSOA Code
-- IMD decile
-- First vaccination date (YYYY-MM or N/A)
-- Second vaccination date (YYYY-MM or N/A)
-- Third vaccination date (YYYY-MM or N/A)
-- Death within 28 days of Covid Diagnosis (Y/N)
-- Date of death due to Covid-19 (YYYY-MM or N/A)
-- Number of AE Episodes before 01.03.20
-- Number of AE Episodes after 01.03.20
-- Total AE Episodes (01.03.18 - 01.03.22)
-- Number of GP appointments before 01.03.20
-- Number of GP appointments after 01.03.20
-- Total GP appointments (01.03.18 - 01.03.22)
-- evidenceOfCKD_egfr (yes/no)
-- evidenceOfCKD_acr (yes/no)
-- atRiskOfCKD (yes/no)

-- Set the start date
DECLARE @StartDate datetime;
DECLARE @EndDate datetime;
SET @StartDate = '2018-03-01';
SET @EndDate = '2022-03-01';

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



--------------------------------------------------------------------------------------------------------
----------------------------------- DEFINE MAIN COHORT -- ----------------------------------------------
--------------------------------------------------------------------------------------------------------

-- LOAD CODESETS FOR CONDITIONS THAT INDICATE RISK OF CKD

--> CODESET hypertension:1 diabetes:1

-- LOAD CODESETS FOR TESTS USED TO INDICATE CKD

--> CODESET egfr:1 urinary-albumin-creatinine-ratio:1


---- FIND PATIENTS WITH BIOCHEMICAL EVIDENCE OF CKD

---- find all eGFR and ACR tests

IF OBJECT_ID('tempdb..#EGFR_ACR_TESTS') IS NOT NULL DROP TABLE #EGFR_ACR_TESTS;
SELECT gp.FK_Patient_Link_ID, 
	CAST(GP.EventDate AS DATE) AS EventDate, 
	SuppliedCode, 
	[value] = TRY_CONVERT(NUMERIC (18,5), [Value]),  
	[Units],
	egfr_Code = CASE WHEN SuppliedCode IN (
		SELECT [Code] FROM #AllCodes WHERE [Concept] IN ('egfr') AND [Version] = 1 ) THEN 1 ELSE 0 END,
	acr_Code = CASE WHEN SuppliedCode IN (
		SELECT [Code] FROM #AllCodes WHERE [Concept] IN ('urinary-albumin-creatinine-ratio') AND [Version] = 1 ) THEN 1 ELSE 0 END
INTO #EGFR_ACR_TESTS
FROM [RLS].[vw_GP_Events] gp
WHERE (
		gp.FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE Concept IN ('egfr', 'urinary-albumin-creatinine-ratio')  AND [Version]=1) OR
		gp.FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE Concept IN ('egfr', 'urinary-albumin-creatinine-ratio')  AND [Version]=1)
	  )
	AND gp.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
	AND (gp.EventDate) BETWEEN '2016-01-01' and @EndDate
	AND [Value] IS NOT NULL AND UPPER([Value]) NOT LIKE '%[A-Z]%' 

-- CREATE TABLE OF EGFR TESTS THAT MEET CKD CRITERIA (VARIOUS STAGEs)

IF OBJECT_ID('tempdb..#ckd_stages_egfr') IS NOT NULL DROP TABLE #ckd_stages_egfr;
SELECT FK_Patient_Link_ID,
	EventDate,
	egfr_evidence = CASE WHEN egfr_Code = 1 AND [Value] >= 90   THEN 'G1' 
		WHEN egfr_Code = 1 AND [Value] BETWEEN 60 AND 89 		THEN 'G2'
		WHEN egfr_Code = 1 AND [Value] BETWEEN 45 AND 59 		THEN 'G3a'
		WHEN egfr_Code = 1 AND [Value] BETWEEN 30 AND 44 		THEN 'G3b'
		WHEN egfr_Code = 1 AND [Value] BETWEEN 15 AND 29 		THEN 'G4'
		WHEN egfr_Code = 1 AND [Value] BETWEEN  0 AND 15 		THEN 'G5'
			ELSE NULL END
INTO #ckd_stages_egfr
FROM #EGFR_ACR_TESTS

-- FIND EGFR TESTS INDICATIVE OF CKD STAGE 3-5, WITH THE DATES OF THE PREVIOUS TEST

IF OBJECT_ID('tempdb..#egfr_dates') IS NOT NULL DROP TABLE #egfr_dates;
SELECT *, 
	stage_previous_egfr = LAG(egfr_evidence, 1, NULL) OVER (PARTITION BY FK_Patient_Link_ID ORDER BY EventDate),
	date_previous_egfr = LAG(EventDate, 1, NULL) OVER (PARTITION BY FK_Patient_Link_ID ORDER BY EventDate)
INTO #egfr_dates
FROM #ckd_stages_egfr
where egfr_evidence in ('G3a', 'G3b', 'G4', 'G5')
ORDER BY FK_Patient_Link_ID, EventDate

-- CREATE TABLE OF PATIENTS THAT HAD TWO EGFR TESTS INDICATIVE OF CKD STAGE 3-5, WITHIN 3 MONTHS OF EACH OTHER

IF OBJECT_ID('tempdb..#egfr_ckd_evidence') IS NOT NULL DROP TABLE #egfr_ckd_evidence;
SELECT *
INTO #egfr_ckd_evidence
FROM #egfr_dates
WHERE datediff(month, date_previous_egfr, EventDate) <=  3 --only find patients with two tests in three months

-- FIND PATIENTS THAT MEET THE FOLLOWING: "ACR > 3mg/mmol lasting for at least 3 months”

-- CREATE TABLE OF ACR TESTS

IF OBJECT_ID('tempdb..#ckd_stages_acr') IS NOT NULL DROP TABLE #ckd_stages_acr;
SELECT FK_Patient_Link_ID,
	EventDate, 
	acr_evidence = CASE WHEN acr_Code = 1 AND [Value] > 30  	THEN 'A3' 
		WHEN acr_Code = 1 AND [Value] BETWEEN 3 AND 30 			THEN 'A2'
		WHEN acr_Code = 1 AND [Value] BETWEEN  0 AND 3 			THEN 'A1'
			ELSE NULL END 
INTO #ckd_stages_acr
FROM #EGFR_ACR_TESTS

-- FIND TESTS THAT ARE >3mg/mmol AND SHOW DATE OF PREVIOUS TEST

IF OBJECT_ID('tempdb..#acr_dates') IS NOT NULL DROP TABLE #acr_dates;
SELECT *, 
	stage_previous_acr = LAG(acr_evidence, 1, NULL) OVER (PARTITION BY FK_Patient_Link_ID ORDER BY EventDate),
	date_previous_acr = LAG(EventDate, 1, NULL) OVER (PARTITION BY FK_Patient_Link_ID ORDER BY EventDate)
INTO #acr_dates
FROM #ckd_stages_acr
WHERE acr_evidence in ('A3','A2')
ORDER BY FK_Patient_Link_ID, EventDate

IF OBJECT_ID('tempdb..#acr_ckd_evidence') IS NOT NULL DROP TABLE #acr_ckd_evidence;
SELECT *
INTO #acr_ckd_evidence
FROM #acr_dates
WHERE datediff(month, date_previous_acr, EventDate) >=  3 --only find patients with acr stages A1/A2 lasting at least 3 months


-- CREATE TABLE OF PATIENTS AT RISK OF CKD: DIABETES OR HYPERTENSION

-- IF OBJECT_ID('tempdb..#ckd_risk') IS NOT NULL DROP TABLE #ckd_risk;
-- SELECT DISTINCT FK_Patient_Link_ID
-- INTO #ckd_risk
-- FROM [RLS].[vw_GP_Events] gp
-- LEFT OUTER JOIN #VersionedSnomedSets s ON s.FK_Reference_SnomedCT_ID = gp.FK_Reference_SnomedCT_ID
-- LEFT OUTER JOIN #VersionedCodeSets c ON c.FK_Reference_Coding_ID = gp.FK_Reference_Coding_ID
-- WHERE  gp.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
-- AND (
-- 	gp.FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE Concept IN ('diabetes', 'hypertension') AND [Version]=1) OR
--     gp.FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE Concept IN ('diabetes', 'hypertension') AND [Version]=1)
-- 	);
-- 	AND EventDate <= @StartDate

-- CREATE TABLE ONLY INCLUDING THE REQUIRED COHORT, WHICH INCLUDES THOSE WITH EVIDENCE OF CKD AND THOSE AT RISK OF CKD

IF OBJECT_ID('tempdb..#Cohort') IS NOT NULL DROP TABLE #Cohort;
SELECT p.FK_Patient_Link_ID,
		p.EthnicMainGroup,
		p.DeathDate,
		EvidenceOfCKD_egfr = CASE WHEN p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #egfr_ckd_evidence) THEN 1 ELSE 0 END,
		EvidenceOfCKD_acr = CASE WHEN p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #acr_ckd_evidence) THEN 1 ELSE 0 END
		--,AtRiskOfCKD = CASE WHEN p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #ckd_risk) THEN 1 ELSE 0 END
INTO #Cohort
FROM #Patients p
WHERE p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #egfr_ckd_evidence) 
	OR p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #acr_ckd_evidence) 
	--OR p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #ckd_risk) 

---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------


--> EXECUTE query-get-covid-vaccines.sql gp-events-table:RLS.vw_GP_Events gp-medications-table:RLS.vw_GP_Medications
--> EXECUTE query-patient-gp-history.sql
--> EXECUTE query-patient-practice-and-ccg.sql

-- FIND PATIENTS THAT HAVE LEFT GM DURING STUDY PERIOD AND THE DATE THAT THEY LEFT

IF OBJECT_ID('tempdb..#GM_GPs') IS NOT NULL DROP TABLE #GM_GPs;
SELECT * 
INTO #GM_GPs
FROM #PatientGPHistory
WHERE 
--StartDate <= @StartDate and EndDate > @StartDate and 
GPPracticeCode <> 'OutOfArea'

IF OBJECT_ID('tempdb..#GM_GP_range') IS NOT NULL DROP TABLE #GM_GP_range;
SELECT FK_Patient_Link_ID, MIN(StartDate) AS MinDate, MAX(EndDate) AS MaxDate
INTO #GM_GP_range
FROM #GM_GPs
GROUP BY FK_Patient_Link_ID
ORDER BY FK_Patient_Link_ID, MIN(StartDate)

IF OBJECT_ID('tempdb..#GPExitDates') IS NOT NULL DROP TABLE #GPExitDates;
SELECT *,
	MovedOutOfGMDate = CASE WHEN MaxDate <  @EndDate THEN MaxDate ELSE NULL END
INTO #GPExitDates
FROM #GM_GP_range



-- FIND NUMBER OF ATTENDED GP APPOINTMENTS FROM MARCH 2018 TO MARCH 2022

IF OBJECT_ID('tempdb..#gp_appointments') IS NOT NULL DROP TABLE #gp_appointments;
SELECT G.FK_Patient_Link_ID, 
	G.AppointmentDate, 
	BeforeOrAfter1stMarch2020 = CASE WHEN G.AppointmentDate < '2020-03-01' THEN 'BEFORE' ELSE 'AFTER' END
INTO #gp_appointments
FROM RLS.vw_GP_Appointments G
WHERE AppointmentCancelledDate IS NULL 
AND AppointmentDate BETWEEN '2018-03-01' AND '2022-03-01'
AND G.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Cohort) 

SELECT FK_Patient_Link_ID, BeforeOrAfter1stMarch2020, COUNT(*) as gp_appointments
INTO #count_gp_appointments
FROM #gp_appointments
GROUP BY FK_Patient_Link_ID, BeforeOrAfter1stMarch2020
ORDER BY FK_Patient_Link_ID, BeforeOrAfter1stMarch2020

-- FIND NUMBER OF A&E APPOINTMENTS FROM MARCH 2018 TO MARCH 2022

IF OBJECT_ID('tempdb..#ae_encounters') IS NOT NULL DROP TABLE #ae_encounters;
SELECT a.FK_Patient_Link_ID, 
	a.AttendanceDate, 
	BeforeOrAfter1stMarch2020 = CASE WHEN a.AttendanceDate < '2020-03-01' THEN 'BEFORE' ELSE 'AFTER' END
INTO #ae_encounters
FROM RLS.vw_Acute_AE a
WHERE EventType = 'Attendance'
AND a.AttendanceDate BETWEEN '2018-03-01' AND '2022-03-01'
AND a.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #cohort) 

SELECT FK_Patient_Link_ID, BeforeOrAfter1stMarch2020, COUNT(*) AS ae_encounters
INTO #count_ae_encounters
FROM #ae_encounters
GROUP BY FK_Patient_Link_ID, BeforeOrAfter1stMarch2020
ORDER BY FK_Patient_Link_ID, BeforeOrAfter1stMarch2020


-- Get patient list of those with COVID death within 28 days of positive test
IF OBJECT_ID('tempdb..#COVIDDeath') IS NOT NULL DROP TABLE #COVIDDeath;
SELECT DISTINCT FK_Patient_Link_ID 
INTO #COVIDDeath FROM RLS.vw_COVID19
WHERE DeathWithin28Days = 'Y'
	AND EventDate <= @EndDate

--> EXECUTE query-patient-sex.sql
--> EXECUTE query-patient-imd.sql
--> EXECUTE query-patient-year-of-birth.sql
--> EXECUTE query-patient-lsoa.sql
--> EXECUTE query-patient-smoking-status.sql gp-events-table:RLS.vw_GP_Events
--> EXECUTE query-patient-alcohol-intake.sql gp-events-table:RLS.vw_GP_Events

---- CREATE OUTPUT TABLE OF COHORT PATIENTS (EITHER EVIDENCE OF CKD OR AT RISK OF CKD), JOINING TO TEMP TABLES FOR ALL OTHER INFO 

SELECT  PatientId = p.FK_Patient_Link_ID, 
		PracticeExitDate = gpex.MovedOutOfGMDate,
		PracticeCCG = prac.CCG,
		YearOfBirth, 
		Sex,
		EthnicMainGroup,
	    LSOA_Code,
		IMD2019Decile1IsMostDeprived10IsLeastDeprived,
		CurrentSmokingStatus = smok.CurrentSmokingStatus,
		CurrentAlcoholIntake,
		WorstAlcoholIntake,
		DeathWithin28DaysCovid = CASE WHEN cd.FK_Patient_Link_ID  IS NOT NULL THEN 'Y' ELSE 'N' END,
		DeathDueToCovid_Year = CASE WHEN cd.FK_Patient_Link_ID IS NOT NULL THEN YEAR(p.DeathDate) ELSE null END,
		DeathDueToCovid_Month = CASE WHEN cd.FK_Patient_Link_ID IS NOT NULL THEN MONTH(p.DeathDate) ELSE null END,
		FirstVaccineYear =  YEAR(VaccineDose1Date),
		FirstVaccineMonth = MONTH(VaccineDose1Date),
		SecondVaccineYear =  YEAR(VaccineDose2Date),
		SecondVaccineMonth = MONTH(VaccineDose2Date),
		ThirdVaccineYear =  YEAR(VaccineDose3Date),
		ThirdVaccineMonth = MONTH(VaccineDose3Date),
		AEEncountersBefore1stMarch2020 = ae_b.ae_encounters,
		AEEncountersAfter1stMarch2020 = ae_a.ae_encounters,
		GPAppointmentsBefore1stMarch2020 = gp_b.gp_appointments,
		GPAppointmentsAfter1stMarch2020 =  gp_a.gp_appointments ,
		EvidenceOfCKD_egfr,
		EvidenceOfCKD_acr
		--,AtRiskOfCKD
FROM #Cohort p
LEFT OUTER JOIN #PatientLSOA lsoa ON lsoa.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientYearOfBirth yob ON yob.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientSex sex ON sex.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientIMDDecile imd ON imd.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientSmokingStatus smok ON smok.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientAlcoholIntake alc ON alc.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientPracticeAndCCG prac ON prac.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #GPExitDates gpex ON gpex.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #COVIDVaccinations vac ON vac.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #COVIDDeath cd ON cd.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #count_ae_encounters ae_b ON ae_b.FK_Patient_Link_ID = p.FK_Patient_Link_ID AND ae_b.BeforeOrAfter1stMarch2020 = 'BEFORE'
LEFT OUTER JOIN #count_ae_encounters ae_a ON ae_a.FK_Patient_Link_ID = p.FK_Patient_Link_ID AND ae_a.BeforeOrAfter1stMarch2020 = 'AFTER'
LEFT OUTER JOIN #count_gp_appointments gp_b ON gp_b.FK_Patient_Link_ID = p.FK_Patient_Link_ID AND gp_b.BeforeOrAfter1stMarch2020 = 'BEFORE'
LEFT OUTER JOIN #count_gp_appointments gp_a ON gp_a.FK_Patient_Link_ID = p.FK_Patient_Link_ID AND gp_a.BeforeOrAfter1stMarch2020 = 'AFTER'
WHERE YEAR(@StartDate) - YearOfBirth > 18 -- OVER 18s ONLY
--320,594