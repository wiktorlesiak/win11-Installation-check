@echo off

:: Elevate to Administrator if not already
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
"$TaskName = 'Set-UKRegionalSettings'; ^
$ScriptPath = 'C:\Temp\Set-UKRegion.ps1'; ^
if (-not (Test-Path $ScriptPath)) { Write-Error 'Cannot find script at C:\Temp\Set-UKRegion.ps1. Please create Set-UKRegion.ps1 first.'; exit 1 }; ^
if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false }; ^
$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument '-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File ""C:\Temp\Set-UKRegion.ps1""'; ^
$Trigger = New-ScheduledTaskTrigger -AtLogOn; ^
$Principal = New-ScheduledTaskPrincipal -GroupId 'S-1-5-32-545' -RunLevel Limited; ^
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Description 'Applies UK regional format settings at logon for all standard users' -Force; ^
Write-Host 'Scheduled task Set-UKRegionalSettings registered for built-in Users group.'"

pause