#!/bin/bash
# Copyright (c) Facebook, Inc. and its affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#
# Script used to run iOS and tvOS tests on Circle CI.

set -e

# shellcheck source=/dev/null
. "scripts/.tests.env"

COMMANDS_TO_RUN=()

# Install Watchman
COMMANDS_TO_RUN+=('brew install watchman')
COMMANDS_TO_RUN+=('touch .watchmanconfig')

# Print out build environment information
COMMANDS_TO_RUN+=('xcodebuild -version')
COMMANDS_TO_RUN+=('instruments -s devices')

if [ $((0 % CIRCLE_NODE_TOTAL)) -eq "$CIRCLE_NODE_INDEX" ]; then
  # iOS Tests

  # Boot iOS Simulator
  COMMANDS_TO_RUN+=("xcrun simctl boot ${IOS_DEVICE} || true")

  # Run iOS Test Suite
  COMMANDS_TO_RUN+=('./scripts/objc-test-ios.sh test')

  # iOS End-to-End Test Suite (Disabled)
  # COMMANDS_TO_RUN+=('node ./scripts/run-ci-e2e-tests.js --ios --retries 3')
  # Test CocoaPods (Disabled)
  # COMMANDS_TO_RUN+=('./scripts/process-podspecs.sh')
fi

if [ $((1 % CIRCLE_NODE_TOTAL)) -eq "$CIRCLE_NODE_INDEX" ]; then
  # tvOS Tests

  # Boot Apple TV Simulator
  COMMANDS_TO_RUN+=("xcrun simctl boot ${TVOS_DEVICE} || true")

  # Run tvOS Test Suite
  COMMANDS_TO_RUN+=('./scripts/objc-test-tvos.sh test')

  # tvOS End-to-End Test Suite (Disabled)
  # COMMANDS_TO_RUN+=('node ./scripts/run-ci-e2e-tests.js --tvos --retries 3')
fi

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
