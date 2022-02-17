--┌─────────────────────────────────────────────┐
--│ Diabetes and COVID and Vaccines cohort file │
--└─────────────────────────────────────────────┘

------------------------ RDE CHECK -------------------------
--
------------------------------------------------------------

-- Cohort is patients with a diagnosies of diabetes. The below queries produce the data
-- that is required for each patient.

-- DEMOGRAPHIC
-- PatientId, YearOfBirth, DeathDate, DeathWithin28Days, FrailtyIndex, Sex, LSOA, EthnicCategoryDescription, 
-- TownsendScoreHigherIsMoreDeprived, TownsendQuintileHigherIsMoreDeprived,
-- COHORT SPECIFIC
-- FirstDiagnosisDate, FirstT1DiagnosisDate, FirstT2DiagnosisDate, 1stCOVIDPositiveTestDate, 2ndCOVIDPositiveTestDate,
-- 3rdCOVIDPositiveTestDate, 4thCOVIDPositiveTestDate, 5thCOVIDPositiveTestDate, 6thCOVIDPositiveTestDate,
-- 1stAdmissionPost1stCOVIDTest, LengthOfStay1stAdmission1stCOVIDTest, 1stAdmissionPost2ndCOVIDTest, LengthOfStay1stAdmission2ndCOVIDTest,
-- 1stAdmissionPost3rdCOVIDTest, LengthOfStay1stAdmission3rdCOVIDTest, 1stAdmissionPost4thCOVIDTest, LengthOfStay1stAdmission4thCOVIDTest,
-- 1stAdmissionPost5thCOVIDTest, LengthOfStay1stAdmission5thCOVIDTest, 1stAdmissionPost6thCOVIDTest, LengthOfStay1stAdmission6thCOVIDTest,
-- DateOf1stVaccine, DateOf2ndVaccine, DateOf3rdVaccine, DateOf4thVaccine, DateOf5thVaccine, DateOf6thVaccine,
-- BIOMARKERS
-- LatestBMIValue, LatestHBA1CValue, LatestCHOLESTEROLValue, LatestLDLValue, LatestHDLValue,
-- LatestVITAMINDValue, LatestTESTOSTERONEValue, LatestEGFRValue, LatestSHBGValue, LatestSBP, LatestDBP,
-- PATIENT STATUS
-- IsPassiveSmoker, WorstSmokingStatus, CurrentSmokingStatus
-- DIAGNOSES
-- PatientHasCOPD, PatientHasASTHMA, PatientHasSMI, PatientHasHYPERTENSION
-- MEDICATIONS
-- IsOnACEIorARB, IsOnAspirin, IsOnClopidogrel, IsOnMetformin, IsOnInsulin, 
-- IsOnSGLTI, IsOnGLP1A, IsOnSulphonylurea

--Just want the output, not the messages
SET NOCOUNT ON;

-- Set the start date
DECLARE @StartDate datetime;
SET @StartDate = '2020-01-01';

-- Only need medications if in 6 months prior to COVID test
DECLARE @MedicationsFromDate datetime;
SET @MedicationsFromDate = DATEADD(month, -6, @StartDate);

-- Only need bp/bmi etc if in 2 years prior to COVID test
DECLARE @EventsFromDate datetime;
SET @EventsFromDate = DATEADD(year, -2, @StartDate);

-- First get all the diabetic (type 1/type 2/other) patients and the date of first diagnosis
--> CODESET diabetes:1
IF OBJECT_ID('tempdb..#DiabeticPatients') IS NOT NULL DROP TABLE #DiabeticPatients;
SELECT FK_Patient_Link_ID, MIN(CAST(EventDate AS DATE)) AS FirstDiagnosisDate INTO #DiabeticPatients
FROM RLS.vw_GP_Events
WHERE (
	FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE Concept IN ('diabetes') AND [Version]=1) OR
  FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE Concept IN ('diabetes') AND [Version]=1)
)
GROUP BY FK_Patient_Link_ID;

-- Get separate cohorts for paients with type 1 diabetes and type 2 diabetes
--> CODESET diabetes-type-i:1
IF OBJECT_ID('tempdb..#DiabeticTypeIPatients') IS NOT NULL DROP TABLE #DiabeticTypeIPatients;
SELECT FK_Patient_Link_ID, MIN(CAST(EventDate AS DATE)) AS FirstT1DiagnosisDate INTO #DiabeticTypeIPatients
FROM RLS.vw_GP_Events
WHERE (
	FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE Concept IN ('diabetes-type-i') AND [Version]=1) OR
  FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE Concept IN ('diabetes-type-i') AND [Version]=1)
)
GROUP BY FK_Patient_Link_ID;

--> CODESET diabetes-type-ii:1
IF OBJECT_ID('tempdb..#DiabeticTypeIIPatients') IS NOT NULL DROP TABLE #DiabeticTypeIIPatients;
SELECT FK_Patient_Link_ID, MIN(CAST(EventDate AS DATE)) AS FirstT2DiagnosisDate INTO #DiabeticTypeIIPatients
FROM RLS.vw_GP_Events
WHERE (
	FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE Concept IN ('diabetes-type-ii') AND [Version]=1) OR
  FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE Concept IN ('diabetes-type-ii') AND [Version]=1)
)
GROUP BY FK_Patient_Link_ID;

-- Then get all the positive covid test patients
--> EXECUTE query-patients-with-covid.sql start-date:2020-01-01

-- Define #Patients temp table for getting future things like age/sex etc.
-- NB this is where the filter to just DARE patients via NHS number occurs
IF OBJECT_ID('tempdb..#Patients') IS NOT NULL DROP TABLE #Patients;
SELECT FK_Patient_Link_ID INTO #Patients
FROM #CovidPatients cp
INNER JOIN [RLS].vw_Patient p ON p.FK_Patient_Link_ID = cp.FK_Patient_Link_ID
INNER JOIN #DAREPatients dp ON dp.NhsNo = p.NhsNo;

--> EXECUTE query-patient-smoking-status.sql
--> EXECUTE query-patient-year-of-birth.sql
--> EXECUTE query-patient-sex.sql
--> EXECUTE query-patient-lsoa.sql
--> EXECUTE query-patient-townsend.sql
--> EXECUTE query-get-covid-vaccines.sql
--> EXECUTE query-get-admissions-and-length-of-stay.sql

up to here!!!!!!!!!!!!!!!!
need to change covid query to return multiple dates like vaccine one

-- For each patient find the first hospital admission following their positive covid test
-- We allow the test to be within 48 hours post admission and still count it
IF OBJECT_ID('tempdb..#PatientsFirstAdmissionPostTest') IS NOT NULL DROP TABLE #PatientsFirstAdmissionPostTest;
SELECT l.FK_Patient_Link_ID, MAX(l.AdmissionDate) AS FirstAdmissionPostCOVIDTest, MAX(LengthOfStay) AS LengthOfStay
INTO #PatientsFirstAdmissionPostTest
FROM #LengthOfStay l
INNER JOIN (
  SELECT p.FK_Patient_Link_ID, MIN(AdmissionDate) AS FirstAdmission
  FROM #PatientIdsAndIndexDates p
  LEFT OUTER JOIN #LengthOfStay los
    ON los.FK_Patient_Link_ID = p.FK_Patient_Link_ID
    AND los.AdmissionDate >= DATEADD(day, -2, p.IndexDate)
  GROUP BY p.FK_Patient_Link_ID
) sub ON sub.FK_Patient_Link_ID = l.FK_Patient_Link_ID AND sub.FirstAdmission = l.AdmissionDate
GROUP BY l.FK_Patient_Link_ID;

--> CODESET bmi:2 hba1c:2 cholesterol:2 ldl-cholesterol:1 hdl-cholesterol:1 vitamin-d:1 testosterone:1 sex-hormone-binding-globulin:1 egfr:1
IF OBJECT_ID('tempdb..#PatientValuesWithIds') IS NOT NULL DROP TABLE #PatientValuesWithIds;
SELECT 
	FK_Patient_Link_ID,
	CAST(EventDate AS DATE) AS EventDate,
  FK_Reference_Coding_ID,
  FK_Reference_SnomedCT_ID,
	[Value]
INTO #PatientValuesWithIds
FROM RLS.vw_GP_Events
WHERE (
	FK_Reference_SnomedCT_ID IN (
    SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE (
      Concept IN ('bmi') AND [Version]=2 OR
      Concept IN ('hba1c') AND [Version]=2 OR
      Concept IN ('cholesterol') AND [Version]=2 OR
      Concept IN ('ldl-cholesterol') AND [Version]=1 OR
      Concept IN ('hdl-cholesterol') AND [Version]=1 OR
      Concept IN ('vitamin-d') AND [Version]=1 OR
      Concept IN ('testosterone') AND [Version]=1 OR
      Concept IN ('egfr') AND [Version]=1 OR
      Concept IN ('sex-hormone-binding-globulin') AND [Version]=1
    )
  ) OR
  FK_Reference_Coding_ID IN (
    SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE (
      Concept IN ('bmi') AND [Version]=2 OR
      Concept IN ('hba1c') AND [Version]=2 OR
      Concept IN ('cholesterol') AND [Version]=2 OR
      Concept IN ('ldl-cholesterol') AND [Version]=1 OR
      Concept IN ('hdl-cholesterol') AND [Version]=1 OR
      Concept IN ('vitamin-d') AND [Version]=1 OR
      Concept IN ('testosterone') AND [Version]=1 OR
      Concept IN ('egfr') AND [Version]=1 OR
      Concept IN ('sex-hormone-binding-globulin') AND [Version]=1
    )
  )
)
AND FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
AND EventDate > @EventsFromDate
AND [Value] IS NOT NULL
AND [Value] != '0';

IF OBJECT_ID('tempdb..#PatientValuesWithNames') IS NOT NULL DROP TABLE #PatientValuesWithNames;
SELECT 
	FK_Patient_Link_ID,
	EventDate,
  CASE WHEN c.Concept IS NULL THEN s.Concept ELSE c.Concept END AS Concept,
	[Value]
INTO #PatientValuesWithNames
FROM #PatientValuesWithIds p
LEFT OUTER JOIN #VersionedCodeSets c on c.FK_Reference_Coding_ID = p.FK_Reference_Coding_ID
LEFT OUTER JOIN #VersionedSnomedSets s on s.FK_Reference_SnomedCT_ID = p.FK_Reference_SnomedCT_ID;

-- Not needed. Tidy up.
DROP TABLE #PatientValuesWithIds;

-- get most recent value at in the period [index date - 2 years, index date]
IF OBJECT_ID('tempdb..#PatientValues') IS NOT NULL DROP TABLE #PatientValues;
SELECT main.FK_Patient_Link_ID, main.Concept, MAX(main.[Value]) AS LatestValue
INTO #PatientValues
FROM #PatientValuesWithNames main
INNER JOIN (
  SELECT p.FK_Patient_Link_ID, Concept, MAX(EventDate) AS LatestDate FROM #PatientValuesWithNames pv
  INNER JOIN #PatientIdsAndIndexDates p 
    ON p.FK_Patient_Link_ID = pv.FK_Patient_Link_ID
    AND pv.EventDate <= p.IndexDate
    AND pv.EventDate >= DATEADD(year, -2, p.IndexDate)
  GROUP BY p.FK_Patient_Link_ID, Concept
) sub on sub.FK_Patient_Link_ID = main.FK_Patient_Link_ID and sub.LatestDate = main.EventDate and sub.Concept = main.Concept
GROUP BY main.FK_Patient_Link_ID, main.Concept;

-- Not needed. Tidy up.
DROP TABLE #PatientValuesWithNames;

IF OBJECT_ID('tempdb..#PatientValuesBMI') IS NOT NULL DROP TABLE #PatientValuesBMI;
SELECT FK_Patient_Link_ID, LatestValue AS LatestBMIValue INTO #PatientValuesBMI
FROM #PatientValues
WHERE Concept = 'bmi';

IF OBJECT_ID('tempdb..#PatientValuesHBA1C') IS NOT NULL DROP TABLE #PatientValuesHBA1C;
SELECT FK_Patient_Link_ID, LatestValue AS LatestHBA1CValue INTO #PatientValuesHBA1C
FROM #PatientValues
WHERE Concept = 'hba1c';

IF OBJECT_ID('tempdb..#PatientValuesCHOLESTEROL') IS NOT NULL DROP TABLE #PatientValuesCHOLESTEROL;
SELECT FK_Patient_Link_ID, LatestValue AS LatestCHOLESTEROLValue INTO #PatientValuesCHOLESTEROL
FROM #PatientValues
WHERE Concept = 'cholesterol';

IF OBJECT_ID('tempdb..#PatientValuesLDL') IS NOT NULL DROP TABLE #PatientValuesLDL;
SELECT FK_Patient_Link_ID, LatestValue AS LatestLDLValue INTO #PatientValuesLDL
FROM #PatientValues
WHERE Concept = 'ldl-cholesterol';

IF OBJECT_ID('tempdb..#PatientValuesHDL') IS NOT NULL DROP TABLE #PatientValuesHDL;
SELECT FK_Patient_Link_ID, LatestValue AS LatestHDLValue INTO #PatientValuesHDL
FROM #PatientValues
WHERE Concept = 'hdl-cholesterol';

IF OBJECT_ID('tempdb..#PatientValuesVITAMIND') IS NOT NULL DROP TABLE #PatientValuesVITAMIND;
SELECT FK_Patient_Link_ID, LatestValue AS LatestVITAMINDValue INTO #PatientValuesVITAMIND
FROM #PatientValues
WHERE Concept = 'vitamin-d';

IF OBJECT_ID('tempdb..#PatientValuesTESTOSTERONE') IS NOT NULL DROP TABLE #PatientValuesTESTOSTERONE;
SELECT FK_Patient_Link_ID, LatestValue AS LatestTESTOSTERONEValue INTO #PatientValuesTESTOSTERONE
FROM #PatientValues
WHERE Concept = 'testosterone';

IF OBJECT_ID('tempdb..#PatientValuesEGFR') IS NOT NULL DROP TABLE #PatientValuesEGFR;
SELECT FK_Patient_Link_ID, LatestValue AS LatestEGFRValue INTO #PatientValuesEGFR
FROM #PatientValues
WHERE Concept = 'egfr';

IF OBJECT_ID('tempdb..#PatientValuesSHBG') IS NOT NULL DROP TABLE #PatientValuesSHBG;
SELECT FK_Patient_Link_ID, LatestValue AS LatestSHBGValue INTO #PatientValuesSHBG
FROM #PatientValues
WHERE Concept = 'sex-hormone-binding-globulin';


-- diagnoses
--> CODESET copd:1
IF OBJECT_ID('tempdb..#PatientDiagnosesCOPD') IS NOT NULL DROP TABLE #PatientDiagnosesCOPD;
SELECT DISTINCT FK_Patient_Link_ID
INTO #PatientDiagnosesCOPD
FROM RLS.vw_GP_Events
WHERE (
	FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE (Concept IN ('copd') AND [Version]=1)) OR
  FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE (Concept IN ('copd') AND [Version]=1))
)
AND FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients);

--> CODESET asthma:1
IF OBJECT_ID('tempdb..#PatientDiagnosesASTHMA') IS NOT NULL DROP TABLE #PatientDiagnosesASTHMA;
SELECT DISTINCT FK_Patient_Link_ID
INTO #PatientDiagnosesASTHMA
FROM RLS.vw_GP_Events
WHERE (
	FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE (Concept IN ('asthma') AND [Version]=1)) OR
  FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE (Concept IN ('asthma') AND [Version]=1))
)
AND FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients);

--> CODESET severe-mental-illness:1
IF OBJECT_ID('tempdb..#PatientDiagnosesSEVEREMENTALILLNESS') IS NOT NULL DROP TABLE #PatientDiagnosesSEVEREMENTALILLNESS;
SELECT DISTINCT FK_Patient_Link_ID
INTO #PatientDiagnosesSEVEREMENTALILLNESS
FROM RLS.vw_GP_Events
WHERE (
	FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE (Concept IN ('severe-mental-illness') AND [Version]=1)) OR
  FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE (Concept IN ('severe-mental-illness') AND [Version]=1))
)
AND FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients);

--> CODESET hypertension:1
IF OBJECT_ID('tempdb..#PatientDiagnosesHYPERTENSION') IS NOT NULL DROP TABLE #PatientDiagnosesHYPERTENSION;
SELECT DISTINCT FK_Patient_Link_ID
INTO #PatientDiagnosesHYPERTENSION
FROM RLS.vw_GP_Events
WHERE (
	FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE (Concept IN ('hypertension') AND [Version]=1)) OR
  FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE (Concept IN ('hypertension') AND [Version]=1))
)
AND FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients);


-- medications
--> CODESET metformin:1
IF OBJECT_ID('tempdb..#PatientMedicationsMETFORMIN') IS NOT NULL DROP TABLE #PatientMedicationsMETFORMIN;
SELECT 
	FK_Patient_Link_ID,
	CAST(MedicationDate AS DATE) AS MedicationDate
INTO #PatientMedicationsMETFORMIN
FROM RLS.vw_GP_Medications
WHERE (
	FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE (Concept IN ('metformin') AND [Version]=1)) OR
  FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE (Concept IN ('metformin') AND [Version]=1))
)
AND FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
AND MedicationDate > @MedicationsFromDate;

--> CODESET glp1-receptor-agonists:1
IF OBJECT_ID('tempdb..#PatientMedicationsGLP1') IS NOT NULL DROP TABLE #PatientMedicationsGLP1;
SELECT 
	FK_Patient_Link_ID,
	CAST(MedicationDate AS DATE) AS MedicationDate
INTO #PatientMedicationsGLP1
FROM RLS.vw_GP_Medications
WHERE (
	FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE (Concept IN ('glp1-receptor-agonists') AND [Version]=1)) OR
  FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE (Concept IN ('glp1-receptor-agonists') AND [Version]=1))
)
AND FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
AND MedicationDate > @MedicationsFromDate;

--> CODESET insulin:1
IF OBJECT_ID('tempdb..#PatientMedicationsINSULIN') IS NOT NULL DROP TABLE #PatientMedicationsINSULIN;
SELECT 
	FK_Patient_Link_ID,
	CAST(MedicationDate AS DATE) AS MedicationDate
INTO #PatientMedicationsINSULIN
FROM RLS.vw_GP_Medications
WHERE (
	FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE (Concept IN ('insulin') AND [Version]=1)) OR
  FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE (Concept IN ('insulin') AND [Version]=1))
)
AND FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
AND MedicationDate > @MedicationsFromDate;

--> CODESET sglt2-inhibitors:1
IF OBJECT_ID('tempdb..#PatientMedicationsSGLT2I') IS NOT NULL DROP TABLE #PatientMedicationsSGLT2I;
SELECT 
	FK_Patient_Link_ID,
	CAST(MedicationDate AS DATE) AS MedicationDate
INTO #PatientMedicationsSGLT2I
FROM RLS.vw_GP_Medications
WHERE (
	FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE (Concept IN ('sglt2-inhibitors') AND [Version]=1)) OR
  FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE (Concept IN ('sglt2-inhibitors') AND [Version]=1))
)
AND FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
AND MedicationDate > @MedicationsFromDate;

--> CODESET sulphonylureas:1
IF OBJECT_ID('tempdb..#PatientMedicationsSULPHONYLUREAS') IS NOT NULL DROP TABLE #PatientMedicationsSULPHONYLUREAS;
SELECT 
	FK_Patient_Link_ID,
	CAST(MedicationDate AS DATE) AS MedicationDate
INTO #PatientMedicationsSULPHONYLUREAS
FROM RLS.vw_GP_Medications
WHERE (
	FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE (Concept IN ('sulphonylureas') AND [Version]=1)) OR
  FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE (Concept IN ('sulphonylureas') AND [Version]=1))
)
AND FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
AND MedicationDate > @MedicationsFromDate;

--> CODESET ace-inhibitor:1
IF OBJECT_ID('tempdb..#PatientMedicationsACEI') IS NOT NULL DROP TABLE #PatientMedicationsACEI;
SELECT 
	FK_Patient_Link_ID,
	CAST(MedicationDate AS DATE) AS MedicationDate
INTO #PatientMedicationsACEI
FROM RLS.vw_GP_Medications
WHERE (
	FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE (Concept IN ('ace-inhibitor') AND [Version]=1)) OR
  FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE (Concept IN ('ace-inhibitor') AND [Version]=1))
)
AND FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
AND MedicationDate > @MedicationsFromDate;

--> CODESET aspirin:1
IF OBJECT_ID('tempdb..#PatientMedicationsASPIRIN') IS NOT NULL DROP TABLE #PatientMedicationsASPIRIN;
SELECT 
	FK_Patient_Link_ID,
	CAST(MedicationDate AS DATE) AS MedicationDate
INTO #PatientMedicationsASPIRIN
FROM RLS.vw_GP_Medications
WHERE (
	FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE (Concept IN ('aspirin') AND [Version]=1)) OR
  FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE (Concept IN ('aspirin') AND [Version]=1))
)
AND FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
AND MedicationDate > @MedicationsFromDate;

--> CODESET clopidogrel:1
IF OBJECT_ID('tempdb..#PatientMedicationsCLOPIDOGREL') IS NOT NULL DROP TABLE #PatientMedicationsCLOPIDOGREL;
SELECT 
	FK_Patient_Link_ID,
	CAST(MedicationDate AS DATE) AS MedicationDate
INTO #PatientMedicationsCLOPIDOGREL
FROM RLS.vw_GP_Medications
WHERE (
	FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE (Concept IN ('clopidogrel') AND [Version]=1)) OR
  FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE (Concept IN ('clopidogrel') AND [Version]=1))
)
AND FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
AND MedicationDate > @MedicationsFromDate;

-- record as on med if value within 6 months on index date
IF OBJECT_ID('tempdb..#TempPatMedsACEI') IS NOT NULL DROP TABLE #TempPatMedsACEI;
SELECT 
  p.FK_Patient_Link_ID
INTO #TempPatMedsACEI
FROM #PatientIdsAndIndexDates p
INNER JOIN #PatientMedicationsACEI acei
  ON acei.FK_Patient_Link_ID = p.FK_Patient_Link_ID
  AND acei.MedicationDate <= p.IndexDate
  AND acei.MedicationDate >= DATEADD(day, -183, p.IndexDate)
GROUP BY p.FK_Patient_Link_ID;

IF OBJECT_ID('tempdb..#TempPatMedsASPIRIN') IS NOT NULL DROP TABLE #TempPatMedsASPIRIN;
SELECT 
  p.FK_Patient_Link_ID
INTO #TempPatMedsASPIRIN
FROM #PatientIdsAndIndexDates p
INNER JOIN #PatientMedicationsASPIRIN aspirin
  ON aspirin.FK_Patient_Link_ID = p.FK_Patient_Link_ID
  AND aspirin.MedicationDate <= p.IndexDate
  AND aspirin.MedicationDate >= DATEADD(day, -183, p.IndexDate)
GROUP BY p.FK_Patient_Link_ID;

IF OBJECT_ID('tempdb..#TempPatMedsCLOPIDOGREL') IS NOT NULL DROP TABLE #TempPatMedsCLOPIDOGREL;
SELECT 
  p.FK_Patient_Link_ID
INTO #TempPatMedsCLOPIDOGREL
FROM #PatientIdsAndIndexDates p
INNER JOIN #PatientMedicationsCLOPIDOGREL clop
  ON clop.FK_Patient_Link_ID = p.FK_Patient_Link_ID
  AND clop.MedicationDate <= p.IndexDate
  AND clop.MedicationDate >= DATEADD(day, -183, p.IndexDate)
GROUP BY p.FK_Patient_Link_ID;

IF OBJECT_ID('tempdb..#TempPatMedsMETFORMIN') IS NOT NULL DROP TABLE #TempPatMedsMETFORMIN;
SELECT 
  p.FK_Patient_Link_ID
INTO #TempPatMedsMETFORMIN
FROM #PatientIdsAndIndexDates p
INNER JOIN #PatientMedicationsMETFORMIN met
  ON met.FK_Patient_Link_ID = p.FK_Patient_Link_ID
  AND met.MedicationDate <= p.IndexDate
  AND met.MedicationDate >= DATEADD(day, -183, p.IndexDate)
GROUP BY p.FK_Patient_Link_ID;

IF OBJECT_ID('tempdb..#TempPatMedsGLP1') IS NOT NULL DROP TABLE #TempPatMedsGLP1;
SELECT 
  p.FK_Patient_Link_ID
INTO #TempPatMedsGLP1
FROM #PatientIdsAndIndexDates p
INNER JOIN #PatientMedicationsGLP1 glp1
  ON glp1.FK_Patient_Link_ID = p.FK_Patient_Link_ID
  AND glp1.MedicationDate <= p.IndexDate
  AND glp1.MedicationDate >= DATEADD(day, -183, p.IndexDate)
GROUP BY p.FK_Patient_Link_ID;

IF OBJECT_ID('tempdb..#TempPatMedsINSULIN') IS NOT NULL DROP TABLE #TempPatMedsINSULIN;
SELECT 
  p.FK_Patient_Link_ID
INTO #TempPatMedsINSULIN
FROM #PatientIdsAndIndexDates p
INNER JOIN #PatientMedicationsINSULIN insu
  ON insu.FK_Patient_Link_ID = p.FK_Patient_Link_ID
  AND insu.MedicationDate <= p.IndexDate
  AND insu.MedicationDate >= DATEADD(day, -183, p.IndexDate)
GROUP BY p.FK_Patient_Link_ID;

IF OBJECT_ID('tempdb..#TempPatMedsSGLT2I') IS NOT NULL DROP TABLE #TempPatMedsSGLT2I;
SELECT 
  p.FK_Patient_Link_ID
INTO #TempPatMedsSGLT2I
FROM #PatientIdsAndIndexDates p
INNER JOIN #PatientMedicationsSGLT2I sglt
  ON sglt.FK_Patient_Link_ID = p.FK_Patient_Link_ID
  AND sglt.MedicationDate <= p.IndexDate
  AND sglt.MedicationDate >= DATEADD(day, -183, p.IndexDate)
GROUP BY p.FK_Patient_Link_ID;

IF OBJECT_ID('tempdb..#TempPatMedsSULPHONYLUREAS') IS NOT NULL DROP TABLE #TempPatMedsSULPHONYLUREAS;
SELECT 
  p.FK_Patient_Link_ID
INTO #TempPatMedsSULPHONYLUREAS
FROM #PatientIdsAndIndexDates p
INNER JOIN #PatientMedicationsSULPHONYLUREAS sulp
  ON sulp.FK_Patient_Link_ID = p.FK_Patient_Link_ID
  AND sulp.MedicationDate <= p.IndexDate
  AND sulp.MedicationDate >= DATEADD(day, -183, p.IndexDate)
GROUP BY p.FK_Patient_Link_ID;

-- record as on med if value within 6 months on index date
IF OBJECT_ID('tempdb..#PatientMedications') IS NOT NULL DROP TABLE #PatientMedications;
SELECT 
  p.FK_Patient_Link_ID,
  CASE WHEN acei.FK_Patient_Link_ID IS NULL THEN 'N' ELSE 'Y' END AS IsOnACEIorARB,
  CASE WHEN aspirin.FK_Patient_Link_ID IS NULL THEN 'N' ELSE 'Y' END AS IsOnAspirin,
  CASE WHEN clop.FK_Patient_Link_ID IS NULL THEN 'N' ELSE 'Y' END AS IsOnClopidogrel,
  CASE WHEN insu.FK_Patient_Link_ID IS NULL THEN 'N' ELSE 'Y' END AS IsOnInsulin,
  CASE WHEN sglt.FK_Patient_Link_ID IS NULL THEN 'N' ELSE 'Y' END AS IsOnSGLTI,
  CASE WHEN glp1.FK_Patient_Link_ID IS NULL THEN 'N' ELSE 'Y' END AS IsOnGLP1A,
  CASE WHEN sulp.FK_Patient_Link_ID IS NULL THEN 'N' ELSE 'Y' END AS IsOnSulphonylurea,
  CASE WHEN met.FK_Patient_Link_ID IS NULL THEN 'N' ELSE 'Y' END AS IsOnMetformin
INTO #PatientMedications
FROM #PatientIdsAndIndexDates p
LEFT OUTER JOIN #TempPatMedsACEI acei ON acei.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #TempPatMedsASPIRIN aspirin ON aspirin.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #TempPatMedsCLOPIDOGREL clop ON clop.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #TempPatMedsMETFORMIN met ON met.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #TempPatMedsGLP1 glp1 ON glp1.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #TempPatMedsINSULIN insu ON insu.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #TempPatMedsSGLT2I sglt ON sglt.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #TempPatMedsSULPHONYLUREAS sulp ON sulp.FK_Patient_Link_ID = p.FK_Patient_Link_ID;
  
-- Get patient list of those with COVID death within 28 days of positive test
IF OBJECT_ID('tempdb..#COVIDDeath') IS NOT NULL DROP TABLE #COVIDDeath;
SELECT DISTINCT FK_Patient_Link_ID 
INTO #COVIDDeath FROM RLS.vw_COVID19
WHERE DeathWithin28Days = 'Y';

-- Bring together for final output
-- Patients in main cohort
SELECT 
  m.FK_Patient_Link_ID AS PatientId,
  NULL AS MainCohortMatchedPatientId,
  YearOfBirth,
  DeathDate,
  CASE WHEN covidDeath.FK_Patient_Link_ID IS NULL THEN 'N' ELSE 'Y' END AS DeathWithin28DaysCovidPositiveTest,
  Sex,
  LSOA_Code AS LSOA,
  TownsendScoreHigherIsMoreDeprived,
  TownsendQuintileHigherIsMoreDeprived,
  FirstDiagnosisDate,
  FirstT1DiagnosisDate,
  FirstT2DiagnosisDate,
  IndexDate AS COVIDPositiveTestDate,
  FirstAdmissionPostCOVIDTest,
  LengthOfStay,
  EthnicCategoryDescription,
  LatestBMIValue,
  LatestHBA1CValue,
  LatestCHOLESTEROLValue,
  LatestLDLValue,
  LatestHDLValue,
  LatestVITAMINDValue,
  LatestTESTOSTERONEValue,
  LatestEGFRValue,
  LatestSHBGValue,
  smok.PassiveSmoker AS IsPassiveSmoker,
  smok.WorstSmokingStatus,
  smok.CurrentSmokingStatus,
  CASE WHEN copd.FK_Patient_Link_ID IS NULL THEN 'N' ELSE 'Y' END AS PatientHasCOPD,
  CASE WHEN asthma.FK_Patient_Link_ID IS NULL THEN 'N' ELSE 'Y' END AS PatientHasASTHMA,
  CASE WHEN smi.FK_Patient_Link_ID IS NULL THEN 'N' ELSE 'Y' END AS PatientHasSMI,
  IsOnACEIorARB,
  IsOnAspirin,
  IsOnClopidogrel,
  IsOnMetformin,
  CASE WHEN htn.FK_Patient_Link_ID IS NULL THEN 'N' ELSE 'Y' END AS PatientHasHYPERTENSION,
  VaccineDose1Date AS FirstVaccineDate,
  VaccineDose2Date AS SecondVaccineDate,
  IsOnInsulin,
  IsOnSGLTI,
  IsOnGLP1A,
  IsOnSulphonylurea
FROM #MainCohort m
LEFT OUTER JOIN RLS.vw_Patient_Link pl ON pl.PK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientValuesBMI bmi ON bmi.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientTownsend town ON town.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientValuesHBA1C hba1c ON hba1c.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientValuesCHOLESTEROL cholesterol ON cholesterol.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientValuesLDL ldl ON ldl.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientValuesHDL hdl ON hdl.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientValuesVITAMIND vitamind ON vitamind.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientValuesTESTOSTERONE testosterone ON testosterone.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientValuesEGFR egfr ON egfr.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientValuesSHBG shbg ON shbg.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientDiagnosesCOPD copd ON copd.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientDiagnosesASTHMA asthma ON asthma.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientDiagnosesSEVEREMENTALILLNESS smi ON smi.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientDiagnosesHYPERTENSION htn ON htn.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientMedications pm ON pm.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientSmokingStatus smok ON smok.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #COVIDDeath covidDeath ON covidDeath.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientsFirstAdmissionPostTest fa ON fa.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #COVIDVaccinations v ON v.FK_Patient_Link_ID = m.FK_Patient_Link_ID
UNION
--Patients in matched cohort
SELECT 
  m.FK_Patient_Link_ID AS PatientId,
  m.PatientWhoIsMatched AS MainCohortMatchedPatientId,
  MatchingYearOfBirth,
  DeathDate,
  CASE WHEN covidDeath.FK_Patient_Link_ID IS NULL THEN 'N' ELSE 'Y' END AS DeathWithin28DaysCovidPositiveTest,
  Sex,
  LSOA_Code AS LSOA,
  TownsendScoreHigherIsMoreDeprived,
  TownsendQuintileHigherIsMoreDeprived,
  NULL AS FirstDiagnosisDate,
  NULL AS FirstT1DiagnosisDate,
  NULL AS FirstT2DiagnosisDate,
  IndexDate AS COVIDPositiveTestDate,
  FirstAdmissionPostCOVIDTest,
  LengthOfStay,
  EthnicCategoryDescription,
  LatestBMIValue,
  LatestHBA1CValue,
  LatestCHOLESTEROLValue,
  LatestLDLValue,
  LatestHDLValue,
  LatestVITAMINDValue,
  LatestTESTOSTERONEValue,
  LatestEGFRValue,
  LatestSHBGValue,
  smok.PassiveSmoker AS IsPassiveSmoker,
  smok.WorstSmokingStatus,
  smok.CurrentSmokingStatus,
  CASE WHEN copd.FK_Patient_Link_ID IS NULL THEN 'N' ELSE 'Y' END AS PatientHasCOPD,
  CASE WHEN asthma.FK_Patient_Link_ID IS NULL THEN 'N' ELSE 'Y' END AS PatientHasASTHMA,
  CASE WHEN smi.FK_Patient_Link_ID IS NULL THEN 'N' ELSE 'Y' END AS PatientHasSMI,
  IsOnACEIorARB,
  IsOnAspirin,
  IsOnClopidogrel,
  IsOnMetformin,
  CASE WHEN htn.FK_Patient_Link_ID IS NULL THEN 'N' ELSE 'Y' END AS PatientHasHYPERTENSION,
  VaccineDose1Date AS FirstVaccineDate,
  VaccineDose2Date AS SecondVaccineDate,
  IsOnInsulin,
  IsOnSGLTI,
  IsOnGLP1A,
  IsOnSulphonylurea
FROM #MatchedCohort m
LEFT OUTER JOIN RLS.vw_Patient_Link pl ON pl.PK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientValuesBMI bmi ON bmi.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientTownsend town ON town.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientValuesHBA1C hba1c ON hba1c.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientValuesCHOLESTEROL cholesterol ON cholesterol.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientValuesLDL ldl ON ldl.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientValuesHDL hdl ON hdl.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientValuesVITAMIND vitamind ON vitamind.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientValuesTESTOSTERONE testosterone ON testosterone.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientValuesEGFR egfr ON egfr.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientValuesSHBG shbg ON shbg.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientDiagnosesCOPD copd ON copd.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientDiagnosesASTHMA asthma ON asthma.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientDiagnosesSEVEREMENTALILLNESS smi ON smi.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientDiagnosesHYPERTENSION htn ON htn.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientMedications pm ON pm.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientSmokingStatus smok ON smok.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #COVIDDeath covidDeath ON covidDeath.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientsFirstAdmissionPostTest fa ON fa.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #COVIDVaccinations v ON v.FK_Patient_Link_ID = m.FK_Patient_Link_ID;