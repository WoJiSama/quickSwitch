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
echo
echo "提示:这个 .app 只有本地(ad-hoc)签名。直接在本机 open 没问题;"
echo "但通过下载/AirDrop/微信分发给别人时,首次打开会被 Gatekeeper 拦截:"
echo "  系统设置 → 隐私与安全性 → 「仍要打开」,或:"
echo "  xattr -dr com.apple.quarantine ${APP_NAME}.app"
