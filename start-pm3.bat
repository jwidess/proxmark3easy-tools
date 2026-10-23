@echo off
title Proxmark3 Easy - Start Client
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\start-pm3.ps1"
if %ERRORLEVEL% NEQ 0 (
    echo.
    pause
)
