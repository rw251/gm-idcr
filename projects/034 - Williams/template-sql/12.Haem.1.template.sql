﻿--+---------------------------------------------------------------------------+
--¦ People >75 years old with haemoglobin <100 g/L or ferritin <15 ng/ml      ¦
--+---------------------------------------------------------------------------+

-------- RESEARCH DATA ENGINEER CHECK ---------

-- OUTPUT: Data with the following fields
-- Year (YYYY)
-- Month (1-12)
-- CCG (can be an anonymised id for each CCG)
-- GPPracticeId
-- NumberOfOver75WithLowHaem (integer) The number of over 75s with a haemoglobin <100 or a ferritin <15 in this year, month and for this ccg and gp
-- NumberOfOver75s (integer) The number of over 75s for this year, month, ccg and gp

-- Set the start date
DECLARE @StartDate datetime;
SET @StartDate = '2019-01-01';

--Just want the output, not the messages
SET NOCOUNT ON;

-- Create a table with all patients (ID)=========================================================================================================================
IF OBJECT_ID('tempdb..#Patients') IS NOT NULL DROP TABLE #Patients;
SELECT DISTINCT FK_Patient_Link_ID INTO #Patients FROM [RLS].vw_Patient;

--> CODESET haemoglobin:1


-- Create a table of all patients with haemoglobin values after the start date================================================================================================
-- All haemoglobin records
IF OBJECT_ID('tempdb..#Haemoglobin') IS NOT NULL DROP TABLE #Haemoglobin;
SELECT FK_Patient_Link_ID, EventDate, FK_Reference_Coding_ID, FK_Reference_SnomedCT_ID, Value, Units
INTO #Haemoglobin
FROM [RLS].[vw_GP_Events]
WHERE (
  FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE Concept = 'haemoglobin' AND Version = 1) OR
  FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE Concept = 'haemoglobin' AND Version = 1)
)
AND EventDate >= @StartDate AND Value IS NOT NULL;

-- Only select values as number
IF OBJECT_ID('tempdb..#HaemoglobinConvert') IS NOT NULL DROP TABLE #HaemoglobinConvert;
SELECT *, TRY_CONVERT(NUMERIC (18,5), [Value]) AS Value_new
INTO #HaemoglobinConvert
FROM #Haemoglobin
WHERE UPPER([Value]) NOT LIKE '%[A-Z]%';

-- Convert units
UPDATE
#HaemoglobinConvert
SET
Value_new = Value_new * 10
WHERE
Units = 'g(hb)/dL';

UPDATE
#HaemoglobinConvert
SET
Value_new = Value_new * 10
WHERE
Units = 'g/dL';

UPDATE
#HaemoglobinConvert
SET
Value_new = Value_new * 10
WHERE
Units = 'gm/dl';


-- Create the final table================================================================================================================================
IF OBJECT_ID('tempdb..#HaemLt100') IS NOT NULL DROP TABLE #HaemLt100;
SELECT FK_Patient_Link_ID AS PatientId, EventDate AS Date
INTO #HaemLt100
FROM #HaemoglobinConvert
WHERE Value_new > 0 AND Value_new < 100 AND 
	  (Units = 'g(hb)/dL' OR Units = 'g/dl' OR Units = 'g/L' OR Units = 'g/L (115-165) L' OR Units = 'gm/dl' OR Units = 'gm/L' OR Units = 'mmol/l');