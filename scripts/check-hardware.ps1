# Queries connected PM3 for hw version, hw status, hw ping, hw tune.

[CmdletBinding()]
param(
    [string]$Distribution = "Ubuntu"
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$shScript = Join-Path $scriptDir "check-hardware.sh"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Proxmark3 Easy - Hardware Tests" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$pm3HwId = "9ac4:4b8f"
$isAttached = (& usbipd list) | Where-Object { ($_ -match $pm3HwId) -and ($_ -match "Attached") }

if (-not $isAttached) {
    Write-Host "[*] Device is not attached to WSL. Attaching..." -ForegroundColor Yellow
    Start-Process -FilePath "usbipd.exe" -ArgumentList "attach --auto-attach --hardware-id $pm3HwId --wsl $Distribution" -WindowStyle Hidden
    Start-Sleep -Seconds 2
    & wsl.exe -d $Distribution -u root bash -c "service udev restart >/dev/null 2>&1; udevadm trigger --action=change >/dev/null 2>&1"
    Start-Sleep -Seconds 1
}

$wslShPath = (& wsl.exe -d $Distribution wslpath -u ($shScript -replace '\\', '/')).Trim()

& wsl.exe -d $Distribution bash $wslShPath
