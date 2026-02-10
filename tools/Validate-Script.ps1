<#
.SYNOPSIS
    Pre-commit validation script for Get-AzVMAvailability.
.DESCRIPTION
    Runs five checks in sequence: syntax validation, PSScriptAnalyzer linting,
    Pester tests, AI-comment pattern scan, and version consistency.
    Run this before every commit.

    Exit code 0 = all checks passed. Non-zero = at least one check failed.
.EXAMPLE
    .\tools\Validate-Script.ps1
.EXAMPLE
    .\tools\Validate-Script.ps1 -SkipTests
#>
[CmdletBinding()]
param(
    [switch]$SkipTests
)

$ErrorActionPreference = 'Continue'
$repoRoot = Split-Path -Parent $PSScriptRoot
$mainScript = Join-Path $repoRoot 'Get-AzVMAvailability.ps1'
$settingsFile = Join-Path $repoRoot 'PSScriptAnalyzerSettings.psd1'
$testsDir = Join-Path $repoRoot 'tests'
$failCount = 0

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " GET-AZVMAVAILABILITY VALIDATION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# ── Check 1: Syntax Validation ──────────────────────────────────────
Write-Host "[1/5] Syntax Check" -ForegroundColor Yellow
try {
    $content = Get-Content $mainScript -Raw -ErrorAction Stop
    [scriptblock]::Create($content) | Out-Null
    Write-Host "  PASS  Script parses without syntax errors" -ForegroundColor Green
}
catch {
    Write-Host "  FAIL  Syntax error: $($_.Exception.Message)" -ForegroundColor Red
    $failCount++
}

# ── Check 2: PSScriptAnalyzer ───────────────────────────────────────
Write-Host "[2/5] PSScriptAnalyzer" -ForegroundColor Yellow
$hasAnalyzer = Get-Module -ListAvailable PSScriptAnalyzer -ErrorAction SilentlyContinue
if (-not $hasAnalyzer) {
    Write-Host "  SKIP  PSScriptAnalyzer not installed (Install-Module PSScriptAnalyzer)" -ForegroundColor DarkYellow
}
else {
    $analyzerParams = @{ Path = $mainScript; Severity = @('Error', 'Warning') }
    if (Test-Path $settingsFile) {
        $analyzerParams.Settings = $settingsFile
    }
    $issues = Invoke-ScriptAnalyzer @analyzerParams
    if ($issues.Count -eq 0) {
        Write-Host "  PASS  No warnings or errors" -ForegroundColor Green
    }
    else {
        Write-Host "  FAIL  $($issues.Count) issue(s) found:" -ForegroundColor Red
        foreach ($issue in $issues) {
            Write-Host "         Line $($issue.Line): [$($issue.Severity)] $($issue.RuleName) - $($issue.Message)" -ForegroundColor Red
        }
        $failCount++
    }
}

# ── Check 3: Pester Tests ──────────────────────────────────────────
Write-Host "[3/5] Pester Tests" -ForegroundColor Yellow
if ($SkipTests) {
    Write-Host "  SKIP  -SkipTests specified" -ForegroundColor DarkYellow
}
else {
    $hasPester = Get-Module -ListAvailable Pester -ErrorAction SilentlyContinue |
    Where-Object { $_.Version.Major -ge 5 }
    if (-not $hasPester) {
        Write-Host "  SKIP  Pester v5+ not installed (Install-Module Pester -Force -SkipPublisherCheck)" -ForegroundColor DarkYellow
    }
    else {
        Import-Module Pester -MinimumVersion 5.0 -ErrorAction Stop
        $pesterConfig = New-PesterConfiguration
        $pesterConfig.Run.Path = $testsDir
        $pesterConfig.Run.PassThru = $true
        $pesterConfig.Output.Verbosity = 'None'
        $results = Invoke-Pester -Configuration $pesterConfig
        if ($results.FailedCount -eq 0) {
            Write-Host "  PASS  $($results.PassedCount) test(s) passed" -ForegroundColor Green
        }
        else {
            Write-Host "  FAIL  $($results.FailedCount) of $($results.TotalCount) test(s) failed" -ForegroundColor Red
            $failCount++
        }
    }
}

# ── Check 4: AI Comment Pattern Scan ───────────────────────────────
Write-Host "[4/5] AI Comment Pattern Scan" -ForegroundColor Yellow
$aiPatterns = @(
    @{ Pattern = '# Must be (after|before|placed)'; Desc = 'Instructional placement comment' }
    @{ Pattern = '# Note:.*see (below|above)'; Desc = 'Cross-reference instruction' }
    @{ Pattern = '# This (ensures|makes sure)'; Desc = 'Explanatory narration' }
    @{ Pattern = '# Handle potential'; Desc = 'Defensive narration' }
    @{ Pattern = '# Don''t populate'; Desc = 'Instructional comment' }
)
$lines = Get-Content $mainScript
$aiHits = @()
for ($i = 0; $i -lt $lines.Count; $i++) {
    foreach ($p in $aiPatterns) {
        if ($lines[$i] -match $p.Pattern) {
            $aiHits += [PSCustomObject]@{
                Line    = $i + 1
                Type    = $p.Desc
                Content = $lines[$i].Trim()
            }
        }
    }
}
if ($aiHits.Count -eq 0) {
    Write-Host "  PASS  No AI-pattern comments detected" -ForegroundColor Green
}
else {
    Write-Host "  WARN  $($aiHits.Count) AI-pattern comment(s) found:" -ForegroundColor DarkYellow
    foreach ($hit in $aiHits) {
        Write-Host "         Line $($hit.Line): $($hit.Type)" -ForegroundColor DarkYellow
        Write-Host "           $($hit.Content)" -ForegroundColor Gray
    }
    # Warning only — does not increment fail count
}

# ── Check 5: Version Consistency ────────────────────────────────────
Write-Host "[5/5] Version Consistency" -ForegroundColor Yellow
$versionMismatches = @()

# Extract $ScriptVersion from the main script (source of truth)
if ($content -match '\$ScriptVersion\s*=\s*["'']([\d.]+)["'']') {
    $scriptVer = $matches[1]

    # Check .NOTES Version in comment-based help
    if ($content -match '\.NOTES[\s\S]*?Version\s*:\s*([\d.]+)') {
        $notesVer = $matches[1]
        if ($notesVer -ne $scriptVer) {
            $versionMismatches += ".NOTES Version: $notesVer"
        }
    }
    else {
        $versionMismatches += ".NOTES: Version pattern not found"
    }

    # Check README badge
    $readmePath = Join-Path $repoRoot 'README.md'
    if (Test-Path $readmePath) {
        $readmeContent = Get-Content $readmePath -Raw -ErrorAction Stop
        if ($readmeContent -match 'img\.shields\.io/badge/Version-([\d.]+)') {
            $readmeVer = $matches[1]
            if ($readmeVer -ne $scriptVer) {
                $versionMismatches += "README.md badge: $readmeVer"
            }
        }
        else {
            $versionMismatches += "README.md: version badge pattern not found"
        }
    }

    # Check CHANGELOG has an entry for this version
    $changelogPath = Join-Path $repoRoot 'CHANGELOG.md'
    if (Test-Path $changelogPath) {
        $changelogContent = Get-Content $changelogPath -Raw -ErrorAction Stop
        if ($changelogContent -notmatch [regex]::Escape("[$scriptVer]")) {
            $versionMismatches += "CHANGELOG.md: no [$scriptVer] entry"
        }
    }

    # Check ROADMAP Current Release
    $roadmapPath = Join-Path $repoRoot 'ROADMAP.md'
    if (Test-Path $roadmapPath) {
        $roadmapContent = Get-Content $roadmapPath -Raw -ErrorAction Stop
        if ($roadmapContent -match 'Current Release:\s*v([\d.]+)') {
            $roadmapVer = $matches[1]
            if ($roadmapVer -ne $scriptVer) {
                $versionMismatches += "ROADMAP.md Current Release: v$roadmapVer"
            }
        }
        else {
            $versionMismatches += "ROADMAP.md: Current Release pattern not found"
        }
    }

    if ($versionMismatches.Count -eq 0) {
        Write-Host "  PASS  All version references match v$scriptVer" -ForegroundColor Green
    }
    else {
        Write-Host "  FAIL  \$ScriptVersion is v$scriptVer but mismatches found:" -ForegroundColor Red
        foreach ($m in $versionMismatches) {
            Write-Host "         $m" -ForegroundColor Red
        }
        $failCount++
    }
}
else {
    Write-Host "  SKIP  Could not find \$ScriptVersion in script" -ForegroundColor DarkYellow
}

# ── Summary ─────────────────────────────────────────────────────────
Write-Host "`n========================================" -ForegroundColor Cyan
if ($failCount -eq 0) {
    Write-Host " ALL CHECKS PASSED" -ForegroundColor Green
}
else {
    Write-Host " $failCount CHECK(S) FAILED" -ForegroundColor Red
}
Write-Host "========================================`n" -ForegroundColor Cyan

exit $failCount
