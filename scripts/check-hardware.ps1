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

$pm3HwId = "9ac4:4b8f"
$usbipdList = & usbipd list 2>$null
$pm3Entry = $usbipdList | Where-Object { $_ -match $pm3HwId -or $_ -match "502d:502d" }

if (-not $pm3Entry) {
    Write-Host "[!] Proxmark3 device ($pm3HwId) was not found by usbipd." -ForegroundColor Red
    Write-Host "    Plug in the device and run this check again." -ForegroundColor Yellow
    exit 1
}

if ($pm3Entry -match "Not shared") {
    Write-Host "[*] Device is not shared in USBIPD. Elevating to bind..." -ForegroundColor Yellow
    try {
        $p = Start-Process -FilePath "usbipd.exe" -ArgumentList "bind --hardware-id $pm3HwId" -Verb RunAs -PassThru -Wait
        if ($p.ExitCode -ne 0) {
            Write-Host "[!] Failed to bind device with administrator rights." -ForegroundColor Red
            exit 1
        }
    } catch {
        Write-Host "[!] Elevation failed or was cancelled." -ForegroundColor Red
        exit 1
    }
}

if ($pm3Entry -notmatch "Attached") {
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

    Write-Host "[*] Device is not attached to WSL. Attaching..." -ForegroundColor Yellow
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
        Write-Host "    Check 'usbipd list' or try attaching manually." -ForegroundColor Yellow
        exit 1
    }

    & wsl.exe -d $Distribution -u root bash -c "service udev restart >/dev/null 2>&1; udevadm trigger --action=change >/dev/null 2>&1" 2>$null
    Start-Sleep -Milliseconds 500
}

$wslShPath = (& wsl.exe -d $Distribution wslpath -u ($shScript -replace '\\', '/') 2>$null).Trim()

& wsl.exe -d $Distribution bash $wslShPath
