@echo off
REM Double-click this file to remove the Kiro Ghost Button extension.
REM ASCII-only on purpose: see the note in install.bat.
setlocal

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\uninstall.ps1" %*
set EXITCODE=%ERRORLEVEL%

echo.
if not "%EXITCODE%"=="0" (
    echo ============================================
    echo  UNINSTALL FAILED - exit code %EXITCODE%
    echo  Read the messages above, then see README.md
    echo ============================================
)

pause
exit /b %EXITCODE%
