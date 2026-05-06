<#
.SYNOPSIS
    Stages the AzVMAvailability module package for PSGallery publishing.
.DESCRIPTION
    Copies the module source plus curated runtime and user-facing assets into a
    PSGallery-ready staging folder. The staged folder is the input to
    Publish-Module and the GitHub Release zip.
.PARAMETER RepoRoot
    Repository root. Defaults to the parent of the tools directory.
.PARAMETER StagingRoot
    Directory that will contain the staged AzVMAvailability folder.
#>
[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$StagingRoot = (Join-Path (Split-Path $PSScriptRoot -Parent) 'staging'),
    [string]$ModuleName = 'AzVMAvailability'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRootPath = (Resolve-Path -LiteralPath $RepoRoot).Path
$moduleSource = Join-Path $repoRootPath $ModuleName

if (-not (Test-Path -LiteralPath $moduleSource -PathType Container)) {
    throw "Module source folder not found: $moduleSource"
}

$stagingRootPath = if (Test-Path -LiteralPath $StagingRoot) {
    (Resolve-Path -LiteralPath $StagingRoot).Path
}
else {
    (New-Item -ItemType Directory -Path $StagingRoot -Force).FullName
}

$stagingDir = Join-Path $stagingRootPath $ModuleName
New-Item -ItemType Directory -Path $stagingDir -Force | Out-Null

Get-ChildItem -LiteralPath $moduleSource -Force | ForEach-Object {
    Copy-Item -LiteralPath $_.FullName -Destination $stagingDir -Recurse -Force
}

$packageAssetPaths = @(
    'README.md',
    'LICENSE',
    'CHANGELOG.md',
    'data/UpgradePath.json',
    'data/UpgradePath.md',
    'docs/agent-integration.md',
    'docs/cloud-environments.md',
    'docs/codespaces.md',
    'docs/Excel-Legend-Reference.md',
    'docs/image-compatibility.md',
    'docs/inventory-planning.md',
    'docs/lifecycle-recommendations.md',
    'docs/LifecycleRecommendationCoreDifferences.md',
    'docs/local-installation.md',
    'docs/output-and-pricing.md',
    'docs/parameters.md',
    'docs/region-presets.md',
    'docs/usage-examples.md',
    'examples/ARG-Queries.md',
    'examples/fleet-bom.csv',
    'examples/fleet-bom.json'
)

foreach ($relativePath in $packageAssetPaths) {
    $sourcePath = Join-Path $repoRootPath $relativePath
    if (-not (Test-Path -LiteralPath $sourcePath -PathType Leaf)) {
        throw "Package asset not found: $relativePath"
    }

    $destinationPath = Join-Path $stagingDir $relativePath
    $destinationParent = Split-Path -Path $destinationPath -Parent
    New-Item -ItemType Directory -Path $destinationParent -Force | Out-Null
    Copy-Item -LiteralPath $sourcePath -Destination $destinationPath -Force
}

$requiredFiles = @(
    'AzVMAvailability.psd1',
    'AzVMAvailability.psm1',
    'Public/Get-AzVMAvailability.ps1',
    'Private/Utility/Get-SafeString.ps1',
    'data/UpgradePath.json',
    'README.md',
    'LICENSE',
    'CHANGELOG.md'
)

foreach ($relativePath in $requiredFiles) {
    $stagedPath = Join-Path $stagingDir $relativePath
    if (-not (Test-Path -LiteralPath $stagedPath -PathType Leaf)) {
        throw "Required package file missing from staging: $relativePath"
    }
}

Write-Host "Staged $ModuleName package at $stagingDir"

[pscustomobject]@{
    ModulePath         = (Resolve-Path -LiteralPath $stagingDir).Path
    IncludedAssetCount = $packageAssetPaths.Count
    IncludedAssets     = @($packageAssetPaths)
}
