#!/bin/bash
# =============================================================================
#  CDC Sample macOS Qt Creator 工程生成
#   用法: ./gen_qtcreator.sh [Debug|Release]
#   默认: Debug
#
#   前置条件:
#     - macOS 11.0+
#     - Qt6 已安装 (默认 /Users/mac/Qt/6.11.1/macos)
#     - Qt Creator (推荐用 Qt Creator 打开 ../CMakeLists.txt)
#
#   本脚本用 Ninja 作为构建器, 生成到 mac/ 目录。
#   Qt Creator 打开 sample/cdc_sample/CMakeLists.txt 时会自动识别该构建目录。
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SAMPLE_SRC="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

BUILD_TYPE="${1:-Debug}"

# Qt6 安装路径
QT6_PREFIX="${QT6_PREFIX:-/Users/mac/Qt/6.11.1/macos}"

echo "=========================================="
echo "  CDC Sample Qt Creator Project Generator"
echo "  Build Type : ${BUILD_TYPE}"
echo "  Qt6 Prefix : ${QT6_PREFIX}"
echo "  Source Dir : ${SAMPLE_SRC}"
echo "  Build Dir  : ${SCRIPT_DIR}"
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

# 优先用 Ninja, 回退到 Unix Makefiles
BUILD_GENERATOR=""
if command -v ninja &>/dev/null; then
    BUILD_GENERATOR="Ninja"
    echo "  Generator   : Ninja ($(ninja --version))"
elif command -v make &>/dev/null; then
    BUILD_GENERATOR="Unix Makefiles"
    echo "  Generator   : Unix Makefiles"
else
    echo "[ERROR] Neither ninja nor make found. Install one: brew install ninja"
    exit 1
fi

# cmake configure
cmake -G "${BUILD_GENERATOR}" \
    -B "${SCRIPT_DIR}" \
    -S "${SAMPLE_SRC}" \
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=11.0 \
    -DCMAKE_PREFIX_PATH="${QT6_PREFIX}" \
    -DCDC_BUILD_DIR="${REPO_ROOT}/build/mac"

echo ""
echo "Build done."
echo ""
echo "To open in Qt Creator:"
echo "  open -a \"Qt Creator\" \"${SAMPLE_SRC}/CMakeLists.txt\""
echo ""
echo "Or in Qt Creator: File -> Open File or Project -> select:"
echo "  ${SAMPLE_SRC}/CMakeLists.txt"
echo ""
echo "Qt Creator will detect the existing build in:"
echo "  ${SCRIPT_DIR}"
echo ""
echo "To build from command line:"
echo "  cmake --build ${SCRIPT_DIR} --config ${BUILD_TYPE}"