--┌─────────────────────────────────┐
--│ Cancer anal                     │
--└─────────────────────────────────┘


-- OUTPUT: A single table with the following:
    -- [PK_Anal_Cancer_ID]
    --   ,[ExternalID]
    --   ,[CreateDate]
    --   ,[ModifDate]
    --   ,[LoadID]
    --   ,[Deleted]
    --   ,[HDMModifDate]
    --   ,[FK_Reference_Tenancy_ID]
    --   ,[FK_Patient_Link_ID]
    --   ,[FK_Patient_ID]
    --   ,[NhsNo]
    --   ,[FormInstance]
    --   ,[FormDataID]
    --   ,[FormID]
    --   ,[ExamKey]
    --   ,[CRISOrderNo]
    --   ,[StatusID]
    --   ,[Date]
    --   ,[FormLoadedTS]
    --   ,[EventKey]
    --   ,[DeleteFlag]
    --   ,[TStemp]
    --   ,[ConsultantID]
    --   ,[BatchUpdate]
    --   ,[DateCreated]
    --   ,[CreatedBy]
    --   ,[DateModified]
    --   ,[ModifiedBy]
    --   ,[AceComorbidities]
    --   ,[ActionFollowingReferralForSecondOpinion]
    --   ,[AnalDefunctioning]
    --   ,[AreThereSynchronousBilateralTumours?]
    --   ,[AxillaryNodesTakenExcludingSnb]
    --   ,[BasisOfDiagnosis]
    --   ,[ClinicalNodalStagingTable]
    --   ,[ClinicalStage]
    --   ,[ConsultantConferred]
    --   ,[CurrentDiseaseStatusForThisCancer]
    --   ,[CurrentProgressiveDisease]
    --   ,[DateOfAxillarySurgery]
    --   ,[DateOfBiopsy]
    --   ,[DateOfDiagnosis]
    --   ,[DateOfDiseaseProgression]
    --   ,[DateOfOriginalDiagnosis]
    --   ,[DateOfRelapse]
    --   ,[DateOfScreening]
    --   ,[DateOfSurgery]
    --   ,[DateSeen]
    --   ,[DateSymptomsFirstNoted]
    --   ,[DefinitiveSurgeryPlanned]
    --   ,[Diagnosis]
    --   ,[Differentiation]
    --   ,[DifferentiationFromNewBiopsy]
    --   ,[Disease-freeFollowingPrimaryTreatment]
    --   ,[EntryIntoAClinicalTrial]
    --   ,[Er]
    --   ,[ExtracapsularExtension]
    --   ,[Histology]
    --   ,[HistologyFromNewBiopsy]
    --   ,[HivStatus]
    --   ,[ImmediateProposedManagement]
    --   ,[IsSubsequentEndocrineTherapyPlanned?]
    --   ,[IsSubsequentRadiotherapyPlanned?]
    --   ,[IsThisTheDateOfDiagnosis?]
    --   ,[KeyWorkerName]
    --   ,[Ki-67]
    --   ,[Lvsi]
    --   ,[LvsiFromNewBiopsy]
    --   ,[ManagementDeclinedByPatient]
    --   ,[MetastaticDiseaseIndicator]
    --   ,[MucosalMelanomaStagingNote]
    --   ,[NewBiopsy]
    --   ,[NodalStatus]
    --   ,[NumberOfAxillaryNodesTaken]
    --   ,[NumberOfMacroPositiveNodes]
    --   ,[NumberOfMacroPositiveNodesExcludingSnb]
    --   ,[NumberOfMicroPositiveNodes]
    --   ,[NumberOfMicroPositiveNodesExcludingSnb]
    --   ,[NumberOfPositiveNodesLeft]
    --   ,[NumberOfPositiveNodesRight]
    --   ,[NumberOfSnbMacroPositiveNodes]
    --   ,[NumberOfSnbMicroPositiveNodes]
    --   ,[NumberOfSnbNodesTaken]
    --   ,[OtherPrimDis]
    --   ,[OtherSitesOfCurrentDisease]
    --   ,[PathStage]
    --   ,[PatientAppropriateForGoldStandardsFramework]
    --   ,[PatientWasReferredForSecondOpinion]
    --   ,[PerformanceStatus]
    --   ,[PlannedBiologicalTherapy]
    --   ,[PlannedChemotherapyRegimen]
    --   ,[PlannedEndocrineTherapy]
    --   ,[Pr]
    --   ,[PreviousBiologicalTherapy]
    --   ,[PreviousChemotherapyLines]
    --   ,[PreviousChemotherapyRegimen2]
    --   ,[PreviousChemotherapyRegimen3]
    --   ,[PreviousChemotherapyRegimens]
    --   ,[PreviousEndocrineTherapy]
    --   ,[PreviousNodalSurgeryForThisCancer]
    --   ,[PreviousRadiotherapySite]
    --   ,[PreviousRadiotherapySites]
    --   ,[PreviousSurgeryForThisCancer]
    --   ,[PreviousSurgicalProcedureForThisCancer]
    --   ,[PreviousTreatmentForThisCancer]
    --   ,[PrimaryDiseaseSite]
    --   ,[PrimaryTreatmentGivenWithCurativeIntent]
    --   ,[ReconstructionPlanned?]
    --   ,[ReferredBy]
    --   ,[ReferringHospital]
    --   ,[ResectionMarginDistance]
    --   ,[ResponsibleConsultant]
    --   ,[ScreenDetectedLesion?]
    --   ,[SeenBy]
    --   ,[SeenByKeyWorker]
    --   ,[SitesOfCurrentDisease]
    --   ,[SitesOfPlannedRadiotherapy]
    --   ,[TreatmentIntent]
    --   ,[TreatmentStatusForThisCancer]
    --   ,[TrialName]
    --   ,[CreatedBySurname]
    --   ,[CreatedByForename]
    --   ,[CreatedByUserDepartment]
    --   ,[CreatedByUserEmployer]
    --   ,[ModifiedBySurname]
    --   ,[ModifiedByForename]
    --   ,[ModifiedByUserDepartment]
    --   ,[ModifiedByUserEmployer]

--Just want the output, not the messages
SET NOCOUNT ON;

SELECT *
FROM [SharedCare].[Cancer_Anal];