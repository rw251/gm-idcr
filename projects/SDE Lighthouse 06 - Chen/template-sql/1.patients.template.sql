--┌──────────────────────────────────────────────┐
--│ SDE Lighthouse study 06 - Patients           │
--└──────────────────────────────────────────────┘

-------- RESEARCH DATA ENGINEER CHECK ------------
-- Richard Williams	2024-08-30	Review complete --
--------------------------------------------------

--> EXECUTE query-build-lh006-cohort.sql
	
--- death table to join to later

DROP TABLE IF EXISTS Death;
CREATE TEMPORARY TABLE Death AS
SELECT 
    DEATH."GmPseudo",
    TO_DATE(DEATH."RegisteredDateOfDeath") AS DeathDate,
    OM."DiagnosisOriginalMentionCode",
    OM."DiagnosisOriginalMentionDesc",
    OM."DiagnosisOriginalMentionChapterCode",
    OM."DiagnosisOriginalMentionChapterDesc",
    OM."DiagnosisOriginalMentionCategory1Code",
    OM."DiagnosisOriginalMentionCategory1Desc"
FROM PRESENTATION.NATIONAL_FLOWS_PCMD."DS1804_Pcmd" DEATH
LEFT JOIN PRESENTATION.NATIONAL_FLOWS_PCMD."DS1804_PcmdDiagnosisOriginalMentions" OM 
        ON OM."XSeqNo" = DEATH."XSeqNo" AND OM."DiagnosisOriginalMentionNumber" = 1;

-- create cohort of patients
-- join to demographic table to get ethnicity and date of birth

{{create-output-table::"1_Patients"::"GmPseudo"}}
SELECT
	 dem."GmPseudo", -- NEEDS PSEUDONYMISING
	 dem."Sex",
	 dem."DateOfBirth" AS "MonthOfBirth", -- I've renamed this to what it actually is
	 dem."Age",
	 dem."IMD_Decile",
	 dem."EthnicityLatest_Category",
	 dem."PracticeCode", 
	 dth.DeathDate,
     dth."DiagnosisOriginalMentionCode" AS "ReasonForDeathCode",
     dth."DiagnosisOriginalMentionDesc" AS "ReasonForDeathDesc",
	 co.IndexDate
FROM {{cohort-table}}  co
LEFT OUTER JOIN PRESENTATION.GP_RECORD."DemographicsProtectedCharacteristics_SecondaryUses" dem ON dem."GmPseudo" = co."GmPseudo"
LEFT OUTER JOIN Death dth ON dth."GmPseudo" = co."GmPseudo"
QUALIFY row_number() OVER (PARTITION BY dem."GmPseudo" ORDER BY "Snapshot" DESC) = 1;