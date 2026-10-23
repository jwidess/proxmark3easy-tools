# Environment setup for Windows and WSL2 to prepare a new PC for PM3 development.

[CmdletBinding()]
param(
    [string]$Distribution = "Ubuntu"
)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " Proxmark3 Easy - Windows Setup" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Check / Install USBIPD
$usbipd = Get-Command usbipd.exe -ErrorAction SilentlyContinue
if (-not $usbipd) {
    Write-Host "[1/3] usbipd-win not found. Installing via winget..." -ForegroundColor Yellow
    winget install --id dorssel.usbipd-win -e --accept-source-agreements --accept-package-agreements
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [+] USBIPD installed successfully." -ForegroundColor Green
    } else {
        Write-Host "  [!] USBIPD installation via winget returned code $LASTEXITCODE." -ForegroundColor Yellow
        Write-Host "      Download manually from: https://github.com/dorssel/usbipd-win/releases" -ForegroundColor Gray
    }
} else {
    Write-Host "[1/3] usbipd is already installed." -ForegroundColor Green
}

# 2. Check / Install WSL
$wsl = Get-Command wsl.exe -ErrorAction SilentlyContinue
if (-not $wsl) {
    Write-Host "[2/3] WSL not found. Installing Ubuntu..." -ForegroundColor Yellow
    wsl --install -d $Distribution
    Write-Host "  [*] WSL installed. You may need to reboot your computer if this is the first time enabling WSL." -ForegroundColor Yellow
} else {
    Write-Host "[2/3] WSL is installed." -ForegroundColor Green
}

# 3. Run WSL setup script
Write-Host "[3/3] Setting up WSL packages and udev rules..." -ForegroundColor Yellow
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$shScript = Join-Path $scriptDir "setup-wsl-environment.sh"
$wslShPath = (& wsl.exe -d $Distribution wslpath -u ($shScript -replace '\\', '/')).Trim()

& wsl.exe -d $Distribution bash $wslShPath

Write-Host ""
Write-Host "Setup complete!" -ForegroundColor Cyan
