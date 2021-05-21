--┌────────────────────────────────────┐
--│ Patient information for SMI cohort │
--└────────────────────────────────────┘

-- REVIEW LOG:

-- OUTPUT: Data with the following fields
-- Patient Id
-- Month and year of birth (YYYY-MM)
-- Sex (male/female)
-- Ethnicity (white/black/asian/mixed/other)
-- IMD score
-- LSOA code
-- GP practice (anon id)
-- Any hx of psychosis/schizophrenia (yes/no)
-- Earliest recorded date of psychosis/schizophrenia diagnosis (YYYY-MM or N/A)
-- Any hx of bipolar disorder (yes/no)
-- Earliest recorded date of bipolar diagnosis (YYYY-MM or N/A)
-- Any hx of major depressive disorder (yes/no)
-- Earliest recorded date of MDD diagnosis (YYYY-MM or N/A)
-- Recent (12 months) major depression (yes/no)
-- H/O comorbid physical health conditions (all yes/no plus earliest recorded date): coronary heart disease, myocardial infarction, asthma, bronchiectasis, COPD, pulmonary fibrosis, cystic fibrosis,  cancer (within 5 years), dementia,  diabetes, chronic kidney disease, liver disease, hemiplegia, rheumatoid arthritis and other inflammatory diseases,  thyroid disorders, and/or HIV/AIDS
-- Death after 31.01.2020 (yes/no)
-- Death within 28 days of Covid Diagnosis (yes/no)
-- Date of death due to Covid-19 (YYYY-MM or N/A)
-- Vaccination offered (yes/no)
-- Patient refused vaccination (yes/no)
-- Date of vaccination (YYYY-MM or N/A)

-- Set the start date
DECLARE @StartDate datetime;
SET @StartDate = '2020-01-31';

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

--> CODESET recurrent-depressive schizophrenia-psychosis bipolar severe-mental-illness

--> EXECUTE query-patient-sex.sql
--> EXECUTE query-patient-imd.sql
--> EXECUTE query-patient-year-of-birth.sql
--> EXECUTE query-patient-lsoa.sql
--> EXECUTE query-patient-practice-and-ccg.sql

--> EXECUTE query-patient-ltcs.sql
--> EXECUTE query-patient-ltcs-group.sql

--> EXECUTE query-get-covid-vaccines.sql

IF OBJECT_ID('tempdb..#COVIDVaccinations1') IS NOT NULL DROP TABLE #COVIDVaccinations1;
SELECT 
	FK_Patient_Link_ID
	,FirstVaccineDate = MAX(CASE WHEN VaccineDate IS NOT NULL AND DaysSinceFirstVaccine = 0 THEN VaccineDate ELSE NULL END) 
	,SecondVaccineDate = MAX(CASE WHEN VaccineDate IS NOT NULL AND DaysSinceFirstVaccine != 0 THEN VaccineDate ELSE NULL END) 
INTO #COVIDVaccinations1
FROM #COVIDVaccinations
GROUP BY FK_Patient_Link_ID

-- Get patients with covid vaccine refusal
--> CODESET covid-vaccine-declined
SELECT FK_Patient_Link_ID, MIN(EventDate) AS DateVaccineDeclined 
INTO #VaccineDeclinedPatients FROM [RLS].[vw_GP_Events]
WHERE SuppliedCode IN (SELECT [Code] FROM #AllCodes WHERE [Concept] = 'covid-vaccine-declined' AND [Version] = 1)
GROUP BY FK_Patient_Link_ID;

-- Get patient list of those with COVID death within 28 days of positive test
IF OBJECT_ID('tempdb..#COVIDDeath') IS NOT NULL DROP TABLE #COVIDDeath;
SELECT DISTINCT FK_Patient_Link_ID 
INTO #COVIDDeath FROM RLS.vw_COVID19
WHERE DeathWithin28Days = 'Y';


---- CREATE TABLE OF ALL PATIENTS THAT HAVE ANY LIFETIME DIAGNOSES OF SMI AS OF 31.01.20

IF OBJECT_ID('tempdb..#SMI_Episodes') IS NOT NULL DROP TABLE #SMI_Episodes;
SELECT gp.FK_Patient_Link_ID, 
		YearOfBirth, 
		Sex,
		LSOA_Code,
		EthnicMainGroup,
		IMD2019Decile1IsMostDeprived10IsLeastDeprived, --may need changing to IMD Score
		prac.GPPracticeCode, -- needs anonymising
		EventDate,
		SuppliedCode,
		Schizophrenia_Psychosis_Code = CASE WHEN SuppliedCode IN 
					( SELECT [Code] FROM #AllCodes WHERE [Concept] IN ('schizophrenia-psychosis') AND [Version] = 1 ) THEN 1 ELSE 0 END,
		Bipolar_Code = CASE WHEN SuppliedCode IN 
					( SELECT [Code] FROM #AllCodes WHERE [Concept] IN ('bipolar') AND [Version] = 1 ) THEN 1 ELSE 0 END,			
		Recurrent_Depressive_Code = CASE WHEN SuppliedCode IN 
					( SELECT [Code] FROM #AllCodes WHERE [Concept] IN ('recurrent-depressive') AND [Version] = 1 ) THEN 1 ELSE 0 END
INTO #SMI_Episodes
FROM [RLS].[vw_GP_Events] gp
LEFT OUTER JOIN #Patients p ON p.FK_Patient_Link_ID = gp.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientLSOA lsoa ON lsoa.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientYearOfBirth yob ON yob.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientSex sex ON sex.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientIMDDecile imd ON imd.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientPracticeAndCCG prac ON prac.FK_Patient_Link_ID = p.FK_Patient_Link_ID
WHERE SuppliedCode IN (
	SELECT [Code] FROM #AllCodes WHERE [Concept] IN ('severe-mental-illness') AND [Version] = 1
)
	AND (gp.EventDate) <= '2020-01-31'

-- Define the main cohort to be matched

IF OBJECT_ID('tempdb..#MainCohort') IS NOT NULL DROP TABLE #MainCohort;
SELECT DISTINCT FK_Patient_Link_ID, 
		YearOfBirth, 
		Sex,
		LSOA_Code,
		EthnicMainGroup,
		IMD2019Decile1IsMostDeprived10IsLeastDeprived, --may need changing to IMD Score
		GPPracticeCode -- needs anonymising
INTO #MainCohort
FROM #SMI_Episodes
--57,622

-- Define the population of potential matches for the cohort
IF OBJECT_ID('tempdb..#PotentialMatches') IS NOT NULL DROP TABLE #PotentialMatches;
SELECT p.FK_Patient_Link_ID, Sex, YearOfBirth
INTO #PotentialMatches
FROM #Patients p
LEFT OUTER JOIN #PatientSex sex ON sex.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientYearOfBirth yob ON yob.FK_Patient_Link_ID = p.FK_Patient_Link_ID
EXCEPT
SELECT FK_Patient_Link_ID, Sex, YearOfBirth FROM #MainCohort;
-- 3,378,730

--> EXECUTE query-cohort-matching-yob-sex.sql yob-flex:1

-- Get the matched cohort detail - same as main cohort
IF OBJECT_ID('tempdb..#MatchedCohort') IS NOT NULL DROP TABLE #MatchedCohort;
SELECT 
  c.MatchingPatientId AS FK_Patient_Link_ID,
  Sex,
  MatchingYearOfBirth,
  LSOA_Code,
  EthnicMainGroup,
  IMD2019Decile1IsMostDeprived10IsLeastDeprived, --may need changing to IMD Score
  GPPracticeCode, -- needs anonymising
  PatientId AS PatientWhoIsMatched
INTO #MatchedCohort
FROM #CohortStore c
LEFT OUTER JOIN #Patients p ON p.FK_Patient_Link_ID = c.MatchingPatientId
LEFT OUTER JOIN #PatientLSOA lsoa ON lsoa.FK_Patient_Link_ID = c.MatchingPatientId
LEFT OUTER JOIN #PatientIMDDecile imd ON imd.FK_Patient_Link_ID = c.MatchingPatientId
LEFT OUTER JOIN #PatientPracticeAndCCG prac ON prac.FK_Patient_Link_ID = p.FK_Patient_Link_ID
WHERE c.PatientId IN (SELECT FK_Patient_Link_ID FROM #Patients);
--254,824

-- Define a table with all the patient ids for the main cohort and the matched cohort
IF OBJECT_ID('tempdb..#PatientIds') IS NOT NULL DROP TABLE #PatientIds;
SELECT PatientId AS FK_Patient_Link_ID INTO #PatientIds FROM #CohortStore
UNION
SELECT MatchingPatientId FROM #CohortStore;



-- TABLES WITH EARLIEST DIAGNOSES OF SMI DIAGNOSES

IF OBJECT_ID('tempdb..#EarliestDiagnosis_Schizophrenia_Psychosis') IS NOT NULL DROP TABLE #EarliestDiagnosis_Schizophrenia_Psychosis;
SELECT FK_Patient_Link_ID
	,EarliestDiagnosis_Schizophrenia_Psychosis = MIN(EventDate)
INTO #EarliestDiagnosis_Schizophrenia_Psychosis
FROM #SMI_Episodes 
WHERE Schizophrenia_Psychosis_Code = 1
GROUP BY FK_Patient_Link_ID

IF OBJECT_ID('tempdb..#EarliestDiagnosis_Bipolar') IS NOT NULL DROP TABLE #EarliestDiagnosis_Bipolar;
SELECT FK_Patient_Link_ID
	,EarliestDiagnosis_Bipolar = MIN(EventDate)
INTO #EarliestDiagnosis_Bipolar
FROM #SMI_Episodes 
WHERE Bipolar_Code = 1
GROUP BY FK_Patient_Link_ID

IF OBJECT_ID('tempdb..#EarliestDiagnosis_Recurrent_Depressive ') IS NOT NULL DROP TABLE #EarliestDiagnosis_Recurrent_Depressive ;
SELECT FK_Patient_Link_ID
	,EarliestDiagnosis_Recurrent_Depressive = MIN(EventDate)
INTO #EarliestDiagnosis_Recurrent_Depressive
FROM #SMI_Episodes 
WHERE Recurrent_Depressive_Code = 1
GROUP BY FK_Patient_Link_ID



-- CREATE WIDE TABLE SHOWING WHICH PATIENTS HAVE A HISTORY OF EACH LTC

SELECT FK_Patient_Link_ID,
		HO_cancer 						= MAX(CASE WHEN LTC = 'cancer' then 1 else 0 end),
		HO_painful_condition 			= MAX(CASE WHEN LTC = 'painful condition' then 1 else 0 end),
		HO_migraine 					= MAX(CASE WHEN LTC = 'migraine' then 1 else 0 end),
		HO_epilepsy						= MAX(CASE WHEN LTC = 'epilepsy' then 1 else 0 end),
		HO_coronary_heart_disease 		= MAX(CASE WHEN LTC = 'coronary heart disease' then 1 else 0 end),
		HO_atrial_fibrillation 			= MAX(CASE WHEN LTC = 'atrial fibrillation' then 1 else 0 end),
		HO_heart_failure 				= MAX(CASE WHEN LTC = 'heart failure' then 1 else 0 end),
		HO_hypertension 				= MAX(CASE WHEN LTC = 'hypertension' then 1 else 0 end),
		HO_peripheral_vascular_disease  = MAX(CASE WHEN LTC = 'peripheral vascular disease' then 1 else 0 end),
		HO_stroke_and_transient_ischaemic_attack = MAX(CASE WHEN LTC = 'stroke & transient ischaemic attack' then 1 else 0 end),
		HO_diabetes 					= MAX(CASE WHEN LTC = 'diabetes' then 1 else 0 end),
		HO_thyroid_disorders 			= MAX(CASE WHEN LTC = 'thyroid disorders' then 1 else 0 end),
		HO_chronic_liver_disease 		= MAX(CASE WHEN LTC = 'chronic liver disease' then 1 else 0 end),
		HO_diverticular_disease_of_intestine = MAX(CASE WHEN LTC = 'diverticular disease of intestine' then 1 else 0 end),
		HO_inflammatory_bowel_disease 	= MAX(CASE WHEN LTC = 'inflammatory bowel disease' then 1 else 0 end),
		HO_irritable_bowel_syndrome 	= MAX(CASE WHEN LTC = 'irritable bowel syndrome' then 1 else 0 end),
		HO_constipation					= MAX(CASE WHEN LTC = 'constipation' then 1 else 0 end),
		HO_dyspepsia					= MAX(CASE WHEN LTC = 'dyspepsia' then 1 else 0 end),
		HO_peptic_ulcer_disease 		= MAX(CASE WHEN LTC = 'peptic ulcer disease' then 1 else 0 end),
		HO_psoriasis_or_eczema 			= MAX(CASE WHEN LTC = 'psoriasis or eczema' then 1 else 0 end),
		HO_rheumatoid_arthritis_other_inflammatory_polyarthropathies	= MAX(CASE WHEN LTC = 'rheumatoid arthritis and other inflammatory polyarthropathies' then 1 else 0 end),
		HO_multiple_sclerosis			= MAX(CASE WHEN LTC = 'multiple sclerosis' then 1 else 0 end),
		HO_parkinsons_disease 			= MAX(CASE WHEN LTC = 'parkinsons disease' then 1 else 0 end),
		HO_anorexia_bulimia 			= MAX(CASE WHEN LTC = 'anorexia or bulimia' then 1 else 0 end),
		HO_anxiety_other_somatoform_disorders	= MAX(CASE WHEN LTC = 'anxiety and other somatoform disorders' then 1 else 0 end),
		HO_dementia						= MAX(CASE WHEN LTC = 'dementia' then 1 else 0 end),
		HO_chronic_kidney_disease		= MAX(CASE WHEN LTC = 'chronic kidney disease' then 1 else 0 end),
		HO_prostate_disorders			= MAX(CASE WHEN LTC = 'prostate disorders' then 1 else 0 end),
		HO_asthma						= MAX(CASE WHEN LTC = 'asthma' then 1 else 0 end),
		HO_bronchiectasis				= MAX(CASE WHEN LTC = 'bronchiectasis' then 1 else 0 end),
		HO_chronic_sinusitis			= MAX(CASE WHEN LTC = 'chronic sinusitis' then 1 else 0 end),
		HO_copd							= MAX(CASE WHEN LTC = 'copd' then 1 else 0 end),
		HO_blindness_low_vision			= MAX(CASE WHEN LTC = 'blindness and low vision' then 1 else 0 end),
		HO_glaucoma						= MAX(CASE WHEN LTC = 'glaucoma' then 1 else 0 end),
		HO_hearing_loss					= MAX(CASE WHEN LTC = 'hearing loss' then 1 else 0 end),
		HO_learning_disability			= MAX(CASE WHEN LTC = 'learning disability' then 1 else 0 end),
		HO_alcohol_problems				= MAX(CASE WHEN LTC = 'alcohol problems' then 1 else 0 end),
		HO_psychoactive_substance_abuse	= MAX(CASE WHEN LTC = 'psychoactive substance abuse' then 1 else 0 end)
INTO #HistoryOfLTCs
FROM #PatientsWithLTCs
GROUP BY FK_Patient_Link_ID


--bring together for final output
--patients in main cohort
SELECT	 m.FK_Patient_Link_ID
		,NULL AS MainCohortMatchedPatientId
		,m.YearOfBirth
		,m.Sex
		,LSOA_Code
		,m.EthnicMainGroup
		,IMD2019Decile1IsMostDeprived10IsLeastDeprived --may need changing to IMD Score
		,GPPracticeCode -- needs anonymising
		,HO_cancer 
		,HO_painful_condition 
		,HO_migraine 
		,HO_epilepsy
		,HO_coronary_heart_disease 
		,HO_atrial_fibrillation 
		,HO_heart_failure 
		,HO_hypertension 
		,HO_peripheral_vascular_disease
		,HO_stroke_and_transient_ischaemic_attack
		,HO_diabetes 
		,HO_thyroid_disorders 
		,HO_chronic_liver_disease 
		,HO_diverticular_disease_of_intestine
		,HO_inflammatory_bowel_disease 
		,HO_irritable_bowel_syndrome 
		,HO_constipation
		,HO_dyspepsia
		,HO_peptic_ulcer_disease 
		,HO_psoriasis_or_eczema 
		,HO_rheumatoid_arthritis_other_inflammatory_polyarthropathies
		,HO_multiple_sclerosis
		,HO_parkinsons_disease 
		,HO_anorexia_bulimia 
		,HO_anxiety_other_somatoform_disorders
		,HO_dementia
		,HO_chronic_kidney_disease
		,HO_prostate_disorders
		,HO_asthma
		,HO_bronchiectasis
		,HO_chronic_sinusitis
		,HO_copd
		,HO_blindness_low_vision
		,HO_glaucoma
		,HO_hearing_loss
		,HO_asthma
		,HO_learning_disability
		,HO_alcohol_problems
		,HO_psychoactive_substance_abuse
		,HO_Schizophrenia_Psychosis = CASE WHEN EarliestDiagnosis_Schizophrenia_Psychosis IS NULL THEN 0 ELSE 1 END
		,EarliestDiagnosis_Schizophrenia_Psychosis
		,HO_Bipolar = CASE WHEN EarliestDiagnosis_Bipolar IS NULL THEN 0 ELSE 1 END
		,EarliestDiagnosis_Bipolar
		,HO_Recurrent_Depressive = CASE WHEN EarliestDiagnosis_Recurrent_Depressive IS NULL THEN 0 ELSE 1 END
		,EarliestDiagnosis_Recurrent_Depressive
		,DeathAfter31Jan20 = CASE WHEN pl.DeathDate > '2020-01-31' THEN 'Y' ELSE 'N' END
		,DeathWithin28DaysCovid = CASE WHEN cd.FK_Patient_Link_ID  IS NOT NULL THEN 'Y' ELSE 'N' END
		,DeathDateDueToCovid = CASE WHEN cd.FK_Patient_Link_ID  IS NOT NULL THEN pl.DeathDate ELSE null END
		,FirstVaccineDate
		,SecondVaccineDate
FROM #MainCohort m
LEFT OUTER JOIN RLS.vw_Patient_Link pl ON pl.PK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #HistoryOfLTCs ltc on ltc.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #EarliestDiagnosis_Schizophrenia_Psychosis edsc on edsc.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #EarliestDiagnosis_Bipolar edbp on edbp.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #EarliestDiagnosis_Recurrent_Depressive edmd on edmd.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #COVIDVaccinations1 vac on vac.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #VaccineDeclinedPatients vd ON vd.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #COVIDDeath cd ON cd.FK_Patient_Link_ID = m.FK_Patient_Link_ID
UNION
--patients in matched cohort
SELECT	m.FK_Patient_Link_ID
		,m.PatientWhoIsMatched AS MainCohortMatchedPatientId
		,m.MatchingYearOfBirth
		,m.Sex
		,LSOA_Code
		,m.EthnicMainGroup
		,IMD2019Decile1IsMostDeprived10IsLeastDeprived --may need changing to IMD Score
		,GPPracticeCode -- needs anonymising
		,HO_cancer 
		,HO_painful_condition 
		,HO_migraine 
		,HO_epilepsy
		,HO_coronary_heart_disease 
		,HO_atrial_fibrillation 
		,HO_heart_failure 
		,HO_hypertension 
		,HO_peripheral_vascular_disease
		,HO_stroke_and_transient_ischaemic_attack
		,HO_diabetes 
		,HO_thyroid_disorders 
		,HO_chronic_liver_disease 
		,HO_diverticular_disease_of_intestine
		,HO_inflammatory_bowel_disease 
		,HO_irritable_bowel_syndrome 
		,HO_constipation
		,HO_dyspepsia
		,HO_peptic_ulcer_disease 
		,HO_psoriasis_or_eczema 
		,HO_rheumatoid_arthritis_other_inflammatory_polyarthropathies
		,HO_multiple_sclerosis
		,HO_parkinsons_disease 
		,HO_anorexia_bulimia 
		,HO_anxiety_other_somatoform_disorders
		,HO_dementia
		,HO_chronic_kidney_disease
		,HO_prostate_disorders
		,HO_asthma
		,HO_bronchiectasis
		,HO_chronic_sinusitis
		,HO_copd
		,HO_blindness_low_vision
		,HO_glaucoma
		,HO_hearing_loss
		,HO_asthma
		,HO_learning_disability
		,HO_alcohol_problems
		,HO_psychoactive_substance_abuse
		,HO_Schizophrenia_Psychosis = CASE WHEN EarliestDiagnosis_Schizophrenia_Psychosis IS NULL THEN 0 ELSE 1 END
		,EarliestDiagnosis_Schizophrenia_Psychosis
		,HO_Bipolar = CASE WHEN EarliestDiagnosis_Bipolar IS NULL THEN 0 ELSE 1 END
		,EarliestDiagnosis_Bipolar
		,HO_Recurrent_Depressive = CASE WHEN EarliestDiagnosis_Recurrent_Depressive IS NULL THEN 0 ELSE 1 END
		,EarliestDiagnosis_Recurrent_Depressive
		,DeathAfter31Jan20 = CASE WHEN pl.DeathDate > '2020-01-31' THEN 'Y' ELSE 'N' END
		,DeathWithin28DaysCovid = CASE WHEN cd.FK_Patient_Link_ID  IS NOT NULL THEN 'Y' ELSE 'N' END
		,DeathDateDueToCovid = CASE WHEN cd.FK_Patient_Link_ID  IS NOT NULL THEN pl.DeathDate ELSE null END
		,FirstVaccineDate
		,SecondVaccineDate
FROM #MatchedCohort m
LEFT OUTER JOIN RLS.vw_Patient_Link pl ON pl.PK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #HistoryOfLTCs ltc on ltc.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #EarliestDiagnosis_Schizophrenia_Psychosis edsc on edsc.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #EarliestDiagnosis_Bipolar edbp on edbp.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #EarliestDiagnosis_Recurrent_Depressive edmd on edmd.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #COVIDVaccinations1 vac on vac.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #VaccineDeclinedPatients vd ON vd.FK_Patient_Link_ID = m.FK_Patient_Link_ID
LEFT OUTER JOIN #COVIDDeath cd ON cd.FK_Patient_Link_ID = m.FK_Patient_Link_ID;
--312,446

