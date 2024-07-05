--┌──────────────────────────────────────────────────────────────┐
--│ SDE Lighthouse study 14 - Whittaker - A&E Encounters         │
--└──────────────────────────────────────────────────────────────┘

-- Date range: 2018 to present

---- find the latest snapshot for each spell, to get all virtual ward patients

drop table if exists virtualWards;
create temporary table virtualWards as
select  
	distinct SUBSTRING(vw."Pseudo NHS Number", 2)::INT as "GmPseudo"
from PRESENTATION.LOCAL_FLOWS_VIRTUAL_WARDS.VIRTUAL_WARD_OCCUPANCY vw;

-- get all a&e admissions for the virtual ward cohort

SELECT 
E."GmPseudo", 
TO_DATE(E."ArrivalDate") AS "ArrivalDate",
E."EcDuration" AS LOS_Mins,
E."EcChiefComplaintSnomedCtDesc" AS ChiefComplaint
FROM PRESENTATION.NATIONAL_FLOWS_ECDS."DS707_Ecds" E
WHERE "IsAttendance" = 1
	AND "GmPseudo" IN (SELECT "GmPseudo" FROM virtualWards);