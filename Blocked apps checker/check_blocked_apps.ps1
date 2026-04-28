# check_blocked_apps.ps1
# Scans installed applications and compares with blocked_apps.txt (fuzzy match + logging)

# Collect installed apps
$installedApps = @()

# 64-bit
$installedApps += Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
    Select-Object DisplayName

# 32-bit
$installedApps += Get-ItemProperty HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* |
    Select-Object DisplayName

# Current user
$installedApps += Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* |
    Select-Object DisplayName

# Clean up list
$installedApps = $installedApps | Where-Object { $_.DisplayName } | Sort-Object DisplayName -Unique

Write-Host "=== Installed Applications ===" -ForegroundColor Cyan
$installedApps.DisplayName | ForEach-Object { Write-Host $_ }

# Load blocked list
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$blockedListPath = Join-Path $scriptDir "blocked_apps.txt"

$blockedApps = Get-Content $blockedListPath | Where-Object { $_.Trim() -ne "" }

Write-Host "`n=== Checking for Blocked Applications ===" -ForegroundColor Yellow

$foundBlocked = @()

foreach ($blocked in $blockedApps) {
    foreach ($app in $installedApps) {
        if ($app.DisplayName -match [Regex]::Escape($blocked)) {
            $foundBlocked += $app.DisplayName
        }
    }
}

# Prepare log file in the same folder as script
$logPath = Join-Path $scriptDir "blocked_report.txt"
$timeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$computerName = $env:COMPUTERNAME

Add-Content $logPath "`nScan Run: $timeStamp on $computerName"

Add-Content $logPath "`n=Installed Applications="
$installedApps.DisplayName | ForEach-Object { Add-Content $logPath $_ }

Add-Content $logPath "`n=Blocked Applications found="
if ($foundBlocked) {
    Write-Host "`nBlocked applications detected:" -ForegroundColor Red
    $foundBlocked | Sort-Object -Unique | ForEach-Object {
        Write-Host " - $_" -ForegroundColor Red
        Add-Content $logPath "Blocked app found: $_"
    }
} else {
    Write-Host "`nNo blocked applications found." -ForegroundColor Green
    Add-Content $logPath "No blocked applications found."
}

Write-Host "`nLog saved to $logPath"

Read-Host -Prompt "Press Enter to exit"