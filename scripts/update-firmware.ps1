# Pulls latest Iceman fork, compiles PM3 Easy firmware, copies binaries to this repo, and optionally flashes.

[CmdletBinding()]
param(
    [string]$Distribution = "Ubuntu"
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Proxmark3 Easy - Update & Rebuild Tool   " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$shScript = Join-Path $scriptDir "update-firmware.sh"

$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $wsl) {
    Write-Host "[!] WSL is not installed or enabled." -ForegroundColor Red
    Read-Host "Press Enter to exit..."
    exit 1
}

# Attach device to WSL if connected so flashing works if requested
$pm3HwId = "9ac4:4b8f"
$currentList = & usbipd list 2>$null
$pm3Entry = $currentList | Where-Object { $_ -match $pm3HwId -or $_ -match "502d:502d" }

if ($pm3Entry) {
    if ($pm3Entry -match "Not shared") {
        try {
            Start-Process -FilePath "usbipd.exe" -ArgumentList "bind --hardware-id $pm3HwId" -Verb RunAs -PassThru -Wait | Out-Null
        } catch {}
    }
    if ($pm3Entry -notmatch "Attached") {
        Start-Process -FilePath "usbipd.exe" -ArgumentList "attach --auto-attach --hardware-id $pm3HwId --wsl $Distribution" -WindowStyle Hidden
        Start-Sleep -Seconds 2
        & wsl.exe -d $Distribution -u root bash -c "service udev restart >/dev/null 2>&1; udevadm trigger --action=change >/dev/null 2>&1"
    }
}

$wslShPath = (& wsl.exe -d $Distribution wslpath -u ($shScript -replace '\\', '/')).Trim()

& wsl.exe -d $Distribution bash $wslShPath

Write-Host ""
Write-Host "Remember to commit and push changes to proxmark3easy-tools if updated!" -ForegroundColor Yellow
