# Environment setup for Windows and WSL2 to prepare a new PC for PM3 development.

[CmdletBinding()]
param(
    [string]$Distribution = "Ubuntu",
    [string]$Proxmark3Path = (Join-Path $env:USERPROFILE "Documents\GitHub\proxmark3")
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Proxmark3 Easy - Windows Setup" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check / Install USBIPD
$usbipd = Get-Command usbipd.exe -ErrorAction SilentlyContinue
if (-not $usbipd) {
    $defaultUsbipdDir = Join-Path $env:ProgramFiles "usbipd-win"
    if (Test-Path (Join-Path $defaultUsbipdDir "usbipd.exe")) {
        $env:PATH = "$defaultUsbipdDir;$env:PATH"
        $usbipd = Get-Command usbipd.exe -ErrorAction SilentlyContinue
    }
}

if (-not $usbipd) {
    Write-Host "[1/3] usbipd-win not found. Installing via winget..." -ForegroundColor Yellow
    winget install --id dorssel.usbipd-win -e --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [+] USBIPD installed successfully." -ForegroundColor Green
        $defaultUsbipdDir = Join-Path $env:ProgramFiles "usbipd-win"
        if (Test-Path (Join-Path $defaultUsbipdDir "usbipd.exe")) {
            $env:PATH = "$defaultUsbipdDir;$env:PATH"
        }
        $usbipd = Get-Command usbipd.exe -ErrorAction SilentlyContinue
    } else {
        Write-Host "  [!] USBIPD installation via winget returned code $LASTEXITCODE." -ForegroundColor Yellow
        Write-Host "      Download manually from: https://github.com/dorssel/usbipd-win/releases" -ForegroundColor Gray
    }
} else {
    Write-Host "[1/3] usbipd is already installed." -ForegroundColor Green
}

if (-not $usbipd) {
    Write-Host "[!] usbipd.exe is not available. Please install it and ensure it is in PATH, then run setup again." -ForegroundColor Red
    exit 1
}

# 2. Check / Install WSL
$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
$distributionMissing = $true
if (-not $wsl) {
    Write-Host "[2/3] WSL is not installed." -ForegroundColor Yellow
} else {
    $installedDistributions = @(wsl.exe --list --quiet 2>$null | ForEach-Object { $_ -replace "\0", "" } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    $distributionMissing = $installedDistributions -notcontains $Distribution
    if (-not $distributionMissing) {
        Write-Host "[2/3] WSL and $Distribution are installed." -ForegroundColor Green
    }
}

if ($distributionMissing) {
    Write-Host "[!] The $Distribution WSL distribution is a large download." -ForegroundColor Yellow
    $confirm = Read-Host "Would you like to download and install it now? [y/N]"
    if ($confirm -notmatch '^[Yy]$') {
        Write-Host "[!] $Distribution installation cancelled by user. Setup aborted." -ForegroundColor Red
        exit 1
    }

    Write-Host "[*] Installing $Distribution..." -ForegroundColor Yellow
    wsl.exe --install --no-launch -d $Distribution
    if ($LASTEXITCODE -ne 0) {
        Write-Host "[!] $Distribution installation failed with code $LASTEXITCODE." -ForegroundColor Red
        exit 1
    }
}

$installedDistributions = @(wsl.exe --list --quiet 2>$null | ForEach-Object { $_ -replace "\0", "" } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($installedDistributions -notcontains $Distribution) {
    Write-Host "[!] '$Distribution' is not ready yet." -ForegroundColor Red
    Write-Host "    If Windows requested a reboot, reboot then run this script again." -ForegroundColor Yellow
    exit 1
}

Write-Host "[*] Initializing $Distribution. Complete any first-run username/password prompts..." -ForegroundColor Yellow
& wsl.exe -d $Distribution -- bash -lc "true"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[!] Could not initialize the $Distribution WSL distribution." -ForegroundColor Red
    Write-Host "    Complete its first-run setup, then run this script again." -ForegroundColor Yellow
    exit 1
}

$wslUser = $null
$uid = 0
$passwdEntries = @(wsl.exe -d $Distribution -- getent passwd 2>$null)
foreach ($entry in $passwdEntries) {
    $fields = $entry.Trim() -split ':'
    if ($fields.Count -ge 3 -and [int]::TryParse($fields[2], [ref]$uid) -and $uid -ge 1000 -and $uid -lt 60000) {
        $wslUser = $fields[0]
        break
    }
}

if ($wslUser) {
    Write-Host "[*] Running setup as WSL user '$wslUser'..." -ForegroundColor Gray
} else {
    Write-Host "[!] No normal Linux user was found in $Distribution." -ForegroundColor Red
    Write-Host "    Create one before continuing so packages and the Proxmark3 repo are installed for your user:" -ForegroundColor Yellow
    Write-Host "    wsl.exe -d $Distribution -u root adduser <username>" -ForegroundColor Gray
    Write-Host "    wsl.exe -d $Distribution -u root usermod -aG sudo <username>" -ForegroundColor Gray
    Write-Host "    Then run this setup script again." -ForegroundColor Yellow
    exit 1
}

# 3. Run WSL setup script
Write-Host "[3/3] Setting up WSL packages and udev rules..." -ForegroundColor Yellow
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$shScript = Join-Path $scriptDir "setup-wsl-environment.sh"
$wslShPath = (& wsl.exe -d $Distribution wslpath -u ($shScript -replace '\\', '/') 2>$null).Trim()
$wslProxmark3Path = (& wsl.exe -d $Distribution wslpath -u ($Proxmark3Path -replace '\\', '/') 2>$null).Trim()

& wsl.exe -d $Distribution -u $wslUser bash $wslShPath $wslProxmark3Path
if ($LASTEXITCODE -ne 0) {
    Write-Host "[!] WSL environment setup failed with code $LASTEXITCODE." -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "Setup complete!" -ForegroundColor Cyan
