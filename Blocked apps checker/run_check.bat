@echo off
:: Run PowerShell script as Administrator and keep PowerShell window open
PowerShell -NoProfile -ExecutionPolicy Bypass -Command ^
 "Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -NoExit -File ""%~dp0check_blocked_apps.ps1""' -Verb RunAs"
exit