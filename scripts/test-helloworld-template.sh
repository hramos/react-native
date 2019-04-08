#!/bin/bash
# Copyright (c) Facebook, Inc. and its affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.

set -ex

THIS_DIR=$(cd -P "$(dirname "$(readlink "${BASH_SOURCE[0]}" || echo "${BASH_SOURCE[0]}")")" && pwd)

REACT_NATIVE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REACT_NATIVE_TEMP_DIR=$(mktemp -d /tmp/react-native-XXXXXXXX)
TEST_TEMPLATE_DIR="$REACT_NATIVE_TEMP_DIR/template"

if [[ -z "${NODE_BINARY}" ]]; then
  NODE_BINARY=$(command -v node)
fi
if [[ -z "${NPM_BINARY}" ]]; then
  NPM_BINARY=$(command -v npm)
fi

describe () {
  printf "\\n\\n>>>>> %s\\n\\n\\n" "$1"
}

cleanup () {
  set +e
  rm -rf "$REACT_NATIVE_TEMP_DIR"
  rm -rf "$REACT_NATIVE_DIR/react-native-1000.0.0.tgz"
  set -e
}

create_new_app_from_template () {
  pushd "$REACT_NATIVE_DIR" >/dev/null

  describe "Creating React Native package"
  "$NPM_BINARY" pack 2>&1
  REACT_NATIVE_PACKAGE="$(pwd)/react-native-1000.0.0.tgz"
  popd >/dev/null

  describe "Scaffolding a basic React Native app"
  cp -R \
    "$REACT_NATIVE_DIR/template" \
    "$TEST_TEMPLATE_DIR"

  pushd "$TEST_TEMPLATE_DIR" >/dev/null

  # rename _watchmanconfig to .watchmanconfig and so on
  for src in $(find -H "$TEST_TEMPLATE_DIR" -maxdepth 1 -name '_*' -not -name '__tests__')
  do
    dst="$TEST_TEMPLATE_DIR/$(basename "${src/_/.}")"
    mv "$src" "$dst"
  done

  # BSD sed and GNU sed have different inline replacement syntax
  # for backup-less inline replacement. Using -i.bak ensures sed
  # can be used with the same results on BSD and GNU (i.e. macOS/Circle)
  sed -i.bak 's/HelloWorld/test-template/g' package.json

  describe "Installing React Native package"
  $NPM_BINARY install $REACT_NATIVE_PACKAGE

  describe "Installing Flow"
  $NPM_BINARY install --save-dev flow-bin

  describe "Installing node_modules"
  "$NPM_BINARY" install 2>&1

  popd >/dev/null
}

test_template () {
  pushd "$TEST_TEMPLATE_DIR" >/dev/null

  # Check the packager produces a bundle successfully on both platforms
  describe "Test: Verify packager can generate an iOS bundle"
  "$NODE_BINARY" ./node_modules/react-native/cli.js bundle \
    --max-workers 1 \
    --platform ios \
    --dev true \
    --entry-file index.js \
    --bundle-output rn-ios.js

  describe "Test: Verify packager can generate an Android bundle"
  "$NODE_BINARY" ./node_modules/react-native/cli.js bundle \
    --max-workers 1 \
    --platform android \
    --dev true \
    --entry-file index.js \
    --bundle-output rn-android.js

  describe "Test: Flow check"
  ./node_modules/.bin/flow check

  popd >/dev/null
}

main () {
  create_new_app_from_template
  test_template
}

trap cleanup EXIT
main "$@"
