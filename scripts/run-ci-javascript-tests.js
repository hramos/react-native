/**
 * Copyright (c) Facebook, Inc. and its affiliates.
 *
 * This source code is licensed under the MIT license found in the
 * LICENSE file in the root directory of this source tree.
 *
 * @format
 */

'use strict';

/**
 * This script runs JavaScript tests.
 * Available arguments:
 * --maxWorkers [num] - how many workers, default 1
 * --jestBinary [path] - path to jest binary, defaults to local node modules
 * --yarnBinary [path] - path to yarn binary, defaults to yarn
 */
/*eslint-disable no-undef */
require('shelljs/global');

const argv = require('yargs').argv;
const path = require('path');

const SCRIPTS = __dirname;
const ROOT = path.normalize(path.join(__dirname, '..'));

const numberOfRetries = argv.retries || 1;
const numberOfMaxWorkers = argv.maxWorkers || 1;
let exitCode;

const JEST_BINARY = argv.jestBinary || './node_modules/.bin/jest';
const YARN_BINARY = argv.yarnBinary || 'yarn';

try {
  echo('Executing JavaScript tests');

  echo('\n\n>>>>> Test: eslint\n\n\n');
  if (exec(`${YARN_BINARY} run lint`).code) {
    echo('Failed to run eslint.');
    exitCode = 1;
    throw Error(exitCode);
  }

  echo('\n\n>>>>> Test: Flow check (iOS)\n\n\n');
  if (exec(`${YARN_BINARY} run flow-check-ios`).code) {
    echo('Failed to run flow.');
    exitCode = 1;
    throw Error(exitCode);
  }
  echo('\n\n>>>>> Test: Flow check (Android)\n\n\n');
  if (exec(`${YARN_BINARY} run flow-check-android`).code) {
    echo('Failed to run flow.');
    exitCode = 1;
    throw Error(exitCode);
  }

  echo('\n\n>>>>> Test: Jest\n\n\n');
  if (
    exec(
      `${JEST_BINARY} --maxWorkers=${numberOfMaxWorkers} --ci --reporters="default" --reporters="jest-junit"`,
    ).code
  ) {
    echo('Failed to run JavaScript tests.');
    echo('Most likely the code is broken.');
    exitCode = 1;
    throw Error(exitCode);
  }

  exitCode = 0;
} finally {
  cd(ROOT);
  // clean up?
}
exit(exitCode);

/*eslint-enable no-undef */
