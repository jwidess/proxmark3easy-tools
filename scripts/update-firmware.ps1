# Pulls latest Iceman fork, compiles PM3 Easy firmware, copies binaries to this repo, and optionally flashes.

[CmdletBinding()]
param(
    [string]$Distribution = "Ubuntu",
    [string]$Proxmark3Path = (Join-Path $env:USERPROFILE "Documents\GitHub\proxmark3")
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

$installedDistributions = @(wsl.exe --list --quiet 2>$null | ForEach-Object { $_ -replace "\0", "" } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($installedDistributions -notcontains $Distribution) {
    Write-Host "[!] WSL distribution '$Distribution' is not installed." -ForegroundColor Red
    Write-Host "    Run .\scripts\setup-wsl-environment.ps1 first." -ForegroundColor Yellow
    Read-Host "Press Enter to exit..."
    exit 1
}

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

# Resolve usbipd if installed in default location
$usbipd = Get-Command usbipd.exe -ErrorAction SilentlyContinue
if (-not $usbipd) {
    $defaultUsbipdDir = Join-Path $env:ProgramFiles "usbipd-win"
    if (Test-Path (Join-Path $defaultUsbipdDir "usbipd.exe")) {
        $env:PATH = "$defaultUsbipdDir;$env:PATH"
        $usbipd = Get-Command usbipd.exe -ErrorAction SilentlyContinue
    }
}

# Attach device to WSL if connected so flashing works if requested
if ($usbipd) {
    $pm3HwId = "9ac4:4b8f"
    $currentList = & usbipd.exe list 2>$null
    $pm3Entry = $currentList | Where-Object { $_ -match $pm3HwId -or $_ -match "502d:502d" }

    if ($pm3Entry) {
        if ($pm3Entry -match "Not shared") {
            try {
                Start-Process -FilePath "usbipd.exe" -ArgumentList "bind --hardware-id $pm3HwId" -Verb RunAs -PassThru -Wait | Out-Null
            } catch {}
        }
        if ($pm3Entry -notmatch "Attached") {
            & wsl.exe -d $Distribution --exec true 2>$null
            Start-Process -FilePath "usbipd.exe" -ArgumentList "attach --auto-attach --hardware-id $pm3HwId --wsl $Distribution" -WindowStyle Hidden
            Start-Sleep -Seconds 2
            & wsl.exe -d $Distribution -u root bash -c "service udev restart >/dev/null 2>&1; udevadm trigger --action=change >/dev/null 2>&1" 2>$null
        }
    }
}

$wslShPath = (& wsl.exe -d $Distribution wslpath -u ($shScript -replace '\\', '/') 2>$null).Trim()
$wslProxmark3Path = (& wsl.exe -d $Distribution wslpath -u ($Proxmark3Path -replace '\\', '/') 2>$null).Trim()

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

if (-not $wslUser) {
    Write-Host "[!] No normal Linux user was found in $Distribution." -ForegroundColor Red
    Write-Host "    Run setup-wsl-environment.ps1 first to initialize the distribution." -ForegroundColor Yellow
    exit 1
}

$buildDate = Get-Date -Format "MMMM dd, yyyy 'at' hh:mm tt"
& wsl.exe -d $Distribution -u $wslUser bash $wslShPath $wslProxmark3Path $buildDate
$updateExitCode = $LASTEXITCODE

if ($updateExitCode -ne 0) {
    Write-Host "[!] Firmware update failed with code $updateExitCode." -ForegroundColor Red
    exit $updateExitCode
}

Write-Host ""
Write-Host "Remember to commit and push changes to proxmark3easy-tools if updated!" -ForegroundColor Yellow
