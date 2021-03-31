const { Connection, Request } = require('tedious');
const Stream = require('stream');
const fs = require('fs');
const msRestNodeAuth = require('@azure/ms-rest-nodeauth');
const chalk = require('chalk');
const inquirer = require('inquirer');
const { join } = require('path');
require('clear')();
const { version } = require('./package.json');

const EXTRACTION_DIR = join(__dirname, '..', 'extraction-sql');
const OUTPUT_DIR = join(__dirname, '..', 'output-for-analysts');
const PSEUDO_ID_DIR = join(__dirname, '..', 'pseudo-id-data');
const PSEUDO_ID_FILE = join(PSEUDO_ID_DIR, 'pseudo-ids.txt');
const store = { pseudoLookup: {} };

// Catch any attempt to kill the process e.g. CTRL-C / CMD-C and exit gracefully
process.kill = () => {
  process.stdout.write('\n\n');
  log('Exiting... Goodbye!');
  process.exit();
};

confirmClearOutputDirectory()
  .then(getQueriesToRun)
  .then(getQueryContent)
  .then(confirmPseudoIdRequired)
  .then(finalConfirmation)
  .then(getPatientPseudoIds)
  .then(executeSql)
  .then(() => {
    if (store.updateLookup) {
      log('The lookup was changed due to unknown patient ids. Writing new lookup file...');
      fs.writeFileSync(
        PSEUDO_ID_FILE,
        Object.keys(store.pseudoLookup)
          .map((x) => `${x},${store.pseudoLookup[x]}`)
          .join('\n')
      );
    }
    console.log(
      chalk.yellowBright(`
All data files have now been written. You can now copy the contents of the directory:

${OUTPUT_DIR}

to the study shared folder. This will have the form ${chalk.cyanBright(
        'gmcr-rqxxx-name'
      )} and be located under ${chalk.cyanBright('This PC')} in ${chalk.cyanBright(
        'File Explorer'
      )}.
		`)
    );
  })
  .catch((err) => {
    log('An error occurred.');
    log(err.message);
    log(err);
  });

function executeSql() {
  return authenticate().then(() => Promise.all(store.files.map(executeSqlFile)));
}

function executeSqlFile(sqlFile) {
  return doQuery(sqlFile);
}

/**
 * Authenticate with Azure via multi-factor authentication
 * @returns {Promise}
 */
function authenticate() {
  if (store.accessToken) return Promise.resolve();
  console.log(`
First you need to be authenticated.`);
  return msRestNodeAuth
    .interactiveLoginWithAuthResponse({ tokenAudience: 'https://database.windows.net/' })
    .then(({ credentials }) => credentials.getToken())
    .then(saveTokens);
}

function getQueryContent(files) {
  store.files = files.map((file) => ({
    filename: file,
    sql: fs.readFileSync(join(EXTRACTION_DIR, file), 'utf8'),
  }));
}

function finalConfirmation() {
  console.log(
    chalk.bold(`
You are about to execute the following files:

${chalk.greenBright(store.files.map((x) => x.filename).join('\n'))}

and your data ${
      store.shouldPseudo
        ? `contains patient ids that will be pseudonymised${
            store.shouldOverwrite ? '' : ' using the existing pseudonymisation'
          }.`
        : 'does not contain patient ids.'
    }
`)
  );
  return inquirer
    .prompt([
      {
        type: 'confirm',
        name: 'confirm',
        message: `Is that right?`,
        default: false,
      },
    ])
    .then(({ confirm }) => {
      if (confirm) {
        return true;
      }
      console.log('Ok. Goodbye.');
      process.exit(0);
    });
}

function confirmPseudoIdRequired() {
  console.log(
    chalk.bold(
      `
All patient ids (Patient_Link_Ids) extracted will be pseudonymised. This takes time, so we won't do it unless your data actually contains patients ids.`
    )
  );
  return inquirer
    .prompt([
      {
        type: 'confirm',
        name: 'shouldPseudo',
        message: `Does your data require the patient ids to be pseudonymised?`,
        default: true,
      },
    ])
    .then(({ shouldPseudo }) => {
      store.shouldPseudo = shouldPseudo;
      if (!shouldPseudo) {
        return;
      }
      // So they want to pseudonymise
      if (!fs.existsSync(PSEUDO_ID_DIR) || !fs.existsSync(PSEUDO_ID_FILE)) {
        // Nothing exists so just do it
        if (!fs.existsSync(PSEUDO_ID_DIR)) fs.mkdirSync(PSEUDO_ID_DIR);
        store.shouldOverwrite = true;
        return;
      }
      console.log(
        chalk.bold(`
There is already a mapping between pseudo ids and patient ids for this project.`)
      );
      return inquirer
        .prompt([
          {
            type: 'confirm',
            name: 'shouldReuse',
            message: `Do you want to reuse this?`,
            default: false,
          },
        ])
        .then(({ shouldReuse }) => {
          store.shouldOverwrite = !shouldReuse;
          return;
        });
    });
}

function confirmClearOutputDirectory() {
  if (!fs.existsSync(OUTPUT_DIR)) {
    createDirectoryStructure();
    return Promise.resolve();
  }
  console.log(
    chalk.bold(`This will first empty the output directory:

${chalk.green(OUTPUT_DIR)}
`)
  );
  return inquirer
    .prompt([
      {
        type: 'confirm',
        name: 'isClearOK',
        message: `Is that ok?`,
        default: false,
      },
    ])
    .then(({ isClearOK }) => {
      if (isClearOK) {
        createDirectoryStructure();
        return true;
      }
      console.log('Ok. Goodbye.');
      process.exit(0);
    });
}

/**
 * Select which SQL queries to execute
 * @returns {Promise}
 */
function getQueriesToRun() {
  const files = fs.readdirSync(EXTRACTION_DIR).filter((x) => x.match(/.+\.sql$/));
  return runAllOrSome().then((shouldRunAll) => {
    if (shouldRunAll) return files;
    return inquirer
      .prompt([
        {
          type: 'checkbox',
          name: 'sql',
          message: 'Which files do you want to execute?',
          choices: files,
          validate: (input) => input.length > 0,
        },
      ])
      .then(({ sql }) => sql);
  });
}

/**
 * CLI prompt to get whether to run all or just some SQL files
 * @returns {Promise}
 */
function runAllOrSome() {
  const choices = {
    RUN_ALL: 'Execute all SQL files',
    RUN_SOME: 'Execute some SQL files (can choose which ones next)',
  };
  return inquirer
    .prompt([
      {
        type: 'list',
        name: 'choice',
        message: 'What do you want to do?',
        choices: Object.values(choices),
      },
    ])
    .then(({ choice }) => {
      if (choice === choices.RUN_ALL) return true;
      return false;
    });
}

// Not used at present but this is how to obtain a new accessToken from the refreshToken
// const msal = require('@azure/msal-node');
// function refresh() {
//   const pca = new msal.ClientApplication();
// 	return pca
//     .acquireTokenByRefreshToken({ refreshToken: store.refreshToken })
// 		.then(saveTokens);
// }

/**
 * Persist the access/refresh tokens for future requests
 * @param {Object} token
 */
function saveTokens({ refreshToken, accessToken, expiresOn }) {
  if (refreshToken) store.refreshToken = refreshToken;
  store.accessToken = accessToken;
  store.expiresOn = expiresOn;
}

/**
 * Take an SQL file, execute against the database, and write
 * to an output file
 * @param {Object} config filename, sql
 * @returns {Promise}
 */
function doQuery({ filename, sql }) {
  log(`Executing ${filename}...`);
  return new Promise((resolve) => {
    const outputStream = fs.createWriteStream(join(OUTPUT_DIR, 'data', 'raw', `${filename}.txt`));
    const readable = new Stream.Readable({
      read(size) {
        return !!size;
      },
    });
    readable.pipe(outputStream);

    outputStream.on('finish', () => {
      log(`${filename} - Output written. All Done!`);
      return resolve();
    });

    const connection = new Connection({
      server: 'GM-ccbi-live-01.database.windows.net',
      authentication: {
        type: 'azure-active-directory-access-token',
        options: { token: store.accessToken },
      },
      options: { encrypt: true, database: 'HDM_Research' },
    });

    connection.on('connect', (err) => {
      if (err) {
        logError(`Connection Failed for ${filename}`);
        throw err;
      }

      executeStatement();
    });

    connection.connect();

    let patientIdColumns = [];
    function executeStatement() {
      const request = new Request(sql, (err) => {
        if (err) {
          throw err;
        }
        connection.close();
        log(filename + ' request done');
        readable.push(null);
      });

      request.setTimeout(0);

      // Pipe the rows to the output stream
      request.on('row', (columns) => {
        const row = [];
        let nullPatientIdWarning = false;
        columns.forEach((column, i) => {
          if (column.value === null) {
            row.push('NULL');
            if (patientIdColumns.indexOf(i) > -1) {
              nullPatientIdWarning = true;
            }
          } else if (column.value.toISOString) {
            row.push(column.value.toISOString().substr(0, 10));
          } else if (patientIdColumns.indexOf(i) > -1) {
            if (
              typeof column.value === 'number' &&
              (column.value > Number.MAX_SAFE_INTEGER || column.value < Number.MIN_SAFE_INTEGER)
            ) {
              logError(`${filename} has a patient id outside the max safe range for JS.`);
            }
            if (!store.pseudoLookup[column.value]) {
              logWarning(
                `${filename} has a patient id (${column.value}) that isn't in the Patient_Link table.`
              );
              logWarning('Adding a new id for this patient to the lookup.');
              store.highestId += 1;
              store.pseudoLookup[column.value] = store.highestId;
              store.updateLookup = true;
              row.push(store.highestId);
            } else {
              row.push(store.pseudoLookup[column.value]);
            }
          } else {
            row.push(column.value);
          }
        });
        readable.push(row.join(',') + '\n');
        if (nullPatientIdWarning) {
          logWarning(`${filename} has a row where a patient id is null. Is that expected?
          ${row.join(',')}`);
        }
      });

      // Add the header row from the column metadata
      request.on('columnMetadata', (columns) => {
        readable.push(
          columns
            .map((column, i) => {
              if (!column.colName) {
                logWarning(
                  `${filename} doesn't have a name for the ${nth(
                    i + 1
                  )} column. Please make sure the final SELECT statement has an "AS COLUMN_NAME" for this column.`
                );
                return '';
              } else if (column.colName.match(/.*PatientId$/g)) {
                patientIdColumns.push(i);
              }
              return column.colName;
            })
            .join(',') + '\n'
        );
        if (patientIdColumns.length === 0) {
          logWarning(
            `${filename} doesn't have any patient id columns. If you have a patient id column 
but where the name doesn't end with 'PatientId' then the ids will not be pseudonymised.`
          );
        }
      });

      request.on('doneInProc', (rowCount) => {
        if (rowCount || rowCount === 0) {
          log(chalk.bold(`${filename} has completed. ${rowCount} rows were returned.`));
        }
      });

      connection.execSql(request);
    }
  });
}

function getPatientPseudoIds() {
  if (!store.shouldPseudo) return Promise.resolve();
  return authenticate().then(
    () =>
      new Promise((resolve) => {
        log(`Querying the database for ${store.shouldOverwrite ? '' : 'any new '}patient ids...`);
        const patientIds = [];

        const connection = new Connection({
          server: 'GM-ccbi-live-01.database.windows.net',
          authentication: {
            type: 'azure-active-directory-access-token',
            options: { token: store.accessToken },
          },
          options: { encrypt: true, database: 'HDM_Research' },
        });

        connection.on('connect', (err) => {
          if (err) {
            logError(`Connection failed while attempting to generate the pseudo patient ids.`);
            throw err;
          }

          executeStatement();
        });

        connection.connect();

        function executeStatement() {
          const request = new Request(
            'SELECT PK_Patient_Link_ID FROM RLS.vw_Patient_Link;',
            (err) => {
              if (err) {
                throw err;
              }
              connection.close();

              if (!store.shouldOverwrite) {
                log('Loading the existing mapping file...');
                let maxPseudoId = 0;
                fs.readFileSync(PSEUDO_ID_FILE, 'utf8')
                  .split('\n')
                  .forEach((x) => {
                    if (x.trim().length < 2) return;
                    const [fkid, pseudoId] = x.split(',');
                    store.pseudoLookup[fkid.trim()] = +pseudoId.trim();
                    maxPseudoId = Math.max(maxPseudoId, +pseudoId.trim());
                  });
                log(
                  `There are ${
                    Object.keys(store.pseudoLookup).length
                  } patient ids in the mapping file.`
                );
                const newPatientIds = patientIds.filter(
                  (patientId) => !store.pseudoLookup[patientId]
                );
                log(`There are ${newPatientIds.length} new patient ids from the database.`);
                if (newPatientIds.length > 0) {
                  const newPatientIdRows = randomIdGenerator(maxPseudoId, newPatientIds);
                  fs.writeFileSync(PSEUDO_ID_FILE, newPatientIdRows.join('\n'), { flag: 'a' });
                  log(`New patient ids added to the pseudo id lookup file.`);
                }
              } else {
                log(chalk.bold(`${patientIds.length} patient ids retrived.`));
                const patientIdRows = randomIdGenerator(0, patientIds);
                fs.writeFileSync(PSEUDO_ID_FILE, patientIdRows.join('\n'));
                log(`Patient ids written to the pseudo id lookup file.`);
              }
              return resolve();
            }
          );

          request.setTimeout(0);

          // Pipe the rows to the output stream
          request.on('row', (columns) => {
            patientIds.push(columns[0].value);
          });

          connection.execSql(request);
        }
      })
  );
}

function randomIdGenerator(start = 0, ids) {
  log('Randomly assigning ids...');
  shuffleArray(ids);
  return ids.map((id, i) => {
    store.highestId = start + i + 1;
    store.pseudoLookup[id] = store.highestId;
    return `${id},${store.highestId}`;
  });
}

function shuffleArray(array) {
  for (let i = array.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [array[i], array[j]] = [array[j], array[i]];
  }
}

function createDirectoryStructure() {
  console.log(
    chalk.bold(`
Creating the output directory structure...`)
  );
  if (fs.existsSync(OUTPUT_DIR)) {
    fs.rmdirSync(OUTPUT_DIR, { recursive: true });
  }
  if (fs.existsSync(OUTPUT_DIR)) {
    console.log(
      chalk.bold(`
Failed. This usually means you have a file open from within the output directory:

${chalk.green(OUTPUT_DIR)}

Please close any files and try again.`)
    );
    process.exit(0);
  }
  fs.mkdirSync(OUTPUT_DIR);
  fs.mkdirSync(join(OUTPUT_DIR, 'code'));
  fs.mkdirSync(join(OUTPUT_DIR, 'data'));
  fs.mkdirSync(join(OUTPUT_DIR, 'data', 'raw'));
  fs.mkdirSync(join(OUTPUT_DIR, 'data', 'processed'));
  fs.mkdirSync(join(OUTPUT_DIR, 'doc'));
  fs.mkdirSync(join(OUTPUT_DIR, 'output'));
  fs.mkdirSync(join(OUTPUT_DIR, 'output', 'approved'));
  fs.mkdirSync(join(OUTPUT_DIR, 'output', 'check'));
  fs.mkdirSync(join(OUTPUT_DIR, 'output', 'export'));
  writeReadme();
  console.log(
    chalk.bold(`Done.
`)
  );
}

function writeReadme() {
  fs.writeFileSync(
    join(OUTPUT_DIR, '_README_FIRST.txt'),
    `* Data from the RDEs will be in the data/raw folder. Do not edit the contents of this folder.

* Data that you have processed through your scripts goes in the data/processed folder.

* Code goes in the 'code' folder.

* ***For any summary data or figures that you wish to export you MUST conform to the following:

  1. Files for export should first be placed in the output/check folder.
  2. They should then be checked by another analyst for disclosure control risk. 
  3. Once approved by another analyst they should then be placed in the output/approved folder. 
  4. When files are exported from the VDE they should be placed in a subdirectory of output/export with a datestamp prior to copying off the machine.

E.g. the folder structure will look as follows:

output
  |- export
      |- 2021-05-12
      |   |- file1.png
      |   |- file2.png
      |   |- file3.txt
      |- 2021-06-30
      |   |- fileA.png
      |   |- fileB.csv

Files should not be deleted from the 'output/export' folder***

* Anything else (e.g. documentation that is not code) goes in the 'doc' folder.

v${version}`
  );
}

/**
 * Converts 1, 2, 3... into 1st, 2nd, 3rd etc..
 * @param {Number} n The number to nth
 * @returns {String}
 */
function nth(n) {
  if (n % 100 === 11 || n % 100 === 12 || n % 100 === 13) return `${n}th`;
  if (n % 10 === 1) return `${n}st`;
  if (n % 10 === 2) return `${n}nd`;
  if (n % 10 === 3) return `${n}rd`;
  return `${n}th`;
}

function log(message) {
  console.log(`${chalk.blueBright(timestamp())}: ${message}`);
}

function logError(message) {
  console.log(`${chalk.blueBright(timestamp())}: ${chalk.white.bgRed.bold(message)}`);
}

function logWarning(message) {
  console.log(`${chalk.blueBright(timestamp())}: ${chalk.yellow(message)}`);
}

/**
 * Timestamp in format YYYY-MM-DDThh:mm:ss.nnn"
 * @returns {String} Timestamp
 */
function timestamp() {
  return new Date().toISOString().substr(0, 23);
}