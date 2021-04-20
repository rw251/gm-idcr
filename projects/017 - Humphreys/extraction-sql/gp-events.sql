--┌───────────┐
--│ GP Events │
--└───────────┘

-- All GP events for the cohort of RA patients

-- OUTPUT: Data with the following fields
-- 	- PatientId (int)
-- 	- GPPracticeCode
--	-	EventDate (YYYY-MM-DD)
--	-	SuppliedCode
--	-	Units
--	-	Value
--	-	SensitivityDormant
--	-	EventNo

--Just want the output, not the messages
SET NOCOUNT ON;

-- For now let's use the in-built QOF rule for the RA cohort. We can refine this over time
IF OBJECT_ID('tempdb..#Patients') IS NOT NULL DROP TABLE #Patients;
SELECT DISTINCT FK_Patient_Link_ID
INTO #Patients
FROM [RLS].[vw_Cohort_Patient_Registers]
WHERE FK_Cohort_Register_ID IN (
	SELECT PK_Cohort_Register_ID FROM SharedCare.Cohort_Register
	WHERE FK_Cohort_Category_ID IN (
		SELECT PK_Cohort_Category_ID FROM SharedCare.Cohort_Category
		WHERE CategoryName = 'Rheumatoid Arthritis'
	)
);

SELECT 
	FK_Patient_Link_ID AS PatientId,
	GPPracticeCode,
	CAST(EventDate AS DATE) AS EventDate,
	SuppliedCode,
	Units,
	Value,
	SensitivityDormant,
	EventNo
FROM RLS.vw_GP_Events
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients);