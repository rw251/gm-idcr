--┌──────────────────────────────┐
--│ Medications for LH006 cohort │
--└──────────────────────────────┘

------------ RESEARCH DATA ENGINEER CHECK ------------
-- 
------------------------------------------------------

-- All prescriptions of: antipsychotic medication.

-- OUTPUT: Data with the following fields
-- 	-   PatientId (int)
--	-	MedicationCategory
--  -   Quantity
--  -   Dosage

--Just want the output, not the messages
SET NOCOUNT ON;

-- Set the start date
DECLARE @StartDate datetime;
DECLARE @EndDate datetime;
SET @StartDate = '2017-01-01';
SET @EndDate = '2023-12-31';

--> EXECUTE query-build-lh006-cohort.sql


-- codesets already added (from cohort sql file): opioids-analgesics, nsaids, benzodiazepines, gabapentinoid

--> CODESET 

--  PATIENTS WITH RX OF SELECTED MEDS SINCE 31.07.19

IF OBJECT_ID('tempdb..#meds') IS NOT NULL DROP TABLE #meds;
SELECT 
	 m.FK_Patient_Link_ID,
		CAST(MedicationDate AS DATE) as PrescriptionDate,
		[description] = CASE WHEN s.[description] IS NOT NULL THEN s.[description] ELSE c.[description] END
INTO #meds
FROM SharedCare.GP_Medications m
--LEFT OUTER JOIN #VersionedSnomedSets s ON s.FK_Reference_SnomedCT_ID = m.FK_Reference_SnomedCT_ID
--LEFT OUTER JOIN #VersionedCodeSets c ON c.FK_Reference_Coding_ID = m.FK_Reference_Coding_ID
WHERE m.FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Cohort)
AND m.MedicationDate BETWEEN @StartDate AND @EndDate
AND (
	m.FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #VersionedSnomedSets WHERE Concept IN ('antipsychotics') AND [Version]=1) OR
    m.FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #VersionedCodeSets WHERE Concept IN ('antipsychotics') AND [Version]=1)
);


-- CREATE TABLE OF ALL ANTIPSYCHOTIC RX FOR THE DEMENTIA COHORT, WITH THE MAIN INGREDIENT AND PRESCRIPTION DATE

IF OBJECT_ID('tempdb..#antipsychotics_rx') IS NOT NULL DROP TABLE #antipsychotics_rx;
SELECT 
	PatientId = FK_Patient_Link_ID,
	PrescriptionDate,
	ActiveIngredient = CASE WHEN UPPER([description]) like '%ABILIFY%' THEN 'abilify'
	WHEN UPPER([description]) like '%AMISULPRIDE%' THEN 'amisulpride'
	WHEN UPPER([description]) like '%ANQUIL%' THEN 'anquil'
	WHEN UPPER([description]) like '%ARIPIPRAZOLE%' THEN 'aripiprazole'
	WHEN UPPER([description]) like '%ASENAPINE%' THEN 'asenapine'
	WHEN UPPER([description]) like '%BENPERIDOL%' THEN 'benperidol'
	WHEN UPPER([description]) like '%BENQUIL%' THEN 'benquil'
	WHEN UPPER([description]) like '%CHLORACTIL%' THEN 'chloractil'
	WHEN UPPER([description]) like '%CHLORPROMAZ%' THEN 'chlorpromazine'
	WHEN UPPER([description]) like '%CHLORPROTHIXENE%' THEN 'chlorprothixene'
	WHEN UPPER([description]) like '%CLOPIXOL%' THEN 'clopixol'
	WHEN UPPER([description]) like '%CLOZAPINE%' THEN 'clozapine'
	WHEN UPPER([description]) like '%CLOZARIL%' THEN 'clozaril'
	WHEN UPPER([description]) like '%DENZAPINE%' THEN 'denzapine'
	WHEN UPPER([description]) like '%DEPIXOL%' THEN 'depixol'
	WHEN UPPER([description]) like '%DOLMATIL%' THEN 'dolmatil'
	WHEN UPPER([description]) like '%DOZIC%' THEN 'dozic'
	WHEN UPPER([description]) like '%DROLEPTAN%' THEN 'droleptan'
	WHEN UPPER([description]) like '%Droperidol%' THEN 'droperidol'
	WHEN UPPER([description]) like '%FENTAZIN%' THEN 'fentazin'
	WHEN (UPPER([description]) like '%FLUPENTIXOL%' OR UPPER([description]) like '%FLUPENTHIXOL%') THEN 'flupentixol'
	WHEN UPPER([description]) like '%FLUPHENAZ%' THEN 'fluphenazine'
	WHEN UPPER([description]) like '%HALDOL%' THEN 'haldol'
	WHEN UPPER([description]) like '%HALOPERIDOL%' THEN 'haloperidol'
	WHEN UPPER([description]) like '%INTEGRIN%' THEN 'integrin'
	WHEN UPPER([description]) like '%INVEGA%' THEN 'invega'
	WHEN UPPER([description]) like '%LARGACTIL%' THEN 'largactil'
	WHEN UPPER([description]) like '%LEVINAN%' THEN 'levinan'
	WHEN UPPER([description]) like '%LEVOMEPROMAZINE%' THEN 'levomepromazine'
	WHEN UPPER([description]) like '%Modecate%' THEN 'modecate'
	WHEN UPPER([description]) like '%MODITEN%' THEN 'moditen'
	WHEN UPPER([description]) like '%NEULACTIL%' THEN 'neulactil'
	WHEN UPPER([description]) like '%NOZINAN%' THEN 'nozinan'
	WHEN UPPER([description]) like '%OLANZAPINE%' THEN 'olanzapine'
	WHEN UPPER([description]) like 'ORAP %' THEN 'orap'
	WHEN UPPER([description]) like '%PALIPERIDON%' THEN 'paliperidone'
	WHEN UPPER([description]) like '%PARSTELIN%' THEN 'parstelin'
	WHEN UPPER([description]) like '%PERICYAZINE%' THEN 'pericyazine'
	WHEN UPPER([description]) like '%PERPHENAZINE%' THEN 'perphenazine'
	WHEN UPPER([description]) like '%PIMOZIDE%' THEN 'pimozide'
	WHEN UPPER([description]) like '%PIPORTIL%' THEN 'piportil'
	WHEN (UPPER([description]) like '%PIPOTIAZINE%' OR UPPER([description]) like '%PIPOTHIAZINE%') THEN 'pipotiazine'
	WHEN (UPPER([description]) like '%PROMAZINE%' AND UPPER([description]) NOT like '%CHLORPROMAZINE%') THEN 'promazine'
	WHEN UPPER([description]) like '%PSYTIXOL%' THEN 'psytixol'
	WHEN UPPER([description]) like '%QUETIAPINE%' THEN 'quetiapine'
	WHEN UPPER([description]) like '%REMOXIPRIDE%' THEN 'remoxipride'
	WHEN UPPER([description]) like '%RISPERDAL%' THEN 'risperdal'
	WHEN UPPER([description]) like '%RISPERIDONE%' THEN 'risperidone'
	WHEN UPPER([description]) like '%ROXIAM%' THEN 'roxiam'
	WHEN UPPER([description]) like '%SERDOLECT%' THEN 'serdolect'
	WHEN UPPER([description]) like '%SERENACE%' THEN 'serenace'
	WHEN UPPER([description]) like '%SEROQUEL%' THEN 'seroquel'
	WHEN UPPER([description]) like '%SERTINDOLE%' THEN 'sertindole'
	WHEN UPPER([description]) like '%SOLIAN%' THEN 'solian'
	WHEN UPPER([description]) like '%SONDATE%' THEN 'sondate'
	WHEN UPPER([description]) like '%SPARINE%' THEN 'sparine'
	WHEN UPPER([description]) like '%STELABID%' THEN 'stelabid'
	WHEN UPPER([description]) like '%STELAZINE%' THEN 'stelazine'
	WHEN UPPER([description]) like '%SULPAREX%' THEN 'sulparex'
	WHEN UPPER([description]) like '%SULPIRIDE%' THEN 'sulpiride'
	WHEN UPPER([description]) like '%SULPITIL%' THEN 'sulpitil'
	WHEN UPPER([description]) like '%SULPOR%' THEN 'sulpor'
	WHEN UPPER([description]) like '%TARACTAN%' THEN 'taractan'
	WHEN UPPER([description]) like '%TENPROLIDE%' THEN 'tenprolide'
	WHEN UPPER([description]) like '%THIORIDAZINE%' THEN 'thioridazine'
	WHEN UPPER([description]) like '%TRANYLCYPROMINE%' THEN 'tranylcypromine'
	WHEN UPPER([description]) like '%TRIFLUOPERAZ%' THEN 'trifluoperazine'
	WHEN UPPER([description]) like '%TRIFLUPERIDOL%' THEN 'trifluperidol'
	WHEN UPPER([description]) like '%TRIPERIDOL%' THEN 'triperidol'
	WHEN UPPER([description]) like '%TRIPTAFEN%' THEN 'triptafen'
	WHEN UPPER([description]) like '%VERACTIL%' THEN 'veractil'
	WHEN UPPER([description]) like '%XEPLION%' THEN 'xeplion'
	WHEN UPPER([description]) like '%ZALASTA%' THEN 'zalasta'
	WHEN UPPER([description]) like '%ZAPONEX%' THEN 'zaponex'
	WHEN UPPER([description]) like '%ZOLEPTIL%' THEN 'zoleptil'
	WHEN UPPER([description]) like '%ZOTEPINE%' THEN 'zotepine'
	WHEN UPPER([description]) like '%ZUCLOPENTHIX%' THEN 'zuclopenthixol'
	WHEN UPPER([description]) like '%ZYPADHERA%' THEN 'zypadhera'
	WHEN UPPER([description]) like '%ZYPREXA%'  THEN 'zyprexa'
		ELSE NULL END
FROM #SMI_antipsychotics 



