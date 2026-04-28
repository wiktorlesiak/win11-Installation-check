SET ThisScriptsDirectory=%~dp0
SET PowerShellScriptPath=%ThisScriptsDirectory%ApplockerWin11scriptstask.ps1

PowerShell -NoProfile -ExecutionPolicy Bypass -Command "& {Start-Process PowerShell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File ""%PowerShellScriptPath%""' -Verb RunAs}"

REM Check if silent upgrade script exists
IF EXIST "C:\Win11Upgrade\silent-upgrade.cmd" (
    powershell.exe -command "& {Start-Process 'C:\Win11Upgrade\silent-upgrade.cmd' -ArgumentList 'Args' -Verb RunAs}"
) ELSE (
    REM If not found, run Windows 11 Installation Assistant
    powershell.exe -command "& {Start-Process 'C:\Windows11InstallationAssistant.exe' -Verb RunAs}"
)

pause