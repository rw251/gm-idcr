--┌─────────────────────────────────┐
--│ Cancer Lung Small Cell          │
--└─────────────────────────────────┘


-- OUTPUT: A single table with the following:
--       [PK_Lung_Small_Cell_ID]
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
--       ,[ALK]
--       ,[ALKFromNewBiopsy]
--       ,[AlkalinePhosphatase]
--       ,[AreThereSynchronousBilateralTumours]
--       ,[BasisOfDiagnosis]
--       ,[BRAF]
--       ,[BRAFFromNewBiopsy]
--       ,[ClinicalFIGOStage]
--       ,[ClinicalFrailtyScale]
--       ,[ClinicalStage]
--       ,[ConsultantConferred]
--       ,[CurrentDiseaseStatusForThisCancer]
--       ,[CurrentProgressiveDisease]
--       ,[DateOfDiagnosis]
--       ,[DateOfDiseaseProgression]
--       ,[DateOfOriginalDiagnosis]
--       ,[DateOfRelapse]
--       ,[DateOfSurgery]
--       ,[DateSeen]
--       ,[DateSymptomsFirstNoted]
--       ,[DefinitiveTreatmentPlanned]
--       ,[Diagnosis]
--       ,[Differentiation]
--       ,[DifferentiationFromNewBiopsy]
--       ,[DiseaseFreeFollowingPrimaryTreatment]
--       ,[DLCO]
--       ,[EGFR]
--       ,[EGFRFromNewBiopsy]
--       ,[EntryIntoAClinicalTrial]
--       ,[ExtraPulmonarySite]
--       ,[FEV1]
--       ,[FGFR]
--       ,[FGFRFromNewBiopsy]
--       ,[FVC]
--       ,[Histology]
--       ,[HistologyFromNewBiopsy]
--       ,[ImmediateProposedManagement]
--       ,[KCO]
--       ,[KeyWorkerName]
--       ,[KRAS]
--       ,[KRASFromNewBiopsy]
--       ,[LDH]
--       ,[ManagementDeclinedByPatient]
--       ,[ManchesterScore]
--       ,[MET]
--       ,[METFromNewBiopsy]
--       ,[MetastaticDiseaseIndicator]
--       ,[MutationAnalysis]
--       ,[MutationAnalysisFromNewBiopsy]
--       ,[NewBiopsy]
--       ,[PackYears]
--       ,[PathFIGOStage]
--       ,[PathStage]
--       ,[PatientAppropriateForGoldStandardsFramework]
--       ,[PatientWasReferredForSecondOpinion]
--       ,[PerformanceStatus]
--       ,[PI3K]
--       ,[PI3KFromNewBiopsy]
--       ,[PlannedBiologicalTherapy]
--       ,[PlannedChemotherapyRegimen]
--       ,[PlannedDefinitiveTreatment]
--       ,[PlannedRadiotherapySites]
--       ,[PreviousChemotherapyRegimens]
--       ,[PreviousRadiotherapySite]
--       ,[PreviousSurgicalProcedureForThisCancer]
--       ,[PreviousTreatmentForThisCancer]
--       ,[PrimaryDiseaseSite]
--       ,[PrimaryTreatmentGivenWithCurativeIntent]
--       ,[PulmonaryFunctionTests]
--       ,[RecordingSynchronousBilateralTumours]
--       ,[ReferredBy]
--       ,[ReferringHospital]
--       ,[ResectionMargin]
--       ,[ResponsibleConsultant]
--       ,[SeenBy]
--       ,[SeenByKeyWorker]
--       ,[SerumNa]
--       ,[Side]
--       ,[SitesOfCurrentDisease]
--       ,[SmokingHistory]
--       ,[SourceOfTissueDiagnosis]
--       ,[TreatmentIntent]
--       ,[TreatmentStatusForThisCancer]
--       ,[TrialName]
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
FROM [SharedCare].[Cancer_Lung_Small_Cell];

/* Drop the columns that are not needed */
ALTER TABLE #TempTable
DROP COLUMN [FK_Patient_Link_ID], [FK_Patient_ID];

SELECT * FROM #TempTable;