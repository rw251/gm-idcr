--┌─────────────────────────────────┐
--│ Covid information               │
--└─────────────────────────────────┘

-- Covid information including shielding for all patients in the entire cohort. 

-- OUTPUT: A single table with the following:
--  PatientId (Int)
--  CovidEvent ('High Clinical Vulnerability', 'Moderate Clinical Vulnerability', 'Positive Test', 'Death Within 28 Days')
--  CovidEventDate (YYYY-MM-DD)

--Just want the output, not the messages
SET NOCOUNT ON;

-- Set the start date
DECLARE @StartDate datetime;
SET @StartDate = '2020-02-01';

--> EXECUTE query-cancer-cohort-matching.sql
-- OUTPUTS: #Patients2


-- Get all patients with a positive covid test and the date they tested positive.
-- Grain: multiple dates per patient, De-duped: Assume that a patient can have only one positive tests per day. 
IF OBJECT_ID('tempdb..#CovidPatients') IS NOT NULL DROP TABLE #CovidPatients;
SELECT DISTINCT
    FK_Patient_Link_ID, 
    CONVERT(DATE, [EventDate]) AS CovidPositiveDate 
INTO #CovidPatients
FROM [RLS].[vw_COVID19]
WHERE 
    (GroupDescription = 'Confirmed' OR (GroupDescription = 'Tested' AND SubGroupDescription = 'Positive'))
    AND EventDate > @StartDate
    AND FK_Patient_Link_ID IN (Select FK_Patient_Link_ID from  #Patients2);



--> CODESET high-clinical-vulnerability:1 moderate-clinical-vulnerability:1 

-- Get patients with high and moderate covid vulnerability code and date of entry
-- Get all dates that a code was used to identify any patients with changes from high to moderate and vise versa.
-- De-duped: Assume that a patient was assessed as high/moderate once within a day. 
IF OBJECT_ID('tempdb..#HighVulnerabilityPatients') IS NOT NULL DROP TABLE #HighVulnerabilityPatients;
SELECT DISTINCT
    FK_Patient_Link_ID, 
    CONVERT(DATE, [EventDate]) AS HighVulnerabilityCodeDate
INTO #HighVulnerabilityPatients 
FROM [RLS].[vw_GP_Events]
WHERE 
    SuppliedCode IN (SELECT [Code] FROM #AllCodes WHERE [Concept] = 'high-clinical-vulnerability' AND [Version] = 1) 
    AND EventDate > @StartDate
    AND FK_Patient_Link_ID IN (Select FK_Patient_Link_ID from  #Patients2);

IF OBJECT_ID('tempdb..#ModerateVulnerabilityPatients') IS NOT NULL DROP TABLE #ModerateVulnerabilityPatients;
SELECT DISTINCT
    FK_Patient_Link_ID, 
    CONVERT(DATE, [EventDate]) AS ModerateVulnerabilityCodeDate 
INTO #ModerateVulnerabilityPatients 
FROM [RLS].[vw_GP_Events]
WHERE 
    SuppliedCode IN (SELECT [Code] FROM #AllCodes WHERE [Concept] = 'moderate-clinical-vulnerability' AND [Version] = 1) 
    AND EventDate > @StartDate
    AND FK_Patient_Link_ID IN (Select FK_Patient_Link_ID from  #Patients2);


-- Get patient list with COVID death within 28 days of positive test
IF OBJECT_ID('tempdb..#COVIDDeath') IS NOT NULL DROP TABLE #COVIDDeath;
SELECT DISTINCT 
    FK_Patient_Link_ID,
    DeathWithin28Days,
    DeathDate
INTO #COVIDDeath FROM RLS.vw_COVID19
WHERE 
    DeathWithin28Days = 'Y';


IF OBJECT_ID('tempdb..#COVIDEvents') IS NOT NULL DROP TABLE #COVIDEvents;
SELECT
    FK_Patient_Link_ID AS PatientId,
    'High Clinical Vulnerability' AS CovidEvent,
    HighVulnerabilityCodeDate AS CovidEventDate
INTO #COVIDEvents
FROM #HighVulnerabilityPatients
WHERE HighVulnerabilityCodeDate IS NOT NULL 

UNION ALL

SELECT
    FK_Patient_Link_ID AS PatientId,
    'Moderate Clinical Vulnerability' AS CovidEvent,
    ModerateVulnerabilityCodeDate AS CovidEventDate
FROM #ModerateVulnerabilityPatients
WHERE ModerateVulnerabilityCodeDate IS NOT NULL 

UNION ALL

SELECT
    FK_Patient_Link_ID AS PatientId,
    'Positive Test' AS CovidEvent,
    CovidPositiveDate AS CovidEventDate
FROM #CovidPatients
WHERE CovidPositiveDate IS NOT NULL 

UNION ALL

SELECT
    FK_Patient_Link_ID AS PatientId,
    'Death Within 28 Days' AS CovidEvent,
    DeathDate AS CovidEventDate
FROM #COVIDDeath
WHERE DeathDate IS NOT NULL 

-- Grain:
-- each row corresponds to 1 event that could occur for each patient at a given date
-- events cover:
-- - 'High Clinical Vulnerability'
-- - 'Moderate Clinical Vulnerability'
-- - 'Positive Test'
-- - 'Death Within 28 Days'
SELECT
    PatientId,
    CovidEvent,
    CovidEventDate
FROM #COVIDEvents

