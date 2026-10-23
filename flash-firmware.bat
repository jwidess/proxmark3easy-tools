@echo off
title Proxmark3 Easy - Flash Firmware
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\flash-firmware.ps1"
echo.
pause
