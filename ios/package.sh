#!/bin/bash
# =============================================================================
#  CDC Sample iOS - package .app into signed .ipa
#
#  Usage:
#    ./package.sh [Debug|Release] [device|simulator]
#      config : Debug (default) | Release
#      dest   : device (default) | simulator
#
#  Prereq:
#    - build.sh 已成功 (生成 .app 且已由 Xcode 用 Apple Development 证书签名)
#
#  Output:
#    sample/cdc_sample/ios/package/cdc_sample-<config>-<timestamp>.ipa
#
#  真机安装 (需 iPhone 与签名证书匹配):
#    1) Xcode -> Window -> Devices and Simulators -> 拖入 .ipa
#    2) 或 ideviceinstaller -i <ipa>   (brew install ideviceinstaller)
#    3) 或 xcrun devicectl device install app --device <UDID> <ipa>
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

BUILD_TYPE="${1:-Debug}"
DEST_ARG="${2:-device}"

case "${DEST_ARG}" in
    device)     SDK="iphoneos" ;;
    simulator)  SDK="iphonesimulator" ;;
    *)
        echo "[package][error] unknown destination: ${DEST_ARG}" >&2
        exit 1
        ;;
esac

echo "============================================================"
echo "  CDC Sample iOS Package"
echo "  Config : ${BUILD_TYPE}"
echo "  SDK    : ${SDK}"
echo "============================================================"

# --- 1. locate .app ---------------------------------------------------------
CANDIDATES=(
    "${SCRIPT_DIR}/${BUILD_TYPE}-${SDK}/cdc_sample.app"
    "${SCRIPT_DIR}/build/${BUILD_TYPE}-${SDK}/cdc_sample.app"
)

APP_PATH=""
for c in "${CANDIDATES[@]}"; do
    if [ -d "${c}" ]; then
        APP_PATH="${c}"
        break
    fi
done

if [ -z "${APP_PATH}" ]; then
    APP_PATH="$(find "${SCRIPT_DIR}" -type d -name 'cdc_sample.app' -path "*/${BUILD_TYPE}-${SDK}/*" | head -n1 || true)"
fi

if [ -z "${APP_PATH}" ] || [ ! -d "${APP_PATH}" ]; then
    echo "[package][error] cdc_sample.app not found under ${SCRIPT_DIR}" >&2
    echo "[package][hint ] run build.sh first: ${SCRIPT_DIR}/build.sh ${BUILD_TYPE} ${DEST_ARG}" >&2
    exit 1
fi

echo "[package] app         : ${APP_PATH}"

# --- 2. verify embedded dylib is signed ------------------------------------
EMBEDDED_DYLIB="${APP_PATH}/Frameworks/libcdc.dylib"
if [ ! -f "${EMBEDDED_DYLIB}" ]; then
    echo "[package][error] libcdc.dylib not embedded: ${EMBEDDED_DYLIB}" >&2
    exit 1
fi

echo "[package] check dylib signature..."
codesign -dv --verbose=2 "${EMBEDDED_DYLIB}" 2>&1 | sed 's/^/  [dylib] /'

echo "[package] check app signature..."
codesign -dv --verbose=2 "${APP_PATH}" 2>&1 | sed 's/^/  [app  ] /'

# 校验完整性 (device 构建才要求真证书验证; 模拟器跳过)
if [ "${SDK}" = "iphoneos" ]; then
    echo "[package] verifying app signature integrity..."
    if ! codesign --verify --deep --strict --verbose=2 "${APP_PATH}" 2>&1 | sed 's/^/  [verify] /'; then
        echo "[package][error] codesign --verify failed" >&2
        exit 2
    fi
fi

# --- 3. package into .ipa ---------------------------------------------------
PKG_DIR="${SCRIPT_DIR}/package"
mkdir -p "${PKG_DIR}"

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
IPA_NAME="cdc_sample-${BUILD_TYPE}-${DEST_ARG}-${TIMESTAMP}.ipa"
IPA_PATH="${PKG_DIR}/${IPA_NAME}"

STAGING="${PKG_DIR}/.staging"
rm -rf "${STAGING}"
mkdir -p "${STAGING}/Payload"

# 复制整个 .app 保留符号链接/权限
cp -R "${APP_PATH}" "${STAGING}/Payload/"

(
    cd "${STAGING}"
    # -X: 不存 uid/gid
    # -y: 保留符号链接
    zip -qry "${IPA_PATH}" Payload
)

rm -rf "${STAGING}"

if [ ! -f "${IPA_PATH}" ]; then
    echo "[package][error] failed to create ipa" >&2
    exit 3
fi

echo ""
echo "============================================================"
echo "  Package succeeded"
echo "  ipa : ${IPA_PATH}"
echo "  size: $(du -h "${IPA_PATH}" | awk '{print $1}')"
echo "============================================================"
echo ""
echo "Install on connected iPhone:"
echo "  1) Xcode -> Window -> Devices and Simulators -> drag ${IPA_PATH}"
echo "  2) or: xcrun devicectl device install app --device <UDID> ${IPA_PATH}"
echo "  3) or: ideviceinstaller -i ${IPA_PATH}   (brew install ideviceinstaller)"
