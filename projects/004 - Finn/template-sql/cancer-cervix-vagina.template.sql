--┌─────────────────────────────────┐
--│ Cancer cervix vagina              │
--└─────────────────────────────────┘


-- OUTPUT: A single table with the following:
--       [PK_Cervix-Vagina_Cancer_ID]
--       ,[ExternalID]
--       ,[CreateDate]
--       ,[ModifDate]
--       ,[LoadID]
--       ,[Deleted]
--       ,[HDMModifDate]
--       ,[FK_Reference_Tenancy_ID]
--       ,[FK_Patient_Link_ID]
--       ,[FK_Patient_ID]
--       ,[NhsNo]
--       ,[FormInstance]
--       ,[FormDataID]
--       ,[FormID]
--       ,[ExamKey]
--       ,[CRISOrderNo]
--       ,[StatusID]
--       ,[Date]
--       ,[FormLoadedTS]
--       ,[EventKey]
--       ,[DeleteFlag]
--       ,[TStemp]
--       ,[ConsultantID]
--       ,[BatchUpdate]
--       ,[DateCreated]
--       ,[CreatedBy]
--       ,[DateModified]
--       ,[ModifiedBy]
--       ,[ACEComorbidities]
--       ,[ActionFollowingReferralForSecondOpinion]
--       ,[BaselineMorbidity]
--       ,[BaselineMorbidityCTCAE]
--       ,[BaselineMorbidityMeasurements]
--       ,[BasisOfDiagnosis]
--       ,[BodyMassIndex]
--       ,[BowelFunction]
--       ,[CervicalSmearHistory]
--       ,[ClinicalFrailtyScale]
--       ,[ClinicalStage]
--       ,[ClosestMarginSite]
--       ,[ConsultantConferred]
--       ,[CurrentDiseaseStatusForThisCancer]
--       ,[CurrentProgressiveDisease]
--       ,[DateOfBirth]
--       ,[DateOfDiagnosis]
--       ,[DateOfDiseaseProgression]
--       ,[DateOfOriginalDiagnosis]
--       ,[DateOfRelapse]
--       ,[DateOfSmokingCessation]
--       ,[DateOfSurgery]
--       ,[DateSeen]
--       ,[DateSymptomsFirstNoted]
--       ,[DefinitiveSurgeryPlanned]
--       ,[Diagnosis]
--       ,[Differentiation]
--       ,[DifferentiationFromNewBiopsy]
--       ,[DiseaseFreeFollowingPrimaryTreatment]
--       ,[EntryIntoAClinicalTrial]
--       ,[FurtherPreviousChemotherapyDetails]
--       ,[HasThePatientBeenGivenSmokingCessationAdvice]
--       ,[Height]
--       ,[Histology]
--       ,[HistologyFromNewBiopsy]
--       ,[ImmediateProposedManagement]
--       ,[InvolvedNodes]
--       ,[KeyWorkerName]
--       ,[LVSI]
--       ,[LVSIFromNewBiopsy]
--       ,[ManagementDeclinedByPatient]
--       ,[MarkerDetailsRelapse]
--       ,[NewBiopsy]
--       ,[NumberOfProceduresForThisCancer]
--       ,[OtherPreviousTreatmentForThisCancer]
--       ,[PathStage]
--       ,[PatientAge]
--       ,[PatientAppropriateForGoldStandardsFramework]
--       ,[PatientWasReferredForSecondOpinion]
--       ,[PatientRecordedMorbidity]
--       ,[PerformanceStatus]
--       ,[PlannedAccess]
--       ,[PlannedChemotherapyRegimen]
--       ,[PlannedSurgicalProcedures]
--       ,[PreviousChemotherapyLines]
--       ,[PreviousChemotherapyRegimen1]
--       ,[PreviousChemotherapyRegimen2]
--       ,[PreviousChemotherapyRegimen3]
--       ,[PreviousPelvicSurgery]
--       ,[PreviousRadiotherapyCentre]
--       ,[PreviousRadiotherapySite]
--       ,[PreviousSurgicalProcedureForThisCancer]
--       ,[PreviousSurgicalProcedureForThisCancer2]
--       ,[PreviousTreatmentForThisCancer]
--       ,[PrimaryDiseaseSite]
--       ,[PrimaryTreatmentGivenWithCurativeIntent]
--       ,[RectalUrgencyBaseline]
--       ,[ReferredBy]
--       ,[ReferredForFertilityConsultation]
--       ,[ReferringHospital]
--       ,[ResectionMarginDistance]
--       ,[ResponsibleConsultant]
--       ,[SeenBy]
--       ,[SeenByKeyWorker]
--       ,[SexualFunction]
--       ,[SiteSOfCurrentDisease]
--       ,[SmokingHistory]
--       ,[SubsequentBrachytherapyPlanned]
--       ,[SubsequentChemotherapyPlanned]
--       ,[SubsequentRadiotherapyPlanned]
--       ,[TreatmentIntent]
--       ,[TreatmentStatusForThisCancer]
--       ,[TreatmentTypeBrachytherapy]
--       ,[TrialName]
--       ,[TruncatedDataCapture]
--       ,[TumourSizeCm]
--       ,[TumourSizeCmFromNewBiopsy]
--       ,[UrgencyOfDefecationBaseline]
--       ,[UrinaryFunction]
--       ,[VaccinationHistory]
--       ,[Weight]
--       ,[CreatedBySurname]
--       ,[CreatedByForename]
--       ,[CreatedByUserDepartment]
--       ,[CreatedByUserEmployer]
--       ,[ModifiedBySurname]
--       ,[ModifiedByForename]
--       ,[ModifiedByUserDepartment]
--       ,[ModifiedByUserEmployer]
  

--Just want the output, not the messages
SET NOCOUNT ON;


/* simulating a select * except one column */
IF OBJECT_ID('tempdb..#TempTable') IS NOT NULL DROP TABLE #TempTable;
SELECT [FK_Patient_Link_ID] AS PatientId, * INTO #TempTable
FROM [SharedCare].[Cancer_Cervix-Vagina];

/* Drop the columns that are not needed */
ALTER TABLE #TempTable
DROP COLUMN [PK_Cervix-Vagina_Cancer_ID], [FK_Patient_Link_ID], [FK_Patient_ID];

SELECT * FROM #TempTable;