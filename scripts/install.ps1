# Installs the Kiro Ghost Button extension into the Kiro on this machine.
#
# NOTE: keep this file ASCII-only (see scripts/KiroCommon.ps1 for why).
#
# Does not require administrator rights: Kiro installs extensions under
# %USERPROFILE%\.kiro\extensions.

[CmdletBinding()]
param(
    # auto -> use the icon font glyph when this Kiro build provides it,
    #         otherwise fall back to the bundled SVGs.
    # font -> force "$(kiro)"        (exact theme colour, needs the glyph)
    # svg  -> force light/dark SVGs  (two fixed colours, works anywhere)
    [ValidateSet('auto', 'font', 'svg')]
    [string] $IconMode = 'auto',

    # Explicit path to bin\kiro.cmd, for non-standard install locations.
    [string] $KiroCli = '',

    # Keep the built .vsix in dist/ instead of deleting it afterwards.
    [switch] $KeepVsix
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'KiroCommon.ps1')

function Write-Step {
    param([string] $Message)
    Write-Host ''
    Write-Host ("==> " + $Message) -ForegroundColor Cyan
}

Write-Host ''
Write-Host 'Kiro Ghost Button - installer' -ForegroundColor White

# --- 1. locate Kiro --------------------------------------------------------
Write-Step 'Locating Kiro'
$kiroCliPath = Find-KiroCli -ExplicitPath $KiroCli
$kiroAppRoot = Get-KiroAppRoot -KiroCliPath $kiroCliPath
Write-Host ("    launcher    : " + $kiroCliPath)
Write-Host ("    install root: " + $kiroAppRoot)

# --- 2. decide how to render the icon --------------------------------------
Write-Step 'Checking icon support'
if ($IconMode -eq 'auto') {
    if (Test-KiroFontIcon -KiroAppRoot $kiroAppRoot) {
        $resolvedIconMode = 'font'
        Write-Host '    This Kiro build registers the "kiro" glyph in its icon font.'
        Write-Host '    Using $(kiro) so the icon takes the exact theme foreground colour.'
    }
    else {
        $resolvedIconMode = 'svg'
        Write-Host '    The "kiro" glyph was not found in this Kiro build.'
        Write-Host '    Falling back to the bundled light/dark SVGs so the icon stays legible.'
    }
}
else {
    $resolvedIconMode = $IconMode
    Write-Host ("    Icon mode forced to '" + $resolvedIconMode + "' via -IconMode.")
}

# --- 3. build the .vsix ----------------------------------------------------
Write-Step 'Building the extension package'
$buildScript = Join-Path $PSScriptRoot 'build-vsix.ps1'
# build-vsix.ps1 throws on any failure, so reaching the next line means it worked.
$buildOutput = & $buildScript -IconMode $resolvedIconMode
# The script writes progress with Write-Host and returns the artifact path,
# but take the last pipeline item defensively in case anything else leaks out.
$vsixPath = @($buildOutput)[-1]
if (-not $vsixPath -or -not (Test-Path -LiteralPath $vsixPath)) {
    throw "The build did not produce a .vsix (got: '$vsixPath')."
}

# --- 4. hand it to Kiro ----------------------------------------------------
Write-Step 'Installing into Kiro'
$installLog = & $kiroCliPath --install-extension $vsixPath --force 2>&1 | Out-String
$installExitCode = $LASTEXITCODE
Write-Host ($installLog.TrimEnd())

if ($installExitCode -ne 0) {
    throw "Kiro's CLI returned exit code $installExitCode. The extension was probably not installed."
}

# --- 5. verify Kiro actually registered it ---------------------------------
Write-Step 'Verifying'
$installedExtensions = & $kiroCliPath --list-extensions 2>&1 | Out-String
if ($installedExtensions -notmatch 'local\.kiro-ghost-button') {
    throw 'Kiro does not list local.kiro-ghost-button after installing. Something went wrong.'
}
Write-Host '    local.kiro-ghost-button is registered.'

if (-not $KeepVsix) {
    Remove-Item -LiteralPath $vsixPath -Force -ErrorAction SilentlyContinue
}

# --- 6. tell the user what to do next --------------------------------------
$kiroIsRunning = @(Get-Process -Name 'Kiro' -ErrorAction SilentlyContinue).Count -gt 0

Write-Host ''
Write-Host 'Done.' -ForegroundColor Green
Write-Host ''
if ($kiroIsRunning) {
    Write-Host 'Kiro is running, so reload it to pick up the new extension:'
    Write-Host '    Ctrl+Shift+P  ->  Reload Window'
}
else {
    Write-Host 'Start Kiro and the button will be there.'
}
Write-Host ''
Write-Host 'You will get:'
Write-Host '  - a ghost icon on the right of the editor title bar (needs an open file)'
Write-Host '  - a "Kiro" button in the status bar, bottom right'
Write-Host '  - the Ctrl+Alt+K shortcut'
Write-Host ''
