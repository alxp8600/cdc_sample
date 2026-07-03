#!/bin/bash
# =============================================================================
#  CDC Sample - iOS embed + codesign libcdc.dylib
#
#  由 CMake add_custom_command(TARGET ... POST_BUILD) 调用
#  (在 Xcode 生成器下等价于一个 Run Script build phase).
#
#  Usage:
#    embed_and_sign.sh <src_dylib> [<app_bundle_dir>]
#
#  <app_bundle_dir> 可选:
#    - 不传时, 会读取 Xcode 提供的以下环境变量拼接 app bundle 路径:
#        BUILT_PRODUCTS_DIR   例如 /path/to/Debug-iphoneos
#        FULL_PRODUCT_NAME    例如 cdc_sample.app
#      这是最可靠的方式, 避免 CMake 在 Xcode 生成器下把 $<TARGET_BUNDLE_DIR>
#      展开成含 ${EFFECTIVE_PLATFORM_NAME} 字面量的路径而无法解析.
#
#  Xcode 环境变量 (通常 Run Script phase 会自动注入, 手动运行时可选):
#    EXPANDED_CODE_SIGN_IDENTITY     证书 SHA1 (最可靠, 优先使用)
#    CODE_SIGN_IDENTITY              例如 "Apple Development"
#    CONFIGURATION                   Debug / Release
#    BUILT_PRODUCTS_DIR              构建产物根目录
#    FULL_PRODUCT_NAME               产物名, e.g. cdc_sample.app
#
#  Actions:
#    1. mkdir -p <app_bundle>/Frameworks
#    2. cp <src_dylib> <app_bundle>/Frameworks/
#    3. codesign --force --sign <id> <app_bundle>/Frameworks/libcdc.dylib
# =============================================================================
set -euo pipefail

if [ "$#" -lt 1 ]; then
    echo "[embed_and_sign][error] usage: $0 <src_dylib> [<app_bundle_dir>]" >&2
    exit 1
fi

SRC_DYLIB="$1"
APP_BUNDLE="${2:-}"

# --- 解析 app bundle 路径 ---------------------------------------------------
if [ -z "${APP_BUNDLE}" ]; then
    if [ -n "${BUILT_PRODUCTS_DIR:-}" ] && [ -n "${FULL_PRODUCT_NAME:-}" ]; then
        APP_BUNDLE="${BUILT_PRODUCTS_DIR}/${FULL_PRODUCT_NAME}"
    else
        echo "[embed_and_sign][error] app bundle dir not provided and BUILT_PRODUCTS_DIR/FULL_PRODUCT_NAME env vars are empty" >&2
        exit 1
    fi
fi

if [ ! -f "${SRC_DYLIB}" ]; then
    echo "[embed_and_sign][error] source dylib not found: ${SRC_DYLIB}" >&2
    echo "[embed_and_sign][hint ] build CDC SDK first:" >&2
    echo "                        cd projects/ios && ./build.sh Debug" >&2
    exit 1
fi

if [ ! -d "${APP_BUNDLE}" ]; then
    echo "[embed_and_sign][error] app bundle not found: ${APP_BUNDLE}" >&2
    exit 1
fi

DYLIB_NAME="$(basename "${SRC_DYLIB}")"
DEST_DIR="${APP_BUNDLE}/Frameworks"
DEST_DYLIB="${DEST_DIR}/${DYLIB_NAME}"

echo "[embed_and_sign] src   : ${SRC_DYLIB}"
echo "[embed_and_sign] app   : ${APP_BUNDLE}"
echo "[embed_and_sign] dest  : ${DEST_DYLIB}"

# --- 1. copy ----------------------------------------------------------------
mkdir -p "${DEST_DIR}"
cp -f "${SRC_DYLIB}" "${DEST_DYLIB}"
chmod u+w "${DEST_DYLIB}"

# --- 2. pick codesign identity ---------------------------------------------
#  优先级: EXPANDED_CODE_SIGN_IDENTITY (SHA1) > CODE_SIGN_IDENTITY > "-" (ad-hoc)
IDENTITY=""
if [ -n "${EXPANDED_CODE_SIGN_IDENTITY:-}" ]; then
    IDENTITY="${EXPANDED_CODE_SIGN_IDENTITY}"
elif [ -n "${CODE_SIGN_IDENTITY:-}" ]; then
    IDENTITY="${CODE_SIGN_IDENTITY}"
else
    IDENTITY="-"
fi

# 模拟器 build 时 Xcode 会把 CODE_SIGN_IDENTITY 设为空字符串, 走 ad-hoc
if [ -z "${IDENTITY}" ]; then
    IDENTITY="-"
fi

echo "[embed_and_sign] ident : ${IDENTITY}"

# --- 3. codesign ------------------------------------------------------------
# --generate-entitlement-der: iOS 15+ 真机要求 DER-encoded entitlements
if xcrun codesign --help 2>&1 | grep -q -- '--generate-entitlement-der'; then
    DER_FLAG="--generate-entitlement-der"
else
    DER_FLAG=""
fi

xcrun codesign --force \
    --sign "${IDENTITY}" \
    --timestamp=none \
    ${DER_FLAG} \
    "${DEST_DYLIB}"

echo "[embed_and_sign] done  ."
