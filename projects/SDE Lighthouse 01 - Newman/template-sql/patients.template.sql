--┌────────────────────────────────────┐
--│ LH001 Patient file                 │
--└────────────────────────────────────┘

--> EXECUTE query-build-lh001-cohort.sql

-- deaths table

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
        ON OM."XSeqNo" = DEATH."XSeqNo" AND OM."DiagnosisOriginalMentionNumber" = 1
WHERE "GmPseudo" IN (SELECT "GmPseudo" FROM Cohort);

-- patient demographics table

--DROP TABLE IF EXISTS Patients;
--CREATE TEMPORARY TABLE Patients AS 
SELECT * EXCLUDE (rownum)
FROM (
SELECT 
	"Snapshot", 
	D."GmPseudo" AS GmPseudo,
	"FK_Patient_ID", 
	"DateOfBirth",
	DATE_TRUNC(month, dth.DeathDate) AS DeathDate,
	"DiagnosisOriginalMentionCode" AS CauseOfDeathCode,
	"DiagnosisOriginalMentionDesc" AS CauseOfDeathDesc,
	"DiagnosisOriginalMentionChapterCode" AS CauseOfDeathChapterCode,
    "DiagnosisOriginalMentionChapterDesc" AS CauseOfDeathChapterDesc,
    "DiagnosisOriginalMentionCategory1Code" AS CauseOfDeathCategoryCode,
    "DiagnosisOriginalMentionCategory1Desc" AS CauseOfDeathCategoryDesc,
	LSOA11, 
	"IMD_Decile", 
	"Age", 
	"Sex", 
	"EthnicityLatest_Category", 
	"PracticeCode", -- need to anonymise
	"Frailty" -- 92% missingness
	row_number() over (partition by D."GmPseudo" order by "Snapshot" desc) rownum
FROM PRESENTATION.GP_RECORD."DemographicsProtectedCharacteristics_SecondaryUses" D
LEFT JOIN Death dth ON dth."GmPseudo" = D."GmPseudo"
WHERE D."GmPseudo" IN (select "GmPseudo" from Cohort) -- patients in pharmacogenetic cohort
)
WHERE rownum = 1; -- get latest demographic snapshot only

---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------------------
-- 