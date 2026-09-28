@echo off
rem Host side build + run of the CFOP diagnostics probe.
rem Mirrors run_tests.bat: the MSVC environment is set up by hand because
rem vcvars64.bat shells out to reg.exe, which the sandbox blacklists.
rem
rem Usage:  tools\native_tests\probe.bat  [source file, default cfop_probe.cpp]
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

if "%~1"=="" (set "SRC=%~dp0cfop_probe.cpp") else (set "SRC=%~dp0%~1")

rem Remaining arguments after the source file are forwarded to the probe itself.
set "RUNARGS=%2 %3 %4 %5 %6 %7 %8 %9"

cd /d "%OUT%"
cl /nologo /std:c++17 /utf-8 /EHsc /O2 /W3 /I"%CPP%" ^
   "%SRC%" ^
   /Fe:cfop_probe.exe
if errorlevel 1 (
  echo [error] compile failed
  exit /b 1
)

echo.
cfop_probe.exe %RUNARGS%
exit /b %errorlevel%
