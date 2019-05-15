#!/bin/bash
# Copyright (c) Facebook, Inc. and its affiliates.
#
# This source code is licensed under the MIT license found in the
# LICENSE file in the root directory of this source tree.
#
# Script used to run iOS tests.
# ./objc-test-ios.sh

set -e

SCRIPTS=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
ROOT=$(dirname "$SCRIPTS")

cd "$ROOT"

# shellcheck disable=SC1091
source "scripts/objc-test.sh" && run_ios_tests
