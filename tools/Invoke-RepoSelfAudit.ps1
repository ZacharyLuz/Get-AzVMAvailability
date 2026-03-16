<#
.SYNOPSIS
    Repository self-audit quality gate for Get-AzVMAvailability-style PowerShell repos.
.DESCRIPTION
    Scans repository hygiene, GitHub standards files, PowerShell script quality
    hotspots, and emits Markdown + JSON + CSV reports suitable for CI gating and
    trend tracking over time.

    Outputs to artifacts/audit/:
      audit-report.md     Human-readable report with Top 5 Changes, Already Strong,
                          and Files to Remove sections.
      audit-report.json   Machine-readable full findings.
      findings.csv        All findings as CSV for delta diffing.
      function-index.csv  Inventory of all functions with line numbers.
      hotspots.csv        All pattern hotspot hits with line references.
      analyzer.csv        PSScriptAnalyzer findings (if module available).
      tracked-files.txt   Complete list of git-tracked files at time of run.

.PARAMETER RepoRoot
    Root directory of the repository. Defaults to current directory.
.PARAMETER PrimaryScript
    Relative path to the primary script to analyze. Defaults to Get-AzVMAvailability.ps1.
.PARAMETER OutputDir
    Relative path for output artifacts. Defaults to artifacts/audit.
.PARAMETER FailOnCritical
    If specified, exits with error when critical findings exceed MaxAllowedCritical.
.PARAMETER MaxAllowedCritical
    Maximum allowed critical findings before FailOnCritical triggers. Default 0.
.NOTES
    Requires : PowerShell 7+
    Optional : PSScriptAnalyzer module (Install-Module PSScriptAnalyzer -Scope CurrentUser)
    Version  : 1.0.0
    Fix log  : Approved verbs used throughout (Invoke-, Find-, Get-, New-, Test-).
               Artifacts/ directory excluded from hygiene scan to prevent false positives
               on generated CSV/XLSX outputs.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepoRoot = (Get-Location).Path,

    [Parameter()]
    [string]$PrimaryScript = 'Get-AzVMAvailability.ps1',

    [Parameter()]
    [string]$OutputDir = 'artifacts/audit',

    [Parameter()]
    [switch]$FailOnCritical,

    [Parameter()]
    [int]$MaxAllowedCritical = 0
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Helper Functions

function New-AuditResult {
    <#
    .SYNOPSIS
        Creates a structured audit finding object.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Creates in-memory object only, no system state change')]
    param(
        [string]$Section,
        [string]$Rating,
        [string]$Finding,
        [string]$File           = '',
        [int]$Line              = 0,
        [string]$WhyItMatters   = '',
        [string]$Recommendation = '',
        [string]$Severity       = 'Info'
    )
    [pscustomobject]@{
        Section        = $Section
        Rating         = $Rating
        Severity       = $Severity
        File           = $File
        Line           = $Line
        Finding        = $Finding
        WhyItMatters   = $WhyItMatters
        Recommendation = $Recommendation
    }
}

function Get-RepoFiles {
    <#
    .SYNOPSIS
        Returns all git-tracked files in the repository. Falls back to filesystem
        enumeration if git is unavailable.
    #>
    param([string]$Root)

    Push-Location $Root
    try {
        if ((Test-Path '.git') -and (Get-Command git -ErrorAction SilentlyContinue)) {
            try {
                $files = git ls-files 2>$null
                if ($LASTEXITCODE -eq 0 -and $files) {
                    return $files
                }
            }
            catch {
                Write-Verbose "git ls-files failed: $($_.Exception.Message)"
            }
        }
        return Get-ChildItem -Path $Root -Recurse -File | ForEach-Object {
            $_.FullName.Substring($Root.Length).TrimStart('\', '/')
        }
    }
    finally { Pop-Location }
}

function Test-StandardFiles {
    <#
    .SYNOPSIS
        Checks for required and recommended GitHub repository standard files.
    #>
    param([string[]]$Files)

    $required = @(
        'README.md', 'LICENSE', 'CHANGELOG.md', 'CONTRIBUTING.md'
    )
    $recommended = @(
        'CODE_OF_CONDUCT.md', 'SECURITY.md', '.gitignore',
        '.github/PULL_REQUEST_TEMPLATE.md', '.github/CODEOWNERS'
    )

    $out = [System.Collections.Generic.List[object]]::new()

    foreach ($r in $required) {
        if ($Files -notcontains $r) {
            $out.Add((New-AuditResult -Section 'Repository Structure & Standards' `
                -Rating 'Critical Gap' -Severity 'Critical' `
                -Finding "Missing required standard file: $r" -File $r `
                -WhyItMatters 'Core project metadata and contributor guidance are incomplete.' `
                -Recommendation "Add $r with project-specific content."))
        }
    }
    foreach ($r in $recommended) {
        if ($Files -notcontains $r) {
            $out.Add((New-AuditResult -Section 'Repository Structure & Standards' `
                -Rating 'Needs Work' -Severity 'Warning' `
                -Finding "Missing recommended file: $r" -File $r `
                -WhyItMatters 'Contributor experience and governance consistency are reduced.' `
                -Recommendation "Add $r to align with GitHub maintainer best practices."))
        }
    }

    $hasWorkflow = $Files -contains '.github/workflows/ci.yml' -or
                   ($Files | Where-Object { $_ -like '.github/workflows/*' })
    if ($hasWorkflow) {
        $out.Add((New-AuditResult -Section 'Repository Structure & Standards' `
            -Rating 'Strong' -Severity 'Info' `
            -Finding 'CI workflow detected under .github/workflows.' `
            -WhyItMatters 'Automated checks reduce regressions before merge.' `
            -Recommendation 'Keep CI required on protected branches.'))
    }
    else {
        $out.Add((New-AuditResult -Section 'Repository Structure & Standards' `
            -Rating 'Needs Work' -Severity 'Warning' `
            -Finding 'No GitHub Actions workflow detected.' `
            -WhyItMatters 'No automated gate for lint, tests, or validation on push.' `
            -Recommendation 'Add .github/workflows/ci.yml running Validate-Script.ps1 and this audit with -FailOnCritical.'))
    }

    return $out
}

function Find-HygieneRisks {
    <#
    .SYNOPSIS
        Scans tracked files for hygiene risks: session artifacts, binaries,
        and potential secret patterns.
    .NOTES
        Excludes the artifacts/ directory from pattern matching to prevent false
        positives on CSV/XLSX outputs generated by this script and Validate-Script.ps1.
    #>
    param([string]$Root, [string[]]$Files)

    $out = [System.Collections.Generic.List[object]]::new()

    $suspiciousNamePatterns = @(
        'HANDOFF', 'CONTEXT', 'CLAUDE', 'AGENTS', 'copilot-', '-handoff', '-context',
        'TODO', 'NOTES', 'SCRATCH', 'draft-', 'temp-', '_inspect_', 'debug-'
    )
    # Note: .csv and .xlsx are excluded from artifact pattern matching because
    # this repo generates those as intentional export outputs. The artifacts/
    # directory should be gitignored to prevent them from being tracked.
    $artifactPatterns = @(
        '\.log$', '\.tmp$', '\.bak$', '\.zip$', '\.exe$', '\.dll$',
        # Office/presentation files belong in OneDrive, not git
        '\.pptx$', '\.ppt$', '\.docx$', '\.doc$', '\.pdf$',
        # Media files (demo animations should be gitignored locally)
        '\.mp4$', '\.mov$', '\.webm$', '\.avi$', '\.gif$',
        # Additional archive formats
        '\.7z$', '\.tar$', '\.gz$', '\.rar$',
        # Python files — this is a pure PowerShell repo
        '\.py$', '\.pyc$'
    )

    foreach ($f in $Files) {
        # Skip generated output directories entirely
        if ($f -match '^artifacts/' -or $f -match '^output/' -or $f -match '^exports/') {
            continue
        }

        $name = [System.IO.Path]::GetFileName($f)

        foreach ($p in $suspiciousNamePatterns) {
            if ($name -match [regex]::Escape($p)) {
                $out.Add((New-AuditResult -Section 'Repository Hygiene & Artifacts' `
                    -Rating 'Needs Work' -Severity 'Warning' `
                    -Finding "Potential session/draft artifact committed: $f" -File $f `
                    -WhyItMatters 'Internal process artifacts can confuse users and clutter maintenance.' `
                    -Recommendation 'Remove from tracking via .gitignore or document purpose clearly.'))
                break
            }
        }

        foreach ($p in $artifactPatterns) {
            if ($f -match $p) {
                $out.Add((New-AuditResult -Section 'Repository Hygiene & Artifacts' `
                    -Rating 'Needs Work' -Severity 'Warning' `
                    -Finding "Potential generated/binary artifact tracked: $f" -File $f `
                    -WhyItMatters 'Generated files increase noise and cause merge conflicts.' `
                    -Recommendation 'Add to .gitignore unless intentionally versioned.'))
                break
            }
        }
    }

    # Lightweight secret heuristics — scan text files only
    $textFiles = $Files | Where-Object {
        $_ -match '\.(ps1|psm1|psd1|md|yml|yaml|json|txt)$' -and
        $_ -notmatch '^artifacts/'
    }
    $secretPatterns = @(
        "AKIA[0-9A-Z]{16}",
        "(?i)client_secret\s*[:=]\s*[`"'][^`"']+",
        "(?i)tenant[_-]?id\s*[:=]\s*[`"'][0-9a-f\-]{20,}",
        "(?i)subscription[_-]?id\s*[:=]\s*[`"'][0-9a-f\-]{20,}",
        "(?i)password\s*[:=]\s*[`"'][^`"']+",
        "(?i)connectionstring\s*[:=]\s*[`"'][^`"']+"
    )

    foreach ($tf in $textFiles) {
        $path = Join-Path $Root $tf
        if (-not (Test-Path $path)) { continue }
        try {
            $hits = Select-String -Path $path -Pattern $secretPatterns -AllMatches
            foreach ($h in $hits) {
                $out.Add((New-AuditResult -Section 'Repository Hygiene & Artifacts' `
                    -Rating 'Critical Gap' -Severity 'Critical' `
                    -Finding "Potential secret pattern in $tf" -File $tf -Line $h.LineNumber `
                    -WhyItMatters 'Credential exposure leads to account compromise and incident response.' `
                    -Recommendation 'Rotate affected credentials immediately. Purge from git history if confirmed.'))
            }
        }
        catch { Write-Verbose "Secret scan skipped for $tf : $_" }
    }

    return $out
}

function Invoke-PrimaryScriptAnalysis {
    <#
    .SYNOPSIS
        Analyzes the primary PowerShell script for quality hotspots, #Requires
        declarations, function inventory, and line count metrics.
    #>
    param([string]$Root, [string]$ScriptRelativePath)

    $out = [System.Collections.Generic.List[object]]::new()
    $scriptPath = Join-Path $Root $ScriptRelativePath

    if (-not (Test-Path $scriptPath)) {
        return @{
            Results       = @(New-AuditResult -Section 'PowerShell Standards & Idioms' `
                -Rating 'Critical Gap' -Severity 'Critical' `
                -Finding "Primary script not found: $ScriptRelativePath" `
                -File $ScriptRelativePath `
                -WhyItMatters 'Core quality checks cannot run.' `
                -Recommendation 'Fix path or ensure script is committed.')
            FunctionIndex = @()
            Hotspots      = @()
            LineCount     = 0
            FunctionCount = 0
        }
    }

    $lines     = Get-Content -Path $scriptPath
    $lineCount = $lines.Count

    # #Requires checks
    $reqVersion = Select-String -Path $scriptPath -Pattern '^\s*#Requires\s+-Version\s+([0-9.]+)' |
                  Select-Object -First 1
    $reqModules = Select-String -Path $scriptPath -Pattern '^\s*#Requires\s+-Modules?\s+(.+)$'

    if (-not $reqVersion) {
        $out.Add((New-AuditResult -Section 'PowerShell Standards & Idioms' `
            -Rating 'Needs Work' -Severity 'Warning' `
            -Finding 'Missing #Requires -Version declaration.' -File $ScriptRelativePath `
            -WhyItMatters 'Users get late runtime failures instead of immediate prerequisite validation.' `
            -Recommendation "Add '#Requires -Version 7.0' near top of script."))
    }
    if (-not $reqModules) {
        $out.Add((New-AuditResult -Section 'PowerShell Standards & Idioms' `
            -Rating 'Needs Work' -Severity 'Warning' `
            -Finding 'Missing #Requires -Modules declaration.' -File $ScriptRelativePath `
            -WhyItMatters 'Module dependency failures occur deep into execution.' `
            -Recommendation "Add '#Requires -Modules Az.Compute, Az.Resources'."))
    }

    # Function inventory
    $funcMatches = Select-String -Path $scriptPath -Pattern '^\s*function\s+([A-Za-z0-9\-_]+)\s*\{?' -AllMatches
    $funcCount   = ($funcMatches | Measure-Object).Count

    $out.Add((New-AuditResult -Section 'PowerShell Standards & Idioms' -Rating 'Info' -Severity 'Info' `
        -Finding "Script metrics: $lineCount lines, $funcCount functions." -File $ScriptRelativePath `
        -WhyItMatters 'High size/function count is a proxy for modularization pressure.' `
        -Recommendation 'Track this over time; split by responsibility when approaching v2.0.0 module conversion.'))

    if ($lineCount -gt 1500) {
        $out.Add((New-AuditResult -Section 'Scope & Separation of Concerns' `
            -Rating 'Critical Gap' -Severity 'Critical' `
            -Finding "Script exceeds 1500 lines ($lineCount lines)." -File $ScriptRelativePath `
            -WhyItMatters 'Large monoliths are harder to test, review, and refactor safely.' `
            -Recommendation 'Migrate to module layout with Public/Private functions (v2.0.0 roadmap item).'))
    }

    # Hotspot pattern inventory
    $patterns = @{
        'Write-Host'       = '^\s*Write-Host\b'
        'ArrayPlusEquals'  = '\+\='
        'ScriptScopeState' = '\$script:'
        'WhereObject'      = '\bWhere-Object\b'
        'TryCatch'         = '^\s*try\s*\{|^\s*catch\s*\{'
        'Throw'            = '\bthrow\b'
        'Exit'             = '^\s*exit\b'
        'Parallel'         = 'ForEach-Object\s+-Parallel|Start-ThreadJob'
    }

    foreach ($k in $patterns.Keys) {
        $hits  = Select-String -Path $scriptPath -Pattern $patterns[$k] -AllMatches
        $count = ($hits | Measure-Object).Count
        $out.Add((New-AuditResult -Section 'Performance & Optimization' -Rating 'Info' -Severity 'Info' `
            -Finding "$k occurrences: $count" -File $ScriptRelativePath `
            -WhyItMatters 'Hotspot counts help target refactor and performance work.' `
            -Recommendation 'Review high-count hotspots in context before the v2.0.0 module migration.'))
    }

    # Build CSV artifacts
    $funcInventory = $funcMatches | ForEach-Object {
        [pscustomobject]@{
            FunctionName = $_.Matches[0].Groups[1].Value
            Line         = $_.LineNumber
        }
    }
    $hotspotRows = foreach ($k in $patterns.Keys) {
        Select-String -Path $scriptPath -Pattern $patterns[$k] -AllMatches | ForEach-Object {
            [pscustomobject]@{
                Pattern    = $k
                LineNumber = $_.LineNumber
                Line       = $_.Line.Trim()
            }
        }
    }

    return @{
        Results       = $out
        FunctionIndex = $funcInventory
        Hotspots      = $hotspotRows
        LineCount     = $lineCount
        FunctionCount = $funcCount
    }
}

function Invoke-AvailableScriptAnalyzer {
    <#
    .SYNOPSIS
        Runs PSScriptAnalyzer if installed; emits a warning finding if not.
    #>
    param([string]$Root, [string]$ScriptRelativePath)

    $out        = [System.Collections.Generic.List[object]]::new()
    $scriptPath = Join-Path $Root $ScriptRelativePath
    $settings   = Join-Path $Root 'PSScriptAnalyzerSettings.psd1'

    if (-not (Get-Module -ListAvailable -Name PSScriptAnalyzer)) {
        $out.Add((New-AuditResult -Section 'PowerShell Standards & Idioms' `
            -Rating 'Needs Work' -Severity 'Warning' `
            -Finding 'PSScriptAnalyzer not installed — static analysis skipped.' `
            -WhyItMatters 'Static analysis findings may regress unnoticed without the module.' `
            -Recommendation 'Install-Module PSScriptAnalyzer -Scope CurrentUser'))
        return @{ Results = $out; Analyzer = @() }
    }

    $params = @{ Path = $scriptPath }
    if (Test-Path $settings) { $params['Settings'] = $settings }

    $an = Invoke-ScriptAnalyzer @params
    foreach ($a in $an) {
        $severity = switch ($a.Severity) {
            'Error'       { 'Critical' }
            'Warning'     { 'Warning'  }
            default       { 'Info'     }
        }
        $rating = if ($severity -eq 'Critical') { 'Critical Gap' } else { 'Needs Work' }
        $out.Add((New-AuditResult -Section 'PowerShell Standards & Idioms' `
            -Rating $rating -Severity $severity `
            -Finding "ScriptAnalyzer [$($a.RuleName)]: $($a.Message)" `
            -File $a.ScriptName -Line $a.Line `
            -WhyItMatters 'Violations reduce reliability, readability, or safety.' `
            -Recommendation 'Address finding or add justified suppression comment.'))
    }

    return @{ Results = $out; Analyzer = $an }
}

#endregion

#region Main

$start         = Get-Date
$fullOutputDir = Join-Path $RepoRoot $OutputDir
New-Item -ItemType Directory -Path $fullOutputDir -Force | Out-Null

$allFiles = Get-RepoFiles -Root $RepoRoot | Sort-Object
$results  = [System.Collections.Generic.List[object]]::new()

# Run all checks
Find-HygieneRisks -Root $RepoRoot -Files $allFiles      | ForEach-Object { $results.Add($_) }
Test-StandardFiles -Files $allFiles                      | ForEach-Object { $results.Add($_) }

$scriptAnalysis = Invoke-PrimaryScriptAnalysis -Root $RepoRoot -ScriptRelativePath $PrimaryScript
$scriptAnalysis.Results | ForEach-Object { $results.Add($_) }

$analyzerRun = Invoke-AvailableScriptAnalyzer -Root $RepoRoot -ScriptRelativePath $PrimaryScript
$analyzerRun.Results | ForEach-Object { $results.Add($_) }

# Ensure all 6 sections appear at least once
$sections = @(
    'Repository Hygiene & Artifacts',
    'Repository Structure & Standards',
    'PowerShell Standards & Idioms',
    'Usability & Intuitiveness',
    'Scope & Separation of Concerns',
    'Performance & Optimization'
)
foreach ($s in $sections) {
    if (-not ($results | Where-Object Section -eq $s)) {
        $results.Add((New-AuditResult -Section $s -Rating 'Needs Work' -Severity 'Warning' `
            -Finding 'No automated checks implemented for this section yet.' `
            -WhyItMatters 'Blind spots reduce trust in gate completeness.' `
            -Recommendation 'Extend this script to cover the section explicitly.'))
    }
}

# Aggregate counts
$criticalCount = ($results | Where-Object Severity -eq 'Critical' | Measure-Object).Count
$warningCount  = ($results | Where-Object Severity -eq 'Warning'  | Measure-Object).Count
$infoCount     = ($results | Where-Object Severity -eq 'Info'     | Measure-Object).Count

# Save machine-readable artifacts
$allFiles | Set-Content (Join-Path $fullOutputDir 'tracked-files.txt')
$results  | Export-Csv  (Join-Path $fullOutputDir 'findings.csv') -NoTypeInformation
$results  | ConvertTo-Json -Depth 8 | Set-Content (Join-Path $fullOutputDir 'audit-report.json')

if ($scriptAnalysis.FunctionIndex) {
    $scriptAnalysis.FunctionIndex | Export-Csv (Join-Path $fullOutputDir 'function-index.csv') -NoTypeInformation
}
if ($scriptAnalysis.Hotspots) {
    $scriptAnalysis.Hotspots | Export-Csv (Join-Path $fullOutputDir 'hotspots.csv') -NoTypeInformation
}
if ($analyzerRun.Analyzer) {
    $analyzerRun.Analyzer | Select-Object RuleName, Severity, Message, Line, ScriptName |
        Export-Csv (Join-Path $fullOutputDir 'analyzer.csv') -NoTypeInformation
}

#region Markdown Report

$mdPath = Join-Path $fullOutputDir 'audit-report.md'
$sb     = [System.Text.StringBuilder]::new()

[void]$sb.AppendLine('# Repository Self-Audit Report')
[void]$sb.AppendLine('')
[void]$sb.AppendLine("- **Generated:** $(Get-Date -Format s)")
[void]$sb.AppendLine("- **RepoRoot:** $RepoRoot")
[void]$sb.AppendLine("- **PrimaryScript:** $PrimaryScript")
[void]$sb.AppendLine("- **Tracked files:** $($allFiles.Count)")
[void]$sb.AppendLine("- **Findings:** Critical=$criticalCount, Warning=$warningCount, Info=$infoCount")
[void]$sb.AppendLine('')

foreach ($s in $sections) {
    $sec         = $results | Where-Object Section -eq $s
    $secCritical = ($sec | Where-Object Severity -eq 'Critical' | Measure-Object).Count
    $secWarn     = ($sec | Where-Object Severity -eq 'Warning'  | Measure-Object).Count
    $rating      = if ($secCritical -gt 0) { 'Critical Gap' } elseif ($secWarn -gt 0) { 'Needs Work' } else { 'Strong' }

    [void]$sb.AppendLine("## $s")
    [void]$sb.AppendLine("**Rating:** $rating")
    [void]$sb.AppendLine('')
    foreach ($f in $sec) {
        $loc = if ($f.File) { "$($f.File):$($f.Line)" } else { '-' }
        [void]$sb.AppendLine("- **[$($f.Severity)]** $($f.Finding)")
        [void]$sb.AppendLine("  - File/Line: $loc")
        if ($f.WhyItMatters)   { [void]$sb.AppendLine("  - Why It Matters: $($f.WhyItMatters)") }
        if ($f.Recommendation) { [void]$sb.AppendLine("  - Recommendation: $($f.Recommendation)") }
    }
    [void]$sb.AppendLine('')
}

# Top 5 Changes
[void]$sb.AppendLine('## Top 5 Changes')
[void]$sb.AppendLine('*Highest-impact improvements ranked by severity.*')
[void]$sb.AppendLine('')
$top = $results | Where-Object { $_.Severity -in @('Critical', 'Warning') } | Select-Object -First 5
if (-not $top) {
    [void]$sb.AppendLine('- No high-severity changes identified. Repository is in good shape.')
}
else {
    $i = 1
    foreach ($t in $top) {
        [void]$sb.AppendLine("$i. **$($t.Finding)** — $($t.Section)")
        $i++
    }
}
[void]$sb.AppendLine('')

# Already Strong
[void]$sb.AppendLine('## Already Strong')
[void]$sb.AppendLine('*Sections with no warnings or critical findings — do not change what is working.*')
[void]$sb.AppendLine('')
$strongSections = $sections | Where-Object {
    $sec         = $results | Where-Object Section -eq $_
    $secCritical = ($sec | Where-Object Severity -eq 'Critical' | Measure-Object).Count
    $secWarn     = ($sec | Where-Object Severity -eq 'Warning'  | Measure-Object).Count
    $secCritical -eq 0 -and $secWarn -eq 0
}
if ($strongSections) {
    foreach ($s in $strongSections) { [void]$sb.AppendLine("- $s") }
}
else {
    [void]$sb.AppendLine('- No sections are fully clean in this run.')
}
[void]$sb.AppendLine('')

# Files to Remove or Gitignore
[void]$sb.AppendLine('## Files to Remove or Gitignore')
[void]$sb.AppendLine('*Files flagged by hygiene checks that should not be in the repository.*')
[void]$sb.AppendLine('')
$filesToReview = $results |
    Where-Object { $_.Section -eq 'Repository Hygiene & Artifacts' -and $_.Severity -in @('Critical', 'Warning') } |
    Where-Object { $_.File -ne '' }
if ($filesToReview) {
    foreach ($f in $filesToReview) {
        [void]$sb.AppendLine("- ``$($f.File)`` — $($f.Finding)")
    }
}
else {
    [void]$sb.AppendLine('- No hygiene issues found.')
}
[void]$sb.AppendLine('')

$elapsed = (Get-Date) - $start
[void]$sb.AppendLine("---")
[void]$sb.AppendLine("*Audit completed in $([math]::Round($elapsed.TotalSeconds, 1))s*")

$sb.ToString() | Set-Content $mdPath

#endregion

Write-Host 'Audit complete.' -ForegroundColor Green
Write-Host "Report : $mdPath"
Write-Host "JSON   : $(Join-Path $fullOutputDir 'audit-report.json')"
Write-Host "CSV    : $(Join-Path $fullOutputDir 'findings.csv')"
Write-Host "Critical=$criticalCount  Warning=$warningCount  Info=$infoCount"

if ($FailOnCritical -and $criticalCount -gt $MaxAllowedCritical) {
    Write-Error "GATE FAILED: Critical findings ($criticalCount) exceed threshold ($MaxAllowedCritical)."
}

#endregion
