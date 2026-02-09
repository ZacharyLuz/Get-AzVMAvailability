<#
.SYNOPSIS
    Pre-commit validation script for Get-AzVMAvailability.
.DESCRIPTION
    Runs four checks in sequence: syntax validation, PSScriptAnalyzer linting,
    Pester tests, and an AI-comment pattern scan. Run this before every commit.

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
Write-Host "[1/4] Syntax Check" -ForegroundColor Yellow
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
Write-Host "[2/4] PSScriptAnalyzer" -ForegroundColor Yellow
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
Write-Host "[3/4] Pester Tests" -ForegroundColor Yellow
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
Write-Host "[4/4] AI Comment Pattern Scan" -ForegroundColor Yellow
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
