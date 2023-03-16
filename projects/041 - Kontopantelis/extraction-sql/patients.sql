--┌──────────────────────────────────────────────────────────────────┐
--│ Patient information for those with biochemical evidence of CKD   │
--└──────────────────────────────────────────────────────────────────┘

------------ RESEARCH DATA ENGINEER CHECK ------------

------------------------------------------------------

-- PatientID
-- Year of birth (YYYY-MM)
-- Practice exit date (moved out of GM date) (YYYY-MM-DD)
-- Month and year of death (YYYY-MM)
-- Sex at birth (male/female)
-- Ethnicity (white/black/asian/mixed/other)
-- CCG of registered GP practice
-- Alcohol intake
-- Smoking status
-- BMI (closest to 2020-03-01)
-- BMI date
-- LSOA Code
-- IMD decile
-- First vaccination date (YYYY-MM or N/A)
-- Second vaccination date (YYYY-MM or N/A)
-- Third vaccination date (YYYY-MM or N/A)
-- Death within 28 days of Covid Diagnosis (Y/N)
-- Date of death due to Covid-19 (YYYY-MM or N/A)
-- Number of AE Episodes before covid (01.03.18 - 01.03.20)
-- Number of AE Episodes after covid (01.03.20 - 01.03.22)
-- Total AE Episodes (01.03.18 - 01.03.22)
-- Number of GP appointments before covid (01.03.18 - 01.03.20)
-- Number of GP appointments after covid (01.03.20 - 01.03.22)
-- Total GP appointments (01.03.18 - 01.03.22)
-- evidenceOfCKD_egfr (1/0)
-- evidenceOfCKD_acr (1/0)
-- EarliestEgfrEvidence
-- EarliestAcrEvidence 
-- HypertensionAtStudyStart
-- HypertensionDuringStudyPeriod
-- DiabetesAtStudyStart
-- DiabetesDuringStudyPeriod
-- CKDAtStudyStart
-- CKDDuringStudyPeriod

-- Set the start date
DECLARE @StartDate datetime;
DECLARE @EndDate datetime;
SET @StartDate = '2018-03-01';
SET @EndDate = '2022-03-01';

DECLARE @IndexDate datetime;
SET @IndexDate = '2020-03-01';

--Just want the output, not the messages
SET NOCOUNT ON;

--┌──────────────────────────────────────────────────────────────────────┐
--│ Define Cohort for RQ041: patients with biochemical evidence of CKD   │
--└──────────────────────────────────────────────────────────────────────┘

-- OBJECTIVE: To build the cohort of patients needed for RQ041. This reduces duplication of code in the template scripts.

-- COHORT: Any patient with biochemical evidence of CKD. More detail in the comments throughout this script.

-- INPUT: assumes there exists one temp table as follows:
-- #Patients (FK_Patient_Link_ID)
--  A distinct list of FK_Patient_Link_IDs for each patient in the cohort

-- OUTPUT: A temp table as follows:
-- #Cohort (FK_Patient_Link_ID)
-- #PatientEventData

--┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
--│ Create table of patients who are registered with a GM GP, and haven't joined the database from June 2022 onwards  │
--└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘

-- INPUT REQUIREMENTS: @StartDate

DECLARE @TempEndDate datetime;
SET @TempEndDate = '2022-06-01'; -- THIS TEMP END DATE IS DUE TO THE POST-COPI GOVERNANCE REQUIREMENTS 

IF OBJECT_ID('tempdb..#PatientsToInclude') IS NOT NULL DROP TABLE #PatientsToInclude;
SELECT FK_Patient_Link_ID INTO #PatientsToInclude
FROM RLS.vw_Patient_GP_History
GROUP BY FK_Patient_Link_ID
HAVING MIN(StartDate) < @TempEndDate; -- ENSURES NO PATIENTS THAT ENTERED THE DATABASE FROM JUNE 2022 ONWARDS ARE INCLUDED

-- Find all patients alive at start date
IF OBJECT_ID('tempdb..#PossiblePatients') IS NOT NULL DROP TABLE #PossiblePatients;
SELECT PK_Patient_Link_ID as FK_Patient_Link_ID, EthnicMainGroup, DeathDate INTO #PossiblePatients FROM [RLS].vw_Patient_Link
WHERE 
	(DeathDate IS NULL OR (DeathDate >= @StartDate AND DeathDate <= @TempEndDate))
	AND PK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #PatientsToInclude);

-- Find all patients registered with a GP
IF OBJECT_ID('tempdb..#PatientsWithGP') IS NOT NULL DROP TABLE #PatientsWithGP;
SELECT DISTINCT FK_Patient_Link_ID INTO #PatientsWithGP FROM [RLS].vw_Patient
where FK_Reference_Tenancy_ID = 2;

-- Make cohort from patients alive at start date and registered with a GP
IF OBJECT_ID('tempdb..#Patients') IS NOT NULL DROP TABLE #Patients;
SELECT pp.* INTO #Patients FROM #PossiblePatients pp
INNER JOIN #PatientsWithGP gp on gp.FK_Patient_Link_ID = pp.FK_Patient_Link_ID;

------------------------------------------

-- OUTPUT: #Patients

-- LOAD CODESETS NEEDED FOR DEFINING COHORT

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
VALUES ('chronic-kidney-disease',1,'1Z1f.',NULL,'CKD G5A3 - chronic kidney disease with glomerular filtration rate category G5 and albuminuria category A3'),('chronic-kidney-disease',1,'1Z1f.00',NULL,'CKD G5A3 - chronic kidney disease with glomerular filtration rate category G5 and albuminuria category A3'),('chronic-kidney-disease',1,'1Z1e.',NULL,'CKD G5A2 - chronic kidney disease with glomerular filtration rate category G5 and albuminuria category A2'),('chronic-kidney-disease',1,'1Z1e.00',NULL,'CKD G5A2 - chronic kidney disease with glomerular filtration rate category G5 and albuminuria category A2'),('chronic-kidney-disease',1,'1Z1d.',NULL,'CKD G5A1 - chronic kidney disease with glomerular filtration rate category G5 and albuminuria category A1'),('chronic-kidney-disease',1,'1Z1d.00',NULL,'CKD G5A1 - chronic kidney disease with glomerular filtration rate category G5 and albuminuria category A1'),('chronic-kidney-disease',1,'1Z1c.',NULL,'CKD G4A3 - chronic kidney disease with glomerular filtration rate category G4 and albuminuria category A3'),('chronic-kidney-disease',1,'1Z1c.00',NULL,'CKD G4A3 - chronic kidney disease with glomerular filtration rate category G4 and albuminuria category A3'),('chronic-kidney-disease',1,'1Z1b.',NULL,'CKD G4A2 - chronic kidney disease with glomerular filtration rate category G4 and albuminuria category A2'),('chronic-kidney-disease',1,'1Z1b.00',NULL,'CKD G4A2 - chronic kidney disease with glomerular filtration rate category G4 and albuminuria category A2'),('chronic-kidney-disease',1,'1Z1a.',NULL,'CKD G4A1 - chronic kidney disease with glomerular filtration rate category G4 and albuminuria category A1'),('chronic-kidney-disease',1,'1Z1a.00',NULL,'CKD G4A1 - chronic kidney disease with glomerular filtration rate category G4 and albuminuria category A1'),('chronic-kidney-disease',1,'1Z1Z.',NULL,'CKD G3bA3 - chronic kidney disease with glomerular filtration rate category G3b and albuminuria category A3'),('chronic-kidney-disease',1,'1Z1Z.00',NULL,'CKD G3bA3 - chronic kidney disease with glomerular filtration rate category G3b and albuminuria category A3'),('chronic-kidney-disease',1,'1Z1Y.',NULL,'CKD G3bA2 - chronic kidney disease with glomerular filtration rate category G3b and albuminuria category A2'),('chronic-kidney-disease',1,'1Z1Y.00',NULL,'CKD G3bA2 - chronic kidney disease with glomerular filtration rate category G3b and albuminuria category A2'),('chronic-kidney-disease',1,'1Z1X.',NULL,'CKD G3bA1 - chronic kidney disease with glomerular filtration rate category G3b and albuminuria category A1'),('chronic-kidney-disease',1,'1Z1X.00',NULL,'CKD G3bA1 - chronic kidney disease with glomerular filtration rate category G3b and albuminuria category A1'),('chronic-kidney-disease',1,'1Z1W.',NULL,'CKD G3aA3 - chronic kidney disease with glomerular filtration rate category G3a and albuminuria category A3'),('chronic-kidney-disease',1,'1Z1W.00',NULL,'CKD G3aA3 - chronic kidney disease with glomerular filtration rate category G3a and albuminuria category A3'),('chronic-kidney-disease',1,'1Z1V.',NULL,'CKD G3aA2 - chronic kidney disease with glomerular filtration rate category G3a and albuminuria category A2'),('chronic-kidney-disease',1,'1Z1V.00',NULL,'CKD G3aA2 - chronic kidney disease with glomerular filtration rate category G3a and albuminuria category A2'),('chronic-kidney-disease',1,'1Z1T.',NULL,'CKD G3aA1 - chronic kidney disease with glomerular filtration rate category G3a and albuminuria category A1'),('chronic-kidney-disease',1,'1Z1T.00',NULL,'CKD G3aA1 - chronic kidney disease with glomerular filtration rate category G3a and albuminuria category A1'),('chronic-kidney-disease',1,'1Z1S.',NULL,'CKD G2A3 - chronic kidney disease with glomerular filtration rate category G2 and albuminuria category A3'),('chronic-kidney-disease',1,'1Z1S.00',NULL,'CKD G2A3 - chronic kidney disease with glomerular filtration rate category G2 and albuminuria category A3'),('chronic-kidney-disease',1,'1Z1R.',NULL,'CKD G2A2 - chronic kidney disease with glomerular filtration rate category G2 and albuminuria category A2'),('chronic-kidney-disease',1,'1Z1R.00',NULL,'CKD G2A2 - chronic kidney disease with glomerular filtration rate category G2 and albuminuria category A2'),('chronic-kidney-disease',1,'1Z1Q.',NULL,'CKD G2A1 - chronic kidney disease with glomerular filtration rate category G2 and albuminuria category A1'),('chronic-kidney-disease',1,'1Z1Q.00',NULL,'CKD G2A1 - chronic kidney disease with glomerular filtration rate category G2 and albuminuria category A1'),('chronic-kidney-disease',1,'1Z1P.',NULL,'CKD G1A3 - chronic kidney disease with glomerular filtration rate category G1 and albuminuria category A3'),('chronic-kidney-disease',1,'1Z1P.00',NULL,'CKD G1A3 - chronic kidney disease with glomerular filtration rate category G1 and albuminuria category A3'),('chronic-kidney-disease',1,'1Z1N.',NULL,'CKD G1A2 - chronic kidney disease with glomerular filtration rate category G1 and albuminuria category A2'),('chronic-kidney-disease',1,'1Z1N.00',NULL,'CKD G1A2 - chronic kidney disease with glomerular filtration rate category G1 and albuminuria category A2'),('chronic-kidney-disease',1,'1Z1M.',NULL,'CKD G1A1 - chronic kidney disease with glomerular filtration rate category G1 and albuminuria category A1'),('chronic-kidney-disease',1,'1Z1M.00',NULL,'CKD G1A1 - chronic kidney disease with glomerular filtration rate category G1 and albuminuria category A1'),('chronic-kidney-disease',1,'1Z16.',NULL,'Chronic kidney disease stage 3B'),('chronic-kidney-disease',1,'1Z16.00',NULL,'Chronic kidney disease stage 3B'),('chronic-kidney-disease',1,'1Z15.',NULL,'Chronic kidney disease stage 3A'),('chronic-kidney-disease',1,'1Z15.00',NULL,'Chronic kidney disease stage 3A'),('chronic-kidney-disease',1,'1Z14.',NULL,'Chronic kidney disease stage 5'),('chronic-kidney-disease',1,'1Z14.00',NULL,'Chronic kidney disease stage 5'),('chronic-kidney-disease',1,'1Z13.',NULL,'Chronic kidney disease stage 4'),('chronic-kidney-disease',1,'1Z13.00',NULL,'Chronic kidney disease stage 4'),('chronic-kidney-disease',1,'1Z12.',NULL,'Chronic kidney disease stage 3'),('chronic-kidney-disease',1,'1Z12.00',NULL,'Chronic kidney disease stage 3'),('chronic-kidney-disease',1,'1Z11.',NULL,'Chronic kidney disease stage 2'),('chronic-kidney-disease',1,'1Z11.00',NULL,'Chronic kidney disease stage 2'),('chronic-kidney-disease',1,'1Z10.',NULL,'Chronic kidney disease stage 1'),('chronic-kidney-disease',1,'1Z10.00',NULL,'Chronic kidney disease stage 1'),('chronic-kidney-disease',1,'1Z1L.',NULL,'Chronic kidney disease stage 5 without proteinuria'),('chronic-kidney-disease',1,'1Z1L.00',NULL,'Chronic kidney disease stage 5 without proteinuria'),('chronic-kidney-disease',1,'1Z1K.',NULL,'Chronic kidney disease stage 5 with proteinuria'),('chronic-kidney-disease',1,'1Z1K.00',NULL,'Chronic kidney disease stage 5 with proteinuria'),('chronic-kidney-disease',1,'1Z1J.',NULL,'Chronic kidney disease stage 4 without proteinuria'),('chronic-kidney-disease',1,'1Z1J.00',NULL,'Chronic kidney disease stage 4 without proteinuria'),('chronic-kidney-disease',1,'1Z1H.',NULL,'Chronic kidney disease stage 4 with proteinuria'),('chronic-kidney-disease',1,'1Z1H.00',NULL,'Chronic kidney disease stage 4 with proteinuria'),('chronic-kidney-disease',1,'1Z1G.',NULL,'Chronic kidney disease stage 3B without proteinuria'),('chronic-kidney-disease',1,'1Z1G.00',NULL,'Chronic kidney disease stage 3B without proteinuria'),('chronic-kidney-disease',1,'1Z1F.',NULL,'Chronic kidney disease stage 3B with proteinuria'),('chronic-kidney-disease',1,'1Z1F.00',NULL,'Chronic kidney disease stage 3B with proteinuria'),('chronic-kidney-disease',1,'1Z1E.',NULL,'Chronic kidney disease stage 3A without proteinuria'),('chronic-kidney-disease',1,'1Z1E.00',NULL,'Chronic kidney disease stage 3A without proteinuria'),('chronic-kidney-disease',1,'1Z1D.',NULL,'Chronic kidney disease stage 3A with proteinuria'),('chronic-kidney-disease',1,'1Z1D.00',NULL,'Chronic kidney disease stage 3A with proteinuria'),('chronic-kidney-disease',1,'1Z1C.',NULL,'Chronic kidney disease stage 3 without proteinuria'),('chronic-kidney-disease',1,'1Z1C.00',NULL,'Chronic kidney disease stage 3 without proteinuria'),('chronic-kidney-disease',1,'1Z1B.',NULL,'Chronic kidney disease stage 3 with proteinuria'),('chronic-kidney-disease',1,'1Z1B.00',NULL,'Chronic kidney disease stage 3 with proteinuria'),('chronic-kidney-disease',1,'1Z1A.',NULL,'Chronic kidney disease stage 2 without proteinuria'),('chronic-kidney-disease',1,'1Z1A.00',NULL,'Chronic kidney disease stage 2 without proteinuria'),('chronic-kidney-disease',1,'1Z19.',NULL,'Chronic kidney disease stage 2 with proteinuria'),('chronic-kidney-disease',1,'1Z19.00',NULL,'Chronic kidney disease stage 2 with proteinuria'),('chronic-kidney-disease',1,'1Z18.',NULL,'Chronic kidney disease stage 1 without proteinuria'),('chronic-kidney-disease',1,'1Z18.00',NULL,'Chronic kidney disease stage 1 without proteinuria'),('chronic-kidney-disease',1,'1Z17.',NULL,'Chronic kidney disease stage 1 with proteinuria'),('chronic-kidney-disease',1,'1Z17.00',NULL,'Chronic kidney disease stage 1 with proteinuria'),('chronic-kidney-disease',1,'K05..',NULL,'Chronic renal failure'),('chronic-kidney-disease',1,'K05..00',NULL,'Chronic renal failure'),('chronic-kidney-disease',1,'K055.',NULL,'Chronic kidney disease stage 5'),('chronic-kidney-disease',1,'K055.00',NULL,'Chronic kidney disease stage 5'),('chronic-kidney-disease',1,'K054.',NULL,'Chronic kidney disease stage 4'),('chronic-kidney-disease',1,'K054.00',NULL,'Chronic kidney disease stage 4'),('chronic-kidney-disease',1,'K053.',NULL,'Chronic kidney disease stage 3'),('chronic-kidney-disease',1,'K053.00',NULL,'Chronic kidney disease stage 3'),('chronic-kidney-disease',1,'K052.',NULL,'Chronic kidney disease stage 2'),('chronic-kidney-disease',1,'K052.00',NULL,'Chronic kidney disease stage 2'),
('chronic-kidney-disease',1,'K051.',NULL,'Chronic kidney disease stage 1'),('chronic-kidney-disease',1,'K051.00',NULL,'Chronic kidney disease stage 1'),('chronic-kidney-disease',1,'1Z1..',NULL,'Chronic renal impairment'),('chronic-kidney-disease',1,'1Z1..00',NULL,'Chronic renal impairment'),('chronic-kidney-disease',1,'K050.',NULL,'End stage renal failure'),('chronic-kidney-disease',1,'K050.00',NULL,'End stage renal failure'),('chronic-kidney-disease',1,'K0D..',NULL,'End-stage renal disease'),('chronic-kidney-disease',1,'K0D..00',NULL,'End-stage renal disease');
INSERT INTO #codesreadv2
VALUES ('diabetes',1,'C10..',NULL,'Diabetes mellitus'),('diabetes',1,'C10..00',NULL,'Diabetes mellitus'),('diabetes',1,'C100.',NULL,'Diabetes mellitus with no mention of complication'),('diabetes',1,'C100.00',NULL,'Diabetes mellitus with no mention of complication'),('diabetes',1,'C1000',NULL,'Diabetes mellitus, juvenile type, with no mention of complication'),('diabetes',1,'C100000',NULL,'Diabetes mellitus, juvenile type, with no mention of complication'),('diabetes',1,'C1001',NULL,'Diabetes mellitus, adult onset, with no mention of complication'),('diabetes',1,'C100100',NULL,'Diabetes mellitus, adult onset, with no mention of complication'),('diabetes',1,'C100z',NULL,'Diabetes mellitus NOS with no mention of complication'),('diabetes',1,'C100z00',NULL,'Diabetes mellitus NOS with no mention of complication'),('diabetes',1,'C101.',NULL,'Diabetes mellitus with ketoacidosis'),('diabetes',1,'C101.00',NULL,'Diabetes mellitus with ketoacidosis'),('diabetes',1,'C1010',NULL,'Diabetes mellitus, juvenile type, with ketoacidosis'),('diabetes',1,'C101000',NULL,'Diabetes mellitus, juvenile type, with ketoacidosis'),('diabetes',1,'C1011',NULL,'Diabetes mellitus, adult onset, with ketoacidosis'),('diabetes',1,'C101100',NULL,'Diabetes mellitus, adult onset, with ketoacidosis'),('diabetes',1,'C101y',NULL,'Other specified diabetes mellitus with ketoacidosis'),('diabetes',1,'C101y00',NULL,'Other specified diabetes mellitus with ketoacidosis'),('diabetes',1,'C101z',NULL,'Diabetes mellitus NOS with ketoacidosis'),('diabetes',1,'C101z00',NULL,'Diabetes mellitus NOS with ketoacidosis'),('diabetes',1,'C102.',NULL,'Diabetes mellitus with hyperosmolar coma'),('diabetes',1,'C102.00',NULL,'Diabetes mellitus with hyperosmolar coma'),('diabetes',1,'C1020',NULL,'Diabetes mellitus, juvenile type, with hyperosmolar coma'),('diabetes',1,'C102000',NULL,'Diabetes mellitus, juvenile type, with hyperosmolar coma'),('diabetes',1,'C1021',NULL,'Diabetes mellitus, adult onset, with hyperosmolar coma'),('diabetes',1,'C102100',NULL,'Diabetes mellitus, adult onset, with hyperosmolar coma'),('diabetes',1,'C102z',NULL,'Diabetes mellitus NOS with hyperosmolar coma'),('diabetes',1,'C102z00',NULL,'Diabetes mellitus NOS with hyperosmolar coma'),('diabetes',1,'C103.',NULL,'Diabetes mellitus with ketoacidotic coma'),('diabetes',1,'C103.00',NULL,'Diabetes mellitus with ketoacidotic coma'),('diabetes',1,'C1030',NULL,'Diabetes mellitus, juvenile type, with ketoacidotic coma'),('diabetes',1,'C103000',NULL,'Diabetes mellitus, juvenile type, with ketoacidotic coma'),('diabetes',1,'C1031',NULL,'Diabetes mellitus, adult onset, with ketoacidotic coma'),('diabetes',1,'C103100',NULL,'Diabetes mellitus, adult onset, with ketoacidotic coma'),('diabetes',1,'C103y',NULL,'Other specified diabetes mellitus with coma'),('diabetes',1,'C103y00',NULL,'Other specified diabetes mellitus with coma'),('diabetes',1,'C103z',NULL,'Diabetes mellitus NOS with ketoacidotic coma'),('diabetes',1,'C103z00',NULL,'Diabetes mellitus NOS with ketoacidotic coma'),('diabetes',1,'C104.',NULL,'Diabetes mellitus with renal manifestation'),('diabetes',1,'C104.00',NULL,'Diabetes mellitus with renal manifestation'),('diabetes',1,'C1040',NULL,'Diabetes mellitus, juvenile type, with renal manifestation'),('diabetes',1,'C104000',NULL,'Diabetes mellitus, juvenile type, with renal manifestation'),('diabetes',1,'C1041',NULL,'Diabetes mellitus, adult onset, with renal manifestation'),('diabetes',1,'C104100',NULL,'Diabetes mellitus, adult onset, with renal manifestation'),('diabetes',1,'C104y',NULL,'Other specified diabetes mellitus with renal complications'),('diabetes',1,'C104y00',NULL,'Other specified diabetes mellitus with renal complications'),('diabetes',1,'C104z',NULL,'Diabetes mellitus with nephropathy NOS'),('diabetes',1,'C104z00',NULL,'Diabetes mellitus with nephropathy NOS'),('diabetes',1,'C105.',NULL,'Diabetes mellitus with ophthalmic manifestation'),('diabetes',1,'C105.00',NULL,'Diabetes mellitus with ophthalmic manifestation'),('diabetes',1,'C1050',NULL,'Diabetes mellitus, juvenile type, with ophthalmic manifestation'),('diabetes',1,'C105000',NULL,'Diabetes mellitus, juvenile type, with ophthalmic manifestation'),('diabetes',1,'C1051',NULL,'Diabetes mellitus, adult onset, with ophthalmic manifestation'),('diabetes',1,'C105100',NULL,'Diabetes mellitus, adult onset, with ophthalmic manifestation'),('diabetes',1,'C105y',NULL,'Other specified diabetes mellitus with ophthalmic complications'),('diabetes',1,'C105y00',NULL,'Other specified diabetes mellitus with ophthalmic complications'),('diabetes',1,'C105z',NULL,'Diabetes mellitus NOS with ophthalmic manifestation'),('diabetes',1,'C105z00',NULL,'Diabetes mellitus NOS with ophthalmic manifestation'),('diabetes',1,'C106.',NULL,'Diabetes mellitus with neurological manifestation'),('diabetes',1,'C106.00',NULL,'Diabetes mellitus with neurological manifestation'),('diabetes',1,'C1060',NULL,'Diabetes mellitus, juvenile type, with neurological manifestation'),('diabetes',1,'C106000',NULL,'Diabetes mellitus, juvenile type, with neurological manifestation'),('diabetes',1,'C1061',NULL,'Diabetes mellitus, adult onset, with neurological manifestation'),('diabetes',1,'C106100',NULL,'Diabetes mellitus, adult onset, with neurological manifestation'),('diabetes',1,'C106y',NULL,'Other specified diabetes mellitus with neurological complications'),('diabetes',1,'C106y00',NULL,'Other specified diabetes mellitus with neurological complications'),('diabetes',1,'C106z',NULL,'Diabetes mellitus NOS with neurological manifestation'),('diabetes',1,'C106z00',NULL,'Diabetes mellitus NOS with neurological manifestation'),('diabetes',1,'C107.',NULL,'Diabetes mellitus with peripheral circulatory disorder'),('diabetes',1,'C107.00',NULL,'Diabetes mellitus with peripheral circulatory disorder'),('diabetes',1,'C1070',NULL,'Diabetes mellitus, juvenile type, with peripheral circulatory disorder'),('diabetes',1,'C107000',NULL,'Diabetes mellitus, juvenile type, with peripheral circulatory disorder'),('diabetes',1,'C1071',NULL,'Diabetes mellitus, adult onset, with peripheral circulatory disorder'),('diabetes',1,'C107100',NULL,'Diabetes mellitus, adult onset, with peripheral circulatory disorder'),('diabetes',1,'C1072',NULL,'Diabetes mellitus, adult with gangrene'),('diabetes',1,'C107200',NULL,'Diabetes mellitus, adult with gangrene'),('diabetes',1,'C107y',NULL,'Other specified diabetes mellitus with peripheral circulatory complications'),('diabetes',1,'C107y00',NULL,'Other specified diabetes mellitus with peripheral circulatory complications'),('diabetes',1,'C107z',NULL,'Diabetes mellitus NOS with peripheral circulatory disorder'),('diabetes',1,'C107z00',NULL,'Diabetes mellitus NOS with peripheral circulatory disorder'),('diabetes',1,'C108.',NULL,'Insulin dependent diabetes mellitus'),('diabetes',1,'C108.00',NULL,'Insulin dependent diabetes mellitus'),('diabetes',1,'C1080',NULL,'Insulin-dependent diabetes mellitus with renal complications'),('diabetes',1,'C108000',NULL,'Insulin-dependent diabetes mellitus with renal complications'),('diabetes',1,'C1081',NULL,'Insulin-dependent diabetes mellitus with ophthalmic complications'),('diabetes',1,'C108100',NULL,'Insulin-dependent diabetes mellitus with ophthalmic complications'),('diabetes',1,'C1082',NULL,'Insulin-dependent diabetes mellitus with neurological complications'),('diabetes',1,'C108200',NULL,'Insulin-dependent diabetes mellitus with neurological complications'),('diabetes',1,'C1083',NULL,'Insulin dependent diabetes mellitus with multiple complications'),('diabetes',1,'C108300',NULL,'Insulin dependent diabetes mellitus with multiple complications'),('diabetes',1,'C1084',NULL,'Unstable insulin dependent diabetes mellitus'),('diabetes',1,'C108400',NULL,'Unstable insulin dependent diabetes mellitus'),('diabetes',1,'C1085',NULL,'Insulin dependent diabetes mellitus with ulcer'),('diabetes',1,'C108500',NULL,'Insulin dependent diabetes mellitus with ulcer'),('diabetes',1,'C1086',NULL,'Insulin dependent diabetes mellitus with gangrene'),('diabetes',1,'C108600',NULL,'Insulin dependent diabetes mellitus with gangrene'),('diabetes',1,'C1087',NULL,'Insulin dependent diabetes mellitus with retinopathy'),('diabetes',1,'C108700',NULL,'Insulin dependent diabetes mellitus with retinopathy'),('diabetes',1,'C1088',NULL,'Insulin dependent diabetes mellitus - poor control'),('diabetes',1,'C108800',NULL,'Insulin dependent diabetes mellitus - poor control'),('diabetes',1,'C1089',NULL,'Insulin dependent diabetes maturity onset'),('diabetes',1,'C108900',NULL,'Insulin dependent diabetes maturity onset'),('diabetes',1,'C108A',NULL,'Insulin-dependent diabetes without complication'),('diabetes',1,'C108A00',NULL,'Insulin-dependent diabetes without complication'),('diabetes',1,'C108B',NULL,'Insulin dependent diabetes mellitus with mononeuropathy'),('diabetes',1,'C108B00',NULL,'Insulin dependent diabetes mellitus with mononeuropathy'),('diabetes',1,'C108C',NULL,'Insulin dependent diabetes mellitus with polyneuropathy'),('diabetes',1,'C108C00',NULL,'Insulin dependent diabetes mellitus with polyneuropathy'),('diabetes',1,'C108D',NULL,'Insulin dependent diabetes mellitus with nephropathy'),('diabetes',1,'C108D00',NULL,'Insulin dependent diabetes mellitus with nephropathy'),('diabetes',1,'C108E',NULL,'Insulin dependent diabetes mellitus with hypoglycaemic coma'),('diabetes',1,'C108E00',NULL,'Insulin dependent diabetes mellitus with hypoglycaemic coma'),('diabetes',1,'C108F',NULL,'Insulin dependent diabetes mellitus with diabetic cataract'),('diabetes',1,'C108F00',NULL,'Insulin dependent diabetes mellitus with diabetic cataract'),('diabetes',1,'C108G',NULL,'Insulin dependent diabetes mellitus with peripheral angiopathy'),('diabetes',1,'C108G00',NULL,'Insulin dependent diabetes mellitus with peripheral angiopathy'),('diabetes',1,'C108H',NULL,'Insulin dependent diabetes mellitus with arthropathy'),
('diabetes',1,'C108H00',NULL,'Insulin dependent diabetes mellitus with arthropathy'),('diabetes',1,'C108J',NULL,'Insulin dependent diabetes mellitus with neuropathic arthropathy'),('diabetes',1,'C108J00',NULL,'Insulin dependent diabetes mellitus with neuropathic arthropathy'),('diabetes',1,'C108y',NULL,'Other specified diabetes mellitus with multiple complications'),('diabetes',1,'C108y00',NULL,'Other specified diabetes mellitus with multiple complications'),('diabetes',1,'C108z',NULL,'Unspecified diabetes mellitus with multiple complications'),('diabetes',1,'C108z00',NULL,'Unspecified diabetes mellitus with multiple complications'),('diabetes',1,'C109.',NULL,'Non-insulin dependent diabetes mellitus'),('diabetes',1,'C109.00',NULL,'Non-insulin dependent diabetes mellitus'),('diabetes',1,'C1090',NULL,'Non-insulin-dependent diabetes mellitus with renal complications'),('diabetes',1,'C109000',NULL,'Non-insulin-dependent diabetes mellitus with renal complications'),('diabetes',1,'C1091',NULL,'Non-insulin-dependent diabetes mellitus with ophthalmic complications'),('diabetes',1,'C109100',NULL,'Non-insulin-dependent diabetes mellitus with ophthalmic complications'),('diabetes',1,'C1092',NULL,'Non-insulin-dependent diabetes mellitus with neurological complications'),('diabetes',1,'C109200',NULL,'Non-insulin-dependent diabetes mellitus with neurological complications'),('diabetes',1,'C1093',NULL,'Non-insulin-dependent diabetes mellitus with multiple complications'),('diabetes',1,'C109300',NULL,'Non-insulin-dependent diabetes mellitus with multiple complications'),('diabetes',1,'C1094',NULL,'Non-insulin dependent diabetes mellitus with ulcer'),('diabetes',1,'C109400',NULL,'Non-insulin dependent diabetes mellitus with ulcer'),('diabetes',1,'C1095',NULL,'Non-insulin dependent diabetes mellitus with gangrene'),('diabetes',1,'C109500',NULL,'Non-insulin dependent diabetes mellitus with gangrene'),('diabetes',1,'C1096',NULL,'Non-insulin-dependent diabetes mellitus with retinopathy'),('diabetes',1,'C109600',NULL,'Non-insulin-dependent diabetes mellitus with retinopathy'),('diabetes',1,'C1097',NULL,'Non-insulin dependent diabetes mellitus - poor control'),('diabetes',1,'C109700',NULL,'Non-insulin dependent diabetes mellitus - poor control'),('diabetes',1,'C1098',NULL,'Reavens syndrome'),('diabetes',1,'C109800',NULL,'Reavens syndrome'),('diabetes',1,'C1099',NULL,'Non-insulin-dependent diabetes mellitus without complication'),('diabetes',1,'C109900',NULL,'Non-insulin-dependent diabetes mellitus without complication'),('diabetes',1,'C109A',NULL,'Non-insulin dependent diabetes mellitus with mononeuropathy'),('diabetes',1,'C109A00',NULL,'Non-insulin dependent diabetes mellitus with mononeuropathy'),('diabetes',1,'C109B',NULL,'Non-insulin dependent diabetes mellitus with polyneuropathy'),('diabetes',1,'C109B00',NULL,'Non-insulin dependent diabetes mellitus with polyneuropathy'),('diabetes',1,'C109C',NULL,'Non-insulin dependent diabetes mellitus with nephropathy'),('diabetes',1,'C109C00',NULL,'Non-insulin dependent diabetes mellitus with nephropathy'),('diabetes',1,'C109D',NULL,'Non-insulin dependent diabetes mellitus with hypoglycaemic coma'),('diabetes',1,'C109D00',NULL,'Non-insulin dependent diabetes mellitus with hypoglycaemic coma'),('diabetes',1,'C109E',NULL,'Non-insulin dependent diabetes mellitus with diabetic cataract'),('diabetes',1,'C109E00',NULL,'Non-insulin dependent diabetes mellitus with diabetic cataract'),('diabetes',1,'C109F',NULL,'Non-insulin-dependent diabetes mellitus with peripheral angiopathy'),('diabetes',1,'C109F00',NULL,'Non-insulin-dependent diabetes mellitus with peripheral angiopathy'),('diabetes',1,'C109G',NULL,'Non-insulin dependent diabetes mellitus with arthropathy'),('diabetes',1,'C109G00',NULL,'Non-insulin dependent diabetes mellitus with arthropathy'),('diabetes',1,'C109H',NULL,'Non-insulin dependent diabetes mellitus with neuropathic arthropathy'),('diabetes',1,'C109H00',NULL,'Non-insulin dependent diabetes mellitus with neuropathic arthropathy'),('diabetes',1,'C109J',NULL,'Insulin treated Type 2 diabetes mellitus'),('diabetes',1,'C109J00',NULL,'Insulin treated Type 2 diabetes mellitus'),('diabetes',1,'C109K',NULL,'Hyperosmolar non-ketotic state in type 2 diabetes mellitus'),('diabetes',1,'C109K00',NULL,'Hyperosmolar non-ketotic state in type 2 diabetes mellitus'),('diabetes',1,'C10A.',NULL,'Malnutrition-related diabetes mellitus'),('diabetes',1,'C10A.00',NULL,'Malnutrition-related diabetes mellitus'),('diabetes',1,'C10A0',NULL,'Malnutrition-related diabetes mellitus with coma'),('diabetes',1,'C10A000',NULL,'Malnutrition-related diabetes mellitus with coma'),('diabetes',1,'C10A1',NULL,'Malnutrition-related diabetes mellitus with ketoacidosis'),('diabetes',1,'C10A100',NULL,'Malnutrition-related diabetes mellitus with ketoacidosis'),('diabetes',1,'C10A2',NULL,'Malnutrition-related diabetes mellitus with renal complications'),('diabetes',1,'C10A200',NULL,'Malnutrition-related diabetes mellitus with renal complications'),('diabetes',1,'C10A3',NULL,'Malnutrition-related diabetes mellitus with ophthalmic complications'),('diabetes',1,'C10A300',NULL,'Malnutrition-related diabetes mellitus with ophthalmic complications'),('diabetes',1,'C10A4',NULL,'Malnutrition-related diabetes mellitus with neurological complications'),('diabetes',1,'C10A400',NULL,'Malnutrition-related diabetes mellitus with neurological complications'),('diabetes',1,'C10A5',NULL,'Malnutrition-related diabetes mellitus with peripheral circulatory complications'),('diabetes',1,'C10A500',NULL,'Malnutrition-related diabetes mellitus with peripheral circulatory complications'),('diabetes',1,'C10A6',NULL,'Malnutrition-related diabetes mellitus with multiple complications'),('diabetes',1,'C10A600',NULL,'Malnutrition-related diabetes mellitus with multiple complications'),('diabetes',1,'C10A7',NULL,'Malnutrition-related diabetes mellitus without complications'),('diabetes',1,'C10A700',NULL,'Malnutrition-related diabetes mellitus without complications'),('diabetes',1,'C10AW',NULL,'Malnutrition-related diabetes mellitus with unspecified complications'),('diabetes',1,'C10AW00',NULL,'Malnutrition-related diabetes mellitus with unspecified complications'),('diabetes',1,'C10AX',NULL,'Malnutrition-related diabetes mellitus with other specified complications'),('diabetes',1,'C10AX00',NULL,'Malnutrition-related diabetes mellitus with other specified complications'),('diabetes',1,'C10B.',NULL,'Diabetes mellitus induced by steroids'),('diabetes',1,'C10B.00',NULL,'Diabetes mellitus induced by steroids'),('diabetes',1,'C10B0',NULL,'Steroid induced diabetes mellitus without complication'),('diabetes',1,'C10B000',NULL,'Steroid induced diabetes mellitus without complication'),('diabetes',1,'C10C.',NULL,'Diabetes mellitus autosomal dominant'),('diabetes',1,'C10C.00',NULL,'Diabetes mellitus autosomal dominant'),('diabetes',1,'C10D.',NULL,'Diabetes mellitus autosomal dominant type 2'),('diabetes',1,'C10D.00',NULL,'Diabetes mellitus autosomal dominant type 2'),('diabetes',1,'C10E.',NULL,'Type 1 diabetes mellitus'),('diabetes',1,'C10E.00',NULL,'Type 1 diabetes mellitus'),('diabetes',1,'C10E0',NULL,'Type 1 diabetes mellitus with renal complications'),('diabetes',1,'C10E000',NULL,'Type 1 diabetes mellitus with renal complications'),('diabetes',1,'C10E1',NULL,'Type 1 diabetes mellitus with ophthalmic complications'),('diabetes',1,'C10E100',NULL,'Type 1 diabetes mellitus with ophthalmic complications'),('diabetes',1,'C10E2',NULL,'Type 1 diabetes mellitus with neurological complications'),('diabetes',1,'C10E200',NULL,'Type 1 diabetes mellitus with neurological complications'),('diabetes',1,'C10E3',NULL,'Type 1 diabetes mellitus with multiple complications'),('diabetes',1,'C10E300',NULL,'Type 1 diabetes mellitus with multiple complications'),('diabetes',1,'C10E4',NULL,'Unstable type 1 diabetes mellitus'),('diabetes',1,'C10E400',NULL,'Unstable type 1 diabetes mellitus'),('diabetes',1,'C10E5',NULL,'Type 1 diabetes mellitus with ulcer'),('diabetes',1,'C10E500',NULL,'Type 1 diabetes mellitus with ulcer'),('diabetes',1,'C10E6',NULL,'Type 1 diabetes mellitus with gangrene'),('diabetes',1,'C10E600',NULL,'Type 1 diabetes mellitus with gangrene'),('diabetes',1,'C10E7',NULL,'Type 1 diabetes mellitus with retinopathy'),('diabetes',1,'C10E700',NULL,'Type 1 diabetes mellitus with retinopathy'),('diabetes',1,'C10E8',NULL,'Type 1 diabetes mellitus - poor control'),('diabetes',1,'C10E800',NULL,'Type 1 diabetes mellitus - poor control'),('diabetes',1,'C10E9',NULL,'Type 1 diabetes mellitus maturity onset'),('diabetes',1,'C10E900',NULL,'Type 1 diabetes mellitus maturity onset'),('diabetes',1,'C10EA',NULL,'Type 1 diabetes mellitus without complication'),('diabetes',1,'C10EA00',NULL,'Type 1 diabetes mellitus without complication'),('diabetes',1,'C10EB',NULL,'Type 1 diabetes mellitus with mononeuropathy'),('diabetes',1,'C10EB00',NULL,'Type 1 diabetes mellitus with mononeuropathy'),('diabetes',1,'C10EC',NULL,'Type 1 diabetes mellitus with polyneuropathy'),('diabetes',1,'C10EC00',NULL,'Type 1 diabetes mellitus with polyneuropathy'),('diabetes',1,'C10ED',NULL,'Type 1 diabetes mellitus with nephropathy'),('diabetes',1,'C10ED00',NULL,'Type 1 diabetes mellitus with nephropathy'),('diabetes',1,'C10EE',NULL,'Type 1 diabetes mellitus with hypoglycaemic coma'),('diabetes',1,'C10EE00',NULL,'Type 1 diabetes mellitus with hypoglycaemic coma'),('diabetes',1,'C10EF',NULL,'Type 1 diabetes mellitus with diabetic cataract'),('diabetes',1,'C10EF00',NULL,'Type 1 diabetes mellitus with diabetic cataract'),('diabetes',1,'C10EG',NULL,'Type 1 diabetes mellitus with peripheral angiopathy'),('diabetes',1,'C10EG00',NULL,'Type 1 diabetes mellitus with peripheral angiopathy'),('diabetes',1,'C10EH',NULL,'Type 1 diabetes mellitus with arthropathy'),('diabetes',1,'C10EH00',NULL,'Type 1 diabetes mellitus with arthropathy'),('diabetes',1,'C10EJ',NULL,'Type 1 diabetes mellitus with neuropathic arthropathy'),
('diabetes',1,'C10EJ00',NULL,'Type 1 diabetes mellitus with neuropathic arthropathy'),('diabetes',1,'C10EK',NULL,'Type 1 diabetes mellitus with persistent proteinuria'),('diabetes',1,'C10EK00',NULL,'Type 1 diabetes mellitus with persistent proteinuria'),('diabetes',1,'C10EL',NULL,'Type 1 diabetes mellitus with persistent microalbuminuria'),('diabetes',1,'C10EL00',NULL,'Type 1 diabetes mellitus with persistent microalbuminuria'),('diabetes',1,'C10EM',NULL,'Type 1 diabetes mellitus with ketoacidosis'),('diabetes',1,'C10EM00',NULL,'Type 1 diabetes mellitus with ketoacidosis'),('diabetes',1,'C10EN',NULL,'Type 1 diabetes mellitus with ketoacidotic coma'),('diabetes',1,'C10EN00',NULL,'Type 1 diabetes mellitus with ketoacidotic coma'),('diabetes',1,'C10EP',NULL,'Type 1 diabetes mellitus with exudative maculopathy'),('diabetes',1,'C10EP00',NULL,'Type 1 diabetes mellitus with exudative maculopathy'),('diabetes',1,'C10EQ',NULL,'Type 1 diabetes mellitus with gastroparesis'),('diabetes',1,'C10EQ00',NULL,'Type 1 diabetes mellitus with gastroparesis'),('diabetes',1,'C10ER',NULL,'Latent autoimmune diabetes mellitus in adult'),('diabetes',1,'C10ER00',NULL,'Latent autoimmune diabetes mellitus in adult'),('diabetes',1,'C10F.',NULL,'Type 2 diabetes mellitus'),('diabetes',1,'C10F.00',NULL,'Type 2 diabetes mellitus'),('diabetes',1,'C10F0',NULL,'Type 2 diabetes mellitus with renal complications'),('diabetes',1,'C10F000',NULL,'Type 2 diabetes mellitus with renal complications'),('diabetes',1,'C10F1',NULL,'Type 2 diabetes mellitus with ophthalmic complications'),('diabetes',1,'C10F100',NULL,'Type 2 diabetes mellitus with ophthalmic complications'),('diabetes',1,'C10F2',NULL,'Type 2 diabetes mellitus with neurological complications'),('diabetes',1,'C10F200',NULL,'Type 2 diabetes mellitus with neurological complications'),('diabetes',1,'C10F3',NULL,'Type 2 diabetes mellitus with multiple complications'),('diabetes',1,'C10F300',NULL,'Type 2 diabetes mellitus with multiple complications'),('diabetes',1,'C10F4',NULL,'Type 2 diabetes mellitus with ulcer'),('diabetes',1,'C10F400',NULL,'Type 2 diabetes mellitus with ulcer'),('diabetes',1,'C10F5',NULL,'Type 2 diabetes mellitus with gangrene'),('diabetes',1,'C10F500',NULL,'Type 2 diabetes mellitus with gangrene'),('diabetes',1,'C10F6',NULL,'Type 2 diabetes mellitus with retinopathy'),('diabetes',1,'C10F600',NULL,'Type 2 diabetes mellitus with retinopathy'),('diabetes',1,'C10F7',NULL,'Type 2 diabetes mellitus - poor control'),('diabetes',1,'C10F700',NULL,'Type 2 diabetes mellitus - poor control'),('diabetes',1,'C10F8',NULL,'Reavens syndrome'),('diabetes',1,'C10F800',NULL,'Reavens syndrome'),('diabetes',1,'C10F9',NULL,'Type 2 diabetes mellitus without complication'),('diabetes',1,'C10F900',NULL,'Type 2 diabetes mellitus without complication'),('diabetes',1,'C10FA',NULL,'Type 2 diabetes mellitus with mononeuropathy'),('diabetes',1,'C10FA00',NULL,'Type 2 diabetes mellitus with mononeuropathy'),('diabetes',1,'C10FB',NULL,'Type 2 diabetes mellitus with polyneuropathy'),('diabetes',1,'C10FB00',NULL,'Type 2 diabetes mellitus with polyneuropathy'),('diabetes',1,'C10FC',NULL,'Type 2 diabetes mellitus with nephropathy'),('diabetes',1,'C10FC00',NULL,'Type 2 diabetes mellitus with nephropathy'),('diabetes',1,'C10FD',NULL,'Type 2 diabetes mellitus with hypoglycaemic coma'),('diabetes',1,'C10FD00',NULL,'Type 2 diabetes mellitus with hypoglycaemic coma'),('diabetes',1,'C10FE',NULL,'Type 2 diabetes mellitus with diabetic cataract'),('diabetes',1,'C10FE00',NULL,'Type 2 diabetes mellitus with diabetic cataract'),('diabetes',1,'C10FF',NULL,'Type 2 diabetes mellitus with peripheral angiopathy'),('diabetes',1,'C10FF00',NULL,'Type 2 diabetes mellitus with peripheral angiopathy'),('diabetes',1,'C10FG',NULL,'Type 2 diabetes mellitus with arthropathy'),('diabetes',1,'C10FG00',NULL,'Type 2 diabetes mellitus with arthropathy'),('diabetes',1,'C10FH',NULL,'Type 2 diabetes mellitus with neuropathic arthropathy'),('diabetes',1,'C10FH00',NULL,'Type 2 diabetes mellitus with neuropathic arthropathy'),('diabetes',1,'C10FJ',NULL,'Insulin treated Type 2 diabetes mellitus'),('diabetes',1,'C10FJ00',NULL,'Insulin treated Type 2 diabetes mellitus'),('diabetes',1,'C10FK',NULL,'Hyperosmolar non-ketotic state in type 2 diabetes mellitus'),('diabetes',1,'C10FK00',NULL,'Hyperosmolar non-ketotic state in type 2 diabetes mellitus'),('diabetes',1,'C10FL',NULL,'Type 2 diabetes mellitus with persistent proteinuria'),('diabetes',1,'C10FL00',NULL,'Type 2 diabetes mellitus with persistent proteinuria'),('diabetes',1,'C10FM',NULL,'Type 2 diabetes mellitus with persistent microalbuminuria'),('diabetes',1,'C10FM00',NULL,'Type 2 diabetes mellitus with persistent microalbuminuria'),('diabetes',1,'C10FN',NULL,'Type 2 diabetes mellitus with ketoacidosis'),('diabetes',1,'C10FN00',NULL,'Type 2 diabetes mellitus with ketoacidosis'),('diabetes',1,'C10FP',NULL,'Type 2 diabetes mellitus with ketoacidotic coma'),('diabetes',1,'C10FP00',NULL,'Type 2 diabetes mellitus with ketoacidotic coma'),('diabetes',1,'C10FQ',NULL,'Type 2 diabetes mellitus with exudative maculopathy'),('diabetes',1,'C10FQ00',NULL,'Type 2 diabetes mellitus with exudative maculopathy'),('diabetes',1,'C10FR',NULL,'Type 2 diabetes mellitus with gastroparesis'),('diabetes',1,'C10FR00',NULL,'Type 2 diabetes mellitus with gastroparesis'),('diabetes',1,'C10FS',NULL,'Maternally inherited diabetes mellitus'),('diabetes',1,'C10FS00',NULL,'Maternally inherited diabetes mellitus'),('diabetes',1,'C10G.',NULL,'Secondary pancreatic diabetes mellitus'),('diabetes',1,'C10G.00',NULL,'Secondary pancreatic diabetes mellitus'),('diabetes',1,'C10G0',NULL,'Secondary pancreatic diabetes mellitus without complication'),('diabetes',1,'C10G000',NULL,'Secondary pancreatic diabetes mellitus without complication'),('diabetes',1,'C10H.',NULL,'Diabetes mellitus induced by non-steroid drugs'),('diabetes',1,'C10H.00',NULL,'Diabetes mellitus induced by non-steroid drugs'),('diabetes',1,'C10H0',NULL,'Diabetes mellitus induced by non-steroid drugs without complication'),('diabetes',1,'C10H000',NULL,'Diabetes mellitus induced by non-steroid drugs without complication'),('diabetes',1,'C10M.',NULL,'Lipoatrophic diabetes mellitus'),('diabetes',1,'C10M.00',NULL,'Lipoatrophic diabetes mellitus'),('diabetes',1,'C10M0',NULL,'Lipoatrophic diabetes mellitus without complication'),('diabetes',1,'C10M000',NULL,'Lipoatrophic diabetes mellitus without complication'),('diabetes',1,'C10N.',NULL,'Secondary diabetes mellitus'),('diabetes',1,'C10N.00',NULL,'Secondary diabetes mellitus'),('diabetes',1,'C10N0',NULL,'Secondary diabetes mellitus without complication'),('diabetes',1,'C10N000',NULL,'Secondary diabetes mellitus without complication'),('diabetes',1,'C10N1',NULL,'Cystic fibrosis related diabetes mellitus'),('diabetes',1,'C10N100',NULL,'Cystic fibrosis related diabetes mellitus'),('diabetes',1,'C10Q.',NULL,'Maturity onset diabetes of the young type 5'),('diabetes',1,'C10Q.00',NULL,'Maturity onset diabetes of the young type 5'),('diabetes',1,'C10y.',NULL,'Diabetes mellitus with other specified manifestation'),('diabetes',1,'C10y.00',NULL,'Diabetes mellitus with other specified manifestation'),('diabetes',1,'C10y0',NULL,'Diabetes mellitus, juvenile type, with other specified manifestation'),('diabetes',1,'C10y000',NULL,'Diabetes mellitus, juvenile type, with other specified manifestation'),('diabetes',1,'C10y1',NULL,'Diabetes mellitus, adult onset, with other specified manifestation'),('diabetes',1,'C10y100',NULL,'Diabetes mellitus, adult onset, with other specified manifestation'),('diabetes',1,'C10yy',NULL,'Other specified diabetes mellitus with other specified complications'),('diabetes',1,'C10yy00',NULL,'Other specified diabetes mellitus with other specified complications'),('diabetes',1,'C10yz',NULL,'Diabetes mellitus NOS with other specified manifestation'),('diabetes',1,'C10yz00',NULL,'Diabetes mellitus NOS with other specified manifestation'),('diabetes',1,'C10z.',NULL,'Diabetes mellitus with unspecified complication'),('diabetes',1,'C10z.00',NULL,'Diabetes mellitus with unspecified complication'),('diabetes',1,'C10z0',NULL,'Diabetes mellitus, juvenile type, with unspecified complication'),('diabetes',1,'C10z000',NULL,'Diabetes mellitus, juvenile type, with unspecified complication'),('diabetes',1,'C10z1',NULL,'Diabetes mellitus, adult onset, with unspecified complication'),('diabetes',1,'C10z100',NULL,'Diabetes mellitus, adult onset, with unspecified complication'),('diabetes',1,'C10zy',NULL,'Other specified diabetes mellitus with unspecified complications'),('diabetes',1,'C10zy00',NULL,'Other specified diabetes mellitus with unspecified complications'),('diabetes',1,'C10zz',NULL,'Diabetes mellitus NOS with unspecified complication'),('diabetes',1,'C10zz00',NULL,'Diabetes mellitus NOS with unspecified complication'),('diabetes',1,'C1A0.',NULL,'Metabolic syndrome'),('diabetes',1,'C1A0.00',NULL,'Metabolic syndrome'),('diabetes',1,'Cyu2.',NULL,'[X]Diabetes mellitus'),('diabetes',1,'Cyu2.00',NULL,'[X]Diabetes mellitus'),('diabetes',1,'Cyu20',NULL,'[X]Other specified diabetes mellitus'),('diabetes',1,'Cyu2000',NULL,'[X]Other specified diabetes mellitus'),('diabetes',1,'Cyu21',NULL,'[X]Malnutrition-related diabetes mellitus with other specified complications'),('diabetes',1,'Cyu2100',NULL,'[X]Malnutrition-related diabetes mellitus with other specified complications'),('diabetes',1,'Cyu22',NULL,'[X]Malnutrition-related diabetes mellitus with unspecified complications'),('diabetes',1,'Cyu2200',NULL,'[X]Malnutrition-related diabetes mellitus with unspecified complications'),('diabetes',1,'Cyu23',NULL,'[X]Unspecified diabetes mellitus with renal complications'),('diabetes',1,'Cyu2300',NULL,'[X]Unspecified diabetes mellitus with renal complications'),('diabetes',1,'L180.',NULL,'Diabetes mellitus during pregnancy, childbirth and the puerperium'),('diabetes',1,'L180.00',NULL,'Diabetes mellitus during pregnancy, childbirth and the puerperium'),
('diabetes',1,'L1800',NULL,'Diabetes mellitus - unspecified whether during pregnancy or the puerperium'),('diabetes',1,'L180000',NULL,'Diabetes mellitus - unspecified whether during pregnancy or the puerperium'),('diabetes',1,'L1801',NULL,'Diabetes mellitus during pregnancy - baby delivered'),('diabetes',1,'L180100',NULL,'Diabetes mellitus during pregnancy - baby delivered'),('diabetes',1,'L1802',NULL,'Diabetes mellitus in the puerperium - baby delivered during current episode of care'),('diabetes',1,'L180200',NULL,'Diabetes mellitus in the puerperium - baby delivered during current episode of care'),('diabetes',1,'L1803',NULL,'Diabetes mellitus during pregnancy - baby not yet delivered'),('diabetes',1,'L180300',NULL,'Diabetes mellitus during pregnancy - baby not yet delivered'),('diabetes',1,'L1804',NULL,'Diabetes mellitus in the pueperium - baby delivered during previous episode of care'),('diabetes',1,'L180400',NULL,'Diabetes mellitus in the pueperium - baby delivered during previous episode of care'),('diabetes',1,'L1805',NULL,'Pre-existing diabetes mellitus, insulin-dependent'),('diabetes',1,'L180500',NULL,'Pre-existing diabetes mellitus, insulin-dependent'),('diabetes',1,'L1806',NULL,'Pre-existing diabetes mellitus, non-insulin-dependent'),('diabetes',1,'L180600',NULL,'Pre-existing diabetes mellitus, non-insulin-dependent'),('diabetes',1,'L1807',NULL,'Pre-existing malnutrition-related diabetes mellitus'),('diabetes',1,'L180700',NULL,'Pre-existing malnutrition-related diabetes mellitus'),('diabetes',1,'L1808',NULL,'Diabetes mellitus arising in pregnancy'),('diabetes',1,'L180800',NULL,'Diabetes mellitus arising in pregnancy'),('diabetes',1,'L1809',NULL,'Gestational diabetes mellitus'),('diabetes',1,'L180900',NULL,'Gestational diabetes mellitus'),('diabetes',1,'L180A',NULL,'Pre-existing type 1 diabetes mellitus in pregnancy'),('diabetes',1,'L180A00',NULL,'Pre-existing type 1 diabetes mellitus in pregnancy'),('diabetes',1,'L180B',NULL,'Pre-existing type 2 diabetes mellitus in pregnancy'),('diabetes',1,'L180B00',NULL,'Pre-existing type 2 diabetes mellitus in pregnancy'),('diabetes',1,'L180X',NULL,'Pre-existing diabetes mellitus, unspecified'),('diabetes',1,'L180X00',NULL,'Pre-existing diabetes mellitus, unspecified'),('diabetes',1,'L180z',NULL,'Diabetes mellitus during pregnancy, childbirth or the puerperium NOS'),('diabetes',1,'L180z00',NULL,'Diabetes mellitus during pregnancy, childbirth or the puerperium NOS'),('diabetes',1,'Lyu29',NULL,'[X]Pre-existing diabetes mellitus, unspecified'),('diabetes',1,'Lyu2900',NULL,'[X]Pre-existing diabetes mellitus, unspecified'),('diabetes',1,'PKyP.',NULL,'Diabetes insipidus, diabetes mellitus, optic atrophy and deafness'),('diabetes',1,'PKyP.00',NULL,'Diabetes insipidus, diabetes mellitus, optic atrophy and deafness'),('diabetes',1,'Q441.',NULL,'Neonatal diabetes mellitus'),('diabetes',1,'Q441.00',NULL,'Neonatal diabetes mellitus'),('diabetes',1,'ZV13F',NULL,'[V]Personal history of gestational diabetes mellitus'),('diabetes',1,'ZV13F00',NULL,'[V]Personal history of gestational diabetes mellitus');
INSERT INTO #codesreadv2
VALUES ('glomerulonephritis',1,'K02..',NULL,'Chronic glomerulonephritis'),('glomerulonephritis',1,'K02..00',NULL,'Chronic glomerulonephritis'),('glomerulonephritis',1,'K02z.',NULL,'Chronic glomerulonephritis NOS'),('glomerulonephritis',1,'K02z.00',NULL,'Chronic glomerulonephritis NOS'),('glomerulonephritis',1,'K02y.',NULL,'Other chronic glomerulonephritis'),('glomerulonephritis',1,'K02y.00',NULL,'Other chronic glomerulonephritis'),('glomerulonephritis',1,'K02yz',NULL,'Other chronic glomerulonephritis NOS'),('glomerulonephritis',1,'K02yz00',NULL,'Other chronic glomerulonephritis NOS'),('glomerulonephritis',1,'K02y3',NULL,'Chronic diffuse glomerulonephritis'),('glomerulonephritis',1,'K02y300',NULL,'Chronic diffuse glomerulonephritis'),('glomerulonephritis',1,'K02y2',NULL,'Chronic focal glomerulonephritis'),('glomerulonephritis',1,'K02y200',NULL,'Chronic focal glomerulonephritis'),('glomerulonephritis',1,'K02y1',NULL,'Chronic exudative glomerulonephritis'),('glomerulonephritis',1,'K02y100',NULL,'Chronic exudative glomerulonephritis'),('glomerulonephritis',1,'K02y0',NULL,'Chronic glomerulonephritis + diseases EC'),('glomerulonephritis',1,'K02y000',NULL,'Chronic glomerulonephritis + diseases EC'),('glomerulonephritis',1,'K023.',NULL,'Chronic rapidly progressive glomerulonephritis'),('glomerulonephritis',1,'K023.00',NULL,'Chronic rapidly progressive glomerulonephritis'),('glomerulonephritis',1,'K022.',NULL,'Chronic membranoproliferative glomerulonephritis'),('glomerulonephritis',1,'K022.00',NULL,'Chronic membranoproliferative glomerulonephritis'),('glomerulonephritis',1,'K021.',NULL,'Chronic membranous glomerulonephritis'),('glomerulonephritis',1,'K021.00',NULL,'Chronic membranous glomerulonephritis'),('glomerulonephritis',1,'K020.',NULL,'Chronic proliferative glomerulonephritis'),('glomerulonephritis',1,'K020.00',NULL,'Chronic proliferative glomerulonephritis'),('glomerulonephritis',1,'K00..',NULL,'Acute glomerulonephritis'),('glomerulonephritis',1,'K00..00',NULL,'Acute glomerulonephritis'),('glomerulonephritis',1,'K00z.',NULL,'Acute glomerulonephritis NOS'),('glomerulonephritis',1,'K00z.00',NULL,'Acute glomerulonephritis NOS'),('glomerulonephritis',1,'K00y.',NULL,'Other acute glomerulonephritis'),('glomerulonephritis',1,'K00y.00',NULL,'Other acute glomerulonephritis'),('glomerulonephritis',1,'K00yz',NULL,'Other acute glomerulonephritis NOS'),('glomerulonephritis',1,'K00yz00',NULL,'Other acute glomerulonephritis NOS'),('glomerulonephritis',1,'K00y0',NULL,'Acute glomerulonephritis in diseases EC'),('glomerulonephritis',1,'K00y000',NULL,'Acute glomerulonephritis in diseases EC'),('glomerulonephritis',1,'K000.',NULL,'Acute proliferative glomerulonephritis'),('glomerulonephritis',1,'K000.00',NULL,'Acute proliferative glomerulonephritis'),('glomerulonephritis',1,'K0001',NULL,'Crescentic glomerulonephritis'),('glomerulonephritis',1,'K000100',NULL,'Crescentic glomerulonephritis'),('glomerulonephritis',1,'K032z',NULL,'Nephritis unspecified with lesion of membranoproliferative glomerulonephritis NOS'),('glomerulonephritis',1,'K032z00',NULL,'Nephritis unspecified with lesion of membranoproliferative glomerulonephritis NOS'),('glomerulonephritis',1,'K032y',NULL,'Nephritis unspecified with other specified lesion of membranoproliferative glomerulonephritis'),('glomerulonephritis',1,'K032y00',NULL,'Nephritis unspecified with other specified lesion of membranoproliferative glomerulonephritis'),('glomerulonephritis',1,'K0325',NULL,'Other familial glomerulonephritis'),('glomerulonephritis',1,'K032500',NULL,'Other familial glomerulonephritis'),('glomerulonephritis',1,'K0324',NULL,'Familial glomerulonephritis in Alports syndrome'),('glomerulonephritis',1,'K032400',NULL,'Familial glomerulonephritis in Alports syndrome'),('glomerulonephritis',1,'K0323',NULL,'Anaphylactoid glomerulonephritis'),('glomerulonephritis',1,'K032300',NULL,'Anaphylactoid glomerulonephritis'),('glomerulonephritis',1,'K0322',NULL,'Focal glomerulonephritis with focal recurrent macroscopic glomerulonephritis'),('glomerulonephritis',1,'K032200',NULL,'Focal glomerulonephritis with focal recurrent macroscopic glomerulonephritis'),('glomerulonephritis',1,'K0320',NULL,'Focal membranoproliferative glomerulonephritis'),('glomerulonephritis',1,'K032000',NULL,'Focal membranoproliferative glomerulonephritis'),('glomerulonephritis',1,'K01B.',NULL,'Nephrotic syndrome, diffuse crescentic glomerulonephritis'),('glomerulonephritis',1,'K01B.00',NULL,'Nephrotic syndrome, diffuse crescentic glomerulonephritis'),('glomerulonephritis',1,'K019.',NULL,'Nephrotic syndrome, diffuse mesangiocapillary glomerulonephritis'),('glomerulonephritis',1,'K019.00',NULL,'Nephrotic syndrome, diffuse mesangiocapillary glomerulonephritis'),('glomerulonephritis',1,'K018.',NULL,'Nephrotic syndrome, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'K018.00',NULL,'Nephrotic syndrome, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'K017.',NULL,'Nephrotic syndrome, diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'K017.00',NULL,'Nephrotic syndrome, diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'K016.',NULL,'Nephrotic syndrome, diffuse membranous glomerulonephritis'),('glomerulonephritis',1,'K016.00',NULL,'Nephrotic syndrome, diffuse membranous glomerulonephritis'),('glomerulonephritis',1,'K012.',NULL,'Nephrotic syndrome with membranoproliferative glomerulonephritis'),('glomerulonephritis',1,'K012.00',NULL,'Nephrotic syndrome with membranoproliferative glomerulonephritis'),('glomerulonephritis',1,'K011.',NULL,'Nephrotic syndrome with membranous glomerulonephritis'),('glomerulonephritis',1,'K011.00',NULL,'Nephrotic syndrome with membranous glomerulonephritis'),('glomerulonephritis',1,'K010.',NULL,'Nephrotic syndrome with proliferative glomerulonephritis'),('glomerulonephritis',1,'K010.00',NULL,'Nephrotic syndrome with proliferative glomerulonephritis'),('glomerulonephritis',1,'K013.',NULL,'Nephrotic syndrome with minimal change glomerulonephritis'),('glomerulonephritis',1,'K013.00',NULL,'Nephrotic syndrome with minimal change glomerulonephritis'),('glomerulonephritis',1,'K03z.',NULL,'Unspecified glomerulonephritis NOS'),('glomerulonephritis',1,'K03z.00',NULL,'Unspecified glomerulonephritis NOS'),('glomerulonephritis',1,'K03X.',NULL,'Unspecified nephritic syndrome, diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'K03X.00',NULL,'Unspecified nephritic syndrome, diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'K03W.',NULL,'Unspecified nephritic syndrome, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'K03W.00',NULL,'Unspecified nephritic syndrome, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'K03U.',NULL,'Unspecified nephritic syndrome, diffuse concentric glomerulonephritis'),('glomerulonephritis',1,'K03U.00',NULL,'Unspecified nephritic syndrome, diffuse concentric glomerulonephritis'),('glomerulonephritis',1,'K036.',NULL,'Cryoglobulinaemic glomerulonephritis'),('glomerulonephritis',1,'K036.00',NULL,'Cryoglobulinaemic glomerulonephritis'),('glomerulonephritis',1,'K0A07',NULL,'Acute nephritic syndrome, diffuse crescentic glomerulonephritis'),('glomerulonephritis',1,'K0A0700',NULL,'Acute nephritic syndrome, diffuse crescentic glomerulonephritis'),('glomerulonephritis',1,'K0A05',NULL,'Acute nephritic syndrome, diffuse mesangiocapillary glomerulonephritis'),('glomerulonephritis',1,'K0A0500',NULL,'Acute nephritic syndrome, diffuse mesangiocapillary glomerulonephritis'),('glomerulonephritis',1,'K0A04',NULL,'Acute nephritic syndrome, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A0400',NULL,'Acute nephritic syndrome, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A03',NULL,'Acute nephritic syndrome, diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A0300',NULL,'Acute nephritic syndrome, diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A02',NULL,'Acute nephritic syndrome, diffuse membranous glomerulonephritis'),('glomerulonephritis',1,'K0A0200',NULL,'Acute nephritic syndrome, diffuse membranous glomerulonephritis'),('glomerulonephritis',1,'K0A17',NULL,'Rapidly progressive nephritic syndrome, diffuse crescentic glomerulonephritis'),('glomerulonephritis',1,'K0A1700',NULL,'Rapidly progressive nephritic syndrome, diffuse crescentic glomerulonephritis'),('glomerulonephritis',1,'K0A15',NULL,'Rapidly progressive nephritic syndrome, diffuse mesangiocapillary glomerulonephritis'),('glomerulonephritis',1,'K0A1500',NULL,'Rapidly progressive nephritic syndrome, diffuse mesangiocapillary glomerulonephritis'),('glomerulonephritis',1,'K0A14',NULL,'Rapidly progressive nephritic syndrome, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A1400',NULL,'Rapidly progressive nephritic syndrome, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A13',NULL,'Rapidly progressive nephritic syndrome, diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A1300',NULL,'Rapidly progressive nephritic syndrome, diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A12',NULL,'Rapidly progressive nephritic syndrome, diffuse membranous glomerulonephritis'),('glomerulonephritis',1,'K0A1200',NULL,'Rapidly progressive nephritic syndrome, diffuse membranous glomerulonephritis'),('glomerulonephritis',1,'K0A27',NULL,'Recurrent and persistent haematuria, diffuse crescentic glomerulonephritis'),('glomerulonephritis',1,'K0A2700',NULL,'Recurrent and persistent haematuria, diffuse crescentic glomerulonephritis'),('glomerulonephritis',1,'K0A25',NULL,'Recurrent and persistent haematuria, diffuse mesangiocapillary glomerulonephritis'),
('glomerulonephritis',1,'K0A2500',NULL,'Recurrent and persistent haematuria, diffuse mesangiocapillary glomerulonephritis'),('glomerulonephritis',1,'K0A24',NULL,'Recurrent and persistent haematuria, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A2400',NULL,'Recurrent and persistent haematuria, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A23',NULL,'Recurrent and persistent haematuria, diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A2300',NULL,'Recurrent and persistent haematuria, diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A22',NULL,'Recurrent and persistent haematuria, diffuse membranous glomerulonephritis'),('glomerulonephritis',1,'K0A2200',NULL,'Recurrent and persistent haematuria, diffuse membranous glomerulonephritis'),('glomerulonephritis',1,'K0A37',NULL,'Chronic nephritic syndrome, diffuse crescentic glomerulonephritis'),('glomerulonephritis',1,'K0A3700',NULL,'Chronic nephritic syndrome, diffuse crescentic glomerulonephritis'),('glomerulonephritis',1,'K0A35',NULL,'Chronic nephritic syndrome, diffuse mesangiocapillary glomerulonephritis'),('glomerulonephritis',1,'K0A3500',NULL,'Chronic nephritic syndrome, diffuse mesangiocapillary glomerulonephritis'),('glomerulonephritis',1,'K0A34',NULL,'Chronic nephritic syndrome, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A3400',NULL,'Chronic nephritic syndrome, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A33',NULL,'Chronic nephritic syndrome, diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A3300',NULL,'Chronic nephritic syndrome, diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A32',NULL,'Chronic nephritic syndrome, diffuse membranous glomerulonephritis'),('glomerulonephritis',1,'K0A3200',NULL,'Chronic nephritic syndrome, diffuse membranous glomerulonephritis'),('glomerulonephritis',1,'K0A47',NULL,'Isolated proteinuria with specified morphological lesion, diffuse concentric glomerulonephritis'),('glomerulonephritis',1,'K0A4700',NULL,'Isolated proteinuria with specified morphological lesion, diffuse concentric glomerulonephritis'),('glomerulonephritis',1,'K0A45',NULL,'Isolated proteinuria with specified morphological lesion, diffuse mesangiocapillary glomerulonephritis'),('glomerulonephritis',1,'K0A4500',NULL,'Isolated proteinuria with specified morphological lesion, diffuse mesangiocapillary glomerulonephritis'),('glomerulonephritis',1,'K0A44',NULL,'Isolated proteinuria with specified morphological lesion, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A4400',NULL,'Isolated proteinuria with specified morphological lesion, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A43',NULL,'Isolated proteinuria with specified morphological lesion, diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A4300',NULL,'Isolated proteinuria with specified morphological lesion, diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A42',NULL,'Isolated proteinuria with specified morphological lesion, diffuse membranous glomerulonephritis'),('glomerulonephritis',1,'K0A4200',NULL,'Isolated proteinuria with specified morphological lesion, diffuse membranous glomerulonephritis'),('glomerulonephritis',1,'K0A57',NULL,'Hereditary nephropathy, not elsewhere classified, diffuse crescentic glomerulonephritis'),('glomerulonephritis',1,'K0A5700',NULL,'Hereditary nephropathy, not elsewhere classified, diffuse crescentic glomerulonephritis'),('glomerulonephritis',1,'K0A55',NULL,'[X]Hereditary nephropathy, not elsewhere classified, diffuse mesangiocapillary glomerulonephritis'),('glomerulonephritis',1,'K0A5500',NULL,'[X]Hereditary nephropathy, not elsewhere classified, diffuse mesangiocapillary glomerulonephritis'),('glomerulonephritis',1,'K0A54',NULL,'Hereditary nephropathy, not elsewhere classified, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A5400',NULL,'Hereditary nephropathy, not elsewhere classified, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A53',NULL,'Hereditary nephropathy, not elsewhere classified, diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A5300',NULL,'Hereditary nephropathy, not elsewhere classified, diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A52',NULL,'Hereditary nephropathy, not elsewhere classified, diffuse membranous glomerulonephritis'),('glomerulonephritis',1,'K0A5200',NULL,'Hereditary nephropathy, not elsewhere classified, diffuse membranous glomerulonephritis'),('glomerulonephritis',1,'Kyu0C',NULL,'[X]Unspecified nephritic syndrome, diffuse concentric glomerulonephritis'),('glomerulonephritis',1,'Kyu0C00',NULL,'[X]Unspecified nephritic syndrome, diffuse concentric glomerulonephritis'),('glomerulonephritis',1,'Kyu0A',NULL,'[X]Unspecified nephritic syndrome, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'Kyu0A00',NULL,'[X]Unspecified nephritic syndrome, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'Kyu09',NULL,'[X]Unspecified nephritic syndrome, diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'Kyu0900',NULL,'[X]Unspecified nephritic syndrome, diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A9.',NULL,'Cytomegalovirus-induced glomerulonephritis'),('glomerulonephritis',1,'K0A9.00',NULL,'Cytomegalovirus-induced glomerulonephritis'),('glomerulonephritis',1,'K0A8.',NULL,'Rapidly progressive glomerulonephritis'),('glomerulonephritis',1,'K0A8.00',NULL,'Rapidly progressive glomerulonephritis'),('glomerulonephritis',1,'SP08b',NULL,'De novo glomerulonephritis'),('glomerulonephritis',1,'SP08b00',NULL,'De novo glomerulonephritis'),('glomerulonephritis',1,'K0A28',NULL,'IgA nephropathy'),('glomerulonephritis',1,'K0A2800',NULL,'IgA nephropathy'),('glomerulonephritis',1,'G7520',NULL,'Goodpastures syndrome'),('glomerulonephritis',1,'G752000',NULL,'Goodpastures syndrome'),('glomerulonephritis',1,'K01x4',NULL,'Nephrotic syndrome in systemic lupus erythematosus'),('glomerulonephritis',1,'K01x400',NULL,'Nephrotic syndrome in systemic lupus erythematosus'),('glomerulonephritis',1,'K00y2',NULL,'Acute focal nephritis'),('glomerulonephritis',1,'K00y200',NULL,'Acute focal nephritis'),('glomerulonephritis',1,'K00y3',NULL,'Acute diffuse nephritis'),('glomerulonephritis',1,'K00y300',NULL,'Acute diffuse nephritis'),('glomerulonephritis',1,'K033.',NULL,'Rapidly progressive nephritis unspecified'),('glomerulonephritis',1,'K033.00',NULL,'Rapidly progressive nephritis unspecified'),('glomerulonephritis',1,'PKy90',NULL,'Alports syndrome'),('glomerulonephritis',1,'PKy9000',NULL,'Alports syndrome'),('glomerulonephritis',1,'K001.',NULL,'Acute nephritis with lesions of necrotising glomerulitis'),('glomerulonephritis',1,'K001.00',NULL,'Acute nephritis with lesions of necrotising glomerulitis'),('glomerulonephritis',1,'K00y1',NULL,'Acute exudative nephritis'),('glomerulonephritis',1,'K00y100',NULL,'Acute exudative nephritis'),('glomerulonephritis',1,'K031.',NULL,'Membranous nephritis unspecified'),('glomerulonephritis',1,'K031.00',NULL,'Membranous nephritis unspecified');
INSERT INTO #codesreadv2
VALUES ('hypertension',1,'G2...',NULL,'Hypertensive disease'),('hypertension',1,'G2...00',NULL,'Hypertensive disease'),('hypertension',1,'G2z..',NULL,'Hypertensive disease NOS'),('hypertension',1,'G2z..00',NULL,'Hypertensive disease NOS'),('hypertension',1,'G2y..',NULL,'Other specified hypertensive disease'),('hypertension',1,'G2y..00',NULL,'Other specified hypertensive disease'),('hypertension',1,'G28..',NULL,'Stage 2 hypertension (NICE - National Institute for Health and Clinical Excellence 2011)'),('hypertension',1,'G28..00',NULL,'Stage 2 hypertension (NICE - National Institute for Health and Clinical Excellence 2011)'),('hypertension',1,'G26..',NULL,'Severe hypertension (NICE - National Institute for Health and Clinical Excellence 2011)'),('hypertension',1,'G26..00',NULL,'Severe hypertension (NICE - National Institute for Health and Clinical Excellence 2011)'),('hypertension',1,'G25..',NULL,'Stage 1 hypertension (NICE - National Institute for Health and Clinical Excellence 2011)'),('hypertension',1,'G25..00',NULL,'Stage 1 hypertension (NICE - National Institute for Health and Clinical Excellence 2011)'),('hypertension',1,'G251.',NULL,'Stage 1 hypertension (NICE 2011) with evidence of end organ damage'),('hypertension',1,'G251.00',NULL,'Stage 1 hypertension (NICE 2011) with evidence of end organ damage'),('hypertension',1,'G250.',NULL,'Stage 1 hypertension (NICE 2011) without evidence of end organ damage'),('hypertension',1,'G250.00',NULL,'Stage 1 hypertension (NICE 2011) without evidence of end organ damage'),('hypertension',1,'G24..',NULL,'Secondary hypertension'),('hypertension',1,'G24..00',NULL,'Secondary hypertension'),('hypertension',1,'G24z.',NULL,'Secondary hypertension NOS'),('hypertension',1,'G24z.00',NULL,'Secondary hypertension NOS'),('hypertension',1,'G24zz',NULL,'Secondary hypertension NOS'),('hypertension',1,'G24zz00',NULL,'Secondary hypertension NOS'),('hypertension',1,'G24z0',NULL,'Secondary renovascular hypertension NOS'),('hypertension',1,'G24z000',NULL,'Secondary renovascular hypertension NOS'),('hypertension',1,'G244.',NULL,'Hypertension secondary to endocrine disorders'),('hypertension',1,'G244.00',NULL,'Hypertension secondary to endocrine disorders'),('hypertension',1,'G241.',NULL,'Secondary benign hypertension'),('hypertension',1,'G241.00',NULL,'Secondary benign hypertension'),('hypertension',1,'G241z',NULL,'Secondary benign hypertension NOS'),('hypertension',1,'G241z00',NULL,'Secondary benign hypertension NOS'),('hypertension',1,'G2410',NULL,'Secondary benign renovascular hypertension'),('hypertension',1,'G241000',NULL,'Secondary benign renovascular hypertension'),('hypertension',1,'G240.',NULL,'Secondary malignant hypertension'),('hypertension',1,'G240.00',NULL,'Secondary malignant hypertension'),('hypertension',1,'G240z',NULL,'Secondary malignant hypertension NOS'),('hypertension',1,'G240z00',NULL,'Secondary malignant hypertension NOS'),('hypertension',1,'G2400',NULL,'Secondary malignant renovascular hypertension'),('hypertension',1,'G240000',NULL,'Secondary malignant renovascular hypertension'),('hypertension',1,'G20..',NULL,'Essential hypertension'),('hypertension',1,'G20..00',NULL,'Essential hypertension'),('hypertension',1,'G20z.',NULL,'Essential hypertension NOS'),('hypertension',1,'G20z.00',NULL,'Essential hypertension NOS'),('hypertension',1,'G203.',NULL,'Diastolic hypertension'),('hypertension',1,'G203.00',NULL,'Diastolic hypertension'),('hypertension',1,'G202.',NULL,'Systolic hypertension'),('hypertension',1,'G202.00',NULL,'Systolic hypertension'),('hypertension',1,'G201.',NULL,'Benign essential hypertension'),('hypertension',1,'G201.00',NULL,'Benign essential hypertension'),('hypertension',1,'G200.',NULL,'Malignant essential hypertension'),('hypertension',1,'G200.00',NULL,'Malignant essential hypertension'),('hypertension',1,'Gyu2.',NULL,'[X]Hypertensive diseases'),('hypertension',1,'Gyu2.00',NULL,'[X]Hypertensive diseases'),('hypertension',1,'Gyu21',NULL,'[X]Hypertension secondary to other renal disorders'),('hypertension',1,'Gyu2100',NULL,'[X]Hypertension secondary to other renal disorders'),('hypertension',1,'Gyu20',NULL,'[X]Other secondary hypertension'),('hypertension',1,'Gyu2000',NULL,'[X]Other secondary hypertension');
INSERT INTO #codesreadv2
VALUES ('kidney-stones',1,'4G4..',NULL,'O/E: kidney stone'),('kidney-stones',1,'4G4..00',NULL,'O/E: kidney stone'),('kidney-stones',1,'4G42.',NULL,'O/E: phosphate -staghorn-stone'),('kidney-stones',1,'4G42.00',NULL,'O/E: phosphate -staghorn-stone'),('kidney-stones',1,'4G4Z.',NULL,'O/E: renal stone NOS'),('kidney-stones',1,'4G4Z.00',NULL,'O/E: renal stone NOS'),('kidney-stones',1,'C3411',NULL,'Renal stone - uric acid'),('kidney-stones',1,'C341100',NULL,'Renal stone - uric acid'),('kidney-stones',1,'K1006',NULL,'Calculous pyelonephritis'),('kidney-stones',1,'K100600',NULL,'Calculous pyelonephritis'),('kidney-stones',1,'K12..',NULL,'Calculus of kidney and ureter'),('kidney-stones',1,'K12..00',NULL,'Calculus of kidney and ureter'),('kidney-stones',1,'K120.',NULL,'Calculus of kidney'),('kidney-stones',1,'K120.00',NULL,'Calculus of kidney'),('kidney-stones',1,'K122.',NULL,'Calculus of kidney with calculus of ureter'),('kidney-stones',1,'K122.00',NULL,'Calculus of kidney with calculus of ureter'),('kidney-stones',1,'PD31.',NULL,'Congenital calculus of kidney'),('kidney-stones',1,'PD31.00',NULL,'Congenital calculus of kidney');
INSERT INTO #codesreadv2
VALUES ('vasculitis',1,'M2y0X',NULL,'Vasculitis limited to skin, unspecified'),('vasculitis',1,'M2y0X00',NULL,'Vasculitis limited to skin, unspecified'),('vasculitis',1,'M2y02',NULL,'Livedoid vasculitis'),('vasculitis',1,'M2y0200',NULL,'Livedoid vasculitis'),('vasculitis',1,'Myu7G',NULL,'[X]Vasculitis limited to skin, unspecified'),('vasculitis',1,'Myu7G00',NULL,'[X]Vasculitis limited to skin, unspecified'),('vasculitis',1,'Myu7A',NULL,'[X]Other vasculitis limited to the skin'),('vasculitis',1,'Myu7A00',NULL,'[X]Other vasculitis limited to the skin'),('vasculitis',1,'M152.',NULL,'Erythema nodosum'),('vasculitis',1,'M152.00',NULL,'Erythema nodosum'),('vasculitis',1,'C3321',NULL,'Cryoglobulinaemic vasculitis'),('vasculitis',1,'C332100',NULL,'Cryoglobulinaemic vasculitis'),('vasculitis',1,'F421E',NULL,'Retinal vasculitis NOS'),('vasculitis',1,'F421E00',NULL,'Retinal vasculitis NOS'),('vasculitis',1,'G758.',NULL,'Churg-Strauss vasculitis'),('vasculitis',1,'G758.00',NULL,'Churg-Strauss vasculitis'),('vasculitis',1,'G76B.',NULL,'Vasculitis'),('vasculitis',1,'G76B.00',NULL,'Vasculitis'),('vasculitis',1,'N040N',NULL,'Rheumatoid vasculitis'),('vasculitis',1,'N040N00',NULL,'Rheumatoid vasculitis'),('vasculitis',1,'D310.',NULL,'Allergic purpura'),('vasculitis',1,'D310.00',NULL,'Allergic purpura'),('vasculitis',1,'D3100',NULL,'Acute vascular purpura'),('vasculitis',1,'D310000',NULL,'Acute vascular purpura'),('vasculitis',1,'F371.',NULL,'Polyneuropathy in collagen vascular disease'),('vasculitis',1,'F371.00',NULL,'Polyneuropathy in collagen vascular disease'),('vasculitis',1,'G750.',NULL,'Polyarteritis nodosa'),('vasculitis',1,'G750.00',NULL,'Polyarteritis nodosa'),('vasculitis',1,'G752.',NULL,'Hypersensitivity angiitis'),('vasculitis',1,'G752.00',NULL,'Hypersensitivity angiitis'),('vasculitis',1,'G752z',NULL,'Hypersensitivity angiitis NOS'),('vasculitis',1,'G752z00',NULL,'Hypersensitivity angiitis NOS');
INSERT INTO #codesreadv2
VALUES ('alcohol-heavy-drinker',1,'136b.',NULL,'Feels should cut down drinking'),('alcohol-heavy-drinker',1,'136b.00',NULL,'Feels should cut down drinking'),('alcohol-heavy-drinker',1,'136c.',NULL,'Higher risk drinking'),('alcohol-heavy-drinker',1,'136c.00',NULL,'Higher risk drinking'),('alcohol-heavy-drinker',1,'136K.',NULL,'Alcohol intake above recommended sensible limits'),('alcohol-heavy-drinker',1,'136K.00',NULL,'Alcohol intake above recommended sensible limits'),('alcohol-heavy-drinker',1,'136P.',NULL,'Heavy drinker'),('alcohol-heavy-drinker',1,'136P.00',NULL,'Heavy drinker'),('alcohol-heavy-drinker',1,'136Q.',NULL,'Very heavy drinker'),('alcohol-heavy-drinker',1,'136Q.00',NULL,'Very heavy drinker'),('alcohol-heavy-drinker',1,'136R.',NULL,'Binge drinker'),('alcohol-heavy-drinker',1,'136R.00',NULL,'Binge drinker'),('alcohol-heavy-drinker',1,'136S.',NULL,'Hazardous alcohol use'),('alcohol-heavy-drinker',1,'136S.00',NULL,'Hazardous alcohol use'),('alcohol-heavy-drinker',1,'136T.',NULL,'Harmful alcohol use'),('alcohol-heavy-drinker',1,'136T.00',NULL,'Harmful alcohol use'),('alcohol-heavy-drinker',1,'136W.',NULL,'Alcohol misuse'),('alcohol-heavy-drinker',1,'136W.00',NULL,'Alcohol misuse'),('alcohol-heavy-drinker',1,'136Y.',NULL,'Drinks in morning to get rid of hangover'),('alcohol-heavy-drinker',1,'136Y.00',NULL,'Drinks in morning to get rid of hangover'),('alcohol-heavy-drinker',1,'E23..','12','Alcohol problem drinking'),('alcohol-heavy-drinker',1,'E23..','12','Alcohol problem drinking');
INSERT INTO #codesreadv2
VALUES ('alcohol-light-drinker',1,'1362.',NULL,'Trivial drinker - <1u/day'),('alcohol-light-drinker',1,'1362.00',NULL,'Trivial drinker - <1u/day'),('alcohol-light-drinker',1,'136N.',NULL,'Light drinker'),('alcohol-light-drinker',1,'136N.00',NULL,'Light drinker'),('alcohol-light-drinker',1,'136d.',NULL,'Lower risk drinking'),('alcohol-light-drinker',1,'136d.00',NULL,'Lower risk drinking');
INSERT INTO #codesreadv2
VALUES ('alcohol-moderate-drinker',1,'136O.',NULL,'Moderate drinker'),('alcohol-moderate-drinker',1,'136O.00',NULL,'Moderate drinker'),('alcohol-moderate-drinker',1,'136F.',NULL,'Spirit drinker'),('alcohol-moderate-drinker',1,'136F.00',NULL,'Spirit drinker'),('alcohol-moderate-drinker',1,'136G.',NULL,'Beer drinker'),('alcohol-moderate-drinker',1,'136G.00',NULL,'Beer drinker'),('alcohol-moderate-drinker',1,'136H.',NULL,'Drinks beer and spirits'),('alcohol-moderate-drinker',1,'136H.00',NULL,'Drinks beer and spirits'),('alcohol-moderate-drinker',1,'136I.',NULL,'Drinks wine'),('alcohol-moderate-drinker',1,'136I.00',NULL,'Drinks wine'),('alcohol-moderate-drinker',1,'136J.',NULL,'Social drinker'),('alcohol-moderate-drinker',1,'136J.00',NULL,'Social drinker'),('alcohol-moderate-drinker',1,'136L.',NULL,'Alcohol intake within recommended sensible limits'),('alcohol-moderate-drinker',1,'136L.00',NULL,'Alcohol intake within recommended sensible limits'),('alcohol-moderate-drinker',1,'136Z.',NULL,'Alcohol consumption NOS'),('alcohol-moderate-drinker',1,'136Z.00',NULL,'Alcohol consumption NOS'),('alcohol-moderate-drinker',1,'136a.',NULL,'Increasing risk drinking'),('alcohol-moderate-drinker',1,'136a.00',NULL,'Increasing risk drinking');
INSERT INTO #codesreadv2
VALUES ('alcohol-non-drinker',1,'1361.',NULL,'Teetotaller'),('alcohol-non-drinker',1,'1361.00',NULL,'Teetotaller'),('alcohol-non-drinker',1,'136M.',NULL,'Current non drinker'),('alcohol-non-drinker',1,'136M.00',NULL,'Current non drinker');
INSERT INTO #codesreadv2
VALUES ('alcohol-weekly-intake',1,'136V.',NULL,'Alcohol units per week'),('alcohol-weekly-intake',1,'136V.00',NULL,'Alcohol units per week'),('alcohol-weekly-intake',1,'136..',NULL,'Alcohol consumption'),('alcohol-weekly-intake',1,'136..00',NULL,'Alcohol consumption');
INSERT INTO #codesreadv2
VALUES ('bmi',2,'22K..',NULL,'Body Mass Index'),('bmi',2,'22K..00',NULL,'Body Mass Index');
INSERT INTO #codesreadv2
VALUES ('smoking-status-current',1,'137P.',NULL,'Cigarette smoker'),('smoking-status-current',1,'137P.00',NULL,'Cigarette smoker'),('smoking-status-current',1,'13p3.',NULL,'Smoking status at 52 weeks'),('smoking-status-current',1,'13p3.00',NULL,'Smoking status at 52 weeks'),('smoking-status-current',1,'1374.',NULL,'Moderate smoker - 10-19 cigs/d'),('smoking-status-current',1,'1374.00',NULL,'Moderate smoker - 10-19 cigs/d'),('smoking-status-current',1,'137G.',NULL,'Trying to give up smoking'),('smoking-status-current',1,'137G.00',NULL,'Trying to give up smoking'),('smoking-status-current',1,'137R.',NULL,'Current smoker'),('smoking-status-current',1,'137R.00',NULL,'Current smoker'),('smoking-status-current',1,'1376.',NULL,'Very heavy smoker - 40+cigs/d'),('smoking-status-current',1,'1376.00',NULL,'Very heavy smoker - 40+cigs/d'),('smoking-status-current',1,'1375.',NULL,'Heavy smoker - 20-39 cigs/day'),('smoking-status-current',1,'1375.00',NULL,'Heavy smoker - 20-39 cigs/day'),('smoking-status-current',1,'1373.',NULL,'Light smoker - 1-9 cigs/day'),('smoking-status-current',1,'1373.00',NULL,'Light smoker - 1-9 cigs/day'),('smoking-status-current',1,'137M.',NULL,'Rolls own cigarettes'),('smoking-status-current',1,'137M.00',NULL,'Rolls own cigarettes'),('smoking-status-current',1,'137o.',NULL,'Waterpipe tobacco consumption'),('smoking-status-current',1,'137o.00',NULL,'Waterpipe tobacco consumption'),('smoking-status-current',1,'137m.',NULL,'Failed attempt to stop smoking'),('smoking-status-current',1,'137m.00',NULL,'Failed attempt to stop smoking'),('smoking-status-current',1,'137h.',NULL,'Minutes from waking to first tobacco consumption'),('smoking-status-current',1,'137h.00',NULL,'Minutes from waking to first tobacco consumption'),('smoking-status-current',1,'137g.',NULL,'Cigarette pack-years'),('smoking-status-current',1,'137g.00',NULL,'Cigarette pack-years'),('smoking-status-current',1,'137f.',NULL,'Reason for restarting smoking'),('smoking-status-current',1,'137f.00',NULL,'Reason for restarting smoking'),('smoking-status-current',1,'137e.',NULL,'Smoking restarted'),('smoking-status-current',1,'137e.00',NULL,'Smoking restarted'),('smoking-status-current',1,'137d.',NULL,'Not interested in stopping smoking'),('smoking-status-current',1,'137d.00',NULL,'Not interested in stopping smoking'),('smoking-status-current',1,'137c.',NULL,'Thinking about stopping smoking'),('smoking-status-current',1,'137c.00',NULL,'Thinking about stopping smoking'),('smoking-status-current',1,'137b.',NULL,'Ready to stop smoking'),('smoking-status-current',1,'137b.00',NULL,'Ready to stop smoking'),('smoking-status-current',1,'137C.',NULL,'Keeps trying to stop smoking'),('smoking-status-current',1,'137C.00',NULL,'Keeps trying to stop smoking'),('smoking-status-current',1,'137J.',NULL,'Cigar smoker'),('smoking-status-current',1,'137J.00',NULL,'Cigar smoker'),('smoking-status-current',1,'137H.',NULL,'Pipe smoker'),('smoking-status-current',1,'137H.00',NULL,'Pipe smoker'),('smoking-status-current',1,'137a.',NULL,'Pipe tobacco consumption'),('smoking-status-current',1,'137a.00',NULL,'Pipe tobacco consumption'),('smoking-status-current',1,'137Z.',NULL,'Tobacco consumption NOS'),('smoking-status-current',1,'137Z.00',NULL,'Tobacco consumption NOS'),('smoking-status-current',1,'137Y.',NULL,'Cigar consumption'),('smoking-status-current',1,'137Y.00',NULL,'Cigar consumption'),('smoking-status-current',1,'137X.',NULL,'Cigarette consumption'),('smoking-status-current',1,'137X.00',NULL,'Cigarette consumption'),('smoking-status-current',1,'137V.',NULL,'Smoking reduced'),('smoking-status-current',1,'137V.00',NULL,'Smoking reduced'),('smoking-status-current',1,'137Q.',NULL,'Smoking started'),('smoking-status-current',1,'137Q.00',NULL,'Smoking started');
INSERT INTO #codesreadv2
VALUES ('smoking-status-currently-not',1,'137L.',NULL,'Current non-smoker'),('smoking-status-currently-not',1,'137L.00',NULL,'Current non-smoker');
INSERT INTO #codesreadv2
VALUES ('smoking-status-ex',1,'137l.',NULL,'Ex roll-up cigarette smoker'),('smoking-status-ex',1,'137l.00',NULL,'Ex roll-up cigarette smoker'),('smoking-status-ex',1,'137j.',NULL,'Ex-cigarette smoker'),('smoking-status-ex',1,'137j.00',NULL,'Ex-cigarette smoker'),('smoking-status-ex',1,'137S.',NULL,'Ex smoker'),('smoking-status-ex',1,'137S.00',NULL,'Ex smoker'),('smoking-status-ex',1,'137O.',NULL,'Ex cigar smoker'),('smoking-status-ex',1,'137O.00',NULL,'Ex cigar smoker'),('smoking-status-ex',1,'137N.',NULL,'Ex pipe smoker'),('smoking-status-ex',1,'137N.00',NULL,'Ex pipe smoker'),('smoking-status-ex',1,'137F.',NULL,'Ex-smoker - amount unknown'),('smoking-status-ex',1,'137F.00',NULL,'Ex-smoker - amount unknown'),('smoking-status-ex',1,'137B.',NULL,'Ex-very heavy smoker (40+/day)'),('smoking-status-ex',1,'137B.00',NULL,'Ex-very heavy smoker (40+/day)'),('smoking-status-ex',1,'137A.',NULL,'Ex-heavy smoker (20-39/day)'),('smoking-status-ex',1,'137A.00',NULL,'Ex-heavy smoker (20-39/day)'),('smoking-status-ex',1,'1379.',NULL,'Ex-moderate smoker (10-19/day)'),('smoking-status-ex',1,'1379.00',NULL,'Ex-moderate smoker (10-19/day)'),('smoking-status-ex',1,'1378.',NULL,'Ex-light smoker (1-9/day)'),('smoking-status-ex',1,'1378.00',NULL,'Ex-light smoker (1-9/day)'),('smoking-status-ex',1,'137K.',NULL,'Stopped smoking'),('smoking-status-ex',1,'137K.00',NULL,'Stopped smoking'),('smoking-status-ex',1,'137K0',NULL,'Recently stopped smoking'),('smoking-status-ex',1,'137K000',NULL,'Recently stopped smoking'),('smoking-status-ex',1,'137T.',NULL,'Date ceased smoking'),('smoking-status-ex',1,'137T.00',NULL,'Date ceased smoking'),('smoking-status-ex',1,'13p4.',NULL,'Smoking free weeks'),('smoking-status-ex',1,'13p4.00',NULL,'Smoking free weeks');
INSERT INTO #codesreadv2
VALUES ('smoking-status-ex-trivial',1,'1377.',NULL,'Ex-trivial smoker (<1/day)'),('smoking-status-ex-trivial',1,'1377.00',NULL,'Ex-trivial smoker (<1/day)');
INSERT INTO #codesreadv2
VALUES ('smoking-status-never',1,'1371.',NULL,'Never smoked tobacco'),('smoking-status-never',1,'1371.00',NULL,'Never smoked tobacco');
INSERT INTO #codesreadv2
VALUES ('smoking-status-passive',1,'137I.',NULL,'Passive smoker'),('smoking-status-passive',1,'137I.00',NULL,'Passive smoker'),('smoking-status-passive',1,'137I0',NULL,'Exposed to tobacco smoke at home'),('smoking-status-passive',1,'137I000',NULL,'Exposed to tobacco smoke at home'),('smoking-status-passive',1,'13WF4',NULL,'Passive smoking risk'),('smoking-status-passive',1,'13WF400',NULL,'Passive smoking risk');
INSERT INTO #codesreadv2
VALUES ('smoking-status-trivial',1,'1372.',NULL,'Trivial smoker - < 1 cig/day'),('smoking-status-trivial',1,'1372.00',NULL,'Trivial smoker - < 1 cig/day');
INSERT INTO #codesreadv2
VALUES ('covid-vaccination',1,'65F0.',NULL,'2019-nCoV (novel coronavirus) vaccination'),('covid-vaccination',1,'65F0.00',NULL,'2019-nCoV (novel coronavirus) vaccination'),('covid-vaccination',1,'65F01',NULL,'Administration of first dose of SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccine'),('covid-vaccination',1,'65F0100',NULL,'Administration of first dose of SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccine'),('covid-vaccination',1,'65F02',NULL,'2019-nCoV (novel coronavirus) vaccination'),('covid-vaccination',1,'65F0200',NULL,'2019-nCoV (novel coronavirus) vaccination'),('covid-vaccination',1,'65F06',NULL,'SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccination'),('covid-vaccination',1,'65F0600',NULL,'SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccination'),('covid-vaccination',1,'65F07',NULL,'Immunisation course to achieve immunity against SARS-CoV-2'),('covid-vaccination',1,'65F0700',NULL,'Immunisation course to achieve immunity against SARS-CoV-2'),('covid-vaccination',1,'65F08',NULL,'Immunisation course to maintain protection against SARS-CoV-2'),('covid-vaccination',1,'65F0800',NULL,'Immunisation course to maintain protection against SARS-CoV-2'),('covid-vaccination',1,'65F09',NULL,'Administration of third dose of SARS-CoV-2 vaccine'),('covid-vaccination',1,'65F0900',NULL,'Administration of third dose of SARS-CoV-2 vaccine'),('covid-vaccination',1,'65F0A',NULL,'Administration of fourth dose of SARS-CoV-2 vaccine'),('covid-vaccination',1,'65F0A00',NULL,'Administration of fourth dose of SARS-CoV-2 vaccine'),('covid-vaccination',1,'9bJ..',NULL,'COVID-19 mRNA Vaccine BNT162b2 30micrograms/0.3ml dose concentrate for suspension for injection multidose vials (Pfizer-BioNTech)'),('covid-vaccination',1,'9bJ..00',NULL,'COVID-19 mRNA Vaccine BNT162b2 30micrograms/0.3ml dose concentrate for suspension for injection multidose vials (Pfizer-BioNTech)');
INSERT INTO #codesreadv2
VALUES ('kidney-transplant',1,'14S2.',NULL,'H/O: kidney recipient'),('kidney-transplant',1,'14S2.00',NULL,'H/O: kidney recipient'),('kidney-transplant',1,'7B00.',NULL,'Transplantation of kidney'),('kidney-transplant',1,'7B00.00',NULL,'Transplantation of kidney'),('kidney-transplant',1,'7B001',NULL,'Transplantation of kidney from live donor'),('kidney-transplant',1,'7B00100',NULL,'Transplantation of kidney from live donor'),('kidney-transplant',1,'7B002',NULL,'Transplantation of kidney from cadaver'),('kidney-transplant',1,'7B00200',NULL,'Transplantation of kidney from cadaver'),('kidney-transplant',1,'7B00y',NULL,'Other specified transplantation of kidney'),('kidney-transplant',1,'7B00y00',NULL,'Other specified transplantation of kidney'),('kidney-transplant',1,'7B00z',NULL,'Transplantation of kidney NOS'),('kidney-transplant',1,'7B00z00',NULL,'Transplantation of kidney NOS'),('kidney-transplant',1,'K0B5.',NULL,'Renal tubulo-interstitial disorders in transplant rejection'),('kidney-transplant',1,'K0B5.00',NULL,'Renal tubulo-interstitial disorders in transplant rejection'),('kidney-transplant',1,'SP080',NULL,'Transplanted organ failure'),('kidney-transplant',1,'SP08000',NULL,'Transplanted organ failure'),('kidney-transplant',1,'SP083',NULL,'Kidney transplant failure and rejection'),('kidney-transplant',1,'SP08300',NULL,'Kidney transplant failure and rejection'),('kidney-transplant',1,'TB001',NULL,'Transplantation of kidney as the cause of abnormal reaction of patient, or of later complication, without mention of misadventure at the time of operation'),('kidney-transplant',1,'TB00100',NULL,'Transplantation of kidney as the cause of abnormal reaction of patient, or of later complication, without mention of misadventure at the time of operation'),('kidney-transplant',1,'ZV420',NULL,'[V]Kidney transplanted'),('kidney-transplant',1,'ZV42000',NULL,'[V]Kidney transplanted');
INSERT INTO #codesreadv2
VALUES ('covid-positive-antigen-test',1,'43kB1',NULL,'SARS-CoV-2 antigen positive'),('covid-positive-antigen-test',1,'43kB100',NULL,'SARS-CoV-2 antigen positive');
INSERT INTO #codesreadv2
VALUES ('covid-positive-pcr-test',1,'4J3R6',NULL,'SARS-CoV-2 RNA pos lim detect'),('covid-positive-pcr-test',1,'4J3R600',NULL,'SARS-CoV-2 RNA pos lim detect'),('covid-positive-pcr-test',1,'A7952',NULL,'COVID-19 confirmed by laboratory test'),('covid-positive-pcr-test',1,'A795200',NULL,'COVID-19 confirmed by laboratory test'),('covid-positive-pcr-test',1,'43hF.',NULL,'Detection of SARS-CoV-2 by PCR'),('covid-positive-pcr-test',1,'43hF.00',NULL,'Detection of SARS-CoV-2 by PCR');
INSERT INTO #codesreadv2
VALUES ('covid-positive-test-other',1,'4J3R1',NULL,'2019-nCoV (novel coronavirus) detected'),('covid-positive-test-other',1,'4J3R100',NULL,'2019-nCoV (novel coronavirus) detected');
INSERT INTO #codesreadv2
VALUES ('egfr',1,'451E.',NULL,'Glomerular filtration rate calculated by abbreviated Modification of Diet in Renal Disease Study Group calculation'),('egfr',1,'451E.00',NULL,'Glomerular filtration rate calculated by abbreviated Modification of Diet in Renal Disease Study Group calculation'),('egfr',1,'451G.',NULL,'Glomerular filtration rate calculated by abbreviated Modification of Diet in Renal Disease Study Group calculation adjusted for African American origin'),('egfr',1,'451G.00',NULL,'Glomerular filtration rate calculated by abbreviated Modification of Diet in Renal Disease Study Group calculation adjusted for African American origin'),('egfr',1,'451K.',NULL,'Estimated glomerular filtration rate using Chronic Kidney Disease Epidemiology Collaboration formula per 1.73 square metres'),('egfr',1,'451K.00',NULL,'Estimated glomerular filtration rate using Chronic Kidney Disease Epidemiology Collaboration formula per 1.73 square metres'),('egfr',1,'451M.',NULL,'Estimated glomerular filtration rate using cystatin C Chronic Kidney Disease Epidemiology Collaboration equation per 1.73 square metres'),('egfr',1,'451M.00',NULL,'Estimated glomerular filtration rate using cystatin C Chronic Kidney Disease Epidemiology Collaboration equation per 1.73 square metres'),('egfr',1,'451N.',NULL,'Estimated glomerular filtration rate using creatinine Chronic Kidney Disease Epidemiology Collaboration equation per 1.73 square metres'),('egfr',1,'451N.00',NULL,'Estimated glomerular filtration rate using creatinine Chronic Kidney Disease Epidemiology Collaboration equation per 1.73 square metres');
INSERT INTO #codesreadv2
VALUES ('urinary-albumin-creatinine-ratio',1,'46TC.',NULL,'Urine albumin:creatinine ratio'),('urinary-albumin-creatinine-ratio',1,'46TC.00',NULL,'Urine albumin:creatinine ratio')

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
VALUES ('chronic-kidney-disease',1,'X30In',NULL,'Chronic kidney disease'),('chronic-kidney-disease',1,'XaLHG',NULL,'Chronic kidney disease stage 1'),('chronic-kidney-disease',1,'XaLHH',NULL,'Chronic kidney disease stage 2'),('chronic-kidney-disease',1,'XaLHI',NULL,'Chronic kidney disease stage 3'),('chronic-kidney-disease',1,'XaLHJ',NULL,'Chronic kidney disease stage 4'),('chronic-kidney-disease',1,'XaLHK',NULL,'Chronic kidney disease stage 5'),('chronic-kidney-disease',1,'Xac9y',NULL,'CKD G1A1 - chronic kidney disease with glomerular filtration rate category G1 and albuminuria category A1'),('chronic-kidney-disease',1,'Xac9z',NULL,'CKD G1A2 - chronic kidney disease with glomerular filtration rate category G1 and albuminuria category A2'),('chronic-kidney-disease',1,'XacA2',NULL,'CKD G1A3 - chronic kidney disease with glomerular filtration rate category G1 and albuminuria category A3'),('chronic-kidney-disease',1,'XacA4',NULL,'CKD G2A1 - chronic kidney disease with glomerular filtration rate category G2 and albuminuria category A1'),('chronic-kidney-disease',1,'XacA6',NULL,'CKD G2A2 - chronic kidney disease with glomerular filtration rate category G2 and albuminuria category A2'),('chronic-kidney-disease',1,'XacA9',NULL,'CKD G2A3 - chronic kidney disease with glomerular filtration rate category G2 and albuminuria category A3'),('chronic-kidney-disease',1,'XacAM',NULL,'CKD G3aA1 - chronic kidney disease with glomerular filtration rate category G3a and albuminuria category A1'),('chronic-kidney-disease',1,'XacAN',NULL,'CKD G3aA2 - chronic kidney disease with glomerular filtration rate category G3a and albuminuria category A2'),('chronic-kidney-disease',1,'XacAO',NULL,'CKD G3aA3 - chronic kidney disease with glomerular filtration rate category G3a and albuminuria category A3'),('chronic-kidney-disease',1,'XacAV',NULL,'CKD G3bA1 - chronic kidney disease with glomerular filtration rate category G3b and albuminuria category A1'),('chronic-kidney-disease',1,'XacAW',NULL,'CKD G3bA2 - chronic kidney disease with glomerular filtration rate category G3b and albuminuria category A2'),('chronic-kidney-disease',1,'XacAX',NULL,'CKD G3bA3 - chronic kidney disease with glomerular filtration rate category G3b and albuminuria category A3'),('chronic-kidney-disease',1,'XacAb',NULL,'CKD G4A1 - chronic kidney disease with glomerular filtration rate category G4 and albuminuria category A1'),('chronic-kidney-disease',1,'XacAd',NULL,'CKD G4A2 - chronic kidney disease with glomerular filtration rate category G4 and albuminuria category A2'),('chronic-kidney-disease',1,'XacAe',NULL,'CKD G4A3 - chronic kidney disease with glomerular filtration rate category G4 and albuminuria category A3'),('chronic-kidney-disease',1,'XacAf',NULL,'CKD G5A1 - chronic kidney disease with glomerular filtration rate category G5 and albuminuria category A1'),('chronic-kidney-disease',1,'XacAh',NULL,'CKD G5A2 - chronic kidney disease with glomerular filtration rate category G5 and albuminuria category A2'),('chronic-kidney-disease',1,'XacAi',NULL,'CKD G5A3 - chronic kidney disease with glomerular filtration rate category G5 and albuminuria category A3'),('chronic-kidney-disease',1,'XaO3p',NULL,'Chronic kidney disease stage 1 with proteinuria'),('chronic-kidney-disease',1,'XaO3s',NULL,'Chronic kidney disease stage 2 without proteinuria'),('chronic-kidney-disease',1,'XaNbn',NULL,'Chronic kidney disease stage 3A'),('chronic-kidney-disease',1,'XaNbo',NULL,'Chronic kidney disease stage 3B'),('chronic-kidney-disease',1,'XaO3t',NULL,'Chronic kidney disease stage 3 with proteinuria'),('chronic-kidney-disease',1,'XaO3u',NULL,'Chronic kidney disease stage 3 without proteinuria'),('chronic-kidney-disease',1,'XaO40',NULL,'Chronic kidney disease stage 4 without proteinuria'),('chronic-kidney-disease',1,'XaO3w',NULL,'Chronic kidney disease stage 3A without proteinuria'),('chronic-kidney-disease',1,'XaO3x',NULL,'Chronic kidney disease stage 3B with proteinuria'),('chronic-kidney-disease',1,'XaO3y',NULL,'Chronic kidney disease stage 3B without proteinuria'),('chronic-kidney-disease',1,'XaMFs',NULL,'Chronic kidney disease monitoring administration'),('chronic-kidney-disease',1,'XaMFt',NULL,'Chronic kidney disease monitoring first letter'),('chronic-kidney-disease',1,'XaMFu',NULL,'Chronic kidney disease monitoring second letter'),('chronic-kidney-disease',1,'XaMFv',NULL,'Chronic kidney disease monitoring third letter'),('chronic-kidney-disease',1,'XaMFw',NULL,'Chronic kidney disease monitoring verbal invite'),('chronic-kidney-disease',1,'XaMFx',NULL,'Chronic kidney disease monitoring telephone invite'),('chronic-kidney-disease',1,'XaMLh',NULL,'Predicted stage chronic kidney disease'),('chronic-kidney-disease',1,'X30J0',NULL,'ESCRF - End stage chronic renal failure'),('chronic-kidney-disease',1,'XaO3q',NULL,'Chronic kidney disease stage 1 without proteinuria'),('chronic-kidney-disease',1,'XaO3r',NULL,'Chronic kidney disease stage 2 with proteinuria'),('chronic-kidney-disease',1,'XaO3v',NULL,'Chronic kidney disease stage 3A with proteinuria'),('chronic-kidney-disease',1,'XaO3z',NULL,'Chronic kidney disease stage 4 with proteinuria'),('chronic-kidney-disease',1,'XaO41',NULL,'Chronic kidney disease stage 5 with proteinuria'),('chronic-kidney-disease',1,'XaO42',NULL,'Chronic kidney disease stage 5 without proteinuria');
INSERT INTO #codesctv3
VALUES ('diabetes',1,'C10..',NULL,'DM - Diabetes mellitus'),('diabetes',1,'C100.',NULL,'Diabetes mellitus with no mention of complication'),('diabetes',1,'C1000',NULL,'Diabetes mellitus, juvenile type, with no mention of complication'),('diabetes',1,'C1001',NULL,'Maturity onset diabetes'),('diabetes',1,'C100z',NULL,'Diabetes mellitus NOS with no mention of complication'),('diabetes',1,'C101.',NULL,'Diabetic ketoacidosis'),('diabetes',1,'C1010',NULL,'Diabetes mellitus, juvenile type, with ketoacidosis'),('diabetes',1,'C1011',NULL,'Diabetes mellitus, adult onset, with ketoacidosis'),('diabetes',1,'C101y',NULL,'Other specified diabetes mellitus with ketoacidosis'),('diabetes',1,'C101z',NULL,'Diabetes mellitus NOS with ketoacidosis'),('diabetes',1,'C102.',NULL,'Diabetes mellitus with hyperosmolar coma'),('diabetes',1,'C1020',NULL,'Diabetes mellitus, juvenile type, with hyperosmolar coma'),('diabetes',1,'C1021',NULL,'Diabetes mellitus, adult onset, with hyperosmolar coma'),('diabetes',1,'C102z',NULL,'Diabetes mellitus NOS with hyperosmolar coma'),('diabetes',1,'C103.',NULL,'Diabetes mellitus with ketoacidotic coma'),('diabetes',1,'C1030',NULL,'Diabetes mellitus, juvenile type, with ketoacidotic coma'),('diabetes',1,'C1031',NULL,'Diabetes mellitus, adult onset, with ketoacidotic coma'),('diabetes',1,'C103y',NULL,'Other specified diabetes mellitus with coma'),('diabetes',1,'C103z',NULL,'Diabetes mellitus NOS with ketoacidotic coma'),('diabetes',1,'C1040',NULL,'Diabetes mellitus, juvenile type, with renal manifestation'),('diabetes',1,'C1041',NULL,'Diabetes mellitus, adult onset, with renal manifestation'),('diabetes',1,'C104y',NULL,'Other specified diabetes mellitus with renal complications'),('diabetes',1,'C104z',NULL,'Diabetes mellitus with nephropathy NOS'),('diabetes',1,'C105.',NULL,'Diabetes mellitus with ophthalmic manifestation'),('diabetes',1,'C1050',NULL,'Diabetes mellitus, juvenile type, with ophthalmic manifestation'),('diabetes',1,'C1051',NULL,'Diabetes mellitus, adult onset, with ophthalmic manifestation'),('diabetes',1,'C105y',NULL,'Other specified diabetes mellitus with ophthalmic complications'),('diabetes',1,'C105z',NULL,'Diabetes mellitus NOS with ophthalmic manifestation'),('diabetes',1,'C1060',NULL,'Diabetes mellitus, juvenile type, with neurological manifestation'),('diabetes',1,'C1061',NULL,'Diabetes mellitus, adult onset, with neurological manifestation'),('diabetes',1,'C106y',NULL,'Other specified diabetes mellitus with neurological complications'),('diabetes',1,'C106z',NULL,'Diabetes mellitus NOS with neurological manifestation'),('diabetes',1,'C1070',NULL,'Diabetes mellitus, juvenile type, with peripheral circulatory disorder'),('diabetes',1,'C1071',NULL,'Diabetes mellitus, adult onset, with peripheral circulatory disorder'),('diabetes',1,'C1072',NULL,'Diabetes mellitus, adult with gangrene'),('diabetes',1,'C107y',NULL,'Other specified diabetes mellitus with peripheral circulatory complications'),('diabetes',1,'C107z',NULL,'Diabetes mellitus NOS with peripheral circulatory disorder'),('diabetes',1,'C1080',NULL,'Insulin-dependent diabetes mellitus with renal complications'),('diabetes',1,'C1081',NULL,'Insulin-dependent diabetes mellitus with ophthalmic complications'),('diabetes',1,'C1082',NULL,'Insulin-dependent diabetes mellitus with neurological complications'),('diabetes',1,'C1083',NULL,'Insulin-dependent diabetes mellitus with multiple complications'),('diabetes',1,'C1085',NULL,'Insulin-dependent diabetes mellitus with ulcer'),('diabetes',1,'C1086',NULL,'Insulin-dependent diabetes mellitus with gangrene'),('diabetes',1,'C1087',NULL,'IDDM - Insulin-dependent diabetes mellitus with retinopathy'),('diabetes',1,'C1088',NULL,'Insulin-dependent diabetes mellitus - poor control'),('diabetes',1,'C1089',NULL,'Insulin-dependent diabetes maturity onset'),('diabetes',1,'C108y',NULL,'Other specified diabetes mellitus with multiple complications'),('diabetes',1,'C108z',NULL,'Unspecified diabetes mellitus with multiple complications'),('diabetes',1,'C1090',NULL,'Non-insulin-dependent diabetes mellitus with renal complications'),('diabetes',1,'C1091',NULL,'Non-insulin-dependent diabetes mellitus with ophthalmic complications'),('diabetes',1,'C1092',NULL,'Non-insulin-dependent diabetes mellitus with neurological complications'),('diabetes',1,'C1093',NULL,'Non-insulin-dependent diabetes mellitus with multiple complications'),('diabetes',1,'C1094',NULL,'Non-insulin-dependent diabetes mellitus with ulcer'),('diabetes',1,'C1095',NULL,'Non-insulin-dependent diabetes mellitus with gangrene'),('diabetes',1,'C1096',NULL,'NIDDM - Non-insulin-dependent diabetes mellitus with retinopathy'),('diabetes',1,'C1097',NULL,'Non-insulin-dependent diabetes mellitus - poor control'),('diabetes',1,'C10A0',NULL,'Malnutrition-related diabetes mellitus with coma'),('diabetes',1,'C10A1',NULL,'Malnutrition-related diabetes mellitus with ketoacidosis'),('diabetes',1,'C10A2',NULL,'Malnutrition-related diabetes mellitus with renal complications'),('diabetes',1,'C10A3',NULL,'Malnutrition-related diabetes mellitus with ophthalmic complications'),('diabetes',1,'C10A4',NULL,'Malnutrition-related diabetes mellitus with neurological complications'),('diabetes',1,'C10A5',NULL,'Malnutrition-related diabetes mellitus with peripheral circulatory complications'),('diabetes',1,'C10A6',NULL,'Malnutrition-related diabetes mellitus with multiple complications'),('diabetes',1,'C10A7',NULL,'Malnutrition-related diabetes mellitus without complications'),('diabetes',1,'C10B0',NULL,'Steroid-induced diabetes mellitus without complication'),('diabetes',1,'C10y.',NULL,'Diabetes mellitus with other specified manifestation'),('diabetes',1,'C10y0',NULL,'Diabetes mellitus, juvenile type, with other specified manifestation'),('diabetes',1,'C10y1',NULL,'Diabetes mellitus, adult onset, with other specified manifestation'),('diabetes',1,'C10yy',NULL,'Other specified diabetes mellitus with other specified complications'),('diabetes',1,'C10yz',NULL,'Diabetes mellitus NOS with other specified manifestation'),('diabetes',1,'C10z.',NULL,'Diabetes mellitus with unspecified complication'),('diabetes',1,'C10z0',NULL,'Diabetes mellitus, juvenile type, with unspecified complication'),('diabetes',1,'C10z1',NULL,'Diabetes mellitus, adult onset, with unspecified complication'),('diabetes',1,'C10zy',NULL,'Other specified diabetes mellitus with unspecified complications'),('diabetes',1,'C10zz',NULL,'Diabetes mellitus NOS with unspecified complication'),('diabetes',1,'Cyu20',NULL,'[X]Other specified diabetes mellitus'),('diabetes',1,'Cyu21',NULL,'[X]Malnutrition-related diabetes mellitus with other specified complications'),('diabetes',1,'Cyu22',NULL,'[X]Malnutrition-related diabetes mellitus with unspecified complications'),('diabetes',1,'Cyu23',NULL,'[X]Unspecified diabetes mellitus with renal complications'),('diabetes',1,'L180.',NULL,'Diabetes mellitus during pregnancy, childbirth and the puerperium'),('diabetes',1,'L1800',NULL,'Diabetes mellitus - unspecified whether during pregnancy or the puerperium'),('diabetes',1,'L1801',NULL,'Diabetes mellitus during pregnancy - baby delivered'),('diabetes',1,'L1802',NULL,'Diabetes mellitus in the puerperium - baby delivered during current episode of care'),('diabetes',1,'L1803',NULL,'Diabetes mellitus during pregnancy - baby not yet delivered'),('diabetes',1,'L1804',NULL,'Diabetes mellitus in the puerperium - baby delivered during previous episode of care'),('diabetes',1,'L1805',NULL,'Pre-existing diabetes mellitus, insulin-dependent'),('diabetes',1,'L1806',NULL,'Pre-existing diabetes mellitus, non-insulin-dependent'),('diabetes',1,'L1807',NULL,'Pre-existing malnutrition-related diabetes mellitus'),('diabetes',1,'L1808',NULL,'Diabetes mellitus arising in pregnancy'),('diabetes',1,'L180z',NULL,'Diabetes mellitus during pregnancy, childbirth or the puerperium NOS'),('diabetes',1,'Lyu29',NULL,'[X]Pre-existing diabetes mellitus, unspecified'),('diabetes',1,'Q441.',NULL,'Neonatal diabetes mellitus'),('diabetes',1,'X40J4',NULL,'Insulin-dependent diabetes mellitus'),('diabetes',1,'X40J5',NULL,'Non-insulin-dependent diabetes mellitus'),('diabetes',1,'X40J6',NULL,'Insulin treated Type 2 diabetes mellitus'),('diabetes',1,'X40J7',NULL,'Malnutrition-related diabetes mellitus'),('diabetes',1,'X40J8',NULL,'Malnutrition-related diabetes mellitus - fibrocalculous'),('diabetes',1,'X40J9',NULL,'Malnutrition-related diabetes mellitus - protein-deficient'),('diabetes',1,'X40JA',NULL,'Secondary diabetes mellitus'),('diabetes',1,'X40JB',NULL,'Secondary pancreatic diabetes mellitus'),('diabetes',1,'X40JC',NULL,'Secondary endocrine diabetes mellitus'),('diabetes',1,'X40JE',NULL,'Reavens syndrome'),('diabetes',1,'X40JF',NULL,'Transitory neonatal diabetes mellitus'),('diabetes',1,'X40JG',NULL,'Genetic syndromes of diabetes mellitus'),('diabetes',1,'X40JI',NULL,'Maturity onset diabetes in youth type 1'),('diabetes',1,'X40JJ',NULL,'Diabetes mellitus autosomal dominant type 2'),('diabetes',1,'X40JN',NULL,'Lipodystrophy, partial, with Reiger anomaly, short stature, and insulinopenic diabetes mellitus'),('diabetes',1,'X40JQ',NULL,'Muscular atrophy, ataxia, retinitis pigmentosa, and diabetes mellitus'),('diabetes',1,'X40JV',NULL,'Hypogonadism, diabetes mellitus, alopecia ,mental retardation and electrocardiographic abnormalities'),('diabetes',1,'X40JX',NULL,'Pineal hyperplasia, insulin-resistant diabetes mellitus and somatic abnormalities'),('diabetes',1,'X40JY',NULL,'Congenital insulin-dependent diabetes mellitus with fatal secretory diarrhoea'),('diabetes',1,'X40Ja',NULL,'Abnormal metabolic state in diabetes mellitus'),('diabetes',1,'X50GO',NULL,'Soft tissue complication of diabetes mellitus'),('diabetes',1,'XE10E',NULL,'Diabetes mellitus, juvenile type, with no mention of complication'),('diabetes',1,'XE10F',NULL,'Diabetes mellitus, adult onset, with no mention of complication'),
('diabetes',1,'XE10G',NULL,'Diabetes mellitus with renal manifestation'),('diabetes',1,'XE10H',NULL,'Diabetes mellitus with neurological manifestation'),('diabetes',1,'XE10I',NULL,'Diabetes mellitus with peripheral circulatory disorder'),('diabetes',1,'XE12C',NULL,'Insulin dependent diabetes mel'),('diabetes',1,'XE15k',NULL,'Diabetes mellitus with polyneuropathy'),('diabetes',1,'XM19i',NULL,'[EDTA] Diabetes Type I (insulin dependent) associated with renal failure'),('diabetes',1,'XM19j',NULL,'[EDTA] Diabetes Type II (non-insulin-dependent) associated with renal failure'),('diabetes',1,'XM1Qx',NULL,'Diabetes mellitus with gangrene'),('diabetes',1,'XSETH',NULL,'Maturity onset diabetes mellitus in young'),('diabetes',1,'XSETK',NULL,'Drug-induced diabetes mellitus'),('diabetes',1,'XSETp',NULL,'Diabetes mellitus due to insulin receptor antibodies'),('diabetes',1,'Xa08a',NULL,'Small for gestation neonatal diabetes mellitus'),('diabetes',1,'Xa4g7',NULL,'Unstable type 1 diabetes mellitus'),('diabetes',1,'Xa9FG',NULL,'Postpancreatectomy diabetes mellitus'),('diabetes',1,'XaA6b',NULL,'Perceived control of insulin-dependent diabetes'),('diabetes',1,'XaELP',NULL,'Insulin-dependent diabetes without complication'),('diabetes',1,'XaELQ',NULL,'Non-insulin-dependent diabetes mellitus without complication'),('diabetes',1,'XaEnn',NULL,'Type I diabetes mellitus with mononeuropathy'),('diabetes',1,'XaEno',NULL,'Insulin dependent diabetes mellitus with polyneuropathy'),('diabetes',1,'XaEnp',NULL,'Type II diabetes mellitus with mononeuropathy'),('diabetes',1,'XaEnq',NULL,'Type 2 diabetes mellitus with polyneuropathy'),('diabetes',1,'XaF04',NULL,'Type 1 diabetes mellitus with nephropathy'),('diabetes',1,'XaF05',NULL,'Type 2 diabetes mellitus with nephropathy'),('diabetes',1,'XaFWG',NULL,'Type 1 diabetes mellitus with hypoglycaemic coma'),('diabetes',1,'XaFWI',NULL,'Type II diabetes mellitus with hypoglycaemic coma'),('diabetes',1,'XaFm8',NULL,'Type 1 diabetes mellitus with diabetic cataract'),('diabetes',1,'XaFmA',NULL,'Type II diabetes mellitus with diabetic cataract'),('diabetes',1,'XaFmK',NULL,'Type I diabetes mellitus with peripheral angiopathy'),('diabetes',1,'XaFmL',NULL,'Type 1 diabetes mellitus with arthropathy'),('diabetes',1,'XaFmM',NULL,'Type 1 diabetes mellitus with neuropathic arthropathy'),('diabetes',1,'XaFn7',NULL,'Non-insulin-dependent diabetes mellitus with peripheral angiopathy'),('diabetes',1,'XaFn8',NULL,'Non-insulin dependent diabetes mellitus with arthropathy'),('diabetes',1,'XaFn9',NULL,'Non-insulin dependent diabetes mellitus with neuropathic arthropathy'),('diabetes',1,'XaIrf',NULL,'Hyperosmolar non-ketotic state in type II diabetes mellitus'),('diabetes',1,'XaIyz',NULL,'Diabetes mellitus with persistent microalbuminuria'),('diabetes',1,'XaIz0',NULL,'Diabetes mellitus with persistent proteinuria'),('diabetes',1,'XaIzM',NULL,'Type 1 diabetes mellitus with persistent proteinuria'),('diabetes',1,'XaIzN',NULL,'Type 1 diabetes mellitus with persistent microalbuminuria'),('diabetes',1,'XaIzQ',NULL,'Type 2 diabetes mellitus with persistent proteinuria'),('diabetes',1,'XaIzR',NULL,'Type 2 diabetes mellitus with persistent microalbuminuria'),('diabetes',1,'XaJQp',NULL,'Type II diabetes mellitus with exudative maculopathy'),('diabetes',1,'XaJSr',NULL,'Type I diabetes mellitus with exudative maculopathy'),('diabetes',1,'XaJUI',NULL,'Diabetes mellitus induced by non-steroid drugs'),('diabetes',1,'XaJlL',NULL,'Secondary pancreatic diabetes mellitus without complication'),('diabetes',1,'XaJlM',NULL,'Diabetes mellitus induced by non-steroid drugs without complication'),('diabetes',1,'XaJlQ',NULL,'Lipoatrophic diabetes mellitus without complication'),('diabetes',1,'XaJlR',NULL,'Secondary diabetes mellitus without complication'),('diabetes',1,'XaKyW',NULL,'Type I diabetes mellitus with gastroparesis'),('diabetes',1,'XaKyX',NULL,'Type II diabetes mellitus with gastroparesis'),('diabetes',1,'XaMzI',NULL,'Cystic fibrosis related diabetes mellitus'),('diabetes',1,'XaOPt',NULL,'Maternally inherited diabetes mellitus'),('diabetes',1,'XaOPu',NULL,'Latent autoimmune diabetes mellitus in adult'),('diabetes',1,'XacoB',NULL,'Maturity onset diabetes of the young type 5'),('diabetes',1,'XaIfG',NULL,'Type II diabetes on insulin'),('diabetes',1,'XaIfI',NULL,'Type II diabetes on diet only');
INSERT INTO #codesctv3
VALUES ('glomerulonephritis',1,'Xa1uD',NULL,'Glomerulonephritis'),('glomerulonephritis',1,'XE0dY',NULL,'Acute glomerulonephritis'),('glomerulonephritis',1,'K00z.',NULL,'Acute glomerulonephritis NOS'),('glomerulonephritis',1,'K001.',NULL,'Acute nephritis with lesions of necrotising glomerulitis'),('glomerulonephritis',1,'K000.',NULL,'Acute proliferative glomerulonephritis'),('glomerulonephritis',1,'X30IG',NULL,'Crescentic glomerulonephritis'),('glomerulonephritis',1,'Xa33d',NULL,'[EDTA] Crescentric glomerulonephritis (type I,II,III) associated with renal failure'),('glomerulonephritis',1,'X30I9',NULL,'Endocapillary glomerulonephritis'),('glomerulonephritis',1,'X30IA',NULL,'Idiopathic endocapillary glomerulonephritis'),('glomerulonephritis',1,'X30IB',NULL,'Post-infectious glomerulonephritis'),('glomerulonephritis',1,'X30ID',NULL,'Post-infectious glomerulonephritis - Garland variety'),('glomerulonephritis',1,'X30IC',NULL,'Post-streptococcal glomerulonephritis'),('glomerulonephritis',1,'X30IE',NULL,'Shunt nephritis'),('glomerulonephritis',1,'X30IF',NULL,'Necrotising glomerulonephritis'),('glomerulonephritis',1,'K00y.',NULL,'Other acute glomerulonephritis'),('glomerulonephritis',1,'K00y3',NULL,'Acute diffuse nephritis'),('glomerulonephritis',1,'K00y1',NULL,'Acute exudative nephritis'),('glomerulonephritis',1,'K00y2',NULL,'Acute focal nephritis'),('glomerulonephritis',1,'K00y0',NULL,'Acute glomerulonephritis in diseases EC'),('glomerulonephritis',1,'K00yz',NULL,'Other acute glomerulonephritis NOS'),('glomerulonephritis',1,'XE0db',NULL,'Chronic glomerulonephritis'),('glomerulonephritis',1,'XM1AL',NULL,'[EDTA] Glomerulonephritis, histologically examined (otherwise specified) associated with renal failure'),('glomerulonephritis',1,'XM1AM',NULL,'[EDTA] Glomerulonephritis, histologically not examined associated with renal failure'),('glomerulonephritis',1,'K000.',NULL,'PGN - Acute proliferative glomerulonephritis'),('glomerulonephritis',1,'X30I9',NULL,'Endocapillary glomerulonephritis'),('glomerulonephritis',1,'X30IF',NULL,'Necrotising glomerulonephritis'),('glomerulonephritis',1,'X30IG',NULL,'CGN - Crescentic glomerulonephritis'),('glomerulonephritis',1,'XE0dY',NULL,'AGN - Acute glomerulonephritis'),('glomerulonephritis',1,'X30IA',NULL,'Idiopathic endocapillary glomerulonephritis'),('glomerulonephritis',1,'X30IB',NULL,'Post-infectious glomerulonephritis'),('glomerulonephritis',1,'Xa33d',NULL,'[EDTA] Crescentric glomerulonephritis (type I,II,III) associated with renal failure'),('glomerulonephritis',1,'K00y.',NULL,'Other acute glomerulonephritis'),('glomerulonephritis',1,'K00z.',NULL,'Acute glomerulonephritis NOS'),('glomerulonephritis',1,'Xa1uD',NULL,'Glomerulonephritis'),('glomerulonephritis',1,'X30IC',NULL,'Post-streptococcal glomerulonephritis'),('glomerulonephritis',1,'X30ID',NULL,'Post-infectious glomerulonephritis - Garland variety'),('glomerulonephritis',1,'K00y0',NULL,'Acute glomerulonephritis in diseases EC'),('glomerulonephritis',1,'K00yz',NULL,'Other acute glomerulonephritis NOS'),('glomerulonephritis',1,'XE0db',NULL,'CGN - Chronic glomerulonephritis'),('glomerulonephritis',1,'XM1AL',NULL,'[EDTA] Glomerulonephritis, histologically examined (otherwise specified) associated with renal failure'),('glomerulonephritis',1,'XM1AM',NULL,'[EDTA] Glomerulonephritis, histologically not examined associated with renal failure'),('glomerulonephritis',1,'K020.',NULL,'Chronic nephritic syndrome, diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'K021.',NULL,'Chronic nephritic syndrome, diffuse membranous glomerulonephritis'),('glomerulonephritis',1,'K023.',NULL,'Chronic rapidly progressive glomerulonephritis'),('glomerulonephritis',1,'K02y.',NULL,'Other chronic glomerulonephritis'),('glomerulonephritis',1,'K02y2',NULL,'Chronic focal glomerulonephritis'),('glomerulonephritis',1,'K02y3',NULL,'Chronic diffuse glomerulonephritis'),('glomerulonephritis',1,'K02yz',NULL,'Other chronic glomerulonephritis NOS'),('glomerulonephritis',1,'K02z.',NULL,'Chronic glomerulonephritis NOS'),('glomerulonephritis',1,'K0A34',NULL,'Chronic nephritic syndrome, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A35',NULL,'Chronic nephritic syndrome, diffuse mesangiocapillary glomerulonephritis'),('glomerulonephritis',1,'K0A37',NULL,'Chronic nephritic syndrome, diffuse crescentic glomerulonephritis'),('glomerulonephritis',1,'X30Ie',NULL,'GN - Hereditary glomerulonephritis'),('glomerulonephritis',1,'Xa9CC',NULL,'Minimal change glomerulonephritis'),('glomerulonephritis',1,'K02..',NULL,'Chronic glomerulonephritis'),('glomerulonephritis',1,'K022.',NULL,'Membranoproliferative glomerulonephritis'),('glomerulonephritis',1,'X30IW',NULL,'Mesangial IgM proliferative glomerulonephritis'),('glomerulonephritis',1,'X30IY',NULL,'Membranous glomerulonephritis - stage I'),('glomerulonephritis',1,'X30IZ',NULL,'MGN stage II - Membranous glomerulonephritis - stage II'),('glomerulonephritis',1,'X30Ia',NULL,'MGN stage III - Membranous glomerulonephritis stage III'),('glomerulonephritis',1,'X30Ib',NULL,'MGN stage IV - Membranous glomerulonephritis stage IV'),('glomerulonephritis',1,'X30Ic',NULL,'MGN stage V - Membranous glomerulonephritis stage V'),('glomerulonephritis',1,'K02y0',NULL,'Chronic glomerulonephritis with diseases EC'),('glomerulonephritis',1,'K02y1',NULL,'Chronic exudative glomerulonephritis'),('glomerulonephritis',1,'K0325',NULL,'Other familial glomerulonephritis'),('glomerulonephritis',1,'X30Ih',NULL,'Non-progressive hereditary glomerulonephritis'),('glomerulonephritis',1,'X30IH',NULL,'Steroid-sensitive minimal change glomerulonephritis'),('glomerulonephritis',1,'X30II',NULL,'Steroid-resistant minimal change glomerulonephritis'),('glomerulonephritis',1,'X30IJ',NULL,'Steroid-dependent minimal change glomerulonephritis'),('glomerulonephritis',1,'K0320',NULL,'Focal membranoproliferative glomerulonephritis'),('glomerulonephritis',1,'X30IR',NULL,'Mesangiocapillary glomerulonephritis NEC'),('glomerulonephritis',1,'X30IS',NULL,'Mesangiocapillary glomerulonephritis type I'),('glomerulonephritis',1,'X30IT',NULL,'Mesangiocapillary glomerulonephritis type II'),('glomerulonephritis',1,'X30IU',NULL,'MCGN type III - Mesangiocapillary glomerulonephritis type III'),('glomerulonephritis',1,'X30IV',NULL,'Mesangiocapillary glomerulonephritis type IV'),('glomerulonephritis',1,'XM19Y',NULL,'[EDTA] Membrano-proliferative glomerulonephritis,type I (proven immunofluorescence / electron microscopy-excluding lupus erythematosus+other specified multi-system disease) associated renal failure'),('glomerulonephritis',1,'XM19Z',NULL,'[EDTA] Dense deposit disease, membrano-proliferative glomerulonephritis, type II, (proven by immunofluorescence and/or electronic microscopy) associated with renal failure'),('glomerulonephritis',1,'K032y',NULL,'Mesangiocapillary glomerulonephritis NEC'),('glomerulonephritis',1,'K032z',NULL,'Nephritis unspecified with lesion of membranoproliferative glomerulonephritis NOS'),('glomerulonephritis',1,'K0A02',NULL,'Acute nephritic syndrome, diffuse membranous glomerulonephritis'),('glomerulonephritis',1,'K0A03',NULL,'Acute nephritic syndrome, diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A04',NULL,'Acute nephritic syndrome, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A05',NULL,'Acute nephritic syndrome, diffuse mesangiocapillary glomerulonephritis'),('glomerulonephritis',1,'X30I8',NULL,'Rapidly progressive glomerulonephritis'),('glomerulonephritis',1,'XE0de',NULL,'Nephritis unspecified with other specified lesion of membranoproliferative glomerulonephritis'),('glomerulonephritis',1,'X30I3',NULL,'Mixed membranous and proliferative glomerulonephritis NEC'),('glomerulonephritis',1,'X30I4',NULL,'Mesangioproliferative glomerulonephritis NEC'),('glomerulonephritis',1,'X30I5',NULL,'Lobular glomerulonephritis NEC'),('glomerulonephritis',1,'X30I6',NULL,'Hypocomplementaemic persistent glomerulonephritis NEC'),('glomerulonephritis',1,'K0A12',NULL,'Rapidly progressive nephritic syndrome, diffuse membranous glomerulonephritis'),('glomerulonephritis',1,'K0A13',NULL,'Rapidly progressive nephritic syndrome, diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A14',NULL,'Rapidly progressive nephritic syndrome, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A15',NULL,'Rapidly progressive nephritic syndrome, diffuse mesangiocapillary glomerulonephritis'),('glomerulonephritis',1,'K0A17',NULL,'Rapidly progressive nephritic syndrome, diffuse crescentic glomerulonephritis'),('glomerulonephritis',1,'K010.',NULL,'Nephrotic syndrome with proliferative glomerulonephritis'),('glomerulonephritis',1,'K011.',NULL,'Nephrotic syndrome with membranous glomerulonephritis'),('glomerulonephritis',1,'K012.',NULL,'Nephrotic syndrome with membranoproliferative glomerulonephritis'),('glomerulonephritis',1,'K013.',NULL,'Nephrotic syndrome with minimal change glomerulonephritis'),('glomerulonephritis',1,'K016.',NULL,'Nephrotic syndrome, diffuse membranous glomerulonephritis'),('glomerulonephritis',1,'K017.',NULL,'Nephrotic syndrome, diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'K018.',NULL,'Nephrotic syndrome, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'K019.',NULL,'Nephrotic syndrome, diffuse mesangiocapillary glomerulonephritis'),('glomerulonephritis',1,'K01B.',NULL,'Nephrotic syndrome, diffuse crescentic glomerulonephritis'),('glomerulonephritis',1,'K0A07',NULL,'Acute nephritic syndrome, diffuse crescentic glomerulonephritis'),('glomerulonephritis',1,'XE0dZ',NULL,'Nephrotic syndrome with minimal change glomerulonephritis'),('glomerulonephritis',1,'K0A22',NULL,'Recurrent and persistent haematuria, diffuse membranous glomerulonephritis'),('glomerulonephritis',1,'K0A23',NULL,'Recurrent and persistent haematuria, diffuse mesangial proliferative glomerulonephritis'),
('glomerulonephritis',1,'K0A24',NULL,'Recurrent and persistent haematuria, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A25',NULL,'Recurrent and persistent haematuria, diffuse mesangiocapillary glomerulonephritis'),('glomerulonephritis',1,'K0A27',NULL,'Recurrent and persistent haematuria, diffuse crescentic glomerulonephritis'),('glomerulonephritis',1,'K0A42',NULL,'Isolated proteinuria with specified morphological lesion, diffuse membranous glomerulonephritis'),('glomerulonephritis',1,'K0A43',NULL,'Isolated proteinuria with specified morphological lesion, diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A44',NULL,'Isolated proteinuria with specified morphological lesion, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A45',NULL,'Isolated proteinuria with specified morphological lesion, diffuse mesangiocapillary glomerulonephritis'),('glomerulonephritis',1,'K0A47',NULL,'Isolated proteinuria with specified morphological lesion, diffuse concentric glomerulonephritis'),('glomerulonephritis',1,'K0A52',NULL,'Hereditary nephropathy, not elsewhere classified, diffuse membranous glomerulonephritis'),('glomerulonephritis',1,'K0A53',NULL,'Hereditary nephropathy, not elsewhere classified, diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A54',NULL,'Hereditary nephropathy, not elsewhere classified, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'K0A55',NULL,'Hereditary nephropathy, not elsewhere classified, diffuse mesangiocapillary glomerulonephritis'),('glomerulonephritis',1,'K0A57',NULL,'Hereditary nephropathy, not elsewhere classified, diffuse crescentic glomerulonephritis'),('glomerulonephritis',1,'Kyu09',NULL,'[X]Unspecified nephritic syndrome, diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'Kyu0A',NULL,'[X]Unspecified nephritic syndrome, diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'Kyu0C',NULL,'[X]Unspecified nephritic syndrome, diffuse concentric glomerulonephritis'),('glomerulonephritis',1,'K0322',NULL,'Focal glomerulonephritis with focal recurrent macroscopic glomerulonephritis'),('glomerulonephritis',1,'K0323',NULL,'Anaphylactoid glomerulonephritis'),('glomerulonephritis',1,'X30Kw',NULL,'Cryoglobulinaemic glomerulonephritis'),('glomerulonephritis',1,'Xa33h',NULL,'[EDTA] Cryoglobulineme glomerulonephritis associated with renal failure'),('glomerulonephritis',1,'X30Mf',NULL,'De novo glomerulonephritis'),('glomerulonephritis',1,'X30Mj',NULL,'CMV - Cytomegalovirus-induced glomerulonephritis'),('glomerulonephritis',1,'K03z.',NULL,'Unspecified glomerulonephritis NOS'),('glomerulonephritis',1,'X30L1',NULL,'Malignancy-associated glomerulonephritis'),('glomerulonephritis',1,'X705a',NULL,'Primary pauci-immune necrotising and crescentic glomerulonephritis'),('glomerulonephritis',1,'K01x4',NULL,'Lupus nephritis'),('glomerulonephritis',1,'X30IQ',NULL,'IgAN - IgA nephropathy'),('glomerulonephritis',1,'K031.',NULL,'Membranous nephritis unspecified'),('glomerulonephritis',1,'K01x4',NULL,'(Nephrotic syndrome in systemic lupus erythematosus) or (lupus nephritis)'),('glomerulonephritis',1,'G7520',NULL,'Goodpastures syndrome'),('glomerulonephritis',1,'K01x4',NULL,'Nephrotic syndrome in systemic lupus erythematosus'),('glomerulonephritis',1,'K033.',NULL,'Rapidly progressive nephritis unspecified'),('glomerulonephritis',1,'X30Kr',NULL,'Lupus nephritis - WHO Class V'),('glomerulonephritis',1,'PKy90',NULL,'Alports syndrome'),('glomerulonephritis',1,'XE0dd',NULL,'Primary IgA nephropathy'),('glomerulonephritis',1,'X30Kp',NULL,'Lupus nephritis - WHO Class III'),('glomerulonephritis',1,'X30Kq',NULL,'Lupus nephritis - WHO Class IV'),('glomerulonephritis',1,'X30IQ',NULL,'IgA nephropathy'),('glomerulonephritis',1,'XE0da',NULL,'Lupus nephritis'),('glomerulonephritis',1,'XE0dd',NULL,'Bergers disease');
INSERT INTO #codesctv3
VALUES ('hypertension',1,'G24..',NULL,'Secondary hypertension'),('hypertension',1,'G240.',NULL,'Malignant secondary hypertension'),('hypertension',1,'G241.',NULL,'Secondary benign hypertension'),('hypertension',1,'G244.',NULL,'Hypertension secondary to endocrine disorders'),('hypertension',1,'G24z.',NULL,'Secondary hypertension NOS'),('hypertension',1,'Gyu20',NULL,'[X]Other secondary hypertension'),('hypertension',1,'Gyu21',NULL,'[X]Hypertension secondary to other renal disorders'),('hypertension',1,'Xa0kX',NULL,'Hypertension due to renovascular disease'),('hypertension',1,'XE0Ub',NULL,'Systemic arterial hypertension'),('hypertension',1,'G2400',NULL,'Secondary malignant renovascular hypertension'),('hypertension',1,'G240z',NULL,'Secondary malignant hypertension NOS'),('hypertension',1,'G2410',NULL,'Secondary benign renovascular hypertension'),('hypertension',1,'G241z',NULL,'Secondary benign hypertension NOS'),('hypertension',1,'G24z0',NULL,'Secondary renovascular hypertension NOS'),('hypertension',1,'G20..',NULL,'Primary hypertension'),('hypertension',1,'G202.',NULL,'Systolic hypertension'),('hypertension',1,'G20z.',NULL,'Essential hypertension NOS'),('hypertension',1,'XE0Uc',NULL,'Primary hypertension'),('hypertension',1,'XE0W8',NULL,'Hypertension'),('hypertension',1,'XSDSb',NULL,'Diastolic hypertension'),('hypertension',1,'Xa0Cs',NULL,'Labile hypertension'),('hypertension',1,'Xa3fQ',NULL,'Malignant hypertension'),('hypertension',1,'XaZWm',NULL,'Stage 1 hypertension'),('hypertension',1,'XaZWn',NULL,'Severe hypertension'),('hypertension',1,'XaZbz',NULL,'Stage 2 hypertension (NICE - National Institute for Health and Clinical Excellence 2011)'),('hypertension',1,'XaZzo',NULL,'Nocturnal hypertension'),('hypertension',1,'G2...',NULL,'Hypertensive disease'),('hypertension',1,'G200.',NULL,'Malignant essential hypertension'),('hypertension',1,'G201.',NULL,'Benign essential hypertension'),('hypertension',1,'XE0Ud',NULL,'Essential hypertension NOS'),('hypertension',1,'Xa41E',NULL,'Maternal hypertension'),('hypertension',1,'Xab9L',NULL,'Stage 1 hypertension (NICE 2011) without evidence of end organ damage'),('hypertension',1,'Xab9M',NULL,'Stage 1 hypertension (NICE 2011) with evidence of end organ damage'),('hypertension',1,'G2y..',NULL,'Other specified hypertensive disease'),('hypertension',1,'G2z..',NULL,'Hypertensive disease NOS'),('hypertension',1,'Gyu2.',NULL,'[X]Hypertensive diseases'),('hypertension',1,'XM19D',NULL,'[EDTA] Renal vascular disease due to hypertension (no primary renal disease) associated with renal failure'),('hypertension',1,'XM19E',NULL,'[EDTA] Renal vascular disease due to malignant hypertension (no primary renal disease) associated with renal failure');
INSERT INTO #codesctv3
VALUES ('kidney-stones',1,'XE0dk',NULL,'Calculus of kidney'),('kidney-stones',1,'X30Pp',NULL,'Calculus in calyceal diverticulum'),('kidney-stones',1,'X30Pr',NULL,'Calculus in pelviureteric junction'),('kidney-stones',1,'X30Pq',NULL,'Calculus in renal pelvis'),('kidney-stones',1,'X30Po',NULL,'Calyceal renal calculus'),('kidney-stones',1,'XE0fN',NULL,'Kidney calculus (& [staghorn])'),('kidney-stones',1,'K120z',NULL,'Renal calculus NOS'),('kidney-stones',1,'K1200',NULL,'Staghorn calculus'),('kidney-stones',1,'XM14o',NULL,'Uric acid renal calculus'),('kidney-stones',1,'4G4..',NULL,'O/E: renal calculus'),('kidney-stones',1,'4G42.',NULL,'Phosphate kidney stone &/or [O/E: staghorn]'),('kidney-stones',1,'4G4Z.',NULL,'O/E: renal stone NOS'),('kidney-stones',1,'C3411',NULL,'(Uric acid nephrolithiasis) or (renal stone - uric acid)'),('kidney-stones',1,'K12..',NULL,'Urinary calculus (& [kidney &/or ureter)'),('kidney-stones',1,'K120.',NULL,'(Calculus of kidney) or (nephrolithiasis NOS)'),('kidney-stones',1,'PD31.',NULL,'Congenital calculus of kidney'),('kidney-stones',1,'X30Pn',NULL,'Nephrolithiasis NOS'),('kidney-stones',1,'XE0dj',NULL,'Calculus of kidney and ureter'),('kidney-stones',1,'XM1XM',NULL,'Phosphate kidney stone');
INSERT INTO #codesctv3
VALUES ('vasculitis',1,'C3321',NULL,'Cryoglobulinaemic vasculitis'),('vasculitis',1,'X205F',NULL,'Secondary systemic vasculitis'),('vasculitis',1,'X205G',NULL,'Vasculitis secondary to drug'),('vasculitis',1,'X701l',NULL,'Rheumatoid vasculitis'),('vasculitis',1,'X705w',NULL,'Lupus vasculitis'),('vasculitis',1,'X205D',NULL,'Systemic vasculitis'),('vasculitis',1,'X705t',NULL,'Nailfold rheumatoid vasculitis'),('vasculitis',1,'X705u',NULL,'Systemic rheumatoid vasculitis'),('vasculitis',1,'X705v',NULL,'Necrotising rheumatoid vasculitis'),('vasculitis',1,'G76B.',NULL,'Vasculitis'),('vasculitis',1,'X7061',NULL,'Essential cryoglobulinaemic vasculitis'),('vasculitis',1,'X50BC',NULL,'Primary cutaneous vasculitis'),('vasculitis',1,'X50BG',NULL,'Gougerot-Ruiter vasculitis'),('vasculitis',1,'X705x',NULL,'Hypocomplementaemic vasculitis'),('vasculitis',1,'X50BI',NULL,'Secondary cutaneous vasculitis'),('vasculitis',1,'Myu7A',NULL,'[X]Other vasculitis limited to the skin'),('vasculitis',1,'Myu7G',NULL,'[X]Vasculitis limited to skin, unspecified'),('vasculitis',1,'X50BK',NULL,'Nodular vasculitis'),('vasculitis',1,'X00Dw',NULL,'Cerebral arteritis in systemic vasculitis'),('vasculitis',1,'X00Dz',NULL,'Primary central nervous system granulomatous vasculitis'),('vasculitis',1,'X705i',NULL,'Churg-Strauss vasculitis'),('vasculitis',1,'F421E',NULL,'Retinal vasculitis NOS'),('vasculitis',1,'X00dO',NULL,'Retinal vasculitis'),('vasculitis',1,'X309p',NULL,'Peritoneal vasculitis'),('vasculitis',1,'XaXlI',NULL,'H/O vasculitis'),('vasculitis',1,'D310.',NULL,'Allergic purpura'),('vasculitis',1,'D3100',NULL,'Acute vascular purpura'),('vasculitis',1,'F371.',NULL,'Neuropathy in vasculitis and connective tissue disease'),('vasculitis',1,'G750.',NULL,'(Polyarteritis nodosa) or (necrotising angiitis)'),('vasculitis',1,'G750.',NULL,'Polyarteritis nodosa'),('vasculitis',1,'G752.',NULL,'Hypersensitivity: [angiitis] or [arteritis]'),('vasculitis',1,'G752z',NULL,'Hypersensitivity angiitis NOS'),('vasculitis',1,'X203B',NULL,'Post-arteritic pulmonary hypertension'),('vasculitis',1,'XE0VV',NULL,'Hypersensitivity angiitis');
INSERT INTO #codesctv3
VALUES ('alcohol-light-drinker',1,'1362.00',NULL,'Trivial drinker - <1u/day');
INSERT INTO #codesctv3
VALUES ('alcohol-non-drinker',1,'1361.',NULL,'Teetotaller'),('alcohol-non-drinker',1,'136M.',NULL,'Current non-drinker');
INSERT INTO #codesctv3
VALUES ('bmi',2,'22K..',NULL,'Body Mass Index');
INSERT INTO #codesctv3
VALUES ('smoking-status-current',1,'1373.',NULL,'Lt cigaret smok, 1-9 cigs/day'),('smoking-status-current',1,'1374.',NULL,'Mod cigaret smok, 10-19 cigs/d'),('smoking-status-current',1,'1375.',NULL,'Hvy cigaret smok, 20-39 cigs/d'),('smoking-status-current',1,'1376.',NULL,'Very hvy cigs smoker,40+cigs/d'),('smoking-status-current',1,'137C.',NULL,'Keeps trying to stop smoking'),('smoking-status-current',1,'137D.',NULL,'Admitted tobacco cons untrue ?'),('smoking-status-current',1,'137G.',NULL,'Trying to give up smoking'),('smoking-status-current',1,'137H.',NULL,'Pipe smoker'),('smoking-status-current',1,'137J.',NULL,'Cigar smoker'),('smoking-status-current',1,'137M.',NULL,'Rolls own cigarettes'),('smoking-status-current',1,'137P.',NULL,'Cigarette smoker'),('smoking-status-current',1,'137Q.',NULL,'Smoking started'),('smoking-status-current',1,'137R.',NULL,'Current smoker'),('smoking-status-current',1,'137Z.',NULL,'Tobacco consumption NOS'),('smoking-status-current',1,'Ub1tI',NULL,'Cigarette consumption'),('smoking-status-current',1,'Ub1tJ',NULL,'Cigar consumption'),('smoking-status-current',1,'Ub1tK',NULL,'Pipe tobacco consumption'),('smoking-status-current',1,'XaBSp',NULL,'Smoking restarted'),('smoking-status-current',1,'XaIIu',NULL,'Smoking reduced'),('smoking-status-current',1,'XaIkW',NULL,'Thinking about stop smoking'),('smoking-status-current',1,'XaIkX',NULL,'Ready to stop smoking'),('smoking-status-current',1,'XaIkY',NULL,'Not interested stop smoking'),('smoking-status-current',1,'XaItg',NULL,'Reason for restarting smoking'),('smoking-status-current',1,'XaIuQ',NULL,'Cigarette pack-years'),('smoking-status-current',1,'XaJX2',NULL,'Min from wake to 1st tobac con'),('smoking-status-current',1,'XaWNE',NULL,'Failed attempt to stop smoking'),('smoking-status-current',1,'XaZIE',NULL,'Waterpipe tobacco consumption'),('smoking-status-current',1,'XE0og',NULL,'Tobacco smoking consumption'),('smoking-status-current',1,'XE0oq',NULL,'Cigarette smoker'),('smoking-status-current',1,'XE0or',NULL,'Smoking started');
INSERT INTO #codesctv3
VALUES ('smoking-status-currently-not',1,'Ub0oq',NULL,'Non-smoker'),('smoking-status-currently-not',1,'137L.',NULL,'Current non-smoker');
INSERT INTO #codesctv3
VALUES ('smoking-status-ex',1,'1378.',NULL,'Ex-light smoker (1-9/day)'),('smoking-status-ex',1,'1379.',NULL,'Ex-moderate smoker (10-19/day)'),('smoking-status-ex',1,'137A.',NULL,'Ex-heavy smoker (20-39/day)'),('smoking-status-ex',1,'137B.',NULL,'Ex-very heavy smoker (40+/day)'),('smoking-status-ex',1,'137F.',NULL,'Ex-smoker - amount unknown'),('smoking-status-ex',1,'137K.',NULL,'Stopped smoking'),('smoking-status-ex',1,'137N.',NULL,'Ex-pipe smoker'),('smoking-status-ex',1,'137O.',NULL,'Ex-cigar smoker'),('smoking-status-ex',1,'137T.',NULL,'Date ceased smoking'),('smoking-status-ex',1,'Ub1na',NULL,'Ex-smoker'),('smoking-status-ex',1,'Xa1bv',NULL,'Ex-cigarette smoker'),('smoking-status-ex',1,'XaIr7',NULL,'Smoking free weeks'),('smoking-status-ex',1,'XaKlS',NULL,'[V]PH of tobacco abuse'),('smoking-status-ex',1,'XaQ8V',NULL,'Ex roll-up cigarette smoker'),('smoking-status-ex',1,'XaQzw',NULL,'Recently stopped smoking'),('smoking-status-ex',1,'XE0ok',NULL,'Ex-light cigaret smok, 1-9/day'),('smoking-status-ex',1,'XE0ol',NULL,'Ex-mod cigaret smok, 10-19/day'),('smoking-status-ex',1,'XE0om',NULL,'Ex-heav cigaret smok,20-39/day'),('smoking-status-ex',1,'XE0on',NULL,'Ex-very hv cigaret smk,40+/day');
INSERT INTO #codesctv3
VALUES ('smoking-status-ex-trivial',1,'XE0oj',NULL,'Ex-triv cigaret smoker, <1/day'),('smoking-status-ex-trivial',1,'1377.',NULL,'Ex-trivial smoker (<1/day)');
INSERT INTO #codesctv3
VALUES ('smoking-status-never',1,'XE0oh',NULL,'Never smoked tobacco'),('smoking-status-never',1,'1371.',NULL,'Never smoked tobacco');
INSERT INTO #codesctv3
VALUES ('smoking-status-passive',1,'137I.',NULL,'Passive smoker'),('smoking-status-passive',1,'Ub0pe',NULL,'Exposed to tobacco smoke at work'),('smoking-status-passive',1,'Ub0pf',NULL,'Exposed to tobacco smoke at home'),('smoking-status-passive',1,'Ub0pg',NULL,'Exposed to tobacco smoke in public places'),('smoking-status-passive',1,'13WF4',NULL,'Passive smoking risk');
INSERT INTO #codesctv3
VALUES ('smoking-status-trivial',1,'XagO3',NULL,'Occasional tobacco smoker'),('smoking-status-trivial',1,'XE0oi',NULL,'Triv cigaret smok, < 1 cig/day'),('smoking-status-trivial',1,'1372.',NULL,'Trivial smoker - < 1 cig/day');
INSERT INTO #codesctv3
VALUES ('covid-vaccination',1,'Y210d',NULL,'2019-nCoV (novel coronavirus) vaccination'),('covid-vaccination',1,'Y29e7',NULL,'Administration of first dose of SARS-CoV-2 vaccine'),('covid-vaccination',1,'Y29e8',NULL,'Administration of second dose of SARS-CoV-2 vaccine'),('covid-vaccination',1,'Y2a0e',NULL,'SARS-2 Coronavirus vaccine'),('covid-vaccination',1,'Y2a0f',NULL,'COVID-19 mRNA Vaccine BNT162b2 30micrograms/0.3ml dose concentrate for suspension for injection multidose vials (Pfizer-BioNTech) part 1'),('covid-vaccination',1,'Y2a3a',NULL,'COVID-19 mRNA Vaccine BNT162b2 30micrograms/0.3ml dose concentrate for suspension for injection multidose vials (Pfizer-BioNTech) part 2'),('covid-vaccination',1,'65F06',NULL,'SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccination'),('covid-vaccination',1,'65F09',NULL,'Administration of third dose of SARS-CoV-2 vaccine'),('covid-vaccination',1,'65F0A',NULL,'Administration of fourth dose of SARS-CoV-2 vaccine'),('covid-vaccination',1,'9bJ..',NULL,'COVID-19 mRNA Vaccine BNT162b2 30micrograms/0.3ml dose concentrate for suspension for injection multidose vials (Pfizer-BioNTech)'),('covid-vaccination',1,'Y2a10',NULL,'COVID-19 Vac AstraZeneca (ChAdOx1 S recomb) 5x10000000000 viral particles/0.5ml dose sol for inj MDV part 1'),('covid-vaccination',1,'Y2a39',NULL,'COVID-19 Vac AstraZeneca (ChAdOx1 S recomb) 5x10000000000 viral particles/0.5ml dose sol for inj MDV part 2'),('covid-vaccination',1,'Y2b9d',NULL,'COVID-19 mRNA (nucleoside modified) Vaccine Moderna 0.1mg/0.5mL dose dispersion for injection multidose vials part 2'),('covid-vaccination',1,'Y2f45',NULL,'Administration of third dose of SARS-CoV-2 vaccine'),('covid-vaccination',1,'Y2f48',NULL,'Administration of fourth dose of SARS-CoV-2 vaccine'),('covid-vaccination',1,'Y2f57',NULL,'COVID-19 mRNA Vaccine BNT162b2 30micrograms/0.3ml dose concentrate for suspension for injection multidose vials (Pfizer-BioNTech) booster'),('covid-vaccination',1,'Y31cc',NULL,'SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antigen vaccination'),('covid-vaccination',1,'Y31e6',NULL,'Administration of SARS-CoV-2 mRNA vaccine'),('covid-vaccination',1,'Y31e7',NULL,'Administration of first dose of SARS-CoV-2 mRNA vaccine'),('covid-vaccination',1,'Y31e8',NULL,'Administration of second dose of SARS-CoV-2 mRNA vaccine');
INSERT INTO #codesctv3
VALUES ('kidney-transplant',1,'14S2.',NULL,'H/O: kidney recipient'),('kidney-transplant',1,'7B00.',NULL,'Renal transplant'),('kidney-transplant',1,'7B001',NULL,'Live donor renal transplant'),('kidney-transplant',1,'7B002',NULL,'Cadaveric renal transplant'),('kidney-transplant',1,'7B00y',NULL,'Other specified transplantation of kidney'),('kidney-transplant',1,'7B00z',NULL,'Transplantation of kidney NOS'),('kidney-transplant',1,'K0B5.',NULL,'Renal tubulo-interstitial disorders in transplant rejection'),('kidney-transplant',1,'SP080',NULL,'(Transpl organ fail) or (deterior ren func aft ren transpl)'),('kidney-transplant',1,'SP083',NULL,'Kidney transplant failure and rejection'),('kidney-transplant',1,'TB001',NULL,'Kidney transplant with complication, without blame'),('kidney-transplant',1,'X30D2',NULL,'Xenograft renal transplant'),('kidney-transplant',1,'X30J3',NULL,'End stage renal failure with renal transplant'),('kidney-transplant',1,'X30Ma',NULL,'Chronic rejection of renal transplant - grade III'),('kidney-transplant',1,'X30Mb',NULL,'Acute-on-chronic rejection of renal transplant'),('kidney-transplant',1,'X30Mc',NULL,'Failed renal transplant'),('kidney-transplant',1,'X30Md',NULL,'Perfusion injury of renal transplant'),('kidney-transplant',1,'X30Me',NULL,'De novo transplant disease'),('kidney-transplant',1,'X30Mf',NULL,'De novo glomerulonephritis'),('kidney-transplant',1,'X30Mg',NULL,'Transplant glomerulopathy'),('kidney-transplant',1,'X30Mh',NULL,'Transplant glomerulopathy - early form'),('kidney-transplant',1,'X30Mi',NULL,'Transplant glomerulopathy - late form'),('kidney-transplant',1,'X30MN',NULL,'Renal transplant disorder'),('kidney-transplant',1,'X30MO',NULL,'Primary non-function of renal transplant'),('kidney-transplant',1,'X30MP',NULL,'Renal transplant rejection'),('kidney-transplant',1,'X30MQ',NULL,'Hyperacute rejection of renal transplant'),('kidney-transplant',1,'X30MR',NULL,'Accelerated rejection of renal transplant'),('kidney-transplant',1,'X30MS',NULL,'Very mild acute rejection of renal transplant'),('kidney-transplant',1,'X30MT',NULL,'Acute rejection of renal transplant'),('kidney-transplant',1,'X30MU',NULL,'Acute rejection of renal transplant - grade I'),('kidney-transplant',1,'X30MV',NULL,'Acute rejection of renal transplant - grade II'),('kidney-transplant',1,'X30MW',NULL,'Acute rejection of renal transplant - grade III'),('kidney-transplant',1,'X30MX',NULL,'Chronic rejection of renal transplant'),('kidney-transplant',1,'X30MY',NULL,'Chronic rejection of renal transplant - grade 1'),('kidney-transplant',1,'X30MZ',NULL,'Chronic rejection of renal transplant - grade II'),('kidney-transplant',1,'X30NN',NULL,'Perirenal and periureteric post-transplant lymphocele'),('kidney-transplant',1,'Xa0HK',NULL,'Unexplained episode of renal transplant dysfunction'),('kidney-transplant',1,'Xa0HL',NULL,'Pre-existing disease in renal transplant'),('kidney-transplant',1,'Xa1dw',NULL,'Transplant kidney'),('kidney-transplant',1,'Xa3x6',NULL,'Kidney replacement'),('kidney-transplant',1,'Xaa2O',NULL,'Thrombosis of artery of transplanted kidney'),('kidney-transplant',1,'Xaa2Q',NULL,'Thrombosis of vein of transplanted kidney'),('kidney-transplant',1,'XaE9T',NULL,'Donor renal transplantation'),('kidney-transplant',1,'XaM1o',NULL,'Allotransplantation of kidney from cadaver, heart-beating'),('kidney-transplant',1,'XaM1p',NULL,'Allotransplantation kidney from cadaver, heart non-beating'),('kidney-transplant',1,'XaM4e',NULL,'Interventions associated with transplantation of kidney'),('kidney-transplant',1,'XaM4f',NULL,'OS interventions associated with transplantation of kidney'),('kidney-transplant',1,'XaM4g',NULL,'Interventions associated with transplantation of kidney NOS'),('kidney-transplant',1,'XaM4l',NULL,'Post-transplantation of kidney examination, recipient'),('kidney-transplant',1,'XaMKM',NULL,'Allotransplantation of kidney from cadaver NEC'),('kidney-transplant',1,'XaZe2',NULL,'Rupture of artery of transplanted kidney'),('kidney-transplant',1,'XaZe3',NULL,'Rupture of vein of transplanted kidney'),('kidney-transplant',1,'XaZe7',NULL,'Stenosis of vein of transplanted kidney'),('kidney-transplant',1,'XaZkw',NULL,'Aneurysm of vein of transplanted kidney'),('kidney-transplant',1,'XaZl0',NULL,'Aneurysm of artery of transplanted kidney'),('kidney-transplant',1,'XaZWa',NULL,'Urological complication of renal transplant'),('kidney-transplant',1,'XaZYx',NULL,'Vascular complication of renal transplant'),('kidney-transplant',1,'Y1602',NULL,'Kidney-pancreas transplant'),('kidney-transplant',1,'ZV420',NULL,'[V]Kidney transplanted');
INSERT INTO #codesctv3
VALUES ('covid-positive-antigen-test',1,'Y269d',NULL,'SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antigen detection result positive'),('covid-positive-antigen-test',1,'43kB1',NULL,'SARS-CoV-2 antigen positive');
INSERT INTO #codesctv3
VALUES ('covid-positive-pcr-test',1,'4J3R6',NULL,'SARS-CoV-2 RNA pos lim detect'),('covid-positive-pcr-test',1,'Y240b',NULL,'Severe acute respiratory syndrome coronavirus 2 qualitative existence in specimen (observable entity)'),('covid-positive-pcr-test',1,'Y2a3b',NULL,'SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) RNA (ribonucleic acid) detection result positive'),('covid-positive-pcr-test',1,'A7952',NULL,'COVID-19 confirmed by laboratory test'),('covid-positive-pcr-test',1,'Y228d',NULL,'Coronavirus disease 19 caused by severe acute respiratory syndrome coronavirus 2 confirmed by laboratory test (situation)'),('covid-positive-pcr-test',1,'Y210e',NULL,'Detection of 2019-nCoV (novel coronavirus) using polymerase chain reaction technique'),('covid-positive-pcr-test',1,'43hF.',NULL,'Detection of SARS-CoV-2 by PCR'),('covid-positive-pcr-test',1,'Y2a3d',NULL,'SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) RNA (ribonucleic acid) detection result positive at the limit of detection');
INSERT INTO #codesctv3
VALUES ('covid-positive-test-other',1,'4J3R1',NULL,'2019-nCoV (novel coronavirus) detected'),('covid-positive-test-other',1,'Y20d1',NULL,'Confirmed 2019-nCov (Wuhan) infection'),('covid-positive-test-other',1,'Y23f7',NULL,'SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) detection result positive');
INSERT INTO #codesctv3
VALUES ('egfr',1,'X70kK',NULL,'Tc99m-DTPA clearance - GFR'),('egfr',1,'X70kL',NULL,'Cr51- EDTA clearance - GFR'),('egfr',1,'X90kf',NULL,'With GFR'),('egfr',1,'XaK8y',NULL,'Glomerular filtration rate calculated by abbreviated Modification of Diet in Renal Disease Study Group calculation'),('egfr',1,'XaMDA',NULL,'Glomerular filtration rate calculated by abbreviated Modification of Diet in Renal Disease Study Group calculation adjusted for African American origin'),('egfr',1,'XaZpN',NULL,'Estimated glomerular filtration rate using Chronic Kidney Disease Epidemiology Collaboration formula per 1.73 square metres'),('egfr',1,'XacUJ',NULL,'Estimated glomerular filtration rate using cystatin C Chronic Kidney Disease Epidemiology Collaboration equation per 1.73 square metres'),('egfr',1,'XacUK',NULL,'Estimated glomerular filtration rate using creatinine Chronic Kidney Disease Epidemiology Collaboration equation per 1.73 square metres');
INSERT INTO #codesctv3
VALUES ('urinary-albumin-creatinine-ratio',1,'46TC.',NULL,'Urine albumin:creatinine ratio'),('urinary-albumin-creatinine-ratio',1,'XE2n3',NULL,'Urine albumin:creatinine ratio')

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
VALUES ('chronic-kidney-disease',1,'46177005',NULL,'End-stage renal disease'),('chronic-kidney-disease',1,'431855005',NULL,'CKD stage 1'),('chronic-kidney-disease',1,'431856006',NULL,'CKD stage 2'),('chronic-kidney-disease',1,'431857002',NULL,'CKD stage 4'),('chronic-kidney-disease',1,'433144002',NULL,'CKD stage 3'),('chronic-kidney-disease',1,'433146000',NULL,'CKD stage 5'),('chronic-kidney-disease',1,'700378005',NULL,'Chronic kidney disease stage 3A (disorder)'),('chronic-kidney-disease',1,'700379002',NULL,'Chronic kidney disease stage 3B (disorder)'),('chronic-kidney-disease',1,'707323002',NULL,'Anemia in chronic kidney disease'),('chronic-kidney-disease',1,'709044004',NULL,'Chronic renal disease'),('chronic-kidney-disease',1,'713313000',NULL,'Chronic kidney disease mineral and bone disorder (disorder)'),('chronic-kidney-disease',1,'714152005',NULL,'Chronic kidney disease stage 5 on dialysis'),('chronic-kidney-disease',1,'714153000',NULL,'CKD (chronic kidney disease) stage 5t'),('chronic-kidney-disease',1,'722098007',NULL,'Chronic kidney disease following donor nephrectomy'),('chronic-kidney-disease',1,'722149000',NULL,'Chronic kidney disease due to tumour nephrectomy'),('chronic-kidney-disease',1,'722150000',NULL,'Chronic kidney disease due to systemic infection'),('chronic-kidney-disease',1,'722467000',NULL,'Chronic kidney disease due to traumatic loss of kidney'),('chronic-kidney-disease',1,'140121000119100',NULL,'Hypertension in chronic kidney disease stage 3 due to type II diabetes mellitus'),('chronic-kidney-disease',1,'140131000119102',NULL,'Hypertension in chronic kidney disease stage 2 due to type II diabetes mellitus'),('chronic-kidney-disease',1,'140101000119109',NULL,'Hypertension in chronic kidney disease stage 5 due to type II diabetes mellitus'),('chronic-kidney-disease',1,'140111000119107',NULL,'Hypertension in chronic kidney disease stage 4 due to type II diabetes mellitus'),('chronic-kidney-disease',1,'71701000119105',NULL,'Hypertension in chronic kidney disease due to type I diabetes mellitus'),('chronic-kidney-disease',1,'71421000119105',NULL,'Hypertension in chronic kidney disease due to type II diabetes mellitus'),('chronic-kidney-disease',1,'104931000119100',NULL,'Chronic kidney disease due to hypertension (disorder)'),('chronic-kidney-disease',1,'731000119105',NULL,'Chronic kidney disease stage 3 due to type II diabetes mellitus'),('chronic-kidney-disease',1,'741000119101',NULL,'Chronic kidney disease stage 2 due to type II diabetes mellitus'),('chronic-kidney-disease',1,'711000119100',NULL,'Chronic kidney disease stage 5 due to type II diabetes mellitus'),('chronic-kidney-disease',1,'721000119107',NULL,'Chronic kidney disease stage 4 due to type II diabetes mellitus'),('chronic-kidney-disease',1,'96441000119101',NULL,'Chronic kidney disease due to type I diabetes mellitus'),('chronic-kidney-disease',1,'771000119108',NULL,'Chronic kidney disease due to type 2 diabetes mellitus (disorder)'),('chronic-kidney-disease',1,'10757481000119107',NULL,'Preexisting hypertensive heart and chronic kidney disease in pregnancy'),('chronic-kidney-disease',1,'285831000119108',NULL,'Malignant hypertensive chronic kidney disease (disorder)'),('chronic-kidney-disease',1,'129161000119100',NULL,'Chronic kidney disease stage 5 due to hypertension (disorder)'),('chronic-kidney-disease',1,'117681000119102',NULL,'Chronic kidney disease stage 1 due to hypertension (disorder)'),('chronic-kidney-disease',1,'129171000119106',NULL,'Chronic kidney disease stage 3 due to hypertension (disorder)'),('chronic-kidney-disease',1,'129181000119109',NULL,'Chronic kidney disease stage 2 due to hypertension (disorder)'),('chronic-kidney-disease',1,'129151000119102',NULL,'Chronic kidney disease stage 4 due to hypertension (disorder)'),('chronic-kidney-disease',1,'8501000119104',NULL,'Hypertensive heart and chronic kidney disease (disorder)'),('chronic-kidney-disease',1,'96701000119107',NULL,'Hypertensive heart AND chronic kidney disease on dialysis (disorder)'),('chronic-kidney-disease',1,'284961000119106',NULL,'Chronic kidney disease due to benign hypertension (disorder)'),('chronic-kidney-disease',1,'324281000000104',NULL,'Chronic kidney disease stage 3 without proteinuria'),('chronic-kidney-disease',1,'324251000000105',NULL,'Chronic kidney disease stage 3 with proteinuria'),('chronic-kidney-disease',1,'285871000119106',NULL,'Malignant hypertensive chronic kidney disease stage 3 (disorder)'),('chronic-kidney-disease',1,'96731000119100',NULL,'Hypertensive heart AND chronic kidney disease stage 3 (disorder)'),('chronic-kidney-disease',1,'90741000119107',NULL,'Chronic kidney disease stage 3 due to type I diabetes mellitus'),('chronic-kidney-disease',1,'284991000119104',NULL,'Chronic kidney disease stage 3 due to benign hypertension'),('chronic-kidney-disease',1,'691421000119108',NULL,'Anemia co-occurrent and due to chronic kidney disease stage 3'),('chronic-kidney-disease',1,'324211000000106',NULL,'Chronic kidney disease stage 2 without proteinuria'),('chronic-kidney-disease',1,'324181000000105',NULL,'Chronic kidney disease stage 2 with proteinuria'),('chronic-kidney-disease',1,'285861000119100',NULL,'Malignant hypertensive chronic kidney disease stage 2 (disorder)'),('chronic-kidney-disease',1,'96741000119109',NULL,'Hypertensive heart AND chronic kidney disease stage 2 (disorder)'),('chronic-kidney-disease',1,'90731000119103',NULL,'Chronic kidney disease stage 2 due to type I diabetes mellitus'),('chronic-kidney-disease',1,'284981000119102',NULL,'Chronic kidney disease stage 2 due to benign hypertension (disorder)'),('chronic-kidney-disease',1,'324541000000105',NULL,'Chronic kidney disease stage 5 without proteinuria'),('chronic-kidney-disease',1,'324501000000107',NULL,'Chronic kidney disease stage 5 with proteinuria'),('chronic-kidney-disease',1,'153851000119106',NULL,'Malignant hypertensive chronic kidney disease stage 5 (disorder)'),('chronic-kidney-disease',1,'96711000119105',NULL,'Hypertensive heart AND chronic kidney disease stage 5 (disorder)'),('chronic-kidney-disease',1,'90761000119106',NULL,'Chronic kidney disease stage 5 due to type I diabetes mellitus'),('chronic-kidney-disease',1,'285011000119108',NULL,'Chronic kidney disease stage 5 due to benign hypertension'),('chronic-kidney-disease',1,'324441000000106',NULL,'Chronic kidney disease stage 4 with proteinuria'),('chronic-kidney-disease',1,'324471000000100',NULL,'Chronic kidney disease stage 4 without proteinuria'),('chronic-kidney-disease',1,'285881000119109',NULL,'Malignant hypertensive chronic kidney disease stage 4 (disorder)'),('chronic-kidney-disease',1,'96721000119103',NULL,'Hypertensive heart AND chronic kidney disease stage 4 (disorder)'),('chronic-kidney-disease',1,'90751000119109',NULL,'Chronic kidney disease stage 4 due to type I diabetes mellitus'),('chronic-kidney-disease',1,'285001000119105',NULL,'Chronic kidney disease stage 4 due to benign hypertension (disorder)'),('chronic-kidney-disease',1,'90721000119101',NULL,'Chronic kidney disease stage 1 due to type I diabetes mellitus'),('chronic-kidney-disease',1,'751000119104',NULL,'Chronic kidney disease stage 1 due to type II diabetes mellitus'),('chronic-kidney-disease',1,'285851000119102',NULL,'Malignant hypertensive chronic kidney disease stage 1 (disorder)'),('chronic-kidney-disease',1,'96751000119106',NULL,'Hypertensive heart AND chronic kidney disease stage 1 (disorder)'),('chronic-kidney-disease',1,'284971000119100',NULL,'Chronic kidney disease stage 1 due to benign hypertension (disorder)'),('chronic-kidney-disease',1,'10757401000119104',NULL,'Pre-existing hypertensive heart and chronic kidney disease in mother complicating childbirth'),('chronic-kidney-disease',1,'324311000000101',NULL,'Chronic kidney disease stage 3A with proteinuria'),('chronic-kidney-disease',1,'324341000000100',NULL,'Chronic kidney disease stage 3A without proteinuria'),('chronic-kidney-disease',1,'324371000000106',NULL,'Chronic kidney disease stage 3B with proteinuria'),('chronic-kidney-disease',1,'324411000000105',NULL,'Chronic kidney disease stage 3B without proteinuria'),('chronic-kidney-disease',1,'949521000000108',NULL,'Chronic kidney disease with glomerular filtration rate category G2 and albuminuria category A1'),('chronic-kidney-disease',1,'949561000000100',NULL,'Chronic kidney disease with glomerular filtration rate category G2 and albuminuria category A2'),('chronic-kidney-disease',1,'949621000000109',NULL,'Chronic kidney disease with glomerular filtration rate category G2 and albuminuria category A3'),('chronic-kidney-disease',1,'950251000000106',NULL,'Chronic kidney disease with glomerular filtration rate category G5 and albuminuria category A1'),('chronic-kidney-disease',1,'950291000000103',NULL,'Chronic kidney disease with glomerular filtration rate category G5 and albuminuria category A2'),('chronic-kidney-disease',1,'950311000000102',NULL,'Chronic kidney disease with glomerular filtration rate category G5 and albuminuria category A3'),('chronic-kidney-disease',1,'950181000000106',NULL,'Chronic kidney disease with glomerular filtration rate category G4 and albuminuria category A1'),('chronic-kidney-disease',1,'950211000000107',NULL,'Chronic kidney disease with glomerular filtration rate category G4 and albuminuria category A2'),('chronic-kidney-disease',1,'950231000000104',NULL,'Chronic kidney disease with glomerular filtration rate category G4 and albuminuria category A3'),('chronic-kidney-disease',1,'324151000000104',NULL,'Chronic kidney disease stage 1 without proteinuria'),('chronic-kidney-disease',1,'324121000000109',NULL,'Chronic kidney disease stage 1 with proteinuria'),('chronic-kidney-disease',1,'949881000000106',NULL,'CKD G3aA1 - chronic kidney disease with glomerular filtration rate category G3a and albuminuria category A1'),('chronic-kidney-disease',1,'949901000000109',NULL,'Chronic kidney disease with glomerular filtration rate category G3a and albuminuria category A2'),
('chronic-kidney-disease',1,'949921000000100',NULL,'Chronic kidney disease with glomerular filtration rate category G3a and albuminuria category A3'),('chronic-kidney-disease',1,'950061000000103',NULL,'Chronic kidney disease with glomerular filtration rate category G3b and albuminuria category A1'),('chronic-kidney-disease',1,'950081000000107',NULL,'Chronic kidney disease with glomerular filtration rate category G3b and albuminuria category A2'),('chronic-kidney-disease',1,'950101000000101',NULL,'Chronic kidney disease with glomerular filtration rate category G3b and albuminuria category A3'),('chronic-kidney-disease',1,'949401000000103',NULL,'Chronic kidney disease with glomerular filtration rate category G1 and albuminuria category A1'),('chronic-kidney-disease',1,'949421000000107',NULL,'Chronic kidney disease with glomerular filtration rate category G1 and albuminuria category A2'),('chronic-kidney-disease',1,'949481000000108',NULL,'Chronic kidney disease with glomerular filtration rate category G1 and albuminuria category A3'),('chronic-kidney-disease',1,'691401000119104',NULL,'Anaemia in chronic kidney disease stage 4'),('chronic-kidney-disease',1,'691411000119101',NULL,'Anaemia in chronic kidney disease stage 5'),('chronic-kidney-disease',1,'444271000',NULL,'Erythropoietin resistance in anemia of chronic kidney disease'),('chronic-kidney-disease',1,'15781000119107',NULL,'Hypertensive heart AND chronic kidney disease with congestive heart failure (disorder)');
INSERT INTO #codessnomed
VALUES ('glomerulonephritis',1,'1426004',NULL,'Necrotizing glomerulonephritis (disorder)'),('glomerulonephritis',1,'3704008',NULL,'Diffuse endocapillary proliferative glomerulonephritis (disorder)'),('glomerulonephritis',1,'4676006',NULL,'Systemic lupus erythematosus glomerulonephritis syndrome, World Health Organization class II (disorder)'),('glomerulonephritis',1,'11013005',NULL,'Systemic lupus erythematosus glomerulonephritis syndrome, World Health Organization class VI'),('glomerulonephritis',1,'13335004',NULL,'Sclerosing glomerulonephritis (disorder)'),('glomerulonephritis',1,'19351000',NULL,'Acute glomerulonephritis (disorder)'),('glomerulonephritis',1,'20917003',NULL,'CGN - Chronic glomerulonephritis'),('glomerulonephritis',1,'35546006',NULL,'Mesangial proliferative glomerulonephritis (disorder)'),('glomerulonephritis',1,'36171008',NULL,'GN - Glomerulonephritis'),('glomerulonephritis',1,'36402006',NULL,'Systemic lupus erythematosus glomerulonephritis syndrome, World Health Organization class IV'),('glomerulonephritis',1,'44785005',NULL,'MCN - Minimal change nephropathy'),('glomerulonephritis',1,'50581000',NULL,'Goodpasture syndrome'),('glomerulonephritis',1,'52042003',NULL,'Systemic lupus erythematosus glomerulonephritis syndrome, World Health Organization class V'),('glomerulonephritis',1,'55652009',NULL,'Idiopathic crescentic glomerulonephritis type 3'),('glomerulonephritis',1,'57965003',NULL,'Acute benign haemorrhagic glomerulonephritis'),('glomerulonephritis',1,'59479006',NULL,'Mesangiocapillary glomerulonephritis, type II (disorder)'),('glomerulonephritis',1,'64168005',NULL,'Idiopathic crescentic glomerulonephritis, type I (disorder)'),('glomerulonephritis',1,'64212008',NULL,'Diffuse crescentic glomerulonephritis (disorder)'),('glomerulonephritis',1,'68544003',NULL,'PSGN - Post-streptococcal glomerulonephritis'),('glomerulonephritis',1,'68779003',NULL,'Primary immunoglobulin A nephropathy (disorder)'),('glomerulonephritis',1,'68815009',NULL,'Systemic lupus erythematosus glomerulonephritis syndrome'),('glomerulonephritis',1,'73286009',NULL,'Systemic lupus erythematosus glomerulonephritis syndrome, World Health Organization class I (disorder)'),('glomerulonephritis',1,'73305009',NULL,'Amyloid-like glomerulopathy'),('glomerulonephritis',1,'75888001',NULL,'Mesangiocapillary glomerulonephritis type I'),('glomerulonephritis',1,'76521009',NULL,'Systemic lupus erythematosus glomerulonephritis syndrome, World Health Organization class III'),('glomerulonephritis',1,'77182004',NULL,'Chronic nephritic syndrome, diffuse membranous glomerulonephritis'),('glomerulonephritis',1,'80321008',NULL,'Mesangiocapillary glomerulonephritis (disorder)'),('glomerulonephritis',1,'83866005',NULL,'Focal AND segmental proliferative glomerulonephritis (disorder)'),('glomerulonephritis',1,'123609007',NULL,'Subacute glomerulonephritis (disorder)'),('glomerulonephritis',1,'123752003',NULL,'Immune complex glomerulonephritis'),('glomerulonephritis',1,'197579006',NULL,'Acute proliferative glomerulonephritis (disorder)'),('glomerulonephritis',1,'197582001',NULL,'Acute glomerulonephritis associated with another disorder'),('glomerulonephritis',1,'197589005',NULL,'Nephrotic syndrome with proliferative glomerulonephritis (disorder)'),('glomerulonephritis',1,'197590001',NULL,'Nephrotic syndrome with membranous glomerulonephritis (disorder)'),('glomerulonephritis',1,'197591002',NULL,'Nephrotic syndrome with membranoproliferative glomerulonephritis (disorder)'),('glomerulonephritis',1,'197595006',NULL,'Nephrotic syndrome, diffuse membranous glomerulonephritis (disorder)'),('glomerulonephritis',1,'197596007',NULL,'Nephrotic syndrome, diffuse mesangial proliferative glomerulonephritis (disorder)'),('glomerulonephritis',1,'197597003',NULL,'Nephrotic syndrome, diffuse endocapillary proliferative glomerulonephritis (disorder)'),('glomerulonephritis',1,'197598008',NULL,'Nephrotic syndrome, diffuse mesangiocapillary glomerulonephritis (disorder)'),('glomerulonephritis',1,'197600002',NULL,'Nephrotic syndrome, diffuse crescentic glomerulonephritis (disorder)'),('glomerulonephritis',1,'197613008',NULL,'Chronic mesangial proliferative glomerulonephritis (disorder)'),('glomerulonephritis',1,'197616000',NULL,'Chronic glomerulonephritis associated with another disorder'),('glomerulonephritis',1,'197617009',NULL,'Chronic exudative glomerulonephritis (disorder)'),('glomerulonephritis',1,'197618004',NULL,'Chronic focal glomerulonephritis (disorder)'),('glomerulonephritis',1,'197619007',NULL,'Chronic diffuse glomerulonephritis (disorder)'),('glomerulonephritis',1,'197626007',NULL,'Focal membranoproliferative glomerulonephritis (disorder)'),('glomerulonephritis',1,'197629000',NULL,'Anaphylactoid glomerulonephritis (disorder)'),('glomerulonephritis',1,'197683002',NULL,'Acute nephritic syndrome, diffuse membranous glomerulonephritis (disorder)'),('glomerulonephritis',1,'197684008',NULL,'Acute nephritic syndrome, diffuse mesangial proliferative glomerulonephritis (disorder)'),('glomerulonephritis',1,'197685009',NULL,'Acute nephritic syndrome, diffuse endocapillary proliferative glomerulonephritis (disorder)'),('glomerulonephritis',1,'197686005',NULL,'Acute nephritic syndrome, diffuse mesangiocapillary glomerulonephritis (disorder)'),('glomerulonephritis',1,'197688006',NULL,'Acute nephritic syndrome, diffuse crescentic glomerulonephritis (disorder)'),('glomerulonephritis',1,'197692004',NULL,'Rapidly progressive nephritic syndrome, diffuse membranous glomerulonephritis (disorder)'),('glomerulonephritis',1,'197693009',NULL,'Rapidly progressive nephritic syndrome, diffuse mesangial proliferative glomerulonephritis (disorder)'),('glomerulonephritis',1,'197694003',NULL,'Rapidly progressive nephritic syndrome, diffuse endocapillary proliferative glomerulonephritis (disorder)'),('glomerulonephritis',1,'197695002',NULL,'Rapidly progressive nephritic syndrome, diffuse mesangiocapillary glomerulonephritis (disorder)'),('glomerulonephritis',1,'197697005',NULL,'Rapidly progressive nephritic syndrome, diffuse crescentic glomerulonephritis (disorder)'),('glomerulonephritis',1,'197712008',NULL,'Chronic nephritic syndrome, diffuse endocapillary proliferative glomerulonephritis (disorder)'),('glomerulonephritis',1,'197713003',NULL,'Chronic nephritic syndrome, diffuse mesangiocapillary glomerulonephritis (disorder)'),('glomerulonephritis',1,'197715005',NULL,'Chronic nephritic syndrome, diffuse crescentic glomerulonephritis (disorder)'),('glomerulonephritis',1,'197720005',NULL,'Isolated proteinuria with specified morphological lesion, diffuse membranous glomerulonephritis (finding)'),('glomerulonephritis',1,'197721009',NULL,'Isolated proteinuria with specified morphological lesion, diffuse mesangial proliferative glomerulonephritis (finding)'),('glomerulonephritis',1,'197722002',NULL,'Isolated proteinuria with specified morphological lesion, diffuse endocapillary proliferative glomerulonephritis (finding)'),('glomerulonephritis',1,'197723007',NULL,'Isolated proteinuria with specified morphological lesion, diffuse mesangiocapillary glomerulonephritis (finding)'),('glomerulonephritis',1,'197725000',NULL,'Isolated proteinuria with specified morphological lesion, diffuse concentric glomerulonephritis (finding)'),('glomerulonephritis',1,'236392004',NULL,'Rapidly progressive glomerulonephritis (disorder)'),('glomerulonephritis',1,'236393009',NULL,'Endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'236394003',NULL,'Idiopathic endocapillary glomerulonephritis (disorder)'),('glomerulonephritis',1,'236395002',NULL,'Post-infectious glomerulonephritis (disorder)'),('glomerulonephritis',1,'236397005',NULL,'Post-infectious glomerulonephritis - Garland variety (disorder)'),('glomerulonephritis',1,'236398000',NULL,'Proliferative crescentic glomerulonephritis'),('glomerulonephritis',1,'236399008',NULL,'Steroid-sensitive minimal change glomerulonephritis (disorder)'),('glomerulonephritis',1,'236400001',NULL,'Steroid-resistant minimal change glomerulonephritis (disorder)'),('glomerulonephritis',1,'236401002',NULL,'Steroid-dependent minimal change glomerulonephritis (disorder)'),('glomerulonephritis',1,'236407003',NULL,'Immunoglobulin A nephropathy (disorder)'),('glomerulonephritis',1,'236409000',NULL,'Mesangiocapillary glomerulonephritis type III (disorder)'),('glomerulonephritis',1,'236410005',NULL,'Mesangiocapillary glomerulonephritis type IV (disorder)'),('glomerulonephritis',1,'236411009',NULL,'Immunoglobulin M nephropathy (disorder)'),('glomerulonephritis',1,'236413007',NULL,'Membranous glomerulonephritis - stage I (disorder)'),('glomerulonephritis',1,'236414001',NULL,'Membranous glomerulonephritis - stage II (disorder)'),('glomerulonephritis',1,'236415000',NULL,'Membranous glomerulonephritis - stage III (disorder)'),('glomerulonephritis',1,'236416004',NULL,'Membranous glomerulonephritis - stage IV (disorder)'),('glomerulonephritis',1,'236417008',NULL,'Membranous glomerulonephritis stage V (disorder)'),('glomerulonephritis',1,'236419006',NULL,'Progressive hereditary glomerulonephritis without deafness (disorder)'),('glomerulonephritis',1,'236505008',NULL,'Cryoglobulinemic glomerulonephritis (disorder)'),('glomerulonephritis',1,'236508005',NULL,'Malignancy-associated glomerulonephritis (disorder)'),('glomerulonephritis',1,'236586006',NULL,'De novo glomerulonephritis (disorder)'),('glomerulonephritis',1,'236590008',NULL,'Cytomegalovirus-induced glomerulonephritis (disorder)'),('glomerulonephritis',1,'239932005',NULL,'Primary pauci-immune necrotizing and crescentic glomerulonephritis (disorder)'),('glomerulonephritis',1,'266549004',NULL,'Nephrotic syndrome with minimal change glomerulonephritis (disorder)'),('glomerulonephritis',1,'359694003',NULL,'Idiopathic crescentic glomerulonephritis, type II (disorder)'),('glomerulonephritis',1,'363233007',NULL,'Nephrotic syndrome secondary to glomerulonephritis (disorder)'),
('glomerulonephritis',1,'399190000',NULL,'Non-progressive hereditary glomerulonephritis'),('glomerulonephritis',1,'399340005',NULL,'Alports syndrome'),('glomerulonephritis',1,'425384007',NULL,'Sarcoidosis with glomerulonephritis'),('glomerulonephritis',1,'425455002',NULL,'Diabetic glomerulonephritis'),('glomerulonephritis',1,'427555000',NULL,'Glomerulonephritis co-occurrent and due to Wegeners granulomatosis'),('glomerulonephritis',1,'441815006',NULL,'Proliferative glomerulonephritis (disorder)'),('glomerulonephritis',1,'445258009',NULL,'Idiopathic rapidly progressive glomerulonephritis'),('glomerulonephritis',1,'707332000',NULL,'Recurrent proliferative glomerulonephritis (disorder)'),('glomerulonephritis',1,'711531007',NULL,'Focal mesangial proliferative glomerulonephritis (disorder)'),('glomerulonephritis',1,'714815007',NULL,'Recurrent haematuria co-occurrent and due to diffuse crescentic glomerulonephritis'),('glomerulonephritis',1,'714816008',NULL,'Persistent haematuria co-occurrent and due to diffuse crescentic glomerulonephritis'),('glomerulonephritis',1,'714817004',NULL,'Recurrent haematuria co-occurrent and due to diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'714818009',NULL,'Persistent haematuria co-occurrent and due to diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'714819001',NULL,'Recurrent haematuria co-occurrent and due to diffuse mesangiocapillary glomerulonephritis'),('glomerulonephritis',1,'714820007',NULL,'Persistent haematuria co-occurrent and due to diffuse mesangiocapillary glomerulonephritis'),('glomerulonephritis',1,'714821006',NULL,'Recurrent haematuria co-occurrent and due to diffuse membranous glomerulonephritis'),('glomerulonephritis',1,'714822004',NULL,'Persistent haematuria co-occurrent and due to diffuse membranous glomerulonephritis'),('glomerulonephritis',1,'714825002',NULL,'Recurrent haematuria co-occurrent and due to diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'714826001',NULL,'Persistent haematuria co-occurrent and due to diffuse mesangial proliferative glomerulonephritis'),('glomerulonephritis',1,'718192000',NULL,'Congo red negative amyloidosis like glomerulopathy'),('glomerulonephritis',1,'722086002',NULL,'Malignancy-associated membranous nephropathy'),('glomerulonephritis',1,'722119002',NULL,'Idiopathic membranous nephropathy'),('glomerulonephritis',1,'722120008',NULL,'Membranous glomerulonephritis caused by drug'),('glomerulonephritis',1,'722168002',NULL,'Membranous glomerulonephritis co-occurrent with infectious disease'),('glomerulonephritis',1,'722761003',NULL,'Complement component 3 glomerulonephritis'),('glomerulonephritis',1,'726082003',NULL,'Immunotactoid glomerulonephritis'),('glomerulonephritis',1,'733472005',NULL,'Microcephalus, glomerulonephritis, marfanoid habitus syndrome'),('glomerulonephritis',1,'106911000119102',NULL,'Idiopathic glomerulonephritis'),('glomerulonephritis',1,'120241000119100',NULL,'Glomerulonephritis due to hepatitis C'),('glomerulonephritis',1,'85381000119105',NULL,'Glomerulonephritis due to Henoch-Schönlein purpura (disorder)'),('glomerulonephritis',1,'89681000119101',NULL,'Glomerulonephritis co-occurrent and due to scleroderma'),('glomerulonephritis',1,'101711000119105',NULL,'Glomerulonephritis co-occurrent and due to antineutrophil cytoplasmic antibody positive vasculitis'),('glomerulonephritis',1,'90971000119103',NULL,'Glomerulonephritis co-occurrent and due to vasculitis'),('glomerulonephritis',1,'195791000119101',NULL,'Chronic proliferative glomerulonephritis'),('glomerulonephritis',1,'367561000119103',NULL,'Hereditary diffuse mesangiocapillary glomerulonephritis (disorder)'),('glomerulonephritis',1,'367551000119100',NULL,'Hereditary diffuse mesangial proliferative glomerulonephritis (disorder)'),('glomerulonephritis',1,'367531000119106',NULL,'Hereditary diffuse endocapillary proliferative glomerulonephritis'),('glomerulonephritis',1,'367541000119102',NULL,'Hereditary diffuse membranous glomerulonephritis'),('glomerulonephritis',1,'368941000119108',NULL,'Hereditary nephropathy co-occurrent with membranoproliferative glomerulonephritis type III'),('glomerulonephritis',1,'368881000119109',NULL,'Rapidly progressive nephritic syndrome co-occurrent and due to membranoproliferative glomerulonephritis type III (disorder)'),('glomerulonephritis',1,'28191000119109',NULL,'Chronic nephritic syndrome with membranous glomerulonephritis (disorder)'),('glomerulonephritis',1,'368931000119104',NULL,'Isolated proteinuria co-occurrent and due to membranoproliferative glomerulonephritis type III (disorder)'),('glomerulonephritis',1,'368921000119102',NULL,'Nephritic syndrome co-occurrent and due to membranoproliferative glomerulonephritis type III (disorder)'),('glomerulonephritis',1,'368911000119109',NULL,'Nephrotic syndrome co-occurrent and due to membranoproliferative glomerulonephritis type III'),('glomerulonephritis',1,'367511000119101',NULL,'Hereditary dense deposit disease'),('glomerulonephritis',1,'367521000119108',NULL,'Hereditary diffuse crescentic glomerulonephritis (disorder)'),('glomerulonephritis',1,'368871000119106',NULL,'Acute nephritic syndrome co-occurrent and due to membranoproliferative glomerulonephritis type III (disorder)'),('glomerulonephritis',1,'368901000119106',NULL,'Chronic nephritic syndrome co-occurrent and due to membranoproliferative glomerulonephritis type III (disorder)'),('glomerulonephritis',1,'123610002',NULL,'Healed glomerulonephritis (disorder)');
INSERT INTO #codessnomed
VALUES ('kidney-stones',1,'95570007',NULL,'Kidney stone (disorder)'),('kidney-stones',1,'833291009',NULL,'Calcium oxalate calculus of kidney (disorder)'),('kidney-stones',1,'427649000',NULL,'Calcium renal calculus (disorder)'),('kidney-stones',1,'23754003',NULL,'Calculous pyelonephritis (disorder)'),('kidney-stones',1,'236710009',NULL,'Calculus in renal pelvis (disorder)'),('kidney-stones',1,'266556005',NULL,'Calculus of kidney and ureter (disorder)'),('kidney-stones',1,'236708007',NULL,'Calyceal renal calculus (disorder)'),('kidney-stones',1,'48061001',NULL,'Congenital calculus of kidney (disorder)'),('kidney-stones',1,'833293007',NULL,'Cystine calculus of kidney (disorder)'),('kidney-stones',1,'699322002',NULL,'Matrix stone of kidney (disorder)'),('kidney-stones',1,'168041003',NULL,'On examination - renal calculus (disorder)'),('kidney-stones',1,'275893001',NULL,'Phosphate calculus of kidney (disorder)'),('kidney-stones',1,'1056501000112102',NULL,'Recurrent kidney stone (disorder)'),('kidney-stones',1,'197794008',NULL,'Staghorn calculus (disorder)'),('kidney-stones',1,'274401005',NULL,'Uric acid renal calculus (disorder)'),('kidney-stones',1,'236713006',NULL,'X-linked recessive nephrolithiasis with renal failure (disorder)');
INSERT INTO #codessnomed
VALUES ('vasculitis',1,'228007',NULL,'Lucio phenomenon (disorder)'),('vasculitis',1,'9177003',NULL,'Histiocytic vasculitis of skin (disorder)'),('vasculitis',1,'11791001',NULL,'Necrotizing vasculitis (disorder)'),('vasculitis',1,'31996006',NULL,'Vasculitis (disorder)'),('vasculitis',1,'46286007',NULL,'Lymphocytic vasculitis of skin (disorder)'),('vasculitis',1,'46956008',NULL,'Polyangiitis'),('vasculitis',1,'53312001',NULL,'Vasculitis of the skin (disorder)'),('vasculitis',1,'55275006',NULL,'Non-tubercular erythema induratum'),('vasculitis',1,'56780006',NULL,'Segmental hyalinizing vasculitis (disorder)'),('vasculitis',1,'60555002',NULL,'Hypersensitivity angiitis (disorder)'),('vasculitis',1,'64832003',NULL,'Neutrophilic vasculitis of skin (disorder)'),('vasculitis',1,'77628002',NULL,'Retinal vasculitis (disorder)'),('vasculitis',1,'95578000',NULL,'Renal vasculitis (disorder)'),('vasculitis',1,'190815001',NULL,'Cryoglobulinemic vasculitis (disorder)'),('vasculitis',1,'191306005',NULL,'Henoch-Schönlein purpura (disorder)'),('vasculitis',1,'230731002',NULL,'Cerebral arteritis in systemic vasculitis (disorder)'),('vasculitis',1,'230733004',NULL,'Isolated angiitis of central nervous system (disorder)'),('vasculitis',1,'234019004',NULL,'Secondary systemic vasculitis (disorder)'),('vasculitis',1,'234020005',NULL,'Vasculitis caused by drug'),('vasculitis',1,'238762002',NULL,'Livedoid vasculitis (disorder)'),('vasculitis',1,'238785001',NULL,'Primary cutaneous vasculitis (disorder)'),('vasculitis',1,'238786000',NULL,'Gougerot-Ruiter purpura (disorder)'),('vasculitis',1,'238787009',NULL,'Secondary cutaneous vasculitis (disorder)'),('vasculitis',1,'239924002',NULL,'Primary necrotizing systemic vasculitis (disorder)'),('vasculitis',1,'239933000',NULL,'Primary necrotizing vasculitis with granulomata (disorder)'),('vasculitis',1,'239941000',NULL,'Nailfold rheumatoid vasculitis (disorder)'),('vasculitis',1,'239942007',NULL,'Systemic rheumatoid vasculitis (disorder)'),('vasculitis',1,'239943002',NULL,'Necrotizing rheumatoid vasculitis (disorder)'),('vasculitis',1,'239944008',NULL,'Lupus erythematosus-associated vasculitis'),('vasculitis',1,'239945009',NULL,'Hypocomplementemic urticarial vasculitis (disorder)'),('vasculitis',1,'239947001',NULL,'Essential mixed cryoglobulinemia (disorder)'),('vasculitis',1,'400054000',NULL,'Rheumatoid vasculitis'),('vasculitis',1,'402416000',NULL,'Urticarial vasculitis with monoclonal immunoglobulin M component, Schnitzler'),('vasculitis',1,'402655006',NULL,'Necrotizing cutaneous vasculitis'),('vasculitis',1,'402656007',NULL,'Urticarial vasculitis'),('vasculitis',1,'402657003',NULL,'Necrotizing vasculitis secondary to connective tissue disease'),('vasculitis',1,'402658008',NULL,'Serum sickness type vasculitis'),('vasculitis',1,'402659000',NULL,'Drug-induced necrotizing vasculitis'),('vasculitis',1,'402660005',NULL,'Necrotizing vasculitis secondary to infection'),('vasculitis',1,'402661009',NULL,'Paraneoplastic vasculitis'),('vasculitis',1,'402662002',NULL,'Necrotizing vasculitis due to mixed cryoglobulinemia'),('vasculitis',1,'402663007',NULL,'Pustular vasculitis'),('vasculitis',1,'402664001',NULL,'Localized cutaneous vasculitis'),('vasculitis',1,'402855009',NULL,'Normocomplementemic urticarial vasculitis'),('vasculitis',1,'402859003',NULL,'Necrotizing vasculitis of undetermined etiology'),('vasculitis',1,'402958005',NULL,'Pustular vasculitis due to gonococcal bacteremia'),('vasculitis',1,'403510002',NULL,'Urticarial vasculitis due to lupus erythematosus'),('vasculitis',1,'403511003',NULL,'Necrotizing vasculitis due to lupus erythematosus'),('vasculitis',1,'403518009',NULL,'Necrotizing vasculitis due to scleroderma'),('vasculitis',1,'403616000',NULL,'Drug-induced lymphocytic vasculitis'),('vasculitis',1,'407530004',NULL,'Primary systemic vasculitis'),('vasculitis',1,'416703007',NULL,'Retinal vasculitis due to polyarteritis nodosa'),('vasculitis',1,'417303004',NULL,'Retinal vasculitis due to systemic lupus erythematosus'),('vasculitis',1,'427020007',NULL,'Cerebral vasculitis'),('vasculitis',1,'427213005',NULL,'Autoimmune vasculitis'),('vasculitis',1,'427356003',NULL,'Eosinophilic vasculitis of skin'),('vasculitis',1,'718217000',NULL,'Cutaneous small vessel vasculitis'),('vasculitis',1,'721664001',NULL,'Mesenteric arteritis'),('vasculitis',1,'722191003',NULL,'Antineutrophil cytoplasmic antibody (ANCA) positive vasculitis'),('vasculitis',1,'722858009',NULL,'Vasculitis of large intestine'),('vasculitis',1,'724063005',NULL,'Postinfective vasculitis'),('vasculitis',1,'724597006',NULL,'Large vessel vasculitis'),('vasculitis',1,'724598001',NULL,'Medium sized vessel vasculitis'),('vasculitis',1,'724599009',NULL,'Small vessel vasculitis'),('vasculitis',1,'724600007',NULL,'Immune complex small vessel vasculitis'),('vasculitis',1,'724601006',NULL,'Vasculitis caused by antineutrophil cytoplasmic antibody'),('vasculitis',1,'724602004',NULL,'Single organ vasculitis'),('vasculitis',1,'724996005',NULL,'Vasculitic lumbosacral plexopathy'),('vasculitis',1,'737184001',NULL,'Interstitial lung disease with systemic vasculitis'),('vasculitis',1,'762302008',NULL,'Drug-associated immune complex vasculitis'),('vasculitis',1,'762352004',NULL,'Demyelination due to systemic vasculitis'),('vasculitis',1,'762537007',NULL,'Livedoid vasculitis of lower limb due to varicose veins of lower limb'),('vasculitis',1,'985941000000100',NULL,'Medium vessel vasculitis (disorder)'),('vasculitis',1,'101711000119105',NULL,'Glomerulonephritis co-occurrent and due to antineutrophil cytoplasmic antibody positive vasculitis'),('vasculitis',1,'985971000000106',NULL,'Sarcoid vasculitis (disorder)'),('vasculitis',1,'988101000000109',NULL,'Vasculitis co-occurrent and due to Hepatitis B virus infection (disorder)'),('vasculitis',1,'988081000000103',NULL,'Antineutrophil cytoplasmic antibody associated vasculitis caused by drug (disorder)'),('vasculitis',1,'988111000000106',NULL,'Cryoglobulinaemic vasculitis co-occurrent and due to Hepatitis C virus infection (disorder)'),('vasculitis',1,'233948000',NULL,'Pulmonary hypertension in vasculitis'),('vasculitis',1,'703355003',NULL,'Pulmonary hypertension due to vasculitis (disorder)'),('vasculitis',1,'404658009',NULL,'Optic disc vasculitis'),('vasculitis',1,'193177003',NULL,'Polyneuropathy in collagen vascular disease (disorder)'),('vasculitis',1,'472974007',NULL,'History of vasculitis');
INSERT INTO #codessnomed
VALUES ('bmi',2,'301331008',NULL,'Finding of body mass index (finding)');
INSERT INTO #codessnomed
VALUES ('smoking-status-current',1,'266929003',NULL,'Smoking started (life style)'),('smoking-status-current',1,'836001000000109',NULL,'Waterpipe tobacco consumption (observable entity)'),('smoking-status-current',1,'77176002',NULL,'Smoker (life style)'),('smoking-status-current',1,'65568007',NULL,'Cigarette smoker (life style)'),('smoking-status-current',1,'394873005',NULL,'Not interested in stopping smoking (finding)'),('smoking-status-current',1,'394872000',NULL,'Ready to stop smoking (finding)'),('smoking-status-current',1,'394871007',NULL,'Thinking about stopping smoking (observable entity)'),('smoking-status-current',1,'266918002',NULL,'Tobacco smoking consumption (observable entity)'),('smoking-status-current',1,'230057008',NULL,'Cigar consumption (observable entity)'),('smoking-status-current',1,'230056004',NULL,'Cigarette consumption (observable entity)'),('smoking-status-current',1,'160623006',NULL,'Smoking: [started] or [restarted]'),('smoking-status-current',1,'160622001',NULL,'Smoker (& cigarette)'),('smoking-status-current',1,'160619003',NULL,'Rolls own cigarettes (finding)'),('smoking-status-current',1,'160616005',NULL,'Trying to give up smoking (finding)'),('smoking-status-current',1,'160612007',NULL,'Keeps trying to stop smoking (finding)'),('smoking-status-current',1,'160606002',NULL,'Very heavy cigarette smoker (40+ cigs/day) (life style)'),('smoking-status-current',1,'160605003',NULL,'Heavy cigarette smoker (20-39 cigs/day) (life style)'),('smoking-status-current',1,'160604004',NULL,'Moderate cigarette smoker (10-19 cigs/day) (life style)'),('smoking-status-current',1,'160603005',NULL,'Light cigarette smoker (1-9 cigs/day) (life style)'),('smoking-status-current',1,'59978006',NULL,'Cigar smoker (life style)'),('smoking-status-current',1,'446172000',NULL,'Failed attempt to stop smoking (finding)'),('smoking-status-current',1,'413173009',NULL,'Minutes from waking to first tobacco consumption (observable entity)'),('smoking-status-current',1,'401201003',NULL,'Cigarette pack-years (observable entity)'),('smoking-status-current',1,'401159003',NULL,'Reason for restarting smoking (observable entity)'),('smoking-status-current',1,'308438006',NULL,'Smoking restarted (life style)'),('smoking-status-current',1,'230058003',NULL,'Pipe tobacco consumption (observable entity)'),('smoking-status-current',1,'134406006',NULL,'Smoking reduced (observable entity)'),('smoking-status-current',1,'82302008',NULL,'Pipe smoker (life style)');
INSERT INTO #codessnomed
VALUES ('smoking-status-currently-not',1,'160618006',NULL,'Current non-smoker (life style)'),('smoking-status-currently-not',1,'8392000',NULL,'Non-smoker (life style)');
INSERT INTO #codessnomed
VALUES ('smoking-status-ex',1,'160617001',NULL,'Stopped smoking (life style)'),('smoking-status-ex',1,'160620009',NULL,'Ex-pipe smoker (life style)'),('smoking-status-ex',1,'160621008',NULL,'Ex-cigar smoker (life style)'),('smoking-status-ex',1,'160625004',NULL,'Date ceased smoking (observable entity)'),('smoking-status-ex',1,'266922007',NULL,'Ex-light cigarette smoker (1-9/day) (life style)'),('smoking-status-ex',1,'266923002',NULL,'Ex-moderate cigarette smoker (10-19/day) (life style)'),('smoking-status-ex',1,'266924008',NULL,'Ex-heavy cigarette smoker (20-39/day) (life style)'),('smoking-status-ex',1,'266925009',NULL,'Ex-very heavy cigarette smoker (40+/day) (life style)'),('smoking-status-ex',1,'281018007',NULL,'Ex-cigarette smoker (life style)'),('smoking-status-ex',1,'395177003',NULL,'Smoking free weeks (observable entity)'),('smoking-status-ex',1,'492191000000103',NULL,'Ex roll-up cigarette smoker (finding)'),('smoking-status-ex',1,'517211000000106',NULL,'Recently stopped smoking (finding)'),('smoking-status-ex',1,'8517006',NULL,'Ex-smoker (life style)');
INSERT INTO #codessnomed
VALUES ('smoking-status-ex-trivial',1,'266921000',NULL,'Ex-trivial cigarette smoker (<1/day) (life style)');
INSERT INTO #codessnomed
VALUES ('smoking-status-never',1,'160601007',NULL,'Non-smoker (& [never smoked tobacco])'),('smoking-status-never',1,'266919005',NULL,'Never smoked tobacco (life style)');
INSERT INTO #codessnomed
VALUES ('smoking-status-passive',1,'43381005',NULL,'Passive smoker (finding)'),('smoking-status-passive',1,'161080002',NULL,'Passive smoking risk (environment)'),('smoking-status-passive',1,'228523000',NULL,'Exposed to tobacco smoke at work (finding)'),('smoking-status-passive',1,'228524006',NULL,'Exposed to tobacco smoke at home (finding)'),('smoking-status-passive',1,'228525007',NULL,'Exposed to tobacco smoke in public places (finding)'),('smoking-status-passive',1,'713142003',NULL,'At risk from passive smoking (finding)'),('smoking-status-passive',1,'722451000000101',NULL,'Passive smoking (qualifier value)');
INSERT INTO #codessnomed
VALUES ('smoking-status-trivial',1,'266920004',NULL,'Trivial cigarette smoker (less than one cigarette/day) (life style)'),('smoking-status-trivial',1,'428041000124106',NULL,'Occasional tobacco smoker (finding)');
INSERT INTO #codessnomed
VALUES ('covid-vaccination',1,'1240491000000103',NULL,'2019-nCoV (novel coronavirus) vaccination'),('covid-vaccination',1,'2807821000000115',NULL,'2019-nCoV (novel coronavirus) vaccination'),('covid-vaccination',1,'840534001',NULL,'Severe acute respiratory syndrome coronavirus 2 vaccination (procedure)');
INSERT INTO #codessnomed
VALUES ('egfr',1,'1011481000000105',NULL,'eGFR (estimated glomerular filtration rate) using creatinine Chronic Kidney Disease Epidemiology Collaboration equation per 1.73 square metres'),('egfr',1,'1011491000000107',NULL,'eGFR (estimated glomerular filtration rate) using cystatin C Chronic Kidney Disease Epidemiology Collaboration equation per 1.73 square metres'),('egfr',1,'1020291000000106',NULL,'GFR (glomerular filtration rate) calculated by abbreviated Modification of Diet in Renal Disease Study Group calculation'),('egfr',1,'1107411000000104',NULL,'eGFR (estimated glomerular filtration rate) by laboratory calculation'),('egfr',1,'241373003',NULL,'Technetium-99m-diethylenetriamine pentaacetic acid clearance - glomerular filtration rate (procedure)'),('egfr',1,'262300005',NULL,'With glomerular filtration rate'),('egfr',1,'737105002',NULL,'GFR (glomerular filtration rate) calculation technique'),('egfr',1,'80274001',NULL,'Glomerular filtration rate (observable entity)'),('egfr',1,'996231000000108',NULL,'GFR (glomerular filtration rate) calculated by abbreviated Modification of Diet in Renal Disease Study Group calculation adjusted for African American origin');
INSERT INTO #codessnomed
VALUES ('urinary-albumin-creatinine-ratio',1,'271075006',NULL,'Urine albumin/creatinine ratio measurement')

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
VALUES ('chronic-kidney-disease',1,'EMISNQCH20',NULL,'Chronic kidney disease stage 3'),('chronic-kidney-disease',1,'EMISNQCH17',NULL,'Chronic kidney disease stage');
INSERT INTO #codesemis
VALUES ('diabetes',1,'^ESCTGE801661',NULL,'Gestational diabetes, delivered'),('diabetes',1,'^ESCTGE801662',NULL,'Gestational diabetes mellitus complicating pregnancy'),('diabetes',1,'^ESCTMA257526',NULL,'Maternal diabetes mellitus with hypoglycaemia affecting foetus OR newborn'),('diabetes',1,'EMISQNU2',NULL,'Number of admissions for ketoacidosis'),('diabetes',1,'ESCTDI20',NULL,'Diabetic ketoacidosis without coma'),('diabetes',1,'ESCTDI22',NULL,'Diabetic severe hyperglycaemia'),('diabetes',1,'ESCTDI23',NULL,'Diabetic hyperosmolar non-ketotic state'),('diabetes',1,'ESCTDR3',NULL,'Drug-induced diabetes mellitus'),('diabetes',1,'ESCTSE11',NULL,'Secondary endocrine diabetes mellitus');
INSERT INTO #codesemis
VALUES ('hypertension',1,'EMISNQST25',NULL,'Stage 2 hypertension'),('hypertension',1,'^ESCTMA364280',NULL,'Malignant hypertension'),('hypertension',1,'EMISNQST25',NULL,'Stage 2 hypertension');
INSERT INTO #codesemis
VALUES ('covid-vaccination',1,'^ESCT1348323',NULL,'Administration of first dose of SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccine'),('covid-vaccination',1,'^ESCT1348324',NULL,'Administration of first dose of 2019-nCoV (novel coronavirus) vaccine'),('covid-vaccination',1,'COCO138186NEMIS',NULL,'COVID-19 mRNA Vaccine BNT162b2 30micrograms/0.3ml dose concentrate for suspension for injection multidose vials (Pfizer-BioNTech) (Pfizer-BioNTech)'),('covid-vaccination',1,'^ESCT1348325',NULL,'Administration of second dose of SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccine'),('covid-vaccination',1,'^ESCT1348326',NULL,'Administration of second dose of 2019-nCoV (novel coronavirus) vaccine'),('covid-vaccination',1,'^ESCT1428354',NULL,'Administration of third dose of SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccine'),('covid-vaccination',1,'^ESCT1428342',NULL,'Administration of fourth dose of SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccine'),('covid-vaccination',1,'^ESCT1428348',NULL,'Administration of fifth dose of SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccine'),('covid-vaccination',1,'^ESCT1348298',NULL,'SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccination'),('covid-vaccination',1,'^ESCT1348301',NULL,'COVID-19 vaccination'),('covid-vaccination',1,'^ESCT1299050',NULL,'2019-nCoV (novel coronavirus) vaccination'),('covid-vaccination',1,'^ESCT1301222',NULL,'SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccination'),('covid-vaccination',1,'CODI138564NEMIS',NULL,'Covid-19 mRna (nucleoside modified) Vaccine Moderna  Dispersion for injection  0.1 mg/0.5 ml dose, multidose vial'),('covid-vaccination',1,'TASO138184NEMIS',NULL,'Covid-19 Vaccine AstraZeneca (ChAdOx1 S recombinant)  Solution for injection  5x10 billion viral particle/0.5 ml multidose vial'),('covid-vaccination',1,'PCSDT18491_1375',NULL,'Administration of first dose of SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccine'),('covid-vaccination',1,'PCSDT18491_1376',NULL,'Administration of second dose of SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccine'),('covid-vaccination',1,'PCSDT18491_716',NULL,'Administration of second dose of SARS-CoV-2 vacc'),('covid-vaccination',1,'PCSDT18491_903',NULL,'Administration of first dose of SARS-CoV-2 vacccine'),('covid-vaccination',1,'PCSDT3370_2254',NULL,'2019-nCoV (novel coronavirus) vaccination'),('covid-vaccination',1,'PCSDT3919_2185',NULL,'Administration of first dose of SARS-CoV-2 vacccine'),('covid-vaccination',1,'PCSDT3919_662',NULL,'Administration of second dose of SARS-CoV-2 vacc'),('covid-vaccination',1,'PCSDT4803_1723',NULL,'2019-nCoV (novel coronavirus) vaccination'),('covid-vaccination',1,'PCSDT5823_2264',NULL,'Administration of second dose of SARS-CoV-2 vacc'),('covid-vaccination',1,'PCSDT5823_2757',NULL,'Administration of second dose of SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccine'),('covid-vaccination',1,'PCSDT5823_2902',NULL,'Administration of first dose of SARS-CoV-2 vacccine'),('covid-vaccination',1,'^ESCT1348300',NULL,'Severe acute respiratory syndrome coronavirus 2 vaccination'),('covid-vaccination',1,'ASSO138368NEMIS',NULL,'COVID-19 Vaccine Janssen (Ad26.COV2-S [recombinant]) 0.5ml dose suspension for injection multidose vials (Janssen-Cilag Ltd)'),('covid-vaccination',1,'COCO141057NEMIS',NULL,'Comirnaty Children 5-11 years COVID-19 mRNA Vaccine 10micrograms/0.2ml dose concentrate for dispersion for injection multidose vials (Pfizer Ltd)'),('covid-vaccination',1,'COSO141059NEMIS',NULL,'COVID-19 Vaccine Covishield (ChAdOx1 S [recombinant]) 5x10,000,000,000 viral particles/0.5ml dose solution for injection multidose vials (Serum Institute of India)'),('covid-vaccination',1,'COSU138776NEMIS',NULL,'COVID-19 Vaccine Valneva (inactivated adjuvanted whole virus) 40antigen units/0.5ml dose suspension for injection multidose vials (Valneva UK Ltd)'),('covid-vaccination',1,'COSU138943NEMIS',NULL,'COVID-19 Vaccine Novavax (adjuvanted) 5micrograms/0.5ml dose suspension for injection multidose vials (Baxter Oncology GmbH)'),('covid-vaccination',1,'COSU141008NEMIS',NULL,'CoronaVac COVID-19 Vaccine (adjuvanted) 600U/0.5ml dose suspension for injection vials (Sinovac Life Sciences)'),('covid-vaccination',1,'COSU141037NEMIS',NULL,'COVID-19 Vaccine Sinopharm BIBP (inactivated adjuvanted) 6.5U/0.5ml dose suspension for injection vials (Beijing Institute of Biological Products)');
INSERT INTO #codesemis
VALUES ('covid-positive-antigen-test',1,'^ESCT1305304',NULL,'SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antigen detection result positive'),('covid-positive-antigen-test',1,'^ESCT1348538',NULL,'Detection of SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antigen');
INSERT INTO #codesemis
VALUES ('covid-positive-pcr-test',1,'^ESCT1305238',NULL,'SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) RNA (ribonucleic acid) qualitative existence in specimen'),('covid-positive-pcr-test',1,'^ESCT1348314',NULL,'SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) RNA (ribonucleic acid) detection result positive'),('covid-positive-pcr-test',1,'^ESCT1305235',NULL,'SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) RNA (ribonucleic acid) detection result positive'),('covid-positive-pcr-test',1,'^ESCT1300228',NULL,'COVID-19 confirmed by laboratory test GP COVID-19'),('covid-positive-pcr-test',1,'^ESCT1348316',NULL,'2019-nCoV (novel coronavirus) ribonucleic acid detected'),('covid-positive-pcr-test',1,'^ESCT1301223',NULL,'Detection of SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) using polymerase chain reaction technique'),('covid-positive-pcr-test',1,'^ESCT1348359',NULL,'SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) RNA (ribonucleic acid) detection result positive at the limit of detection'),('covid-positive-pcr-test',1,'^ESCT1299053',NULL,'Detection of 2019-nCoV (novel coronavirus) using polymerase chain reaction technique'),('covid-positive-pcr-test',1,'^ESCT1300228',NULL,'COVID-19 confirmed by laboratory test'),('covid-positive-pcr-test',1,'^ESCT1348359',NULL,'SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) RNA (ribonucleic acid) detection result positive at the limit of detection');
INSERT INTO #codesemis
VALUES ('covid-positive-test-other',1,'^ESCT1303928',NULL,'SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) detection result positive'),('covid-positive-test-other',1,'^ESCT1299074',NULL,'2019-nCoV (novel coronavirus) detected'),('covid-positive-test-other',1,'^ESCT1301230',NULL,'SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) detected'),('covid-positive-test-other',1,'EMISNQCO303',NULL,'Confirmed 2019-nCoV (Wuhan) infectio'),('covid-positive-test-other',1,'^ESCT1299075',NULL,'Wuhan 2019-nCoV (novel coronavirus) detected'),('covid-positive-test-other',1,'^ESCT1300229',NULL,'COVID-19 confirmed using clinical diagnostic criteria'),('covid-positive-test-other',1,'^ESCT1348575',NULL,'Detection of SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2)'),('covid-positive-test-other',1,'^ESCT1299074',NULL,'2019-nCoV (novel coronavirus) detected'),('covid-positive-test-other',1,'^ESCT1300229',NULL,'COVID-19 confirmed using clinical diagnostic criteria'),('covid-positive-test-other',1,'EMISNQCO303',NULL,'Confirmed 2019-nCoV (novel coronavirus) infection'),('covid-positive-test-other',1,'EMISNQCO303',NULL,'Confirmed 2019-nCoV (novel coronavirus) infection'),('covid-positive-test-other',1,'^ESCT1348575',NULL,'Detection of SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2)')

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

-- >>> Following code sets injected: egfr v1/urinary-albumin-creatinine-ratio v1/glomerulonephritis v1/kidney-transplant v1/kidney-stones v1/vasculitis v1

---- FIND PATIENTS WITH BIOCHEMICAL EVIDENCE OF CKD

---- find all eGFR and ACR tests

IF OBJECT_ID('tempdb..#EGFR_TESTS') IS NOT NULL DROP TABLE #EGFR_TESTS;
SELECT gp.FK_Patient_Link_ID, 
	CAST(GP.EventDate AS DATE) AS EventDate, 
	[value] = TRY_CONVERT(NUMERIC (18,5), [Value])
INTO #EGFR_TESTS
FROM [RLS].[vw_GP_Events] gp
WHERE 
	(gp.FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE Concept = 'egfr' AND [Version]=1) OR
	 gp.FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE Concept = 'egfr' AND [Version]=1))
		AND gp.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
		AND (gp.EventDate) --BETWEEN '2005-01-01' and 
		<= @EndDate
		AND [Value] IS NOT NULL AND TRY_CONVERT(NUMERIC (18,5), [Value]) <> 0 AND [Value] <> '0' -- REMOVE NULLS AND ZEROES
		AND UPPER([Value]) NOT LIKE '%[A-Z]%' -- REMOVE RECORDS WITH TEXT 

IF OBJECT_ID('tempdb..#ACR_TESTS') IS NOT NULL DROP TABLE #ACR_TESTS;
SELECT gp.FK_Patient_Link_ID, 
	CAST(GP.EventDate AS DATE) AS EventDate, 
	[value] = TRY_CONVERT(NUMERIC (18,5), [Value])
INTO #ACR_TESTS
FROM [RLS].[vw_GP_Events] gp
WHERE 
	(gp.FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE Concept = 'urinary-albumin-creatinine-ratio' AND [Version]=1) OR
	 gp.FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE Concept = 'urinary-albumin-creatinine-ratio'  AND [Version]=1))
		AND gp.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
		AND gp.EventDate --BETWEEN '2005-01-01' and 
		<= @EndDate
		AND [Value] IS NOT NULL AND TRY_CONVERT(NUMERIC (18,5), [Value]) <> 0 AND [Value] <> '0' -- REMOVE NULLS AND ZEROES
		AND UPPER([Value]) NOT LIKE '%[A-Z]%' -- REMOVE RECORDS WITH TEXT 

-- "eGFR < 60 Ml/Min lasting for at least 3 months"

-- For each low egfr we calculate the first date more than 3 months in the future when they also have a low egfr.
IF OBJECT_ID('tempdb..#E1TEMP') IS NOT NULL DROP TABLE #E1TEMP
SELECT E1.FK_Patient_Link_ID, E1.EventDate, MIN(E2.EventDate) AS FirstLowDatePost3Months 
INTO #E1Temp 
FROM #EGFR_TESTS E1
  INNER JOIN #EGFR_TESTS E2 ON
    E1.FK_Patient_Link_ID = E2.FK_Patient_Link_ID AND
    E2.EventDate >= DATEADD(month, 3, E1.EventDate)
WHERE TRY_CONVERT(NUMERIC, E1.Value) < 60 AND TRY_CONVERT(NUMERIC, E2.Value)  < 60
GROUP BY E1.FK_Patient_Link_ID, E1.EventDate;

-- For each low egfr we find the first date after where their egfr wasn't low
IF OBJECT_ID('tempdb..#E2TEMP') IS NOT NULL DROP TABLE #E2TEMP
SELECT E1.FK_Patient_Link_ID, E1.EventDate, MIN(E2.EventDate) AS FirstOkDatePostValue 
INTO #E2Temp 
FROM #EGFR_TESTS E1
  INNER JOIN #EGFR_TESTS E2 ON
    E1.FK_Patient_Link_ID = E2.FK_Patient_Link_ID AND
    E1.EventDate < E2.EventDate 
WHERE TRY_CONVERT(NUMERIC, E1.Value) < 60 AND TRY_CONVERT(NUMERIC, E2.Value) >= 60
GROUP BY E1.FK_Patient_Link_ID, E1.EventDate;

-- We want everyone in the first table REGARDLESS of whether they have a healthy EGFR in between their <60 results
IF OBJECT_ID('tempdb..#EGFR_cohort') IS NOT NULL DROP TABLE #EGFR_cohort
SELECT DISTINCT E1.FK_Patient_Link_ID
INTO #EGFR_cohort
FROM #E1Temp E1
--LEFT OUTER JOIN #E2Temp E2 ON E1.FK_Patient_Link_ID = E2.FK_Patient_Link_ID AND E1.EventDate = E2.EventDate
--WHERE FirstOkDatePostValue IS NULL OR FirstOkDatePostValue > FirstLowDatePost3Months;

-- Create table of patients who have a healthy EGFR in between their <60 results - this will be used to create a flag for these patients
IF OBJECT_ID('tempdb..#EGFR_HealthyResultInbetween') IS NOT NULL DROP TABLE #EGFR_HealthyResultInbetween
SELECT DISTINCT E1.FK_Patient_Link_ID
INTO #EGFR_HealthyResultInbetween
FROM #E1Temp E1
LEFT OUTER JOIN #E2Temp E2 ON E1.FK_Patient_Link_ID = E2.FK_Patient_Link_ID AND E1.EventDate = E2.EventDate
WHERE FirstOkDatePostValue < FirstLowDatePost3Months;

--------------- Same as above but for: "ACR > 3mg/mmol lasting for at least 3 months” ---------------------

-- For each high ACR we calculate the first date more than 3 months in the future when they also have a high ACR.

IF OBJECT_ID('tempdb..#A1TEMP') IS NOT NULL DROP TABLE #A1TEMP
SELECT A1.FK_Patient_Link_ID, A1.EventDate, MIN(A2.EventDate) AS FirstLowDatePost3Months 
INTO #A1Temp 
FROM #ACR_TESTS A1
  INNER JOIN #ACR_TESTS A2 ON
    A1.FK_Patient_Link_ID = A2.FK_Patient_Link_ID AND
    A2.EventDate >= DATEADD(month, 3, A1.EventDate)
WHERE TRY_CONVERT(NUMERIC, A1.Value) >= 3 AND TRY_CONVERT(NUMERIC, A2.Value)  >= 3
GROUP BY A1.FK_Patient_Link_ID, A1.EventDate;

-- For each high ACR we find the first date after where their ACR wasn't high
IF OBJECT_ID('tempdb..#A2TEMP') IS NOT NULL DROP TABLE #A2TEMP
SELECT A1.FK_Patient_Link_ID, A1.EventDate, MIN(A2.EventDate) AS FirstOkDatePostValue 
INTO #A2Temp 
FROM #ACR_TESTS A1
  INNER JOIN #ACR_TESTS A2 ON
    A1.FK_Patient_Link_ID = A2.FK_Patient_Link_ID AND
    A1.EventDate < A2.EventDate 
WHERE TRY_CONVERT(NUMERIC, A1.Value) >= 3 AND TRY_CONVERT(NUMERIC, A2.Value) < 3
GROUP BY A1.FK_Patient_Link_ID, A1.EventDate;

-- We want everyone in the first table REGARDLESS of whether they have a healthy ACR in between their >3 results
IF OBJECT_ID('tempdb..#ACR_cohort') IS NOT NULL DROP TABLE #ACR_cohort
SELECT DISTINCT A1.FK_Patient_Link_ID
INTO #ACR_cohort
FROM #A1Temp A1
--LEFT OUTER JOIN #A2Temp A2 ON A1.FK_Patient_Link_ID = A2.FK_Patient_Link_ID AND A1.EventDate = A2.EventDate
--WHERE FirstOkDatePostValue IS NULL OR FirstOkDatePostValue > FirstLowDatePost3Months;

-- Create table of patients who have a healthy ACR in between their >=3 results - this will be used to create a flag for these patients
IF OBJECT_ID('tempdb..#ACR_HealthyResultInbetween') IS NOT NULL DROP TABLE #ACR_HealthyResultInbetween
SELECT DISTINCT A1.FK_Patient_Link_ID
INTO #ACR_HealthyResultInbetween
FROM #A1Temp A1
LEFT OUTER JOIN #A2Temp A2 ON A1.FK_Patient_Link_ID = A2.FK_Patient_Link_ID AND A1.EventDate = A2.EventDate
WHERE FirstOkDatePostValue < FirstLowDatePost3Months;


-- CREATE TABLE OF PATIENTS THAT HAVE A HISTORY OF KIDNEY DAMAGE (TO BE USED AS EXTRA CRITERIA FOR EGFRs INDICATING CKD STAGE 1 AND 2)

IF OBJECT_ID('tempdb..#kidney_damage') IS NOT NULL DROP TABLE #kidney_damage;
SELECT DISTINCT FK_Patient_Link_ID
INTO #kidney_damage
FROM [RLS].[vw_GP_Events] gp
WHERE (
	gp.FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE Concept IN ('glomerulonephritis', 'kidney-transplant', 'kidney-stones', 'vasculitis') AND [Version]=1) OR
    gp.FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE Concept IN ('glomerulonephritis', 'kidney-transplant', 'kidney-stones', 'vasculitis') AND [Version]=1)
	)
	AND EventDate <= @StartDate

--┌───────────────┐
--│ Year of birth │
--└───────────────┘

-- OBJECTIVE: To get the year of birth for each patient.

-- INPUT: Assumes there exists a temp table as follows:
-- #Patients (FK_Patient_Link_ID)
--  A distinct list of FK_Patient_Link_IDs for each patient in the cohort

-- OUTPUT: A temp table as follows:
-- #PatientYearOfBirth (FK_Patient_Link_ID, YearOfBirth)
-- 	- FK_Patient_Link_ID - unique patient id
--	- YearOfBirth - INT

-- ASSUMPTIONS:
--	- Patient data is obtained from multiple sources. Where patients have multiple YOBs we determine the YOB as follows:
--	-	If the patients has a YOB in their primary care data feed we use that as most likely to be up to date
--	-	If every YOB for a patient is the same, then we use that
--	-	If there is a single most recently updated YOB in the database then we use that
--	-	Otherwise we take the highest YOB for the patient that is not in the future

-- Get all patients year of birth for the cohort
IF OBJECT_ID('tempdb..#AllPatientYearOfBirths') IS NOT NULL DROP TABLE #AllPatientYearOfBirths;
SELECT 
	FK_Patient_Link_ID,
	FK_Reference_Tenancy_ID,
	HDMModifDate,
	YEAR(Dob) AS YearOfBirth
INTO #AllPatientYearOfBirths
FROM SharedCare.Patient p
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
AND Dob IS NOT NULL;


-- If patients have a tenancy id of 2 we take this as their most likely YOB
-- as this is the GP data feed and so most likely to be up to date
IF OBJECT_ID('tempdb..#PatientYearOfBirth') IS NOT NULL DROP TABLE #PatientYearOfBirth;
SELECT FK_Patient_Link_ID, MIN(YearOfBirth) as YearOfBirth INTO #PatientYearOfBirth FROM #AllPatientYearOfBirths
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
AND FK_Reference_Tenancy_ID = 2
GROUP BY FK_Patient_Link_ID
HAVING MIN(YearOfBirth) = MAX(YearOfBirth);

-- Find the patients who remain unmatched
IF OBJECT_ID('tempdb..#UnmatchedYobPatients') IS NOT NULL DROP TABLE #UnmatchedYobPatients;
SELECT FK_Patient_Link_ID INTO #UnmatchedYobPatients FROM #Patients
EXCEPT
SELECT FK_Patient_Link_ID FROM #PatientYearOfBirth;

-- If every YOB is the same for all their linked patient ids then we use that
INSERT INTO #PatientYearOfBirth
SELECT FK_Patient_Link_ID, MIN(YearOfBirth) FROM #AllPatientYearOfBirths
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #UnmatchedYobPatients)
GROUP BY FK_Patient_Link_ID
HAVING MIN(YearOfBirth) = MAX(YearOfBirth);

-- Find any still unmatched patients
TRUNCATE TABLE #UnmatchedYobPatients;
INSERT INTO #UnmatchedYobPatients
SELECT FK_Patient_Link_ID FROM #Patients
EXCEPT
SELECT FK_Patient_Link_ID FROM #PatientYearOfBirth;

-- If there is a unique most recent YOB then use that
INSERT INTO #PatientYearOfBirth
SELECT p.FK_Patient_Link_ID, MIN(p.YearOfBirth) FROM #AllPatientYearOfBirths p
INNER JOIN (
	SELECT FK_Patient_Link_ID, MAX(HDMModifDate) MostRecentDate FROM #AllPatientYearOfBirths
	WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #UnmatchedYobPatients)
	GROUP BY FK_Patient_Link_ID
) sub ON sub.FK_Patient_Link_ID = p.FK_Patient_Link_ID AND sub.MostRecentDate = p.HDMModifDate
GROUP BY p.FK_Patient_Link_ID
HAVING MIN(YearOfBirth) = MAX(YearOfBirth);

-- Find any still unmatched patients
TRUNCATE TABLE #UnmatchedYobPatients;
INSERT INTO #UnmatchedYobPatients
SELECT FK_Patient_Link_ID FROM #Patients
EXCEPT
SELECT FK_Patient_Link_ID FROM #PatientYearOfBirth;

-- Otherwise just use the highest value (with the exception that can't be in the future)
INSERT INTO #PatientYearOfBirth
SELECT FK_Patient_Link_ID, MAX(YearOfBirth) FROM #AllPatientYearOfBirths
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #UnmatchedYobPatients)
GROUP BY FK_Patient_Link_ID
HAVING MAX(YearOfBirth) <= YEAR(GETDATE());

-- Tidy up - helpful in ensuring the tempdb doesn't run out of space mid-query
DROP TABLE #AllPatientYearOfBirths;
DROP TABLE #UnmatchedYobPatients;


-- FIND EARLIEST EGFR AND ACR EVIDENCE OF CKD FOR EACH PATIENT

IF OBJECT_ID('tempdb..#EarliestEvidence') IS NOT NULL DROP TABLE #EarliestEvidence;
SELECT FK_Patient_Link_ID, min(EventDate) as EarliestDate, TestName = 'egfr'
INTO #EarliestEvidence
FROM #E1Temp e
GROUP BY FK_Patient_Link_ID
UNION ALL 
SELECT FK_Patient_Link_ID, min(EventDate) as EarliestDate, TestName = 'acr'
FROM #A1Temp a
GROUP BY FK_Patient_Link_ID

---- CREATE COHORT:
	-- 1. PATIENTS WITH EGFR TESTS INDICATIVE OF CKD STAGES 1-2, PLUS RAISED ACR OR HISTORY OF KIDNEY DAMAGE
	-- 2. PATIENTS WITH EGFR TESTS INDICATIVE OF CKD STAGES 3-5 (AT LEAST 3 MONTHS APART)
	-- 3. PATIENTS WITH ACR TESTS INDICATIVE OF CKD (A3 AND A2) (AT LEAST 3 MONTHS APART)

IF OBJECT_ID('tempdb..#Cohort') IS NOT NULL DROP TABLE #Cohort;
SELECT p.FK_Patient_Link_ID,
		p.EthnicMainGroup,
		yob.YearOfBirth,
		p.DeathDate,
		EvidenceOfCKD_egfr = CASE WHEN p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #EGFR_cohort) 			THEN 1 ELSE 0 END,-- egfr indicating stages 3-5 	
		EvidenceOfCKD_combo = CASE WHEN (p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #EGFR_TESTS where [Value] >= 60) -- egfr indicating stage 1 or 2, with ACR evidence or kidney damage
				AND ((p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #ACR_cohort)) 
					OR p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #kidney_damage)))						THEN 1 ELSE 0 END,
		EvidenceOfCKD_acr = CASE WHEN p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #ACR_cohort) 		THEN 1 ELSE 0 END, -- ACR evidence
		HealthyEgfrResult = CASE WHEN p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #EGFR_HealthyResultInbetween) THEN 1 ELSE 0 END,
		HealthyAcrResult = CASE WHEN p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #ACR_HealthyResultInbetween) THEN 1 ELSE 0 END,
		EarliestEgfrEvidence = egfr.EarliestDate,
		EarliestAcrEvidence = acr.EarliestDate
INTO #Cohort
FROM #Patients p
LEFT OUTER JOIN #PatientYearOfBirth yob ON yob.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #EarliestEvidence egfr 
	ON egfr.FK_Patient_Link_ID = p.FK_Patient_Link_ID AND egfr.TestName = 'egfr' 
LEFT OUTER JOIN #EarliestEvidence acr 
	ON acr.FK_Patient_Link_ID = p.FK_Patient_Link_ID AND acr.TestName = 'acr' 
WHERE 
	(DeathDate < '2022-03-01' OR DeathDate IS NULL) AND
	(YEAR(@StartDate) - YearOfBirth > 18) AND 								-- OVER 18s ONLY
		( 
	p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #EGFR_cohort ) -- egfr indicating stages 3-5
		OR (
	p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #EGFR_TESTS where [Value] >= 60) -- egfr indicating stage 1 or 2, with ACR evidence or kidney damage
			AND ((p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #ACR_cohort)) OR p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #kidney_damage))
			) 
		OR p.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #ACR_cohort) -- ACR evidence
		)

-- TABLE OF GP EVENTS FOR COHORT TO SPEED UP REUSABLE QUERIES

IF OBJECT_ID('tempdb..#PatientEventData') IS NOT NULL DROP TABLE #PatientEventData;
SELECT 
  FK_Patient_Link_ID,
  CAST(EventDate AS DATE) AS EventDate,
  SuppliedCode,
  FK_Reference_SnomedCT_ID,
  FK_Reference_Coding_ID,
  [Value],
  [Units]
INTO #PatientEventData
FROM [RLS].vw_GP_Events
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Cohort);


--Outputs from this reusable query:
-- #Cohort
-- #PatientEventData

---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------


-- >>> Following code sets injected: hypertension v1/diabetes v1/chronic-kidney-disease v1

-- FIND WHICH PATIENTS IN THE COHORT HAD HYPERTENSION OR DIABETES AND THE DATE OF EARLIEST DIAGNOSIS

IF OBJECT_ID('tempdb..#hypertension') IS NOT NULL DROP TABLE #hypertension;
SELECT FK_Patient_Link_ID, MIN(EventDate) as EarliestDiagnosis
INTO #hypertension
FROM #PatientEventData gp
WHERE  (
	gp.FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE Concept = 'hypertension' AND [Version]=1) OR
    gp.FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE Concept = 'hypertension' AND [Version]=1)
	)
GROUP BY FK_Patient_Link_ID

IF OBJECT_ID('tempdb..#diabetes') IS NOT NULL DROP TABLE #diabetes;
SELECT FK_Patient_Link_ID, MIN(EventDate) as EarliestDiagnosis
INTO #diabetes
FROM #PatientEventData gp
WHERE  (
	gp.FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE Concept = 'diabetes' AND [Version]=1) OR
    gp.FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE Concept = 'diabetes' AND [Version]=1)
	)
GROUP BY FK_Patient_Link_ID


IF OBJECT_ID('tempdb..#ckd') IS NOT NULL DROP TABLE #ckd;
SELECT FK_Patient_Link_ID, MIN(EventDate) as EarliestDiagnosis
INTO #ckd
FROM #PatientEventData gp
WHERE  (
	gp.FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE Concept = 'chronic-kidney-disease' AND [Version]=1) OR
    gp.FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE Concept = 'chronic-kidney-disease' AND [Version]=1)
	)
GROUP BY FK_Patient_Link_ID


--┌────────────────────┐
--│ COVID vaccinations │
--└────────────────────┘

-- OBJECTIVE: To obtain a table with first, second, third... etc vaccine doses per patient.

-- ASSUMPTIONS:
--	-	GP records can often be duplicated. The assumption is that if a patient receives
--    two vaccines within 14 days of each other then it is likely that both codes refer
--    to the same vaccine.
--  - The vaccine can appear as a procedure or as a medication. We assume that the
--    presence of either represents a vaccination

-- INPUT: Takes two parameters:
--	- gp-events-table: string - (table name) the name of the table containing the GP events. Usually is "RLS.vw_GP_Events" but can be anything with the columns: FK_Patient_Link_ID, EventDate, and SuppliedCode
--	- gp-medications-table: string - (table name) the name of the table containing the GP medications. Usually is "RLS.vw_GP_Medications" but can be anything with the columns: FK_Patient_Link_ID, EventDate, and SuppliedCode

-- OUTPUT: A temp table as follows:
-- #COVIDVaccinations (FK_Patient_Link_ID, VaccineDate, DaysSinceFirstVaccine)
-- 	- FK_Patient_Link_ID - unique patient id
--	- VaccineDose1Date - date of first vaccine (YYYY-MM-DD)
--	-	VaccineDose2Date - date of second vaccine (YYYY-MM-DD)
--	-	VaccineDose3Date - date of third vaccine (YYYY-MM-DD)
--	-	VaccineDose4Date - date of fourth vaccine (YYYY-MM-DD)
--	-	VaccineDose5Date - date of fifth vaccine (YYYY-MM-DD)
--	-	VaccineDose6Date - date of sixth vaccine (YYYY-MM-DD)
--	-	VaccineDose7Date - date of seventh vaccine (YYYY-MM-DD)

-- Get patients with covid vaccine and earliest and latest date
-- >>> Following code sets injected: covid-vaccination v1


IF OBJECT_ID('tempdb..#VacEvents') IS NOT NULL DROP TABLE #VacEvents;
SELECT FK_Patient_Link_ID, CONVERT(DATE, EventDate) AS EventDate into #VacEvents
FROM #PatientEventData
WHERE SuppliedCode IN (
	SELECT [Code] FROM #AllCodes WHERE [Concept] = 'covid-vaccination' AND [Version] = 1
)
AND EventDate > '2020-12-01'
AND EventDate < '2022-06-01'; --TODO temp addition for COPI expiration

IF OBJECT_ID('tempdb..#VacMeds') IS NOT NULL DROP TABLE #VacMeds;
SELECT FK_Patient_Link_ID, CONVERT(DATE, MedicationDate) AS EventDate into #VacMeds
FROM RLS.vw_GP_Medications
WHERE SuppliedCode IN (
	SELECT [Code] FROM #AllCodes WHERE [Concept] = 'covid-vaccination' AND [Version] = 1
)
AND MedicationDate > '2020-12-01'
AND MedicationDate < '2022-06-01';--TODO temp addition for COPI expiration

IF OBJECT_ID('tempdb..#COVIDVaccines') IS NOT NULL DROP TABLE #COVIDVaccines;
SELECT FK_Patient_Link_ID, EventDate into #COVIDVaccines FROM #VacEvents
UNION
SELECT FK_Patient_Link_ID, EventDate FROM #VacMeds;
--4426892 5m03

-- Tidy up
DROP TABLE #VacEvents;
DROP TABLE #VacMeds;

-- Get first vaccine dose
IF OBJECT_ID('tempdb..#VacTemp1') IS NOT NULL DROP TABLE #VacTemp1;
select FK_Patient_Link_ID, MIN(EventDate) AS VaccineDoseDate
into #VacTemp1
from #COVIDVaccines
group by FK_Patient_Link_ID;
--2046837

-- Get second vaccine dose (if exists) - assume dose within 14 days is same dose
IF OBJECT_ID('tempdb..#VacTemp2') IS NOT NULL DROP TABLE #VacTemp2;
select c.FK_Patient_Link_ID, MIN(c.EventDate) AS VaccineDoseDate
into #VacTemp2
from #VacTemp1 v
inner join #COVIDVaccines c on c.EventDate > DATEADD(day, 14, v.VaccineDoseDate) and c.FK_Patient_Link_ID = v.FK_Patient_Link_ID
group by c.FK_Patient_Link_ID;
--1810762

-- Get third vaccine dose (if exists) - assume dose within 14 days is same dose
IF OBJECT_ID('tempdb..#VacTemp3') IS NOT NULL DROP TABLE #VacTemp3;
select c.FK_Patient_Link_ID, MIN(c.EventDate) AS VaccineDoseDate
into #VacTemp3
from #VacTemp2 v
inner join #COVIDVaccines c on c.EventDate > DATEADD(day, 14, v.VaccineDoseDate) and c.FK_Patient_Link_ID = v.FK_Patient_Link_ID
group by c.FK_Patient_Link_ID;
--578468

-- Get fourth vaccine dose (if exists) - assume dose within 14 days is same dose
IF OBJECT_ID('tempdb..#VacTemp4') IS NOT NULL DROP TABLE #VacTemp4;
select c.FK_Patient_Link_ID, MIN(c.EventDate) AS VaccineDoseDate
into #VacTemp4
from #VacTemp3 v
inner join #COVIDVaccines c on c.EventDate > DATEADD(day, 14, v.VaccineDoseDate) and c.FK_Patient_Link_ID = v.FK_Patient_Link_ID
group by c.FK_Patient_Link_ID;
--1860

-- Get fifth vaccine dose (if exists) - assume dose within 14 days is same dose
IF OBJECT_ID('tempdb..#VacTemp5') IS NOT NULL DROP TABLE #VacTemp5;
select c.FK_Patient_Link_ID, MIN(c.EventDate) AS VaccineDoseDate
into #VacTemp5
from #VacTemp4 v
inner join #COVIDVaccines c on c.EventDate > DATEADD(day, 14, v.VaccineDoseDate) and c.FK_Patient_Link_ID = v.FK_Patient_Link_ID
group by c.FK_Patient_Link_ID;
--39

-- Get sixth vaccine dose (if exists) - assume dose within 14 days is same dose
IF OBJECT_ID('tempdb..#VacTemp6') IS NOT NULL DROP TABLE #VacTemp6;
select c.FK_Patient_Link_ID, MIN(c.EventDate) AS VaccineDoseDate
into #VacTemp6
from #VacTemp5 v
inner join #COVIDVaccines c on c.EventDate > DATEADD(day, 14, v.VaccineDoseDate) and c.FK_Patient_Link_ID = v.FK_Patient_Link_ID
group by c.FK_Patient_Link_ID;
--2

-- Get seventh vaccine dose (if exists) - assume dose within 14 days is same dose
IF OBJECT_ID('tempdb..#VacTemp7') IS NOT NULL DROP TABLE #VacTemp7;
select c.FK_Patient_Link_ID, MIN(c.EventDate) AS VaccineDoseDate
into #VacTemp7
from #VacTemp6 v
inner join #COVIDVaccines c on c.EventDate > DATEADD(day, 14, v.VaccineDoseDate) and c.FK_Patient_Link_ID = v.FK_Patient_Link_ID
group by c.FK_Patient_Link_ID;
--2

IF OBJECT_ID('tempdb..#COVIDVaccinations') IS NOT NULL DROP TABLE #COVIDVaccinations;
SELECT v1.FK_Patient_Link_ID, v1.VaccineDoseDate AS VaccineDose1Date,
v2.VaccineDoseDate AS VaccineDose2Date,
v3.VaccineDoseDate AS VaccineDose3Date,
v4.VaccineDoseDate AS VaccineDose4Date,
v5.VaccineDoseDate AS VaccineDose5Date,
v6.VaccineDoseDate AS VaccineDose6Date,
v7.VaccineDoseDate AS VaccineDose7Date
INTO #COVIDVaccinations
FROM #VacTemp1 v1
LEFT OUTER JOIN #VacTemp2 v2 ON v2.FK_Patient_Link_ID = v1.FK_Patient_Link_ID
LEFT OUTER JOIN #VacTemp3 v3 ON v3.FK_Patient_Link_ID = v1.FK_Patient_Link_ID
LEFT OUTER JOIN #VacTemp4 v4 ON v4.FK_Patient_Link_ID = v1.FK_Patient_Link_ID
LEFT OUTER JOIN #VacTemp5 v5 ON v5.FK_Patient_Link_ID = v1.FK_Patient_Link_ID
LEFT OUTER JOIN #VacTemp6 v6 ON v6.FK_Patient_Link_ID = v1.FK_Patient_Link_ID
LEFT OUTER JOIN #VacTemp7 v7 ON v7.FK_Patient_Link_ID = v1.FK_Patient_Link_ID;

-- Tidy up
DROP TABLE #VacTemp1;
DROP TABLE #VacTemp2;
DROP TABLE #VacTemp3;
DROP TABLE #VacTemp4;
DROP TABLE #VacTemp5;
DROP TABLE #VacTemp6;
DROP TABLE #VacTemp7;


--┌────────────────────┐
--│ Patient GP history │
--└────────────────────┘

-- OBJECTIVE: To produce a table showing the start and end dates for each practice the patient
--            has been registered at.

-- ASSUMPTIONS:
--	-	We do not have data on patients who move out of GM, though we do know that it happened. 
--    For these patients we record the GPPracticeCode as OutOfArea
--  - Where two adjacent time periods either overlap, or have a gap between them, we assume that
--    the most recent registration is more accurate and adjust the end date of the first time
--    period accordingly. This is an infrequent occurrence.

-- INPUT: No pre-requisites

-- OUTPUT: A temp table as follows:
-- #PatientGPHistory (FK_Patient_Link_ID, GPPracticeCode, StartDate, EndDate)
--	- FK_Patient_Link_ID - unique patient id
--	- GPPracticeCode - national GP practice id system
--	- StartDate - date the patient registered at the practice
--	- EndDate - date the patient left the practice

-- First let's get the raw data from the GP history table
IF OBJECT_ID('tempdb..#AllGPHistoryData') IS NOT NULL DROP TABLE #AllGPHistoryData;
SELECT 
	FK_Patient_Link_ID, CASE WHEN GPPracticeCode like 'ZZZ%' THEN 'OutOfArea' ELSE GPPracticeCode END AS GPPracticeCode, 
	CASE WHEN StartDate IS NULL THEN '1900-01-01' ELSE CAST(StartDate AS DATE) END AS StartDate, 
	CASE WHEN EndDate IS NULL THEN '2100-01-01' ELSE CAST(EndDate AS DATE) END AS EndDate 
INTO #AllGPHistoryData FROM rls.vw_Patient_GP_History
WHERE FK_Reference_Tenancy_ID=2 -- limit to GP feed makes it easier than trying to deal with the conflicting data coming from acute care
AND (StartDate < EndDate OR EndDate IS NULL) --Some time periods are instantaneous (start = end) - this ignores them
AND GPPracticeCode IS NOT NULL;
--4147852

IF OBJECT_ID('tempdb..#PatientGPHistory') IS NOT NULL DROP TABLE #PatientGPHistory;
CREATE TABLE #PatientGPHistory(FK_Patient_Link_ID BIGINT, GPPracticeCode NVARCHAR(50), StartDate DATE, EndDate DATE);

IF OBJECT_ID('tempdb..#AllGPHistoryDataOrdered') IS NOT NULL DROP TABLE #AllGPHistoryDataOrdered;
CREATE TABLE #AllGPHistoryDataOrdered(FK_Patient_Link_ID BIGINT, GPPracticeCode NVARCHAR(50), StartDate DATE, EndDate DATE, RowNumber INT);

IF OBJECT_ID('tempdb..#AllGPHistoryDataOrderedJoined') IS NOT NULL DROP TABLE #AllGPHistoryDataOrderedJoined;
CREATE TABLE #AllGPHistoryDataOrderedJoined(
  FK_Patient_Link_ID BIGINT,
  GP1 NVARCHAR(50),
  R1 INT,
  S1 DATE,
  E1 DATE,
  GP2 NVARCHAR(50),
  S2 DATE,
  E2 DATE,
  R2 INT,
);

-- Easier to get rid of everyone who only has one GP history entry
IF OBJECT_ID('tempdb..#PatientGPHistoryJustOneEntryIds') IS NOT NULL DROP TABLE #PatientGPHistoryJustOneEntryIds;
SELECT FK_Patient_Link_ID INTO #PatientGPHistoryJustOneEntryIds FROM #AllGPHistoryData
GROUP BY FK_Patient_Link_ID
HAVING COUNT(*) = 1;

-- Holding table for their data
IF OBJECT_ID('tempdb..#PatientGPHistoryJustOneEntry') IS NOT NULL DROP TABLE #PatientGPHistoryJustOneEntry;
SELECT * INTO #PatientGPHistoryJustOneEntry FROM #AllGPHistoryData
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #PatientGPHistoryJustOneEntryIds);

-- Remove from main table
DELETE FROM #AllGPHistoryData
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #PatientGPHistoryJustOneEntryIds);

DECLARE @size INT;
SET @size = (SELECT COUNT(*) FROM #AllGPHistoryData) + 1;

WHILE(@size > (SELECT COUNT(*) FROM #AllGPHistoryData))
BEGIN
  SET @size = (SELECT COUNT(*) FROM #AllGPHistoryData);

  -- Add row numbers so we can join with next row
  TRUNCATE TABLE #AllGPHistoryDataOrdered;
  INSERT INTO #AllGPHistoryDataOrdered
  SELECT *, ROW_NUMBER() OVER (PARTITION BY FK_Patient_Link_ID ORDER BY StartDate) AS RowNumber from #AllGPHistoryData;

  -- Join each patient row with the next one, but only look at the odd numbers to avoid duplicating
  TRUNCATE TABLE #AllGPHistoryDataOrderedJoined;
  INSERT INTO #AllGPHistoryDataOrderedJoined
  SELECT 
    o1.FK_Patient_Link_ID,o1.GPPracticeCode AS GP1,o1.RowNumber AS R1, 
    o1.StartDate AS S1, o1.EndDate AS E1, o2.GPPracticeCode AS GP2, 
    o2.StartDate as S2, o2.EndDate as E2, o2.RowNumber as R2
  FROM #AllGPHistoryDataOrdered o1
  LEFT OUTER JOIN #AllGPHistoryDataOrdered o2 ON o1.FK_Patient_Link_ID = o2.FK_Patient_Link_ID AND o1.RowNumber = o2.RowNumber - 1
  WHERE o1.RowNumber % 2 = 1
  ORDER BY o1.FK_Patient_Link_ID DESC, o1.StartDate;

  -- If GP is the same, then merge the time periods
  TRUNCATE TABLE #PatientGPHistory;
  INSERT INTO #PatientGPHistory
  SELECT FK_Patient_Link_ID, GP1, S1, CASE WHEN E2 > E1 THEN E2 ELSE E1 END AS E
  FROM #AllGPHistoryDataOrderedJoined
  WHERE GP1 = GP2;

  -- If GP is different, first insert the GP2 record
  INSERT INTO #PatientGPHistory
  SELECT FK_Patient_Link_ID, GP2, S2, E2 FROM #AllGPHistoryDataOrderedJoined
  WHERE GP1 != GP2;

  --  then insert the GP1 record
  INSERT into #PatientGPHistory
  SELECT FK_Patient_Link_ID, GP1, S1, S2 FROM #AllGPHistoryDataOrderedJoined
  WHERE GP1 != GP2;

  -- If the GP2 is null, implies it's the last row and didn't have a subsequent
  -- row to match on, so we just put it back in the gp history table
  INSERT into #PatientGPHistory
  SELECT FK_Patient_Link_ID, GP1, S1, E1 FROM #AllGPHistoryDataOrderedJoined
  WHERE GP2 IS NULL;

  -- Nuke the AllGPHistoryData table
  TRUNCATE TABLE #AllGPHistoryData;

  -- Repopulate with the current "final" snapshot
  INSERT INTO #AllGPHistoryData
  SELECT * FROM #PatientGPHistory;

END

-- Finally re-add the people with only one record
INSERT INTO #PatientGPHistory
SELECT * FROM #PatientGPHistoryJustOneEntry;
--┌───────────────────────────────────────┐
--│ GET practice and ccg for each patient │
--└───────────────────────────────────────┘

-- OBJECTIVE:	For each patient to get the practice id that they are registered to, and 
--						the CCG name that the practice belongs to.

-- INPUT: Assumes there exists a temp table as follows:
-- #Patients (FK_Patient_Link_ID)
--  A distinct list of FK_Patient_Link_IDs for each patient in the cohort

-- OUTPUT: Two temp tables as follows:
-- #PatientPractice (FK_Patient_Link_ID, GPPracticeCode)
--	- FK_Patient_Link_ID - unique patient id
--	- GPPracticeCode - the nationally recognised practice id for the patient
-- #PatientPracticeAndCCG (FK_Patient_Link_ID, GPPracticeCode, CCG)
--	- FK_Patient_Link_ID - unique patient id
--	- GPPracticeCode - the nationally recognised practice id for the patient
--	- CCG - the name of the patient's CCG

-- If patients have a tenancy id of 2 we take this as their most likely GP practice
-- as this is the GP data feed and so most likely to be up to date
IF OBJECT_ID('tempdb..#PatientPractice') IS NOT NULL DROP TABLE #PatientPractice;
SELECT FK_Patient_Link_ID, MIN(GPPracticeCode) as GPPracticeCode INTO #PatientPractice FROM SharedCare.Patient
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
AND FK_Reference_Tenancy_ID = 2
AND GPPracticeCode IS NOT NULL
GROUP BY FK_Patient_Link_ID;
-- 1298467 rows
-- 00:00:11

-- Find the patients who remain unmatched
IF OBJECT_ID('tempdb..#UnmatchedPatientsForPracticeCode') IS NOT NULL DROP TABLE #UnmatchedPatientsForPracticeCode;
SELECT FK_Patient_Link_ID INTO #UnmatchedPatientsForPracticeCode FROM #Patients
EXCEPT
SELECT FK_Patient_Link_ID FROM #PatientPractice;
-- 12702 rows
-- 00:00:00

-- If every GPPracticeCode is the same for all their linked patient ids then we use that
INSERT INTO #PatientPractice
SELECT FK_Patient_Link_ID, MIN(GPPracticeCode) FROM SharedCare.Patient
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #UnmatchedPatientsForPracticeCode)
AND GPPracticeCode IS NOT NULL
GROUP BY FK_Patient_Link_ID
HAVING MIN(GPPracticeCode) = MAX(GPPracticeCode);
-- 12141
-- 00:00:00

-- Find any still unmatched patients
TRUNCATE TABLE #UnmatchedPatientsForPracticeCode;
INSERT INTO #UnmatchedPatientsForPracticeCode
SELECT FK_Patient_Link_ID FROM #Patients
EXCEPT
SELECT FK_Patient_Link_ID FROM #PatientPractice;
-- 561 rows
-- 00:00:00

-- If there is a unique most recent gp practice then we use that
INSERT INTO #PatientPractice
SELECT p.FK_Patient_Link_ID, MIN(p.GPPracticeCode) FROM SharedCare.Patient p
INNER JOIN (
	SELECT FK_Patient_Link_ID, MAX(HDMModifDate) MostRecentDate FROM SharedCare.Patient
	WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #UnmatchedPatientsForPracticeCode)
	GROUP BY FK_Patient_Link_ID
) sub ON sub.FK_Patient_Link_ID = p.FK_Patient_Link_ID AND sub.MostRecentDate = p.HDMModifDate
WHERE p.GPPracticeCode IS NOT NULL
GROUP BY p.FK_Patient_Link_ID
HAVING MIN(GPPracticeCode) = MAX(GPPracticeCode);
-- 15

--┌──────────────────┐
--│ CCG lookup table │
--└──────────────────┘

-- OBJECTIVE: To provide lookup table for CCG names. The GMCR provides the CCG id (e.g. '00T', '01G') but not 
--            the CCG name. This table can be used in other queries when the output is required to be a ccg 
--            name rather than an id.

-- INPUT: No pre-requisites

-- OUTPUT: A temp table as follows:
-- #CCGLookup (CcgId, CcgName)
-- 	- CcgId - Nationally recognised ccg id
--	- CcgName - Bolton, Stockport etc..

IF OBJECT_ID('tempdb..#CCGLookup') IS NOT NULL DROP TABLE #CCGLookup;
CREATE TABLE #CCGLookup (CcgId nchar(3), CcgName nvarchar(20));
INSERT INTO #CCGLookup VALUES ('01G', 'Salford'); 
INSERT INTO #CCGLookup VALUES ('00T', 'Bolton'); 
INSERT INTO #CCGLookup VALUES ('01D', 'HMR'); 
INSERT INTO #CCGLookup VALUES ('02A', 'Trafford'); 
INSERT INTO #CCGLookup VALUES ('01W', 'Stockport');
INSERT INTO #CCGLookup VALUES ('00Y', 'Oldham'); 
INSERT INTO #CCGLookup VALUES ('02H', 'Wigan'); 
INSERT INTO #CCGLookup VALUES ('00V', 'Bury'); 
INSERT INTO #CCGLookup VALUES ('14L', 'Manchester'); 
INSERT INTO #CCGLookup VALUES ('01Y', 'Tameside Glossop'); 

IF OBJECT_ID('tempdb..#PatientPracticeAndCCG') IS NOT NULL DROP TABLE #PatientPracticeAndCCG;
SELECT p.FK_Patient_Link_ID, ISNULL(pp.GPPracticeCode,'') AS GPPracticeCode, ISNULL(ccg.CcgName, '') AS CCG
INTO #PatientPracticeAndCCG
FROM #Patients p
LEFT OUTER JOIN #PatientPractice pp ON pp.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN SharedCare.Reference_GP_Practice gp ON gp.OrganisationCode = pp.GPPracticeCode
LEFT OUTER JOIN #CCGLookup ccg ON ccg.CcgId = gp.Commissioner;

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

--┌───────────────────────┐
--│ Patient GP encounters │
--└───────────────────────┘

-- OBJECTIVE: To produce a table of GP encounters for a list of patients.
-- This script uses many codes related to observations (e.g. blood pressure), symptoms, and diagnoses, to infer when GP encounters occured.
-- This script includes face to face and telephone encounters - it will need copying and editing if you don't require both.

-- ASSUMPTIONS:
--	- multiple codes on the same day will be classed as one encounter (so max daily encounters per patient is 1)

-- INPUT: Assumes there exists a temp table as follows:
-- #Patients (FK_Patient_Link_ID)
--  A distinct list of FK_Patient_Link_IDs for each patient in the cohort

-- Also takes parameters:
--	-	all-patients: boolean - (true/false) if true, then all patients are included, otherwise only those in the pre-existing #Patients table.
--	- gp-events-table: string - (table name) the name of the table containing the GP events. Usually is "RLS.vw_GP_Events" but can be anything with the columns: FK_Patient_Link_ID, EventDate, FK_Reference_Coding_ID, and FK_Reference_SnomedCT_ID
--  - start-date: string - (YYYY-MM-DD) the date to count encounters from.
--  - end-date: string - (YYYY-MM-DD) the date to count encounters to.


-- OUTPUT: A temp table as follows:
-- #GPEncounters (FK_Patient_Link_ID, EncounterDate)
--	- FK_Patient_Link_ID - unique patient id
--	- EncounterDate - date the patient had a GP encounter


-- Create a table with all GP encounters ========================================================================================================

IF OBJECT_ID('tempdb..#CodingClassifier') IS NOT NULL DROP TABLE #CodingClassifier;
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

INSERT INTO #CodingClassifier
SELECT 'Telephone', PK_Reference_Coding_ID, FK_Reference_SnomedCT_ID
FROM SharedCare.Reference_Coding
WHERE CodingType='ReadCodeV2'
AND (
	MainCode like '8H9%'
	or MainCode like '9N31%'
	or MainCode like '9N3A%'
);

-- Add the equivalent CTV3 codes
INSERT INTO #CodingClassifier
SELECT 'Face2face', PK_Reference_Coding_ID, FK_Reference_SnomedCT_ID FROM SharedCare.Reference_Coding
WHERE FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #CodingClassifier WHERE EncounterType='Face2face' AND FK_Reference_SnomedCT_ID != -1)
AND CodingType='CTV3';

INSERT INTO #CodingClassifier
SELECT 'Telephone', PK_Reference_Coding_ID, FK_Reference_SnomedCT_ID FROM SharedCare.Reference_Coding
WHERE FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #CodingClassifier WHERE EncounterType='Telephone' AND FK_Reference_SnomedCT_ID != -1)
AND CodingType='CTV3';

-- Add the equivalent EMIS codes
INSERT INTO #CodingClassifier
SELECT 'Face2face', FK_Reference_Coding_ID, FK_Reference_SnomedCT_ID FROM SharedCare.Reference_Local_Code
WHERE (
	FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #CodingClassifier WHERE EncounterType='Face2face' AND FK_Reference_SnomedCT_ID != -1) OR
	FK_Reference_Coding_ID IN (SELECT PK_Reference_Coding_ID FROM #CodingClassifier WHERE EncounterType='Face2face' AND PK_Reference_Coding_ID != -1)
);
INSERT INTO #CodingClassifier
SELECT 'Telephone', FK_Reference_Coding_ID, FK_Reference_SnomedCT_ID FROM SharedCare.Reference_Local_Code
WHERE (
	FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #CodingClassifier WHERE EncounterType='Telephone' AND FK_Reference_SnomedCT_ID != -1) OR
	FK_Reference_Coding_ID IN (SELECT PK_Reference_Coding_ID FROM #CodingClassifier WHERE EncounterType='Telephone' AND PK_Reference_Coding_ID != -1)
);

-- All above takes ~30s

IF OBJECT_ID('tempdb..#GPEncounters') IS NOT NULL DROP TABLE #GPEncounters;
CREATE TABLE #GPEncounters (
	FK_Patient_Link_ID BIGINT,
	EncounterDate DATE
);

BEGIN
  IF 'false'='true'
    INSERT INTO #GPEncounters 
    SELECT DISTINCT FK_Patient_Link_ID, CAST(EventDate AS DATE) AS EncounterDate
    FROM #PatientEventData
    WHERE 
      FK_Reference_Coding_ID IN (SELECT PK_Reference_Coding_ID FROM #CodingClassifier WHERE PK_Reference_Coding_ID != -1)
      AND EventDate BETWEEN '2018-03-01' AND '2022-03-01'
  ELSE 
    INSERT INTO #GPEncounters 
    SELECT DISTINCT FK_Patient_Link_ID, CAST(EventDate AS DATE) AS EncounterDate
    FROM #PatientEventData
    WHERE 
      FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
      AND FK_Reference_Coding_ID IN (SELECT PK_Reference_Coding_ID FROM #CodingClassifier WHERE PK_Reference_Coding_ID != -1)
      AND EventDate BETWEEN '2018-03-01' AND '2022-03-01'
  END


-- -- FIND NUMBER OF ATTENDED GP APPOINTMENTS FROM MARCH 2018 TO MARCH 2022

IF OBJECT_ID('tempdb..#GPEncounters1') IS NOT NULL DROP TABLE #GPEncounters1;
SELECT FK_Patient_Link_ID, 
	EncounterDate, 
	BeforeOrAfter1stMarch2020 = CASE WHEN EncounterDate < '2020-03-01' THEN 'BEFORE' ELSE 'AFTER' END -- before and after covid started
INTO #GPEncounters1
FROM #GPEncounters

IF OBJECT_ID('tempdb..#GPEncountersCount') IS NOT NULL DROP TABLE #GPEncountersCount;
SELECT FK_Patient_Link_ID, BeforeOrAfter1stMarch2020, COUNT(*) as gp_appointments
INTO #GPEncountersCount
FROM #GPEncounters1
GROUP BY FK_Patient_Link_ID, BeforeOrAfter1stMarch2020
ORDER BY FK_Patient_Link_ID, BeforeOrAfter1stMarch2020

-- FIND NUMBER OF A&E APPOINTMENTS FROM MARCH 2018 TO MARCH 2022

IF OBJECT_ID('tempdb..#ae_encounters') IS NOT NULL DROP TABLE #ae_encounters;
SELECT a.FK_Patient_Link_ID, 
	a.AttendanceDate, 
	BeforeOrAfter1stMarch2020 = CASE WHEN a.AttendanceDate < '2020-03-01' THEN 'BEFORE' ELSE 'AFTER' END -- before and after covid started
INTO #ae_encounters
FROM RLS.vw_Acute_AE a
WHERE EventType = 'Attendance'
AND a.AttendanceDate BETWEEN @StartDate AND @EndDate
AND a.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Cohort) 

SELECT FK_Patient_Link_ID, BeforeOrAfter1stMarch2020, COUNT(*) AS ae_encounters
INTO #AEEncountersCount
FROM #ae_encounters
GROUP BY FK_Patient_Link_ID, BeforeOrAfter1stMarch2020
ORDER BY FK_Patient_Link_ID, BeforeOrAfter1stMarch2020


-- Get patient list of those with COVID death within 28 days of positive test
-- 15.11.22: updated to deal with '28 days' flag over-reporting

-- IF OBJECT_ID('tempdb..#COVIDDeath') IS NOT NULL DROP TABLE #COVIDDeath;
-- SELECT DISTINCT FK_Patient_Link_ID 
-- INTO #COVIDDeath FROM RLS.vw_COVID19
-- WHERE DeathWithin28Days = 'Y'
-- AND EventDate <= @EndDate
-- AND (
--   (GroupDescription = 'Confirmed' AND SubGroupDescription != 'Negative') OR
--   (GroupDescription = 'Tested' AND SubGroupDescription = 'Positive')
-- );

IF OBJECT_ID('tempdb..#COVIDDeath') IS NOT NULL DROP TABLE #COVIDDeath;
SELECT DISTINCT FK_Patient_Link_ID 
INTO #COVIDDeath FROM SharedCare.COVID19
WHERE (
	(GroupDescription = 'Confirmed' AND SubGroupDescription != 'Negative') OR
	(GroupDescription = 'Tested' AND SubGroupDescription = 'Positive')
)
AND FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Cohort)
AND DATEDIFF(day,EventDate,DeathDate) <= 28
AND EventDate < '2022-03-01';


--┌─────┐
--│ Sex │
--└─────┘

-- OBJECTIVE: To get the Sex for each patient.

-- INPUT: Assumes there exists a temp table as follows:
-- #Patients (FK_Patient_Link_ID)
--  A distinct list of FK_Patient_Link_IDs for each patient in the cohort

-- OUTPUT: A temp table as follows:
-- #PatientSex (FK_Patient_Link_ID, Sex)
-- 	- FK_Patient_Link_ID - unique patient id
--	- Sex - M/F

-- ASSUMPTIONS:
--	- Patient data is obtained from multiple sources. Where patients have multiple sexes we determine the sex as follows:
--	-	If the patients has a sex in their primary care data feed we use that as most likely to be up to date
--	-	If every sex for a patient is the same, then we use that
--	-	If there is a single most recently updated sex in the database then we use that
--	-	Otherwise the patient's sex is considered unknown

-- Get all patients sex for the cohort
IF OBJECT_ID('tempdb..#AllPatientSexs') IS NOT NULL DROP TABLE #AllPatientSexs;
SELECT 
	FK_Patient_Link_ID,
	FK_Reference_Tenancy_ID,
	HDMModifDate,
	Sex
INTO #AllPatientSexs
FROM SharedCare.Patient p
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
AND Sex IS NOT NULL;


-- If patients have a tenancy id of 2 we take this as their most likely Sex
-- as this is the GP data feed and so most likely to be up to date
IF OBJECT_ID('tempdb..#PatientSex') IS NOT NULL DROP TABLE #PatientSex;
SELECT FK_Patient_Link_ID, MIN(Sex) as Sex INTO #PatientSex FROM #AllPatientSexs
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
AND FK_Reference_Tenancy_ID = 2
GROUP BY FK_Patient_Link_ID
HAVING MIN(Sex) = MAX(Sex);

-- Find the patients who remain unmatched
IF OBJECT_ID('tempdb..#UnmatchedSexPatients') IS NOT NULL DROP TABLE #UnmatchedSexPatients;
SELECT FK_Patient_Link_ID INTO #UnmatchedSexPatients FROM #Patients
EXCEPT
SELECT FK_Patient_Link_ID FROM #PatientSex;

-- If every Sex is the same for all their linked patient ids then we use that
INSERT INTO #PatientSex
SELECT FK_Patient_Link_ID, MIN(Sex) FROM #AllPatientSexs
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #UnmatchedSexPatients)
GROUP BY FK_Patient_Link_ID
HAVING MIN(Sex) = MAX(Sex);

-- Find any still unmatched patients
TRUNCATE TABLE #UnmatchedSexPatients;
INSERT INTO #UnmatchedSexPatients
SELECT FK_Patient_Link_ID FROM #Patients
EXCEPT
SELECT FK_Patient_Link_ID FROM #PatientSex;

-- If there is a unique most recent Sex then use that
INSERT INTO #PatientSex
SELECT p.FK_Patient_Link_ID, MIN(p.Sex) FROM #AllPatientSexs p
INNER JOIN (
	SELECT FK_Patient_Link_ID, MAX(HDMModifDate) MostRecentDate FROM #AllPatientSexs
	WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #UnmatchedSexPatients)
	GROUP BY FK_Patient_Link_ID
) sub ON sub.FK_Patient_Link_ID = p.FK_Patient_Link_ID AND sub.MostRecentDate = p.HDMModifDate
GROUP BY p.FK_Patient_Link_ID
HAVING MIN(Sex) = MAX(Sex);

-- Tidy up - helpful in ensuring the tempdb doesn't run out of space mid-query
DROP TABLE #AllPatientSexs;
DROP TABLE #UnmatchedSexPatients;
--┌────────────────────────────┐
--│ Index Multiple Deprivation │
--└────────────────────────────┘

-- OBJECTIVE: To get the 2019 Index of Multiple Deprivation (IMD) decile for each patient.

-- INPUT: Assumes there exists a temp table as follows:
-- #Patients (FK_Patient_Link_ID)
--  A distinct list of FK_Patient_Link_IDs for each patient in the cohort

-- OUTPUT: A temp table as follows:
-- #PatientIMDDecile (FK_Patient_Link_ID, IMD2019Decile1IsMostDeprived10IsLeastDeprived)
-- 	- FK_Patient_Link_ID - unique patient id
--	- IMD2019Decile1IsMostDeprived10IsLeastDeprived - number 1 to 10 inclusive

-- Get all patients IMD_Score (which is a rank) for the cohort and map to decile
-- (Data on mapping thresholds at: https://www.gov.uk/government/statistics/english-indices-of-deprivation-2019
IF OBJECT_ID('tempdb..#AllPatientIMDDeciles') IS NOT NULL DROP TABLE #AllPatientIMDDeciles;
SELECT 
	FK_Patient_Link_ID,
	FK_Reference_Tenancy_ID,
	HDMModifDate,
	CASE 
		WHEN IMD_Score <= 3284 THEN 1
		WHEN IMD_Score <= 6568 THEN 2
		WHEN IMD_Score <= 9853 THEN 3
		WHEN IMD_Score <= 13137 THEN 4
		WHEN IMD_Score <= 16422 THEN 5
		WHEN IMD_Score <= 19706 THEN 6
		WHEN IMD_Score <= 22990 THEN 7
		WHEN IMD_Score <= 26275 THEN 8
		WHEN IMD_Score <= 29559 THEN 9
		ELSE 10
	END AS IMD2019Decile1IsMostDeprived10IsLeastDeprived 
INTO #AllPatientIMDDeciles
FROM SharedCare.Patient p
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
AND IMD_Score IS NOT NULL
AND IMD_Score != -1;
-- 972479 rows
-- 00:00:11

-- If patients have a tenancy id of 2 we take this as their most likely IMD_Score
-- as this is the GP data feed and so most likely to be up to date
IF OBJECT_ID('tempdb..#PatientIMDDecile') IS NOT NULL DROP TABLE #PatientIMDDecile;
SELECT FK_Patient_Link_ID, MIN(IMD2019Decile1IsMostDeprived10IsLeastDeprived) as IMD2019Decile1IsMostDeprived10IsLeastDeprived INTO #PatientIMDDecile FROM #AllPatientIMDDeciles
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
AND FK_Reference_Tenancy_ID = 2
GROUP BY FK_Patient_Link_ID;
-- 247377 rows
-- 00:00:00

-- Find the patients who remain unmatched
IF OBJECT_ID('tempdb..#UnmatchedImdPatients') IS NOT NULL DROP TABLE #UnmatchedImdPatients;
SELECT FK_Patient_Link_ID INTO #UnmatchedImdPatients FROM #Patients
EXCEPT
SELECT FK_Patient_Link_ID FROM #PatientIMDDecile;
-- 38710 rows
-- 00:00:00

-- If every IMD_Score is the same for all their linked patient ids then we use that
INSERT INTO #PatientIMDDecile
SELECT FK_Patient_Link_ID, MIN(IMD2019Decile1IsMostDeprived10IsLeastDeprived) FROM #AllPatientIMDDeciles
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #UnmatchedImdPatients)
GROUP BY FK_Patient_Link_ID
HAVING MIN(IMD2019Decile1IsMostDeprived10IsLeastDeprived) = MAX(IMD2019Decile1IsMostDeprived10IsLeastDeprived);
-- 36656
-- 00:00:00

-- Find any still unmatched patients
TRUNCATE TABLE #UnmatchedImdPatients;
INSERT INTO #UnmatchedImdPatients
SELECT FK_Patient_Link_ID FROM #Patients
EXCEPT
SELECT FK_Patient_Link_ID FROM #PatientIMDDecile;
-- 2054 rows
-- 00:00:00

-- If there is a unique most recent imd decile then use that
INSERT INTO #PatientIMDDecile
SELECT p.FK_Patient_Link_ID, MIN(p.IMD2019Decile1IsMostDeprived10IsLeastDeprived) FROM #AllPatientIMDDeciles p
INNER JOIN (
	SELECT FK_Patient_Link_ID, MAX(HDMModifDate) MostRecentDate FROM #AllPatientIMDDeciles
	WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #UnmatchedImdPatients)
	GROUP BY FK_Patient_Link_ID
) sub ON sub.FK_Patient_Link_ID = p.FK_Patient_Link_ID AND sub.MostRecentDate = p.HDMModifDate
GROUP BY p.FK_Patient_Link_ID
HAVING MIN(IMD2019Decile1IsMostDeprived10IsLeastDeprived) = MAX(IMD2019Decile1IsMostDeprived10IsLeastDeprived);
-- 489
-- 00:00:00
--┌───────────────────────────────┐
--│ Lower level super output area │
--└───────────────────────────────┘

-- OBJECTIVE: To get the LSOA for each patient.

-- INPUT: Assumes there exists a temp table as follows:
-- #Patients (FK_Patient_Link_ID)
--  A distinct list of FK_Patient_Link_IDs for each patient in the cohort

-- OUTPUT: A temp table as follows:
-- #PatientLSOA (FK_Patient_Link_ID, LSOA)
-- 	- FK_Patient_Link_ID - unique patient id
--	- LSOA_Code - nationally recognised LSOA identifier

-- ASSUMPTIONS:
--	- Patient data is obtained from multiple sources. Where patients have multiple LSOAs we determine the LSOA as follows:
--	-	If the patients has an LSOA in their primary care data feed we use that as most likely to be up to date
--	-	If every LSOA for a paitent is the same, then we use that
--	-	If there is a single most recently updated LSOA in the database then we use that
--	-	Otherwise the patient's LSOA is considered unknown

-- Get all patients LSOA for the cohort
IF OBJECT_ID('tempdb..#AllPatientLSOAs') IS NOT NULL DROP TABLE #AllPatientLSOAs;
SELECT 
	FK_Patient_Link_ID,
	FK_Reference_Tenancy_ID,
	HDMModifDate,
	LSOA_Code
INTO #AllPatientLSOAs
FROM SharedCare.Patient p
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
AND LSOA_Code IS NOT NULL;


-- If patients have a tenancy id of 2 we take this as their most likely LSOA_Code
-- as this is the GP data feed and so most likely to be up to date
IF OBJECT_ID('tempdb..#PatientLSOA') IS NOT NULL DROP TABLE #PatientLSOA;
SELECT FK_Patient_Link_ID, MIN(LSOA_Code) as LSOA_Code INTO #PatientLSOA FROM #AllPatientLSOAs
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
AND FK_Reference_Tenancy_ID = 2
GROUP BY FK_Patient_Link_ID
HAVING MIN(LSOA_Code) = MAX(LSOA_Code);

-- Find the patients who remain unmatched
IF OBJECT_ID('tempdb..#UnmatchedLsoaPatients') IS NOT NULL DROP TABLE #UnmatchedLsoaPatients;
SELECT FK_Patient_Link_ID INTO #UnmatchedLsoaPatients FROM #Patients
EXCEPT
SELECT FK_Patient_Link_ID FROM #PatientLSOA;
-- 38710 rows
-- 00:00:00

-- If every LSOA_Code is the same for all their linked patient ids then we use that
INSERT INTO #PatientLSOA
SELECT FK_Patient_Link_ID, MIN(LSOA_Code) FROM #AllPatientLSOAs
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #UnmatchedLsoaPatients)
GROUP BY FK_Patient_Link_ID
HAVING MIN(LSOA_Code) = MAX(LSOA_Code);

-- Find any still unmatched patients
TRUNCATE TABLE #UnmatchedLsoaPatients;
INSERT INTO #UnmatchedLsoaPatients
SELECT FK_Patient_Link_ID FROM #Patients
EXCEPT
SELECT FK_Patient_Link_ID FROM #PatientLSOA;

-- If there is a unique most recent lsoa then use that
INSERT INTO #PatientLSOA
SELECT p.FK_Patient_Link_ID, MIN(p.LSOA_Code) FROM #AllPatientLSOAs p
INNER JOIN (
	SELECT FK_Patient_Link_ID, MAX(HDMModifDate) MostRecentDate FROM #AllPatientLSOAs
	WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #UnmatchedLsoaPatients)
	GROUP BY FK_Patient_Link_ID
) sub ON sub.FK_Patient_Link_ID = p.FK_Patient_Link_ID AND sub.MostRecentDate = p.HDMModifDate
GROUP BY p.FK_Patient_Link_ID
HAVING MIN(LSOA_Code) = MAX(LSOA_Code);

-- Tidy up - helpful in ensuring the tempdb doesn't run out of space mid-query
DROP TABLE #AllPatientLSOAs;
DROP TABLE #UnmatchedLsoaPatients;
--┌─────┐
--│ BMI │
--└─────┘

-- OBJECTIVE: To get the BMI for each patient in a cohort.

-- INPUT: Assumes there exists a temp table as follows:
-- #Patients (FK_Patient_Link_ID)
--  A distinct list of FK_Patient_Link_IDs for each patient in the cohort
-- Also takes one parameter:
--	- gp-events-table: string - (table name) the name of the table containing the GP events. Usually is "RLS.vw_GP_Events" but can be anything with the columns: FK_Patient_Link_ID, EventDate, FK_Reference_Coding_ID, and FK_Reference_SnomedCT_ID
-- Also assumes there is an @IndexDate defined - The index date of the study


-- OUTPUT: A temp table as follows:
-- #PatientBMI (FK_Patient_Link_ID, BMI, DateOfBMIMeasurement)
--	- FK_Patient_Link_ID - unique patient id
--  - BMI
--  - DateOfBMIMeasurement

-- ASSUMPTIONS:
--	- We take the measurement closest to @IndexDate to be correct

-- >>> Following code sets injected: bmi v2

-- Get all BMI measurements 

IF OBJECT_ID('tempdb..#AllPatientBMI') IS NOT NULL DROP TABLE #AllPatientBMI;
SELECT 
	FK_Patient_Link_ID,
	CAST(EventDate AS DATE) AS EventDate,
	FK_Reference_Coding_ID,
	FK_Reference_SnomedCT_ID,
	[Value]
INTO #AllPatientBMI
FROM #PatientEventData
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
	AND FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE Concept = 'bmi'AND [Version]=2) 
	AND EventDate <= @IndexDate
	AND TRY_CONVERT(NUMERIC(16,5), [Value]) BETWEEN 5 AND 100

UNION
SELECT 
	FK_Patient_Link_ID,
	CAST(EventDate AS DATE) AS EventDate,
	FK_Reference_Coding_ID,
	FK_Reference_SnomedCT_ID,
	[Value]
FROM #PatientEventData
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
	AND FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE Concept = 'bmi' AND [Version]=2)
	AND EventDate <= @IndexDate
	AND TRY_CONVERT(NUMERIC(16,5), [Value]) BETWEEN 5 AND 100


-- For closest BMI prior to index date
IF OBJECT_ID('tempdb..#TempCurrentBMI') IS NOT NULL DROP TABLE #TempCurrentBMI;
SELECT 
	a.FK_Patient_Link_ID, 
	Max([Value]) as [Value],
	Max(EventDate) as EventDate
INTO #TempCurrentBMI
FROM #AllPatientBMI a
INNER JOIN (
	SELECT FK_Patient_Link_ID, MAX(EventDate) AS MostRecentDate 
	FROM #AllPatientBMI
	GROUP BY FK_Patient_Link_ID
) sub ON sub.MostRecentDate = a.EventDate and sub.FK_Patient_Link_ID = a.FK_Patient_Link_ID
GROUP BY a.FK_Patient_Link_ID;

-- Bring all together in final table
IF OBJECT_ID('tempdb..#PatientBMI') IS NOT NULL DROP TABLE #PatientBMI;
SELECT 
	p.FK_Patient_Link_ID,
	BMI = TRY_CONVERT(NUMERIC(16,5), [Value]),
	EventDate AS DateOfBMIMeasurement
INTO #PatientBMI 
FROM #Patients p
LEFT OUTER JOIN #TempCurrentBMI c on c.FK_Patient_Link_ID = p.FK_Patient_Link_ID
--┌────────────────┐
--│ Smoking status │
--└────────────────┘

-- OBJECTIVE: To get the smoking status for each patient in a cohort.

-- INPUT: Assumes there exists a temp table as follows:
-- #Patients (FK_Patient_Link_ID)
--  A distinct list of FK_Patient_Link_IDs for each patient in the cohort
-- Also takes one parameter:
--	- gp-events-table: string - (table name) the name of the table containing the GP events. Usually is "RLS.vw_GP_Events" but can be anything with the columns: FK_Patient_Link_ID, EventDate, FK_Reference_Coding_ID, and FK_Reference_SnomedCT_ID

-- OUTPUT: A temp table as follows:
-- #PatientSmokingStatus (FK_Patient_Link_ID, PassiveSmoker, WorstSmokingStatus, CurrentSmokingStatus)
--	- FK_Patient_Link_ID - unique patient id
--	- PassiveSmoker - Y/N (whether a patient has ever had a code for passive smoking)
--	- WorstSmokingStatus - [non-trivial-smoker/trivial-smoker/non-smoker]
--	- CurrentSmokingStatus - [non-trivial-smoker/trivial-smoker/non-smoker]

-- ASSUMPTIONS:
--	- We take the most recent smoking status in a patient's record to be correct
--	- However, there is likely confusion between the "non smoker" and "never smoked" codes. Especially as sometimes the synonyms for these codes overlap. Therefore, a patient wih a most recent smoking status of "never", but who has previous smoking codes, would be classed as WorstSmokingStatus=non-trivial-smoker / CurrentSmokingStatus=non-smoker

-- >>> Following code sets injected: smoking-status-current v1/smoking-status-currently-not v1/smoking-status-ex v1/smoking-status-ex-trivial v1/smoking-status-never v1/smoking-status-passive v1/smoking-status-trivial v1
-- Get all patients year of birth for the cohort
IF OBJECT_ID('tempdb..#AllPatientSmokingStatusCodes') IS NOT NULL DROP TABLE #AllPatientSmokingStatusCodes;
SELECT 
	FK_Patient_Link_ID,
	CAST(EventDate AS DATE) AS EventDate,
	FK_Reference_Coding_ID,
	FK_Reference_SnomedCT_ID
INTO #AllPatientSmokingStatusCodes
FROM #PatientEventData
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
AND FK_Reference_SnomedCT_ID IN (
	SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets 
	WHERE Concept IN (
		'smoking-status-current',
		'smoking-status-currently-not',
		'smoking-status-ex',
		'smoking-status-ex-trivial',
		'smoking-status-never',
		'smoking-status-passive',
		'smoking-status-trivial'
	)
	AND [Version]=1
) 
UNION
SELECT 
	FK_Patient_Link_ID,
	CAST(EventDate AS DATE) AS EventDate,
	FK_Reference_Coding_ID,
	FK_Reference_SnomedCT_ID
FROM #PatientEventData
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
AND FK_Reference_Coding_ID IN (
	SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets 
	WHERE Concept IN (
		'smoking-status-current',
		'smoking-status-currently-not',
		'smoking-status-ex',
		'smoking-status-ex-trivial',
		'smoking-status-never',
		'smoking-status-passive',
		'smoking-status-trivial'
	)
	AND [Version]=1
);

IF OBJECT_ID('tempdb..#AllPatientSmokingStatusConcept') IS NOT NULL DROP TABLE #AllPatientSmokingStatusConcept;
SELECT 
	a.FK_Patient_Link_ID,
	EventDate,
	CASE WHEN c.Concept IS NULL THEN s.Concept ELSE c.Concept END AS Concept,
	-1 AS SeverityWorst,
	-1 AS SeverityCurrent
INTO #AllPatientSmokingStatusConcept
FROM #AllPatientSmokingStatusCodes a
LEFT OUTER JOIN #VersionedCodeSets c on c.FK_Reference_Coding_ID = a.FK_Reference_Coding_ID
LEFT OUTER JOIN #VersionedSnomedSets s on s.FK_Reference_SnomedCT_ID = a.FK_Reference_SnomedCT_ID;

UPDATE #AllPatientSmokingStatusConcept
SET SeverityWorst = 2, 
	SeverityCurrent = 2
WHERE Concept IN ('smoking-status-current');
UPDATE #AllPatientSmokingStatusConcept
SET SeverityWorst = 2, 
	SeverityCurrent = 0
WHERE Concept IN ('smoking-status-ex');
UPDATE #AllPatientSmokingStatusConcept
SET SeverityWorst = 1,	
	SeverityCurrent = 0
WHERE Concept IN ('smoking-status-ex-trivial');
UPDATE #AllPatientSmokingStatusConcept
SET SeverityWorst = 1,
	SeverityCurrent = 1
WHERE Concept IN ('smoking-status-trivial');
UPDATE #AllPatientSmokingStatusConcept
SET SeverityWorst = 0,
	SeverityCurrent = 0
WHERE Concept IN ('smoking-status-never');
UPDATE #AllPatientSmokingStatusConcept
SET SeverityWorst = 0,
	SeverityCurrent = 0
WHERE Concept IN ('smoking-status-currently-not');

-- passive smokers
IF OBJECT_ID('tempdb..#TempPassiveSmokers') IS NOT NULL DROP TABLE #TempPassiveSmokers;
select DISTINCT FK_Patient_Link_ID into #TempPassiveSmokers from #AllPatientSmokingStatusConcept
where Concept = 'smoking-status-passive';

-- For "worst" smoking status
IF OBJECT_ID('tempdb..#TempWorst') IS NOT NULL DROP TABLE #TempWorst;
SELECT 
	FK_Patient_Link_ID, 
	CASE 
		WHEN MAX(SeverityWorst) = 2 THEN 'non-trivial-smoker'
		WHEN MAX(SeverityWorst) = 1 THEN 'trivial-smoker'
		WHEN MAX(SeverityWorst) = 0 THEN 'non-smoker'
	END AS [Status]
INTO #TempWorst
FROM #AllPatientSmokingStatusConcept
WHERE SeverityWorst >= 0
GROUP BY FK_Patient_Link_ID;

-- For "current" smoking status
IF OBJECT_ID('tempdb..#TempCurrent') IS NOT NULL DROP TABLE #TempCurrent;
SELECT 
	a.FK_Patient_Link_ID, 
	CASE 
		WHEN MAX(SeverityCurrent) = 2 THEN 'non-trivial-smoker'
		WHEN MAX(SeverityCurrent) = 1 THEN 'trivial-smoker'
		WHEN MAX(SeverityCurrent) = 0 THEN 'non-smoker'
	END AS [Status]
INTO #TempCurrent
FROM #AllPatientSmokingStatusConcept a
INNER JOIN (
	SELECT FK_Patient_Link_ID, MAX(EventDate) AS MostRecentDate FROM #AllPatientSmokingStatusConcept
	WHERE SeverityCurrent >= 0
	GROUP BY FK_Patient_Link_ID
) sub ON sub.MostRecentDate = a.EventDate and sub.FK_Patient_Link_ID = a.FK_Patient_Link_ID
GROUP BY a.FK_Patient_Link_ID;

-- Bring all together in final table
IF OBJECT_ID('tempdb..#PatientSmokingStatus') IS NOT NULL DROP TABLE #PatientSmokingStatus;
SELECT 
	p.FK_Patient_Link_ID,
	CASE WHEN ps.FK_Patient_Link_ID IS NULL THEN 'N' ELSE 'Y' END AS PassiveSmoker,
	CASE WHEN w.[Status] IS NULL THEN 'unknown-smoking-status' ELSE w.[Status] END AS WorstSmokingStatus,
	CASE WHEN c.[Status] IS NULL THEN 'unknown-smoking-status' ELSE c.[Status] END AS CurrentSmokingStatus
INTO #PatientSmokingStatus FROM #Patients p
LEFT OUTER JOIN #TempPassiveSmokers ps on ps.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #TempWorst w on w.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #TempCurrent c on c.FK_Patient_Link_ID = p.FK_Patient_Link_ID;
--┌────────────────┐
--│ Alcohol Intake │
--└────────────────┘

-- OBJECTIVE: To get the alcohol status for each patient in a cohort.

-- INPUT: Assumes there exists a temp table as follows:
-- #Patients (FK_Patient_Link_ID)
--  A distinct list of FK_Patient_Link_IDs for each patient in the cohort
-- Also takes one parameter:
--	- gp-events-table: string - (table name) the name of the table containing the GP events. Usually is "RLS.vw_GP_Events" but can be anything with the columns: FK_Patient_Link_ID, EventDate, FK_Reference_Coding_ID, and FK_Reference_SnomedCT_ID

-- OUTPUT: A temp table as follows:
-- #PatientAlcoholIntake (FK_Patient_Link_ID, CurrentAlcoholIntake)
--	- FK_Patient_Link_ID - unique patient id
--  - WorstAlcoholIntake - [heavy drinker/moderate drinker/light drinker/non-drinker] - worst code
--	- CurrentAlcoholIntake - [heavy drinker/moderate drinker/light drinker/non-drinker] - most recent code

-- ASSUMPTIONS:
--	- We take the most recent alcohol intake code in a patient's record to be correct

-- >>> Following code sets injected: alcohol-non-drinker v1/alcohol-light-drinker v1/alcohol-moderate-drinker v1/alcohol-heavy-drinker v1/alcohol-weekly-intake v1

-- Get all patients year of birth for the cohort
IF OBJECT_ID('tempdb..#AllPatientAlcoholIntakeCodes') IS NOT NULL DROP TABLE #AllPatientAlcoholIntakeCodes;
SELECT 
	FK_Patient_Link_ID,
	CAST(EventDate AS DATE) AS EventDate,
	FK_Reference_Coding_ID,
	FK_Reference_SnomedCT_ID,
	[Value]
INTO #AllPatientAlcoholIntakeCodes
FROM #PatientEventData
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
AND FK_Reference_SnomedCT_ID IN (
	SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets 
	WHERE Concept IN (
	'alcohol-non-drinker', 
	'alcohol-light-drinker',
	'alcohol-moderate-drinker',
	'alcohol-heavy-drinker',
	'alcohol-weekly-intake'
	)
	AND [Version]=1
) 
UNION
SELECT 
	FK_Patient_Link_ID,
	CAST(EventDate AS DATE) AS EventDate,
	FK_Reference_Coding_ID,
	FK_Reference_SnomedCT_ID,
	[Value]
FROM #PatientEventData
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
AND FK_Reference_Coding_ID IN (
	SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets 
	WHERE Concept IN (
	'alcohol-non-drinker', 
	'alcohol-light-drinker',
	'alcohol-moderate-drinker',
	'alcohol-heavy-drinker',
	'alcohol-weekly-intake'
	)
	AND [Version]=1
);

IF OBJECT_ID('tempdb..#AllPatientAlcoholIntakeConcept') IS NOT NULL DROP TABLE #AllPatientAlcoholIntakeConcept;
SELECT 
	a.FK_Patient_Link_ID,
	EventDate,
	CASE WHEN c.Concept IS NULL THEN s.Concept ELSE c.Concept END AS Concept,
	-1 AS Severity,
	[Value]
INTO #AllPatientAlcoholIntakeConcept
FROM #AllPatientAlcoholIntakeCodes a
LEFT OUTER JOIN #VersionedCodeSets c on c.FK_Reference_Coding_ID = a.FK_Reference_Coding_ID
LEFT OUTER JOIN #VersionedSnomedSets s on s.FK_Reference_SnomedCT_ID = a.FK_Reference_SnomedCT_ID;

UPDATE #AllPatientAlcoholIntakeConcept
SET Severity = 3
WHERE Concept = 'alcohol-heavy-drinker' OR (Concept = 'alcohol-weekly-intake' AND TRY_CONVERT(NUMERIC(16,5), [Value]) > 14) ;
UPDATE #AllPatientAlcoholIntakeConcept
SET Severity = 2
WHERE Concept = 'alcohol-moderate-drinker' OR (Concept = 'alcohol-weekly-intake' AND TRY_CONVERT(NUMERIC(16,5), [Value]) BETWEEN 7 AND 14);
UPDATE #AllPatientAlcoholIntakeConcept
SET Severity = 1
WHERE Concept = 'alcohol-light-drinker' OR (Concept = 'alcohol-weekly-intake' AND TRY_CONVERT(NUMERIC(16,5), [Value]) BETWEEN 0 AND 7);
UPDATE #AllPatientAlcoholIntakeConcept
SET Severity = 0
WHERE Concept = 'alcohol-non-drinker' OR (Concept = 'alcohol-weekly-intake' AND TRY_CONVERT(NUMERIC(16,5), [Value]) = 0 );

-- For "worst" alcohol intake
IF OBJECT_ID('tempdb..#TempWorstAlc') IS NOT NULL DROP TABLE #TempWorstAlc;
SELECT 
	FK_Patient_Link_ID, 
	CASE 
		WHEN MAX(Severity) = 3 THEN 'heavy drinker'
		WHEN MAX(Severity) = 2 THEN 'moderate drinker'
		WHEN MAX(Severity) = 1 THEN 'light drinker'
		WHEN MAX(Severity) = 0 THEN 'non-drinker'
	END AS [Status]
INTO #TempWorstAlc
FROM #AllPatientAlcoholIntakeConcept
WHERE Severity >= 0
GROUP BY FK_Patient_Link_ID;

-- For "current" alcohol intake
IF OBJECT_ID('tempdb..#TempCurrentAlc') IS NOT NULL DROP TABLE #TempCurrentAlc;
SELECT 
	a.FK_Patient_Link_ID, 
	CASE 
		WHEN MAX(Severity) = 3 THEN 'heavy drinker'
		WHEN MAX(Severity) = 2 THEN 'moderate drinker'
		WHEN MAX(Severity) = 1 THEN 'light drinker'
		WHEN MAX(Severity) = 0 THEN 'non-drinker'
	END AS [Status]
INTO #TempCurrentAlc
FROM #AllPatientAlcoholIntakeConcept a
INNER JOIN (
	SELECT FK_Patient_Link_ID, MAX(EventDate) AS MostRecentDate FROM #AllPatientAlcoholIntakeConcept
	WHERE Severity >= 0
	GROUP BY FK_Patient_Link_ID
) sub ON sub.MostRecentDate = a.EventDate and sub.FK_Patient_Link_ID = a.FK_Patient_Link_ID
GROUP BY a.FK_Patient_Link_ID;

-- Bring all together in final table
IF OBJECT_ID('tempdb..#PatientAlcoholIntake') IS NOT NULL DROP TABLE #PatientAlcoholIntake;
SELECT 
	p.FK_Patient_Link_ID,
	CASE WHEN w.[Status] IS NULL THEN 'unknown' ELSE w.[Status] END AS WorstAlcoholIntake,
	CASE WHEN c.[Status] IS NULL THEN 'unknown' ELSE c.[Status] END AS CurrentAlcoholIntake
INTO #PatientAlcoholIntake FROM #Patients p
LEFT OUTER JOIN #TempWorstAlc w on w.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #TempCurrentAlc c on c.FK_Patient_Link_ID = p.FK_Patient_Link_ID;

-- REDUCE THE #Patients TABLE SO THAT IT ONLY INCLUDES THE COHORT, AND REUSABLE QUERIES CAN USE IT TO BE RUN QUICKER 

DELETE FROM #Patients
WHERE FK_Patient_Link_ID NOT IN (SELECT FK_Patient_Link_ID FROM #Cohort)

--┌─────────────────────┐
--│ Patients with COVID │
--└─────────────────────┘

-- OBJECTIVE: To get tables of all patients with a COVID diagnosis in their record. This now includes a table
-- that has reinfections. This uses a 90 day cut-off to rule out patients that get multiple tests for
-- a single infection. This 90 day cut-off is also used in the government COVID dashboard. In the first wave,
-- prior to widespread COVID testing, and prior to the correct clinical codes being	available to clinicians,
-- infections were recorded in a variety of ways. We therefore take the first diagnosis from any code indicative
-- of COVID. However, for subsequent infections we insist on the presence of a positive COVID test (PCR or antigen)
-- as opposed to simply a diagnosis code. This is to avoid the situation where a hospital diagnosis code gets 
-- entered into the primary care record several months after the actual infection.

-- INPUT: Takes three parameters
--  - start-date: string - (YYYY-MM-DD) the date to count diagnoses from. Usually this should be 2020-01-01.
--	-	all-patients: boolean - (true/false) if true, then all patients are included, otherwise only those in the pre-existing #Patients table.
--	- gp-events-table: string - (table name) the name of the table containing the GP events. Usually is "SharedCare.GP_Events" but can be anything with the columns: FK_Patient_Link_ID, EventDate, and SuppliedCode

-- OUTPUT: Three temp tables as follows:
-- #CovidPatients (FK_Patient_Link_ID, FirstCovidPositiveDate)
-- 	- FK_Patient_Link_ID - unique patient id
--	- FirstCovidPositiveDate - earliest COVID diagnosis
-- #CovidPatientsAllDiagnoses (FK_Patient_Link_ID, CovidPositiveDate)
-- 	- FK_Patient_Link_ID - unique patient id
--	- CovidPositiveDate - any COVID diagnosis
-- #CovidPatientsMultipleDiagnoses
--	-	FK_Patient_Link_ID - unique patient id
--	-	FirstCovidPositiveDate - date of first COVID diagnosis
--	-	SecondCovidPositiveDate - date of second COVID diagnosis
--	-	ThirdCovidPositiveDate - date of third COVID diagnosis
--	-	FourthCovidPositiveDate - date of fourth COVID diagnosis
--	-	FifthCovidPositiveDate - date of fifth COVID diagnosis

-- >>> Following code sets injected: covid-positive-antigen-test v1/covid-positive-pcr-test v1/covid-positive-test-other v1


-- Set the temp end date until new legal basis
DECLARE @TEMPWithCovidEndDate datetime;
SET @TEMPWithCovidEndDate = '2022-06-01';

IF OBJECT_ID('tempdb..#CovidPatientsAllDiagnoses') IS NOT NULL DROP TABLE #CovidPatientsAllDiagnoses;
CREATE TABLE #CovidPatientsAllDiagnoses (
	FK_Patient_Link_ID BIGINT,
	CovidPositiveDate DATE
);

INSERT INTO #CovidPatientsAllDiagnoses
SELECT DISTINCT FK_Patient_Link_ID, CONVERT(DATE, [EventDate]) AS CovidPositiveDate
FROM [SharedCare].[COVID19]
WHERE (
	(GroupDescription = 'Confirmed' AND SubGroupDescription != 'Negative') OR
	(GroupDescription = 'Tested' AND SubGroupDescription = 'Positive')
)
AND EventDate > '2020-01-01'
AND EventDate <= @TEMPWithCovidEndDate
--AND EventDate <= GETDATE()
AND FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients);

-- We can rely on the GraphNet table for first diagnosis.
IF OBJECT_ID('tempdb..#CovidPatients') IS NOT NULL DROP TABLE #CovidPatients;
SELECT FK_Patient_Link_ID, MIN(CovidPositiveDate) AS FirstCovidPositiveDate INTO #CovidPatients
FROM #CovidPatientsAllDiagnoses
GROUP BY FK_Patient_Link_ID;

-- Now let's get the dates of any positive test (i.e. not things like suspected, or historic)
IF OBJECT_ID('tempdb..#AllPositiveTestsTemp') IS NOT NULL DROP TABLE #AllPositiveTestsTemp;
CREATE TABLE #AllPositiveTestsTemp (
	FK_Patient_Link_ID BIGINT,
	TestDate DATE
);

INSERT INTO #AllPositiveTestsTemp
SELECT DISTINCT FK_Patient_Link_ID, CAST(EventDate AS DATE) AS TestDate
FROM #PatientEventData
WHERE SuppliedCode IN (
	select Code from #AllCodes 
	where Concept in ('covid-positive-antigen-test','covid-positive-pcr-test','covid-positive-test-other') 
	AND Version = 1
)
AND EventDate <= @TEMPWithCovidEndDate
AND FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients);

IF OBJECT_ID('tempdb..#CovidPatientsMultipleDiagnoses') IS NOT NULL DROP TABLE #CovidPatientsMultipleDiagnoses;
CREATE TABLE #CovidPatientsMultipleDiagnoses (
	FK_Patient_Link_ID BIGINT,
	FirstCovidPositiveDate DATE,
	SecondCovidPositiveDate DATE,
	ThirdCovidPositiveDate DATE,
	FourthCovidPositiveDate DATE,
	FifthCovidPositiveDate DATE
);

-- Populate first diagnosis
INSERT INTO #CovidPatientsMultipleDiagnoses (FK_Patient_Link_ID, FirstCovidPositiveDate)
SELECT FK_Patient_Link_ID, MIN(FirstCovidPositiveDate) FROM
(
	SELECT * FROM #CovidPatients
	UNION
	SELECT * FROM #AllPositiveTestsTemp
) sub
GROUP BY FK_Patient_Link_ID;

-- Now let's get second tests.
UPDATE t1
SET t1.SecondCovidPositiveDate = NextTestDate
FROM #CovidPatientsMultipleDiagnoses AS t1
INNER JOIN (
SELECT cp.FK_Patient_Link_ID, MIN(apt.TestDate) AS NextTestDate FROM #CovidPatients cp
INNER JOIN #AllPositiveTestsTemp apt ON cp.FK_Patient_Link_ID = apt.FK_Patient_Link_ID AND apt.TestDate >= DATEADD(day, 90, FirstCovidPositiveDate)
GROUP BY cp.FK_Patient_Link_ID) AS sub ON sub.FK_Patient_Link_ID = t1.FK_Patient_Link_ID;

-- Now let's get third tests.
UPDATE t1
SET t1.ThirdCovidPositiveDate = NextTestDate
FROM #CovidPatientsMultipleDiagnoses AS t1
INNER JOIN (
SELECT cp.FK_Patient_Link_ID, MIN(apt.TestDate) AS NextTestDate FROM #CovidPatientsMultipleDiagnoses cp
INNER JOIN #AllPositiveTestsTemp apt ON cp.FK_Patient_Link_ID = apt.FK_Patient_Link_ID AND apt.TestDate >= DATEADD(day, 90, SecondCovidPositiveDate)
GROUP BY cp.FK_Patient_Link_ID) AS sub ON sub.FK_Patient_Link_ID = t1.FK_Patient_Link_ID;

-- Now let's get fourth tests.
UPDATE t1
SET t1.FourthCovidPositiveDate = NextTestDate
FROM #CovidPatientsMultipleDiagnoses AS t1
INNER JOIN (
SELECT cp.FK_Patient_Link_ID, MIN(apt.TestDate) AS NextTestDate FROM #CovidPatientsMultipleDiagnoses cp
INNER JOIN #AllPositiveTestsTemp apt ON cp.FK_Patient_Link_ID = apt.FK_Patient_Link_ID AND apt.TestDate >= DATEADD(day, 90, ThirdCovidPositiveDate)
GROUP BY cp.FK_Patient_Link_ID) AS sub ON sub.FK_Patient_Link_ID = t1.FK_Patient_Link_ID;

-- Now let's get fifth tests.
UPDATE t1
SET t1.FifthCovidPositiveDate = NextTestDate
FROM #CovidPatientsMultipleDiagnoses AS t1
INNER JOIN (
SELECT cp.FK_Patient_Link_ID, MIN(apt.TestDate) AS NextTestDate FROM #CovidPatientsMultipleDiagnoses cp
INNER JOIN #AllPositiveTestsTemp apt ON cp.FK_Patient_Link_ID = apt.FK_Patient_Link_ID AND apt.TestDate >= DATEADD(day, 90, FourthCovidPositiveDate)
GROUP BY cp.FK_Patient_Link_ID) AS sub ON sub.FK_Patient_Link_ID = t1.FK_Patient_Link_ID;

---- CREATE OUTPUT TABLE OF ALL INFO NEEDED FOR THE COHORT

SELECT  PatientId = p.FK_Patient_Link_ID, 
		PracticeExitDate = gpex.MovedOutOfGMDate,
		PracticeCCG = prac.CCG,
		YearOfBirth, 
		Sex,
		BMI,
		BMIDate = bmi.DateOfBMIMeasurement,
		EthnicMainGroup,
	    LSOA_Code,
		IMD2019Decile1IsMostDeprived10IsLeastDeprived,
		CurrentSmokingStatus = smok.CurrentSmokingStatus,
		WorstSmokingStatus = smok.WorstSmokingStatus,
		CurrentAlcoholIntake,
		WorstAlcoholIntake,
		DeathWithin28DaysCovid = CASE WHEN cd.FK_Patient_Link_ID IS NULL OR DeathDate >= @EndDate THEN 'N' ELSE 'Y' END,
		Death_Year = YEAR(p.DeathDate),
		Death_Month = MONTH(p.DeathDate),
		FirstVaccineYear =  YEAR(VaccineDose1Date),
		FirstVaccineMonth = MONTH(VaccineDose1Date),
		SecondVaccineYear =  YEAR(VaccineDose2Date),
		SecondVaccineMonth = MONTH(VaccineDose2Date),
		ThirdVaccineYear =  YEAR(VaccineDose3Date),
		ThirdVaccineMonth = MONTH(VaccineDose3Date),
		FirstCovidPositiveDate,
		SecondCovidPositiveDate, 
		ThirdCovidPositiveDate, 
		FourthCovidPositiveDate, 
		FifthCovidPositiveDate,
		AEEncountersBefore1stMarch2020 = ae_b.ae_encounters,
		AEEncountersAfter1stMarch2020 = ae_a.ae_encounters,
		GPAppointmentsBefore1stMarch2020 = gp_b.gp_appointments,
		GPAppointmentsAfter1stMarch2020 =  gp_a.gp_appointments,
		EvidenceOfCKD_egfr,	-- egfr tests indicating stages 3 - 5
		EvidenceOfCKD_combo, -- egfr indicating stage 1 or 2, with ACR evidence or kidney damage
		EvidenceOfCKD_acr, -- acr tests indicating stages A2 or A3
		HealthyEgfrResult, -- one or more healthy egfr result in between the two <60 results
		HealthyAcrResult, -- one or more healthy acr result in between the two >3 results
		EarliestEgfrEvidence,
		EarliestAcrEvidence,
		HypertensionAtStudyStart = CASE WHEN hyp.FK_Patient_Link_ID IS NOT NULL AND hyp.EarliestDiagnosis <= @StartDate THEN 1 ELSE 0 END,
		HypertensionDuringStudyPeriod = CASE WHEN hyp.FK_Patient_Link_ID IS NOT NULL AND hyp.EarliestDiagnosis BETWEEN @StartDate AND @EndDate THEN 1 ELSE 0 END,
		DiabetesAtStudyStart = CASE WHEN dia.FK_Patient_Link_ID IS NOT NULL AND dia.EarliestDiagnosis <= @StartDate THEN 1 ELSE 0 END,
		DiabetesDuringStudyPeriod = CASE WHEN dia.FK_Patient_Link_ID IS NOT NULL AND dia.EarliestDiagnosis BETWEEN @StartDate AND @EndDate THEN 1 ELSE 0 END,
		CodedCKDAtStudyStart = CASE WHEN ckd.FK_Patient_Link_ID IS NOT NULL AND ckd.EarliestDiagnosis <= @StartDate THEN 1 ELSE 0 END,
		CodedCKDDuringStudyPeriod = CASE WHEN ckd.FK_Patient_Link_ID IS NOT NULL AND ckd.EarliestDiagnosis BETWEEN @StartDate AND @EndDate THEN 1 ELSE 0 END
FROM #Cohort p
LEFT OUTER JOIN #PatientLSOA lsoa ON lsoa.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientSex sex ON sex.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientIMDDecile imd ON imd.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientBMI bmi ON bmi.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientSmokingStatus smok ON smok.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientAlcoholIntake alc ON alc.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientPracticeAndCCG prac ON prac.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #GPExitDates gpex ON gpex.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #COVIDVaccinations vac ON vac.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #COVIDDeath cd ON cd.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #AEEncountersCount ae_b ON ae_b.FK_Patient_Link_ID = p.FK_Patient_Link_ID AND ae_b.BeforeOrAfter1stMarch2020 = 'BEFORE'
LEFT OUTER JOIN #AEEncountersCount ae_a ON ae_a.FK_Patient_Link_ID = p.FK_Patient_Link_ID AND ae_a.BeforeOrAfter1stMarch2020 = 'AFTER'
LEFT OUTER JOIN #GPEncountersCount gp_b ON gp_b.FK_Patient_Link_ID = p.FK_Patient_Link_ID AND gp_b.BeforeOrAfter1stMarch2020 = 'BEFORE'
LEFT OUTER JOIN #GPEncountersCount gp_a ON gp_a.FK_Patient_Link_ID = p.FK_Patient_Link_ID AND gp_a.BeforeOrAfter1stMarch2020 = 'AFTER'
LEFT OUTER JOIN #hypertension hyp ON hyp.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #diabetes dia ON dia.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #ckd ckd ON ckd.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #CovidPatientsMultipleDiagnoses cv ON cv.FK_Patient_Link_ID = P.FK_Patient_Link_ID
WHERE YEAR(@StartDate) - YearOfBirth > 18 -- EXTRA CHECK TO ENSURE OVER 18s ONLY
--320,594