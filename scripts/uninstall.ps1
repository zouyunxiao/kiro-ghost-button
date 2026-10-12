# Removes the Kiro Ghost Button extension from the Kiro on this machine.
#
# NOTE: keep this file ASCII-only (see scripts/KiroCommon.ps1 for why).

[CmdletBinding()]
param(
    # Explicit path to bin\kiro.cmd, for non-standard install locations.
    [string] $KiroCli = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'KiroCommon.ps1')

$extensionId = 'local.kiro-ghost-button'

Write-Host ''
Write-Host 'Kiro Ghost Button - uninstaller' -ForegroundColor White
Write-Host ''

$kiroCliPath = Find-KiroCli -ExplicitPath $KiroCli
Write-Host ("Using launcher: " + $kiroCliPath)

$installedExtensions = & $kiroCliPath --list-extensions 2>&1 | Out-String
if ($installedExtensions -notmatch [regex]::Escape($extensionId)) {
    Write-Host ''
    Write-Host ($extensionId + ' is not installed. Nothing to do.') -ForegroundColor Yellow
    Write-Host ''
    return
}

Write-Host ''
$uninstallLog = & $kiroCliPath --uninstall-extension $extensionId 2>&1 | Out-String
$uninstallExitCode = $LASTEXITCODE
Write-Host ($uninstallLog.TrimEnd())

if ($uninstallExitCode -ne 0) {
    throw "Kiro's CLI returned exit code $uninstallExitCode. The extension may still be installed."
}

Write-Host ''
Write-Host 'Removed.' -ForegroundColor Green
Write-Host 'Reload Kiro (Ctrl+Shift+P -> Reload Window) to make the button disappear.'
Write-Host ''
