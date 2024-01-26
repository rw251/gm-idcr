_This file is autogenerated. Please do not edit._

# Air Pollution Exposure and COVID-19 Severity: A Retrospective Study in Greater Manchester

## Summary

Several national and international studies have linked long- and short-term air pollution exposure to incidence and mortality of COVID-19. However, most of these studies have focused on regional exposures such as PM2.5 and NO2 and findings have mostly been drawn from ecological analyses using population level data on air pollution exposure and COVID-19 outcomes aggregated over various geospatial areas (Chen et al, 2021). This is problematic as ecological studies infer association at the population level, whereas it may not exist at an individual level, and it can also be difficult to detect complicated exposure-outcome relationships.

Our research would aim to further explore the link between long-term exposure to air pollution and COVID-19 severity.

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

- Secondary admissions and length of stay
- Secondary discharges
- COVID vaccinations
- Index Multiple Deprivation
- Lower level super output area
- Smoking status
- Sex
- Year of birth
- Patients with COVID

Further details for each query can be found below.

### Secondary admissions and length of stay
To obtain a table with every secondary care admission, along with the acute provider, the date of admission, the date of discharge, and the length of stay.

_Input_
```
One parameter
	-	all-patients: boolean - (true/false) if true, then all patients are included, otherwise only those in the pre-existing #Patients table.
```

_Output_
```
Two temp table as follows:
 #Admissions (FK_Patient_Link_ID, AdmissionDate, AcuteProvider)
 	- FK_Patient_Link_ID - unique patient id
	- AdmissionDate - date of admission (YYYY-MM-DD)
	- AcuteProvider - Bolton, SRFT, Stockport etc..
  (Limited to one admission per person per hospital per day, because if a patient has 2 admissions
   on the same day to the same hopsital then it's most likely data duplication rather than two short
   hospital stays)
 #LengthOfStay (FK_Patient_Link_ID, AdmissionDate)
 	- FK_Patient_Link_ID - unique patient id
	- AdmissionDate - date of admission (YYYY-MM-DD)
	- AcuteProvider - Bolton, SRFT, Stockport etc..
	- DischargeDate - date of discharge (YYYY-MM-DD)
	- LengthOfStay - Number of days between admission and discharge. 1 = [0,1) days, 2 = [1,2) days, etc.
```
_File_: `query-get-admissions-and-length-of-stay.sql`

_Link_: [https://github.com/rw251/.../query-get-admissions-and-length-of-stay.sql](https://github.com/rw251/gm-idcr/tree/master/shared/Reusable%20queries%20for%20data%20extraction/query-get-admissions-and-length-of-stay.sql)

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
### COVID vaccinations
To obtain a table with first, second, third... etc vaccine doses per patient.

_Assumptions_

- GP records can often be duplicated. The assumption is that if a patient receives two vaccines within 14 days of each other then it is likely that both codes refer to the same vaccine.
- The vaccine can appear as a procedure or as a medication. We assume that the presence of either represents a vaccination

_Input_
```
Takes two parameters:
	- gp-events-table: string - (table name) the name of the table containing the GP events. Usually is "RLS.vw_GP_Events" but can be anything with the columns: FK_Patient_Link_ID, EventDate, and SuppliedCode
	- gp-medications-table: string - (table name) the name of the table containing the GP medications. Usually is "RLS.vw_GP_Medications" but can be anything with the columns: FK_Patient_Link_ID, EventDate, and SuppliedCode
```

_Output_
```
A temp table as follows:
 #COVIDVaccinations (FK_Patient_Link_ID, VaccineDate, DaysSinceFirstVaccine)
 	- FK_Patient_Link_ID - unique patient id
	- VaccineDose1Date - date of first vaccine (YYYY-MM-DD)
	-	VaccineDose2Date - date of second vaccine (YYYY-MM-DD)
	-	VaccineDose3Date - date of third vaccine (YYYY-MM-DD)
	-	VaccineDose4Date - date of fourth vaccine (YYYY-MM-DD)
	-	VaccineDose5Date - date of fifth vaccine (YYYY-MM-DD)
	-	VaccineDose6Date - date of sixth vaccine (YYYY-MM-DD)
	-	VaccineDose7Date - date of seventh vaccine (YYYY-MM-DD)
```
_File_: `query-get-covid-vaccines.sql`

_Link_: [https://github.com/rw251/.../query-get-covid-vaccines.sql](https://github.com/rw251/gm-idcr/tree/master/shared/Reusable%20queries%20for%20data%20extraction/query-get-covid-vaccines.sql)

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
### Smoking status
To get the smoking status for each patient in a cohort.

_Assumptions_

- We take the most recent smoking status in a patient's record to be correct
- However, there is likely confusion between the "non smoker" and "never smoked" codes. Especially as sometimes the synonyms for these codes overlap. Therefore, a patient wih a most recent smoking status of "never", but who has previous smoking codes, would be classed as WorstSmokingStatus=non-trivial-smoker / CurrentSmokingStatus=non-smoker

_Input_
```
Assumes there exists a temp table as follows:
 #Patients (FK_Patient_Link_ID)
  A distinct list of FK_Patient_Link_IDs for each patient in the cohort
 Also takes one parameter:
	- gp-events-table: string - (table name) the name of the table containing the GP events. Usually is "RLS.vw_GP_Events" but can be anything with the columns: FK_Patient_Link_ID, EventDate, FK_Reference_Coding_ID, and FK_Reference_SnomedCT_ID
```

_Output_
```
A temp table as follows:
 #PatientSmokingStatus (FK_Patient_Link_ID, PassiveSmoker, WorstSmokingStatus, CurrentSmokingStatus)
	- FK_Patient_Link_ID - unique patient id
	- PassiveSmoker - Y/N (whether a patient has ever had a code for passive smoking)
	- WorstSmokingStatus - [non-trivial-smoker/trivial-smoker/non-smoker]
	- CurrentSmokingStatus - [non-trivial-smoker/trivial-smoker/non-smoker]
```
_File_: `query-patient-smoking-status.sql`

_Link_: [https://github.com/rw251/.../query-patient-smoking-status.sql](https://github.com/rw251/gm-idcr/tree/master/shared/Reusable%20queries%20for%20data%20extraction/query-patient-smoking-status.sql)

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
### Year of birth
To get the year of birth for each patient.

_Assumptions_

- Patient data is obtained from multiple sources. Where patients have multiple YOBs we determine the YOB as follows:
- If the patients has a YOB in their primary care data feed we use that as most likely to be up to date
- If every YOB for a patient is the same, then we use that
- If there is a single most recently updated YOB in the database then we use that
- Otherwise we take the highest YOB for the patient that is not in the future

_Input_
```
Assumes there exists a temp table as follows:
 #Patients (FK_Patient_Link_ID)
  A distinct list of FK_Patient_Link_IDs for each patient in the cohort
```

_Output_
```
A temp table as follows:
 #PatientYearOfBirth (FK_Patient_Link_ID, YearOfBirth)
 	- FK_Patient_Link_ID - unique patient id
	- YearOfBirth - INT
```
_File_: `query-patient-year-of-birth.sql`

_Link_: [https://github.com/rw251/.../query-patient-year-of-birth.sql](https://github.com/rw251/gm-idcr/tree/master/shared/Reusable%20queries%20for%20data%20extraction/query-patient-year-of-birth.sql)

---
### Patients with COVID
To get tables of all patients with a COVID diagnosis in their record. This now includes a table that has reinfections. This uses a 90 day cut-off to rule out patients that get multiple tests for a single infection. This 90 day cut-off is also used in the government COVID dashboard. In the first wave, prior to widespread COVID testing, and prior to the correct clinical codes being	available to clinicians, infections were recorded in a variety of ways. We therefore take the first diagnosis from any code indicative of COVID. However, for subsequent infections we insist on the presence of a positive COVID test (PCR or antigen) as opposed to simply a diagnosis code. This is to avoid the situation where a hospital diagnosis code gets entered into the primary care record several months after the actual infection.

_Input_
```
Takes three parameters
  - start-date: string - (YYYY-MM-DD) the date to count diagnoses from. Usually this should be 2020-01-01.
	-	all-patients: boolean - (true/false) if true, then all patients are included, otherwise only those in the pre-existing #Patients table.
	- gp-events-table: string - (table name) the name of the table containing the GP events. Usually is "SharedCare.GP_Events" but can be anything with the columns: FK_Patient_Link_ID, EventDate, and SuppliedCode
```

_Output_
```
Three temp tables as follows:
 #CovidPatients (FK_Patient_Link_ID, FirstCovidPositiveDate)
 	- FK_Patient_Link_ID - unique patient id
	- FirstCovidPositiveDate - earliest COVID diagnosis
 #CovidPatientsAllDiagnoses (FK_Patient_Link_ID, CovidPositiveDate)
 	- FK_Patient_Link_ID - unique patient id
	- CovidPositiveDate - any COVID diagnosis
 #CovidPatientsMultipleDiagnoses
	-	FK_Patient_Link_ID - unique patient id
	-	FirstCovidPositiveDate - date of first COVID diagnosis
	-	SecondCovidPositiveDate - date of second COVID diagnosis
	-	ThirdCovidPositiveDate - date of third COVID diagnosis
	-	FourthCovidPositiveDate - date of fourth COVID diagnosis
	-	FifthCovidPositiveDate - date of fifth COVID diagnosis
```
_File_: `query-patients-with-covid.sql`

_Link_: [https://github.com/rw251/.../query-patients-with-covid.sql](https://github.com/rw251/gm-idcr/tree/master/shared/Reusable%20queries%20for%20data%20extraction/query-patients-with-covid.sql)
## Clinical code sets

This project required the following clinical code sets:

- covid-positive-antigen-test v1
- covid-positive-pcr-test v1
- covid-positive-test-other v1
- smoking-status-current v1
- smoking-status-currently-not v1
- smoking-status-ex v1
- smoking-status-ex-trivial v1
- smoking-status-never v1
- smoking-status-passive v1
- smoking-status-trivial v1
- covid-vaccination v1
- asthma v1
- coronary-heart-disease v1
- stroke v1
- diabetes-type-i v1
- diabetes-type-ii v1
- copd v1
- hypertension v1
- bmi v2

Further details for each code set can be found below.

### COVID-19 positive antigen test

A code that indicates that a person has a positive antigen test for COVID-19.
#### COVID positive tests in primary care

The codes used in primary care to indicate a positive COVID test can be split into 3 types: antigen test, PCR test and other. We keep these as separate code sets. However due to the way that COVID diagnoses are recorded in different ways in different GP systems, and because some codes are ambiguous, currently it only makes sense to group these 3 code sets together. Therefore the prevalence log below is for the combined code sets of `covid-positive-antigen-test`, `covid-positive-pcr-test` and `covid-positive-test-other`.
#### Prevalence log

By examining the prevalence of codes (number of patients with the code in their record) broken down by clinical system, we can attempt to validate the clinical code sets and the reporting of the conditions. Here is a log for this code set. The prevalence range `19.7% - 25.4%` suggests that this code set is likely well defined. _NB - this code set needs to rely on the SuppliedCode in the database rather than the foreign key ids._

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2022-02-25 | EMIS            | 2656041    |   152972 (5.76%) |    545759 (20.5%) |
| 2022-02-25 | TPP             | 212453     |      256 (0.12%) |     39503 (18.6%) |
| 2022-02-25 | Vision          | 341354     |     9440 (2.77%) |     65963 (19.3%) |
| 2023-10-04 | EMIS            | 2465646    |     567107 (23%) |    572342 (23.2%) |
| 2023-10-04 | TPP             | 200499     |     2840 (1.42%) |     50964 (25.4%) |
| 2023-10-04 | Vision          | 332029     |    62534 (18.8%) |     65493 (19.7%) |

LINK: [https://github.com/rw251/.../tests/covid-positive-antigen-test/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/tests/covid-positive-antigen-test/1)

### COVID-19 positive pcr test

A code that indicates that a person has a positive pcr test for COVID-19.
#### COVID positive tests in primary care

The codes used in primary care to indicate a positive COVID test can be split into 3 types: antigen test, PCR test and other. We keep these as separate code sets. However due to the way that COVID diagnoses are recorded in different ways in different GP systems, and because some codes are ambiguous, currently it only makes sense to group these 3 code sets together. Therefore the prevalence log below is for the combined code sets of `covid-positive-antigen-test`, `covid-positive-pcr-test` and `covid-positive-test-other`.
#### Prevalence log

By examining the prevalence of codes (number of patients with the code in their record) broken down by clinical system, we can attempt to validate the clinical code sets and the reporting of the conditions. Here is a log for this code set. The prevalence range `19.7% - 25.4%` suggests that this code set is likely well defined. _NB - this code set needs to rely on the SuppliedCode in the database rather than the foreign key ids._

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2022-02-25 | EMIS            | 2656041    |   152972 (5.76%) |    545759 (20.5%) |
| 2022-02-25 | TPP             | 212453     |      256 (0.12%) |     39503 (18.6%) |
| 2022-02-25 | Vision          | 341354     |     9440 (2.77%) |     65963 (19.3%) |
| 2023-10-04 | EMIS            | 2465646    |     567107 (23%) |    572342 (23.2%) |
| 2023-10-04 | TPP             | 200499     |     2840 (1.42%) |     50964 (25.4%) |
| 2023-10-04 | Vision          | 332029     |    62534 (18.8%) |     65493 (19.7%) |

LINK: [https://github.com/rw251/.../tests/covid-positive-pcr-test/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/tests/covid-positive-pcr-test/1)

### COVID-19 positive test - other

A code that indicates that a person has a positive test for COVID-19, but where the type of test (antigen or PCR) is unknown.
#### COVID positive tests in primary care

The codes used in primary care to indicate a positive COVID test can be split into 3 types: antigen test, PCR test and other. We keep these as separate code sets. However due to the way that COVID diagnoses are recorded in different ways in different GP systems, and because some codes are ambiguous, currently it only makes sense to group these 3 code sets together. Therefore the prevalence log below is for the combined code sets of `covid-positive-antigen-test`, `covid-positive-pcr-test` and `covid-positive-test-other`.
#### Prevalence log

By examining the prevalence of codes (number of patients with the code in their record) broken down by clinical system, we can attempt to validate the clinical code sets and the reporting of the conditions. Here is a log for this code set. The prevalence range `19.7% - 25.4%` suggests that this code set is likely well defined. _NB - this code set needs to rely on the SuppliedCode in the database rather than the foreign key ids._

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2022-02-25 | EMIS            | 2656041    |   152972 (5.76%) |    545759 (20.5%) |
| 2022-02-25 | TPP             | 212453     |      256 (0.12%) |     39503 (18.6%) |
| 2022-02-25 | Vision          | 341354     |     9440 (2.77%) |     65963 (19.3%) |
| 2023-10-04 | EMIS            | 2465646    |     567107 (23%) |    572342 (23.2%) |
| 2023-10-04 | TPP             | 200499     |     2840 (1.42%) |     50964 (25.4%) |
| 2023-10-04 | Vision          | 332029     |    62534 (18.8%) |     65493 (19.7%) |

LINK: [https://github.com/rw251/.../tests/covid-positive-test-other/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/tests/covid-positive-test-other/1)

### Smoking status current

Any code suggestive that a patient is a current smoker.

LINK: [https://github.com/rw251/.../patient/smoking-status-current/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/patient/smoking-status-current/1)

### Smoking status currently not

Any code suggestive that a patient is currently a non-smoker. This is different to the "never smoked" code set.

LINK: [https://github.com/rw251/.../patient/smoking-status-currently-not/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/patient/smoking-status-currently-not/1)

### Smoking status ex

Any code suggestive that a patient is an ex-smoker.

LINK: [https://github.com/rw251/.../patient/smoking-status-ex/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/patient/smoking-status-ex/1)


LINK: [https://github.com/rw251/.../patient/smoking-status-ex-trivial/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/patient/smoking-status-ex-trivial/1)

### Smoking status never

Any code suggestive that a patient has never smoked. This is different to the "currently not" code set.

LINK: [https://github.com/rw251/.../patient/smoking-status-never/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/patient/smoking-status-never/1)


LINK: [https://github.com/rw251/.../patient/smoking-status-passive/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/patient/smoking-status-passive/1)


LINK: [https://github.com/rw251/.../patient/smoking-status-trivial/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/patient/smoking-status-trivial/1)

#### Prevalence log

By examining the prevalence of codes (number of patients with the code in their record) broken down by clinical system, we can attempt to validate the clinical code sets and the reporting of the conditions. Here is a log for this code set.

The discrepancy between the patients counted when using the IDs vs using the clinical codes is due to these being new codes which haven't all filtered through to the main Graphnet dictionary. The prevalence range `1.19% - 26.55%` as of 11th March 2021 is too wide. However the prevalence figure of 26.55% from EMIS is close to public data and is likely ok.

**UPDATE - 25th March 2021** Missing Read and CTV3 codes were added to the vaccination list and now the range of `26.91% - 32.96%` seems reasonable. It should be noted that there is an approx 2 week lag between events occurring and them being entered in the record.

**UPDATE - 12th April 2021**, latest prevalence figures.

**UPDATE - 18th March 2022** There are now new codes for things like 3rd/4th/booster dose of vaccine. The latest prevalence shows `65.0% - 66.3%` have at least one vaccine code in the GP_Events table, and `88.2% - 93.6%` have at least one code for the vaccine in the GP_Medications table.

MED

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2021-05-12 | EMIS            | 2606497    |           0 (0%) |    379577(14.56%) |
| 2021-05-12 | TPP             | 210810     |           0 (0%) |       1637(0.78%) |
| 2021-05-12 | Vision          | 334784     |           0 (0%) |         93(0.03%) |
| 2022-03-18 | EMIS            | 2658131    |  1750506 (65.9%) |    1763420(66.3%) |
| 2022-03-18 | TPP             | 212662     |      8207 (3.9%) |     138285(65.0%) |
| 2022-03-18 | Vision          | 341594     |   122060 (35.7%) |     225844(66.1%) |

EVENT

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2021-05-12 | EMIS            | 2606497    |     4446 (0.17%) |  1101577 (42.26%) |
| 2021-05-12 | TPP             | 210810     |        7 (0.00%) |    87841 (41.66%) |
| 2021-05-12 | Vision          | 334784     |        1 (0.00%) |   142724 (42.63%) |
| 2022-03-18 | EMIS            | 2658131    |  2486786 (93.6%) |   1676951 (63.1%) |
| 2022-03-18 | TPP             | 212662     |   187463 (88.2%) |      7314 (3.44%) |
| 2022-03-18 | Vision          | 341594     |   312617 (91.5%) |     62512 (18.3%) |

LINK: [https://github.com/rw251/.../procedures/covid-vaccination/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/procedures/covid-vaccination/1)

### Asthma

This code set was originally created for the SMASH safe medication dashboard and has been validated in practice.
#### Prevalence log

By examining the prevalence of codes (number of patients with the code in their record) broken down by clinical system, we can attempt to validate the clinical code sets and the reporting of the conditions. Here is a log for this code set. The prevalence range `12.14% - 13.37%` suggests that this code set is well defined.

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2021-05-11 | EMIS            | 2606497    |  335219 (12.86%) |   335223 (12.86%) |
| 2021-05-11 | TPP             | 210810     |   25596 (12.14%) |    25596 (12.14%) |
| 2021-05-11 | Vision          | 334784     |   44764 (13.37%) |    44764 (13.37%) |

LINK: [https://github.com/rw251/.../conditions/asthma/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/conditions/asthma/1)

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

### Diabetes mellitus type 1

Any diagnosis of T1DM. A super set of the QOF business rule.

Developed from https://getset.ga.
#### Prevalence log

By examining the prevalence of codes (number of patients with the code in their record) broken down by clinical system, we can attempt to validate the clinical code sets and the reporting of the conditions. Here is a log for this code set. The prevalence range `0.42% - 0.48%` suggests that this code set is well defined.

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2021-05-07 | EMIS            | 2605681    |    11381 (0.44%) |     11381 (0.44%) |
| 2021-05-07 | TPP             | 210817     |      887 (0.42%) |       887 (0.42%) |
| 2021-05-07 | Vision          | 334632     |     1607 (0.48%) |      1607 (0.48%) |
| 2023-09-12 | EMIS            | 2463856    |   10968 (0.445%) |    10223 (0.415%) |
| 2023-09-12 | TPP             | 200590     |    1094 (0.545%) |     1090 (0.543%) |
| 2023-09-12 | Vision          | 332095     |    1574 (0.474%) |     1455 (0.438%) |
| 2023-09-15 | EMIS            | 2463856    |   10999 (0.446%) |    10253 (0.416%) |
| 2023-09-15 | TPP             | 200590     |    1096 (0.546%) |     1092 (0.544%) |
| 2023-09-15 | Vision          | 332095     |    1578 (0.475%) |     1459 (0.439%) |

LINK: [https://github.com/rw251/.../conditions/diabetes-type-i/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/conditions/diabetes-type-i/1)

### Diabetes mellitus type 2

Any diagnosis of T2DM. A super set of the QOF business rule. Includes "adult onset" diabetes, but DOES NOT include "maturity onset" diabetes.

Developed from https://getset.ga.
#### Prevalence log

By examining the prevalence of codes (number of patients with the code in their record) broken down by clinical system, we can attempt to validate the clinical code sets and the reporting of the conditions. Here is a log for this code set. The prevalence range `5.06% - 5.20%` suggests that this code set is well defined.

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2021-05-07 | EMIS            | 2605681    |   133938 (5.14%) |    133938 (5.14%) |
| 2021-05-07 | TPP             | 210817     |    10954 (5.20%) |     10954 (5.20%) |
| 2021-05-07 | Vision          | 334632     |    16936 (5.06%) |     16933 (5.06%) |
| 2023-09-12 | EMIS            | 2463856    |   139199 (5.65%) |    139230 (5.65%) |
| 2023-09-12 | TPP             | 200590     |    13456 (6.71%) |     13458 (6.71%) |
| 2023-09-12 | Vision          | 332095     |    17554 (5.29%) |     17542 (5.28%) |
| 2023-09-15 | EMIS            | 2463856    |   139785 (5.67%) |    139814 (5.67%) |
| 2023-09-15 | TPP             | 200590     |    13485 (6.72%) |     13487 (6.72%) |
| 2023-09-15 | Vision          | 332095     |    17621 (5.31%) |      17609 (5.3%) |

LINK: [https://github.com/rw251/.../conditions/diabetes-type-ii/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/conditions/diabetes-type-ii/1)

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

### Hypertension

Any diagnosis of hypertension. Excludes hypertension in pregnancy, gestational hyptertension, pre-eclampsia. Based on the QOF code sets for hypertension.

Developed from https://getset.ga.
#### Prevalence log

By examining the prevalence of codes (number of patients with the code in their record) broken down by clinical system, we can attempt to validate the clinical code sets and the reporting of the conditions. Here is a log for this code set. The prevalence range `12.55% - 12.95%` suggests that this code set is well defined.

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2021-07-14 | EMIS            | 2615750    |  328350 (12.55%) |  328339 ( 12.55%) |
| 2021-07-14 | TPP             | 211345     |   27363 (12.95%) |   27362 ( 12.95%) |
| 2021-07-14 | Vision          | 336528     |   43389 (12.89%) |   43389 ( 12.89%) |
| 2023-09-12 | EMIS            | 2463856    |   348882 (14.2%) |    348930 (14.2%) |
| 2023-09-12 | TPP             | 200590     |    33584 (16.7%) |     31906 (15.9%) |
| 2023-09-12 | Vision          | 332095     |    45338 (13.7%) |     45277 (13.6%) |
| 2023-09-15 | EMIS            | 2463856    |   350029 (14.2%) |    350075 (14.2%) |
| 2023-09-15 | TPP             | 200590     |    33643 (16.8%) |     31967 (15.9%) |
| 2023-09-15 | Vision          | 332095     |    45529 (13.7%) |     45467 (13.7%) |

LINK: [https://github.com/rw251/.../conditions/hypertension/1](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/conditions/hypertension/1)

### Body Mass Index (BMI)

A patient's BMI as recorded via clinical code and value. This code set only includes codes that are accompanied by a value (`22K.. - Body Mass Index`). It does not include codes that indicate a patient's BMI (`22K6. - Body mass index less than 20`) without giving the actual value.

**NB: This code set is intended to indicate a patient's BMI. If you need to know whether a BMI was recorded then please use v1 of the code set.**
#### Prevalence log

By examining the prevalence of codes (number of patients with the code in their record) broken down by clinical system, we can attempt to validate the clinical code sets and the reporting of the conditions. Here is a log for this code set. The prevalence range `63.96% - 79.69%` suggests that this code set is perhaps not well defined. However, as EMIS (80% of practices) and TPP (10% of practices) are close, it could simply be down to Vision automatically recording BMIs and therefore increasing the prevalence there.

**UPDATE** By looking at the prevalence of patients with a BMI code that also has a non-zero value the range becomes `62.48% - 64.93%` which suggests that this code set is well defined.

| Date       | Practice system | Population | Patients from ID | Patient from code |
| ---------- | --------------- | ---------- | ---------------: | ----------------: |
| 2021-05-07 | EMIS            | 2605681    | 1709250 (65.60%) |  1709224 (65.60%) |
| 2021-05-07 | TPP             | 210817     |  134841 (63.96%) |   134835 (63.96%) |
| 2021-05-07 | Vision          | 334632     |  266612 (79.67%) |   266612 (79.67%) |
| 2021-05-11 | EMIS            | 2606497    | 1692442 (64.93%) |  1692422 (64.93%) |
| 2021-05-11 | TPP             | 210810     |  134652 (63.87%) |   134646 (63.87%) |
| 2021-05-11 | Vision          | 334784     |  209175 (62.48%) |   209175 (62.48%) |

LINK: [https://github.com/rw251/.../patient/bmi/2](https://github.com/rw251/gm-idcr/tree/master/shared/clinical-code-sets/patient/bmi/2)
# Clinical code sets

All code sets required for this analysis are available here: [https://github.com/rw251/.../043 - Cruickshank/clinical-code-sets.csv](https://github.com/rw251/gm-idcr/tree/master/projects/043%20-%20Cruickshank/clinical-code-sets.csv). Individual lists for each concept can also be found by using the links above.