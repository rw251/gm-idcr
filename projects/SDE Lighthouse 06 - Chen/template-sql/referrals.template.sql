--┌────────────────────────────────────────────────────┐
--│ SDE Lighthouse study 06 - Chen - referrals         │
--└────────────────────────────────────────────────────┘

--> EXECUTE query-build-lh006-cohort.sql

DROP TABLE IF EXISTS referralsClusters;
CREATE TEMPORARY TABLE referralsClusters AS
SELECT 
    ec."FK_Patient_ID"
    , TO_DATE(ec."EventDate") AS "MedicationDate"
    , ec."SCTID" AS "SnomedCode"
    , CASE WHEN ec."Cluster_ID" = 'SOCPRESREF_COD' THEN 'social prescribing referral'
			WHEN ("Cluster_ID" in ('REFERRAL_COD') AND lower("Term") LIKE '%physiotherap%') THEN 'physiotherapy-referral'
			WHEN ("Cluster_ID" in ('REFERRAL_COD') AND lower("Term") LIKE '%psych%') THEN 'psychological-therapy-referral'
			WHEN ("Cluster_ID" in ('REFERRAL_COD') AND lower("Term") LIKE '%acupun%') THEN 'acupuncture-referral'
			WHEN ("Cluster_ID" in ('REFERRAL_COD') AND lower("Term") LIKE '%pain%') THEN 'pain-related-referral' 
			WHEN ("Cluster_ID" in ('REFERRAL_COD') AND (lower("Term") like '%surgeon%' or lower("Term") like '%surgery%' or lower("Term") like '%surgical%' )) THEN 'surgery-referral' 
           ELSE 'other' END AS "CodeSet"
    , ec."Term" AS "Description"
FROM INTERMEDIATE.GP_RECORD."EventsClusters" ec
WHERE 
	(
    ("Cluster_ID" in ('SOCPRESREF_COD')) -- social prescribing referral
	OR
	("Cluster_ID" in ('REFERRAL_COD') AND lower("Term") LIKE '%physiotherap%') -- physiotherapy referral
	OR 
	("Cluster_ID" in ('REFERRAL_COD') AND lower("Term") LIKE '%psych%') -- psychological therapy referral
	OR
	("Cluster_ID" in ('REFERRAL_COD') AND lower("Term") LIKE '%acupun%') -- acupuncture referral 
	OR
	("Cluster_ID" in ('REFERRAL_COD') AND lower("Term") LIKE '%pain%') -- pain-related  referral 
	OR 
	("Cluster_ID" in ('REFERRAL_COD') AND (lower("Term") like '%surgeon%' or lower("Term") like '%surgery%' or lower("Term") like '%surgical%' )) -- surgery referral 
    )
AND TO_DATE(ec."EventDate") BETWEEN $StudyStartDate and $StudyEndDate;
    AND ec."FK_Patient_ID" IN (SELECT "FK_Patient_ID" FROM Cohort);
