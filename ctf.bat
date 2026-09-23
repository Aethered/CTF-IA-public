@echo off
rem ==============================================================================
rem CTF-IA - Lanceur Windows pour PowerShell
rem ==============================================================================

where powershell >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERREUR] PowerShell est introuvable sur ce systeme.
    pause
    exit /b 1
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0ctf.ps1" %*
if %ERRORLEVEL% NEQ 0 (
    if "%1"=="" (
        echo.
        pause
    )
)
