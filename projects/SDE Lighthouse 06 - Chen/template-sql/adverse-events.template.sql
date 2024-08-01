--┌──────────────────────────────────────────────────────────┐
--│ SDE Lighthouse study 06 - Chen - adverse events          │
--└──────────────────────────────────────────────────────────┘

USE INTERMEDIATE.GP_RECORD;

-- events needed: suicide, fracture

set(StudyStartDate) = to_date('2017-01-01');
set(StudyEndDate)   = to_date('2023-12-31');

--> EXECUTE query-build-lh006-cohort.sql

SELECT DISTINCT 
	ec."FK_Patient_ID",
    TO_DATE(ec."EventDate") AS "EventDate",
    CASE WHEN ec."Cluster_ID" = 'eFI2_Fracture' THEN 'fracture'
         WHEN ec."Cluster_ID" = 'eFI2_SelfHarm' THEN 'self-harm'
             ELSE 'other' END AS "Concept", 
    ec."SuppliedCode",
    ec."Term"
FROM INTERMEDIATE.GP_RECORD."EventsClusters" ec
WHERE "Cluster_ID" in 
    ('eFI2_Fracture',
     'eFI2_SelfHarm')
AND TO_DATE(ec."EventDate") BETWEEN $StudyStartDate AND $StudyEndDate
and "FK_Patient_ID" = '1107382'
AND "FK_Patient_ID" IN (SELECT "FK_Patient_ID" FROM Cohort)