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

$usbipd = Get-Command usbipd.exe -ErrorAction SilentlyContinue
if (-not $usbipd) {
    $defaultUsbipdDir = Join-Path $env:ProgramFiles "usbipd-win"
    if (Test-Path (Join-Path $defaultUsbipdDir "usbipd.exe")) {
        $env:PATH = "$defaultUsbipdDir;$env:PATH"
        $usbipd = Get-Command usbipd.exe -ErrorAction SilentlyContinue
    }
}

if (-not $usbipd) {
    Write-Host "[!] usbipd-win is not installed or not in PATH." -ForegroundColor Red
    Write-Host "    Run .\scripts\setup-wsl-environment.ps1 first." -ForegroundColor Yellow
    exit 1
}

$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $wsl) {
    Write-Host "[!] WSL is not installed or enabled." -ForegroundColor Red
    Write-Host "    Run .\scripts\setup-wsl-environment.ps1 first." -ForegroundColor Yellow
    exit 1
}

$installedDistributions = @(wsl.exe --list --quiet 2>$null | ForEach-Object { $_ -replace "\0", "" } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($installedDistributions -notcontains $Distribution) {
    Write-Host "[!] WSL distribution '$Distribution' is not installed." -ForegroundColor Red
    Write-Host "    Run .\scripts\setup-wsl-environment.ps1 first." -ForegroundColor Yellow
    exit 1
}

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
$isAttached = (& usbipd list 2>$null) | Where-Object { ($_ -match $pm3HwId -or $_ -match "502d:502d") -and ($_ -match "Attached") }
if (-not $isAttached) {
    Write-Host "[*] Ensuring WSL ($Distribution) is running..." -ForegroundColor Gray
    $wslCheck = & wsl.exe -d $Distribution --exec true 2>&1
    if ($LASTEXITCODE -ne 0) {
        $wslMsg = ($wslCheck | ForEach-Object { "$_" -replace "\0", "" }) -join "`n"
        Write-Host "[!] WSL distribution '$Distribution' failed to start." -ForegroundColor Red
        if ($wslMsg.Trim()) {
            Write-Host "    $($wslMsg.Trim())" -ForegroundColor Red
        }
        if ($wslMsg -match "0x80070569") {
            Write-Host ""
            Write-Host "[*] Hyper-V logon error (0x80070569) detected." -ForegroundColor Yellow
            Write-Host "    To fix WSL, open PowerShell as admin and run:" -ForegroundColor Yellow
            Write-Host "    Restart-Service vmcompute" -ForegroundColor White
        }
        exit 1
    }

    Start-Process -FilePath "usbipd.exe" -ArgumentList "attach --auto-attach --hardware-id $pm3HwId --wsl $Distribution" -WindowStyle Hidden

    $attached = $false
    for ($i = 0; $i -lt 10; $i++) {
        Start-Sleep -Seconds 1
        $check = (& usbipd list 2>$null) | Where-Object { ($_ -match $pm3HwId -or $_ -match "502d:502d") -and ($_ -match "Attached") }
        if ($check) {
            $attached = $true
            break
        }
    }

    if (-not $attached) {
        Write-Host "[!] Failed to attach Proxmark3 to WSL within 10 seconds." -ForegroundColor Red
        exit 1
    }
}

& wsl.exe -d $Distribution -u root bash -c "service udev restart >/dev/null 2>&1; udevadm trigger --action=change >/dev/null 2>&1"
Start-Sleep -Milliseconds 500

# 4. Run Flasher via Bash script
Write-Host "[4/4] Starting flash operation..." -ForegroundColor Yellow
$wslShPath = (& wsl.exe -d $Distribution wslpath -u ($shScript -replace '\\', '/')).Trim()
$forceArg = if ($Force) { "--force" } else { "" }

& wsl.exe -d $Distribution bash $wslShPath $forceArg
