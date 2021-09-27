--┌─────────────────────────────────┐
--│ Cancer prostate                 │
--└─────────────────────────────────┘


-- OUTPUT: A single table with the following:
-- [PK_Prostate_Cancer_ID]
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
--       ,[BasisOfDiagnosis]
--       ,[ClinicalFrailtyScale]
--       ,[ClinicalStage]
--       ,[ConsultantConferred]
--       ,[CoresCombinedFraction]
--       ,[CoresL%]
--       ,[CoresR%]
--       ,[CurrentDiseaseStatusForThisCancer]
--       ,[CurrentEndocrineTreatment]
--       ,[CurrentProgressiveDisease]
--       ,[DateOfDiagnosis]
--       ,[DateOfDiseaseProgression]
--       ,[DateOfOriginalDiagnosis]
--       ,[DateOfRelapse]
--       ,[DateOfSmokingCessation]
--       ,[DateSeen]
--       ,[DateSymptomsFirstNoted]
--       ,[Diagnosis]
--       ,[Differentiation]
--       ,[DiseaseFreeFollowingPrimaryTreatment]
--       ,[EndocrineTherapyForProstateVolumeReduction]
--       ,[EntryIntoAClinicalTrial]
--       ,[HighOrLowVolume]
--       ,[Histology]
--       ,[HistologyFromNewBiopsy]
--       ,[ImmediateProposedManagement]
--       ,[IPSSScore]
--       ,[IsThisAFunctioningTumour]
--       ,[KeyWorkerName]
--       ,[ManagementDeclinedByPatient]
--       ,[MetastaticDiseaseIndicator]
--       ,[MostRecentPSA]
--       ,[MultipleTumours]
--       ,[NewBiopsy]
--       ,[NumberOfProceduresForThisCancer]
--       ,[OverallGleasonScore]
--       ,[PathStage]
--       ,[PatientAppropriateForGoldStandardsFramework]
--       ,[PatientWasReferredForSecondOpinion]
--       ,[PerformanceStatus]
--       ,[PlannedAdjuvantEndocrineTherapy]
--       ,[PlannedChemotherapyRegimen]
--       ,[PlannedDurationOfAdjuvantEndocrineTherapy]
--       ,[PlannedEndocrineTherapy]
--       ,[PlannedRadionuclideTherapy]
--       ,[PlannedRadiotherapySites]
--       ,[PNETType]
--       ,[PositiveSurgicalMargin]
--       ,[PreviousActiveSurveillanceForThisCancer]
--       ,[PreviousChemotherapyLines]
--       ,[PreviousChemotherapyRegimen1]
--       ,[PreviousChemotherapyRegimen2]
--       ,[PreviousChemotherapyRegimen3]
--       ,[PreviousEndocrineRegimeIncludeOnlyIfDiscontinued]
--       ,[PreviousHDRDate]
--       ,[PreviousHipReplacement]
--       ,[PreviousLDRDate]
--       ,[PreviousRa223Date]
--       ,[PreviousRadiotherapyTreatmentDate]
--       ,[PreviousSurgicalProcedureForThisCancer]
--       ,[PreviousSurgicalProcedureForThisCancer2]
--       ,[PreviousSurgicalProcedureForThisCancer3]
--       ,[PreviousTreatmentForThisCancer]
--       ,[PrimaryDiseaseSite]
--       ,[PrimaryTreatmentGivenWithCurativeIntent]
--       ,[PSAAtDiagnosis]
--       ,[PSANadir]
--       ,[PSAScreeningDetected]
--       ,[ReferredBy]
--       ,[ReferringHospital]
--       ,[ResponsibleConsultant]
--       ,[SecretoryHormone]
--       ,[SeenBy]
--       ,[SeenByKeyWorker]
--       ,[SitesOfCurrentDisease]
--       ,[SmokingHistory]
--       ,[TreatmentIntent]
--       ,[TreatmentStatusForThisCancer]
--       ,[TrialName]
--       ,[TumourSizeCm]
--       ,[TURP]
--       ,[TURPInvolvement%]
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
FROM [SharedCare].[Cancer_Prostate];

/* Drop the columns that are not needed */
ALTER TABLE #TempTable
DROP COLUMN [FK_Patient_Link_ID], [FK_Patient_ID];

SELECT * FROM #TempTable;