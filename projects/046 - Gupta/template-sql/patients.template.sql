--┌──────────────────────────────┐
--│ Patients with diabetes 	     │
--└──────────────────────────────┘

---- RESEARCH DATA ENGINEER CHECK ----
-- 1st July 2022 - Richard Williams --
--------------------------------------	

DECLARE @StartDate datetime;
DECLARE @EndDate datetime;
SET @StartDate = '2020-01-01';
SET @EndDate = '2022-05-01';

--Just want the output, not the messages
SET NOCOUNT ON;

--> EXECUTE query-get-possible-patients.sql

------------------------------------ CREATE COHORT -------------------------------------
	-- REGISTERED WITH A GM GP
	-- OVER  18
	-- DIABETES DIAGNOSIS

--> EXECUTE query-patient-year-of-birth.sql

--> CODESET diabetes-type-i:1 diabetes-type-ii:1 height:1 weight:1

-- FIND ALL DIAGNOSES OF TYPE 1 DIABETES

IF OBJECT_ID('tempdb..#DiabetesT1Patients') IS NOT NULL DROP TABLE #DiabetesT1Patients;
SELECT 
	FK_Patient_Link_ID,
	SuppliedCode,
	CAST(EventDate AS DATE) AS EventDate
INTO #DiabetesT1Patients
FROM [RLS].[vw_GP_Events]
WHERE (SuppliedCode IN (SELECT [Code] FROM #AllCodes WHERE [Concept] IN ('diabetes-type-i') AND [Version] = 1))
	AND FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
	AND EventDate <= @StartDate

-- FIND EARLIEST DIAGNOSIS OF TYPE 1 DIABETES FOR EACH PATIENT

IF OBJECT_ID('tempdb..#T1Min') IS NOT NULL DROP TABLE #T1Min;
SELECT FK_Patient_Link_ID, MIN(EventDate) AS MinDate
INTO #T1Min
FROM #DiabetesT1Patients
GROUP BY FK_Patient_Link_ID

-- FIND ALL DIAGNOSES OF TYPE 2 DIABETES

IF OBJECT_ID('tempdb..#DiabetesT2Patients') IS NOT NULL DROP TABLE #DiabetesT2Patients;
SELECT 
	FK_Patient_Link_ID,
	SuppliedCode,
	CAST(EventDate AS DATE) AS EventDate
INTO #DiabetesT2Patients
FROM [RLS].[vw_GP_Events]
WHERE (SuppliedCode IN (SELECT [Code] FROM #AllCodes WHERE [Concept] IN ('diabetes-type-ii') AND [Version] = 1))
	AND FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
	AND EventDate <= @StartDate

-- FIND EARLIEST DIAGNOSIS OF TYPE 2 DIABETES FOR EACH PATIENT

IF OBJECT_ID('tempdb..#T2Min') IS NOT NULL DROP TABLE #T2Min;
SELECT FK_Patient_Link_ID, MIN(EventDate) AS MinDate
INTO #T2Min
FROM #DiabetesT2Patients
GROUP BY FK_Patient_Link_ID

-- CREATE COHORT OF DIABETES PATIENTS

IF OBJECT_ID('tempdb..#Cohort') IS NOT NULL DROP TABLE #Cohort;
SELECT p.FK_Patient_Link_ID, 
	EthnicMainGroup,
	DeathDate,
	yob.YearOfBirth,
	DiabetesT1 = CASE WHEN t1.FK_Patient_Link_ID IS NOT NULL THEN 1 ELSE 0 END,
	DiabetesT1_EarliestDiagnosis = CASE WHEN t1.FK_Patient_Link_ID IS NOT NULL THEN t1.MinDate ELSE NULL END,
	DiabetesT2 = CASE WHEN t2.FK_Patient_Link_ID IS NOT NULL THEN 1 ELSE 0 END,
	DiabetesT2_EarliestDiagnosis = CASE WHEN t2.FK_Patient_Link_ID IS NOT NULL THEN t2.MinDate ELSE NULL END
INTO #Cohort
FROM #Patients p
LEFT OUTER JOIN #PatientYearOfBirth yob ON yob.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #T1Min t1 ON t1.FK_Patient_Link_ID = p.FK_Patient_Link_ID 
LEFT OUTER JOIN #T2Min t2 ON t2.FK_Patient_Link_ID = p.FK_Patient_Link_ID
WHERE YEAR(@StartDate) - YearOfBirth >= 19 														 -- Over 18
	AND (
		p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #DiabetesT1Patients)  OR			 -- Diabetes T1 diagnosis
		p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #DiabetesT2Patients) 			     -- Diabetes T2 diagnosis
		)

----------------------------------------------------------------------------------------

-- TABLE OF GP EVENTS FOR COHORT TO SPEED UP REUSABLE QUERIES

IF OBJECT_ID('tempdb..#PatientEventData') IS NOT NULL DROP TABLE #PatientEventData;
SELECT 
  FK_Patient_Link_ID,
  CAST(EventDate AS DATE) AS EventDate,
  SuppliedCode,
  FK_Reference_SnomedCT_ID,
  FK_Reference_Coding_ID,
  [Value]
INTO #PatientEventData
FROM [RLS].vw_GP_Events
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Cohort)
	AND EventDate < '2022-06-01';

--> EXECUTE query-patients-with-covid.sql start-date:2020-01-01 gp-events-table:#PatientEventData all-patients:false

-- Get patient list of those with COVID death within 28 days of positive test
IF OBJECT_ID('tempdb..#COVIDDeath') IS NOT NULL DROP TABLE #COVIDDeath;
SELECT DISTINCT FK_Patient_Link_ID 
INTO #COVIDDeath FROM RLS.vw_COVID19
WHERE DeathWithin28Days = 'Y'
	AND EventDate <= @EndDate

-- Set the date variables for the LTC code

DECLARE @IndexDate datetime;
DECLARE @MinDate datetime;
SET @IndexDate = '2022-05-01';
SET @MinDate = '1900-01-01';

--> EXECUTE query-patient-bmi.sql gp-events-table:#PatientEventData
--> EXECUTE query-patient-smoking-status.sql gp-events-table:#PatientEventData
--> EXECUTE query-patient-care-home-resident.sql
--> EXECUTE query-patient-practice-and-ccg.sql
--> EXECUTE query-patient-sex.sql
--> EXECUTE query-patient-imd.sql
--> EXECUTE query-patient-lsoa.sql

--> EXECUTE query-get-covid-vaccines.sql gp-events-table:#PatientEventData gp-medications-table:RLS.vw_GP_Medications



IF OBJECT_ID('tempdb..#observations') IS NOT NULL DROP TABLE #observations;
SELECT 
	FK_Patient_Link_ID,
	CAST(EventDate AS DATE) AS EventDate,
	Concept = CASE WHEN sn.Concept IS NOT NULL THEN sn.Concept ELSE co.Concept END,
	[Value] = TRY_CONVERT(NUMERIC (18,5), [Value])
INTO #all_observations
FROM #PatientEventData gp
LEFT JOIN #VersionedSnomedSets sn ON sn.FK_Reference_SnomedCT_ID = gp.FK_Reference_SnomedCT_ID
LEFT JOIN #VersionedCodeSets co ON co.FK_Reference_Coding_ID = gp.FK_Reference_Coding_ID
WHERE
	(
	gp.FK_Reference_SnomedCT_ID   IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets sn WHERE sn.Concept In ('height', 'weight') AND [Version] = 1) 
	OR gp.FK_Reference_Coding_ID   IN (SELECT FK_Reference_Coding_ID   FROM #VersionedCodeSets co   WHERE co.Concept In ('height', 'weight') AND [Version] = 1)
	)
	AND [Value] IS NOT NULL AND [Value] != '0' AND [Value] <> '0.00000' AND (TRY_CONVERT(NUMERIC (18,5), [Value])) > 0 -- REMOVE NULL AND ZERO VALUES
	AND UPPER([Value]) NOT LIKE '%[A-Z]%'  -- REMOVE TEXT VALUES


-- create table of height and weight measurements

IF OBJECT_ID('tempdb..#height_weight') IS NOT NULL DROP TABLE #height_weight;
SELECT FK_Patient_Link_ID, [Value], EventDate, Concept
INTO #height_weight
FROM #all_observations
WHERE Concept in ('height', 'weight')
	AND EventDate <= @IndexDate

-- For height and weight we want closest prior to index date
IF OBJECT_ID('tempdb..#TempCurrentHeightWeight') IS NOT NULL DROP TABLE #TempCurrentHeightWeight;
SELECT 
	a.FK_Patient_Link_ID, 
	a.Concept,
	Max([Value]) as [Value],
	Max(EventDate) as EventDate
INTO #TempCurrentHeightWeight
FROM #height_weight a
INNER JOIN (
	SELECT FK_Patient_Link_ID, MAX(EventDate) AS MostRecentDate 
	FROM #height_weight
	GROUP BY FK_Patient_Link_ID
) sub ON sub.MostRecentDate = a.EventDate and sub.FK_Patient_Link_ID = a.FK_Patient_Link_ID
GROUP BY a.FK_Patient_Link_ID, a.Concept;

-- bring together in a table that can be joined to
IF OBJECT_ID('tempdb..#PatientHeightWeight') IS NOT NULL DROP TABLE #PatientHeightWeight;
SELECT 
	p.FK_Patient_Link_ID,
	height = MAX(CASE WHEN c.Concept = 'height' THEN TRY_CONVERT(NUMERIC(16,5), [Value]) ELSE NULL END),
	height_dt = MAX(CASE WHEN c.Concept = 'height' THEN EventDate ELSE NULL END),
	weight = MAX(CASE WHEN c.Concept = 'weight' THEN TRY_CONVERT(NUMERIC(16,5), [Value]) ELSE NULL END),
	weight_dt = MAX(CASE WHEN c.Concept = 'weight' THEN EventDate ELSE NULL END)
INTO #PatientHeightWeight
FROM #Cohort p
LEFT OUTER JOIN #TempCurrentHeightWeight c on c.FK_Patient_Link_ID = p.FK_Patient_Link_ID
GROUP BY p.FK_Patient_Link_ID

-- BRING TOGETHER FOR FINAL DATA EXTRACT

SELECT  
	PatientId = p.FK_Patient_Link_ID, 
	p.YearOfBirth, 
	Sex,
	p.EthnicMainGroup,
	LSOA_Code,
	IMD2019Decile1IsMostDeprived10IsLeastDeprived,
	BMI,
	BMIDate = bmi.EventDate,
	height,
	height_dt,
	[weight],
	weight_dt,
	CurrentSmokingStatus = smok.CurrentSmokingStatus,
	WorstSmokingStatus = smok.WorstSmokingStatus,
	PracticeCCG = prac.CCG,
	IsCareHomeResident,
	DiabetesT1,
	DiabetesT1_EarliestDiagnosis = CAST(DiabetesT1_EarliestDiagnosis AS DATE),
	DiabetesT2,
	DiabetesT2_EarliestDiagnosis = CAST(DiabetesT2_EarliestDiagnosis AS DATE),
	DeathWithin28DaysCovid = CASE WHEN cd.FK_Patient_Link_ID  IS NOT NULL THEN 'Y' ELSE 'N' END,
	DeathDueToCovid_Year = CASE WHEN cd.FK_Patient_Link_ID IS NOT NULL THEN YEAR(p.DeathDate) ELSE null END,
	DeathDueToCovid_Month = CASE WHEN cd.FK_Patient_Link_ID IS NOT NULL THEN MONTH(p.DeathDate) ELSE null END,
	FirstCovidPositiveDate,
	SecondCovidPositiveDate, 
	ThirdCovidPositiveDate, 
	FourthCovidPositiveDate, 
	FifthCovidPositiveDate,
	FirstVaccineYear =  YEAR(VaccineDose1Date),
	FirstVaccineMonth = MONTH(VaccineDose1Date),
	SecondVaccineYear =  YEAR(VaccineDose2Date),
	SecondVaccineMonth = MONTH(VaccineDose2Date),
	ThirdVaccineYear =  YEAR(VaccineDose3Date),
	ThirdVaccineMonth = MONTH(VaccineDose3Date)
FROM #Cohort p 
LEFT OUTER JOIN #PatientLSOA lsoa ON lsoa.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientSex sex ON sex.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientIMDDecile imd ON imd.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientBMI bmi ON bmi.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientSmokingStatus smok ON smok.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientHeightWeight heiwei ON heiwei.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientPracticeAndCCG prac ON prac.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #COVIDDeath cd ON cd.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #COVIDVaccinations vac ON vac.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #CovidPatientsMultipleDiagnoses cv ON cv.FK_Patient_Link_ID = P.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientCareHomeStatus ch on ch.FK_Patient_Link_ID = p.FK_Patient_Link_ID 