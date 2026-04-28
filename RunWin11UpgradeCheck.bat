@echo off
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File "Run-All.ps1"

pause