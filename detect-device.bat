@echo off
title Proxmark3 Easy - Detect Device
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\detect-device.ps1"
echo.
pause
