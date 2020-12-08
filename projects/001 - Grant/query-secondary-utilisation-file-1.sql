--Just want the output, not the messages
SET NOCOUNT ON;

-- Set the start date
DECLARE @StartDate datetime;
SET @StartDate = '2020-01-01';

--> EXECUTE query-classify-secondary-admissions.sql

-- Populate a table with all the patients so in the future we can get their LTCs and deprivation score etc.
IF OBJECT_ID('tempdb..#Patients') IS NOT NULL DROP TABLE #Patients;
SELECT DISTINCT FK_Patient_Link_ID INTO #Patients FROM #AdmissionTypes;
-- 286087 rows
-- 00:00:01

--> EXECUTE query-patient-ltcs.sql

--> EXECUTE query-patient-ltcs-number-of.sql

--> EXECUTE query-patient-imd.sql

--> EXECUTE query-get-admissions-and-length-of-stay.sql

--> EXECUTE query-admissions-covid-utilisation.sql


-- Prepare discharge data
IF OBJECT_ID('tempdb..#FinalDischarges') IS NOT NULL DROP TABLE #FinalDischarges;
SELECT 
	DischargeDate, l.AcuteProvider,	ISNULL(IMD2019Decile1IsMostDeprived10IsLeastDeprived, 0) AS IMD2019Decile1IsMostDeprived10IsLeastDeprived, 
	ISNULL(NumberOfLTCs,0) AS NumberOfLTCs, CovidHealthcareUtilisation, count(*) AS NumberDischarged 
	INTO #FinalDischarges
FROM #LengthOfStay l
LEFT OUTER JOIN #COVIDUtilisationAdmissions c ON c.FK_Patient_Link_ID = l.FK_Patient_Link_ID AND c.AdmissionDate = l.AdmissionDate AND c.AcuteProvider = l.AcuteProvider
LEFT OUTER JOIN #NumLTCs ltc ON ltc.FK_Patient_Link_ID = l.FK_Patient_Link_ID
LEFT OUTER JOIN #PatientIMDDecile imd ON imd.FK_Patient_Link_ID = l.FK_Patient_Link_ID
GROUP BY DischargeDate, l.AcuteProvider,IMD2019Decile1IsMostDeprived10IsLeastDeprived, NumberOfLTCs, CovidHealthcareUtilisation;
-- 28764

-- Prepare admission data
IF OBJECT_ID('tempdb..#FinalAdmissions') IS NOT NULL DROP TABLE #FinalAdmissions;
SELECT 
	p.AdmissionDate, p.AcuteProvider, ISNULL(IMD2019Decile1IsMostDeprived10IsLeastDeprived, 0) AS IMD2019Decile1IsMostDeprived10IsLeastDeprived, ISNULL(NumberOfLTCs,0) AS NumberOfLTCs, CovidHealthcareUtilisation,
	SUM(CASE WHEN AdmissionType = 'Unplanned' THEN 1 ELSE 0 END) AS NumberUnplannedAdmissions,
	SUM(CASE WHEN AdmissionType = 'Planned' THEN 1 ELSE 0 END) AS NumberPlannedAdmissions,
	SUM(CASE WHEN AdmissionType = 'Maternity' THEN 1 ELSE 0 END) AS NumberMaternityAdmissions,
	SUM(CASE WHEN AdmissionType = 'Transfer' THEN 1 ELSE 0 END) AS NumberTransferAdmissions,
	SUM(CASE WHEN AdmissionType = 'Unknown' THEN 1 ELSE 0 END) AS NumberUnknownAdmissions,
	avg(CAST(l.LengthOfStay AS FLOAT)) AS AverageLengthOfStay
	INTO #FinalAdmissions
FROM #AdmissionTypes p
	LEFT OUTER JOIN #Admissions a ON a.FK_Patient_Link_ID = p.FK_Patient_Link_ID AND a.AdmissionDate = p.AdmissionDate AND a.AcuteProvider = p.AcuteProvider
	LEFT OUTER JOIN #COVIDUtilisationAdmissions c ON c.FK_Patient_Link_ID = p.FK_Patient_Link_ID AND c.AdmissionDate = p.AdmissionDate AND c.AcuteProvider = p.AcuteProvider
	LEFT OUTER JOIN #LengthOfStay l ON l.FK_Patient_Link_ID = p.FK_Patient_Link_ID AND l.AdmissionDate = p.AdmissionDate AND l.AcuteProvider = p.AcuteProvider
	LEFT OUTER JOIN #NumLTCs ltc ON ltc.FK_Patient_Link_ID = p.FK_Patient_Link_ID
	LEFT OUTER JOIN #PatientIMDDecile imd ON imd.FK_Patient_Link_ID = p.FK_Patient_Link_ID
GROUP BY p.AdmissionDate,p.AcuteProvider,IMD2019Decile1IsMostDeprived10IsLeastDeprived, CovidHealthcareUtilisation,NumberOfLTCs;
-- 29833

-- Find unique combinations of data, provider, decile, numLTCs and covid utilisation
IF OBJECT_ID('tempdb..#CovariateCombinations') IS NOT NULL DROP TABLE #CovariateCombinations;
SELECT DISTINCT DischargeDate AS [Date], AcuteProvider, IMD2019Decile1IsMostDeprived10IsLeastDeprived, NumberOfLTCs, CovidHealthcareUtilisation
INTO #CovariateCombinations
FROM #FinalDischarges
UNION
SELECT DISTINCT AdmissionDate, AcuteProvider,IMD2019Decile1IsMostDeprived10IsLeastDeprived, NumberOfLTCs, CovidHealthcareUtilisation
FROM #FinalAdmissions
--32352

-- Bring it all together for output
SELECT 
	cc.[Date], cc.AcuteProvider, cc.IMD2019Decile1IsMostDeprived10IsLeastDeprived, 
	cc.NumberOfLTCs, cc.CovidHealthcareUtilisation,
	ISNULL(fa.NumberMaternityAdmissions, 0) AS NumberMaternityAdmissions, 
	ISNULL(fa.NumberPlannedAdmissions, 0) AS NumberPlannedAdmissions, 
	ISNULL(fa.NumberTransferAdmissions, 0) AS NumberTransferAdmissions,
	ISNULL(fa.NumberUnknownAdmissions, 0) AS NumberUnknownAdmissions, 
	ISNULL(fa.NumberUnplannedAdmissions, 0) AS NumberUnplannedAdmissions, 
	ISNULL(fd.NumberDischarged, 0) AS NumberDischarged
	FROM #CovariateCombinations cc
LEFT OUTER JOIN #FinalAdmissions fa ON 
	fa.AdmissionDate = cc.[Date] AND
	fa.AcuteProvider = cc.AcuteProvider AND
	fa.IMD2019Decile1IsMostDeprived10IsLeastDeprived = cc.IMD2019Decile1IsMostDeprived10IsLeastDeprived AND
	fa.NumberOfLTCs = cc.NumberOfLTCs AND
	fa.CovidHealthcareUtilisation = cc.CovidHealthcareUtilisation
LEFT OUTER JOIN #FinalDischarges fd ON 
	fd.DischargeDate = cc.[Date] AND
	fd.AcuteProvider = cc.AcuteProvider AND
	fd.IMD2019Decile1IsMostDeprived10IsLeastDeprived = cc.IMD2019Decile1IsMostDeprived10IsLeastDeprived AND
	fd.NumberOfLTCs = cc.NumberOfLTCs AND
	fd.CovidHealthcareUtilisation = cc.CovidHealthcareUtilisation
ORDER BY cc.[Date], cc.AcuteProvider, cc.IMD2019Decile1IsMostDeprived10IsLeastDeprived, cc.NumberOfLTCs, cc.CovidHealthcareUtilisation;