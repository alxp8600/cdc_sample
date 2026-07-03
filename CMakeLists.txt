# =============================================================================
# CDC Sample - Qt6 CMake 工程 (跨平台: macOS / Windows / iOS)
#   依赖: Qt6 (Widgets) + CDC SDK (预编译导入库)
# =============================================================================

cmake_minimum_required(VERSION 3.20)

# -----------------------------------------------------------------------------
# 项目声明
#    Apple 平台需要 OBJCXX 编译 miniaudio_impl / Apple 平台代码
# -----------------------------------------------------------------------------
if(APPLE)
    set(_cdc_sample_languages CXX OBJCXX)
else()
    set(_cdc_sample_languages CXX)
endif()

project(cdc_sample
    VERSION     1.0.0
    LANGUAGES   ${_cdc_sample_languages}
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
#   iOS:  CMAKE_SYSTEM_NAME = "iOS" (由 Qt Creator iOS kit 或 -DCMAKE_SYSTEM_NAME=iOS 设置)
#   mac:  APPLE 为真但 CMAKE_SYSTEM_NAME != "iOS"
# -----------------------------------------------------------------------------
if(CMAKE_SYSTEM_NAME STREQUAL "iOS")
    set(CDC_SAMPLE_PLATFORM "ios")
elseif(APPLE)
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

# iOS: CMAKE_PREFIX_PATH 优先从环境变量读取, 否则使用默认值
if(CDC_SAMPLE_PLATFORM STREQUAL "ios" AND NOT DEFINED CMAKE_PREFIX_PATH)
    if(DEFINED ENV{CMAKE_PREFIX_PATH})
        set(CMAKE_PREFIX_PATH "$ENV{CMAKE_PREFIX_PATH}" CACHE STRING "Qt6 install prefix" FORCE)
    else()
        set(CMAKE_PREFIX_PATH "/Users/mac/Qt/6.11.1/ios" CACHE STRING "Qt6 install prefix" FORCE)
        message(STATUS "[sample] CMAKE_PREFIX_PATH env not set, using default: /Users/mac/Qt/6.11.1/ios")
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
elseif(CDC_SAMPLE_PLATFORM STREQUAL "ios")
    # iOS: 导入 .dylib
    # 产物路径: <repo>/build/ios/<config>/dylib/libcdc.dylib
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
set(SAMPLE_SOURCES
    input_capture.cpp
    input_capture.h
    main.cpp
    mainwindow.cpp
    mainwindow.h
)

if(CDC_SAMPLE_PLATFORM STREQUAL "mac")
    list(APPEND SAMPLE_SOURCES input_capture_mac.mm)
endif()

if(CDC_SAMPLE_PLATFORM STREQUAL "windows")
    add_executable(${PROJECT_NAME} WIN32 ${SAMPLE_SOURCES})
elseif(CDC_SAMPLE_PLATFORM STREQUAL "mac")
    add_executable(${PROJECT_NAME} MACOSX_BUNDLE ${SAMPLE_SOURCES})
elseif(CDC_SAMPLE_PLATFORM STREQUAL "ios")
    # MANUAL_FINALIZATION: 让我们在下面手动调用 qt_finalize_target,
    # 否则 Qt 会自动 DEFER 一次, 我们再调一次就会 warning "twice".
    qt_add_executable(${PROJECT_NAME} MANUAL_FINALIZATION ${SAMPLE_SOURCES})
endif()

target_link_libraries(${PROJECT_NAME} PRIVATE
    Qt6::Widgets
    cdc
)

if(CDC_SAMPLE_PLATFORM STREQUAL "mac")
    target_link_libraries(${PROJECT_NAME} PRIVATE
        "-framework Cocoa"
        "-framework ApplicationServices"
        "-framework GameController"
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
# iOS 编译/链接选项
#   注意事项:
#     - projects/ios/gen_xcode.sh 在 CDC SDK 层把 CODE_SIGNING_ALLOWED=NO,
#       这里必须在 sample target 上局部覆盖为 YES, 才能让 Xcode 自动签名 app + dylib.
#     - Automatic Code Signing 需要 DEVELOPMENT_TEAM. 支持通过 -DCDC_DEV_TEAM=xxx 覆盖.
#     - Bundle Identifier 可通过 -DCDC_BUNDLE_ID=xxx 覆盖.
# -----------------------------------------------------------------------------
if(CDC_SAMPLE_PLATFORM STREQUAL "ios")
    if(NOT DEFINED CDC_DEV_TEAM)
        set(CDC_DEV_TEAM "963ETKEBWZ")
    endif()
    if(NOT DEFINED CDC_BUNDLE_ID)
        set(CDC_BUNDLE_ID "com.cdc.sample")
    endif()

    message(STATUS "[sample] iOS DEVELOPMENT_TEAM     = ${CDC_DEV_TEAM}")
    message(STATUS "[sample] iOS PRODUCT_BUNDLE_ID    = ${CDC_BUNDLE_ID}")

    target_compile_options(${PROJECT_NAME} PRIVATE -Wall -Wextra)

    # 使用 iOS 专用 Info.plist (含 UIDeviceFamily / MinimumOSVersion 等 iOS 必需 key)
    set(_ios_info_plist "${CMAKE_CURRENT_SOURCE_DIR}/ios/Info.plist")

    set_target_properties(${PROJECT_NAME} PROPERTIES
        MACOSX_BUNDLE_INFO_PLIST                              "${_ios_info_plist}"
        XCODE_ATTRIBUTE_PRODUCT_BUNDLE_IDENTIFIER             "${CDC_BUNDLE_ID}"
        XCODE_ATTRIBUTE_DEVELOPMENT_TEAM                      "${CDC_DEV_TEAM}"
        XCODE_ATTRIBUTE_CODE_SIGN_STYLE                       "Automatic"
        # 覆盖 SDK 层的 NO, 允许 sample 在真机上签名
        XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED                  "YES"
        XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED                 "YES"
        "XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY[sdk=iphoneos*]"   "Apple Development"
        XCODE_ATTRIBUTE_ENABLE_BITCODE                        "NO"
        XCODE_ATTRIBUTE_TARGETED_DEVICE_FAMILY                "1,2"
        XCODE_ATTRIBUTE_IPHONEOS_DEPLOYMENT_TARGET            "15.0"
        XCODE_ATTRIBUTE_LD_RUNPATH_SEARCH_PATHS               "@executable_path/Frameworks"
        BUILD_RPATH   "@executable_path/Frameworks"
        INSTALL_RPATH "@executable_path/Frameworks"
    )
    qt_finalize_target(${PROJECT_NAME})
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
elseif(CDC_SAMPLE_PLATFORM STREQUAL "ios")
    # 将 libcdc.dylib 嵌入 .app bundle 的 Frameworks 目录并签名 (真机可运行)
    #
    # POST_BUILD 在 Xcode Run Script phase 中执行, Xcode 提供的环境变量:
    #   EXPANDED_CODE_SIGN_IDENTITY : 真正的证书 SHA1 (最可靠, 优先使用)
    #   CODE_SIGN_IDENTITY          : 例如 "Apple Development"
    #   CONFIGURATION               : Debug / Release
    #
    # 因为 add_custom_command 里直接写 shell $VAR 展开在 CMake 里比较绕
    # (VERBATIM + $$ 逃逸容易出错), 这里改为调用一个独立的 shell 脚本
    # ios/embed_and_sign.sh, 由它读取上述 Xcode 环境变量完成 拷贝+签名.
    # 注意: $<TARGET_BUNDLE_DIR> 在 Xcode 生成器下会展开成
    # "Debug${EFFECTIVE_PLATFORM_NAME}/cdc_sample.app", VERBATIM 会把
    # ${EFFECTIVE_PLATFORM_NAME} 当字面量传入 shell -> 不展开.
    # 因此让 embed_and_sign.sh 直接读 Xcode 提供的 BUILT_PRODUCTS_DIR /
    # FULL_PRODUCT_NAME 环境变量拼路径 (更可靠, 也不需要 VERBATIM).
    add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
        COMMAND /bin/bash
            "${CMAKE_CURRENT_SOURCE_DIR}/ios/embed_and_sign.sh"
            "${CDC_BUILD_DIR}/$<LOWER_CASE:$<CONFIG>>/dylib/libcdc.dylib"
        COMMENT "[sample][ios] embed + codesign libcdc.dylib into app bundle"
    )
endif()

# -----------------------------------------------------------------------------
# IDE 文件分组
# -----------------------------------------------------------------------------
source_group("" FILES ${SAMPLE_SOURCES})