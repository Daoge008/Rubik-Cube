@echo off
rem Runs every native check in the order that fails fastest.
rem
rem These are two different guarantees and neither subsumes the other:
rem   run_tests.bat   proves the algorithms are arithmetically correct, but only
rem                   compiles the headers, so it never sees the FFI boundary;
rem   syntax_check.bat proves the sources still compile for the real Android
rem                   target, but says nothing about correctness.
rem Shipping on one of them alone is how librubik_core.so ends up unable to build
rem while the host tests stay green (this happened once: the FFI layer was not
rem updated when the engine moved into `namespace rubik`).
rem
rem Usage:  tools\native_tests\check_all.bat
setlocal

call "%~dp0syntax_check.bat"
if errorlevel 1 (
  echo.
  echo [check_all] FAILED at the Android syntax check
  exit /b 1
)

echo.
call "%~dp0run_tests.bat"
if errorlevel 1 (
  echo.
  echo [check_all] FAILED at the host tests
  exit /b 1
)

echo.
echo [check_all] both native checks passed
exit /b 0
