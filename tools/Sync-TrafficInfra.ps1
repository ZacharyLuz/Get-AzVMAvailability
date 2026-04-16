<#
.SYNOPSIS
    Syncs traffic collection infrastructure from this repo (source of truth) to sibling repos.

.DESCRIPTION
    Copies dashboard.js, collect-traffic.yml, and Generate-TrafficDashboard-Premium-v2.ps1
    to Get-AzAIModelAvailability and Get-AzPaaSAvailability with correct per-repo name
    substitutions. Run from the Get-AzVMAvailability repo root.

.PARAMETER DryRun
    Show what would change without writing files.

.EXAMPLE
    .\tools\Sync-TrafficInfra.ps1
    .\tools\Sync-TrafficInfra.ps1 -DryRun
#>

[CmdletBinding()]
param(
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Configuration
$SourceRepo = Split-Path $PSScriptRoot -Parent
$SiblingRoot = Split-Path $SourceRepo -Parent

# Source of truth identifiers (used in replacement patterns)
$SourceRepoName = 'Get-AzVMAvailability'
$SourcePSGalleryId = 'AzVMAvailability'

# Target repos with their specific identifiers
$Targets = @(
    @{
        Path         = Join-Path $SiblingRoot 'Get-AzAIModelAvailability'
        RepoName     = 'Get-AzAIModelAvailability'
        PSGalleryId  = 'Get-AzAIModelAvailability'
    }
    @{
        Path         = Join-Path $SiblingRoot 'Get-AzPaaSAvailability'
        RepoName     = 'Get-AzPaaSAvailability'
        PSGalleryId  = 'Get-AzPaaSAvailability'
    }
    @{
        Path         = Join-Path $SiblingRoot 'copilot-chat-exporter'
        RepoName     = 'github-copilot-chat-exporter'
        PSGalleryId  = 'github-copilot-chat-exporter'
    }
)

# Files to sync (relative paths + whether they need name substitution)
$SyncFiles = @(
    @{ RelPath = 'tools/dashboard.js';                                   NeedsSub = $false }
    @{ RelPath = '.github/workflows/collect-traffic.yml';                NeedsSub = $true  }
    @{ RelPath = 'tools/Generate-TrafficDashboard-Premium-v2.ps1';      NeedsSub = $true  }
)
#endregion

#region Sync Logic
$totalChanged = 0
$totalSkipped = 0

foreach ($target in $Targets) {
    $targetName = $target.RepoName
    if (-not (Test-Path $target.Path)) {
        Write-Host "  SKIP $targetName — repo not found at $($target.Path)" -ForegroundColor Yellow
        continue
    }
    Write-Host "`n=== $targetName ===" -ForegroundColor Cyan

    foreach ($file in $SyncFiles) {
        $srcFile = Join-Path $SourceRepo ($file.RelPath -replace '/', [IO.Path]::DirectorySeparatorChar)
        $dstFile = Join-Path $target.Path ($file.RelPath -replace '/', [IO.Path]::DirectorySeparatorChar)
        $shortName = $file.RelPath

        if (-not (Test-Path $srcFile)) {
            Write-Host "  SKIP $shortName — source not found" -ForegroundColor Yellow
            continue
        }

        $content = Get-Content $srcFile -Raw

        if ($file.NeedsSub) {
            # Replace repo-specific strings: repo name first, then PSGallery ID
            $content = $content -replace [regex]::Escape($SourceRepoName), $target.RepoName
            $content = $content -replace "id='$([regex]::Escape($SourcePSGalleryId))'", "id='$($target.PSGalleryId)'"
        }

        # Compare with existing target
        $changed = $true
        if (Test-Path $dstFile) {
            $existing = Get-Content $dstFile -Raw
            if ($content -eq $existing) {
                $changed = $false
            }
        }

        if ($changed) {
            if ($DryRun) {
                Write-Host "  WOULD UPDATE $shortName" -ForegroundColor Yellow
            } else {
                # Ensure target directory exists
                $dstDir = Split-Path $dstFile -Parent
                if (-not (Test-Path $dstDir)) { New-Item -ItemType Directory -Path $dstDir -Force | Out-Null }
                $content | Set-Content -Path $dstFile -NoNewline -Encoding UTF8
                Write-Host "  UPDATED $shortName" -ForegroundColor Green
            }
            $totalChanged++
        } else {
            Write-Host "  OK      $shortName (already in sync)" -ForegroundColor DarkGray
            $totalSkipped++
        }
    }
}
#endregion

#region Summary
Write-Host "`n--- Summary ---" -ForegroundColor White
if ($DryRun) {
    Write-Host "DRY RUN: $totalChanged file(s) would be updated, $totalSkipped already in sync" -ForegroundColor Yellow
} else {
    Write-Host "$totalChanged file(s) updated, $totalSkipped already in sync" -ForegroundColor Green
}
#endregion
