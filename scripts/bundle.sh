#!/usr/bin/env bash
set -euo pipefail

APP_NAME="quickSwitch"
BUILD_DIR=".build/release"
APP_BUNDLE="build/${APP_NAME}.app"

swift build -c release

rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

cp "${BUILD_DIR}/${APP_NAME}" "${APP_BUNDLE}/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "${APP_BUNDLE}/Contents/Info.plist"

# Ad-hoc sign so SMAppService (open-at-login) works locally.
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "Built ${APP_BUNDLE}"
