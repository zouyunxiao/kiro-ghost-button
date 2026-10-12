# Packages src/ into a .vsix (a zip laid out per the VSIX spec).
#
# NOTE: keep this file ASCII-only (see scripts/KiroCommon.ps1 for why).
#
# Entries are written one at a time with explicit forward-slash names so we do
# not depend on how ZipFile::CreateFromDirectory handles path separators.

[CmdletBinding()]
param(
    # font -> "icon": "$(kiro)"            (glyph from Kiro's icon font, exact theme colour)
    # svg  -> "icon": { light, dark }      (two fixed-colour SVGs, works on any build)
    [ValidateSet('font', 'svg')]
    [string] $IconMode = 'font',

    [string] $OutDir = ''
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

. (Join-Path $PSScriptRoot 'KiroCommon.ps1')

$projectRoot = Get-ProjectRoot -ScriptDirectory $PSScriptRoot
$srcDir = Join-Path $projectRoot 'src'
if (-not $OutDir) {
    $OutDir = Join-Path $projectRoot 'dist'
}

$utf8NoBom = [System.Text.UTF8Encoding]::new($false)

# --- version: package.json is the source of truth -------------------------
$packageJsonPath = Join-Path $srcDir 'package.json'
$packageJsonText = [System.IO.File]::ReadAllText($packageJsonPath, $utf8NoBom)
$version = ($packageJsonText | ConvertFrom-Json).version

$vsixManifestPath = Join-Path $srcDir 'vsix\extension.vsixmanifest'
$vsixManifestText = [System.IO.File]::ReadAllText($vsixManifestPath, $utf8NoBom)
if (-not $vsixManifestText.Contains('Version="' + $version + '"')) {
    throw "Version mismatch: src/package.json says $version but src/vsix/extension.vsixmanifest does not. Sync them and retry."
}

# --- icon mode: patch the manifest in memory only -------------------------
$fontIconDeclaration = '"icon": "$(kiro)"'
if (-not $packageJsonText.Contains($fontIconDeclaration)) {
    throw "Could not find the icon declaration ($fontIconDeclaration) in src/package.json. Did the manifest change?"
}

if ($IconMode -eq 'svg') {
    $svgIconDeclaration = @'
"icon": {
					"light": "resources/ghost-light.svg",
					"dark": "resources/ghost-dark.svg"
				}
'@
    $packageJsonText = $packageJsonText.Replace($fontIconDeclaration, $svgIconDeclaration)

    # Fail loudly rather than shipping a manifest we did not actually validate.
    $null = $packageJsonText | ConvertFrom-Json
}

# --- assemble the zip ------------------------------------------------------
# The SVGs ship in both modes: they are a few KB and keeping the entry list
# static means one less thing that can diverge between the two modes.
$fileEntries = [ordered]@{
    'vsix\[Content_Types].xml'    = '[Content_Types].xml'
    'vsix\extension.vsixmanifest' = 'extension.vsixmanifest'
    'extension.js'                = 'extension/extension.js'
    'resources\ghost-light.svg'   = 'extension/resources/ghost-light.svg'
    'resources\ghost-dark.svg'    = 'extension/resources/ghost-dark.svg'
}

foreach ($relativePath in $fileEntries.Keys) {
    $fullPath = Join-Path $srcDir $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) {
        throw "Missing source file: $fullPath"
    }
}

if (-not (Test-Path -LiteralPath $OutDir)) {
    $null = New-Item -ItemType Directory -Path $OutDir -Force
}

$vsixPath = Join-Path $OutDir ("kiro-ghost-button-" + $version + ".vsix")
if (Test-Path -LiteralPath $vsixPath) {
    Remove-Item -LiteralPath $vsixPath -Force
}

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

$zip = [System.IO.Compression.ZipFile]::Open($vsixPath, 'Create')
try {
    # package.json is written from the (possibly icon-patched) text in memory.
    $entry = $zip.CreateEntry('extension/package.json', [System.IO.Compression.CompressionLevel]::Optimal)
    $bytes = $utf8NoBom.GetBytes($packageJsonText)
    $stream = $entry.Open()
    try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
    Write-Host ("  + extension/package.json  (" + $bytes.Length + " bytes, icon mode: " + $IconMode + ")")

    # Everything else is copied byte for byte, so encodings survive untouched.
    foreach ($relativePath in $fileEntries.Keys) {
        $entryName = $fileEntries[$relativePath]
        $entry = $zip.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
        $bytes = [System.IO.File]::ReadAllBytes((Join-Path $srcDir $relativePath))
        $stream = $entry.Open()
        try { $stream.Write($bytes, 0, $bytes.Length) } finally { $stream.Dispose() }
        Write-Host ("  + " + $entryName + "  (" + $bytes.Length + " bytes)")
    }
}
finally {
    $zip.Dispose()
}

Write-Host ''
Write-Host ("Packaged: " + $vsixPath)

# Let callers (install.ps1) pick the artifact up without re-deriving the name.
return $vsixPath
