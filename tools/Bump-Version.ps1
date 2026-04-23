<#
.SYNOPSIS
    Programmatically bumps the version across all canonical locations in this project.

.DESCRIPTION
    Prevents the recurring problem of missed version locations during release bumps.
    Updates 10 locations atomically so nothing can be forgotten.

    Locations updated:
      1. Get-AzVMAvailability.ps1     — .NOTES Version
      2. Get-AzVMAvailability.ps1     — $ScriptVersion variable
      3. AzVMAvailability.psd1        — ModuleVersion
      4. AzVMAvailability.psd1        — ReleaseNotes
      5. README.md                    — Version badge (shields.io)
      6. README.md                    — Console output "wrapper vX.Y.Z" if present
      7. demo/DEMO-GUIDE.md           — **Version:** line
      8. ROADMAP.md                   — Current Release header
      9. ROADMAP.md                   — Current release description line
         ROADMAP.md                   — (In Progress) → (Released) if new version section exists
     10. CHANGELOG.md                 — Insert new versioned section

.PARAMETER NewVersion
    The new version string in semver format (e.g. "2.2.0").

.PARAMETER ReleaseNotes
    One-line description of this release. Used in psd1 ReleaseNotes, ROADMAP
    description, and CHANGELOG entry.

.EXAMPLE
    .\tools\Bump-Version.ps1 -NewVersion "2.2.0" -ReleaseNotes "Fleet mode and multi-subscription support"

.EXAMPLE
    .\tools\Bump-Version.ps1 -NewVersion "2.2.0" -ReleaseNotes "Fleet mode" -WhatIf
#>
[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$NewVersion,

    [Parameter(Mandatory)]
    [string]$ReleaseNotes
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$root = Split-Path $PSScriptRoot -Parent

# ── Detect old version ────────────────────────────────────────────────────────
$psd1Path    = Join-Path $root "AzVMAvailability\AzVMAvailability.psd1"
$psd1Content = Get-Content $psd1Path -Raw
if ($psd1Content -notmatch "ModuleVersion\s*=\s*'([^']+)'") {
    throw "Could not detect current ModuleVersion from $psd1Path"
}
$OldVersion = $Matches[1]

if ($OldVersion -eq $NewVersion) {
    throw "NewVersion '$NewVersion' is the same as current version '$OldVersion'. Nothing to do."
}

Write-Host ""
Write-Host "  Version bump: $OldVersion → $NewVersion" -ForegroundColor Cyan
Write-Host "  Release notes: $ReleaseNotes" -ForegroundColor Cyan
Write-Host ""

$changes = 0
$skipped = 0

# ── Helper: replace pattern in file ──────────────────────────────────────────
function Update-File {
    param(
        [string]$Path,
        [string]$Pattern,      # regex
        [string]$Replacement,  # literal replacement string (NOT regex)
        [string]$Label
    )
    $content = Get-Content $Path -Raw
    if ($content -notmatch $Pattern) {
        Write-Host "  ⚠️  SKIPPED [$Label] — pattern not found in $(Split-Path $Path -Leaf)" -ForegroundColor Yellow
        $script:skipped++
        return
    }
    $newContent = [regex]::Replace($content, $Pattern, $Replacement)
    if ($PSCmdlet.ShouldProcess($Path, $Label)) {
        # Preserve original line endings; -NoNewline prevents extra trailing newline
        [System.IO.File]::WriteAllText($Path, $newContent)
        Write-Host "  ✅ $Label" -ForegroundColor Green
        $script:changes++
    } else {
        Write-Host "  [WhatIf] $Label" -ForegroundColor DarkGray
    }
}

# ── 1. ps1 — .NOTES Version ──────────────────────────────────────────────────
$ps1Path = Join-Path $root "Get-AzVMAvailability.ps1"
Update-File $ps1Path `
    "(?m)(    Version:\s+)$([regex]::Escape($OldVersion))" `
    "`${1}$NewVersion" `
    ".NOTES Version in Get-AzVMAvailability.ps1"

# ── 2. ps1 — `$ScriptVersion variable ────────────────────────────────────────
Update-File $ps1Path `
    '(\$ScriptVersion\s*=\s*")[^"]+(")'  `
    "`${1}$NewVersion`${2}" `
    '$ScriptVersion in Get-AzVMAvailability.ps1'

# ── 3. psd1 — ModuleVersion ───────────────────────────────────────────────────
Update-File $psd1Path `
    "(ModuleVersion\s*=\s*')[^']+(')" `
    "`${1}$NewVersion`${2}" `
    "ModuleVersion in AzVMAvailability.psd1"

# ── 4. psd1 — ReleaseNotes ────────────────────────────────────────────────────
Update-File $psd1Path `
    "(ReleaseNotes\s*=\s*')[^']*(')" `
    "`${1}v${NewVersion}: $ReleaseNotes`${2}" `
    "ReleaseNotes in AzVMAvailability.psd1"

# ── 5. README — Version badge ─────────────────────────────────────────────────
$readmePath = Join-Path $root "README.md"
Update-File $readmePath `
    "Version-$([regex]::Escape($OldVersion))-brightgreen" `
    "Version-$NewVersion-brightgreen" `
    "Version badge in README.md"

# ── 6. README — Console output "wrapper vX.Y.Z" (optional) ───────────────────
$readmeContent = Get-Content $readmePath -Raw
if ($readmeContent -match "wrapper v$([regex]::Escape($OldVersion))") {
    Update-File $readmePath `
        "wrapper v$([regex]::Escape($OldVersion))" `
        "wrapper v$NewVersion" `
        "Console output example in README.md"
} else {
    Write-Host "  ─  [Console output in README] Not present — skipping" -ForegroundColor DarkGray
}

# ── 7. DEMO-GUIDE — **Version:** line ────────────────────────────────────────
$demoPath = Join-Path $root "demo\DEMO-GUIDE.md"
Update-File $demoPath `
    "(\*\*Version:\*\*\s*)$([regex]::Escape($OldVersion))" `
    "`${1}$NewVersion" `
    "Version in demo/DEMO-GUIDE.md"

# ── 8. ROADMAP — Current Release header ──────────────────────────────────────
$roadmapPath = Join-Path $root "ROADMAP.md"
Update-File $roadmapPath `
    "(## Current Release: v)$([regex]::Escape($OldVersion))" `
    "`${1}$NewVersion" `
    "Current Release header in ROADMAP.md"

# ── 9a. ROADMAP — Release description line ───────────────────────────────────
Update-File $roadmapPath `
    "(>\s*\*\*v)$([regex]::Escape($OldVersion))(:\*\*)[^\n]+" `
    "`${1}${NewVersion}`${2} $ReleaseNotes. See [CHANGELOG.md](CHANGELOG.md) for details." `
    "Release description in ROADMAP.md"

# ── 9b. ROADMAP — (In Progress) → (Released) for new version if present ──────
$roadmapContent = Get-Content $roadmapPath -Raw
$inProgressPattern = "## Version $([regex]::Escape($NewVersion)) \(In Progress\)"
if ($roadmapContent -match $inProgressPattern) {
    Update-File $roadmapPath `
        $inProgressPattern `
        "## Version $NewVersion (Released)" `
        "ROADMAP (In Progress) → (Released) for v$NewVersion"
} else {
    Write-Host "  ─  [ROADMAP In Progress section] No v$NewVersion section found — skipping" -ForegroundColor DarkGray
}

# ── 10. CHANGELOG — Insert new versioned section ─────────────────────────────
$changelogPath = Join-Path $root "CHANGELOG.md"
$today = Get-Date -Format "yyyy-MM-dd"

$changelogContent = Get-Content $changelogPath -Raw

if ($changelogContent -match '(?m)^## \[Unreleased\]') {
    # Convert [Unreleased] header to the new versioned section
    $label = "CHANGELOG [Unreleased] → [$NewVersion]"
    Update-File $changelogPath `
        '(?m)^## \[Unreleased\]([^\n]*)' `
        "## [$NewVersion] — $today" `
        $label
    # Reload and prepend a fresh [Unreleased] section
    if ($PSCmdlet.ShouldProcess($changelogPath, "CHANGELOG add new [Unreleased] section")) {
        $updated = Get-Content $changelogPath -Raw
        $firstSection = $updated.IndexOf("`n## [")
        if ($firstSection -ge 0) {
            $withUnreleased = $updated.Insert($firstSection + 1, "## [Unreleased]`n`n")
            [System.IO.File]::WriteAllText($changelogPath, $withUnreleased)
            Write-Host "  ✅ CHANGELOG — added fresh [Unreleased] section" -ForegroundColor Green
            $script:changes++
        }
    }
} else {
    # No [Unreleased] section — insert a new versioned section before the first ## [
    if ($PSCmdlet.ShouldProcess($changelogPath, "CHANGELOG insert new [$NewVersion] section")) {
        $firstSection = $changelogContent.IndexOf("`n## [")
        if ($firstSection -lt 0) {
            Write-Host "  ⚠️  SKIPPED [CHANGELOG] — could not locate insertion point" -ForegroundColor Yellow
            $script:skipped++
        } else {
            $newSection = "## [$NewVersion] — $today`n`n### Changed`n- $ReleaseNotes`n`n"
            $newContent = $changelogContent.Insert($firstSection + 1, $newSection)
            [System.IO.File]::WriteAllText($changelogPath, $newContent)
            Write-Host "  ✅ CHANGELOG — inserted ## [$NewVersion] — $today" -ForegroundColor Green
            $script:changes++
        }
    } else {
        Write-Host "  [WhatIf] CHANGELOG — insert ## [$NewVersion] — $today" -ForegroundColor DarkGray
    }
}

# ── Summary ───────────────────────────────────────────────────────────────────
Write-Host ""
if ($WhatIfPreference) {
    Write-Host "  WhatIf mode — no files were changed." -ForegroundColor DarkGray
} else {
    Write-Host "  Done. $changes location(s) updated, $skipped skipped." -ForegroundColor Cyan
    if ($skipped -gt 0) {
        Write-Host "  Review skipped items above — they may indicate the pattern has changed." -ForegroundColor Yellow
    }
}
Write-Host ""
