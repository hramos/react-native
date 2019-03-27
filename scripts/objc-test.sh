#!/bin/bash
# Copyright (c) Facebook, Inc. and its affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#
# Script used to run iOS and tvOS tests.
# Environment variables are used to configure what test to run.
# If not arguments are passed to the script, it will only compile
# the RNTester.
# If the script is called with a single argument "test", we'll
# also run the RNTester integration test (needs JS and packager).
# ./objc-test.sh test

set -e

SCRIPTS=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(dirname "$SCRIPTS")
BUILD_ARGS=()
if [ "$TREAT_WARNINGS_AS_ERRORS" == "YES" ]; then
  BUILD_ARGS+=("GCC_TREAT_WARNINGS_AS_ERRORS=YES")
fi

if [ "$COLLECT_CODE_COVERAGE" == "YES" ]; then
  BUILD_ARGS+=("-enableCodeCoverage" "YES" "GCC_GENERATE_TEST_COVERAGE_FILES=YES")
fi

cd "$ROOT"

# Create cleanup handler
function cleanup {
  EXIT=$?
  set +e

  if [ $EXIT -ne 0 ];
  then
    WATCHMAN_LOGS=/usr/local/Cellar/watchman/3.1/var/run/watchman/$USER.log
    [ -f "$WATCHMAN_LOGS" ] && cat "$WATCHMAN_LOGS"
  fi
  # kill whatever is occupying port 8081 (packager)
  lsof -i tcp:8081 | awk 'NR!=1 {print $2}' | xargs kill
  # kill whatever is occupying port 5555 (web socket server)
  lsof -i tcp:5555 | awk 'NR!=1 {print $2}' | xargs kill
}
trap cleanup EXIT

# Wait for the package to start
function waitForPackager {
  local -i max_attempts=60
  local -i attempt_num=1

  until $(curl -s http://localhost:8081/status | grep "packager-status:running" -q); do
    if (( attempt_num == max_attempts )); then
      echo "Packager did not respond in time. No more attempts left."
      exit 1
    else
      (( attempt_num++ ))
      echo "Packager did not respond. Retrying for attempt number $attempt_num..."
      sleep 1
    fi
  done

  echo "Packager is ready!"
}

function runTests {
  xcodebuild \
    -project "RNTester/RNTester.xcodeproj" \
    -scheme "$SCHEME" \
    -sdk "$SDK" \
    -destination "$DESTINATION" \
    -UseModernBuildSystem="$USE_MODERN_BUILD_SYSTEM" \
    "${BUILD_ARGS[@]}" \
    build test
}

function buildProject {
  xcodebuild \
    -project "RNTester/RNTester.xcodeproj" \
    -scheme "$SCHEME" \
    -sdk "$SDK" \
    -UseModernBuildSystem="$USE_MODERN_BUILD_SYSTEM" \
    "${BUILD_ARGS[@]}" \
    build
}

function prettyFormat {
  if ! [ -x "$(command -v xcpretty)" ]; then
    echo 'Warning: xcpretty is not installed. Install xcpretty to generate JUnit reports.'
  fi

  if [ "$CI" ]; then
    # Circle CI expects JUnit reports to be available here
    REPORTS_DIR="$HOME/react-native/reports"
  else
    THIS_DIR=$(cd -P "$(dirname "$(readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}")")" && pwd)

    # Write reports to the react-native root dir
    REPORTS_DIR="$THIS_DIR/../build/reports"
  fi

  xcpretty --report junit --output "$REPORTS_DIR/junit/$TEST_NAME/results.xml"
}

# If first argument is "test", actually start the packager and run tests.
# Otherwise, just build RNTester and exit

if [ "$1" = "test" ]; then

  # Start the packager
  yarn start --max-workers=1 || echo "Can't start packager automatically" &
  # Start the WebSocket test server
  open "./IntegrationTests/launchWebSocketServer.command" || echo "Can't start web socket server automatically"

  waitForPackager

  # Preload the RNTesterApp bundle for better performance in integration tests
  curl 'http://localhost:8081/RNTester/js/RNTesterApp.ios.bundle?platform=ios&dev=true' -o temp.bundle
  rm temp.bundle
  curl 'http://localhost:8081/RNTester/js/RNTesterApp.ios.bundle?platform=ios&dev=true&minify=false' -o temp.bundle
  rm temp.bundle
  curl 'http://localhost:8081/IntegrationTests/IntegrationTestsApp.bundle?platform=ios&dev=true' -o temp.bundle
  rm temp.bundle
  curl 'http://localhost:8081/IntegrationTests/RCTRootViewIntegrationTestApp.bundle?platform=ios&dev=true' -o temp.bundle
  rm temp.bundle

  # Build and run tests.
  runTests | prettyFormat && exit "${PIPESTATUS[0]}"
else
  # Build without running tests.
  buildProject | prettyFormat && exit "${PIPESTATUS[0]}"
fi
