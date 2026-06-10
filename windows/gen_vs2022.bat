@echo off
rem ============================================================================
rem  CDC Sample - Visual Studio 2022 solution generator (Qt6 + CMake)
rem   用法: gen_vs2022.bat [x64|Win32]
rem
rem   输出目录: sample\cdc_sample\windows\  (sln + vcxproj)
rem
rem   前提条件:
rem     1. 已安装 Visual Studio 2022
rem     2. 已安装 Qt 6.11.0 msvc2022_64, 且环境变量 QTDIR 已指向该路径
rem     3. 已通过 CDC 根 CMake 构建好 cdc.dll / cdc.lib
rem ============================================================================

setlocal EnableExtensions

rem --- Change to bat directory for stable relative paths ------------------------
pushd "%~dp0"

rem --- Compute paths ------------------------------------------------------------
rem  BAT_DIR  = sample\cdc_sample\windows
rem  SAMPLE_SRC = sample\cdc_sample
rem  REPO_ROOT  = cdc root
set "BAT_DIR=%~dp0"
set "BAT_DIR=%BAT_DIR:~0,-1%"
for %%I in ("%BAT_DIR%\..") do set "SAMPLE_SRC=%%~fI"
for %%I in ("%BAT_DIR%\..\..\..") do set "REPO_ROOT=%%~fI"

echo [sample] BAT_DIR    = %BAT_DIR%
echo [sample] SAMPLE_SRC = %SAMPLE_SRC%
echo [sample] REPO_ROOT  = %REPO_ROOT%

rem --- Validate CMakeLists.txt -------------------------------------------------
if not exist "%SAMPLE_SRC%\CMakeLists.txt" (
    echo [sample][error] CMakeLists.txt not found at: %SAMPLE_SRC%\CMakeLists.txt
    popd
    endlocal
    exit /b 1
)

rem --- Check cmake -------------------------------------------------------------
where cmake >nul 2>nul
if errorlevel 1 (
    echo [sample][error] cmake not found in PATH. Install CMake 3.20+ and retry.
    popd
    endlocal
    exit /b 1
)

rem --- Detect Qt6 --------------------------------------------------------------
rem   1) 优先使用环境变量 QTDIR (推荐, 跨机器无硬编码)
rem   2) 回退到注册表查找 Qt 6.11.0 msvc2022_64 安装路径
rem   3) 尝试从 PATH 中检出 qmake.exe
for %%I in ("%QTDIR%") do set "QT6_DIR=%%~fI"
if defined QT6_DIR goto :qt6_found

rem   注册表探测 (Qt 在线安装器 / MaintenanceTool 写入)
for /f "skip=2 tokens=2*" %%A in (
    'reg query "HKEY_CURRENT_USER\Software\QtProject\Qt\6.11.0\msvc2022_64" /v "InstallDir" 2^>nul'
) do set "QT6_DIR=%%B"

if defined QT6_DIR goto :qt6_found

rem   尝试从 PATH 中检出 qmake.exe, 取其所在目录再向上一级即为 Qt6 根目录
for %%X in (qmake.exe) do set "QMAKE_DIR=%%~dp$PATH:X"
if defined QMAKE_DIR (
    for %%I in ("%QMAKE_DIR%..") do set "QT6_DIR=%%~fI"
    goto :qt6_found
)

echo [sample][error] Qt6 msvc2022_64 not found.
echo [sample]        Set QTDIR environment variable pointing to your Qt6 install, e.g.:
echo [sample]          set QTDIR=D:\Qt\6.11.0\msvc2022_64
echo [sample]        Or ensure qmake.exe is in PATH.
popd
endlocal
exit /b 1

:qt6_found
if not exist "%QT6_DIR%\lib\cmake\Qt6\Qt6Config.cmake" (
    echo [sample][error] %QT6_DIR% does not look like a valid Qt6 msvc2022_64 install
    popd
    endlocal
    exit /b 1
)

rem --- Check CDC artifacts (cdc.lib) -------------------------------------------
set "CDC_LIB=%REPO_ROOT%\build\windows\debug\lib\cdc.lib"
if not exist "%CDC_LIB%" (
    echo [sample][warning] CDC library not found at: %CDC_LIB%
    echo [sample]          Please build CDC SDK first (see projects\windows\gen_vs2026.bat).
    echo [sample]          VS project will be generated but linking will fail without cdc.lib.
)

rem --- Optional param: 1st arg = architecture (x64/Win32), default x64 ----------
set "VS_ARCH=%~1"
if "%VS_ARCH%"=="" set "VS_ARCH=x64"

set "GENERATOR=Visual Studio 17 2022"

echo [sample] generator = %GENERATOR%
echo [sample] arch      = %VS_ARCH%
echo [sample] qt6       = %QT6_DIR%
echo(

rem --- Run cmake configure -----------------------------------------------------
rem  CMAKE_PREFIX_PATH 告诉 find_package(Qt6) 去哪里找
cmake -S "%SAMPLE_SRC%" -B "%BAT_DIR%" -G "%GENERATOR%" -A %VS_ARCH% -DCMAKE_PREFIX_PATH="%QT6_DIR%" -DCDC_BUILD_DIR="%REPO_ROOT%\build\windows"
set "ERR=%ERRORLEVEL%"

if not "%ERR%"=="0" (
    echo(
    echo [sample][error] cmake configure failed with exit code %ERR%
    popd
    endlocal
    exit /b %ERR%
)

echo(
echo [sample] Visual Studio 2022 solution generated at:
echo          %BAT_DIR%\cdc_sample.sln
echo(
echo   Open the solution and build, or build from command line:
echo     cmake --build "%BAT_DIR%" --config Debug
echo(

popd
endlocal
exit /b 0