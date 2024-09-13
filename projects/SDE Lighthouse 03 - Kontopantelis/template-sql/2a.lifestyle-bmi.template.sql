--┌──────────────────────────────────────────┐
--│ SDE Lighthouse study 03 - Kontopantelis  │
--└──────────────────────────────────────────┘

-- From application:
--	Table 2: Lifestyle factors (from 2006 to present)
--		- PatientID
--		- TestName ( smoking status, BMI, alcohol consumption)
--		- TestDate
--		- TestResult
--		- TestUnit

{{create-output-table::"LH003-2a_Lifestyl_BMI"}}
SELECT 
  "GmPseudo",
	"EventDate" AS "TestDate",
	"BMI" AS "TestResult"
FROM INTERMEDIATE.GP_RECORD."Readings_BMI"
WHERE "GmPseudo" IN (SELECT "GmPseudo" FROM {{cohort-table}})
AND YEAR("EventDate") >= 2006;