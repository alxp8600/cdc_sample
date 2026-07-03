#!/bin/bash
# =============================================================================
#  CDC Sample iOS - Clean build artifacts (Xcode + CMake)
#   用法: ./clean_xcode.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Cleaning CDC Sample iOS build artifacts under ${SCRIPT_DIR}..."

# Xcode 工程 & 中间产物
rm -rf "${SCRIPT_DIR}/cdc_sample.xcodeproj"
rm -rf "${SCRIPT_DIR}/cdc_sample.xcworkspace"

# CMake 通用中间文件
rm -rf "${SCRIPT_DIR}/CMakeFiles"
rm -rf "${SCRIPT_DIR}/CMakeScripts"
rm -rf "${SCRIPT_DIR}/CMakeCache.txt"
rm -rf "${SCRIPT_DIR}/cmake_install.cmake"

# Qt Creator 用户配置
rm -rf "${SCRIPT_DIR}/.qt"
rm -rf "${SCRIPT_DIR}/CMakeUserPresets.json"

# Xcode 构建产物 (Debug-iphoneos / Release-iphoneos / Debug-iphonesimulator ...)
shopt -s nullglob
for d in "${SCRIPT_DIR}"/{Debug,Release}-iphone{os,simulator}; do
    if [ -d "${d}" ]; then
        echo "Removing ${d}"
        rm -rf "${d}"
    fi
done

# Xcode DerivedData 风格的 build/ 目录 (若 xcodebuild 有额外产物)
if [ -d "${SCRIPT_DIR}/build" ]; then
    echo "Removing ${SCRIPT_DIR}/build"
    rm -rf "${SCRIPT_DIR}/build"
fi

# 打包产物
if [ -d "${SCRIPT_DIR}/package" ]; then
    echo "Removing ${SCRIPT_DIR}/package"
    rm -rf "${SCRIPT_DIR}/package"
fi

# autogen 缓存
shopt -s nullglob
for d in "${SCRIPT_DIR}"/*_autogen; do
    if [ -d "${d}" ]; then
        echo "Removing ${d}"
        rm -rf "${d}"
    fi
done
shopt -u nullglob

echo "Done."
