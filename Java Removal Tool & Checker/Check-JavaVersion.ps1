# Get script directory
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

# Create Logs folder if it doesn't exist
$logFolder = Join-Path $scriptPath "Logs"
if (!(Test-Path $logFolder)) {
    New-Item -ItemType Directory -Path $logFolder | Out-Null
}

# Build log file name: ComputerName_yyyyMMdd_HHmm.log
$computerName = $env:COMPUTERNAME
$dateTime = Get-Date -Format "yyyy-MM-dd_HH-mm"
$logFile = Join-Path $logFolder "${computerName}_${dateTime}.log"

Start-Transcript -Path $logFile -Append

# Java Version Check Script

try {
    $javaOutput = & java -version 2>&1
} catch {
    Write-Host "Java is not installed or not in PATH." -ForegroundColor Yellow
    exit
}

# Display full Java output
Write-Host "Detected Java installation:" -ForegroundColor Cyan
$javaOutput | ForEach-Object { Write-Host $_ }

$versionLine = $javaOutput | Select-Object -First 1

if ($versionLine -match '"([\d\._]+)') {
    $versionString = $matches[1]
    Write-Host "Parsed Java version: $versionString" -ForegroundColor Cyan
} else {
    Write-Host "Unable to determine Java version." -ForegroundColor Yellow
    exit
}

$javaHigherThan202 = $false

# Java 8 check
if ($versionString -match '^1\.8\.0_(\d+)') {
    $updateNumber = [int]$matches[1]
    if ($updateNumber -gt 202) {
        $javaHigherThan202 = $true
    }
}
# Java 9+
elseif ($versionString -match '^(\d+)') {
    $majorVersion = [int]$matches[1]
    if ($majorVersion -gt 8) {
        $javaHigherThan202 = $true
    }
}

if (-not $javaHigherThan202) {
    Write-Host "Java version $versionString is update 202 or lower. No action required." -ForegroundColor Green
    Write-Host "Script completed." -ForegroundColor Gray
    exit
}

Write-Host "Java version $versionString is higher than update 202." -ForegroundColor Red

# Check if McKesson / NIMIS software exists
$nimisInstalled = $false

$installedPrograms = Get-ItemProperty `
HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*,
HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\* `
-ErrorAction SilentlyContinue

foreach ($program in $installedPrograms) {
    if ($program.DisplayName -and $program.DisplayName -match "McKesson|NIMIS") {
        $nimisInstalled = $true
        break
    }
}

# Get script directory
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

if ($nimisInstalled) {

    Write-Host "McKesson/NIMIS detected." -ForegroundColor Cyan

    $source = Join-Path $scriptDir "NIMIS Machine\NMC"
    $destination = "C:\NMC"

    Write-Host "Copying NMC tool to C:\..." -ForegroundColor Yellow

    try {
        if (-not (Test-Path $destination)) {
            New-Item -Path $destination -ItemType Directory | Out-Null
        }

        Copy-Item -Path "$source\*" -Destination $destination -Recurse -Force
        Write-Host "Copy completed successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "File copy failed: $_" -ForegroundColor Red
        exit
    }

    $batPath = "C:\NMC\NMC.bat"

    if (-not (Test-Path $batPath)) {
        Write-Host "BAT file not found at $batPath" -ForegroundColor Red
        exit
    }

    Write-Host "Running NMC tool..." -ForegroundColor Cyan
    Start-Process $batPath -Verb RunAs -Wait

} else {

    Write-Host "No McKesson software detected." -ForegroundColor Cyan

    $source = Join-Path $scriptDir "NON-NIMIS Machine\Java8202Replace"
    $destination = "C:\Java8202Replace"

    Write-Host "Copying Java replacement tool to C:\..." -ForegroundColor Yellow

    try {
        if (-not (Test-Path $destination)) {
            New-Item -Path $destination -ItemType Directory | Out-Null
        }

        Copy-Item -Path "$source\*" -Destination $destination -Recurse -Force
        Write-Host "Copy completed successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "File copy failed: $_" -ForegroundColor Red
        exit
    }

    $batPath = "C:\Java8202Replace\Java8202\ReplaceW8202install.bat"

    if (-not (Test-Path $batPath)) {
        Write-Host "BAT file not found at $batPath" -ForegroundColor Red
        exit
    }

    Write-Host "Running Java replacement tool..." -ForegroundColor Cyan
    Start-Process $batPath -Verb RunAs -Wait
}

Write-Host "Script completed." -ForegroundColor Gray

Stop-Transcript