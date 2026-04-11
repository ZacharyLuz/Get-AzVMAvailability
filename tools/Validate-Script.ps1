<#
.SYNOPSIS
    Pre-commit validation script for Get-AzVMAvailability.
.DESCRIPTION
    Runs seven checks in sequence: syntax validation, PSScriptAnalyzer linting,
    Pester tests, AI-comment pattern scan, version consistency, gh CLI
    anti-pattern detection in tools/ scripts, and module import validation.
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

# Log output to tools/logs/
$logDir = Join-Path $PSScriptRoot 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$timestamp = Get-Date -Format 'yyyy-MM-dd-HHmmss'
$logFile = Join-Path $logDir "validate-$timestamp.log"
$transcriptStarted = $false
try {
    Start-Transcript -Path $logFile -Append -ErrorAction Stop | Out-Null
    $transcriptStarted = $true
}
catch {
    Write-Verbose "Transcript could not be started: $($_.Exception.Message)"
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host " GET-AZVMAVAILABILITY VALIDATION" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# ── Check 1: Syntax Validation ──────────────────────────────────────
Write-Host "[1/7] Syntax Check" -ForegroundColor Yellow
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
Write-Host "[2/7] PSScriptAnalyzer" -ForegroundColor Yellow
$hasAnalyzer = Get-Module -ListAvailable PSScriptAnalyzer -ErrorAction SilentlyContinue
if (-not $hasAnalyzer) {
    Write-Host "  SKIP  PSScriptAnalyzer not installed (Install-Module PSScriptAnalyzer)" -ForegroundColor DarkYellow
}
else {
    # Lint main script + tools scripts; dev/ excluded (experimental code)
    $lintTargets = @($mainScript) + (Get-ChildItem (Join-Path $repoRoot 'tools') -Filter '*.ps1' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty FullName)
    $issues = @()
    foreach ($target in $lintTargets) {
        $analyzerParams = @{ Path = $target; Severity = @('Error', 'Warning') }
        if (Test-Path $settingsFile) { $analyzerParams.Settings = $settingsFile }
        $issues += Invoke-ScriptAnalyzer @analyzerParams
    }
    if ($issues.Count -eq 0) {
        Write-Host "  PASS  No warnings or errors ($($lintTargets.Count) file(s) checked)" -ForegroundColor Green
    }
    else {
        Write-Host "  FAIL  $($issues.Count) issue(s) found:" -ForegroundColor Red
        foreach ($issue in $issues) {
            $relPath = [System.IO.Path]::GetRelativePath($repoRoot, $issue.ScriptPath)
            Write-Host "         $relPath line $($issue.Line): [$($issue.Severity)] $($issue.RuleName) - $($issue.Message)" -ForegroundColor Red
        }
        $failCount++
    }
}

# ── Check 3: Pester Tests ──────────────────────────────────────────
Write-Host "[3/7] Pester Tests" -ForegroundColor Yellow
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
        $unitTests = Get-ChildItem (Join-Path $testsDir '*.Tests.ps1') | Where-Object Name -ne 'Integration.Tests.ps1'
        $pesterConfig = New-PesterConfiguration
        $pesterConfig.Run.Path = $unitTests.FullName
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
Write-Host "[4/7] AI Comment Pattern Scan" -ForegroundColor Yellow
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
Write-Host "[5/7] Version Consistency" -ForegroundColor Yellow
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
        try {
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

            # Check README sample console output (e.g. GET-AZVMAVAILABILITY v1.12.2)
            if ($readmeContent -match 'GET-AZVMAVAILABILITY v([\d.]+)') {
                $readmeSampleVer = $matches[1]
                if ($readmeSampleVer -ne $scriptVer) {
                    $versionMismatches += "README.md sample output: v$readmeSampleVer"
                }
            }
            else {
                $versionMismatches += "README.md: sample output version pattern not found"
            }
        }
        catch {
            $versionMismatches += "README.md: failed to read — $($_.Exception.Message)"
        }
    }
    else {
        $versionMismatches += "README.md: file not found"
    }

    # Check CHANGELOG has an entry for this version
    $changelogPath = Join-Path $repoRoot 'CHANGELOG.md'
    if (Test-Path $changelogPath) {
        try {
            $changelogContent = Get-Content $changelogPath -Raw -ErrorAction Stop
            if ($changelogContent -notmatch [regex]::Escape("[$scriptVer]")) {
                $versionMismatches += "CHANGELOG.md: no [$scriptVer] entry"
            }
        }
        catch {
            $versionMismatches += "CHANGELOG.md: failed to read — $($_.Exception.Message)"
        }
    }
    else {
        $versionMismatches += "CHANGELOG.md: file not found"
    }

    # Check ROADMAP Current Release
    $roadmapPath = Join-Path $repoRoot 'ROADMAP.md'
    if (Test-Path $roadmapPath) {
        try {
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
        catch {
            $versionMismatches += "ROADMAP.md: failed to read — $($_.Exception.Message)"
        }
    }
    else {
        $versionMismatches += "ROADMAP.md: file not found"
    }

    # Check demo/DEMO-GUIDE.md version header
    $demoGuidePath = Join-Path $repoRoot 'demo' 'DEMO-GUIDE.md'
    if (Test-Path $demoGuidePath) {
        try {
            $demoContent = Get-Content $demoGuidePath -Raw -ErrorAction Stop
            if ($demoContent -match '\*\*Version:\*\*\s*([\d.]+)') {
                $demoVer = $matches[1]
                if ($demoVer -ne $scriptVer) {
                    $versionMismatches += "demo/DEMO-GUIDE.md Version: $demoVer"
                }
            }
            else {
                $versionMismatches += "demo/DEMO-GUIDE.md: Version header pattern not found"
            }
        }
        catch {
            $versionMismatches += "demo/DEMO-GUIDE.md: failed to read — $($_.Exception.Message)"
        }
    }

    # Check AzVMAvailability/AzVMAvailability.psd1 ModuleVersion
    # Import-PowerShellDataFile is used instead of regex so the check is robust
    # to whitespace, quote style, and comment variations in the manifest.
    $psd1Path = Join-Path $repoRoot 'AzVMAvailability' 'AzVMAvailability.psd1'
    if (Test-Path $psd1Path) {
        try {
            $psd1Data = Import-PowerShellDataFile -Path $psd1Path -ErrorAction Stop
            $psd1Ver  = $psd1Data.ModuleVersion
            if ($null -eq $psd1Ver) {
                $versionMismatches += "${psd1Path}: ModuleVersion key not found"
            }
            elseif ($psd1Ver -ne $scriptVer) {
                $versionMismatches += "$psd1Path ModuleVersion: $psd1Ver"
            }
        }
        catch {
            $versionMismatches += "${psd1Path}: failed to read — $($_.Exception.Message)"
        }
    }
    else {
        $versionMismatches += "${psd1Path}: file not found"
    }

    # Scan git-tracked .md files under docs/ for backtick-wrapped version literals.
    # This catches prose examples (e.g. `1.10.2`) that weren't in the explicit list above.
    # Uses git ls-files instead of Get-ChildItem so only committed/staged files are scanned —
    # local scratch notes under docs/ cannot trigger false version-consistency failures.
    # Excludes: CHANGELOG.md (intentionally full of old versions), gitignored SESSION-HANDOFF
    # files (ephemeral session snapshots), and internal trackers with historical version data.
    $ignoredDocFiles    = @('CHANGELOG.md', 'copilot-review-log.md', 'Gemini Code Review March 2026.md', 'REMEDIATION-PROGRESS.md')
    $ignoredDocPatterns = @('SESSION-HANDOFF-*.md')
    $versionPattern     = [regex]'`(\d+\.\d+\.\d+)`'
    $docsDir            = Join-Path $repoRoot 'docs'
    if (Test-Path $docsDir) {
        $gitCmd = Get-Command git -ErrorAction SilentlyContinue
        $rawFiles = if ($gitCmd) {
            $trackedFiles = & git -C $repoRoot ls-files -- 'docs/' 2>$null
            if ($LASTEXITCODE -ne 0) {
                Write-Host "  WARN  git ls-files failed (not a git worktree?); falling back to Get-ChildItem for docs scan (untracked files may trigger false positives)" -ForegroundColor Yellow
                Get-ChildItem $docsDir -Recurse -Include '*.md' -ErrorAction SilentlyContinue
            } else {
                $trackedFiles |
                    Where-Object { $_ -match '\.md$' } |
                    ForEach-Object { Join-Path $repoRoot $_ } |
                    Get-Item -ErrorAction SilentlyContinue
            }
        } else {
            Write-Host "  WARN  git not found; falling back to Get-ChildItem for docs scan (untracked files may trigger false positives)" -ForegroundColor Yellow
            Get-ChildItem $docsDir -Recurse -Include '*.md' -ErrorAction SilentlyContinue
        }
        $mdFiles = $rawFiles | Where-Object {
                $fname = $_.Name
                $ignoredDocFiles -notcontains $fname -and
                -not ($ignoredDocPatterns | Where-Object { $fname -like $_ })
            }
        foreach ($mdFile in $mdFiles) {
            $mdContent = Get-Content $mdFile.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $mdContent) { continue }
            $hits = $versionPattern.Matches($mdContent)
            foreach ($hit in $hits) {
                $hitVer = $hit.Groups[1].Value
                if ($hitVer -ne $scriptVer) {
                    $relPath = [System.IO.Path]::GetRelativePath($repoRoot, $mdFile.FullName)
                    $versionMismatches += "$relPath contains hardcoded version example ``$hitVer`` (expected ``$scriptVer`` or remove the literal)"
                }
            }
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

# ── Check 6: gh CLI Anti-Pattern Scan ──────────────────────────────
Write-Host "[6/7] gh CLI Anti-Pattern Scan" -ForegroundColor Yellow
$toolsDir = Join-Path $repoRoot 'tools'
$ghHits = @()
if (Test-Path $toolsDir) {
    $toolScripts = Get-ChildItem $toolsDir -Filter '*.ps1' -ErrorAction SilentlyContinue
    foreach ($ts in $toolScripts) {
        $tsLines = Get-Content $ts.FullName
        for ($i = 0; $i -lt $tsLines.Count; $i++) {
            $ln = $tsLines[$i]
            # Skip lines that are comments, Write-Host examples, or POST/PUT/PATCH/DELETE mutations
            if ($ln -match '^\s*#' -or $ln -match 'Write-Host' -or $ln -match '--(method|input)\s+(POST|PUT|PATCH|DELETE)' -or $ln -match '-X\s+(POST|PUT|PATCH|DELETE)') {
                continue
            }
            # Skip single-resource GETs (no query string = not a list endpoint),
            # traffic/popular endpoints (GitHub caps these, not paginated),
            # and lines that implement manual pagination via page= parameter.
            # NOTE: This heuristic intentionally uses "has ?" as a proxy for list endpoints.
            # It won't catch every no-query-string list endpoint (e.g. /comments) — that's
            # acceptable because the copilot-instructions.md rules and Copilot reviewer
            # provide the authoritative check. This scanner is a fast safety net, not exhaustive.
            if ($ln -match '\bgh\s+api\b' -and ($ln -match '/traffic/' -or $ln -match '[?&]page=' -or ($ln -notmatch '\?' -and $ln -notmatch '--paginate'))) {
                continue
            }
            # Flag: gh api list call without --paginate (has ? query string = list endpoint)
            # Exclude calls that filter to a specific resource (e.g. ?head=owner:branch returns 0-1 results)
            # NOTE: This check does not detect missing $LASTEXITCODE checks (multi-line analysis).
            # That rule is enforced by copilot-instructions.md + Copilot reviewer, not this scanner.
            if ($ln -match '\bgh\s+api\b' -and $ln -match '\?' -and $ln -notmatch '--paginate' -and $ln -notmatch 'graphql' -and $ln -notmatch '\?head=') {
                $ghHits += "$($ts.Name):$($i+1) — gh api list call missing --paginate"
            }
            # Flag: stderr suppressed with 2>$null on gh commands
            if ($ln -match '\bgh\s+(api|pr|issue)\b' -and $ln -match '2>\s*\$null') {
                $ghHits += "$($ts.Name):$($i+1) — gh command uses 2>`$null (use 2>&1 + check `$LASTEXITCODE)"
            }
        }
    }
    if ($ghHits.Count -eq 0) {
        Write-Host "  PASS  No gh CLI anti-patterns in tools/" -ForegroundColor Green
    }
    else {
        Write-Host "  FAIL  $($ghHits.Count) gh CLI anti-pattern(s) found:" -ForegroundColor Red
        foreach ($hit in $ghHits) {
            Write-Host "         $hit" -ForegroundColor Red
        }
        $failCount++
    }
}
else {
    Write-Host "  SKIP  tools/ directory not found" -ForegroundColor DarkYellow
}

# ── Check 7: Module Import Validation ──────────────────────────────
Write-Host "[7/7] Module Import Validation" -ForegroundColor Yellow
$moduleDir = Join-Path $repoRoot 'AzVMAvailability'
if (Test-Path (Join-Path $moduleDir 'AzVMAvailability.psd1')) {
    try {
        Remove-Module AzVMAvailability -ErrorAction SilentlyContinue
        Import-Module $moduleDir -Force -DisableNameChecking -ErrorAction Stop
        $mod = Get-Module AzVMAvailability
        $exported = @($mod.ExportedFunctions.Keys)
        if ($exported.Count -eq 1 -and $exported[0] -eq 'Get-AzVMAvailability') {
            Write-Host "  PASS  Module v$($mod.Version) loaded — exports: $($exported -join ', ')" -ForegroundColor Green
        }
        else {
            Write-Host "  FAIL  Module exports unexpected functions: $($exported -join ', ')" -ForegroundColor Red
            Write-Host "         Expected: Get-AzVMAvailability only" -ForegroundColor Red
            $failCount++
        }
        Remove-Module AzVMAvailability -ErrorAction SilentlyContinue
    }
    catch {
        Write-Host "  FAIL  Module import failed: $($_.Exception.Message)" -ForegroundColor Red
        $failCount++
    }
}
else {
    Write-Host "  SKIP  AzVMAvailability module not found at $moduleDir" -ForegroundColor DarkYellow
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

if ($transcriptStarted) {
    Stop-Transcript | Out-Null
    Write-Host "Log: $logFile" -ForegroundColor DarkGray
}
elseif (Test-Path $logFile) {
    Write-Host "Log: $logFile" -ForegroundColor DarkGray
}
else {
    Write-Host "Log: disabled (transcript did not start)" -ForegroundColor DarkYellow
}

exit $failCount
