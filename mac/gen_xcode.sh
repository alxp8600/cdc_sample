#!/bin/bash
# =============================================================================
#  CDC Sample macOS Xcode Project Generator
#   用法: ./gen_xcode.sh [Debug|Release]
#   默认: Debug
#
#   工程位置: sample/cdc_sample/mac/cdc_sample.xcodeproj
#   依赖:     Qt 6.11.1 (默认 /Users/mac/Qt/6.11.1/macos)
#             libcdc.dylib (默认 ../../../build/mac/<config>/dylib/libcdc.dylib)
#
#   前置条件:
#     - macOS 11.0+
#     - Xcode 16+
#     - Qt 6.11.1 已安装
#     - libcdc.dylib 已编译 (通过 projects/mac/gen_xcode.sh 生成)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SAMPLE_SRC="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

BUILD_TYPE="${1:-Debug}"

# Qt6 安装路径 (根据实际情况修改)
QT6_PREFIX="${QT6_PREFIX:-/Users/mac/Qt/6.11.1/macos}"

echo "=========================================="
echo "  CDC Sample Xcode Project Generator"
echo "  Build Type : ${BUILD_TYPE}"
echo "  Qt6 Prefix : ${QT6_PREFIX}"
echo "  Source Dir : ${SAMPLE_SRC}"
echo "  Build Dir  : ${SCRIPT_DIR}"
echo "  SDK dylib  : ${REPO_ROOT}/build/mac/${BUILD_TYPE}/dylib/libcdc.dylib"
echo "=========================================="

# 检查 Qt6
if [ ! -d "${QT6_PREFIX}" ]; then
    echo "[ERROR] Qt6 not found at ${QT6_PREFIX}"
    echo "  Set QT6_PREFIX environment variable or edit this script."
    exit 1
fi

# 检查 libcdc.dylib
CDC_DYLIB="${REPO_ROOT}/build/mac/${BUILD_TYPE}/dylib/libcdc.dylib"
if [ ! -f "${CDC_DYLIB}" ]; then
    echo "[WARN] libcdc.dylib not found at ${CDC_DYLIB}"
    echo "  The sample project will be generated but linking will fail until the SDK is built."
    echo "  Build the SDK first: cd projects/mac && ./gen_xcode.sh ${BUILD_TYPE}"
    echo "  Then: cmake --build ${REPO_ROOT}/projects/mac --config ${BUILD_TYPE}"
fi

cmake -G Xcode \
    -B "${SCRIPT_DIR}" \
    -S "${SAMPLE_SRC}" \
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
    -DCMAKE_PREFIX_PATH="${QT6_PREFIX}" \
    -DCDC_BUILD_DIR="${REPO_ROOT}/build/mac"

echo ""
echo "Xcode project generated at ${SCRIPT_DIR}/cdc_sample.xcodeproj"
echo ""
echo "To build from command line:"
echo "  cmake --build ${SCRIPT_DIR} --config ${BUILD_TYPE}"
echo ""
echo "Or open ${SCRIPT_DIR}/cdc_sample.xcodeproj in Xcode."