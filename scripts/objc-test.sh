#!/bin/bash
# Copyright (c) Facebook, Inc. and its affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#
# Script used to set up and run iOS or tvOS tests.
# source ./objc-test.sh && run_ios_tests
# source ./objc-test.sh && run_tvos_tests

set -e

SCRIPTS=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(dirname "$SCRIPTS")

describe () {
  printf "\\n\\n>>>>> %s\\n\\n\\n" "$1"
}

# Create cleanup handler
cleanup() {
  EXIT=$?
  set +e

  if [ $EXIT -ne 0 ];
  then
    WATCHMAN_LOGS=/usr/local/Cellar/watchman/3.1/var/run/watchman/$USER.log
    [ -f "$WATCHMAN_LOGS" ] && cat "$WATCHMAN_LOGS"
  fi
  stop_services
}

boot_ios_simulator() {
  source "$SCRIPTS/.tests.env" && xcrun simctl boot "$IOS_DEVICE"
}

boot_tvos_simulator() {
  source "$SCRIPTS/.tests.env" && xcrun simctl boot "$TVOS_DEVICE"
}

start_packager() {
  yarn start --max-workers=1 || echo "Can't start packager automatically" &
}

wait_for_packager() {
  local -i max_attempts=60
  local -i attempt_num=1

  until curl -s http://localhost:8081/status | grep "packager-status:running" -q; do
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

preload_bundles() {
  describe "Preload the RNTesterApp bundle for better performance in integration tests"
  curl -s "http://localhost:8081/${RN_BUNDLE_PREFIX}RNTester/js/RNTesterApp.ios.bundle?platform=ios&dev=true" -o /dev/null
  curl -s "http://localhost:8081/${RN_BUNDLE_PREFIX}RNTester/js/RNTesterApp.ios.bundle?platform=ios&dev=true&minify=false" -o /dev/null
  curl -s "http://localhost:8081/${RN_BUNDLE_PREFIX}IntegrationTests/IntegrationTestsApp.bundle?platform=ios&dev=true" -o /dev/null
  curl -s "http://localhost:8081/${RN_BUNDLE_PREFIX}IntegrationTests/RCTRootViewIntegrationTestApp.bundle?platform=ios&dev=true" -o /dev/null
}

start_websocket_server() {
  open "./IntegrationTests/launchWebSocketServer.command" || echo "Can't start web socket server automatically"
}

stop_services() {
  # kill whatever is occupying port 8081 (packager)
  if lsof -i tcp:8081 > /dev/null 2>&1; then
   lsof -i tcp:8081 | awk 'NR!=1 {print $2}' | xargs kill
  fi

  # kill whatever is occupying port 5555 (web socket server)
  if lsof -i tcp:5555 > /dev/null 2>&1; then
    lsof -i tcp:5555 | awk 'NR!=1 {print $2}' | xargs kill
  fi
}

xcpretty_format() {
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

verify_xcodebuild_dependency() {
  if [ ! -x "$(command -v xcodebuild)" ]; then
    echo 'Error: xcodebuild is not installed. Install the Xcode Command Line Tools before running $TEST_NAME tests.'
    exit 1
  fi
}

xcodebuild_build() {
  verify_xcodebuild_dependency

  describe "Building RNTester"
  xcodebuild \
    -project "RNTester/RNTester.xcodeproj" \
    -scheme "$SCHEME" \
    -sdk "$SDK" \
    -destination "$DESTINATION" \
    -UseModernBuildSystem="$USE_MODERN_BUILD_SYSTEM" \
    build
}

xcodebuild_build_and_analyze() {
  verify_xcodebuild_dependency
  describe "Analyzing RNTester"
  xcodebuild \
    -project "RNTester/RNTester.xcodeproj" \
    -scheme "$SCHEME" \
    -sdk "$SDK" \
    -destination "$DESTINATION" \
    -UseModernBuildSystem="$USE_MODERN_BUILD_SYSTEM" \
    build analyze
}

xcodebuild_build_and_test() {
  verify_xcodebuild_dependency
  describe "Running all RNTester tests"
  xcodebuild \
    -project "RNTester/RNTester.xcodeproj" \
    -scheme "$SCHEME" \
    -sdk "$SDK" \
    -destination "$DESTINATION" \
    -UseModernBuildSystem="$USE_MODERN_BUILD_SYSTEM" \
    "${EXTRA_ARGS[@]}" \
    build test
}

xcodebuild_build_xcpretty() {
  if [ -x "$(command -v xcpretty)" ]; then
    xcodebuild_build | xcpretty_format
    if [ "${PIPESTATUS[0]}" -ne 0 ]; then
      echo "Failed to build RNTester."
      exit "${PIPESTATUS[0]}"
    fi
  else
    xcodebuild_build
  fi
}

xcodebuild_build_and_analyze_xcpretty() {
  if [ -x "$(command -v xcpretty)" ]; then
    xcodebuild_build_and_analyze | xcpretty_format && exit "${PIPESTATUS[0]}"
  else
    xcodebuild_build_and_analyze
  fi
}

xcodebuild_build_and_test_xcpretty() {
  if [ -x "$(command -v xcpretty)" ]; then
    xcodebuild_build_and_test | xcpretty_format && exit "${PIPESTATUS[0]}"
  else
    xcodebuild_build_and_test
  fi
}

configure_for_ios() {
  TEST_NAME="iOS"
  SCHEME="RNTester"
  SDK="iphonesimulator"
  USE_MODERN_BUILD_SYSTEM="NO"

  # shellcheck disable=SC1091
  source "$SCRIPTS/.tests.env"
  DESTINATION="platform=iOS Simulator,name=${IOS_DEVICE},OS=${IOS_TARGET_OS}"
}

configure_for_tvos() {
  TEST_NAME="tvOS"
  SCHEME="RNTester-tvOS"
  SDK="appletvsimulator"
  USE_MODERN_BUILD_SYSTEM="NO"

  # shellcheck disable=SC1091
  source "$SCRIPTS/.tests.env"
  DESTINATION="platform=tvOS Simulator,name=${TVOS_DEVICE},OS=${IOS_TARGET_OS}"
}

build_rntester_ios() {
  trap cleanup EXIT
  cd "$ROOT" || exit

  configure_for_ios
  xcodebuild_build_xcpretty
}

run_ios_tests() {
  trap cleanup EXIT
  cd "$ROOT" || exit

  configure_for_ios
  xcodebuild_build_xcpretty
  start_packager
  start_websocket_server
  wait_for_packager
  preload_bundles
  xcodebuild_build_and_test_xcpretty
}

run_rntester_unit_tests() {
  EXTRA_ARGS=()
  EXTRA_ARGS+=('-only-testing:RNTesterUnitTests')
  export EXTRA_ARGS

  run_ios_tests
}

run_rntester_integration_tests() {
  EXTRA_ARGS=()
  EXTRA_ARGS+=('-only-testing:RNTesterIntegrationTests')
  export EXTRA_ARGS

  run_ios_tests
}


run_tvos_tests() {
  trap cleanup EXIT
  cd "$ROOT" || exit

  configure_for_tvos
  xcodebuild_build_xcpretty
  start_packager
  start_websocket_server
  wait_for_packager
  preload_bundles
  xcodebuild_build_and_test_xcpretty
}
