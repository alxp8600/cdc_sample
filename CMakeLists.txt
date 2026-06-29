# =============================================================================
# CDC Sample - Qt6 CMake 工程 (跨平台: macOS / Windows)
#   依赖: Qt6 (Widgets) + CDC SDK (预编译导入库)
# =============================================================================

cmake_minimum_required(VERSION 3.20)

# -----------------------------------------------------------------------------
# 项目声明
# -----------------------------------------------------------------------------
project(cdc_sample
    VERSION     1.0.0
    LANGUAGES   CXX
    DESCRIPTION "CDC SDK Sample Application"
)

# -----------------------------------------------------------------------------
# C++ 标准 (与 CDC SDK 对齐: C++20)
# -----------------------------------------------------------------------------
set(CMAKE_CXX_STANDARD          20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS        OFF)

# -----------------------------------------------------------------------------
# 平台识别
# -----------------------------------------------------------------------------
if(APPLE)
    set(CDC_SAMPLE_PLATFORM "mac")
elseif(WIN32)
    set(CDC_SAMPLE_PLATFORM "windows")
else()
    message(FATAL_ERROR "[sample] Unsupported platform: ${CMAKE_SYSTEM_NAME}")
endif()

message(STATUS "[sample] target platform = ${CDC_SAMPLE_PLATFORM}")

# -----------------------------------------------------------------------------
# 路径锚点
# -----------------------------------------------------------------------------
get_filename_component(SAMPLE_DIR "${CMAKE_CURRENT_SOURCE_DIR}" ABSOLUTE)
get_filename_component(CDC_ROOT   "${SAMPLE_DIR}/../.."       ABSOLUTE)

set(CDC_INC_DIR   "${CDC_ROOT}/inc")
# CDC_BUILD_DIR 可通过 -DCDC_BUILD_DIR=... 从外部覆盖, 默认自动推断
if(NOT DEFINED CDC_BUILD_DIR)
    set(CDC_BUILD_DIR "${CDC_ROOT}/build/${CDC_SAMPLE_PLATFORM}")
endif()

message(STATUS "[sample] sample dir = ${SAMPLE_DIR}")
message(STATUS "[sample] cdc root   = ${CDC_ROOT}")
message(STATUS "[sample] build dir  = ${CDC_BUILD_DIR}")

# -----------------------------------------------------------------------------
# Qt6 依赖
# -----------------------------------------------------------------------------
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# macOS: CMAKE_PREFIX_PATH 优先从环境变量读取, 否则使用默认值
if(CDC_SAMPLE_PLATFORM STREQUAL "mac" AND NOT DEFINED CMAKE_PREFIX_PATH)
    if(DEFINED ENV{CMAKE_PREFIX_PATH})
        set(CMAKE_PREFIX_PATH "$ENV{CMAKE_PREFIX_PATH}" CACHE STRING "Qt6 install prefix" FORCE)
    else()
        set(CMAKE_PREFIX_PATH "/Users/mac/Qt/6.11.1/macos" CACHE STRING "Qt6 install prefix" FORCE)
        message(STATUS "[sample] CMAKE_PREFIX_PATH env not set, using default: /Users/mac/Qt/6.11.1/macos")
    endif()
endif()

find_package(Qt6 REQUIRED COMPONENTS Widgets)

# -----------------------------------------------------------------------------
# CDC SDK 依赖 (导入库, 非源码编译)
# -----------------------------------------------------------------------------
add_library(cdc SHARED IMPORTED)

if(CDC_SAMPLE_PLATFORM STREQUAL "windows")
    # MSVC: 导入 .dll + .lib
    # 产物路径: <repo>/build/windows/<config>/dll/cdc.dll
    #            <repo>/build/windows/<config>/lib/cdc.lib
    set_target_properties(cdc PROPERTIES
        IMPORTED_LOCATION_DEBUG   "${CDC_BUILD_DIR}/debug/dll/cdc.dll"
        IMPORTED_IMPLIB_DEBUG     "${CDC_BUILD_DIR}/debug/lib/cdc.lib"
        IMPORTED_LOCATION_RELEASE "${CDC_BUILD_DIR}/release/dll/cdc.dll"
        IMPORTED_IMPLIB_RELEASE   "${CDC_BUILD_DIR}/release/lib/cdc.lib"
    )
    set_target_properties(cdc PROPERTIES
        MAP_IMPORTED_CONFIG_RELWITHDEBINFO Release
        MAP_IMPORTED_CONFIG_MINSIZEREL     Release
    )
elseif(CDC_SAMPLE_PLATFORM STREQUAL "mac")
    # macOS: 导入 .dylib
    # 产物路径: <repo>/build/mac/<config>/dylib/libcdc.dylib
    set_target_properties(cdc PROPERTIES
        IMPORTED_LOCATION_DEBUG   "${CDC_BUILD_DIR}/debug/dylib/libcdc.dylib"
        IMPORTED_LOCATION_RELEASE "${CDC_BUILD_DIR}/release/dylib/libcdc.dylib"
    )
    set_target_properties(cdc PROPERTIES
        MAP_IMPORTED_CONFIG_RELWITHDEBINFO Release
        MAP_IMPORTED_CONFIG_MINSIZEREL     Release
    )
endif()

# CDC 公共头
set_property(TARGET cdc APPEND PROPERTY INTERFACE_INCLUDE_DIRECTORIES "${CDC_INC_DIR}")

# -----------------------------------------------------------------------------
# 可执行目标
# -----------------------------------------------------------------------------
if(CDC_SAMPLE_PLATFORM STREQUAL "mac")
    list(APPEND SAMPLE_SOURCES input_capture_mac.mm)
endif()

set(SAMPLE_SOURCES
    input_capture.cpp
    input_capture.h
    main.cpp
    mainwindow.cpp
    mainwindow.h
    ${SAMPLE_SOURCES}
)

if(CDC_SAMPLE_PLATFORM STREQUAL "windows")
    add_executable(${PROJECT_NAME} WIN32 ${SAMPLE_SOURCES})
elseif(CDC_SAMPLE_PLATFORM STREQUAL "mac")
    add_executable(${PROJECT_NAME} MACOSX_BUNDLE ${SAMPLE_SOURCES})
endif()

target_link_libraries(${PROJECT_NAME} PRIVATE
    Qt6::Widgets
    cdc
)

if(CDC_SAMPLE_PLATFORM STREQUAL "mac")
    target_link_libraries(${PROJECT_NAME} PRIVATE
        "-framework Cocoa"
        "-framework ApplicationServices"
    )
endif()

# -----------------------------------------------------------------------------
# macOS 编译/链接选项
# -----------------------------------------------------------------------------
if(CDC_SAMPLE_PLATFORM STREQUAL "mac")
    target_compile_options(${PROJECT_NAME} PRIVATE -Wall -Wextra)
    set_target_properties(${PROJECT_NAME} PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST "${CMAKE_CURRENT_SOURCE_DIR}/Info.plist"
    )
    # 设置 rpath 使 app bundle 能找到 libcdc.dylib (与 app 同目录或系统路径)
    set_target_properties(${PROJECT_NAME} PROPERTIES
        BUILD_RPATH "${CDC_BUILD_DIR}/$<CONFIG>/dylib"
        INSTALL_RPATH "@executable_path/../Frameworks"
    )
endif()

# -----------------------------------------------------------------------------
# MSVC 编译选项 (与原 .pro 对齐)
# -----------------------------------------------------------------------------
if(MSVC)
    if(POLICY CMP0091)
        cmake_policy(SET CMP0091 NEW)
    endif()
    set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

    target_compile_options(${PROJECT_NAME} PRIVATE
        /utf-8 /permissive- /Zc:__cplusplus /EHsc
    )
endif()

# -----------------------------------------------------------------------------
# 构建后复制 CDC 库到可执行文件目录
# -----------------------------------------------------------------------------
if(CDC_SAMPLE_PLATFORM STREQUAL "windows")
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "$<TARGET_FILE:cdc>"
            "$<TARGET_FILE_DIR:${PROJECT_NAME}>"
        COMMENT "[sample] copy cdc.dll to output directory"
        VERBATIM
    )
elseif(CDC_SAMPLE_PLATFORM STREQUAL "mac")
    # 将 libcdc.dylib 复制到 .app bundle 的 Contents/MacOS/ 目录
    # 然后对整个 .app bundle 做 ad-hoc 签名，避免 Gatekeeper 报"包损坏"
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND ${CMAKE_COMMAND} -E copy_if_different
            "$<TARGET_FILE:cdc>"
            "$<TARGET_FILE_DIR:${PROJECT_NAME}>"
        COMMAND ${CMAKE_COMMAND} -E echo "[sample] signing app bundle with ad-hoc signature..."
        COMMAND codesign --force --deep --sign - "$<TARGET_BUNDLE_DIR:${PROJECT_NAME}>"
        COMMENT "[sample] copy libcdc.dylib + ad-hoc sign app bundle"
        VERBATIM
    )
endif()

# -----------------------------------------------------------------------------
# IDE 文件分组
# -----------------------------------------------------------------------------
source_group("" FILES ${SAMPLE_SOURCES})