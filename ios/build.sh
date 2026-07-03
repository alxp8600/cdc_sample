#!/bin/bash
# =============================================================================
#  CDC Sample iOS - one-shot build (Debug default)
#
#  Usage:
#    ./build.sh [Debug|Release] [device|simulator]
#      config : Debug (default) | Release
#      dest   : device (default, iphoneos) | simulator (iphonesimulator)
#
#  Prereq:
#    - CDC iOS SDK has been built (projects/ios/build.sh)
#    - Xcode project has been generated (./gen_xcode.sh) OR this script will run it
#
#  Effect:
#    - cmake --build sample/cdc_sample/ios --config <Debug|Release>
#    - POST_BUILD 会自动:
#         a) 从 <repo>/build/ios/<config>/dylib/ 拷贝 libcdc.dylib 到 .app/Frameworks/
#         b) 用 Xcode 当前的 CODE_SIGN_IDENTITY 对该 dylib 做 codesign
#         c) Xcode 主体流程完成后, 整个 .app 也被 Apple Development 证书签好
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

BUILD_TYPE="${1:-Debug}"
DEST_ARG="${2:-device}"

case "${DEST_ARG}" in
    device)
        SDK="iphoneos"
        DEST="generic/platform=iOS"
        ;;
    simulator)
        SDK="iphonesimulator"
        DEST="generic/platform=iOS Simulator"
        ;;
    *)
        echo "[build][error] unknown destination: ${DEST_ARG} (want: device | simulator)" >&2
        exit 1
        ;;
esac

echo "============================================================"
echo "  CDC Sample iOS Build"
echo "  Config    : ${BUILD_TYPE}"
echo "  SDK       : ${SDK}"
echo "  BuildDir  : ${SCRIPT_DIR}"
echo "============================================================"

# 若 xcodeproj 不存在, 自动 generate 一次
if [ ! -d "${SCRIPT_DIR}/cdc_sample.xcodeproj" ]; then
    echo "[build] xcodeproj not found, running gen_xcode.sh first..."
    "${SCRIPT_DIR}/gen_xcode.sh" "${BUILD_TYPE}"
fi

# 直接用 xcodebuild, 明确指定 SDK 和 destination (真机 / 模拟器)
xcodebuild \
    -project "${SCRIPT_DIR}/cdc_sample.xcodeproj" \
    -scheme cdc_sample \
    -configuration "${BUILD_TYPE}" \
    -sdk "${SDK}" \
    -destination "${DEST}" \
    -allowProvisioningUpdates \
    build

APP_PATH="${SCRIPT_DIR}/${BUILD_TYPE}-${SDK}/cdc_sample.app"
if [ ! -d "${APP_PATH}" ]; then
    # cmake Xcode generator 默认输出到 build_dir/<config>-<sdk>/
    # 有时也会落在 build_dir/Debug-iphoneos/, 兜底再找一遍
    APP_PATH="$(find "${SCRIPT_DIR}" -type d -name 'cdc_sample.app' -path "*/${BUILD_TYPE}-${SDK}/*" | head -n1 || true)"
fi

echo ""
echo "============================================================"
echo "  Build succeeded"
echo "  App: ${APP_PATH:-<not-found>}"
echo "============================================================"

if [ -n "${APP_PATH:-}" ] && [ -d "${APP_PATH}" ]; then
    echo ""
    echo "[build] verifying signatures..."
    codesign -dv --verbose=2 "${APP_PATH}" 2>&1 | sed 's/^/  [app] /' || true
    if [ -f "${APP_PATH}/Frameworks/libcdc.dylib" ]; then
        codesign -dv --verbose=2 "${APP_PATH}/Frameworks/libcdc.dylib" 2>&1 | sed 's/^/  [dylib] /' || true
    fi
    echo ""
    echo "Next step - package into ipa:"
    echo "  ${SCRIPT_DIR}/package.sh ${BUILD_TYPE} ${DEST_ARG}"
fi
