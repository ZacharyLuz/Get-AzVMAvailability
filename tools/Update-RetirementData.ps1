<#
.SYNOPSIS
    Updates the static VM retirement table using GitHub Models AI to parse the
    official Microsoft retirement page.

.DESCRIPTION
    Fetches the raw Markdown source from MicrosoftDocs/azure-compute-docs on GitHub,
    sends it to a GitHub Models LLM to extract structured retirement data, validates the
    output, and shows a diff against the current Get-SkuRetirementInfo.ps1 pattern table.

    Optionally applies the update with -Apply.

.PARAMETER Apply
    Writes the updated retirement table directly to Get-SkuRetirementInfo.ps1.
    Without this switch, the script only shows the diff (dry run).

.PARAMETER IncludeAdvisor
    Queries Azure Advisor via Resource Graph (requires Az.ResourceGraph and an active
    Azure login) and cross-references retirement dates against the static table.
    Gracefully skipped if Search-AzGraph is not available.

.PARAMETER Model
    GitHub Models model to use. Default: openai/gpt-4.1-mini

.EXAMPLE
    .\tools\Update-RetirementData.ps1
    # Dry run — fetches page, shows diff, no changes written

.EXAMPLE
    .\tools\Update-RetirementData.ps1 -IncludeAdvisor
    # Dry run + cross-reference with Advisor ARG data

.EXAMPLE
    .\tools\Update-RetirementData.ps1 -Apply
    # Fetches page, shows diff, writes updated function to disk
#>
[CmdletBinding()]
param(
    [switch]$Apply,
    [switch]$IncludeAdvisor,
    [string]$Model = 'openai/gpt-4.1-mini'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path $PSScriptRoot -Parent
$targetFile = Join-Path $repoRoot 'AzVMAvailability' 'Private' 'SKU' 'Get-SkuRetirementInfo.ps1'

# ── Step 1: Verify gh CLI is authenticated ──
try {
    $null = & gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) { throw "gh CLI not authenticated. Run 'gh auth login' first." }
}
catch {
    Write-Error "GitHub CLI (gh) is required. Install from https://cli.github.com/ and run 'gh auth login'."
    return
}

# ── Step 2: Fetch raw Markdown from MicrosoftDocs ──
$rawUrl = 'https://raw.githubusercontent.com/MicrosoftDocs/azure-compute-docs/main/articles/virtual-machines/sizes/retirement/retired-sizes-list.md'
Write-Host "Fetching retirement page from MicrosoftDocs..." -ForegroundColor Cyan
try {
    $markdown = Invoke-RestMethod -Uri $rawUrl -TimeoutSec 30
}
catch {
    Write-Error "Failed to fetch retirement page: $($_.Exception.Message)"
    return
}
$lineCount = ($markdown -split "`n").Count
Write-Host "  Retrieved $lineCount lines of Markdown" -ForegroundColor DarkGray

# ── Step 3: Send to GitHub Models for structured extraction ──
$systemPrompt = @'
You are a precise data extraction assistant. Extract ALL VM retirement entries from the
provided Azure documentation Markdown. Return ONLY a JSON array, no other text.

Each entry must have exactly these fields:
- "series": The series name exactly as shown (e.g., "D-series", "NCv3-Series", "Standard_M192idms_v2", "NP-series")
- "status": Either "Retired" or "Announced" (map "Announced" to "Retiring" in the output)
- "retireDate": The Planned Retirement Date in YYYY-MM-DD format (convert MM/DD/YY to YYYY-MM-DD)
- "announcementDate": The Retirement Announcement date in YYYY-MM-DD format (if present)

Rules:
- Include EVERY row from EVERY table (General purpose, Compute optimized, Memory optimized, Storage optimized, GPU accelerated, FPGA accelerated, HPC, ADH)
- If a section says "Currently there are no retired ... series", emit nothing for that section
- Convert all dates to YYYY-MM-DD format. "05/01/28" means 2028-05-01. "30/9/25" means 2025-09-30. "03/22/2024" means 2024-03-22
- If retirement date is "-" or missing, use null
- Map status: "Retired" -> "Retired", "Announced" -> "Retiring"
- Do NOT include previous-gen sizes — only entries explicitly in the retirement tables
'@

$userPrompt = @"
Extract all VM retirement entries from this Azure documentation page:

$markdown
"@

Write-Host "Calling GitHub Models ($Model) for structured extraction..." -ForegroundColor Cyan

$body = @{
    model    = $Model
    messages = @(
        @{ role = 'system'; content = $systemPrompt }
        @{ role = 'user';   content = $userPrompt }
    )
    temperature = 0
} | ConvertTo-Json -Depth 5

$modelsResponse = $null
try {
    # PowerShell-native stdin piping: write body to a temp file then pipe its
    # contents to `gh api --input -`. The bash heredoc form (<<< $body) is not
    # valid in pwsh and was dropped.
    $tempBody = [System.IO.Path]::GetTempFileName()
    [System.IO.File]::WriteAllText($tempBody, $body, [System.Text.Encoding]::UTF8)

    $rawResponse = Get-Content $tempBody -Raw | & gh api 'https://models.github.ai/inference/chat/completions' --method POST --input - 2>&1
    Remove-Item $tempBody -Force -ErrorAction SilentlyContinue

    if ($LASTEXITCODE -ne 0) {
        throw "GitHub Models API call failed: $rawResponse"
    }

    $parsed = $rawResponse | ConvertFrom-Json
    $modelsResponse = $parsed.choices[0].message.content
}
catch {
    Write-Error "GitHub Models call failed: $($_.Exception.Message)"
    return
}

# ── Step 4: Parse and validate the JSON response ──
Write-Host "Parsing LLM response..." -ForegroundColor Cyan

# Strip markdown code fences if present
$jsonText = $modelsResponse -replace '```json\s*', '' -replace '```\s*$', '' -replace '^\s*```\s*', ''
$jsonText = $jsonText.Trim()

try {
    $entries = $jsonText | ConvertFrom-Json
}
catch {
    Write-Error "LLM returned invalid JSON. Raw response:`n$modelsResponse"
    return
}

if ($entries.Count -eq 0) {
    Write-Error "LLM returned zero entries — something went wrong."
    return
}

# Validate each entry has required fields
$valid = @()
$invalid = @()
foreach ($e in $entries) {
    if (-not $e.series -or -not $e.status) {
        $invalid += $e
        continue
    }
    # Normalize status
    $e.status = switch ($e.status) {
        'Announced' { 'Retiring' }
        'Retiring'  { 'Retiring' }
        'Retired'   { 'Retired' }
        default     { $e.status }
    }
    # Validate date format
    if ($e.retireDate -and $e.retireDate -notmatch '^\d{4}-\d{2}-\d{2}$') {
        $invalid += $e
        continue
    }
    $valid += $e
}

Write-Host "  Extracted $($valid.Count) valid entries ($($invalid.Count) rejected)" -ForegroundColor DarkGray
if ($invalid.Count -gt 0) {
    Write-Host "  Rejected entries:" -ForegroundColor Yellow
    $invalid | ForEach-Object { Write-Host "    $_" -ForegroundColor Yellow }
}

# ── Step 5: Read current retirement table for comparison ──
Write-Host "`nCurrent table in Get-SkuRetirementInfo.ps1:" -ForegroundColor Cyan

$currentContent = Get-Content $targetFile -Raw
# Extract existing entries by parsing the Series + RetireDate + Status
$currentEntries = @{}
$currentMatches = [regex]::Matches($currentContent, "Series\s*=\s*'([^']+)';\s*RetireDate\s*=\s*'([^']+)';\s*Status\s*=\s*'([^']+)'")
foreach ($m in $currentMatches) {
    $currentEntries[$m.Groups[1].Value] = @{
        RetireDate = $m.Groups[2].Value
        Status     = $m.Groups[3].Value
    }
}
Write-Host "  $($currentEntries.Count) entries in current table" -ForegroundColor DarkGray

# ── Step 5b: Optionally query Azure Advisor via ARG ──
$advisorData = @{}
if ($IncludeAdvisor) {
    $hasARG = $false
    try { if (Get-Command -Name 'Search-AzGraph' -ErrorAction SilentlyContinue) { $hasARG = $true } }
    catch { Write-Verbose "Search-AzGraph availability check failed: $($_.Exception.Message)" }

    if (-not $hasARG) {
        Write-Host "`n  Skipping Advisor: Az.ResourceGraph module not available" -ForegroundColor DarkGray
        Write-Host "  Install with: Install-Module Az.ResourceGraph -Scope CurrentUser" -ForegroundColor DarkGray
    }
    else {
        Write-Host "`nQuerying Azure Advisor via Resource Graph..." -ForegroundColor Cyan
        try {
            $argQuery = @"
advisorresources
| where type =~ 'microsoft.advisor/recommendations'
| where properties.category =~ 'HighAvailability'
| where properties.extendedProperties.recommendationSubCategory =~ 'ServiceUpgradeAndRetirement'
| where properties.impactedField has 'VIRTUALMACHINES'
| summarize
    retireDate   = take_any(tostring(properties.extendedProperties.retirementDate)),
    vmCount      = dcount(tostring(properties.impactedValue))
    by seriesName = tostring(properties.extendedProperties.retirementFeatureName)
"@
            $allRecs = [System.Collections.Generic.List[PSCustomObject]]::new()
            $argParams = @{ Query = $argQuery; First = 1000 }
            do {
                $page = Search-AzGraph @argParams
                if ($page) {
                    foreach ($r in $page) { $allRecs.Add($r) }
                    if ($page.SkipToken) { $argParams['SkipToken'] = $page.SkipToken } else { break }
                } else { break }
            } while ($true)

            foreach ($rec in $allRecs) {
                $sn = $rec.seriesName
                if (-not $sn) { continue }
                # Normalize Advisor retireDate to YYYY-MM-DD
                $rd = $rec.retireDate
                if ($rd) {
                    try {
                        $rd = ([datetime]$rd).ToString('yyyy-MM-dd')
                    } catch {
                        Write-Verbose ("Could not parse Advisor retireDate '{0}' for {1}: {2}; leaving as-is" -f $rd, $sn, $_.Exception.Message)
                    }
                }
                $advisorData[$sn] = @{
                    RetireDate = $rd
                    VMCount    = $rec.vmCount
                    Status     = if ($rd -and [datetime]$rd -lt [datetime]::UtcNow) { 'Retired' } else { 'Retiring' }
                }
            }
            Write-Host "  Advisor returned $($advisorData.Count) retirement group(s)" -ForegroundColor DarkGray
        }
        catch {
            Write-Host "  Advisor query failed (non-fatal): $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }
}

# ── Step 6: Show diff ──
Write-Host "`n=== RETIREMENT DATA DIFF ===" -ForegroundColor White

$newEntries = @()
$changedEntries = @()
$unchangedCount = 0

foreach ($e in $valid) {
    $seriesKey = $e.series -replace '-series$', '' -replace '-Series$', '' -replace ' \(V1\)$', 'v1'
    # Normalize common series name variations
    $seriesKey = switch -Regex ($seriesKey) {
        '^D$'                    { 'Dv1'; break }
        '^Ds$'                   { 'Dv1'; break }  # D/Ds share same row
        '^Dv2$'                  { 'Dv2'; break }
        '^Dsv2$'                 { 'Dv2'; break }  # Dv2/Dsv2 share same row
        '^Av2/Amv2$'             { 'Av2'; break }
        '^B \(V1\)$'             { 'Bv1'; break }
        '^Bv1$'                  { 'Bv1'; break }
        '^F$'                    { 'Fv1'; break }
        '^Fs$'                   { 'Fsv1'; break }
        '^Fsv2$'                 { 'Fsv2'; break }
        '^G$'                    { 'G/GS'; break }
        '^Gs$'                   { 'G/GS'; break }
        '^Ls$'                   { 'Lsv1'; break }
        '^Lsv2$'                 { 'Lsv2'; break }
        '^NCv3-NC24rs$'          { 'NCv3-NC24rs'; break }
        '^NCv3$'                 { 'NCv3'; break }
        '^NVv3$'                 { 'NVv3'; break }
        '^NVv4$'                 { 'NVv4'; break }
        '^NP$'                   { 'NP'; break }
        '^Standard_M\d+.*$'      { $seriesKey; break }  # Keep specific M-series SKU names
        default                  { $seriesKey }
    }

    $existing = $currentEntries[$seriesKey]
    if (-not $existing) {
        $newEntries += [pscustomobject]@{ Series = $seriesKey; Date = $e.retireDate; Status = $e.status; Raw = $e.series }
        Write-Host "  + NEW:     $seriesKey  $($e.status)  $($e.retireDate)" -ForegroundColor Green
    }
    elseif ($existing.RetireDate -ne $e.retireDate -or $existing.Status -ne $e.status) {
        $changedEntries += [pscustomobject]@{
            Series    = $seriesKey
            OldDate   = $existing.RetireDate
            NewDate   = $e.retireDate
            OldStatus = $existing.Status
            NewStatus = $e.status
            Raw       = $e.series
        }
        Write-Host "  ~ CHANGED: $seriesKey  $($existing.Status) $($existing.RetireDate) → $($e.status) $($e.retireDate)" -ForegroundColor Yellow
    }
    else {
        $unchangedCount++
    }
}

Write-Host "`nSummary: $unchangedCount unchanged, $($changedEntries.Count) changed, $($newEntries.Count) new" -ForegroundColor White

# ── Step 6b: Cross-reference Advisor ARG data ──
if ($advisorData.Count -gt 0) {
    Write-Host "`n=== ADVISOR vs STATIC TABLE ===" -ForegroundColor White

    # Build a reverse mapping from Advisor seriesName → our series key
    # Advisor uses names like "Standard Virtual Machines Dv2/DSv2 Series" or shorthand
    $advisorConflicts = @()
    $advisorOnlyEntries = @()
    $advisorMatchCount = 0

    foreach ($advKey in $advisorData.Keys) {
        $advEntry = $advisorData[$advKey]

        # Try to match Advisor series name to a static table key
        # Advisor names vary — try exact key, then substring matches
        $matched = $null
        foreach ($staticKey in $currentEntries.Keys) {
            if ($advKey -match [regex]::Escape($staticKey) -or $advKey -match "\b$([regex]::Escape($staticKey))\b") {
                $matched = $staticKey
                break
            }
        }

        if ($matched) {
            $staticEntry = $currentEntries[$matched]
            $advDate   = $advEntry.RetireDate
            $tableDate = $staticEntry.RetireDate

            if ($advDate -and $tableDate -and $advDate -ne $tableDate) {
                $advisorConflicts += [pscustomobject]@{
                    Series       = $matched
                    AdvisorKey   = $advKey
                    AdvisorDate  = $advDate
                    TableDate    = $tableDate
                    AdvisorVMs   = $advEntry.VMCount
                }
                Write-Host "  !! CONFLICT: $matched  Table=$tableDate  Advisor=$advDate  ($($advEntry.VMCount) VMs)" -ForegroundColor Red
            }
            elseif ($advDate -and $tableDate -and $advDate -eq $tableDate) {
                $advisorMatchCount++
            }
        }
        else {
            $advisorOnlyEntries += [pscustomobject]@{
                AdvisorKey  = $advKey
                AdvisorDate = $advEntry.RetireDate
                AdvisorVMs  = $advEntry.VMCount
                Status      = $advEntry.Status
            }
            Write-Host "  ? ADVISOR-ONLY: '$advKey'  $($advEntry.Status)  $($advEntry.RetireDate)  ($($advEntry.VMCount) VMs)" -ForegroundColor Magenta
        }
    }

    # Also check Advisor dates against the docs-extracted data
    $docsConflicts = @()
    foreach ($advKey in $advisorData.Keys) {
        $advEntry = $advisorData[$advKey]
        foreach ($docEntry in $valid) {
            $docSeries = $docEntry.series -replace '-[Ss]eries$', ''
            if ($advKey -match [regex]::Escape($docSeries) -or $advKey -match "\b$([regex]::Escape($docSeries))\b") {
                if ($advEntry.RetireDate -and $docEntry.retireDate -and $advEntry.RetireDate -ne $docEntry.retireDate) {
                    $docsConflicts += [pscustomobject]@{
                        DocsSeries  = $docEntry.series
                        AdvisorKey  = $advKey
                        DocsDate    = $docEntry.retireDate
                        AdvisorDate = $advEntry.RetireDate
                    }
                }
                break
            }
        }
    }
    if ($docsConflicts.Count -gt 0) {
        Write-Host "`n  Advisor vs Docs page conflicts:" -ForegroundColor Yellow
        foreach ($dc in $docsConflicts) {
            Write-Host "    !! $($dc.DocsSeries): Docs=$($dc.DocsDate)  Advisor=$($dc.AdvisorDate)" -ForegroundColor Red
        }
    }

    Write-Host "`n  Advisor summary: $advisorMatchCount matched, $($advisorConflicts.Count) date conflicts, $($advisorOnlyEntries.Count) advisor-only" -ForegroundColor White
}

if ($changedEntries.Count -eq 0 -and $newEntries.Count -eq 0) {
    Write-Host "`nRetirement table is already up to date (docs)." -ForegroundColor Green
    if ($advisorData.Count -eq 0 -or ($advisorConflicts.Count -eq 0 -and $advisorOnlyEntries.Count -eq 0)) {
        return
    }
    Write-Host "Review Advisor conflicts above before proceeding." -ForegroundColor Yellow
    return
}

# ── Step 7: Apply if requested ──
if (-not $Apply) {
    Write-Host "`nDry run complete. To apply changes, re-run with -Apply" -ForegroundColor Cyan
    Write-Host "  .\tools\Update-RetirementData.ps1 -Apply" -ForegroundColor DarkGray
    return
}

Write-Host "`nApplying updates to $targetFile..." -ForegroundColor Cyan

# Build the updated lookup array entries for changed items
foreach ($change in $changedEntries) {
    $oldPattern = "RetireDate = '$($change.OldDate)'; Status = '$($change.OldStatus)'"
    $newPattern = "RetireDate = '$($change.NewDate)'; Status = '$($change.NewStatus)'"
    # Find and replace the specific line for this series
    $seriesPattern = "Series = '$($change.Series)'"
    $lines = Get-Content $targetFile
    $updated = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match [regex]::Escape($seriesPattern) -and $lines[$i] -match [regex]::Escape($oldPattern)) {
            $lines[$i] = $lines[$i] -replace [regex]::Escape($oldPattern), $newPattern
            $updated = $true
            Write-Host "  Updated: $($change.Series) → $($change.NewStatus) $($change.NewDate)" -ForegroundColor Green
            break
        }
    }
    if ($updated) {
        # Repo .editorconfig requires UTF-8 with BOM for *.ps1; pwsh 7's `-Encoding UTF8`
        # writes UTF-8 without BOM, so use the explicit UTF8BOM identifier.
        $lines | Set-Content $targetFile -Encoding UTF8BOM
    }
    else {
        Write-Warning "Could not find line for $($change.Series) with $oldPattern — manual update needed"
    }
}

# Report new entries that need manual addition
if ($newEntries.Count -gt 0) {
    Write-Host "`nNew series detected — manual regex patterns needed:" -ForegroundColor Yellow
    foreach ($ne in $newEntries) {
        Write-Host "  Series: $($ne.Series)  Status: $($ne.Status)  Date: $($ne.Date)  (source: '$($ne.Raw)')" -ForegroundColor Yellow
    }
    Write-Host "  Add regex patterns to the `$retirementLookup array in:" -ForegroundColor Yellow
    Write-Host "  $targetFile" -ForegroundColor DarkGray
}

# Update the "Last verified" comment — but only when the static table is fully
# in sync. If new entries were detected, the table is incomplete and stamping it
# as "verified today" would mislead downstream consumers about its freshness.
# Require the operator to add the new entries first, then re-run.
if ($newEntries.Count -gt 0) {
    Write-Warning "Skipping 'Last verified' timestamp update — $($newEntries.Count) new series still need to be added manually."
    Write-Host "After adding the missing patterns above, re-run this script to refresh the timestamp." -ForegroundColor Yellow
    Write-Host "`nDone (with pending manual updates). Review changes with: git diff $targetFile" -ForegroundColor Cyan
    exit 1
}

$today = (Get-Date).ToString('yyyy-MM-dd')
$currentContent = Get-Content $targetFile -Raw
if ($currentContent -match 'Last verified: \d{4}-\d{2}-\d{2}') {
    $currentContent = $currentContent -replace 'Last verified: \d{4}-\d{2}-\d{2}', "Last verified: $today"
    # Repo .editorconfig requires UTF-8 with BOM for *.ps1 files; use UTF8Encoding($true) explicitly.
    [System.IO.File]::WriteAllText($targetFile, $currentContent, [System.Text.UTF8Encoding]::new($true))
}

Write-Host "`nDone. Review changes with: git diff $targetFile" -ForegroundColor Cyan
