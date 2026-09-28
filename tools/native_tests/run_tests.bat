@echo off
rem Host side build + run of the native engine tests.
rem
rem The MSVC environment is set up by hand instead of calling vcvars64.bat:
rem vcvars shells out to reg.exe, which the sandbox blacklists, so it silently
rem half-initialises and the compile then fails on missing crtdbg.h.
rem
rem Usage:  tools\native_tests\run_tests.bat  [extra source files...]
setlocal

set "ROOT=%~dp0..\.."
set "CPP=%ROOT%\android\app\src\main\cpp"
set "OUT=%~dp0build"

set "VC=C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Tools\MSVC\14.29.30133"
set "SDK=C:\Program Files (x86)\Windows Kits\10"
set "SDKVER=10.0.19041.0"

set "PATH=%VC%\bin\Hostx64\x64;%PATH%"
set "INCLUDE=%VC%\include;%SDK%\Include\%SDKVER%\ucrt;%SDK%\Include\%SDKVER%\shared;%SDK%\Include\%SDKVER%\um"
set "LIB=%VC%\lib\x64;%SDK%\Lib\%SDKVER%\ucrt\x64;%SDK%\Lib\%SDKVER%\um\x64"

if not exist "%OUT%" mkdir "%OUT%"

cd /d "%OUT%"
cl /nologo /std:c++17 /utf-8 /EHsc /O2 /W3 /I"%CPP%" ^
   "%~dp0engine_test.cpp" %* ^
   /Fe:engine_test.exe
if errorlevel 1 (
  echo [error] compile failed
  exit /b 1
)

echo.
engine_test.exe
exit /b %errorlevel%
