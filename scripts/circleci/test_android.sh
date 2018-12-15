#!/bin/bash
# Copyright (c) Facebook, Inc. and its affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#
# Script used to run Android tests on Circle CI.

set -e

COMMANDS_TO_RUN=()

# Run Android Unit Tests
COMMANDS_TO_RUN+=("buck test ReactAndroid/src/test/... --config build.threads=$BUILD_THREADS --xml ~/react-native/reports/buck/all-results-raw.xml")

# Run Android Instrumentation Tests
if [[ ! -e ReactAndroid/src/androidTest/assets/AndroidTestBundle.js ]]; then
  echo "JavaScript bundle missing, cannot run instrumentation tests. Verify build-js-bundle step completed successfully."; exit 1;
fi
COMMANDS_TO_RUN+=("source scripts/android-setup.sh && NO_BUCKD=1 retry3 timeout 300 buck install ReactAndroid/src/androidTest/buck-runner:instrumentation-tests --config build.threads=$BUILD_THREADS")

# Build RNTester App
COMMANDS_TO_RUN+=("./gradlew RNTester:android:app:assembleRelease -Pjobs=$BUILD_THREADS")

RETURN_CODES=()
FAILURE=0

printf "Node #%s (%s total). " "$CIRCLE_NODE_INDEX" "$CIRCLE_NODE_TOTAL"
if [ -n "${COMMANDS_TO_RUN[0]}" ]; then
  echo "Preparing to run commands:"
  for cmd in "${COMMANDS_TO_RUN[@]}"; do
    echo "- $cmd"
  done

  for cmd in "${COMMANDS_TO_RUN[@]}"; do
    echo
    echo "$ $cmd"
    set +e
    $cmd
    rc=$?
    set -e
    RETURN_CODES+=($rc)
    if [ $rc -ne 0 ]; then
      FAILURE=$rc
    fi
  done

  echo
  for i in "${!COMMANDS_TO_RUN[@]}"; do
    echo "Received return code ${RETURN_CODES[i]} from: ${COMMANDS_TO_RUN[i]}"
  done
  exit $FAILURE
else
  echo "No commands to run."
fi
