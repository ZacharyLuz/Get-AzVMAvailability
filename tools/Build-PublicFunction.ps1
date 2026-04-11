# Build-PublicFunction.ps1
# Assembles AzVMAvailability/Public/Get-AzVMAvailability.ps1 from the monolith script.
# Run from repo root: .\tools\Build-PublicFunction.ps1

param([string]$SourceScript)

if (-not $SourceScript) {
    $backupPath = Join-Path $PSScriptRoot '..' 'backups' 'Get-AzVMAvailability.ps1.backup-pre-v2-wrapper'
    if (Test-Path $backupPath) {
        $SourceScript = $backupPath
        Write-Host "Using backup monolith: $backupPath" -ForegroundColor Cyan
    } else {
        throw "No -SourceScript specified and backup monolith not found at '$backupPath'. Pass the path to the original monolith script."
    }
}

$ErrorActionPreference = 'Stop'
if (-not (Test-Path -LiteralPath $SourceScript)) {
    throw "Source script '$SourceScript' not found."
}
$src = Get-Content -LiteralPath $SourceScript -Encoding UTF8
if ($src.Count -lt 6000) {
    throw "Source script has $($src.Count) lines — expected the monolith (6000+). The file at '$SourceScript' may be the thin wrapper, not the monolith."
}

# Verified boundaries [SEARCHED/OBSERVED]:
#   Lines 1-257:   Comment-based help (<# through #>)
#   Line  258:     [CmdletBinding()]
#   Line  259:     param(
#   Line  391:     ) — closes param
#   Line  393:     $ProgressPreference = 'SilentlyContinue'
#   Line  413:     $script:SuppressConsole = $JsonOutput.IsPresent
#   Lines 415-1025: Init block (#region GenerateInventoryTemplate through #endregion Configuration)
#   Lines 1026-3658: Module import / inline function definitions (SKIP)
#   Lines 3659-6759: Orchestration body (#region Initialize Azure Endpoints through finally/EOF)

$out = [System.Text.StringBuilder]::new(500000)

# --- Function wrapper open ---
[void]$out.AppendLine('function Get-AzVMAvailability {')

# --- Section 1: Comment-based help (lines 1-257, 0-indexed 0-256) ---
for ($i = 0; $i -le 256; $i++) {
    [void]$out.AppendLine($src[$i])
}

# --- Section 2: CmdletBinding + param block (lines 258-391, 0-indexed 257-390) ---
for ($i = 257; $i -le 390; $i++) {
    [void]$out.AppendLine($src[$i])
}

# --- Section 3: Post-param initialization ---
[void]$out.AppendLine('')
[void]$out.AppendLine('    # Set console suppression for this invocation (module-scope flag)')
[void]$out.AppendLine('    $script:SuppressConsole = $JsonOutput.IsPresent')
[void]$out.AppendLine('')
[void]$out.AppendLine('    $ProgressPreference = ''SilentlyContinue''')
[void]$out.AppendLine('')

# --- Section 4: Init block (lines 415-1025, 0-indexed 414-1024) ---
# Includes: GenerateInventoryTemplate, validation guards, constants, FamilyInfo, RunContext
for ($i = 414; $i -le 1024; $i++) {
    $line = $src[$i]
    # Replace $ScriptVersion assignment with module version lookup
    if ($line -match '^\$ScriptVersion\s*=\s*"') {
        $line = '$ScriptVersion = (Get-Module AzVMAvailability).Version.ToString()'
    }
    [void]$out.AppendLine($line)
}

# --- Section 5: Orchestration body (lines 3659-6759, 0-indexed 3658-6758) ---
# Includes: Azure Endpoints init, Interactive Prompts, Data Collection,
#           Inventory Readiness, Lifecycle Recommendations, Recommend Mode,
#           Process Results, Drill-Down, Multi-Region Matrix, Deployment Recommendations,
#           Detailed Breakdown, Completion, Export, finally block
for ($i = 3658; $i -le 6758; $i++) {
    [void]$out.AppendLine($src[$i])
}

# --- Close function ---
[void]$out.AppendLine('}')

# --- Write output ---
$outDir = Join-Path $PSScriptRoot '..' 'AzVMAvailability' 'Public'
if (-not (Test-Path $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
$outFile = Join-Path $outDir 'Get-AzVMAvailability.ps1'
[System.IO.File]::WriteAllText($outFile, $out.ToString(), [System.Text.UTF8Encoding]::new($false))

$lineCount = (Get-Content $outFile).Count
Write-Host "Created $outFile ($lineCount lines)" -ForegroundColor Green
