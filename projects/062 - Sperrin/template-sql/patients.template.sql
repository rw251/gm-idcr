--+--------------------------------------------------------------------------------+
--¦ Patient information                                                            ¦
--+--------------------------------------------------------------------------------+
-- !!! NEED TO DO: WHEN WE HAVE WEEK OF BIRTH, PLEASE CHANGE THE QUERY-BUILD-RQ062-COHORT.SQL TO UPDATE THE COHORT. ALSO ADD WEEK OF BRTH FOR THE TABLE BELOW. THANKS.
-- !!! NEED TO DO: GO THROUGH SURG TO CHECK IF WE CAN PROVIDE ALL THE INFORMATION BELOW OR NEED TO REDUCE SOME COLUMNS FOR PROTECTING PID.

-------- RESEARCH DATA ENGINEER CHECK ---------


-- OUTPUT: Data with the following fields
-- PatientId
-- WeekOfBirth (dd/mm/yyyy)
-- MonthAndYearOfBirth (mm/yyyy)
-- YearAndMonthOfDeath
-- Sex
-- Ethnicity
-- GPID
-- RegistrationGPDate 
-- DeregistrationGPDate
-- LSOA
-- IMD 
-- NumberGPEncounterBeforeSept2013


--Just want the output, not the messages
SET NOCOUNT ON;


--> EXECUTE query-build-rq062-cohort.sql
--> EXECUTE query-patient-sex.sql
--> EXECUTE query-patient-year-and-quarter-month-of-birth.sql
--> EXECUTE query-patient-gp-history.sql
--> EXECUTE query-patient-imd.sql
--> EXECUTE query-patient-lsoa.sql
--> EXECUTE query-patient-gp-encounters.sql all-patients:false gp-events-table:SharedCare.GP_Events start-date:1800-01-01 end-date:2013-09-01


-- Create the table of ethnic================================================================================================================================
IF OBJECT_ID('tempdb..#Ethnic') IS NOT NULL DROP TABLE #Ethnic;
SELECT PK_Patient_Link_ID AS FK_Patient_Link_ID, EthnicCategoryDescription AS Ethnicity
INTO #Ethnic
FROM SharedCare.Patient_Link;


-- Count GP encouters========================================================================================================================================
IF OBJECT_ID('tempdb..#GPEncounterCount') IS NOT NULL DROP TABLE #GPEncounterCount;
SELECT FK_Patient_Link_ID ,COUNT(FK_Patient_Link_ID) AS NumberGPEncounterBeforeSept2013
INTO #GPEncounterCount
FROM #GPEncounters
GROUP BY FK_Patient_Link_ID


-- The final table===========================================================================================================================================
SELECT
  p.FK_Patient_Link_ID as PatientId,
  YearAndQuarterMonthOfBirth,
  FORMAT(link.DeathDate, 'yyyy-MM') AS YearAndMonthOfDeath,
  Sex,
  Ethnicity,
  IMD2019Decile1IsMostDeprived10IsLeastDeprived,
  LSOA_Code AS LSOA,
  GPPracticeCode,
  StartDate AS RegistrationGPDate,
  EndDate AS DeregistrationGPDate,
  NumberGPEncounterBeforeSept2013
FROM #Patients p
LEFT OUTER JOIN #Ethnic e ON e.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientYearAndQuarterMonthOfBirth yob ON yob.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientSex sex ON sex.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientIMDDecile imd ON imd.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientLSOA l ON l.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #GPEncounterCount c ON c.FK_Patient_Link_ID = p.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientGPHistory gp ON p.FK_Patient_Link_ID = gp.FK_Patient_Link_ID
LEFT OUTER JOIN [SharedCare].[Patient_Link] link ON p.FK_Patient_Link_ID = link.PK_Patient_Link_ID;