#!/bin/bash
# =============================================================================
#  CDC Sample macOS - Clean build artifacts (Xcode / Ninja / Makefiles)
#   用法: ./clean_xcode.sh
# =============================================================================
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo "Cleaning CDC Sample macOS build artifacts..."

# Xcode 产物
rm -rf "${SCRIPT_DIR}/cdc_sample.xcodeproj"
rm -rf "${SCRIPT_DIR}/cdc_sample.xcworkspace"

# CMake 通用中间文件
rm -rf "${SCRIPT_DIR}/CMakeFiles"
rm -rf "${SCRIPT_DIR}/CMakeScripts"
rm -rf "${SCRIPT_DIR}/CMakeCache.txt"
rm -rf "${SCRIPT_DIR}/cmake_install.cmake"

# Ninja 产物
rm -rf "${SCRIPT_DIR}/build.ninja"
rm -rf "${SCRIPT_DIR}/rules.ninja"
rm -rf "${SCRIPT_DIR}/.ninja_log"
rm -rf "${SCRIPT_DIR}/.ninja_deps"

# Unix Makefiles 产物
rm -rf "${SCRIPT_DIR}/Makefile"

# Qt Creator 用户配置 (自动生成, 清理后重新 cmake 会重建)
rm -rf "${SCRIPT_DIR}/.qt"
rm -rf "${SCRIPT_DIR}/CMakeUserPresets.json"

# 构建输出产物
rm -rf "${SCRIPT_DIR}/cdc_sample.app"
rm -rf "${SCRIPT_DIR}/cdc_sample.dir"

echo "Done."
