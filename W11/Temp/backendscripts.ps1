# Get Windows version info
$osVersion = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion")

# 24H2 corresponds to build 26100 or higher
if ($osVersion.CurrentBuild -ge 26100) {
    Write-Host "Windows 11 24H2 detected. Continuing script..."
    
       Write-Host "Running actual script now..."

} else {
    Write-Warning "This device is not running Windows 11 24H2. Script aborted."

    exit 
}


# === Setup ===
$osVersion    = (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion")
$TaskName     = "Fix for Excel 2016-Windows 11 issue"
$vbsScript    = "C:\Temp\excel_word_background_memory.vbs"
$regFileNames = @("softwareprotection.reg")
$scriptLogDir = "C:\Temp\script_log"
$logFile      = Join-Path $scriptLogDir "main_script.log"

# Ensure log folder exists
if (-not (Test-Path $scriptLogDir)) {
    New-Item -Path $scriptLogDir -ItemType Directory -Force | Out-Null
}

# Logging function
function Write-Log {
    param (
        [string]$Message,
        [string]$Level = "INFO"
    )

    $Time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
   "$Time [$Level] - $Message" | Out-File -FilePath $logFile -Append -Encoding UTF8
}


# === Remove Widgets ===
try {
    Get-AppxPackage -AllUsers *WebExperience* | Remove-AppxPackage -ErrorAction Stop
    Get-AppxProvisionedPackage -Online | Where-Object PackageName -like "*WebExperience*" |
        Remove-AppxProvisionedPackage -Online -ErrorAction Stop

    Write-Log "Widgets removed successfully"
}
catch {
    Write-Log "Error removing widgets: $_" "ERROR"
}

# === 3. --- Set OS Uninstall Window to 30 days ---
try {
    Start-Process -FilePath "dism.exe" -ArgumentList "/online","/set-OSUninstallWindow","/value:30" -NoNewWindow -Wait
    Write-Log "OS uninstall window set to 30 days."
} catch {
    Write-Log "Error setting OS uninstall window: $_" "WARN"
}

# === 4. --- Import Registry File ---
foreach ($regFile in $regFileNames) {
    $sourcePaths = @("$PSScriptRoot\$regFile", "C:\Temp\$regFile")
    $found = $false
    foreach ($path in $sourcePaths) {
        if (Test-Path $path) {
            Copy-Item -Path $path -Destination "C:\Temp\$regFile" -Force
            Write-Log "Copied $regFile from $path."
            Start-Process -FilePath "reg.exe" -ArgumentList "import `"C:\Temp\$regFile`"" -NoNewWindow -Wait
            Write-Log "Imported registry file $regFile."
            $found = $true
            break
        }
    }
    if (-not $found) {
        Write-Log "Registry file $regFile not found." "WARN"
    }
}

# === 5. --- Create Outlook Shortcut ---
try {
    $possibleDirs = "${env:ProgramFiles}\Microsoft Office","${env:ProgramFiles(x86)}\Microsoft Office"
    $officeVersions = "root\Office16","Office16","Office15","Office21"
    $outlookExe = $null

    foreach ($dir in $possibleDirs) {
        foreach ($ver in $officeVersions) {
            $candidate = Join-Path $dir $ver
            $exePath = Join-Path $candidate "OUTLOOK.EXE"
            if (Test-Path $exePath) {
                $outlookExe = $exePath
                break
            }
        }
        if ($outlookExe) { break }
    }

    if ($outlookExe) {
        $shortcut = "$env:Public\Desktop\Outlook.lnk"
        $WshShell = New-Object -ComObject WScript.Shell
        $sc = $WshShell.CreateShortcut($shortcut)
        $sc.TargetPath = $outlookExe
        $sc.Save()
        Write-Log "Created Outlook shortcut at $shortcut."
    } else {
        Write-Log "Outlook executable not found." "WARN"
    }
} catch {
    Write-Log "Error creating Outlook shortcut: $_" "WARN"
}

# --- 5. StartUp Task creation for fix for Excel 2016 issue  ---

$TaskName = "Fix for Excel 2016-Windows 11 issue"
$ScriptPath = "C:\Temp\excel_word_background_memory.vbs"
$Action = New-ScheduledTaskAction -Execute "wscript.exe" -Argument "`"$ScriptPath`""
$Trigger = New-ScheduledTaskTrigger -AtStartup
$Principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest

try {
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Description "Fix for Excel 2016-Windows 11 issue. Runs Excel 2016 in background. Monitors Excel and Word memory use and quits if hidden and above limit."
    Write-Log "Scheduled task '$TaskName' created successfully."
} catch {
    Write-Warning "Failed to register scheduled task: $_"
    Write-Log "Failed to register scheduled task '$TaskName': $_" "ERROR"
}


# === Define variables ===
$logFolder = "C:\Temp\Cleanup_log"
$cleanupLogFile = Join-Path $logFolder "deletion_log.txt"

# List of files to delete (vbs script removed)
$filesToDelete = @(
    "C:\Temp\backendscripts.ps1",
    "C:\Temp\Softwareprotection.reg"
)

# === Ensure log folder exists ===
if (-not (Test-Path $logFolder)) {
    New-Item -Path $logFolder -ItemType Directory -Force | Out-Null
}

# === Logging function for cleanup ===
function Write-CleanupLog {
    param ([string]$Message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath $cleanupLogFile -Append -Encoding UTF8
}

# === Delete specified files ===
foreach ($file in $filesToDelete) {
    if (Test-Path $file) {
        try {
            attrib -r -h -s $file 2>$null  # Remove attributes if needed
            Remove-Item -Path $file -Force -ErrorAction Stop
            Write-Host "Deleted file: $file"
            Write-CleanupLog "Deleted file: $file"
        } catch {
            Write-Warning "Failed to delete file: $file. Error: $_"
            Write-CleanupLog "ERROR deleting file '$file': $_"
        }
    } else {
        Write-Host "File not found: $file"
        Write-CleanupLog "File not found: $file"
    }
}
