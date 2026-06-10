@echo off
rem ============================================================================
rem  CDC Sample Windows - Clean VS build artifacts
rem   用法: clean_vs.bat
rem ============================================================================

setlocal EnableExtensions
pushd "%~dp0"

echo Cleaning CDC Sample Windows VS build artifacts...

if exist "cdc_sample.sln"          del /q "cdc_sample.sln"
if exist "cdc_sample.vcxproj"      del /q "cdc_sample.vcxproj"
if exist "cdc_sample.vcxproj.filters" del /q "cdc_sample.vcxproj.filters"
if exist "cdc_sample.vcxproj.user" del /q "cdc_sample.vcxproj.user"
if exist "ALL_BUILD.vcxproj"       del /q "ALL_BUILD.vcxproj"
if exist "ALL_BUILD.vcxproj.filters" del /q "ALL_BUILD.vcxproj.filters"
if exist "ZERO_CHECK.vcxproj"      del /q "ZERO_CHECK.vcxproj"
if exist "ZERO_CHECK.vcxproj.filters" del /q "ZERO_CHECK.vcxproj.filters"
if exist "cmake_install.cmake"     del /q "cmake_install.cmake"
if exist "CMakeCache.txt"          del /q "CMakeCache.txt"

if exist "CMakeFiles"              rmdir /s /q "CMakeFiles"
if exist "CMakeScripts"            rmdir /s /q "CMakeScripts"
if exist "Debug"                   rmdir /s /q "Debug"
if exist "Release"                 rmdir /s /q "Release"
if exist "x64"                     rmdir /s /q "x64"
if exist "Win32"                   rmdir /s /q "Win32"
if exist "cdc_sample.dir"          rmdir /s /q "cdc_sample.dir"
if exist "cdc_sample_autogen.dir"  rmdir /s /q "cdc_sample_autogen.dir"

echo Done.

popd
endlocal
exit /b 0