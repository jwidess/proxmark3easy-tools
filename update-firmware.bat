@echo off
title Proxmark3 Easy - Update & Rebuild Firmware
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\update-firmware.ps1"
echo.
pause
