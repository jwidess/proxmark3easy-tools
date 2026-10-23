# Detects connected PM3, COM port assignment, and USBIPD/WSL status.

[CmdletBinding()]
param()

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Proxmark3 Easy - Detect Check " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check Windows Device Manager/ nP
Write-Host "[1/3] Searching Windows PnP Devices..." -ForegroundColor Yellow
$pm3Pnp = Get-CimInstance Win32_PnPEntity -ErrorAction SilentlyContinue | 
    Where-Object { $_.DeviceID -match "VID_9AC4&PID_4B8F|VID_502D&PID_502D|VID_2D2D&PID_504D" }

if ($pm3Pnp) {
    foreach ($dev in $pm3Pnp) {
        Write-Host "  [+] Found Proxmark3 hardware:" -ForegroundColor Green
        Write-Host "      Name:       $($dev.Name)"
        Write-Host "      Device ID:  $($dev.DeviceID)"
        Write-Host "      Status:     $($dev.Status)"
    }
} else {
    Write-Host "  [-] No Proxmark3 USB device found in Windows Device Manager." -ForegroundColor Red
    Write-Host "      Ensure your device is plugged into a USB port." -ForegroundColor Gray
}

# 2. Check Windows COM Ports
Write-Host ""
Write-Host "[2/3] Checking Windows Serial/COM Ports..." -ForegroundColor Yellow
$serialPorts = Get-CimInstance Win32_SerialPort -ErrorAction SilentlyContinue |
    Where-Object { $_.PNPDeviceID -match "9AC4|502D|2D2D" -or $_.Description -match "Proxmark" }

if ($serialPorts) {
    foreach ($port in $serialPorts) {
        Write-Host "  [+] Proxmark3 is assigned to Windows port: " -NoNewline -ForegroundColor Green
        Write-Host "$($port.DeviceID)" -ForegroundColor Cyan
        Write-Host "      Description: $($port.Description)"
    }
} else {
    # It might be attached to WSL via USBIPD, or not yet enumerated
    $allPorts = Get-CimInstance Win32_SerialPort -ErrorAction SilentlyContinue
    if ($allPorts) {
        Write-Host "  [*] Active COM Ports detected:" -ForegroundColor Gray
        foreach ($p in $allPorts) {
            Write-Host "      $($p.DeviceID): $($p.Description)" -ForegroundColor Gray
        }
    }
    if ($pm3Pnp -and -not $serialPorts) {
        Write-Host "  [*] Note: Device is plugged in but not visible as a Windows COM port." -ForegroundColor Yellow
        Write-Host "      It is likely attached into WSL via USBIPD (which is normal when using WSL)." -ForegroundColor Yellow
    }
}

# 3. Check USBIPD status
Write-Host ""
Write-Host "[3/3] Checking USBIPD Status..." -ForegroundColor Yellow
$usbipdCmd = Get-Command usbipd.exe -ErrorAction SilentlyContinue
if (-not $usbipdCmd) {
    $defaultUsbipdDir = Join-Path $env:ProgramFiles "usbipd-win"
    if (Test-Path (Join-Path $defaultUsbipdDir "usbipd.exe")) {
        $env:PATH = "$defaultUsbipdDir;$env:PATH"
        $usbipdCmd = Get-Command usbipd.exe -ErrorAction SilentlyContinue
    }
}
if ($usbipdCmd) {
    try {
        $usbipdOutput = usbipd list
        $pm3Line = $usbipdOutput | Where-Object { $_ -match "9ac4:4b8f|502d:502d|2d2d:504d" }
        if ($pm3Line) {
            Write-Host "  [+] USBIPD Status for Proxmark3:" -ForegroundColor Green
            Write-Host "      $pm3Line" -ForegroundColor White
        } else {
            Write-Host "  [*] Device not detected in 'usbipd list'." -ForegroundColor Yellow
        }
    } catch {
        Write-Host "  [!] Error querying usbipd: $_" -ForegroundColor Red
    }
} else {
    Write-Host "  [-] usbipd-win is not installed or not in PATH." -ForegroundColor Yellow
    Write-Host "      Install with: winget install usbipd" -ForegroundColor Gray
}

# 4. Check WSL status if WSL is available
Write-Host ""
$wslCmd = Get-Command wsl.exe -ErrorAction SilentlyContinue
if ($wslCmd) {
    Write-Host "[*] Checking WSL device nodes..." -ForegroundColor Yellow
    $wslDev = wsl.exe -e bash -c "ls -la /dev/pm3* /dev/ttyACM* 2>/dev/null" 2>$null
    if ($wslDev) {
        Write-Host "  [+] Device attached in WSL:" -ForegroundColor Green
        foreach ($line in $wslDev) {
            Write-Host "      $line" -ForegroundColor White
        }
    } else {
        Write-Host "  [*] Device is currently NOT attached in WSL." -ForegroundColor Gray
    }
}

Write-Host ""
Write-Host "Done." -ForegroundColor Cyan
