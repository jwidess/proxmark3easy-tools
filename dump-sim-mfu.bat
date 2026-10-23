@echo off
title Proxmark3 Easy - MIFARE Ultralight Dump & Sim
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\dump-sim-mfu.ps1"
echo.
pause
