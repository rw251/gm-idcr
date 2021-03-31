const { readFileSync, readdirSync, writeFileSync } = require('fs');
const { join } = require('path');

const LTC_DIRECTORY = join(__dirname, '..', 'shared', 'Long-term conditions');
const OUTPUT_FILE = join(
  __dirname,
  '..',
  'shared',
  'Reusable queries for data extraction',
  'query-patient-ltcs.sql'
);
const OUTPUT_GROUP_FILE = join(
  __dirname,
  '..',
  'shared',
  'Reusable queries for data extraction',
  'query-patient-ltcs-group.sql'
);

// A list of the LTC groups
const LTCGroups = getListOfLTCGroups();

// Get the code sets
const { LTCCodesetsArray, LTCConditions } = getCodesets();

const sql = createSQL();
writeFileSync(OUTPUT_FILE, sql);

const groupSql = createGroupSQL();
writeFileSync(OUTPUT_GROUP_FILE, groupSql);

//
// FUNCTIONS
//

function getListOfLTCGroups() {
  validateLTCDirectory();
  return readdirSync(LTC_DIRECTORY, { withFileTypes: true }) // read all children of the LTC directory
    .filter((item) => item.isDirectory()) // ..then filter to just directories under LTC_DIRECTORY
    .map((dir) => dir.name.replace(/'/g, '')); // ..then return the directory name
}

function validateLTCDirectory() {
  if (
    readdirSync(LTC_DIRECTORY, { withFileTypes: true }).filter((item) => item.isFile()).length > 0
  ) {
    console.error(
      'ERROR>>> There are files in the LTC directory. I was only expecting to see directories.'
    );
  }
}

function getCodesets() {
  // Objects to store the code sets
  const codesetObject = {};
  const LTCCodesetsArray = [];

  LTCGroups.forEach((ltcGroup) => {
    codesetObject[ltcGroup] = {};

    // Get all condition code lists for this group
    const CONDITION_DIRECTORY = join(LTC_DIRECTORY, ltcGroup);

    // A list of the condition code sets in this LTC group
    const conditionCodeSets = readdirSync(CONDITION_DIRECTORY, { withFileTypes: true })
      .filter((item) => item.isFile()) // find all files under LTC_DIRECTORY
      .map((file) => file.name) // return the file name
      .filter((filename) => filename.toLowerCase().match(/^.+ - (readv2|ctv3|snomed|emis).txt$/));

    // Add the codesets
    conditionCodeSets.forEach((conditionCodeSet) => {
      const [condition, terminology] = conditionCodeSet
        .toLowerCase()
        .replace(/'/g, '')
        .replace('.txt', '')
        .split(' - ');
      if (!codesetObject[ltcGroup][condition]) {
        codesetObject[ltcGroup][condition] = {};
      }
      codesetObject[ltcGroup][condition][terminology] = loadCodeset(
        ltcGroup,
        conditionCodeSet,
        terminology
      );
      LTCCodesetsArray.push({
        ltcGroup,
        condition,
        terminology,
        codes: codesetObject[ltcGroup][condition][terminology],
      });
    });
  });

  const LTCConditions = makeArrayUnique(LTCCodesetsArray.map((x) => x.condition));

  return { codesetObject, LTCCodesetsArray, LTCConditions };
}

function createGroupSQL() {
  const sql = `--
--┌────────────────────────────────────────┐
--│ Long-term condition groups per patient │
--└────────────────────────────────────────┘

-- OBJECTIVE: To provide the long-term condition group or groups for each patient. Examples
--            of long term condition groups would be: Cardiovascular, Endocrine, Respiratory

-- INPUT: Assumes there exists a temp table as follows:
-- #PatientsWithLTCs (FK_Patient_Link_ID, LTC)
-- Therefore this is run after query-patient-ltcs.sql

-- OUTPUT: A temp table with a row for each patient and ltc group combo
-- #LTCGroups (FK_Patient_Link_ID, LTCGroup)

--!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
--!!! DO NOT EDIT THIS FILE MANUALLY - see "node create-ltc-sql.js" !!!
--!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

-- Calculate the LTC groups for each patient
IF OBJECT_ID('tempdb..#LTCGroups') IS NOT NULL DROP TABLE #LTCGroups;
SELECT 
  DISTINCT FK_Patient_Link_ID, 
  CASE
    ${LTCGroups.map(
      (group) => `WHEN LTC IN ('${getConditionsFromGroup(group).join("','")}') THEN '${group}'`
    ).join('\n\t\t')}
  END AS LTCGroup INTO #LTCGroups
FROM #PatientsWithLTCs;
`;
  return sql;
}

function getConditionsFromGroup(group) {
  return makeArrayUnique(
    LTCCodesetsArray.filter((x) => x.ltcGroup === group).map((x) => x.condition)
  );
}

function createSQL() {
  const sql = `--
--┌──────────────────────┐
--│ Long-term conditions │
--└──────────────────────┘

-- OBJECTIVE: To get every long-term condition for each patient.

-- INPUT: Assumes there exists a temp table as follows:
-- #Patients (FK_Patient_Link_ID)
-- A distinct list of FK_Patient_Link_IDs for each patient in the cohort

-- OUTPUT: A temp table with a row for each patient and ltc combo
-- #PatientsWithLTCs (FK_Patient_Link_ID, LTC)

-- Get the LTCs that each patient had prior to @StartDate

--!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
--!!! DO NOT EDIT THIS FILE MANUALLY - see "node create-ltc-sql.js" !!!
--!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

${
  hasTerminology('emis')
    ? `IF OBJECT_ID('tempdb..#codesemis') IS NOT NULL DROP TABLE #codesemis;
CREATE TABLE #codesemis (
  [condition] [varchar](255) NOT NULL,
  [group] [varchar](255) NOT NULL,
  [code] [varchar](20) COLLATE Latin1_General_CS_AS NOT NULL,
  [description] [varchar](255) NULL
)ON [PRIMARY];

${getInsertStatementForTerminology('emis')};`
    : ''
}

${
  hasTerminology('readv2')
    ? `IF OBJECT_ID('tempdb..#codesreadv2') IS NOT NULL DROP TABLE #codesreadv2;
CREATE TABLE #codesreadv2 (
  [condition] [varchar](255) NOT NULL,
  [group] [varchar](255) NOT NULL,
	[code] [varchar](20) COLLATE Latin1_General_CS_AS NOT NULL,
	[description] [varchar](255) NULL
) ON [PRIMARY];

${getInsertStatementForTerminology('readv2')};`
    : ''
}

${
  hasTerminology('ctv3')
    ? `IF OBJECT_ID('tempdb..#codesctv3') IS NOT NULL DROP TABLE #codesctv3;
CREATE TABLE #codesctv3 (
  [condition] [varchar](255) NOT NULL,
  [group] [varchar](255) NOT NULL,
	[code] [varchar](20) COLLATE Latin1_General_CS_AS NOT NULL,
	[description] [varchar](255) NULL
) ON [PRIMARY];

${getInsertStatementForTerminology('ctv3')};`
    : ''
}

${
  hasTerminology('snomed')
    ? `IF OBJECT_ID('tempdb..#codessnomed') IS NOT NULL DROP TABLE #codessnomed;
CREATE TABLE #codessnomed (
  [condition] [varchar](255) NOT NULL,
  [group] [varchar](255) NOT NULL,
	[code] [varchar](20) COLLATE Latin1_General_CS_AS NOT NULL,
	[description] [varchar](255) NULL
) ON [PRIMARY];

${getInsertStatementForTerminology('snomed')};`
    : ''
}

IF OBJECT_ID('tempdb..#TempRefCodes') IS NOT NULL DROP TABLE #TempRefCodes;
CREATE TABLE #TempRefCodes (FK_Reference_Coding_ID BIGINT NOT NULL, condition VARCHAR(255) NOT NULL, [group] VARCHAR(255) NOT NULL);

${
  hasTerminology('emis')
    ? `-- EMIS codes with a FK Reference Coding ID
INSERT INTO #TempRefCodes
SELECT FK_Reference_Coding_ID, dce.condition, dce.[group]
FROM [SharedCare].[Reference_Local_Code] rlc
INNER JOIN #codesemis dce on dce.code = rlc.LocalCode
WHERE FK_Reference_Coding_ID != -1;`
    : ''
}

${
  hasTerminology('readv2')
    ? `-- Read v2 codes
INSERT INTO #TempRefCodes
SELECT PK_Reference_Coding_ID, dcr.condition, dcr.[group]
FROM [SharedCare].[Reference_Coding] rc
INNER JOIN #codesreadv2 dcr on dcr.code = rc.MainCode
WHERE CodingType='ReadCodeV2'
and PK_Reference_Coding_ID != -1;`
    : ''
}

${
  hasTerminology('ctv3')
    ? `-- CTV3 codes
INSERT INTO #TempRefCodes
SELECT PK_Reference_Coding_ID, dcc.condition, dcc.[group]
FROM [SharedCare].[Reference_Coding] rc
INNER JOIN #codesctv3 dcc on dcc.code = rc.MainCode
WHERE CodingType='CTV3'
and PK_Reference_Coding_ID != -1;`
    : ''
}

IF OBJECT_ID('tempdb..#TempSNOMEDRefCodes') IS NOT NULL DROP TABLE #TempSNOMEDRefCodes;
CREATE TABLE #TempSNOMEDRefCodes (FK_Reference_SnomedCT_ID BIGINT NOT NULL, condition VARCHAR(255) NOT NULL, [group] VARCHAR(255) NOT NULL);

${
  hasTerminology('emis')
    ? `-- EMIS codes with a FK SNOMED ID but without a FK Reference Coding ID
INSERT INTO #TempSNOMEDRefCodes
SELECT FK_Reference_SnomedCT_ID, dce.condition, dce.[group]
FROM [SharedCare].[Reference_Local_Code] rlc
INNER JOIN #codesemis dce on dce.code = rlc.LocalCode
WHERE FK_Reference_Coding_ID = -1
AND FK_Reference_SnomedCT_ID != -1;`
    : ''
}

${
  hasTerminology('snomed')
    ? `-- SNOMED codes
INSERT INTO #TempSNOMEDRefCodes
SELECT PK_Reference_SnomedCT_ID, dcs.condition, dcs.[group]
FROM SharedCare.Reference_SnomedCT rs
INNER JOIN #codessnomed dcs on dcs.code = rs.ConceptID;`
    : ''
}

-- De-duped tables
IF OBJECT_ID('tempdb..#RefCodes') IS NOT NULL DROP TABLE #RefCodes;
IF OBJECT_ID('tempdb..#SNOMEDRefCodes') IS NOT NULL DROP TABLE #SNOMEDRefCodes;
CREATE TABLE #RefCodes (FK_Reference_Coding_ID BIGINT NOT NULL, condition VARCHAR(255) NOT NULL, [group] VARCHAR(255) NOT NULL);
CREATE TABLE #SNOMEDRefCodes (FK_Reference_SnomedCT_ID BIGINT NOT NULL, condition VARCHAR(255) NOT NULL, [group] VARCHAR(255) NOT NULL);

INSERT INTO #RefCodes
SELECT DISTINCT * FROM #TempRefCodes;

INSERT INTO #SNOMEDRefCodes
SELECT DISTINCT * FROM #TempSNOMEDRefCodes;

IF OBJECT_ID('tempdb..#LTCTemp') IS NOT NULL DROP TABLE #LTCTemp;
SELECT DISTINCT FK_Patient_Link_ID, FK_Reference_SnomedCT_ID, FK_Reference_Coding_ID INTO #LTCTemp 
FROM RLS.vw_GP_Events e
WHERE (
	FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #SNOMEDRefCodes) OR
  FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #RefCodes)
)
AND FK_Patient_Link_ID IN (SELECT FK_Patient_Link_ID FROM #Patients)
AND EventDate < @StartDate;

IF OBJECT_ID('tempdb..#PatientsWithLTCs') IS NOT NULL DROP TABLE #PatientsWithLTCs;
SELECT DISTINCT 
  FK_Patient_Link_ID, 
  CASE
  ${LTCConditions.map(
    (condition) => `  WHEN (
      FK_Reference_SnomedCT_ID IN (SELECT FK_Reference_SnomedCT_ID FROM #SNOMEDRefCodes WHERE condition = '${condition}') OR
      FK_Reference_Coding_ID IN (SELECT FK_Reference_Coding_ID FROM #RefCodes WHERE condition = '${condition}')
    ) THEN '${condition}'`
  ).join('\n\t')}
  END AS LTC
INTO #PatientsWithLTCs
FROM #LTCTemp;
`;
  return sql;
}

function hasTerminology(terminology) {
  return LTCCodesetsArray.filter((item) => item.terminology === terminology).length > 0;
}

function getInsertStatementForTerminology(terminology) {
  return LTCCodesetsArray.filter((item) => item.terminology === terminology)
    .map((item) =>
      item.codes.map((code) => `('${item.condition}','${item.ltcGroup}','${code}','')`)
    )
    .flat()
    .filter((row) => row.length > 2)
    .reduce(
      (soFar, nextValue) => {
        if (soFar.itemCount === 999) {
          // SQL only allows 1000 items to be inserted after each INSERT INTO statememt
          // so need to start again
          soFar.sql = `${soFar.sql.slice(0, -1)};\nINSERT INTO #codes${terminology}\nVALUES `;
          soFar.lineLength = 7;
          soFar.itemCount = 0;
        }
        if (soFar.lineLength > 9900) {
          // the sql management studio doesn't style lines much longer than this
          soFar.sql += `\n${nextValue},`;
          soFar.lineLength = nextValue.length + 1;
        } else {
          soFar.sql += `${nextValue},`;
          soFar.lineLength += nextValue.length + 1;
        }
        soFar.itemCount += 1;
        return soFar;
      },
      { sql: `INSERT INTO #codes${terminology}\nVALUES `, itemCount: 0, lineLength: 7 }
    )
    .sql.slice(0, -1);
}

function loadCodeset(ltcGroup, conditionCodeSet, terminology) {
  if (terminology === 'readv2') return loadCodesetReadv2(ltcGroup, conditionCodeSet);
  if (terminology === 'ctv3') return loadCodesetCTV3(ltcGroup, conditionCodeSet);
  if (terminology === 'snomed') return loadCodesetSnomed(ltcGroup, conditionCodeSet);
  // if (terminology === 'emis') return loadCodesetEmis(ltcGroup, conditionCodeSet);
}

function loadCodesetReadv2(ltcGroup, conditionCodeSet) {
  const filepath = join(LTC_DIRECTORY, ltcGroup, conditionCodeSet);
  const [fileHeader, ...fileBody] = readFileSync(filepath, 'utf8')
    .split('\n')
    .map((row) => row.split('\t'))
    .filter((items) => items.length > 1);
  if (!fileHeader) {
    console.log(`The file ${conditionCodeSet} in ${ltcGroup} does not have a header row.`);
    return [];
  }
  const readcodeIndex = fileHeader.map((x) => x.toLowerCase()).indexOf('readcode');

  if (readcodeIndex < 0) {
    console.log(
      `The file ${conditionCodeSet} in ${ltcGroup} does not have a column with the header 'readcode'.`
    );
    return [];
  }

  const codingSystemIndex = fileHeader.indexOf('CodingSystem');
  const codingSystemFilter =
    codingSystemIndex > -1
      ? (items) => items[codingSystemIndex].toLowerCase() === 'readcode'
      : () => true;
  const readcodes = fileBody.filter(codingSystemFilter).map((items) => items[readcodeIndex]);

  if (readcodes.length === 0) {
    console.log(`The file ${conditionCodeSet} in ${ltcGroup} does not have any read codes.`);
    return [];
  }

  // Add 5 byte codes if we have any 7 character ones
  // e.g. if the code is "G30..00" then we would also
  // add the code "G30.."
  const readcodeSet = {};
  readcodes.forEach((readcode) => {
    if (!readcode) {
      console.log(filepath);
      console.log(fileHeader);
      console.log(readcodes);
    }
    readcodeSet[readcode] = true;
    if (readcode.length === 7) {
      readcodeSet[readcode.substr(0, 5)] = true;
    }
  });
  return Object.keys(readcodeSet);
}

function loadCodesetCTV3(ltcGroup, conditionCodeSet) {
  const filepath = join(LTC_DIRECTORY, ltcGroup, conditionCodeSet);
  const [fileHeader, ...fileBody] = readFileSync(filepath, 'utf8')
    .split('\n')
    .map((row) => row.split('\t'))
    .filter((items) => items.length > 1);
  let ctv3Index = fileHeader.map((x) => x.toLowerCase()).indexOf('ctv3code');
  if (ctv3Index < 0) ctv3Index = fileHeader.map((x) => x.toLowerCase()).indexOf('ctv3id');
  if (ctv3Index < 0) {
    console.log(
      `The file ${conditionCodeSet} in ${ltcGroup} does not have a column with the header 'ctv3code' or 'ctv3id'.`
    );
    return [];
  }
  const ctv3Codes = fileBody.map((items) => items[ctv3Index]);

  if (ctv3Codes.length === 0) {
    console.log(`The file ${conditionCodeSet} in ${ltcGroup} does not have any ctv3 codes.`);
    return [];
  }

  return ctv3Codes;
}

function loadCodesetSnomed(ltcGroup, conditionCodeSet) {
  const filepath = join(LTC_DIRECTORY, ltcGroup, conditionCodeSet);
  const [fileHeader, ...fileBody] = readFileSync(filepath, 'utf8')
    .split('\n')
    .map((row) => row.split('\t'))
    .filter((items) => items.length > 1);
  const snomedIndex = fileHeader.indexOf('snomed');
  const snomedCodes = fileBody.map((items) => items[snomedIndex]);
  return snomedCodes;
}

function makeArrayUnique(array) {
  return [...new Set(array)];
}
