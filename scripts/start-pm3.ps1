# Automates connecting and launching the Proxmark3 client via WSL2 and USBIPD.

[CmdletBinding()]
param(
    [string]$Distribution = "Ubuntu",
    [switch]$NoNewWindow
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Proxmark3 Easy - WSL2 Client Launcher    " -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check for usbipd
$usbipd = Get-Command usbipd.exe -ErrorAction SilentlyContinue
if (-not $usbipd) {
    $defaultUsbipdDir = Join-Path $env:ProgramFiles "usbipd-win"
    if (Test-Path (Join-Path $defaultUsbipdDir "usbipd.exe")) {
        $env:PATH = "$defaultUsbipdDir;$env:PATH"
        $usbipd = Get-Command usbipd.exe -ErrorAction SilentlyContinue
    }
}

if (-not $usbipd) {
    Write-Host "[!] 'usbipd.exe' was not found in PATH." -ForegroundColor Red
    Write-Host "    Please install USBIPD on Windows by running:" -ForegroundColor Yellow
    Write-Host "    winget install usbipd" -ForegroundColor White
    Read-Host "Press Enter to exit..."
    exit 1
}

# 2. Check for WSL
$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $wsl) {
    Write-Host "[!] WSL is not installed or enabled." -ForegroundColor Red
    Write-Host "    Please enable WSL: wsl --install" -ForegroundColor Yellow
    Read-Host "Press Enter to exit..."
    exit 1
}

$installedDistributions = @(wsl.exe --list --quiet 2>$null | ForEach-Object { $_ -replace "\0", "" } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($installedDistributions -notcontains $Distribution) {
    Write-Host "[!] WSL distribution '$Distribution' is not installed." -ForegroundColor Red
    Write-Host "    Run .\scripts\setup-wsl-environment.ps1 first." -ForegroundColor Yellow
    Read-Host "Press Enter to exit..."
    exit 1
}

# 3. Detect Proxmark3 device
Write-Host "[1/4] Detecting Proxmark3 hardware..." -ForegroundColor Yellow
$pm3HwId = "9ac4:4b8f"
$usbipdList = & usbipd list
$pm3Entry = $usbipdList | Where-Object { $_ -match $pm3HwId -or $_ -match "502d:502d" }

if (-not $pm3Entry) {
    Write-Host "[!] Proxmark3 device ($pm3HwId) not detected in USB list." -ForegroundColor Red
    Write-Host "    Please plug in your Proxmark3 Easy and try again." -ForegroundColor Yellow
    Read-Host "Press Enter to exit..."
    exit 1
}

Write-Host "  [+] Found device: $pm3Entry" -ForegroundColor Green

# 4. Check if device is shared; if not, elevate to bind
if ($pm3Entry -match "Not shared") {
    Write-Host "[2/4] Device is not shared in USBIPD. Elevating to bind..." -ForegroundColor Yellow
    try {
        $p = Start-Process -FilePath "usbipd.exe" -ArgumentList "bind --hardware-id $pm3HwId" -Verb RunAs -PassThru -Wait
        if ($p.ExitCode -ne 0) {
            Write-Host "[!] Failed to bind device with administrator rights." -ForegroundColor Red
            Read-Host "Press Enter to exit..."
            exit 1
        }
        Write-Host "  [+] Device bound successfully." -ForegroundColor Green
    } catch {
        Write-Host "[!] Elevation failed or was cancelled." -ForegroundColor Red
        Read-Host "Press Enter to exit..."
        exit 1
    }
} else {
    Write-Host "[2/4] Device is already shared in USBIPD." -ForegroundColor Green
}

# 5. Start auto-attach process if not already attached
Write-Host "[3/4] Attaching device to WSL ($Distribution)..." -ForegroundColor Yellow
$currentList = & usbipd list
$isAttached = $currentList | Where-Object { ($_ -match $pm3HwId) -and ($_ -match "Attached") }

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
        Read-Host "Press Enter to exit..."
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
        Read-Host "Press Enter to exit..."
        exit 1
    }
    Write-Host "  [+] Device attached successfully." -ForegroundColor Green
} else {
    Write-Host "  [+] Device is already attached." -ForegroundColor Green
}

# 6. Trigger udev rules in WSL
& wsl.exe -d $Distribution -u root bash -c "service udev restart >/dev/null 2>&1; udevadm trigger --action=change >/dev/null 2>&1" 2>$null

# 7. Launch Proxmark3 interactive client
Write-Host "[4/4] Launching Proxmark3 client..." -ForegroundColor Green

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$shScript = Join-Path $scriptDir "start-pm3.sh"
$wslShPath = (& wsl.exe -d $Distribution wslpath -u ($shScript -replace '\\', '/') 2>$null).Trim()

$uid = 0
$wslUser = $null
$passwdEntries = @(wsl.exe -d $Distribution -- getent passwd 2>$null)
foreach ($entry in $passwdEntries) {
    $fields = $entry.Trim() -split ':'
    if ($fields.Count -ge 3 -and [int]::TryParse($fields[2], [ref]$uid) -and $uid -ge 1000 -and $uid -lt 60000) {
        $wslUser = $fields[0]
        break
    }
}

$userArgs = if ($wslUser) { @("-u", $wslUser) } else { @() }
$userArgStr = if ($wslUser) { "-u $wslUser " } else { "" }

$wt = Get-Command wt.exe -ErrorAction SilentlyContinue

if ($NoNewWindow) {
    & wsl.exe -d $Distribution @userArgs bash $wslShPath
} elseif ($wt) {
    # Notice: No semicolons in argument list to avoid Windows Terminal tab-splitting
    Start-Process -FilePath "wt.exe" -ArgumentList "--title `"Proxmark3 Easy`" wsl.exe -d $Distribution $userArgStr bash `"$wslShPath`""
    Write-Host "Proxmark3 client launched in Windows Terminal." -ForegroundColor Cyan
} else {
    Start-Process -FilePath "cmd.exe" -ArgumentList "/c start wsl.exe -d $Distribution $userArgStr bash `"$wslShPath`""
    Write-Host "Proxmark3 client launched in new window." -ForegroundColor Cyan
}
