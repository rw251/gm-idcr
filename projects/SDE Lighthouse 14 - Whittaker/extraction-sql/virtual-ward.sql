--┌────────────────────────────────────┐
--│ LH004 Virtual ward file            │
--└────────────────────────────────────┘

-- each provider starting providing VW data at different times, so data is incomplete for periods.

USE PRESENATATION.LOCAL_FLOWS_VIRTUAL_WARDS;

set(StudyStartDate) = to_date('2018-01-01');
set(StudyEndDate)   = to_date('2024-06-30');

---- find the latest snapshot for each spell

select  
    SUBSTRING(vw."Pseudo NHS Number", 2)::INT "GmPseudo",
    vw."Unique Spell ID",
    vw."SnapshotDate",
    vw."Admission Source ID",
    adm."Admission Source Description",
    TO_DATE(vw."Admission Date") AS "Admission Date",
    TO_DATE(vw."Discharge Date") AS "Discharge Date",
    vw."Length of stay",
    vw."LoS Group",
    vw."Year Of Birth",
    vw."Month Of Birth",
    vw."Age on Admission",
    vw."Age Group",
    vw."Gender Group" as Sex,
    vw."Ethnicity Group",
    vw."Postcode_LSOA_2011",
    vw."ProviderName",
    vw."Referral Group",
    TO_DATE(vw."Referral Date") AS "Referral Date",
    TO_DATE(vw."Referral Accepted Date") AS "Referral Accepted Date",
    vw."Primary ICD10 Code Group ID",
    vw."Primary ICD10 Code Group",
    vw."Ward ID",
    vw."Ward name",
    vw."WardCapacity",
    vw."Discharge Method",
    vw."Discharge Method Short",
    vw."Discharge Destination",
    vw."Discharge Destination Short",
    vw."Discharge Destination Group",
    vw."Diagnosis Pathway",
    vw."Step up or down",
    vw."Using tech-enabled service"
from PRESENTATION.LOCAL_FLOWS_VIRTUAL_WARDS.VIRTUAL_WARD_OCCUPANCY vw
-- get admission source description
left join (select distinct "Admission Source ID", "Admission Source Description" 
           from PRESENTATION.LOCAL_FLOWS_VIRTUAL_WARDS.DQ_VIRTUAL_WARDS_ADMISSION_SOURCE) adm
    on adm."Admission Source ID" = vw."Admission Source ID"
-- filter to the latest snapshot for each spell (as advised by colleague at NHS GM)
inner join (select  "Unique Spell ID", Max("SnapshotDate") "LatestRecord" 
            from PRESENTATION.LOCAL_FLOWS_VIRTUAL_WARDS.VIRTUAL_WARD_OCCUPANCY
            group by all) a 
    on a."Unique Spell ID" = vw."Unique Spell ID" and vw."SnapshotDate" = a."LatestRecord"
where TO_DATE(vw."Admission Date") BETWEEN $StudyStartDate AND $StudyEndDate;
-- 24.7k spells
-- 16,217 patients
