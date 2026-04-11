# Test-Parity.ps1
# Compares wrapper script vs module import for behavioral parity.
# Run from repo root: pwsh -NoProfile -File .\tools\Test-Parity.ps1
# Log output goes to tools/logs/parity-test-<timestamp>.log

$ErrorActionPreference = 'Continue'
$repoRoot = Join-Path $PSScriptRoot '..'
Set-Location $repoRoot

$logDir = Join-Path $PSScriptRoot 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
$timestamp = Get-Date -Format 'yyyy-MM-dd-HHmmss'
$logFile = Join-Path $logDir "parity-test-$timestamp.log"

& {
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Write-Output "=== AzVMAvailability Parity Test ==="
    Write-Output "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Output "PowerShell: $($PSVersionTable.PSVersion)"
    Write-Output "Log: $logFile"
    Write-Output ""

    # Detect current subscription
    $ctx = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $ctx) {
        Write-Output "FAIL  No Azure context. Run Connect-AzAccount first."
        $script:parityFailed = $true
        return
    }
    $subName = $ctx.Subscription.Name
    $subId = $ctx.Subscription.Id
    $region = 'eastus'
    Write-Output "Subscription: $subName ($subId)"
    Write-Output "Region: $region"
    Write-Output ""

    #region Test 1: JsonOutput parity
    Write-Output "-- Test 1: -JsonOutput -NoPrompt -Region $region --"
    Write-Output "  Running via wrapper script..."
    $t1 = [System.Diagnostics.Stopwatch]::StartNew()
    $wrapperJson = & pwsh -NoProfile -Command "Set-Location '$repoRoot'; .\Get-AzVMAvailability.ps1 -JsonOutput -NoPrompt -Region $region" 2>&1 | Where-Object { $_ -is [string] }
    $t1.Stop()
    Write-Output "  Wrapper: $($t1.Elapsed.TotalSeconds.ToString('F1'))s"

    Write-Output "  Running via module import..."
    $t2 = [System.Diagnostics.Stopwatch]::StartNew()
    $moduleJson = & pwsh -NoProfile -Command "Set-Location '$repoRoot'; Import-Module .\AzVMAvailability -Force -DisableNameChecking; Get-AzVMAvailability -JsonOutput -NoPrompt -Region $region" 2>&1 | Where-Object { $_ -is [string] }
    $t2.Stop()
    Write-Output "  Module:  $($t2.Elapsed.TotalSeconds.ToString('F1'))s"

    # Parse both
    $wObj = $wrapperJson | ConvertFrom-Json -ErrorAction SilentlyContinue
    $mObj = $moduleJson | ConvertFrom-Json -ErrorAction SilentlyContinue

    if (-not $wObj) { Write-Output "  FAIL  Wrapper JSON is invalid or empty"; $script:parityFailed = $true }
    elseif (-not $mObj) { Write-Output "  FAIL  Module JSON is invalid or empty"; $script:parityFailed = $true }
    else {
        $checks = @()
        # Schema version
        if ($wObj.schemaVersion -eq $mObj.schemaVersion) { $checks += "  PASS  schemaVersion: $($wObj.schemaVersion)" }
        else { $checks += "  FAIL  schemaVersion: wrapper=$($wObj.schemaVersion) module=$($mObj.schemaVersion)"; $script:parityFailed = $true }
        # Mode
        if ($wObj.mode -eq $mObj.mode) { $checks += "  PASS  mode: $($wObj.mode)" }
        else { $checks += "  FAIL  mode: wrapper=$($wObj.mode) module=$($mObj.mode)"; $script:parityFailed = $true }
        # Family count
        $wFam = @($wObj.families).Count
        $mFam = @($mObj.families).Count
        if ($wFam -eq $mFam) { $checks += "  PASS  families count: $wFam" }
        else { $checks += "  FAIL  families count: wrapper=$wFam module=$mFam"; $script:parityFailed = $true }
        # Details count
        $wDet = @($wObj.details).Count
        $mDet = @($mObj.details).Count
        if ($wDet -eq $mDet) { $checks += "  PASS  details count: $wDet" }
        else { $checks += "  FAIL  details count: wrapper=$wDet module=$mDet"; $script:parityFailed = $true }
        # Regions
        $wReg = ($wObj.regions | ConvertTo-Json -Compress)
        $mReg = ($mObj.regions | ConvertTo-Json -Compress)
        if ($wReg -eq $mReg) { $checks += "  PASS  regions match" }
        else { $checks += "  FAIL  regions differ"; $script:parityFailed = $true }

        $checks | ForEach-Object { Write-Output $_ }
    }
    Write-Output ""
    #endregion

    #region Test 2: Recommend mode parity
    Write-Output "-- Test 2: -Recommend Standard_D4s_v5 -NoPrompt -Region $region -JsonOutput --"
    Write-Output "  Running via wrapper..."
    $t3 = [System.Diagnostics.Stopwatch]::StartNew()
    $wRecJson = & pwsh -NoProfile -Command "Set-Location '$repoRoot'; .\Get-AzVMAvailability.ps1 -Recommend Standard_D4s_v5 -NoPrompt -Region $region -JsonOutput" 2>&1 | Where-Object { $_ -is [string] }
    $t3.Stop()
    Write-Output "  Wrapper: $($t3.Elapsed.TotalSeconds.ToString('F1'))s"

    Write-Output "  Running via module..."
    $t4 = [System.Diagnostics.Stopwatch]::StartNew()
    $mRecJson = & pwsh -NoProfile -Command "Set-Location '$repoRoot'; Import-Module .\AzVMAvailability -Force -DisableNameChecking; Get-AzVMAvailability -Recommend Standard_D4s_v5 -NoPrompt -Region $region -JsonOutput" 2>&1 | Where-Object { $_ -is [string] }
    $t4.Stop()
    Write-Output "  Module:  $($t4.Elapsed.TotalSeconds.ToString('F1'))s"

    $wRec = $wRecJson | ConvertFrom-Json -ErrorAction SilentlyContinue
    $mRec = $mRecJson | ConvertFrom-Json -ErrorAction SilentlyContinue

    if (-not $wRec) { Write-Output "  FAIL  Wrapper recommend JSON invalid or empty"; $script:parityFailed = $true }
    elseif (-not $mRec) { Write-Output "  FAIL  Module recommend JSON invalid or empty"; $script:parityFailed = $true }
    else {
        if ($wRec.schemaVersion -eq $mRec.schemaVersion) { Write-Output "  PASS  schemaVersion: $($wRec.schemaVersion)" }
        else { Write-Output "  FAIL  schemaVersion mismatch"; $script:parityFailed = $true }
        $wCount = @($wRec.recommendations).Count
        $mCount = @($mRec.recommendations).Count
        if ($wCount -eq $mCount) { Write-Output "  PASS  recommendation count: $wCount" }
        else { Write-Output "  FAIL  recommendation count: wrapper=$wCount module=$mCount"; $script:parityFailed = $true }
        if ($wRec.target.sku -eq $mRec.target.sku) { Write-Output "  PASS  target SKU: $($wRec.target.sku)" }
        else { Write-Output "  FAIL  target SKU mismatch"; $script:parityFailed = $true }
    }
    Write-Output ""
    #endregion

    #region Test 3: GenerateInventoryTemplate (no Azure needed)
    Write-Output "-- Test 3: -GenerateInventoryTemplate (offline) --"
    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "parity-test-$timestamp"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    $templateOutput = & pwsh -NoProfile -Command "Set-Location '$tempDir'; & '$repoRoot\Get-AzVMAvailability.ps1' -GenerateInventoryTemplate" 2>&1
    $templateErrors = $templateOutput | Where-Object { $_ -is [System.Management.Automation.ErrorRecord] }
    if ($templateErrors) { $templateErrors | ForEach-Object { Write-Output "  WARN  stderr: $_" } }
    $csvExists = Test-Path (Join-Path $tempDir 'inventory-template.csv')
    $jsonExists = Test-Path (Join-Path $tempDir 'inventory-template.json')
    if ($csvExists -and $jsonExists) { Write-Output "  PASS  Template files generated (CSV + JSON)" }
    else { Write-Output "  FAIL  Missing template files: CSV=$csvExists JSON=$jsonExists"; $script:parityFailed = $true }
    Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    Write-Output ""
    #endregion

    #region Summary
    $sw.Stop()
    Write-Output "-- Summary --"
    Write-Output "  Total Duration: $($sw.Elapsed.TotalSeconds.ToString('F1'))s"
    Write-Output "  Log: $logFile"
    #endregion

} *>&1 | Tee-Object -FilePath $logFile

# Exit non-zero if any parity check failed
if ($script:parityFailed) { exit 1 }
