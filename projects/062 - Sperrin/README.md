_This file is autogenerated. Please do not edit._

# _TODO_ - project title

## Summary

**TODO** edit `about.md` to insert a brief lay summary of the work.

## Table of contents

- [Introduction](#introduction)
- [Methodology](#methodology)
- [Reusable queries](#reusable-queries)
- [Clinical code sets](#clinical-code-sets)

## Introduction

The aim of this document is to provide full transparency for all parts of the data extraction process.
This includes:

- The methodology around how the data extraction process is managed and quality is maintained.
- A full list of all queries used in the extraction, and their associated objectives and assumptions.
- A full list of all clinical codes used for the extraction.

## Methodology

After each proposal is approved, a Research Data Engineer (RDE) works closely with the research team to establish precisely what data they require and in what format.
The RDE has access to the entire de-identified database and so builds up an expertise as to which projects are feasible and how best to extract the relevant data.
The RDE has access to a library of resusable SQL queries for common tasks, and sets of clinical codes for different phenotypes, built up from previous studies.
Prior to data extraction, the code is checked and signed off by another RDE.

## Reusable queries
  
This project required the following reusable queries:

- Patient GP encounters
- Lower level super output area
- Index Multiple Deprivation
- Patient GP history
- Sex
- Secondary discharges
- Create listing tables for each GP events - RQ062
- Define Cohort for RQ062: all individuals registered with a GP who were aged 50 years or older on September 1 2013
- Year and quarter month of birth
- GET practice and ccg for each patient
- CCG lookup table

Further details for each query can be found below.

### Patient GP encounters
To produce a table of GP encounters for a list of patients. This script uses many codes related to observations (e.g. blood pressure), symptoms, and diagnoses, to infer when GP encounters occured. This script includes face to face and telephone encounters - it will need copying and editing if you don't require both.

_Assumptions_

- multiple codes on the same day will be classed as one encounter (so max daily encounters per patient is 1)

_Input_
```
Assumes there exists a temp table as follows:
 #Patients (FK_Patient_Link_ID)
  A distinct list of FK_Patient_Link_IDs for each patient in the cohort
```

_Output_
```
A temp table as follows:
 #GPEncounters (FK_Patient_Link_ID, EncounterDate)
	- FK_Patient_Link_ID - unique patient id
	- EncounterDate - date the patient had a GP encounter
```
_File_: `query-patient-gp-encounters.sql`

_Link_: [https://github.com/rw251/.../query-patient-gp-encounters.sql](https://github.com/rw251/gm-idcr/tree/master/shared/Reusable%20queries%20for%20data%20extraction/query-patient-gp-encounters.sql)

---
### Lower level super output area
To get the LSOA for each patient.

_Assumptions_

- Patient data is obtained from multiple sources. Where patients have multiple LSOAs we determine the LSOA as follows:
- If the patients has an LSOA in their primary care data feed we use that as most likely to be up to date
- If every LSOA for a paitent is the same, then we use that
- If there is a single most recently updated LSOA in the database then we use that
- Otherwise the patient's LSOA is considered unknown

_Input_
```
Assumes there exists a temp table as follows:
 #Patients (FK_Patient_Link_ID)
  A distinct list of FK_Patient_Link_IDs for each patient in the cohort
```

_Output_
```
A temp table as follows:
 #PatientLSOA (FK_Patient_Link_ID, LSOA)
 	- FK_Patient_Link_ID - unique patient id
	- LSOA_Code - nationally recognised LSOA identifier
```
_File_: `query-patient-lsoa.sql`

_Link_: [https://github.com/rw251/.../query-patient-lsoa.sql](https://github.com/rw251/gm-idcr/tree/master/shared/Reusable%20queries%20for%20data%20extraction/query-patient-lsoa.sql)

---
### Index Multiple Deprivation
To get the 2019 Index of Multiple Deprivation (IMD) decile for each patient.

_Input_
```
Assumes there exists a temp table as follows:
 #Patients (FK_Patient_Link_ID)
  A distinct list of FK_Patient_Link_IDs for each patient in the cohort
```

_Output_
```
A temp table as follows:
 #PatientIMDDecile (FK_Patient_Link_ID, IMD2019Decile1IsMostDeprived10IsLeastDeprived)
 	- FK_Patient_Link_ID - unique patient id
	- IMD2019Decile1IsMostDeprived10IsLeastDeprived - number 1 to 10 inclusive
```
_File_: `query-patient-imd.sql`

_Link_: [https://github.com/rw251/.../query-patient-imd.sql](https://github.com/rw251/gm-idcr/tree/master/shared/Reusable%20queries%20for%20data%20extraction/query-patient-imd.sql)

---
### Patient GP history
To produce a table showing the start and end dates for each practice the patient has been registered at.

_Assumptions_

- We do not have data on patients who move out of GM, though we do know that it happened. For these patients we record the GPPracticeCode as OutOfArea
- Where two adjacent time periods either overlap, or have a gap between them, we assume that the most recent registration is more accurate and adjust the end date of the first time period accordingly. This is an infrequent occurrence.

_Input_
```
No pre-requisites
```

_Output_
```
A temp table as follows:
 #PatientGPHistory (FK_Patient_Link_ID, GPPracticeCode, StartDate, EndDate)
	- FK_Patient_Link_ID - unique patient id
	- GPPracticeCode - national GP practice id system
	- StartDate - date the patient registered at the practice
	- EndDate - date the patient left the practice
```
_File_: `query-patient-gp-history.sql`

_Link_: [https://github.com/rw251/.../query-patient-gp-history.sql](https://github.com/rw251/gm-idcr/tree/master/shared/Reusable%20queries%20for%20data%20extraction/query-patient-gp-history.sql)

---
### Sex
To get the Sex for each patient.

_Assumptions_

- Patient data is obtained from multiple sources. Where patients have multiple sexes we determine the sex as follows:
- If the patients has a sex in their primary care data feed we use that as most likely to be up to date
- If every sex for a patient is the same, then we use that
- If there is a single most recently updated sex in the database then we use that
- Otherwise the patient's sex is considered unknown

_Input_
```
Assumes there exists a temp table as follows:
 #Patients (FK_Patient_Link_ID)
  A distinct list of FK_Patient_Link_IDs for each patient in the cohort
```

_Output_
```
A temp table as follows:
 #PatientSex (FK_Patient_Link_ID, Sex)
 	- FK_Patient_Link_ID - unique patient id
	- Sex - M/F
```
_File_: `query-patient-sex.sql`

_Link_: [https://github.com/rw251/.../query-patient-sex.sql](https://github.com/rw251/gm-idcr/tree/master/shared/Reusable%20queries%20for%20data%20extraction/query-patient-sex.sql)

---
### Secondary discharges
To obtain a table with every secondary care discharge, along with the acute provider, and the date of discharge.

_Input_
```
One parameter
	-	all-patients: boolean - (true/false) if true, then all patients are included, otherwise only those in the pre-existing #Patients table.
```

_Output_
```
A temp table as follows:
 #Discharges (FK_Patient_Link_ID, DischargeDate, AcuteProvider)
 	- FK_Patient_Link_ID - unique patient id
	- DischargeDate - date of discharge (YYYY-MM-DD)
	- AcuteProvider - Bolton, SRFT, Stockport etc..
  (Limited to one discharge per person per hospital per day, because if a patient has 2 discharges
   on the same day to the same hopsital then it's most likely data duplication rather than two short
   hospital stays)
```
_File_: `query-get-discharges.sql`

_Link_: [https://github.com/rw251/.../query-get-discharges.sql](https://github.com/rw251/gm-idcr/tree/master/shared/Reusable%20queries%20for%20data%20extraction/query-get-discharges.sql)

---
### Create listing tables for each GP events - RQ062
To build the tables listing each requested GP events for RQ062. This reduces duplication of code in the template scripts.

_Input_
```
Assumes there exists one temp table as follows:
 #GPEvents (FK_Patient_Link_ID, EventDate, FK_Reference_Coding_ID, FK_Reference_SnomedCT_ID, SuppliedCode)
```

_Output_
```
A temp table #{param:conditionname} with columns:
 - PatientId
 - EventDate
 - EventCode
 - EventDescription
 - EventCodeSystem (SNOMED, EMIS, ReadV2, CTV3)
```
_File_: `query-build-rq062-gp-events.sql`

_Link_: [https://github.com/rw251/.../query-build-rq062-gp-events.sql](https://github.com/rw251/gm-idcr/tree/master/shared/Reusable%20queries%20for%20data%20extraction/query-build-rq062-gp-events.sql)

---
### Define Cohort for RQ062: all individuals registered with a GP who were aged 50 years or older on September 1 2013
To build the cohort of patients needed for RQ062. This reduces duplication of code in the template scripts.

_Input_
```
undefined
```

_Output_
```
Temp tables as follows:
 #Patients (FK_Patient_Link_ID)
 A distinct list of FK_Patient_Link_IDs for each patient in the cohort
```
_File_: `query-build-rq062-cohort.sql`

_Link_: [https://github.com/rw251/.../query-build-rq062-cohort.sql](https://github.com/rw251/gm-idcr/tree/master/shared/Reusable%20queries%20for%20data%20extraction/query-build-rq062-cohort.sql)

---
### Year and quarter month of birth
To get the year of birth for each patient.

_Assumptions_

- Patient data is obtained from multiple sources. Where patients have multiple YearAndQuarterMonthOfBirths we determine the YearAndQuarterMonthOfBirth as follows:
- If the patients has a YearAndQuarterMonthOfBirth in their primary care data feed we use that as most likely to be up to date
- If every YearAndQuarterMonthOfBirth for a patient is the same, then we use that
- If there is a single most recently updated YearAndQuarterMonthOfBirth in the database then we use that
- Otherwise we take the highest YearAndQuarterMonthOfBirth for the patient that is not in the future

_Input_
```
Assumes there exists a temp table as follows:
 #Patients (FK_Patient_Link_ID)
  A distinct list of FK_Patient_Link_IDs for each patient in the cohort
```

_Output_
```
A temp table as follows:
 #PatientYearAndQuarterMonthOfBirth (FK_Patient_Link_ID, YearAndQuarterMonthOfBirth)
 	- FK_Patient_Link_ID - unique patient id
	- YearAndQuarterMonthOfBirth - (YYYY-MM-01)
```
_File_: `query-patient-year-and-quarter-month-of-birth.sql`

_Link_: [https://github.com/rw251/.../query-patient-year-and-quarter-month-of-birth.sql](https://github.com/rw251/gm-idcr/tree/master/shared/Reusable%20queries%20for%20data%20extraction/query-patient-year-and-quarter-month-of-birth.sql)

---
### GET practice and ccg for each patient
For each patient to get the practice id that they are registered to, and the CCG name that the practice belongs to.

_Input_
```
Assumes there exists a temp table as follows:
 #Patients (FK_Patient_Link_ID)
  A distinct list of FK_Patient_Link_IDs for each patient in the cohort
```

_Output_
```
Two temp tables as follows:
 #PatientPractice (FK_Patient_Link_ID, GPPracticeCode)
	- FK_Patient_Link_ID - unique patient id
	- GPPracticeCode - the nationally recognised practice id for the patient
 #PatientPracticeAndCCG (FK_Patient_Link_ID, GPPracticeCode, CCG)
	- FK_Patient_Link_ID - unique patient id
	- GPPracticeCode - the nationally recognised practice id for the patient
	- CCG - the name of the patient's CCG
```
_File_: `query-patient-practice-and-ccg.sql`

_Link_: [https://github.com/rw251/.../query-patient-practice-and-ccg.sql](https://github.com/rw251/gm-idcr/tree/master/shared/Reusable%20queries%20for%20data%20extraction/query-patient-practice-and-ccg.sql)

---
### CCG lookup table
To provide lookup table for CCG names. The GMCR provides the CCG id (e.g. '00T', '01G') but not the CCG name. This table can be used in other queries when the output is required to be a ccg name rather than an id.

_Input_
```
No pre-requisites
```

_Output_
```
A temp table as follows:
 #CCGLookup (CcgId, CcgName)
 	- CcgId - Nationally recognised ccg id
	- CcgName - Bolton, Stockport etc..
```
_File_: `query-ccg-lookup.sql`

_Link_: [https://github.com/rw251/.../query-ccg-lookup.sql](https://github.com/rw251/gm-idcr/tree/master/shared/Reusable%20queries%20for%20data%20extraction/query-ccg-lookup.sql)
## Clinical code sets

This project required the following clinical code sets:

- shingles v1
- post-herpetic-neuralgia v1
- coronary-heart-disease v1
- stroke v1
- dementia v1
- copd v1
- lung-cancer v1
- pancreatic-cancer v1
- colorectal-cancer v1
- breast-cancer v1
- falls v1
- back-problems v1
- diabetes v1
- flu-vaccination v1
- pneumococcal-vaccination v1
- breast-cancer-screening v1
- colorectal-cancer-screening v1
- respiratory-tract-infection v1

Further details for each code set can be found below.

### Shingles codes

Developed from https://getset.ga with inclusion terms and exclusion terms as below:

  "includeTerms": [
    "shingles",
    "herpes zoster",
    "zoster"
  ],
  "excludeTerms": [
    "vaccination",
    "tablets",
    "tablet",
    "zovirax",
    "vaccine",
    "history of",
    "scarring due to",
    "procedure",
    "injection",
    "adverse reaction",
    "allergy",
    "level",
    "measurement",
    "product",
    "ramsay hunt syndrome 2",
    "substance"
  ]

#### Prevalence log

By examining the prevalence of codes (number of patients with the code in their record) broken down by clinical system, we can attempt to validate the clinical code sets and the reporting of the conditions. Here is a log for this code set. The prevalence range `4.1% - 4.7%` suggests that this code set is well defined.

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2023-10-11 | EMIS            | 2470460    |   101279 (4.1%)  |   100470 (4.1%)   |
| 2023-10-11 | TPP             | 200512     |     9540 (4.8%)  |     9392 (4.7%)   |
| 2023-10-11 | Vision          | 332318     |    14841 (4.5%)  |    14694 (4.4%)   |
LINK: [https://github.com/rw251/.../conditions/shingles/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/conditions/shingles/1)

###  Post herpetic neuralgia codes

Developed from https://getset.ga with inclusion terms and exclusion terms as below:

  "includeTerms": [
    "post-herpetic neuralgia",
    "post-zoster",
    "post-herpetic",
    "post zoster",
    "post herpetic"
  ],
  "excludeTerms": [],

  ## Prevalence log

By examining the prevalence of codes (number of patients with the code in their record) broken down by clinical system, we can attempt to validate the clinical code sets and the reporting of the conditions. Here is a log for this code set. The prevalence range `0.18% - 0.24%` suggests that this code set is well defined.

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2023-10-12 | EMIS            | 2470460    |    5882 (0.24%)  |    5886 (0.24%)   |
| 2023-10-12 | TPP             | 200512     |     374 (0.18%)  |     374 (0.18%)   |
| 2023-10-12 | Vision          | 332318     |     695 (0.21%)  |     692 (0.21%)   |
LINK: [https://github.com/rw251/.../conditions/post-herpetic-neuralgia/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/conditions/post-herpetic-neuralgia/1)

### Coronary heart disease

This code set was developed from https://www.phpc.cam.ac.uk/pcu/research/research-groups/crmh/cprd_cam/codelists/v11/. Codes indicate a diagnosis of CHD.
#### Prevalence log

By examining the prevalence of codes (number of patients with the code in their record) broken down by clinical system, we can attempt to validate the clinical code sets and the reporting of the conditions. Here is a log for this code set. The prevalence range `2.75% - 3.09%` suggests that this code set is well defined.

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2021-05-18 | EMIS            | 2662570    |   73153 (2.75%)  |    73156 (2.75%)  |
| 2021-05-18 | TPP             | 212696     |    6550 (3.08%)  |     6576 (3.09%)  |
| 2021-05-18 | Vision          | 342344     |   10209 (2.98%)  |    10209 (2.98%)  |

LINK: [https://github.com/rw251/.../conditions/coronary-heart-disease/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/conditions/coronary-heart-disease/1)

### Stroke

Any code indicating a diagnosis of a stroke. Includes ischaemic and haemorrhagic strokes.
#### Prevalence log

By examining the prevalence of codes (number of patients with the code in their record) broken down by clinical system, we can attempt to validate the clinical code sets and the reporting of the conditions. Here is a log for this code set.

The discrepancy between the patients counted when using the IDs vs using the clinical codes is due to these being new codes which haven't all filtered through to the main Graphnet dictionary. The prevalence range `0.91% - 1.45%` suggests that this code set is well defined.

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2022-05-12 | EMIS            | 2662570    |    24378 (0.92%) |     24359 (0.91%) |
| 2022-05-12 | TPP             | 212696     |     2441 (1.45%) |      2445 (1.45%) |
| 2022-05-12 | Vision          | 342344     |     3308 (0.97%) |      3307 (0.97%) |
| 2023-09-12 | EMIS            | 2463856    |   23678 (0.961%) |    11237 (0.456%) |
| 2023-09-12 | TPP             | 200590     |     2631 (1.31%) |      2593 (1.29%) |
| 2023-09-12 | Vision          | 332095     |    3098 (0.933%) |     1699 (0.512%) |

LINK: [https://github.com/rw251/.../conditions/stroke/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/conditions/stroke/1)

### Dementia

Any code indicating that a person has dementia, including Alzheimer's disease.

Code set from https://www.opencodelists.org/codelist/opensafely/dementia-complete/48c76cf8/
#### Prevalence log

By examining the prevalence of codes (number of patients with the code in their record) broken down by clinical system, we can attempt to validate the clinical code sets and the reporting of the conditions. Here is a log for this code set. The prevalence range `0.67% - 0.81%` suggests that this code set is likely well defined.

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2022-12-20 | EMIS            | 2438146    |   19770 (0.811%) |    21772 (0.893%) |
| 2022-12-20 | TPP             | 198637     |    1427 (0.718%) |      7445 (3.75%) |
| 2022-12-20 | Vision          | 327196     |    2244 (0.686%) |     2265 (0.692%) |

LINK: [https://github.com/rw251/.../conditions/dementia/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/conditions/dementia/1)

### COPD

Any suggestion of a diagnosis of COPD.

Developed from https://getset.ga.
#### Prevalence log

By examining the prevalence of codes (number of patients with the code in their record) broken down by clinical system, we can attempt to validate the clinical code sets and the reporting of the conditions. Here is a log for this code set. The prevalence range `2.17% - 2.48%` in 2023 suggests that this code set is well defined.

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2021-05-07 | EMIS            | 2605681    |    54668 (2.10%) |     54669 (2.10%) |
| 2021-05-07 | TPP             | 210817     |     4537 (2.15%) |      4538 (2.15%) |
| 2021-05-07 | Vision          | 334632     |     7789 (2.33%) |      7789 (2.33%) |
| 2023-09-15 | EMIS            | 2463856    |    53577 (2.17%) |     53551 (2.17%) |
| 2023-09-15 | TPP             | 200590     |     4959 (2.47%) |      4966 (2.48%) |
| 2023-09-15 | Vision          | 332095     |     7382 (2.22%) |      7374 (2.22%) |

LINK: [https://github.com/rw251/.../conditions/copd/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/conditions/copd/1)

###  Lung cancer codes

Developed from https://getset.ga with inclusion terms and exclusion terms as below:

"includeTerms": [
    "lung cancer"
  ],
  "excludeTerms": [
    "family history of",
    "screening declined",
    "no fh of",
    "lung cancer risk calculator",
    "fh: lung cancer",
    "lung cancer screening",
    "qcancer lung cancer risk"
  ]


  ## Prevalence log

By examining the prevalence of codes (number of patients with the code in their record) broken down by clinical system, we can attempt to validate the clinical code sets and the reporting of the conditions. Here is a log for this code set. The prevalence range `0.18% - 0.24%` suggests that this code set is well defined.

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2023-10-12 | EMIS            | 2470460    |    5882 (0.24%)  |    5886 (0.24%)   |
| 2023-10-12 | TPP             | 200512     |     374 (0.18%)  |     374 (0.18%)   |
| 2023-10-12 | Vision          | 332318     |     695 (0.21%)  |     692 (0.21%)   |
LINK: [https://github.com/rw251/.../conditions/lung-cancer/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/conditions/lung-cancer/1)

"includeTerms": [
    "pancreatic cancer"
  ],
  "excludeTerms": [
    "family history of",
    "assessment using qcancer pancreatic cancer risk calculator (procedure)",
    "qcancer pancreatic cancer risk calculator"
  ]
LINK: [https://github.com/rw251/.../conditions/pancreatic-cancer/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/conditions/pancreatic-cancer/1)

###  Colorectal cancer codes

Developed from https://getset.ga with inclusion terms and exclusion terms as below:

"includeTerms": [
    "colorectal cancer",
    "bowel cancer",
    "rectal cancer",
    "colon cancer"
  ],
  "excludeTerms": [
    "family history of",
    "screening",
    "patient given advice about",
    "fh:",
    "cancer risk",
    "suspected",
    "discharge from secondary care colorectal cancer service",
    "college of american pathologists cancer checklist"
  ]

and OpenCodelists (https://www.opencodelists.org/codelist/phc/phc-colorectal-cancer-ctv3/0706cfd2/#full-list and https://www.opencodelists.org/codelist/phc/phc-colorectal-cancer-snomed/3925b63c/#full-list) 

  ## Prevalence log

By examining the prevalence of codes (number of patients with the code in their record) broken down by clinical system, we can attempt to validate the clinical code sets and the reporting of the conditions. Here is a log for this code set. The prevalence range `0.33% - 0.42%` suggests that this code set is well defined.

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2023-10-13 | EMIS            | 2470460    |    8214 (0.33%)  |    8228 (0.33%)   |
| 2023-10-13 | TPP             | 200512     |     848 (0.42%)  |     848 (0.42%)   |
| 2023-10-13 | Vision          | 332318     |    1158 (0.34%)  |    1159 (0.34%)   |
LINK: [https://github.com/rw251/.../conditions/colorectal-cancer/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/conditions/colorectal-cancer/1)

### Breast cancer codes

Developed from https://getset.ga with inclusion terms and exclusion terms as below:

"includeTerms": [
    "breast cancer"
  ],
  "excludeTerms": [
    "no fh of",
    "familial cancer of breast",
    "no history of",
    "national cancer institute breast cancer risk assessment tool",
    "education about risk of breast cancer",
    "family history of",
    "fear of breast cancer",
    "breast cancer screening declined",
    "claus model",
    "screening for breast cancer",
    "bcrat - breast cancer risk assessment tool",
    "nottingham histologic grading system for breast cancer",
    "fh:",
    "meets nice clinical guideline cg164 familial breast cancer referral criteria for assessment and management in secondary care",
    "national cancer institute breast cancer risk assessment score",
    "at risk of breast cancer (finding)",
    "qcancer breast cancer risk"
  ]

and clinicalcodes.org (https://clinicalcodes.rss.mhs.man.ac.uk/medcodes/article/24/codelist/res24-breast-cancer/) 

  ## Prevalence log

By examining the prevalence of codes (number of patients with the code in their record) broken down by clinical system, we can attempt to validate the clinical code sets and the reporting of the conditions. Here is a log for this code set. The prevalence range `0.8% - 0.9%` suggests that this code set is well defined.

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2023-10-25 | EMIS            | 2472595    |    20089 (0.8%)  |    20102 (0.8%)   |
| 2023-10-25 | TPP             | 200603     |     1808 (0.9%)  |     1808 (0.9%)   |
| 2023-10-25 | Vision          | 332447     |     2900 (0.9%)  |     2901 (0.9%)   |
LINK: [https://github.com/rw251/.../conditions/breast-cancer/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/conditions/breast-cancer/1)

### Falls

Codes taken from OpenCodelists https://www.opencodelists.org/codelist/opensafely/falls/2020-07-09/#full-list and https://www.opencodelists.org/codelist/nhsd-primary-care-domain-refsets/falls_cod/20200812/#full-list 
#### Prevalence log

By examining the prevalence of codes (number of patients with the code in their record) broken down by clinical system, we can attempt to validate the clinical code sets and the reporting of the conditions. Here is a log for this code set. The prevalence range `1.7% - 2.8%` suggests that this code set is well defined.

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2023-10-25 | EMIS            | 2472595    |     54002 (2.2%) |      54015 (2.2%) |
| 2023-10-25 | TPP             | 200603     |      5597 (2.8%) |       5598 (2.8%) |
| 2023-10-25 | Vision          | 332447     |      5537 (1.7%) |       5545 (1.7%) |
LINK: [https://github.com/rw251/.../patient/falls/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/patient/falls/1)

### Back problems

Read codes from: https://clinicalcodes.rss.mhs.man.ac.uk/medcodes/article/6/codelist/back-pain/ 

SNOMED codes from: https://clinicalcodes.rss.mhs.man.ac.uk/medcodes/article/174/codelist/res174-low-back-diagnoses/ and https://www.opencodelists.org/snomedct/concept/279038004/ 
#### Prevalence log

By examining the prevalence of codes (number of patients with the code in their record) broken down by clinical system, we can attempt to validate the clinical code sets and the reporting of the conditions. Here is a log for this code set.

The discrepancy between the patients counted when using the IDs vs using the clinical codes is due to these being new codes which haven't all filtered through to the main Graphnet dictionary. The prevalence range `27.3% - 32.4%` suggests this code set is well defined.

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2022-03-03 | EMIS            | 2656596    |  782005 (29.44%) |   781204 (29.41%) |
| 2022-03-03 | TPP             | 212503     |   57991 (27.29%) |    57990 (27.29%) |
| 2022-03-03 | Vision          | 341299     |  110555 (32.39%) |   110552 (32.39%) |

LINK: [https://github.com/rw251/.../conditions/back-problems/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/conditions/back-problems/1)

### Diabetes mellitus

Code set for any diagnosis of diabetes mellitus (type I/type II/other).

Developed from https://getset.ga.
#### Prevalence log

By examining the prevalence of codes (number of patients with the code in their record) broken down by clinical system, we can attempt to validate the clinical code sets and the reporting of the conditions. Here is a log for this code set. The prevalence range `5.96% - 6.05%` suggests that this code set is well defined.

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2021-05-07 | EMIS            | 2605681    |   155421 (5.96%) |    155398 (5.96%) |
| 2021-05-07 | TPP             | 210817     |    12743 (6.04%) |     12745 (6.05%) |
| 2021-05-07 | Vision          | 334632     |    20145 (6.02%) |     20145 (6.02%) |
| 2023-09-15 | EMIS            | 2463856    |    162625 (6.6%) |    148520 (6.03%) |
| 2023-09-15 | TPP             | 200590     |    15745 (7.85%) |     15685 (7.82%) |
| 2023-09-15 | Vision          | 332095     |    21031 (6.33%) |     18869 (5.68%) |

LINK: [https://github.com/rw251/.../conditions/diabetes/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/conditions/diabetes/1)

### Flu vaccination

Any code that indicates that the patient has had a flu vaccine. Includes procedure codes and admin codes confirming a vaccination has been administered. **NB it does not include the flu vaccine product - see the `flu-vaccine` code set**

LINK: [https://github.com/rw251/.../procedures/flu-vaccination/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/procedures/flu-vaccination/1)

### Pneumococcal vaccination

Codes taken from OpenCodelists https://www.opencodelists.org/codelist/nhsd-primary-care-domain-refsets/pcv_cod/20200812/#full-list and https://www.opencodelists.org/codelist/nhsd-primary-care-domain-refsets/pneuvac1_cod/20210127/#full-list
#### Prevalence log

By examining the prevalence of codes (number of patients with the code in their record) broken down by clinical system, we can attempt to validate the clinical code sets and the reporting of the conditions. Here is a log for this code set. The prevalence range `34.2% - 34.8%` for EMIS and Vision suggests that this code set is well defined. TPP practices are a lot lower at `16.2%` which may be down to the way the codes are recorded there.

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2023-11-01 | EMIS            | 2472595    |   722523 (29.2%) |    862422 (34.8%) |
| 2023-11-01 | TPP             | 200603     |    30992 (15.4%) |     32488 (16.2%) |
| 2023-11-01 | Vision          | 332447     |   110871 (33.3%) |    113668 (34.2%) |


MED

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2023-11-10 | EMIS            | 2482563    |    43312 (1.74%) |     43313 (1.74%) | 
| 2023-11-10 | TPP             | 201030     |     73 (0.0363%) |      74 (0.0368%) | 
| 2023-11-10 | Vision          | 333490     |     2702 (0.81%) |      2702 (0.81%) | 

EVENT

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2023-11-10 | EMIS            | 2482563    |   722186 (29.1%) |    860756 (34.7%) | 
| 2023-11-10 | TPP             | 201030     |    31354 (15.6%) |     32487 (16.2%) | 
| 2023-11-10 | Vision          | 333490     |   110696 (33.2%) |      113431 (34%) | 

LINK: [https://github.com/rw251/.../procedures/pneumococcal-vaccination/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/procedures/pneumococcal-vaccination/1)


### Breast cancer screening codes

Developed from https://getset.ga with inclusion terms and exclusion terms as below:

"includeTerms": [
    "breast cancer screening"
  ],
  "excludeTerms": [
    "breast cancer screening declined"
  ]

and from OpenCodelists https://www.opencodelists.org/codelist/nhsd-primary-care-domain-refsets/brcanscr_cod/20200812/#full-list
#### Prevalence log

By examining the prevalence of codes (number of patients with the code in their record) broken down by clinical system, we can attempt to validate the clinical code sets and the reporting of the conditions. Here is a log for this code set. The prevalence range `12.7% - 16.2%` suggests that this code set is well defined.

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2023-10-17 | EMIS            | 2468919    |  313158 (12.7%)  |   313277 (12.7%)  |
| 2023-10-17 | TPP             | 200465     |   32464 (16.2%)  |    32467 (16.2%)  |
| 2023-10-17 | Vision          | 332162     |   45707 (13.7%)  |    45724 (13.7%)  |
LINK: [https://github.com/rw251/.../procedures/breast-cancer-screening/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/procedures/breast-cancer-screening/1)

### Colorectal cancer screening codes

Developed from https://getset.ga with inclusion terms and exclusion terms as below:

"includeTerms": [
    "colorectal cancer screening",
    "colon cancer screening",
    "rectal cancer screening",
    "bowel cancer screening"
  ],
  "excludeTerms": [
    "colon cancer screening declined",
    "screening for malignant neoplasm of large intestine not done",
    "not eligible",
    "did not attend",
    "no response to bowel cancer screening programme invitation",
    "declined",
    "advice given about bowel cancer screening programme",
    "invitation",
    "provision of written information about bowel cancer screening programme"
  ]
and from OpenCodelists https://www.opencodelists.org/codelist/nhsd-primary-care-domain-refsets/colcanscr_cod/20200812/#full-list
#### Prevalence log

By examining the prevalence of codes (number of patients with the code in their record) broken down by clinical system, we can attempt to validate the clinical code sets and the reporting of the conditions. Here is a log for this code set. The prevalence range `19.8% - 25.3%` suggests that this code set is well defined.

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2023-10-17 | EMIS            | 2470047    |  489640 (19.8%)  |   489820 (19.8%)  |
| 2023-10-17 | TPP             | 200464     |   50735 (25.3%)  |    50743 (25.3%)  |
| 2023-10-17 | Vision          | 332273     |   67508 (20.3%)  |    67525 (20.3%)  |
LINK: [https://github.com/rw251/.../procedures/colorectal-cancer-screening/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/procedures/colorectal-cancer-screening/1)

### Respiratory tract infection

Any indication of a respiratory tract infection.
#### Prevalence log

By examining the prevalence of codes (number of patients with the code in their record) broken down by clinical system, we can attempt to validate the clinical code sets and the reporting of the conditions. Here is a log for this code set. The prevalence range `56.3% - 62.2%` suggests that this code set is well defined.

update:

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2022-12-07 | EMIS            | 2438760    |  1373106 (56.3%) |   1374853 (56.4%) |
| 2022-12-07 | TPP             | 198672     |   123546 (62.2%) |      125113 (63%) |
| 2022-12-07 | Vision          | 327081     |   192697 (58.9%) |    192482 (58.8%) |

LINK: [https://github.com/rw251/.../conditions/respiratory-tract-infection/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/conditions/respiratory-tract-infection/1)
# Clinical code sets

All code sets required for this analysis are available here: [https://github.com/rw251/.../062 - Sperrin/clinical-code-sets.csv](https://github.com/rw251/gm-idcr/tree/master/projects/062%20-%20Sperrin/clinical-code-sets.csv). Individual lists for each concept can also be found by using the links above.