--┌────────────────────────────────────────────────────────────┐
--│ SDE Lighthouse study 14 - Whittaker - Inpatient admissions │
--└────────────────────────────────────────────────────────────┘

-------- RESEARCH DATA ENGINEER CHECK ---------
-- Richard Williams	2024-08-09	Review complete

USE PRESENTATION.LOCAL_FLOWS_VIRTUAL_WARDS;

-- Date range: 2018 to present

set(StudyStartDate) = to_date('2018-01-01');
set(StudyEndDate)   = to_date('2024-05-31');

---- find all virtual ward patients, using latest snapshot for each spell
/*
drop table if exists virtualWards;
create temporary table virtualWards as
select  
	distinct SUBSTRING(vw."Pseudo NHS Number", 2)::INT as "GmPseudo"
from PRESENTATION.LOCAL_FLOWS_VIRTUAL_WARDS.VIRTUAL_WARD_OCCUPANCY vw
where TO_DATE(vw."Admission Date") BETWEEN $StudyStartDate AND $StudyEndDate;
*/

-- get all inpatient admissions
DROP TABLE IF EXISTS {{project-schema}}."5_InpatientAdmissions";
CREATE TABLE {{project-schema}}."5_InpatientAdmissions" AS
SELECT 
    "GmPseudo"
    , TO_DATE("AdmissionDttm") AS "AdmissionDate"
    , TO_DATE("DischargeDttm") AS "DischargeDate"
	, "AdmissionMethodCode"
	, "AdmissionMethodDesc"
    , "HospitalSpellDuration" AS "LOS_days"
    , "DerPrimaryDiagnosisChapterDescReportingEpisode" AS PrimaryDiagnosisChapter
	, "DerPrimaryDiagnosisCodeReportingEpisode" AS PrimaryDiagnosisCode 
    , "DerPrimaryDiagnosisDescReportingEpisode" AS PrimaryDiagnosisDesc
FROM PRESENTATION.NATIONAL_FLOWS_APC."DS708_Apcs"
WHERE TO_DATE("AdmissionDttm") BETWEEN $StudyStartDate AND $StudyEndDate
	AND "GmPseudo" IN (select "GmPseudo" from {{cohort-table}});
