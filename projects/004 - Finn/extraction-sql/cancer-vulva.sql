--┌─────────────────────────────────┐
--│ Cancer vulva                    │
--└─────────────────────────────────┘


-- OUTPUT: A single table with the following:
--       [PK_Vulva_Cancer_ID]
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
--       ,[ReferringHospital]
--       ,[ReferredBy]
--       ,[SeenBy]
--       ,[DateSeen]
--       ,[ResponsibleConsultant]
--       ,[PrimaryDiseaseSite]
--       ,[TreatmentStatusForThisCancer]
--       ,[CurrentDiseaseStatusForThisCancer]
--       ,[DateOfOriginalDiagnosis]
--       ,[PrimaryTreatmentGivenWithCurativeIntent]
--       ,[DiseaseFreeFollowingPrimaryTreatment]
--       ,[DateOfRelapse]
--       ,[NewBiopsy]
--       ,[HistologyFromNewBiopsy]
--       ,[LVSIFromNewBiopsy]
--       ,[DifferentiationFromNewBiopsy]
--       ,[CurrentProgressiveDisease]
--       ,[DateOfDiseaseProgression]
--       ,[DateSymptomsFirstNoted]
--       ,[DateOfDiagnosis]
--       ,[BasisOfDiagnosis]
--       ,[SitesOfCurrentDisease]
--       ,[MetastaticDiseaseIndicator]
--       ,[TruncatedDataCapture]
--       ,[PreviousTreatmentForThisCancer]
--       ,[PreviousChemotherapyRegimens]
--       ,[NumberOfProceduresForThisCancer]
--       ,[PreviousRadiotherapySite]
--       ,[PreviousSurgicalProcedureForThisCancer]
--       ,[PreviousSurgicalProcedureForThisCancer2]
--       ,[PreviousSurgicalProcedureForThisCancer3]
--       ,[DateOfSurgery]
--       ,[ResectionMarginDistance]
--       ,[NodalStatus]
--       ,[NodalExtraCapsularExtension]
--       ,[Histology]
--       ,[Differentiation]
--       ,[LVSI]
--       ,[InvolvedNodes]
--       ,[TumourSizeCm]
--       ,[ClinicalStage]
--       ,[PathStage]
--       ,[PreviousChemotherapyLines]
--       ,[PerformanceStatus]
--       ,[ACEComorbidities]
--       ,[PreviousChemotherapyRegimen2]
--       ,[PreviousTreatmentForOtherVulvalMalignancies]
--       ,[PreviousChemotherapyRegimen3]
--       ,[NumberOfPreviousVulvalExcisions]
--       ,[PreviousNodalSurgery]
--       ,[FurtherPreviousChemotherapyDetails]
--       ,[PreviousRadiotherapyForOtherVulvalMalignancies]
--       ,[SmokingHistory]
--       ,[DateOfSmokingCessation]
--       ,[HIVStatus]
--       ,[TreatmentIntent]
--       ,[PatientAppropriateForGoldStandardsFramework]
--       ,[DefinitiveSurgeryPlanned]
--       ,[ImmediateProposedManagement]
--       ,[PlannedSurgicalProcedures]
--       ,[PlannedAccess]
--       ,[PlannedChemotherapyRegimen]
--       ,[SitesOfPlannedRadiotherapy]
--       ,[ManagementDeclinedByPatient]
--       ,[EntryIntoAClinicalTrial]
--       ,[TrialName]
--       ,[BaselineMorbidityMeasurements]
--       ,[BaselineMorbidity]
--       ,[BaselineMorbidityCTCAE]
--       ,[UrgencyOfDefecationBaseline]
--       ,[RectalUrgencyBaseline]
--       ,[PatientRecordedMorbidity]
--       ,[BowelFunction]
--       ,[Diagnosis]
--       ,[UrinaryFunction]
--       ,[SexualFunction]
--       ,[SeenByKeyWorker]
--       ,[KeyWorkerName]
--       ,[ConsultantConferred]
--       ,[PatientWasReferredForSecondOpinion]
--       ,[ActionFollowingReferralForSecondOpinion]
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
FROM [SharedCare].[Cancer_Vulva];

/* Drop the columns that are not needed */
ALTER TABLE #TempTable
DROP COLUMN [FK_Patient_Link_ID], [FK_Patient_ID];

SELECT * FROM #TempTable;