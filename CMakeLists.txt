# =============================================================================
# CDC Sample1 - Qt6 CMake 工程
#   依赖: Qt6 (Widgets) + CDC SDK
#   对应原 sample1.pro (已废弃 qmake -t vc)
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
# C++ 标准
# -----------------------------------------------------------------------------
set(CMAKE_CXX_STANDARD          17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS        OFF)

# -----------------------------------------------------------------------------
# MSVC 静态 CRT (与原 .pro 中 /MT /MTd 对齐)
# -----------------------------------------------------------------------------
if(POLICY CMP0091)
    cmake_policy(SET CMP0091 NEW)
endif()
set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>")

# -----------------------------------------------------------------------------
# 路径锚点
# -----------------------------------------------------------------------------
get_filename_component(SAMPLE_DIR "${CMAKE_CURRENT_SOURCE_DIR}" ABSOLUTE)
get_filename_component(CDC_ROOT   "${SAMPLE_DIR}/../.."       ABSOLUTE)

set(CDC_INC_DIR  "${CDC_ROOT}/inc")
set(CDC_BUILD_DIR "${CDC_ROOT}/build/windows")

message(STATUS "[sample1] sample dir = ${SAMPLE_DIR}")
message(STATUS "[sample1] cdc root   = ${CDC_ROOT}")

# -----------------------------------------------------------------------------
# Qt6 依赖
# -----------------------------------------------------------------------------
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# 使用系统安装的 Qt6 (如 D:/Qt/6.11.0/msvc2022_64)
# 生成 VS 工程前请先设置 CMAKE_PREFIX_PATH 指向 Qt6 安装路径, 见 gen_vs2022.bat
find_package(Qt6 REQUIRED COMPONENTS Widgets)

# -----------------------------------------------------------------------------
# CDC SDK 依赖 (导入库, 非源码编译)
# -----------------------------------------------------------------------------
# 导入库位置: <repo>/build/windows/<config>/lib/cdc.lib
# DLL 位置:    <repo>/build/windows/<config>/dll/cdc.dll
add_library(cdc SHARED IMPORTED)
set_target_properties(cdc PROPERTIES
    IMPORTED_LOCATION_DEBUG   "${CDC_BUILD_DIR}/debug/dll/cdc.dll"
    IMPORTED_IMPLIB_DEBUG     "${CDC_BUILD_DIR}/debug/lib/cdc.lib"
    IMPORTED_LOCATION_RELEASE "${CDC_BUILD_DIR}/release/dll/cdc.dll"
    IMPORTED_IMPLIB_RELEASE   "${CDC_BUILD_DIR}/release/lib/cdc.lib"
)

# 仅构建了 debug/release 两种 .dll/.lib, 将 RelWithDebInfo / MinSizeRel 映射到 Release
set_target_properties(cdc PROPERTIES
    MAP_IMPORTED_CONFIG_RELWITHDEBINFO Release
    MAP_IMPORTED_CONFIG_MINSIZEREL     Release
)

# CDC 公共头
set_property(TARGET cdc APPEND PROPERTY INTERFACE_INCLUDE_DIRECTORIES "${CDC_INC_DIR}")

# -----------------------------------------------------------------------------
# 可执行目标
# -----------------------------------------------------------------------------
set(SAMPLE_SOURCES
    main.cpp
    mainwindow.cpp
    mainwindow.h
)

add_executable(${PROJECT_NAME} WIN32 ${SAMPLE_SOURCES})

target_link_libraries(${PROJECT_NAME} PRIVATE
    Qt6::Widgets
    cdc
)

# -----------------------------------------------------------------------------
# MSVC 编译选项 (与原 .pro 对齐)
# -----------------------------------------------------------------------------
if(MSVC)
    target_compile_options(${PROJECT_NAME} PRIVATE
        /utf-8 /permissive- /Zc:__cplusplus /EHsc
    )
endif()

# -----------------------------------------------------------------------------
# 构建后复制 cdc.dll 到可执行文件目录
# -----------------------------------------------------------------------------
add_custom_command(TARGET ${PROJECT_NAME} POST_BUILD
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        "$<TARGET_FILE:cdc>"
        "$<TARGET_FILE_DIR:${PROJECT_NAME}>"
    COMMENT "[sample1] copy cdc.dll to output directory"
    VERBATIM
)

# -----------------------------------------------------------------------------
# IDE 文件分组
# -----------------------------------------------------------------------------
source_group("" FILES ${SAMPLE_SOURCES})