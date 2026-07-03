#!/bin/bash
# =============================================================================
#  CDC Sample iOS Xcode Project Generator
#   用法: ./gen_xcode.sh [Debug|Release]
#   默认: Debug
#
#   工程位置: sample/cdc_sample/ios/cdc_sample.xcodeproj
#   依赖:     Qt 6.11.1 iOS  (默认 /Users/mac/Qt/6.11.1/ios)
#             libcdc.dylib   (默认 <repo>/build/ios/<config>/dylib/libcdc.dylib)
#
#   环境变量 (可选):
#     QT6_PREFIX     Qt6 iOS 安装目录, 默认 /Users/mac/Qt/6.11.1/ios
#     DEV_TEAM       Apple Development Team ID, 默认 963ETKEBWZ
#     BUNDLE_ID      App Bundle Identifier, 默认 com.cdc.sample
#
#   前置条件:
#     - macOS 11.0+
#     - Xcode 16+
#     - Qt 6.11.1 iOS 已安装
#     - CDC iOS SDK 已编译 (通过 projects/ios/build.sh)
#     - iPhone 已通过 Xcode 建立信任 (真机安装)
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SAMPLE_SRC="$(cd "${SCRIPT_DIR}/.." && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

BUILD_TYPE="${1:-Debug}"

QT6_PREFIX="${QT6_PREFIX:-/Users/mac/Qt/6.11.1/ios}"
DEV_TEAM="${DEV_TEAM:-963ETKEBWZ}"
BUNDLE_ID="${BUNDLE_ID:-com.cdc.sample}"

CFG_LOWER="$(echo "${BUILD_TYPE}" | tr '[:upper:]' '[:lower:]')"
CDC_DYLIB="${REPO_ROOT}/build/ios/${CFG_LOWER}/dylib/libcdc.dylib"

# Qt6 iOS 需要使用 qt.toolchain.cmake, 否则 find_package(Qt6) 会失败
QT_TOOLCHAIN="${QT6_PREFIX}/lib/cmake/Qt6/qt.toolchain.cmake"

echo "=========================================="
echo "  CDC Sample iOS Xcode Project Generator"
echo "  Build Type    : ${BUILD_TYPE}"
echo "  Qt6 Prefix    : ${QT6_PREFIX}"
echo "  Source Dir    : ${SAMPLE_SRC}"
echo "  Build Dir     : ${SCRIPT_DIR}"
echo "  SDK  Dir      : ${REPO_ROOT}/build/ios"
echo "  SDK  dylib    : ${CDC_DYLIB}"
echo "  Dev Team      : ${DEV_TEAM}"
echo "  Bundle Id     : ${BUNDLE_ID}"
echo "=========================================="

# --- 1. 前置检查 -------------------------------------------------------------
if [ ! -d "${QT6_PREFIX}" ]; then
    echo "[ERROR] Qt6 iOS not found at ${QT6_PREFIX}"
    echo "  Set QT6_PREFIX environment variable or edit this script."
    exit 1
fi

if [ ! -f "${QT_TOOLCHAIN}" ]; then
    echo "[ERROR] Qt6 iOS toolchain not found: ${QT_TOOLCHAIN}"
    echo "  This means QT6_PREFIX (${QT6_PREFIX}) is not a valid Qt6 iOS installation."
    exit 1
fi

if [ ! -f "${CDC_DYLIB}" ]; then
    echo "[WARN ] libcdc.dylib not found at ${CDC_DYLIB}"
    echo "        Project will be generated but link/embed will fail until SDK is built:"
    echo "        cd projects/ios && ./build.sh ${BUILD_TYPE}"
fi

# --- 2. 清理旧 cmake 缓存 (避免复用 macOS/host 配置生成 Catalyst 工程) --------
echo ""
echo "Cleaning old cmake cache..."
rm -rf \
    "${SCRIPT_DIR}/CMakeCache.txt" \
    "${SCRIPT_DIR}/CMakeFiles" \
    "${SCRIPT_DIR}/CMakeScripts" \
    "${SCRIPT_DIR}/cmake_install.cmake" \
    "${SCRIPT_DIR}/cdc_sample.xcodeproj" \
    "${SCRIPT_DIR}/CMakeUserPresets.json" \
    "${SCRIPT_DIR}/.qt"

# --- 3. cmake configure (Xcode generator) -----------------------------------
#   qt.toolchain.cmake 会自动设置:
#     CMAKE_SYSTEM_NAME=iOS, CMAKE_OSX_SYSROOT, CMAKE_OSX_ARCHITECTURES 等,
#     以及正确的 CMAKE_PREFIX_PATH 让 find_package(Qt6) 生效.
#   我们再显式覆盖 SUPPORTED_PLATFORMS 与 DEPLOYMENT_TARGET 以匹配需求.
cmake -G Xcode \
    -B "${SCRIPT_DIR}" \
    -S "${SAMPLE_SRC}" \
    -DCMAKE_TOOLCHAIN_FILE="${QT_TOOLCHAIN}" \
    -DCMAKE_XCODE_ATTRIBUTE_SUPPORTED_PLATFORMS="iphoneos" \
    -DCMAKE_OSX_ARCHITECTURES="arm64" \
    -DCMAKE_OSX_DEPLOYMENT_TARGET=15.0 \
    -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
    -DCDC_BUILD_DIR="${REPO_ROOT}/build/ios" \
    -DCDC_DEV_TEAM="${DEV_TEAM}" \
    -DCDC_BUNDLE_ID="${BUNDLE_ID}"

echo ""
echo "Xcode project generated:  ${SCRIPT_DIR}/cdc_sample.xcodeproj"
echo ""
echo "To build from command line (auto-embeds + signs libcdc.dylib):"
echo "  ${SCRIPT_DIR}/build.sh ${BUILD_TYPE}"
echo ""
echo "To open in Xcode:"
echo "  open ${SCRIPT_DIR}/cdc_sample.xcodeproj"
echo ""
echo "To open in Qt Creator:"
echo "  File -> Open File or Project -> ${SAMPLE_SRC}/CMakeLists.txt"
echo "  (in Kit setup, choose iOS Kit; existing build directory ${SCRIPT_DIR} will be reused)"
