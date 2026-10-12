@echo off
REM Double-click this file to install the Kiro Ghost Button extension.
REM ASCII-only on purpose: cmd.exe reads .bat using the OEM codepage, which
REM differs per Windows locale, so non-ASCII text here would break elsewhere.
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\install.ps1" %*
set EXITCODE=%ERRORLEVEL%

echo.
if not "%EXITCODE%"=="0" (
    echo ============================================
    echo  INSTALL FAILED - exit code %EXITCODE%
    echo  Read the messages above, then see README.md
    echo ============================================
)

pause
exit /b %EXITCODE%
