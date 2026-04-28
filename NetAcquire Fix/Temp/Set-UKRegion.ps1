
# Set UK Language and Region
try {
    $langList = New-WinUserLanguageList en-GB
    $langList[0].Handwriting = $false
    $langList[0].InputMethodTips.Clear()
    Set-WinUserLanguageList $langList -Force

    Set-Culture en-GB
    Set-WinSystemLocale en-GB
    Set-TimeZone -Id "GMT Standard Time"
    Set-WinHomeLocation -GeoId 242
    Write-Output "UK settings applied."
} catch {
    Write-Output "Failed to apply UK settings: $_"
}

Add-Content -Path "$env:USERPROFILE\UKRegionLog.txt" -Value "$(Get-Date): Regional settings applied"
