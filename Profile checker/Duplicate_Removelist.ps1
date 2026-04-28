# ================================
# Self-elevate to Administrator
# ================================
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Start-Process powershell `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -NoExit -File `"$PSCommandPath`"" `
        -Verb RunAs
    exit
}

# ================================
# Logging setup
# ================================
$ScriptDir = Split-Path -Parent $PSCommandPath
$LogFile   = Join-Path $ScriptDir "Duplicate_Profile_Log.log"
$Computer  = $env:COMPUTERNAME
$TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

# ================================
# Begin profile scan
# ================================
Write-Host "`nScanning profile registry keys (including .bak)..." -ForegroundColor Cyan

$profileKeys = Get-ChildItem "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList"

$profiles = foreach ($key in $profileKeys) {

    $props = Get-ItemProperty $key.PSPath -ErrorAction SilentlyContinue
    $path  = $props.ProfileImagePath
    $sid   = $key.PSChildName
    $isBak = $sid -match '\.bak$'

    if ($path) {
        $folder = Split-Path $path -Leaf

        # Detect NTUSER owner SID if available
        $ownerSid = $null
        $ntuser = Join-Path $path "NTUSER.DAT"
        if (Test-Path $ntuser) {
            try {
                $owner = (Get-Acl $ntuser).Owner
                $ownerSid = (New-Object System.Security.Principal.NTAccount($owner)).
                    Translate([System.Security.Principal.SecurityIdentifier]).Value
            } catch {}
        }

        [PSCustomObject]@{
            SID          = $sid
            IsBak        = $isBak
            Folder       = $folder
            Path         = $path
            Exists       = Test-Path $path
            NtUserOwner  = $ownerSid
        }
    }
}

Write-Host "`n=== FULL PROFILE LIST (including .bak) ===`n" -ForegroundColor Yellow
$profiles | Sort-Object Folder | Format-Table SID, IsBak, Folder, Path, Exists

# ================================
# Detect duplicates
# ================================
$dupeGroups = $profiles | Group-Object Folder | Where-Object { $_.Count -gt 1 }
$ProfilesToDelete = @()

Write-Host "`n=== DUPLICATES BY FOLDER NAME ===`n" -ForegroundColor Red

foreach ($g in $dupeGroups) {

    Write-Host "Folder: $($g.Name)" -ForegroundColor Cyan
    $g.Group | Format-Table SID, IsBak, Path, NtUserOwner

    # Identify correct SID (matches NTUSER owner)
    $correct = $g.Group | Where-Object { $_.SID -eq $_.NtUserOwner }

    if ($correct) {
        Write-Host "-> Correct key to KEEP:" -ForegroundColor Green
        $correct | Format-Table SID, Path
    } else {
        Write-Host "-> No NTUSER owner match - check timestamps to decide." -ForegroundColor Yellow
    }

    Write-Host "-> Keys to REMOVE:" -ForegroundColor Red
    $toRemove = $g.Group | Where-Object { $_ -notin $correct }
    $toRemove | Format-Table SID, Path

    $ProfilesToDelete += $toRemove

    Write-Host "-----------------------------------`n"
}

# ================================
# Final logging
# ================================
$TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

if ($ProfilesToDelete.Count -gt 0) {
    "[$TimeStamp] Computer: $Computer - DUPLICATE PROFILES FOUND: $($ProfilesToDelete.Count)" |
        Out-File -FilePath $LogFile -Append -Encoding UTF8
} else {
    "[$TimeStamp] Computer: $Computer - NO DUPLICATE PROFILES FOUND" |
        Out-File -FilePath $LogFile -Append -Encoding UTF8
}

Write-Host "`nScan complete. Log written to:" -ForegroundColor Cyan
Write-Host $LogFile -ForegroundColor White

# Keep PowerShell window open
Write-Host "Press Enter to exit..."
[System.Console]::ReadLine() | Out-Null
exit
