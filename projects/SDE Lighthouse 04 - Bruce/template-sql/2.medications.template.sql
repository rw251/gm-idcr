--┌─────────────┐
--│ Medications │
--└─────────────┘

------------ RESEARCH DATA ENGINEER CHECK ------------
-- 
------------------------------------------------------

-- In the request this is in 3 files, but the PI has confirmed that a single long file
-- with columns PatientID, Date, MedicationCategory, Medication, Dose, Units is fine.
-- Medications to includes are : Prednisolone, MycophenolateMofetil, Azathioprine, 
-- Tacrolimus, Methotrexate, Ciclosporin, HydroxychloroquineOrChloroquine, Belimumab, 
-- ACEInhibitorOrARB*, SGLT2Inhibitor*, AntiplateletDrug*, Statin*, Anticoagulant*,
-- Cyclophosphamide and Rituximab

-- Medication categories such as "antiplatelet" should give the actual drug within that
-- category
USE DATABASE INTERMEDIATE;

--> CODESET belimumab:1 hydroxychloroquine:1 chloroquine:1
DROP TABLE IF EXISTS INTERMEDIATE.GP_RECORD.LH004_med_codes;
CREATE TEMPORARY TABLE INTERMEDIATE.GP_RECORD.LH004_med_codes AS
SELECT
    "FK_Patient_ID",
    CAST("MedicationDate" AS DATE) AS "MedicationDate",
    "SuppliedCode",
    "Dosage",
    "Quantity",
    "Units"
FROM GP_RECORD."GP_Medications_SecondaryUses"
WHERE "SuppliedCode" IN (SELECT code FROM {{code-set-table}} WHERE concept in ('belimumab','hydroxychloroquine','chloroquine'))
AND "FK_Patient_ID" IN (SELECT "FK_Patient_ID" FROM {{cohort-table}});

DROP TABLE IF EXISTS {{project-schema}}."2_medications";
CREATE TABLE {{project-schema}}."2_medications" AS
SELECT "FK_Patient_ID", "MedicationDate",
    CASE 
        WHEN "Field_ID" IN ('SAL_COD','NONASPANTIPLTDRUG_COD') THEN 'Antiplatelet'
        WHEN "Field_ID" IN ('Immunosuppression_Drugs') THEN 'Immunosuppression'
        WHEN "Field_ID" IN ('ACEInhibitor','ARB') THEN 'ACEInhibitorOrARB'
        WHEN "Field_ID" IN ('SGLT2') THEN 'SGLT2Inhibitor'
        WHEN "Field_ID" IN ('DOAC','Warfarin','ORANTICOAGDRUG_COD') THEN 'Anticoagulant'
        ELSE "Field_ID"
    END AS MedicationCategory, 
    SPLIT_PART(LOWER("MedicationDescription"), ' ',0) AS Medication, "Dosage_GP_Medications", "Quantity", "Units"
FROM GP_RECORD."MedicationsClusters"
WHERE "Field_ID" IN ('Immunosuppression_Drugs', 'Prednisolone', 'ACEInhibitor','SGLT2','SAL_COD','NONASPANTIPLTDRUG_COD','Statin','DOAC','Warfarin','ORANTICOAGDRUG_COD','ARB')
AND "FK_Patient_ID" IN (SELECT "FK_Patient_ID" FROM {{cohort-table}})
UNION
SELECT 
    "FK_Patient_ID", 
    "MedicationDate",
    CASE
        WHEN "SuppliedCode" IN (SELECT code FROM {{code-set-table}} WHERE concept = 'chloroquine') THEN     'HydroxychloroquineOrChloroquine'
        WHEN "SuppliedCode" IN (SELECT code FROM {{code-set-table}} WHERE concept = 'hydroxychloroquine') THEN     'HydroxychloroquineOrChloroquine'
        WHEN "SuppliedCode" IN (SELECT code FROM {{code-set-table}} WHERE concept = 'belimumab') THEN     'Belimumab'
    END AS MedicationCategory, 
    CASE
        WHEN "SuppliedCode" IN (SELECT code FROM {{code-set-table}} WHERE concept = 'chloroquine') THEN     'chloroquine'
        WHEN "SuppliedCode" IN (SELECT code FROM {{code-set-table}} WHERE concept = 'hydroxychloroquine') THEN     'hydroxychloroquine'
        WHEN "SuppliedCode" IN (SELECT code FROM {{code-set-table}} WHERE concept = 'belimumab') THEN     'belimumab'
    END AS Medication,
    "Dosage",
    "Quantity",
    "Units"
FROM INTERMEDIATE.GP_RECORD.LH004_med_codes;