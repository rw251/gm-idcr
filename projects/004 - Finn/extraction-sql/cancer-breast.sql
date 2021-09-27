--┌─────────────────────────────────┐
--│ Cancer breast                   │
--└─────────────────────────────────┘


-- OUTPUT: A single table with the following:
--       [PK_Breast_Cancer_ID]
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
--       ,[AreThereSynchronousBilateralTumours]
--       ,[RecordingSynchronousBilateralTumours]
--       ,[TreatmentStatusForThisCancer]
--       ,[CurrentDiseaseStatusForThisCancer]
--       ,[DateOfOriginalDiagnosis]
--       ,[PrimaryTreatmentGivenWithCurativeIntent]
--       ,[DiseaseFreeFollowingPrimaryTreatment]
--       ,[DateOfRelapse]
--       ,[NewBiopsy]
--       ,[HistologyFromNewBiopsy]
--       ,[DifferentiationFromNewBiopsy]
--       ,[CISGradeFromNewBiopsy]
--       ,[ERFromNewBiopsy]
--       ,[ERPercentFromNewBiopsy]
--       ,[OtherSiteSOfCurrentDisease]
--       ,[PRFromNewBiopsy]
--       ,[PRPercentFromNewBiopsy]
--       ,[HER2FromNewBiopsy]
--       ,[Ki67FromNewBiopsy]
--       ,[DateOfSurgery]
--       ,[OncotypeDXFromNewBiopsy]
--       ,[CurrentProgressiveDisease]
--       ,[DateOfDiseaseProgression]
--       ,[PreviousSurgeryForThisCancer]
--       ,[ScreenDetectedLesion]
--       ,[DateOfScreening]
--       ,[DateSymptomsFirstNoted]
--       ,[DateOfDiagnosis]
--       ,[NumberOfSentinelNodesTaken]
--       ,[NumberOfMicroPositiveSentinelNodes]
--       ,[BasisOfDiagnosis]
--       ,[NumberOfMacroPositiveSentinelNodes]
--       ,[SitesOfCurrentDisease]
--       ,[NumberOfAxillaryNodesTaken]
--       ,[MetastaticDiseaseIndicator]
--       ,[NumberOfMicroPositiveNodes]
--       ,[DateOfAxillaryDissection]
--       ,[PreviousTreatmentForThisCancer]
--       ,[PreviousSACTRegimens]
--       ,[NumberOfMacroPositiveNodes]
--       ,[PreviousRadiotherapySite]
--       ,[PreviousEndocrineTherapy]
--       ,[AdditionalExcisionDate]
--       ,[AdditionalExcisionSRequired]
--       ,[PreviousBreastSurgeryForThisCancer]
--       ,[DateOfBreastSurgery]
--       ,[ReconstructionPlanned]
--       ,[PreviousNodalSurgeryForThisCancer]
--       ,[TotalNumberOfAxillaryNodesTaken]
--       ,[TotalNumberOfMicroPositiveNodes]
--       ,[TotalNumberOfMacroPositiveNodes]
--       ,[PathStage]
--       ,[PreviousChemotherapyLines]
--       ,[ClinicalNodalStagingTable]
--       ,[Histology]
--       ,[PreviousChemotherapyRegimen2]
--       ,[Differentiation]
--       ,[CISGrade]
--       ,[PreviousChemotherapyRegimen3]
--       ,[FurtherPreviousChemotherapyDetails]
--       ,[ER]
--       ,[ERPercent]
--       ,[PreviousBiologicalTherapy]
--       ,[PR]
--       ,[PRPercent]
--       ,[HER2]
--       ,[Ki67]
--       ,[OncotypeDX]
--       ,[ClinicalStage]
--       ,[PerformanceStatus]
--       ,[ClinicalFrailtyScale]
--       ,[ACEComorbidities]
--       ,[TreatmentIntent]
--       ,[PatientAppropriateForGoldStandardsFramework]
--       ,[DefinitiveSurgeryPlanned]
--       ,[ImmediateProposedManagement]
--       ,[PatientEligibleForBisphosphonates]
--       ,[PatientOfferedBisphosphonates]
--       ,[ReasonPatientNotOfferedBisphosphonates]
--       ,[PatientAcceptedBisphosphonates]
--       ,[ReasonPatientDeclinedBisphosphonates]
--       ,[FurtherSurgeryPlanned]
--       ,[SitesOfPlannedRadiotherapy]
--       ,[PlannedChemotherapyRegimen]
--       ,[PlannedBiologicalTherapy]
--       ,[PlannedEndocrineTherapy]
--       ,[PlannedTreatmentPostChemotherapy]
--       ,[PlannedTreatmentPostRadiotherapy]
--       ,[SitesOfSubsequentRadiotherapy]
--       ,[SubsequentEndocrineTherapyPlanned]
--       ,[Diagnosis]
--       ,[SubsequentBiologicalTherapyPlanned]
--       ,[ManagementDeclinedByPatient]
--       ,[EntryIntoAClinicalTrial]
--       ,[TrialName]
--       ,[ReasonNotEligibleForTrial]
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
FROM [SharedCare].[Cancer_Breast];

/* Drop the columns that are not needed */
ALTER TABLE #TempTable
DROP COLUMN [FK_Patient_Link_ID], [FK_Patient_ID];

SELECT * FROM #TempTable;