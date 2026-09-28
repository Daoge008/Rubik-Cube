@echo off
rem Syntax-only check of the native sources against the real Android target.
rem
rem The host tests compile the headers with MSVC, which proves the algorithms
rem but says nothing about the Android build: a header guarded by the wrong
rem macro, a Windows-only include or a C++20 construct would slip through. This
rem runs the NDK clang exactly as the CMake build will, without linking.
rem
rem Usage:  tools\native_tests\syntax_check.bat  [ndk version, default 28.2.13676358]
setlocal

set "ROOT=%~dp0..\.."
set "CPP=%ROOT%\android\app\src\main\cpp"
set "NDKVER=%~1"
if "%NDKVER%"=="" set "NDKVER=28.2.13676358"
set "NDK=D:\dev\Android\sdk\ndk\%NDKVER%"
set "CXX=%NDK%\toolchains\llvm\prebuilt\windows-x86_64\bin\clang++.exe"

if not exist "%CXX%" (
  echo [error] clang++ not found at "%CXX%"
  exit /b 1
)

set "FAILED=0"
for %%F in ("%CPP%\*.cpp") do (
  echo === %%~nxF
  "%CXX%" --target=aarch64-linux-android26 -std=c++17 -Wall -Wextra ^
      -fsyntax-only -I"%CPP%" "%%~fF"
  if errorlevel 1 set "FAILED=1"
)

if "%FAILED%"=="1" (
  echo [error] syntax check failed
  exit /b 1
)
echo.
echo syntax check passed for NDK %NDKVER%
exit /b 0
