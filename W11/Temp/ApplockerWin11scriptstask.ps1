# ====== Scheduled Task Creation Block (runs ONCE) ======

$taskName = "Win11Scripts"
$scriptToRun = "C:\Temp\BackendScripts.ps1"

if (-not (Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue)) {
    Write-Host "Creating scheduled task '$taskName'..."

    $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-ExecutionPolicy Bypass -File `"$scriptToRun`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

    Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Description "Run Win11 automation script at boot" | Out-Null

    Write-Host "Scheduled task '$taskName' created."
} else {
    Write-Host "Scheduled task '$taskName' already exists. Skipping creation."
}

# ====== 7-Day Loop Block (runs repeatedly) ======

$LogPath = "C:\Temp\Applocker_log.txt"
$TotalRuntimeMinutes = 10080 # 7 days
$IntervalMinutes = 4
$ElapsedMinutes = 0

if (-not (Test-Path -Path $LogPath)) {
    New-Item -Path $LogPath -ItemType File -Force | Out-Null
}

function Write-Log {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Add-Content -Path $LogPath -Value "$timestamp - $Message"
}

Write-Log "Script started. Will run for $TotalRuntimeMinutes minutes."

$RegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\SrpV2\Appx"

while ($ElapsedMinutes -lt $TotalRuntimeMinutes) {
    Write-Log "Running task..."

    try {
        # Ensure registry path and 'EnforcementMode'
        New-Item -Path $RegPath -Force | Out-Null
        New-ItemProperty -Path $RegPath -Name "EnforcementMode" -Value 0 -PropertyType DWord -Force | Out-Null
        Write-Log "Set 'EnforcementMode' to 0."

        # Check if 'AllowWindows' exists
        $props = Get-ItemProperty -Path $RegPath -ErrorAction SilentlyContinue
        if ($props.PSObject.Properties.Name -contains "AllowWindows") {
            Set-ItemProperty -Path $RegPath -Name "AllowWindows" -Value 1
            Write-Log "'AllowWindows' existed and was updated to 1."
        } else {
            New-ItemProperty -Path $RegPath -Name "AllowWindows" -Value 1 -PropertyType DWord
            Write-Log "'AllowWindows' existed and was updated with value 1."
        }

    } catch {
        Write-Log "ERROR: $_"
    }

    Start-Sleep -Seconds ($IntervalMinutes * 60)
    $ElapsedMinutes += $IntervalMinutes
}

Write-Log "Script completed after $ElapsedMinutes minutes."
