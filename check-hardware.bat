@echo off
title Proxmark3 Easy - Hardware Check
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\check-hardware.ps1"
echo.
pause
