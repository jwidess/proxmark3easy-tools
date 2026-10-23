# Flashes the bundled PM3 firmware images (bootrom.elf and fullimage.elf) to the connected device via WSL2.

[CmdletBinding()]
param(
    [string]$Distribution = "Ubuntu",
    [switch]$Force
)

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$shScript = Join-Path $scriptDir "flash-firmware.sh"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Proxmark3 Easy - Firmware Flasher        " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Detect Proxmark3 device
Write-Host "[1/4] Detecting device..." -ForegroundColor Yellow
$pm3HwId = "9ac4:4b8f"
$usbipdList = & usbipd list
$pm3Entry = $usbipdList | Where-Object { $_ -match $pm3HwId -or $_ -match "502d:502d" }

if (-not $pm3Entry) {
    Write-Host "[!] Proxmark3 device not detected. Ensure it is firmly plugged in." -ForegroundColor Red
    exit 1
}

# 2. Check sharing status
if ($pm3Entry -match "Not shared") {
    Write-Host "[2/4] Device not shared. Requesting admin elevation to bind..." -ForegroundColor Yellow
    try {
        $p = Start-Process -FilePath "usbipd.exe" -ArgumentList "bind --hardware-id $pm3HwId" -Verb RunAs -PassThru -Wait
        if ($p.ExitCode -ne 0) {
            Write-Host "[!] Failed to bind device." -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "[!] Elevation failed." -ForegroundColor Red
        exit 1
    }
}

# 3. Ensure auto-attach is running
Write-Host "[3/4] Ensuring auto-attach is active in WSL..." -ForegroundColor Yellow
$isAttached = (& usbipd list) | Where-Object { ($_ -match $pm3HwId) -and ($_ -match "Attached") }
if (-not $isAttached) {
    Start-Process -FilePath "usbipd.exe" -ArgumentList "attach --auto-attach --hardware-id $pm3HwId --wsl $Distribution" -WindowStyle Hidden
    Start-Sleep -Seconds 3
}

& wsl.exe -d $Distribution -u root bash -c "service udev restart >/dev/null 2>&1; udevadm trigger --action=change >/dev/null 2>&1"
Start-Sleep -Seconds 1

# 4. Run Flasher via Bash script
Write-Host "[4/4] Starting flash operation..." -ForegroundColor Yellow
$wslShPath = (& wsl.exe -d $Distribution wslpath -u ($shScript -replace '\\', '/')).Trim()
$forceArg = if ($Force) { "--force" } else { "" }

& wsl.exe -d $Distribution bash $wslShPath $forceArg
