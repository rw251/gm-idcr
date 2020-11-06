
-- CREATE TEMP TABLE FOR CTV3 CODES

DROP TABLE #CTV3_CODES
SELECT PK_Reference_Coding_ID AS CODE
INTO #CTV3_CODES
  FROM [SharedCare].[Reference_Coding]
  WHERE MainCode IN ('x000q', 'x000r')

-- CREATE TEMP TABLE FOR EMIS CODES

DROP TABLE #EMIS_CODES
SELECT 
     [FK_Reference_Coding_ID] AS CODE
  INTO #EMIS_CODES
  FROM [SharedCare].[Reference_Local_Code] L
  WHERE LocalCode IN ( 
    'EMTA3515',
	'MATA3882',
	'MATA3883',
	'META3900',
	'META5136',
	'MEIN18088EMIS',
	'MEIN18089EMIS',
	'MEIN18090EMIS',
	'MEIN21800NEMIS',
	'MEIN21802NEMIS',
	'MEIN22304NEMIS',
	'MEIN3551NEMIS',
	'MEIN36535NEMIS',
	'MEIN51051NEMIS',
	'MEIN90725NEMIS',
	'MEIN90728NEMIS',
	'MEOR12018NEMIS',
	'MEOR14798NEMIS',
	'MEOR15494NEMIS'
	)

-- CREATE TEMP TABLE FOR READV2 CODES

DROP TABLE #READV2_CODES
SELECT  [PK_Reference_Coding_ID] AS CODE
  INTO #READV2_CODES
  FROM [SharedCare].[Reference_Coding]
  WHERE MainCode in (
    'h34..',
	'h341.',
	'h342.',
	'h34d.',
	'h34p.',
	'h34q.',
	'h343.',
	'h345.',
	'h346.',
	'h347.',
	'h348.',
	'h349.',
	'h34A.',
	'h34E.',
	'h34F.',
	'h34G.',
	'h34H.',
	'h34L.',
	'h34N.',
	'h34O.',
	'h34R.',
	'h34T.',
	'h34U.',
	'h34V.',
	'h34W.',
	'h34X.',
	'h34Y.',
	'h34a.',
	'h34e.',
	'h34f.',
	'h34g.',
	'h34h.',
	'h34i.',
	'h34j.',
	'h34k.',
	'h34l.',
	'h34n.',
	'h34o.',
	'h34r.',
	'h34t.',
	'h34u.',
	'h34v.',
	'h34w.',
	'h34x.',
	'h34y.',
	'h3G..',
	'h3G1.',
	'h3G2.',
	'h3G3.',
	'h3G4.',
	'h3G5.',
	'h3G6.',
	'h3G7.',
	'h3G9.',
	'h3GB.',
	'h3GC.',
	'h3GD.',
	'h3GE.',
	'h3GF.',
	'h3GG.',
	'h3GH.',
	'h3GJ.',
	'h3GK.',
	'h3GL.',
	'h3GM.',
	'h3GN.',
	'h3GP.',
	'h3GR.',
	'h3GT.',
	'h3GV.',
	'h3GW.',
	'h3GX.',
	'h3GY.',
	'h3GZ.',
	'h24B.',
	'h344.',
	'h34b.',
	'h34B.',
	'h34D.',
	'h34P.',
	'h34Z.',
	'h34c.',
	'h34m.',
	'h34s.',
	'h34C.',
	'h34M.',
	'h34Q.',
	'h34S.',
	'h34z.',
	'h3G8.',
	'h3GA.',
	'h3GI.',
	'h3GO.',
	'h3GQ.',
	'h3GS.',
	'h3GU.'
	)

DROP TABLE #SNOMED_CODES
SELECT [PK_Reference_SnomedCT_ID]
  INTO #SNOMED_CODES
  FROM [SharedCare].[Reference_SnomedCT] 
  WHERE ConceptID IN 
  ( 
  '19954111000001103',
'19954411000001108',
'19956011000001109',
'19955711000001103',
'19972411000001103',
'19953911000001102',
'34871011000001105',
'322011000001106',
'644711000001108',
'34776911000001102',
'34777311000001100',
'34777111000001102',
'34777611000001105',
'34777811000001109',
'34778011000001102',
'34778211000001107',
'34778411000001106',
'34778611000001109',
'34776411000001105',
'68887009',
'769892005',
'769898009',
'769899001',
'769895007',
'769893000',
'769894006',
'769897004',
'769896008',
'326875008',
'928011000001103',
'136411000001105',
'24381411000001107',
'24135711000001100',
'14963911000001107',
'191111000001100',
'20310811000001101',
'15109411000001107',
'22222111000001103',
'21796511000001106',
'11026611000001103',
'24594311000001100',
'15517911000001104',
'34167711000001101',
'9468211000001108',
'9455911000001104',
'10675611000001107',
'8664911000001105',
'8618111000001102',
'8665011000001105',
'8618811000001109',
'24594411000001107',
'19231311000001104',
'34167811000001109',
'9468311000001100',
'9455211000001108',
'8665111000001106',
'8619311000001106',
'8665211000001100',
'8619611000001101',
'12813911000001109',
'12794011000001105',
'12814011000001107',
'12793711000001105',
'374444008',
'24594511000001106',
'15518011000001102',
'34167911000001104',
'9468411000001107',
'9454211000001107',
'10675711000001103',
'8665311000001108',
'8619911000001107',
'8665411000001101',
'8620311000001107',
'24594611000001105',
'19231411000001106',
'34168011000001102',
'9468511000001106',
'9453611000001106',
'12814111000001108',
'12794611000001103',
'12814211000001102',
'12794311000001108',
'12814311000001105',
'12796111000001104',
'12814411000001103',
'12795811000001103',
'36032911000001108',
'3618611000001106',
'3619511000001101',
'3619211000001104',
'9561911000001100',
'36033011000001100',
'3624511000001106',
'27951711000001108',
'3625011000001104',
'3624711000001101',
'11091011000001108',
'12814511000001104',
'12796711000001103',
'12814611000001100',
'12796411000001109',
'326874007',
'201811000001107',
'683611000001105',
'706911000001103',
'34956611000001101',
'24381611000001105',
'167911000001107',
'24136011000001106',
'14962511000001107',
'383711000001107',
'20310611000001100',
'14709211000001105',
'29918911000001101',
'22222311000001101',
'14946711000001105',
'21796211000001108',
'11026411000001101',
'8665611000001103',
'8622711000001105',
'8665711000001107',
'8624211000001107',
'36033111000001104',
'3621611000001108',
'3621811000001107',
'3622011000001109',
'24594711000001101',
'15518111000001101',
'34168111000001101',
'9468611000001105',
'9453111000001103',
'19976011000001106',
'10675811000001106',
'12814711000001109',
'12798611000001108',
'12814811000001101',
'12798211000001106',
'24594811000001109',
'19231511000001105',
'34168211000001107',
'9468711000001101',
'9452811000001102',
'12814911000001106',
'12800111000001102',
'12815011000001106',
'12799711000001108',
'24594911000001104',
'15518211000001107',
'19976111000001107',
'34168311000001104',
'9468811000001109',
'9452311000001106',
'10675911000001101',
'14967911000001103',
'14966611000001107',
'12816911000001103',
'12800911000001104',
'12817011000001104',
'12800611000001105',
'766413008',
'24595011000001104',
'19231611000001109',
'9468911000001104',
'9451611000001107',
'30799911000001104',
'31065011000001106',
'30985211000001103',
'30595111000001100',
'12817111000001103',
'12801511000001104',
'12817211000001109',
'12801211000001102',
'24595111000001103',
'18245711000001104',
'9469011000001108',
'9450111000001105',
'19976211000001101',
'9469111000001109',
'9449511000001107',
'9469211000001103',
'9448511000001101',
'12817311000001101',
'12802211000001109',
'12817411000001108',
'12801911000001106',
'374442007',
'36033211000001105',
'3622611000001102',
'27952411000001107',
'3623611000001107',
'3623211000001105',
'14966811000001106',
'3622911000001108',
'10988211000001107',
'9469311000001106',
'9448011000001109',
'36033311000001102',
'3610011000001101',
'28991611000001102',
'3615611000001100',
'3613311000001109',
'15138411000001109',
'3612811000001108',
'10988011000001102',
'12817511000001107',
'12803011000001108',
'12815111000001107',
'12802611000001106',
'36033411000001109',
'3620611000001103',
'3621111000001100',
'3620811000001104',
'36033511000001108',
'3615811000001101',
'3616911000001104',
'3616411000001107',
'9562111000001108',
'9469411000001104',
'9457411000001101',
'36033611000001107',
'3612511000001105',
'3614911000001107',
'3614611000001101',
'8665811000001104',
'8625911000001104',
'8665911000001109',
'8626511000001104',
'12815211000001101',
'12803611000001101',
'12815311000001109',
'12803311000001106',
'374443002',
'24595211000001109',
'15518311000001104',
'34168411000001106',
'9469511000001100',
'9456611000001100',
'10676011000001109',
'8666011000001101',
'8625811000001109',
'8666111000001100',
'8626411000001103',
'12815411000001102',
'12804611000001103',
'12815511000001103',
'12804011000001105',
'12815611000001104',
'12805711000001106',
'12815711000001108',
'12805111000001105',
'12815811000001100',
'12806611000001107',
'12815911000001105',
'12806311000001102',
'714206006',
'714204009',
'15513411000001100',
'10672911000001109',
'19224611000001108',
'15513711000001106',
'10673211000001106',
'19225111000001101',
'15514311000001109',
'10673511000001109',
'19225411000001106',
'15514011000001106',
'10674011000001104',
'19225811000001108',
'18208411000001106',
'15513111000001105',
'10672611000001103',
'24590211000001100',
'24589911000001102',
'24589611000001108',
'24591111000001100',
'24590811000001104',
'24590411000001101',
'24589311000001103',
'24589011000001101',
'24588711000001108',
'24588411000001102',
'34162611000001107',
'34162911000001101',
'34163211000001104',
'34163511000001101',
'34163811000001103',
'34164111000001107',
'34164411000001102',
'34161711000001105',
'31407911000001106',
'31409011000001103',
'31409611000001105',
'31410211000001104',
'31406711000001106',
'31407211000001102',
'31407411000001103',
'31408511000001100'
)

-- 4 TABLES NOW CREATED: CTV3_CODES (2), EMIS_CODES (33), READV2_CODES (287), SNOMED_CODES

-- COMBINE CODES INTO ONE TABLE (ONLY EMIS, CTV3 AND READV2)

/**************** NOTE: None of the SNOMED codes in #SNOMED_CODES appear in GP_Events or Reference_Coding */

DROP TABLE #COMBINED
SELECT CODE
INTO #COMBINED
FROM #READV2_CODES
UNION ALL
SELECT CODE FROM #EMIS_CODES
UNION ALL
SELECT CODE FROM #CTV3_CODES

--- REMOVE DUPLICATES 

DROP TABLE #COMBINED_DEDUPED
SELECT DISTINCT CODE 
INTO #COMBINED_DEDUPED
FROM #COMBINED --290

-- MONTHLY COUNTS OF METHOTREXATE FOR EACH TRUST (EXCLUDING SNOMED CODES)

SELECT 
	TenancyName
	,YEAR(EventDate) AS [YEAR]
	,MONTH(EventDate) AS [MONTH]
	,COUNT(*) AS [COUNT]
FROM RLS.vw_GP_Events GP
LEFT JOIN SharedCare.Reference_Tenancy SC ON (GP.FK_Reference_Tenancy_ID = SC.PK_Reference_Tenancy_ID)
WHERE FK_Reference_Coding_ID IN 
	(SELECT CODE FROM #COMBINED_DEDUPED)
	AND EventDate BETWEEN '01 JAN 2020' AND '31 OCT 2020'
GROUP BY
	TenancyName
	,YEAR(EventDate)
	,MONTH(EventDate)
ORDER BY 
	TenancyName
	,YEAR(EventDate)
	,MONTH(EventDate)

