--┌───────────────┐
--│ Vaccine doses │
--└───────────────┘

--------------------- RDE CHECK ---------------------
-- Le Mai Parkes  - 25 May 2022 - via pull request --
-----------------------------------------------------

-- OUTPUT: Data with the following fields
--  - PatientId (int)
--  - VaccineDate (YYYYMMDD)


--Just want the output, not the messages
SET NOCOUNT ON;

-- Assume temp table #OxAtHome (FK_Patient_Link_ID, AdmissionDate, DischargeDate)

-- As it's a small cohort, it's quicker to get all data in to a temp table
-- and then all subsequent queries will target that data
IF OBJECT_ID('tempdb..#PatientEventData') IS NOT NULL DROP TABLE #PatientEventData;
SELECT 
  FK_Patient_Link_ID,
  CAST(EventDate AS DATE) AS EventDate,
  SuppliedCode,
  FK_Reference_SnomedCT_ID,
  FK_Reference_Coding_ID,
  [Value]
INTO #PatientEventData
FROM [RLS].vw_GP_Events
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #OxAtHome);

IF OBJECT_ID('tempdb..#PatientMedicationData') IS NOT NULL DROP TABLE #PatientMedicationData;
SELECT 
  FK_Patient_Link_ID,
  CAST(MedicationDate AS DATE) AS MedicationDate,
  SuppliedCode,
  FK_Reference_SnomedCT_ID,
  FK_Reference_Coding_ID
INTO #PatientMedicationData
FROM [RLS].vw_GP_Medications
WHERE FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #OxAtHome);

--┌────────────────────┐
--│ COVID vaccinations │
--└────────────────────┘

-- OBJECTIVE: To obtain a table with first, second, third... etc vaccine doses per patient.

-- ASSUMPTIONS:
--	-	GP records can often be duplicated. The assumption is that if a patient receives
--    two vaccines within 14 days of each other then it is likely that both codes refer
--    to the same vaccine.
--  - The vaccine can appear as a procedure or as a medication. We assume that the
--    presence of either represents a vaccination

-- INPUT: Takes two parameters:
--	- gp-events-table: string - (table name) the name of the table containing the GP events. Usually is "RLS.vw_GP_Events" but can be anything with the columns: FK_Patient_Link_ID, EventDate, and SuppliedCode
--	- gp-medications-table: string - (table name) the name of the table containing the GP medications. Usually is "RLS.vw_GP_Medications" but can be anything with the columns: FK_Patient_Link_ID, EventDate, and SuppliedCode

-- OUTPUT: A temp table as follows:
-- #COVIDVaccinations (FK_Patient_Link_ID, VaccineDate, DaysSinceFirstVaccine)
-- 	- FK_Patient_Link_ID - unique patient id
--	- VaccineDose1Date - date of first vaccine (YYYY-MM-DD)
--	-	VaccineDose2Date - date of second vaccine (YYYY-MM-DD)
--	-	VaccineDose3Date - date of third vaccine (YYYY-MM-DD)
--	-	VaccineDose4Date - date of fourth vaccine (YYYY-MM-DD)
--	-	VaccineDose5Date - date of fifth vaccine (YYYY-MM-DD)
--	-	VaccineDose6Date - date of sixth vaccine (YYYY-MM-DD)
--	-	VaccineDose7Date - date of seventh vaccine (YYYY-MM-DD)

-- Get patients with covid vaccine and earliest and latest date
-- >>> Codesets required... Inserting the code set code
--
--┌────────────────────┐
--│ Clinical code sets │
--└────────────────────┘

-- OBJECTIVE: To populate temporary tables with the existing clinical code sets.
--            See the [SQL-generation-process.md](SQL-generation-process.md) for more details.

-- INPUT: No pre-requisites

-- OUTPUT: Five temp tables as follows:
--  #AllCodes (Concept, Version, Code)
--  #CodeSets (FK_Reference_Coding_ID, Concept)
--  #SnomedSets (FK_Reference_SnomedCT_ID, FK_SNOMED_ID)
--  #VersionedCodeSets (FK_Reference_Coding_ID, Concept, Version)
--  #VersionedSnomedSets (FK_Reference_SnomedCT_ID, Version, FK_SNOMED_ID)

--!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
--!!! DO NOT EDIT THIS FILE MANUALLY !!!
--!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

IF OBJECT_ID('tempdb..#AllCodes') IS NOT NULL DROP TABLE #AllCodes;
CREATE TABLE #AllCodes (
  [Concept] [varchar](255) NOT NULL,
  [Version] INT NOT NULL,
  [Code] [varchar](20) COLLATE Latin1_General_CS_AS NOT NULL,
  [description] [varchar] (255) NULL 
);

IF OBJECT_ID('tempdb..#codesreadv2') IS NOT NULL DROP TABLE #codesreadv2;
CREATE TABLE #codesreadv2 (
  [concept] [varchar](255) NOT NULL,
  [version] INT NOT NULL,
	[code] [varchar](20) COLLATE Latin1_General_CS_AS NOT NULL,
	[term] [varchar](20) COLLATE Latin1_General_CS_AS NULL,
	[description] [varchar](255) NULL
) ON [PRIMARY];

INSERT INTO #codesreadv2
VALUES ('covid-vaccination',1,'65F0.',NULL,'2019-nCoV (novel coronavirus) vaccination'),('covid-vaccination',1,'65F0.00',NULL,'2019-nCoV (novel coronavirus) vaccination'),('covid-vaccination',1,'65F01',NULL,'Administration of first dose of SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccine'),('covid-vaccination',1,'65F0100',NULL,'Administration of first dose of SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccine'),('covid-vaccination',1,'65F02',NULL,'2019-nCoV (novel coronavirus) vaccination'),('covid-vaccination',1,'65F0200',NULL,'2019-nCoV (novel coronavirus) vaccination'),('covid-vaccination',1,'65F06',NULL,'SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccination'),('covid-vaccination',1,'65F0600',NULL,'SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccination'),('covid-vaccination',1,'65F07',NULL,'Immunisation course to achieve immunity against SARS-CoV-2'),('covid-vaccination',1,'65F0700',NULL,'Immunisation course to achieve immunity against SARS-CoV-2'),('covid-vaccination',1,'65F08',NULL,'Immunisation course to maintain protection against SARS-CoV-2'),('covid-vaccination',1,'65F0800',NULL,'Immunisation course to maintain protection against SARS-CoV-2'),('covid-vaccination',1,'65F09',NULL,'Administration of third dose of SARS-CoV-2 vaccine'),('covid-vaccination',1,'65F0900',NULL,'Administration of third dose of SARS-CoV-2 vaccine'),('covid-vaccination',1,'65F0A',NULL,'Administration of fourth dose of SARS-CoV-2 vaccine'),('covid-vaccination',1,'65F0A00',NULL,'Administration of fourth dose of SARS-CoV-2 vaccine'),('covid-vaccination',1,'9bJ..',NULL,'COVID-19 mRNA Vaccine BNT162b2 30micrograms/0.3ml dose concentrate for suspension for injection multidose vials (Pfizer-BioNTech)'),('covid-vaccination',1,'9bJ..00',NULL,'COVID-19 mRNA Vaccine BNT162b2 30micrograms/0.3ml dose concentrate for suspension for injection multidose vials (Pfizer-BioNTech)')

INSERT INTO #AllCodes
SELECT [concept], [version], [code], [description] from #codesreadv2;

IF OBJECT_ID('tempdb..#codesctv3') IS NOT NULL DROP TABLE #codesctv3;
CREATE TABLE #codesctv3 (
  [concept] [varchar](255) NOT NULL,
  [version] INT NOT NULL,
	[code] [varchar](20) COLLATE Latin1_General_CS_AS NOT NULL,
	[term] [varchar](20) COLLATE Latin1_General_CS_AS NULL,
	[description] [varchar](255) NULL
) ON [PRIMARY];

INSERT INTO #codesctv3
VALUES ('covid-vaccination',1,'Y210d',NULL,'2019-nCoV (novel coronavirus) vaccination'),('covid-vaccination',1,'Y29e7',NULL,'Administration of first dose of SARS-CoV-2 vaccine'),('covid-vaccination',1,'Y29e8',NULL,'Administration of second dose of SARS-CoV-2 vaccine'),('covid-vaccination',1,'Y2a0e',NULL,'SARS-2 Coronavirus vaccine'),('covid-vaccination',1,'Y2a0f',NULL,'COVID-19 mRNA Vaccine BNT162b2 30micrograms/0.3ml dose concentrate for suspension for injection multidose vials (Pfizer-BioNTech) part 1'),('covid-vaccination',1,'Y2a3a',NULL,'COVID-19 mRNA Vaccine BNT162b2 30micrograms/0.3ml dose concentrate for suspension for injection multidose vials (Pfizer-BioNTech) part 2'),('covid-vaccination',1,'65F06',NULL,'SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccination'),('covid-vaccination',1,'65F09',NULL,'Administration of third dose of SARS-CoV-2 vaccine'),('covid-vaccination',1,'65F0A',NULL,'Administration of fourth dose of SARS-CoV-2 vaccine'),('covid-vaccination',1,'9bJ..',NULL,'COVID-19 mRNA Vaccine BNT162b2 30micrograms/0.3ml dose concentrate for suspension for injection multidose vials (Pfizer-BioNTech)'),('covid-vaccination',1,'Y2a10',NULL,'COVID-19 Vac AstraZeneca (ChAdOx1 S recomb) 5x10000000000 viral particles/0.5ml dose sol for inj MDV part 1'),('covid-vaccination',1,'Y2a39',NULL,'COVID-19 Vac AstraZeneca (ChAdOx1 S recomb) 5x10000000000 viral particles/0.5ml dose sol for inj MDV part 2'),('covid-vaccination',1,'Y2b9d',NULL,'COVID-19 mRNA (nucleoside modified) Vaccine Moderna 0.1mg/0.5mL dose dispersion for injection multidose vials part 2'),('covid-vaccination',1,'Y2f45',NULL,'Administration of third dose of SARS-CoV-2 vaccine'),('covid-vaccination',1,'Y2f48',NULL,'Administration of fourth dose of SARS-CoV-2 vaccine'),('covid-vaccination',1,'Y2f57',NULL,'COVID-19 mRNA Vaccine BNT162b2 30micrograms/0.3ml dose concentrate for suspension for injection multidose vials (Pfizer-BioNTech) booster'),('covid-vaccination',1,'Y31cc',NULL,'SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) antigen vaccination'),('covid-vaccination',1,'Y31e6',NULL,'Administration of SARS-CoV-2 mRNA vaccine'),('covid-vaccination',1,'Y31e7',NULL,'Administration of first dose of SARS-CoV-2 mRNA vaccine'),('covid-vaccination',1,'Y31e8',NULL,'Administration of second dose of SARS-CoV-2 mRNA vaccine')

INSERT INTO #AllCodes
SELECT [concept], [version], [code], [description] from #codesctv3;

IF OBJECT_ID('tempdb..#codessnomed') IS NOT NULL DROP TABLE #codessnomed;
CREATE TABLE #codessnomed (
  [concept] [varchar](255) NOT NULL,
  [version] INT NOT NULL,
	[code] [varchar](20) COLLATE Latin1_General_CS_AS NOT NULL,
	[term] [varchar](20) COLLATE Latin1_General_CS_AS NULL,
	[description] [varchar](255) NULL
) ON [PRIMARY];

INSERT INTO #codessnomed
VALUES ('covid-vaccination',1,'1240491000000103',NULL,'2019-nCoV (novel coronavirus) vaccination'),('covid-vaccination',1,'2807821000000115',NULL,'2019-nCoV (novel coronavirus) vaccination'),('covid-vaccination',1,'840534001',NULL,'Severe acute respiratory syndrome coronavirus 2 vaccination (procedure)')

INSERT INTO #AllCodes
SELECT [concept], [version], [code], [description] from #codessnomed;

IF OBJECT_ID('tempdb..#codesemis') IS NOT NULL DROP TABLE #codesemis;
CREATE TABLE #codesemis (
  [concept] [varchar](255) NOT NULL,
  [version] INT NOT NULL,
	[code] [varchar](20) COLLATE Latin1_General_CS_AS NOT NULL,
	[term] [varchar](20) COLLATE Latin1_General_CS_AS NULL,
	[description] [varchar](255) NULL
) ON [PRIMARY];

INSERT INTO #codesemis
VALUES ('covid-vaccination',1,'^ESCT1348323',NULL,'Administration of first dose of SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccine'),('covid-vaccination',1,'^ESCT1348324',NULL,'Administration of first dose of 2019-nCoV (novel coronavirus) vaccine'),('covid-vaccination',1,'COCO138186NEMIS',NULL,'COVID-19 mRNA Vaccine BNT162b2 30micrograms/0.3ml dose concentrate for suspension for injection multidose vials (Pfizer-BioNTech) (Pfizer-BioNTech)'),('covid-vaccination',1,'^ESCT1348325',NULL,'Administration of second dose of SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccine'),('covid-vaccination',1,'^ESCT1348326',NULL,'Administration of second dose of 2019-nCoV (novel coronavirus) vaccine'),('covid-vaccination',1,'^ESCT1428354',NULL,'Administration of third dose of SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccine'),('covid-vaccination',1,'^ESCT1428342',NULL,'Administration of fourth dose of SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccine'),('covid-vaccination',1,'^ESCT1428348',NULL,'Administration of fifth dose of SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccine'),('covid-vaccination',1,'^ESCT1348298',NULL,'SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccination'),('covid-vaccination',1,'^ESCT1348301',NULL,'COVID-19 vaccination'),('covid-vaccination',1,'^ESCT1299050',NULL,'2019-nCoV (novel coronavirus) vaccination'),('covid-vaccination',1,'^ESCT1301222',NULL,'SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccination'),('covid-vaccination',1,'CODI138564NEMIS',NULL,'Covid-19 mRna (nucleoside modified) Vaccine Moderna  Dispersion for injection  0.1 mg/0.5 ml dose, multidose vial'),('covid-vaccination',1,'TASO138184NEMIS',NULL,'Covid-19 Vaccine AstraZeneca (ChAdOx1 S recombinant)  Solution for injection  5x10 billion viral particle/0.5 ml multidose vial'),('covid-vaccination',1,'PCSDT18491_1375',NULL,'Administration of first dose of SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccine'),('covid-vaccination',1,'PCSDT18491_1376',NULL,'Administration of second dose of SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccine'),('covid-vaccination',1,'PCSDT18491_716',NULL,'Administration of second dose of SARS-CoV-2 vacc'),('covid-vaccination',1,'PCSDT18491_903',NULL,'Administration of first dose of SARS-CoV-2 vacccine'),('covid-vaccination',1,'PCSDT3370_2254',NULL,'2019-nCoV (novel coronavirus) vaccination'),('covid-vaccination',1,'PCSDT3919_2185',NULL,'Administration of first dose of SARS-CoV-2 vacccine'),('covid-vaccination',1,'PCSDT3919_662',NULL,'Administration of second dose of SARS-CoV-2 vacc'),('covid-vaccination',1,'PCSDT4803_1723',NULL,'2019-nCoV (novel coronavirus) vaccination'),('covid-vaccination',1,'PCSDT5823_2264',NULL,'Administration of second dose of SARS-CoV-2 vacc'),('covid-vaccination',1,'PCSDT5823_2757',NULL,'Administration of second dose of SARS-CoV-2 (severe acute respiratory syndrome coronavirus 2) vaccine'),('covid-vaccination',1,'PCSDT5823_2902',NULL,'Administration of first dose of SARS-CoV-2 vacccine'),('covid-vaccination',1,'^ESCT1348300',NULL,'Severe acute respiratory syndrome coronavirus 2 vaccination'),('covid-vaccination',1,'ASSO138368NEMIS',NULL,'COVID-19 Vaccine Janssen (Ad26.COV2-S [recombinant]) 0.5ml dose suspension for injection multidose vials (Janssen-Cilag Ltd)'),('covid-vaccination',1,'COCO141057NEMIS',NULL,'Comirnaty Children 5-11 years COVID-19 mRNA Vaccine 10micrograms/0.2ml dose concentrate for dispersion for injection multidose vials (Pfizer Ltd)'),('covid-vaccination',1,'COSO141059NEMIS',NULL,'COVID-19 Vaccine Covishield (ChAdOx1 S [recombinant]) 5x10,000,000,000 viral particles/0.5ml dose solution for injection multidose vials (Serum Institute of India)'),('covid-vaccination',1,'COSU138776NEMIS',NULL,'COVID-19 Vaccine Valneva (inactivated adjuvanted whole virus) 40antigen units/0.5ml dose suspension for injection multidose vials (Valneva UK Ltd)'),('covid-vaccination',1,'COSU138943NEMIS',NULL,'COVID-19 Vaccine Novavax (adjuvanted) 5micrograms/0.5ml dose suspension for injection multidose vials (Baxter Oncology GmbH)'),('covid-vaccination',1,'COSU141008NEMIS',NULL,'CoronaVac COVID-19 Vaccine (adjuvanted) 600U/0.5ml dose suspension for injection vials (Sinovac Life Sciences)'),('covid-vaccination',1,'COSU141037NEMIS',NULL,'COVID-19 Vaccine Sinopharm BIBP (inactivated adjuvanted) 6.5U/0.5ml dose suspension for injection vials (Beijing Institute of Biological Products)')

INSERT INTO #AllCodes
SELECT [concept], [version], [code], [description] from #codesemis;


IF OBJECT_ID('tempdb..#TempRefCodes') IS NOT NULL DROP TABLE #TempRefCodes;
CREATE TABLE #TempRefCodes (FK_Reference_Coding_ID BIGINT NOT NULL, concept VARCHAR(255) NOT NULL, version INT NOT NULL, [description] VARCHAR(255));

-- Read v2 codes
INSERT INTO #TempRefCodes
SELECT PK_Reference_Coding_ID, dcr.concept, dcr.[version], dcr.[description]
FROM [SharedCare].[Reference_Coding] rc
INNER JOIN #codesreadv2 dcr on dcr.code = rc.MainCode
WHERE CodingType='ReadCodeV2'
AND (dcr.term IS NULL OR dcr.term = rc.Term)
and PK_Reference_Coding_ID != -1;

-- CTV3 codes
INSERT INTO #TempRefCodes
SELECT PK_Reference_Coding_ID, dcc.concept, dcc.[version], dcc.[description]
FROM [SharedCare].[Reference_Coding] rc
INNER JOIN #codesctv3 dcc on dcc.code = rc.MainCode
WHERE CodingType='CTV3'
and PK_Reference_Coding_ID != -1;

-- EMIS codes with a FK Reference Coding ID
INSERT INTO #TempRefCodes
SELECT FK_Reference_Coding_ID, ce.concept, ce.[version], ce.[description]
FROM [SharedCare].[Reference_Local_Code] rlc
INNER JOIN #codesemis ce on ce.code = rlc.LocalCode
WHERE FK_Reference_Coding_ID != -1;

IF OBJECT_ID('tempdb..#TempSNOMEDRefCodes') IS NOT NULL DROP TABLE #TempSNOMEDRefCodes;
CREATE TABLE #TempSNOMEDRefCodes (FK_Reference_SnomedCT_ID BIGINT NOT NULL, concept VARCHAR(255) NOT NULL, [version] INT NOT NULL, [description] VARCHAR(255));

-- SNOMED codes
INSERT INTO #TempSNOMEDRefCodes
SELECT PK_Reference_SnomedCT_ID, dcs.concept, dcs.[version], dcs.[description]
FROM SharedCare.Reference_SnomedCT rs
INNER JOIN #codessnomed dcs on dcs.code = rs.ConceptID;

-- EMIS codes with a FK SNOMED ID but without a FK Reference Coding ID
INSERT INTO #TempSNOMEDRefCodes
SELECT FK_Reference_SnomedCT_ID, ce.concept, ce.[version], ce.[description]
FROM [SharedCare].[Reference_Local_Code] rlc
INNER JOIN #codesemis ce on ce.code = rlc.LocalCode
WHERE FK_Reference_Coding_ID = -1
AND FK_Reference_SnomedCT_ID != -1;

-- De-duped tables
IF OBJECT_ID('tempdb..#CodeSets') IS NOT NULL DROP TABLE #CodeSets;
CREATE TABLE #CodeSets (FK_Reference_Coding_ID BIGINT NOT NULL, concept VARCHAR(255) NOT NULL, [description] VARCHAR(255));

IF OBJECT_ID('tempdb..#SnomedSets') IS NOT NULL DROP TABLE #SnomedSets;
CREATE TABLE #SnomedSets (FK_Reference_SnomedCT_ID BIGINT NOT NULL, concept VARCHAR(255) NOT NULL, [description] VARCHAR(255));

IF OBJECT_ID('tempdb..#VersionedCodeSets') IS NOT NULL DROP TABLE #VersionedCodeSets;
CREATE TABLE #VersionedCodeSets (FK_Reference_Coding_ID BIGINT NOT NULL, Concept VARCHAR(255), [Version] INT, [description] VARCHAR(255));

IF OBJECT_ID('tempdb..#VersionedSnomedSets') IS NOT NULL DROP TABLE #VersionedSnomedSets;
CREATE TABLE #VersionedSnomedSets (FK_Reference_SnomedCT_ID BIGINT NOT NULL, Concept VARCHAR(255), [Version] INT, [description] VARCHAR(255));

INSERT INTO #VersionedCodeSets
SELECT DISTINCT * FROM #TempRefCodes;

INSERT INTO #VersionedSnomedSets
SELECT DISTINCT * FROM #TempSNOMEDRefCodes;

INSERT INTO #CodeSets
SELECT FK_Reference_Coding_ID, c.concept, [description]
FROM #VersionedCodeSets c
INNER JOIN (
  SELECT concept, MAX(version) AS maxVersion FROM #VersionedCodeSets
  GROUP BY concept)
sub ON sub.concept = c.concept AND c.version = sub.maxVersion;

INSERT INTO #SnomedSets
SELECT FK_Reference_SnomedCT_ID, c.concept, [description]
FROM #VersionedSnomedSets c
INNER JOIN (
  SELECT concept, MAX(version) AS maxVersion FROM #VersionedSnomedSets
  GROUP BY concept)
sub ON sub.concept = c.concept AND c.version = sub.maxVersion;

-- >>> Following code sets injected: covid-vaccination v1


IF OBJECT_ID('tempdb..#VacEvents') IS NOT NULL DROP TABLE #VacEvents;
SELECT FK_Patient_Link_ID, CONVERT(DATE, EventDate) AS EventDate into #VacEvents
FROM #PatientEventData
WHERE SuppliedCode IN (
	SELECT [Code] FROM #AllCodes WHERE [Concept] = 'covid-vaccination' AND [Version] = 1
)
AND EventDate > '2020-12-01';

IF OBJECT_ID('tempdb..#VacMeds') IS NOT NULL DROP TABLE #VacMeds;
SELECT FK_Patient_Link_ID, CONVERT(DATE, MedicationDate) AS EventDate into #VacMeds
FROM #PatientMedicationData
WHERE SuppliedCode IN (
	SELECT [Code] FROM #AllCodes WHERE [Concept] = 'covid-vaccination' AND [Version] = 1
)
AND MedicationDate > '2020-12-01';

IF OBJECT_ID('tempdb..#COVIDVaccines') IS NOT NULL DROP TABLE #COVIDVaccines;
SELECT FK_Patient_Link_ID, EventDate into #COVIDVaccines FROM #VacEvents
UNION
SELECT FK_Patient_Link_ID, EventDate FROM #VacMeds;
--4426892 5m03

-- Tidy up
DROP TABLE #VacEvents;
DROP TABLE #VacMeds;

-- Get first vaccine dose
IF OBJECT_ID('tempdb..#VacTemp1') IS NOT NULL DROP TABLE #VacTemp1;
select FK_Patient_Link_ID, MIN(EventDate) AS VaccineDoseDate
into #VacTemp1
from #COVIDVaccines
group by FK_Patient_Link_ID;
--2046837

-- Get second vaccine dose (if exists) - assume dose within 14 days is same dose
IF OBJECT_ID('tempdb..#VacTemp2') IS NOT NULL DROP TABLE #VacTemp2;
select c.FK_Patient_Link_ID, MIN(c.EventDate) AS VaccineDoseDate
into #VacTemp2
from #VacTemp1 v
inner join #COVIDVaccines c on c.EventDate > DATEADD(day, 14, v.VaccineDoseDate) and c.FK_Patient_Link_ID = v.FK_Patient_Link_ID
group by c.FK_Patient_Link_ID;
--1810762

-- Get third vaccine dose (if exists) - assume dose within 14 days is same dose
IF OBJECT_ID('tempdb..#VacTemp3') IS NOT NULL DROP TABLE #VacTemp3;
select c.FK_Patient_Link_ID, MIN(c.EventDate) AS VaccineDoseDate
into #VacTemp3
from #VacTemp2 v
inner join #COVIDVaccines c on c.EventDate > DATEADD(day, 14, v.VaccineDoseDate) and c.FK_Patient_Link_ID = v.FK_Patient_Link_ID
group by c.FK_Patient_Link_ID;
--578468

-- Get fourth vaccine dose (if exists) - assume dose within 14 days is same dose
IF OBJECT_ID('tempdb..#VacTemp4') IS NOT NULL DROP TABLE #VacTemp4;
select c.FK_Patient_Link_ID, MIN(c.EventDate) AS VaccineDoseDate
into #VacTemp4
from #VacTemp3 v
inner join #COVIDVaccines c on c.EventDate > DATEADD(day, 14, v.VaccineDoseDate) and c.FK_Patient_Link_ID = v.FK_Patient_Link_ID
group by c.FK_Patient_Link_ID;
--1860

-- Get fifth vaccine dose (if exists) - assume dose within 14 days is same dose
IF OBJECT_ID('tempdb..#VacTemp5') IS NOT NULL DROP TABLE #VacTemp5;
select c.FK_Patient_Link_ID, MIN(c.EventDate) AS VaccineDoseDate
into #VacTemp5
from #VacTemp4 v
inner join #COVIDVaccines c on c.EventDate > DATEADD(day, 14, v.VaccineDoseDate) and c.FK_Patient_Link_ID = v.FK_Patient_Link_ID
group by c.FK_Patient_Link_ID;
--39

-- Get sixth vaccine dose (if exists) - assume dose within 14 days is same dose
IF OBJECT_ID('tempdb..#VacTemp6') IS NOT NULL DROP TABLE #VacTemp6;
select c.FK_Patient_Link_ID, MIN(c.EventDate) AS VaccineDoseDate
into #VacTemp6
from #VacTemp5 v
inner join #COVIDVaccines c on c.EventDate > DATEADD(day, 14, v.VaccineDoseDate) and c.FK_Patient_Link_ID = v.FK_Patient_Link_ID
group by c.FK_Patient_Link_ID;
--2

-- Get seventh vaccine dose (if exists) - assume dose within 14 days is same dose
IF OBJECT_ID('tempdb..#VacTemp7') IS NOT NULL DROP TABLE #VacTemp7;
select c.FK_Patient_Link_ID, MIN(c.EventDate) AS VaccineDoseDate
into #VacTemp7
from #VacTemp6 v
inner join #COVIDVaccines c on c.EventDate > DATEADD(day, 14, v.VaccineDoseDate) and c.FK_Patient_Link_ID = v.FK_Patient_Link_ID
group by c.FK_Patient_Link_ID;
--2

IF OBJECT_ID('tempdb..#COVIDVaccinations') IS NOT NULL DROP TABLE #COVIDVaccinations;
SELECT v1.FK_Patient_Link_ID, v1.VaccineDoseDate AS VaccineDose1Date,
v2.VaccineDoseDate AS VaccineDose2Date,
v3.VaccineDoseDate AS VaccineDose3Date,
v4.VaccineDoseDate AS VaccineDose4Date,
v5.VaccineDoseDate AS VaccineDose5Date,
v6.VaccineDoseDate AS VaccineDose6Date,
v7.VaccineDoseDate AS VaccineDose7Date
INTO #COVIDVaccinations
FROM #VacTemp1 v1
LEFT OUTER JOIN #VacTemp2 v2 ON v2.FK_Patient_Link_ID = v1.FK_Patient_Link_ID
LEFT OUTER JOIN #VacTemp3 v3 ON v3.FK_Patient_Link_ID = v1.FK_Patient_Link_ID
LEFT OUTER JOIN #VacTemp4 v4 ON v4.FK_Patient_Link_ID = v1.FK_Patient_Link_ID
LEFT OUTER JOIN #VacTemp5 v5 ON v5.FK_Patient_Link_ID = v1.FK_Patient_Link_ID
LEFT OUTER JOIN #VacTemp6 v6 ON v6.FK_Patient_Link_ID = v1.FK_Patient_Link_ID
LEFT OUTER JOIN #VacTemp7 v7 ON v7.FK_Patient_Link_ID = v1.FK_Patient_Link_ID;

-- Tidy up
DROP TABLE #VacTemp1;
DROP TABLE #VacTemp2;
DROP TABLE #VacTemp3;
DROP TABLE #VacTemp4;
DROP TABLE #VacTemp5;
DROP TABLE #VacTemp6;
DROP TABLE #VacTemp7;



SELECT FK_Patient_Link_ID AS PatientId, EventDate AS VaccineDate FROM #COVIDVaccines
ORDER BY FK_Patient_Link_ID, EventDate;