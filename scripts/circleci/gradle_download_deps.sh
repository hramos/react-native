#!/bin/bash

set -e

./gradlew --debug :ReactAndroid:downloadBoost :ReactAndroid:downloadDoubleConversion :ReactAndroid:downloadFolly :ReactAndroid:downloadGlog :ReactAndroid:downloadJSCHeaders
