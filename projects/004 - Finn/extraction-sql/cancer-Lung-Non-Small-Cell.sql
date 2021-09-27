--┌─────────────────────────────────┐
--│ Cancer Lung Non-Small Cell      │
--└─────────────────────────────────┘


-- OUTPUT: A single table with the following:
--       [PK_Lung_Non-Small_Cell_ID]
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
--       ,[ALKSecondSynchronousTumour]
--       ,[ALKThirdSynchronousTumour]
--       ,[ALKFromNewBiopsy]
--       ,[AreThereSynchronousNonSmallCellLungTumours]
--       ,[BasisOfDiagnosis]
--       ,[BasisOfDiagnosisSecondSynchronousTumour]
--       ,[BasisOfDiagnosisThirdSynchronousTumour]
--       ,[BRAF]
--       ,[BRAFSecondSynchronousTumour]
--       ,[BRAFThirdSynchronousTumour]
--       ,[BRAFFromNewBiopsy]
--       ,[ClinicalFrailtyScale]
--       ,[ClinicalStage]
--       ,[ClinicalStageSecondSynchronousTumour]
--       ,[ClinicalStageThirdSynchronousTumour]
--       ,[ConsultantConferred]
--       ,[CurrentDiseaseStatusForThisCancer]
--       ,[CurrentProgressiveDisease]
--       ,[DateOfDiagnosis]
--       ,[DateOfDiseaseProgression]
--       ,[DateOfOriginalDiagnosis]
--       ,[DateOfRelapse]
--       ,[DateOfSurgery]
--       ,[DateOfSurgerySecondSynchronousTumour]
--       ,[DateOfSurgeryThirdSynchronousTumour]
--       ,[DateSeen]
--       ,[DateSymptomsFirstNoted]
--       ,[DefinitiveTreatmentPlanned]
--       ,[Diagnosis]
--       ,[Differentiation]
--       ,[DifferentiationFromNewBiopsy]
--       ,[DiseaseFreeFollowingPrimaryTreatment]
--       ,[DLCO]
--       ,[EGFR]
--       ,[EGFRSecondSynchronousTumour]
--       ,[EGFRThirdSynchronousTumour]
--       ,[EGFRFromNewBiopsy]
--       ,[EntryIntoAClinicalTrial]
--       ,[FEV1]
--       ,[FGFR]
--       ,[FGFRSecondSynchronousTumour]
--       ,[FGFRThirdSynchronousTumour]
--       ,[FGFRFromNewBiopsy]
--       ,[FVC]
--       ,[Histology]
--       ,[HistologySecondSynchronousTumour]
--       ,[HistologyThirdSynchronousTumour]
--       ,[HistologyFromNewBiopsy]
--       ,[ImmediateProposedManagement]
--       ,[ImmediateProposedManagementSecondSynchronousTumour]
--       ,[ImmediateProposedManagementThirdSynchronousTumour]
--       ,[IsThisOligoMetastaticDisease]
--       ,[KCO]
--       ,[KeyWorkerName]
--       ,[KRAS]
--       ,[KRASSecondSynchronousTumour]
--       ,[KRASThirdSynchronousTumour]
--       ,[KRASFromNewBiopsy]
--       ,[ManagementDeclinedByPatient]
--       ,[MET]
--       ,[METSecondSynchronousTumour]
--       ,[METThirdSynchronousTumour]
--       ,[METFromNewBiopsy]
--       ,[MetastaticDiseaseIndicator]
--       ,[MutationAnalysis]
--       ,[MutationAnalysisSecondSynchronousTumour]
--       ,[MutationAnalysisThirdSynchronousTumour]
--       ,[MutationAnalysisFromNewBiopsy]
--       ,[NewBiopsy]
--       ,[PackYears]
--       ,[PathStage]
--       ,[PathStageSecondSynchronousTumour]
--       ,[PathStageThirdSynchronousTumour]
--       ,[PatientAppropriateForGoldStandardsFramework]
--       ,[PatientWasReferredForSecondOpinion]
--       ,[PDL1Score]
--       ,[PDL1ScoreFromNewBiopsy]
--       ,[PerformanceStatus]
--       ,[PI3K]
--       ,[PI3KSecondSynchronousTumour]
--       ,[PI3KThirdSynchronousTumour]
--       ,[PI3KFromNewBiopsy]
--       ,[PlannedBiologicalTherapy]
--       ,[PlannedChemotherapyRegimen]
--       ,[PlannedDefinitiveTreatment]
--       ,[PreviousOtherLungCancerDiagnosis]
--       ,[PreviousRadiotherapySites]
--       ,[PreviousRadiotherapySitesSecondSynchronousTumour]
--       ,[PreviousRadiotherapySitesThirdSynchronousTumour]
--       ,[PreviousSACTRegimens]
--       ,[PreviousSurgicalProcedureSecondSynchronousTumour]
--       ,[PreviousSurgicalProcedureThirdSynchronousTumour]
--       ,[PreviousSurgicalProcedureForThisCancer]
--       ,[PreviousTreatmentSecondSynchronousTumour]
--       ,[PreviousTreatmentThirdSynchronousTumour]
--       ,[PreviousTreatmentForThisCancer]
--       ,[PrimaryDiseaseSite]
--       ,[PrimaryDiseaseSiteSecondSynchronousTumour]
--       ,[PrimaryDiseaseSiteThirdSynchronousTumour]
--       ,[PrimaryTreatmentGivenWithCurativeIntent]
--       ,[PulmonaryFunctionTests]
--       ,[RecordingSynchronousNonSmallCellLungTumours]
--       ,[ReferredBy]
--       ,[ReferringHospital]
--       ,[ResectionMargin]
--       ,[ResectionMarginSecondSynchronousTumour]
--       ,[ResectionMarginsThirdSynchronousTumour]
--       ,[ResponsibleConsultant]
--       ,[SecondSynchronousTumourDetails]
--       ,[SeenBy]
--       ,[SeenByKeyWorker]
--       ,[Side]
--       ,[SideSecondSynchronousTumour]
--       ,[SideThirdSynchronousTumour]
--       ,[SitesOfCurrentDisease]
--       ,[SitesOfPlannedRadiotherapy]
--       ,[SitesOfPlannedRadiotherapySecondSynchronousTumour]
--       ,[SitesOfPlannedRadiotherapyThirdSynchronousTumour]
--       ,[SmokingHistory]
--       ,[SourceOfTissueDiagnosis]
--       ,[SourceOfTissueDiagnosisSecondSynchronousTumour]
--       ,[SourceOfTissueDiagnosisThirdSynchronousTumour]
--       ,[ThirdSynchronousTumourDetails]
--       ,[TotalNumberOfTumoursDiagnosed]
--       ,[TreatmentForPreviousLungCancer]
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
FROM [SharedCare].[Cancer_Lung_Non-Small_Cell];

/* Drop the columns that are not needed */
ALTER TABLE #TempTable
DROP COLUMN [FK_Patient_Link_ID], [FK_Patient_ID];

SELECT * FROM #TempTable;