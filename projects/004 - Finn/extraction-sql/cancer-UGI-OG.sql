--┌─────────────────────────────────┐
--│ Cancer UGI OG                   │
--└─────────────────────────────────┘


-- OUTPUT: A single table with the following:
--       [PK_UGI_OG_ID]
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
--       ,[AddedToEndOfLifeCarePathway]
--       ,[BasisOfDiagnosis]
--       ,[BodyMassIndex]
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
--       ,[DefinitiveSurgeryPlanned]
--       ,[DiagnosingHospital]
--       ,[Diagnosis]
--       ,[DietRecommendationsIDDSI]
--       ,[Differentiation]
--       ,[DifferentiationFromNewBiopsy]
--       ,[DiseaseFreeFollowingPrimaryTreatment]
--       ,[EntryIntoAClinicalTrial]
--       ,[EstimationOfPrognosis]
--       ,[FamilialSyndrome]
--       ,[FamilialSyndromeType]
--       ,[FluidRecommendationsIDDSI]
--       ,[HER2]
--       ,[Histology]
--       ,[HistologyFromNewBiopsy]
--       ,[ImmediateProposedManagement]
--       ,[IsThisAFunctioningTumour]
--       ,[KeyWorkerName]
--       ,[ManagementDeclinedByPatient]
--       ,[MetastaticDiseaseIndicator]
--       ,[MIB1ScoreKi67]
--       ,[MultipleTumours]
--       ,[NewBiopsy]
--       ,[NutritionalSupportIntervention]
--       ,[OrourkeScore]
--       ,[OtherSiteSOfCurrentDisease]
--       ,[PathStage]
--       ,[PatientAppropriateForGoldStandardsFramework]
--       ,[PatientAwarenessOfPrognosis]
--       ,[PatientWasReferredForSecondOpinion]
--       ,[PerformanceStatus]
--       ,[PlannedEmbolisationType]
--       ,[PlannedRadionuclideTherapy]
--       ,[PlannedSACTRegimen]
--       ,[PlannedSomatostatinAnalogue]
--       ,[PlannedTyrosineKinaseInhibitor]
--       ,[PNETType]
--       ,[PreviousEmbolisationType]
--       ,[PreviousRadionuclideTherapy]
--       ,[PreviousRadiotherapySite]
--       ,[PreviousSACTLines]
--       ,[PreviousSACTRegimen2]
--       ,[PreviousSACTRegimen3]
--       ,[PreviousSACTRegimens]
--       ,[PreviousSurgeryForThisCancer]
--       ,[PreviousSurgicalProcedureForThisCancer]
--       ,[PreviousTreatmentForThisCancer]
--       ,[PreviousTyrosineKinaseInhibitor]
--       ,[PrimaryDiseaseSite]
--       ,[PrimaryTreatmentGivenWithCurativeIntent]
--       ,[ReferredBy]
--       ,[ReferringHospital]
--       ,[ResectionMargin]
--       ,[ResponsibleConsultant]
--       ,[SecretoryHormone]
--       ,[SeenBy]
--       ,[SeenByKeyWorker]
--       ,[SitesOfCurrentDisease]
--       ,[SitesOfPlannedRadiotherapy]
--       ,[SmokingHistory]
--       ,[TreatmentIntent]
--       ,[TreatmentStatusForThisCancer]
--       ,[TrialName]
--       ,[TumourSizeCm]
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

SELECT *
FROM [SharedCare].[Cancer_UGI_OG];