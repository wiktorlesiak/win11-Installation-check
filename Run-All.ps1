# =====================================
# Win11 Full Automation Script
# =====================================

# -------------------------------
# Auto Elevate to Admin
# -------------------------------
if (-NOT ([Security.Principal.WindowsPrincipal] `
[Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(`
[Security.Principal.WindowsBuiltInRole] "Administrator"))
{
Write-Host "Restarting as Administrator..." -ForegroundColor Yellow
Start-Process powershell.exe "-ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
exit
}

$ErrorActionPreference = "Inquire"

# -------------------------------
# Script Location
# -------------------------------
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $ScriptRoot

# -------------------------------
# Logging
# -------------------------------
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

$LogFolder = Join-Path $ScriptRoot "Win11UpgradeCheckLog"

if (!(Test-Path $LogFolder)) {
    New-Item $LogFolder -ItemType Directory -Force | Out-Null
}

# Get device name + timestamp (dd-MM-yyyy format)
$DeviceName = $env:COMPUTERNAME
$TimeStamp = Get-Date -Format "dd-MM-yyyy_HH-mm"

# Build log file name
$LogFile = Join-Path $LogFolder ("{0}_{1}.txt" -f $DeviceName, $TimeStamp)

Start-Transcript -Path $LogFile

Write-Host "Logging to $LogFile" -ForegroundColor Cyan
Write-Host ""

# ================================
# SYSTEM INFORMATION
# ================================

Write-Host "===== SYSTEM INFORMATION =====" -ForegroundColor Cyan

$OS = Get-CimInstance Win32_OperatingSystem
$Computer = Get-CimInstance Win32_ComputerSystem
$BIOS = Get-CimInstance Win32_BIOS
$RAM = [math]::Round($Computer.TotalPhysicalMemory / 1GB,2)
$DomainInfo = $Computer.Domain

# Get Windows version (21H2 / 22H2)
$WinVersion = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").DisplayVersion

# Get SKU
$SKU = (Get-CimInstance -Namespace root\wmi -Class MS_SystemInformation).SystemSKU

# Get C: Drive Info
$CDrive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='C:'"

$CSizeGB = [math]::Round($CDrive.Size / 1GB, 2)
$CFreeGB = [math]::Round($CDrive.FreeSpace / 1GB, 2)

#Get IP
$IP = (Get-NetIPAddress -AddressFamily IPv4 |
       Where-Object IPAddress -ne "127.0.0.1").IPAddress[0]


Write-Host "ComputerName      : $env:COMPUTERNAME"
Write-Host "SerialNumber      : $($BIOS.SerialNumber)"
Write-Host "Model             : $SKU"
Write-Host "Domain            : $DomainInfo"
Write-Host "IP Address        : $IP"
Write-Host "InstalledRAM      : $RAM GB"
Write-Host "Disk Size         : $CSizeGB GB"
Write-Host "Free disk space   : $CFreeGB GB"
Write-Host "OSName            : $($OS.Caption)"
Write-Host "Version           : $($OS.Version)"
Write-Host "BuildNumber       : $($OS.BuildNumber)"
Write-Host "WindowsRelease    : $WinVersion"
Write-Host "OSArchitecture    : $($OS.OSArchitecture)"
Write-Host "=============================="
Write-Host ""

# ================================
# WINDOWS VERSION CHECK
# ================================

Write-Host "Checking Windows version..." -ForegroundColor Cyan

# Get DisplayVersion safely
$RegPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
$WinInfo = Get-ItemProperty -Path $RegPath -ErrorAction SilentlyContinue

$DisplayVersion = $WinInfo.DisplayVersion

if (-not $DisplayVersion) {
    Write-Host "Unable to determine Windows release version." -ForegroundColor Red
}
else {

    Write-Host "Detected Version: $DisplayVersion"

    # Extract numeric part (e.g., 21 from 21H2)
    if ($DisplayVersion -match '^(\d{2})H\d$') {
        $VersionNumber = [int]$matches[1]

        if ($VersionNumber -le 21) {
            Write-Host "WARNING: Windows version is $DisplayVersion." -ForegroundColor Yellow
            Write-Host "Feature update required: Upgrade to at least 22H2 before upgrading to Windows 11." -ForegroundColor Red
        }
        else {
            Write-Host "Windows version meets minimum requirement for Windows 11 upgrade path." -ForegroundColor Green
        }
    }
    else {
        Write-Host "Unrecognized Windows version format: $DisplayVersion" -ForegroundColor Yellow
    }
}

Write-Host ""

# ================================
# WINDOWS UPTIME CHECK
# ================================

Write-Host "Checking system uptime..." -ForegroundColor Cyan

$os = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue

if ($os) {
    $LastBoot = $os.LastBootUpTime
    $Uptime = (Get-Date) - $LastBoot

    Write-Host "System Uptime: $($Uptime.Days) Days $($Uptime.Hours) Hours"

    if ($Uptime.Days -ge 3) {
        Write-Host "Restart required: uptime > 3 days." -ForegroundColor Red
    }
    elseif ($Uptime.Days -ge 1) {
        Write-Host "Restart recommended: uptime > 1 day." -ForegroundColor Yellow
    }
    else {
        Write-Host "No restart required: uptime < 1 day." -ForegroundColor Green
    }
}
else {
    Write-Host "Unable to determine uptime." -ForegroundColor Red
}

Write-Host ""

# ================================
# WINDOWS PENDING RESTART CHECK
# ================================

Write-Host "Checking for pending reboot..." -ForegroundColor Cyan

$RebootPending = $false

if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending") {
    $RebootPending = $true
}

if (Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired") {
    $RebootPending = $true
}

if ($RebootPending) {
    Write-Host "Pending reboot detected. Restart required before upgrade." -ForegroundColor Red
}
else {
    Write-Host "No pending reboot." -ForegroundColor Green
}

Write-Host ""

# ================================
# WINDOWS ACTIVATION CHECK
# ================================

Write-Host "Checking Windows activation..." -ForegroundColor Cyan

$WindowsLicense = Get-CimInstance SoftwareLicensingProduct |
Where-Object { $_.Name -like "Windows*" -and $_.PartialProductKey }

if ($WindowsLicense.LicenseStatus -eq 1) {

Write-Host "Windows is ACTIVATED." -ForegroundColor Green

}
else {

Write-Host "Windows NOT activated. Running fix..." -ForegroundColor Red

$ActivationScript = Join-Path $ScriptRoot "Documents\W10 activation\activation w10 office.bat"

if (Test-Path $ActivationScript) {

Start-Process $ActivationScript -Wait

}

}
Write-Host ""

Write-Host "---------------------------------------------------------------------------"

Write-Host ""

Read-Host "Windows check completed press ENTER to continue"

# ================================
# RAM CHECK
# ================================

Write-Host "Checking RAM configuration..." -ForegroundColor Cyan

$RAMModules = Get-CimInstance Win32_PhysicalMemory

$TotalRAMGB = [math]::Round(($RAMModules | Measure-Object Capacity -Sum).Sum / 1GB)
$DIMMs = $RAMModules.Count

# Get individual stick sizes
$StickSizes = $RAMModules | ForEach-Object {
    [math]::Round($_.Capacity / 1GB)
}

Write-Host "Total Installed RAM : $TotalRAMGB GB"
Write-Host "Number of DIMMs     : $DIMMs"
Write-Host "Stick Sizes         : $($StickSizes -join ' GB, ') GB"
Write-Host ""

# RAM LOGIC

if ($TotalRAMGB -gt 16) {

    Write-Host "RAM is sufficient. No upgrade required." -ForegroundColor Green

}
elseif ($TotalRAMGB -eq 16) {

    Write-Host "16GB RAM detected. No upgrade required." -ForegroundColor Green

}
elseif ($TotalRAMGB -eq 8) {

    if ($DIMMs -eq 2 -and ($StickSizes -contains 4)) {

        Write-Host "2x4GB RAM detected." -ForegroundColor Yellow
        Write-Host "Recommendation: Replace with 2x8GB RAM (total 16GB)." -ForegroundColor Red

    }
    elseif ($DIMMs -eq 1 -and ($StickSizes -contains 8)) {

        Write-Host "1x8GB RAM detected." -ForegroundColor Yellow
        Write-Host "Recommendation: Add 1x8GB RAM (to reach 16GB)." -ForegroundColor Red

    }
    else {

        Write-Host "8GB RAM detected (unknown configuration)." -ForegroundColor Yellow
        Write-Host "Recommendation: Upgrade to at least 16GB RAM." -ForegroundColor Red

    }

}
else {

    Write-Host "Less than 8GB RAM detected." -ForegroundColor Red
    Write-Host "Recommendation: Upgrade to at least 16GB RAM." -ForegroundColor Red

}

Write-Host ""

Write-Host "---------------------------------------------------------------------------"

Write-Host ""

Read-Host "RAM check completed press ENTER to continue"

# ================================
# DISK HEALTH + DRIVE INFO
# ================================

Write-Host "Checking disk health and drives..." -ForegroundColor Cyan

# Ensure forms available
Add-Type -AssemblyName System.Windows.Forms

$driveget = Get-PhysicalDisk -ErrorAction SilentlyContinue

if ($driveget) {

    $hdd = $driveget | Select-Object `
        @{n="Name";e={$_.FriendlyName}},
        @{
            n="Size"
            e={
                if ($_.Size -ge 1TB) {
                    "{0:N1} TB" -f ($_.Size / 1TB)
                } else {
                    "{0:N1} GB" -f ($_.Size / 1GB)
                }
            }
        },
        @{n="Firmware"; e={$_.FirmwareVersion}},
        @{n="Type"; e={$_.MediaType}},
        @{n="BusType"; e={$_.BusType}},
        @{n="Status"; e={$_.OperationalStatus}},
        @{n="Health"; e={$_.HealthStatus}},
        @{n="SerialNumber"; e={$_.SerialNumber}},
        Model |
    Where-Object { $_.BusType -ne "USB" } |
    Sort-Object -Descending Type

    $hhdc = ($hdd | Measure-Object).Count

    Write-Host "# Drives detected: $hhdc #" -ForegroundColor Magenta
    $hdd | Format-Table -AutoSize | Out-String | Write-Host -ForegroundColor Green

} else {
    Write-Host "Get-PhysicalDisk not supported on this system." -ForegroundColor Red
}


# ================================
# PARTITIONS
# ================================

$volumeget = Get-Volume -ErrorAction SilentlyContinue | Where-Object DriveType -notin ('Removable','CD-ROM')

if ($volumeget) {
    $v = $volumeget | Sort-Object DriveLetter
    $vc = $v.Count

    Write-Host "# Partitions: $vc #" -ForegroundColor Magenta
    $v | Format-Table DriveLetter, FileSystemLabel, FileSystem, SizeRemaining, Size, HealthStatus -AutoSize |
        Out-String | Write-Host -ForegroundColor Green
} else {
    Write-Host "Volume information unavailable." -ForegroundColor Red
}

# ================================
# SYSTEM DRIVE HEALTH CHECK
# ================================

$SystemDriveLetter = $env:SystemDrive.Replace(":","")
$SystemDriveStatus = Get-Volume -ErrorAction SilentlyContinue | Where-Object DriveLetter -eq $SystemDriveLetter

if ($SystemDriveStatus -and $SystemDriveStatus.HealthStatus -ne "Healthy") {

    Write-Host "WARNING: System Drive Health Issue Detected!" -ForegroundColor Red

    $MessageBody = @"
Volume Health Warning

System drive has reported a health issue.
Disk check is required.

This will require a reboot and may take time.
Proceed now?
"@

    $Result = [System.Windows.Forms.MessageBox]::Show(
        $MessageBody,
        "System Drive Maintenance",
        [System.Windows.Forms.MessageBoxButtons]::YesNo,
        [System.Windows.Forms.MessageBoxIcon]::Warning
    )

    if ($Result -eq "Yes") {

        Write-Host "Scheduling CHKDSK..." -ForegroundColor Yellow

        cmd /c "echo Y|chkdsk $env:SystemDrive /f /r"

        $Restart = [System.Windows.Forms.MessageBox]::Show(
            "Restart computer now?",
            "Restart Required",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )

        if ($Restart -eq "Yes") {

            Write-Host "Logging off other users..." -ForegroundColor Yellow

            $sessions = quser 2>$null

            if ($sessions) {
                $sessions | Select-Object -Skip 1 | ForEach-Object {
                    $parts = $_ -split '\s+'
                    if ($parts.Count -ge 3) {
                        $id = $parts[2]
                        if ($id -match '^\d+$') {
                            logoff $id
                        }
                    }
                }
            }

            shutdown -r -t 5
        }
    }
}

Write-Host ""


# ================================
# DISK SPACE CHECK + CLEANUP
# ================================

Write-Host "Checking disk space..." -ForegroundColor Cyan

$Drive = Get-PSDrive C
$FreeGB = [math]::Round($Drive.Free / 1GB,2)

Write-Host "Sufficient Free Space: $FreeGB GB, no cleanup required." -ForegroundColor Cyan

if ($FreeGB -lt 25) {

Write-Host "Not enough space. Running Disk Cleanup..." -ForegroundColor Yellow

Start-Process cleanmgr.exe "/sageset:1" -Wait
Start-Process cleanmgr.exe "/sagerun:1" -Wait

$Drive = Get-PSDrive C
$FreeGB = [math]::Round($Drive.Free / 1GB,2)

Write-Host "Free Space After Cleanup: $FreeGB GB"

}

Write-Host ""

Write-Host "---------------------------------------------------------------------------"

Write-Host ""

Read-Host "Disk check completed press ENTER to continue"

# ================================
# TPM CHECK
# ================================

Write-Host "Checking TPM..." -ForegroundColor Cyan

try {

$tpm = Get-Tpm

if ($tpm.TpmPresent) {

Write-Host "TPM detected." -ForegroundColor Green

}
else {

Write-Host "TPM NOT detected." -ForegroundColor Red

}

}
catch {

Write-Host "TPM check unavailable." -ForegroundColor Yellow

}

Write-Host ""

# ================================
# SECURE BOOT CHECK
# ================================

Write-Host "Checking Secure Boot..." -ForegroundColor Cyan

try {

if (Confirm-SecureBootUEFI) {

Write-Host "Secure Boot enabled." -ForegroundColor Green

}
else {

Write-Host "Secure Boot disabled." -ForegroundColor Red

}

}
catch {

Write-Host "Legacy BIOS detected." -ForegroundColor Yellow

}

Write-Host ""

# ================================
# Windows Upgrade Cache Cleanup (robust)
# ================================

# Use single quotes so $WINDOWS is not expanded
$WindowsBT = 'C:\$WINDOWS.~BT'

Write-Host "Checking Windows upgrade residue..." -ForegroundColor Cyan

function Remove-WindowsBT {
    param([string]$Path)

    if (!(Test-Path $Path)) {
        Write-Host "No previous upgrade folder detected." -ForegroundColor Green
        return
    }

    Write-Host "Taking ownership and removing hidden/system attributes..." -ForegroundColor Yellow
    try {
        # Take ownership
        takeown /F $Path /R /D Y | Out-Null
        icacls $Path /grant "$($env:USERNAME):(F)" /T | Out-Null

        # Remove hidden/system attributes recursively
        Get-ChildItem -Path $Path -Recurse -Force | ForEach-Object {
            $_.Attributes = 'Normal'
        }
    }
    catch {
        Write-Host "Ownership/attribute removal failed: $_" -ForegroundColor Red
    }

    # Attempt deletion up to 3 times
    $maxAttempts = 3
    for ($i=1; $i -le $maxAttempts; $i++) {
        try {
            Remove-Item $Path -Recurse -Force -ErrorAction Stop
            Write-Host "Cleanup succeeded on attempt $i." -ForegroundColor Green
            break
        }
        catch {
            Write-Host "Attempt $i failed: $_" -ForegroundColor Yellow
            Start-Sleep 2
        }
    }

    # Final check
    if (Test-Path $Path) {
        Write-Host "$Path still exists after multiple attempts. Renaming and deleting..." -ForegroundColor Yellow
        try {
            $NewPath = "C:\winbt"
            Rename-Item -Path $Path -NewName $NewPath -Force
            Remove-Item $NewPath -Recurse -Force
            Write-Host "Folder renamed and deleted successfully." -ForegroundColor Green
        }
        catch {
            Write-Host "Final removal failed. Manual cleanup may be required." -ForegroundColor Red
        }
    }
    else {
        Write-Host "Windows upgrade folder removed successfully." -ForegroundColor Green
    }
}

# Run the function
Remove-WindowsBT -Path $WindowsBT
Write-Host ""

# ================================
# NETWORK CHECK
# ================================

Write-Host "Checking network connection..." -ForegroundColor Cyan

# Get active physical adapters
$adapters = Get-NetAdapter -Physical | Where-Object { $_.Status -eq "Up" }

if (-not $adapters) {
    Write-Host "No active network connection detected." -ForegroundColor Red
}
else {

    $isEthernet = $false
    $isWiFi = $false

    foreach ($adapter in $adapters) {
        if ($adapter.InterfaceDescription -match "Wi-Fi|Wireless") {
            $isWiFi = $true
        }
        elseif ($adapter.InterfaceDescription -match "Ethernet") {
            $isEthernet = $true
        }
    }

    if ($isEthernet) {
        Write-Host "Connected via Ethernet." -ForegroundColor Green
    }
    elseif ($isWiFi) {
        Write-Host "Connected via Wi-Fi." -ForegroundColor Yellow
        Write-Host "This device must be connected via Ethernet." -ForegroundColor Red
    }
    else {
        Write-Host "Connected, but unable to determine connection type." -ForegroundColor Yellow
    }
}

Write-Host ""

# ===============================
# MANUAL PROXY CHECK
# ===============================

Write-Host "Checking Manual Proxy Settings..." -ForegroundColor Cyan

$ProxySettings = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -ErrorAction SilentlyContinue

if ($null -ne $ProxySettings) {

    if ($ProxySettings.ProxyEnable -eq 1) {

        Write-Host "Manual Proxy is ENABLED." -ForegroundColor Red

        if ($ProxySettings.ProxyServer) {
            Write-Host "Proxy Server: $($ProxySettings.ProxyServer)" -ForegroundColor Red
        }

    }
    else {

        Write-Host "Manual Proxy is DISABLED." -ForegroundColor Green

    }

}
else {

    Write-Host "Unable to read proxy settings." -ForegroundColor Red

}

Write-Host ""

# ================================
# COPY TEMP FOLDER
# ================================

$TempSource = Join-Path $ScriptRoot "W11\Temp"

Write-Host "Refreshing C:\Temp"

robocopy $TempSource "C:\Temp" /MIR /R:1 /W:1

Write-Host "---------------------------------------------------------------------------"

Write-Host ""

Read-Host "System checks completed press ENTER to continue"


# ================================
# SCRIPT RUNNER FUNCTION
# ================================

function Run-And-Wait {

param([string]$Script)

if (Test-Path $Script) {

Write-Host "Running $Script" -ForegroundColor Yellow

Start-Process $Script -Wait

Read-Host "Press ENTER to continue"

}
else {

Write-Host "Script missing: $Script" -ForegroundColor Yellow

}

}

Run-And-Wait "$ScriptRoot\Blocked apps checker\run_check.bat"
Run-And-Wait "$ScriptRoot\Profile checker\run_profile_check.bat"
Run-And-Wait "$ScriptRoot\Java Removal Tool & Checker\Run-JavaCheck.bat"
Run-And-Wait "C:\Temp\W11 update fix commands.bat"

Write-Host "---------------------------------------------------------------------------"


# ================================
# NETACQUIRE CHECK
# ================================

# Ensure ScriptRoot is defined
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "Checking NetAcquire..." -ForegroundColor Cyan

$NetAcquire = Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* ,
HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* -ErrorAction SilentlyContinue |
Where-Object { $_.DisplayName -like "*NetAcquire*" }

if ($NetAcquire) {

    Write-Host "NetAcquire installed." -ForegroundColor Green

    if (!(Test-Path "C:\Win11Scripts\NetAcquire")) {

        Write-Host "C:\Win11Scripts\NetAcquire folder missing. Applying NetAcquire Fix..." -ForegroundColor Yellow

        $FixSource = Join-Path $ScriptRoot "NetAcquire Fix\Temp"
        $FixDest = "C:\Temp"

        if (Test-Path $FixSource) {

            Write-Host "Copying NetAcquire fix files to C:\Temp..." -ForegroundColor Cyan
            robocopy $FixSource $FixDest /E /R:1 /W:1 | Out-Null

        }
        else {

            Write-Host "NetAcquire fix source folder missing!" -ForegroundColor Red

        }

        # Run BAT directly from source (Option 1)
        $TaskScript = Join-Path $ScriptRoot "NetAcquire Fix\Run-CreateUKRegionTask.bat"

        if (Test-Path $TaskScript) {

            Write-Host "Running scheduled task creation script from source..." -ForegroundColor Cyan

            try {
                Start-Process $TaskScript -WorkingDirectory (Split-Path $TaskScript) -Wait
            }
            catch {
                Write-Host "Failed to run UK region task creation script." -ForegroundColor Yellow
            }

        }
        else {

            Write-Host "Run-CreateUKRegionTask.bat not found in NetAcquire Fix folder!" -ForegroundColor Red

        }

        Start-Sleep 3

        Write-Host "Checking scheduled task..." -ForegroundColor Cyan

        $Task = Get-ScheduledTask -TaskName "Set-UKRegionalSettings" -ErrorAction SilentlyContinue

        if ($Task) {

            Write-Host "Scheduled task 'Set-UKRegionalSettings' created successfully." -ForegroundColor Green

        }
        else {

            Write-Host "Scheduled task 'Set-UKRegionalSettings' NOT found." -ForegroundColor Red

        }

    }
    else {

        Write-Host "C:\Win11Scripts\NetAcquire already exists. NetAcquire fix not required." -ForegroundColor Green

    }

}
else {

    Write-Host "NetAcquire not installed." -ForegroundColor Yellow

}

Write-Host ""
Write-Host "---------------------------------------------------------------------------"
Write-Host ""

Read-Host "NetAcquire check completed press ENTER to continue"


# ================================
# LENOVO SYSTEM UPDATE CHECK
# ================================

Write-Host "Checking Lenovo System Update..."

$InstalledApp = Get-ItemProperty `
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" ,
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" `
    -ErrorAction SilentlyContinue |
Where-Object {
    $_.DisplayName -like "*Lenovo System Update*" -or
    $_.DisplayName -like "*System Update*"
} | Select-Object -First 1

$Installer = "$PSScriptRoot\Software\system_update_5.08.03.59.exe"
$Executable = "C:\Program Files (x86)\Lenovo\System Update\tvsu.exe"

if (-not $InstalledApp) {

    Write-Host "Lenovo System Update not found. Installing..."

    if (Test-Path $Installer) {

        Start-Process -FilePath $Installer -ArgumentList "/S" -Wait
        Write-Host "Installation completed."

    }
    else {

        Write-Host "Installer not found at $Installer"
        exit 1

    }

}

else {

    Write-Host "System Update already installed: $($InstalledApp.DisplayName)"

}

# Run System Update
if (Test-Path $Executable) {

    Write-Host "Launching Lenovo System Update..."
    Start-Process $Executable

}
else {

    Write-Host "System Update executable not found at $Executable"

}

Write-Host ""

# ================================
# DIRECTX + WDDM CHECK
# ================================

if ($OS.Caption -match "Windows 10") {

    Write-Host "Checking DirectX and WDDM requirements..." -ForegroundColor Cyan

    function Test-DirectXWDDM {

        $dxdiagFile = "$env:TEMP\dxdiag.xml"

        try {
            Start-Process -FilePath "dxdiag.exe" -ArgumentList "/x $dxdiagFile" -Wait -WindowStyle Hidden -ErrorAction Stop
        }
        catch {
            Write-Host "Failed to run dxdiag." -ForegroundColor Red
            return
        }

        if (-not (Test-Path $dxdiagFile)) {
            Write-Host "dxdiag output file not found." -ForegroundColor Red
            return
        }

        try {
            [xml]$dx = Get-Content $dxdiagFile -ErrorAction Stop
        }
        catch {
            Write-Host "Failed to parse dxdiag output." -ForegroundColor Red
            return
        }

        $devices = $dx.DxDiag.DisplayDevices.DisplayDevice

        if (-not $devices) {
            Write-Host "No display devices found." -ForegroundColor Red
            return
        }

        foreach ($gpu in $devices) {

            $featureLevels = $gpu.FeatureLevels
            $driverModel = $gpu.DriverModel

            Write-Host "GPU: $($gpu.CardName)" -ForegroundColor Gray
            Write-Host "DirectX Feature Levels: $featureLevels" -ForegroundColor Gray
            Write-Host "Driver Model (WDDM): $driverModel" -ForegroundColor Gray

            $dx12 = $featureLevels -match "12"

            $wddmVersion = ($driverModel -replace "[^\d\.]", "")
            $wddmOK = $false

            if ($wddmVersion) {
                try {
                    $wddmOK = [version]$wddmVersion -ge [version]"2.0"
                }
                catch {
                    $wddmOK = $false
                }
            }

            if ($dx12 -and $wddmOK) {
                Write-Host "Result: Meets Windows 11 graphics requirements." -ForegroundColor Green
            }
            else {
                Write-Host "Result: Does NOT meet Windows 11 graphics requirements." -ForegroundColor Red

                if (-not $dx12) {
                    Write-Host " - Missing DirectX 12 support." -ForegroundColor Red
                }

                if (-not $wddmOK) {
                    Write-Host " - WDDM version below 2.0 (Detected: $driverModel)" -ForegroundColor Red
                }
            }

            Write-Host ""
        }

        # Cleanup
        Remove-Item $dxdiagFile -ErrorAction SilentlyContinue
    }

    Test-DirectXWDDM
}

Write-Host ""


###########################################################################################

# ================================
# FINAL UPDATE CHECKS
# ================================

Write-Host "Preparing Windows Update environment..." -ForegroundColor Cyan

function Test-And-Report {
    param(
        [string]$Name,
        [scriptblock]$Test,
        [scriptblock]$Fix
    )

    Write-Host "`n[CHECK] $Name" -ForegroundColor Yellow

    try {
        $result = & $Test

        if ($result -eq $true) {
            Write-Host "[OK] $Name" -ForegroundColor Green
        }

        elseif ($result -eq $false) {
            Write-Host "[ISSUE] $Name" -ForegroundColor Red

            if ($Fix) {
                Write-Host " -> Attempting fix..." -ForegroundColor DarkYellow
                try {
                    & $Fix
                    Write-Host " -> Fix applied" -ForegroundColor Green
                }
                catch {
                    Write-Host " -> Fix failed: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }

        else {
            Write-Host "[INFO] $result" -ForegroundColor Cyan
        }
    }
    catch {
        Write-Host "[ERROR] $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Services that must NOT be disabled
$servicesManual = @{
"BITS"                       = "BITS"
"Windows Installer"          = "msiserver"
"Windows Update"             = "wuauserv"
"Windows Update Medic"       = "WaaSMedicSvc"
"Update Orchestrator"        = "UsoSvc"
"Windows Modules Installer"  = "TrustedInstaller"
}

$servicesAutomatic = @{
"Cryptographic Services"     = "CryptSvc"
}

foreach ($svc in $servicesManual.GetEnumerator()) {

Test-And-Report -Name $svc.Key -Test {

$s = Get-Service $svc.Value -ErrorAction SilentlyContinue
if (!$s) { return "Service not found" }

return ($s.StartType -ne "Disabled")

} -Fix {

Set-Service $svc.Value -StartupType Manual

}

}

foreach ($svc in $servicesAutomatic.GetEnumerator()) {

Test-And-Report -Name $svc.Key -Test {

$s = Get-Service $svc.Value -ErrorAction SilentlyContinue
if (!$s) { return "Service not found" }

return ($s.StartType -ne "Disabled")

} -Fix {

Set-Service $svc.Value -StartupType Automatic
Start-Service $svc.Value -ErrorAction SilentlyContinue

}

}

# Windows Update policy cleanup
$regPathU = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"

Test-And-Report -Name "Windows Update Policies" -Test {

if (Test-Path $regPathU) {

$values = Get-ItemProperty $regPathU

if ($values.DisableWindowsUpdateAccess -eq 1 -or
    $values.DoNotConnectToWindowsUpdateInternetLocations -eq 1 -or
    $values.SetDisableUXWUAccess -eq 1 -or
    $values.WUServer) {

    return $false
}

}

return $true

} -Fix {

Remove-Item $regPathU -Recurse -Force -ErrorAction SilentlyContinue

}

# Fast Startup disable
$regPathFS = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"

Test-And-Report -Name "Disable Fast Startup" -Test {

if (Test-Path $regPathFS) {

$values = Get-ItemProperty $regPathFS

if ($values.HiberbootEnabled -eq 1 -or $values.HiberbootEnabled -eq $null) {

return $false

}

}

return $true

} -Fix {

New-ItemProperty -Path $regPathFS -Name "HiberbootEnabled" -Value 0 -PropertyType DWord -Force

}

# Remove Windows Update blocks from hosts
$MSupdatesites = @("windowsupdate","update.microsoft")

foreach ($sb in $MSupdatesites) {

Test-And-Report -Name "Hosts file entries - $sb" -Test {

$hosts = Get-Content "$env:SystemRoot\System32\drivers\etc\hosts"
return -not ($hosts -match "$sb")

} -Fix {

$timestampF = Get-TimestampF

Copy-Item "$env:SystemRoot\System32\drivers\etc\hosts" `
"$env:SystemRoot\System32\drivers\etc\hosts.$timestampF.bak"

(Get-Content "$env:SystemRoot\System32\drivers\etc\hosts") |
Where-Object {$_ -notmatch "$sb"} |
Set-Content "$env:SystemRoot\System32\drivers\etc\hosts"

}

}

Write-Host "`nCleaning Windows Update cache..." -ForegroundColor Yellow

Remove-Item "$env:SystemRoot\SoftwareDistribution" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:SystemRoot\System32\catroot2" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$env:SystemRoot\Temp" -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`n=== Windows Update environment prepared ===" -ForegroundColor Cyan

# ================================
# WINDOWS UPDATE + TEMP CLEANUP
# ================================

Write-Host ""
Write-Host "Cleaning old update and temporary files..." -ForegroundColor Yellow
Write-Host "This may take some time but helps prevent Windows 11 upgrade failures." -ForegroundColor Yellow
Write-Host ""

function Get-FolderStats($Path) {
    $data = Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue | 
            Measure-Object -Property Length -Sum

    $sizeGB = [math]::Round(($data.Sum / 1GB), 2)
    $count = $data.Count

    return @{
        Size = "$sizeGB GB"
        Count = $count
    }
}

# Paths
$SDPath = "$env:SystemRoot\SoftwareDistribution"
$CatrootPath = "$env:SystemRoot\System32\catroot2"
$TempPath = "$env:SystemRoot\Temp"

# Get sizes BEFORE cleanup
$sd = Get-FolderStats $SDPath
$cr = Get-FolderStats $CatrootPath
$tmp = Get-FolderStats $TempPath

Write-Host "SoftwareDistribution size : $($sd.Size)" -ForegroundColor Gray
Write-Host "SoftwareDistribution items: $($sd.Count)" -ForegroundColor Gray
Write-Host ""

Write-Host "Catroot2 size             : $($cr.Size)" -ForegroundColor Gray
Write-Host "Catroot2 items            : $($cr.Count)" -ForegroundColor Gray
Write-Host ""

Write-Host "Temp size                 : $($tmp.Size)" -ForegroundColor Gray
Write-Host "Temp items                : $($tmp.Count)" -ForegroundColor Gray
Write-Host ""

# Stop services safely
Write-Host "Stopping Windows Update services..." -ForegroundColor Cyan

$services = "wuauserv","bits","cryptsvc"

foreach ($svc in $services) {
    Get-Service $svc -ErrorAction SilentlyContinue | Where-Object {$_.Status -ne "Stopped"} | Stop-Service -Force -ErrorAction SilentlyContinue
}

# Cleanup
Write-Host "Cleaning folders..." -ForegroundColor Cyan

try {
    Remove-Item "$SDPath\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$CatrootPath\*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$TempPath\*" -Recurse -Force -ErrorAction SilentlyContinue
}
catch {
    Write-Host "Error during cleanup: $_" -ForegroundColor Red
}

# Restart services
Write-Host "Restarting services..." -ForegroundColor Cyan

foreach ($svc in $services) {
    Get-Service $svc -ErrorAction SilentlyContinue | Start-Service -ErrorAction SilentlyContinue
}

Write-Host ""
Write-Host "Cleanup completed successfully." -ForegroundColor Green
Write-Host ""

# ================================
# COPY TEMP FOLDER AGAIN
# ================================

$TempSource = Join-Path $ScriptRoot "W11\Temp"

Write-Host "Refreshing C:\Temp"

robocopy $TempSource "C:\Temp" /MIR /R:1 /W:1

Write-Host ""

Read-Host "System checks completed press ENTER to continue"


# ================================
# UPGRADE OPTION
# ================================

# -------------------------------
# Choose Upgrade Method
# -------------------------------

Write-Host "Select Upgrade Method:" -ForegroundColor Cyan
Write-Host "1 - Silent Upgrade (Win11Upgrade folder)"
Write-Host "2 - Windows11InstallationAssistant"
Write-Host ""

$Choice = Read-Host "Enter 1 or 2"

# -------------------------------
# Copy TEMP folder
# -------------------------------

$W11Path = Join-Path $ScriptRoot "W11"
$TempSource = Join-Path $W11Path "Temp"
$TempDest = "C:\Temp"

if (!(Test-Path $TempDest)) {

Write-Host "Copying Temp folder..." -ForegroundColor Green
robocopy $TempSource $TempDest /E /R:1 /W:1

if ($LASTEXITCODE -gt 3) {
throw "Failed copying Temp folder."
}

}
else {

Write-Host "C:\Temp already exists. Skipping copy." -ForegroundColor Yellow

}

Write-Host ""

# =====================================
# OPTION 1 — Silent Upgrade
# =====================================

if ($Choice -eq "1") {

Write-Host "Preparing Silent Upgrade..." -ForegroundColor Cyan

$UpgradeSource = Join-Path $W11Path "Win11Upgrade"
$UpgradeDest = "C:\Win11Upgrade"

if (!(Test-Path $UpgradeDest)) {

Write-Host "Copying Win11Upgrade folder..." -ForegroundColor Green

robocopy $UpgradeSource $UpgradeDest /E /R:1 /W:1

if ($LASTEXITCODE -gt 3) {
throw "Failed copying Win11Upgrade folder."
}

}
else {

Write-Host "C:\Win11Upgrade already exists. Skipping copy." -ForegroundColor Yellow

}

$SetupPath = "C:\Temp\upgrade.bat"

if (!(Test-Path $SetupPath)) {
throw "Upgrade script not found in Temp folder!"
}

Write-Host "Starting silent Windows 11 upgrade..." -ForegroundColor Green

Write-Host "Running upgrade.bat..." -ForegroundColor Cyan
Start-Process $UpgradeBat -WorkingDirectory "C:\Temp" -Wait

}

# =====================================
# OPTION 2 — Installation Assistant
# =====================================

elseif ($Choice -eq "2") {

    # Get script directory safely
    if ($PSScriptRoot) {
        $CurrentDir = $PSScriptRoot
    }
    elseif ($MyInvocation.MyCommand.Path) {
        $CurrentDir = Split-Path -Parent $MyInvocation.MyCommand.Path
    }
    else {
        $CurrentDir = Get-Location
    }

    # Now pointing to W11 subfolder
    $SourceAssistant = Join-Path $CurrentDir "W11\Windows11InstallationAssistant.exe"
    $DestAssistant = "C:\Windows11InstallationAssistant.exe"
    $UpgradeBat = "C:\Temp\upgrade.bat"

    # Ensure C:\Temp exists
    if (!(Test-Path "C:\Temp")) { 
        New-Item -Path "C:\Temp" -ItemType Directory -Force | Out-Null 
    }

    # Copy the assistant
    if (Test-Path $SourceAssistant) {
        Write-Host "Copying Windows11InstallationAssistant.exe to C:\..." -ForegroundColor Cyan
        Copy-Item $SourceAssistant $DestAssistant -Force
    }
    else {
        Write-Host "Installer not found at: $SourceAssistant" -ForegroundColor Red
    }

    # Run upgrade batch
    if (Test-Path $UpgradeBat) {
        Write-Host "Running upgrade.bat..." -ForegroundColor Cyan
        Start-Process $UpgradeBat -WorkingDirectory "C:\Temp" -Wait
    }
    else {
        Write-Host "upgrade.bat not found in C:\Temp!" -ForegroundColor Red
    }

}

Write-Host ""
Write-Host "Upgrade process started successfully." -ForegroundColor Green

Stop-Transcript

Read-Host "Press ENTER to exit"