# Shared helpers for the install / uninstall / build scripts.
#
# NOTE: keep every .ps1 in this project ASCII-only. PowerShell 5.1 decodes a
# BOM-less .ps1 using the system ANSI codepage (e.g. GBK on zh-CN Windows),
# which corrupts non-ASCII literals and can break string terminators. Keeping
# these files ASCII makes them behave identically on any Windows locale.
# User-facing UI text lives in src/package.json and src/extension.js, which
# Kiro always reads as UTF-8, so Chinese is safe there.

Set-StrictMode -Version Latest

# Marker proving that Kiro's core icon registry contains the "kiro" glyph id.
# It shows up in the minified workbench bundle as: kiro:Q("kiro",61716)
$script:FontIconMarker = '("kiro",'

# Relative path from the Kiro install root to the minified workbench bundle.
$script:WorkbenchBundleRelativePath = 'resources\app\out\vs\workbench\workbench.desktop.main.js'

function Get-OptionalProperty {
    <#
    .SYNOPSIS
        Reads a property that may not exist, returning $null instead of throwing
        under Set-StrictMode.
    #>
    [CmdletBinding()]
    param(
        $InputObject,
        [Parameter(Mandatory = $true)][string] $Name
    )

    if ($null -eq $InputObject) { return $null }
    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property) { return $null }
    return $property.Value
}

function Find-KiroCli {
    <#
    .SYNOPSIS
        Locates Kiro's command line launcher (bin\kiro.cmd).
    #>
    [CmdletBinding()]
    param(
        [string] $ExplicitPath = ''
    )

    if ($ExplicitPath) {
        if (-not (Test-Path -LiteralPath $ExplicitPath)) {
            throw "The -KiroCli path does not exist: $ExplicitPath"
        }
        return (Resolve-Path -LiteralPath $ExplicitPath).Path
    }

    $candidates = New-Object System.Collections.Generic.List[string]

    foreach ($base in @(
            $env:LOCALAPPDATA,
            $env:ProgramFiles,
            ${env:ProgramFiles(x86)},
            $env:APPDATA
        )) {
        if ($base) {
            $candidates.Add((Join-Path $base 'Programs\Kiro\bin\kiro.cmd'))
            $candidates.Add((Join-Path $base 'Kiro\bin\kiro.cmd'))
        }
    }

    # Custom install directories: ask the uninstall registry where Kiro went.
    $registryRoots = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    foreach ($registryRoot in $registryRoots) {
        if (-not (Test-Path $registryRoot)) { continue }
        Get-ChildItem $registryRoot -ErrorAction SilentlyContinue | ForEach-Object {
            $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            # Most uninstall keys lack these values, and Set-StrictMode turns a
            # missing property into a terminating error, so probe before reading.
            $displayName = Get-OptionalProperty -InputObject $props -Name 'DisplayName'
            $installLocation = Get-OptionalProperty -InputObject $props -Name 'InstallLocation'
            if ($displayName -like '*Kiro*' -and $installLocation) {
                $candidates.Add((Join-Path $installLocation 'bin\kiro.cmd'))
            }
        }
    }

    foreach ($candidate in $candidates) {
        if ($candidate -and (Test-Path -LiteralPath $candidate)) {
            return (Resolve-Path -LiteralPath $candidate).Path
        }
    }

    # Last resort: whatever is on PATH.
    $onPath = Get-Command 'kiro' -ErrorAction SilentlyContinue
    if ($onPath -and $onPath.Source) {
        return $onPath.Source
    }

    throw @'
Could not locate Kiro.

Looked in the usual install directories, the Windows uninstall registry and PATH.
If Kiro is installed somewhere unusual, pass the launcher explicitly, e.g.:

    powershell -ExecutionPolicy Bypass -File scripts\install.ps1 -KiroCli "D:\Tools\Kiro\bin\kiro.cmd"
'@
}

function Get-KiroAppRoot {
    <#
    .SYNOPSIS
        Derives the Kiro install root from the launcher path (<root>\bin\kiro.cmd).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string] $KiroCliPath
    )

    $binDir = Split-Path -Parent $KiroCliPath
    return (Split-Path -Parent $binDir)
}

function Test-KiroFontIcon {
    <#
    .SYNOPSIS
        Reports whether this Kiro build registers the "kiro" ghost glyph in its
        core icon font, which is what makes "$(kiro)" render in theme colours.
    .DESCRIPTION
        Kiro ships its own icon font (out/media/kiricon.ttf) and registers the
        glyph ids in the minified workbench bundle. The CSS classes are generated
        at runtime, so the bundle is the only thing we can inspect statically.
        The bundle is ~12 MB, small enough to read in one go.
        Returns $false when the bundle is missing, so callers fall back to the
        SVG icons rather than risking a blank button.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string] $KiroAppRoot
    )

    $bundlePath = Join-Path $KiroAppRoot $script:WorkbenchBundleRelativePath
    if (-not (Test-Path -LiteralPath $bundlePath)) {
        Write-Verbose "Workbench bundle not found at $bundlePath"
        return $false
    }

    $bundleText = [System.IO.File]::ReadAllText($bundlePath)
    return $bundleText.Contains($script:FontIconMarker)
}

function Get-ProjectRoot {
    <#
    .SYNOPSIS
        Returns the project root, i.e. the parent of the scripts directory.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string] $ScriptDirectory
    )

    return (Split-Path -Parent $ScriptDirectory)
}
