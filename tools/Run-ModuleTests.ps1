# Run-ModuleTests.ps1
# Validates the v2.0.0 module conversion: import, new tests, existing tests.
# Run from standalone terminal: pwsh -NoProfile -File .\tools\Run-ModuleTests.ps1
# Log output goes to tools/logs/module-test-<timestamp>.log

$ErrorActionPreference = 'Continue'
$repoRoot = Join-Path $PSScriptRoot '..'
Set-Location $repoRoot

$logDir = Join-Path $PSScriptRoot 'logs'
if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }

$timestamp = Get-Date -Format 'yyyy-MM-dd-HHmmss'
$logFile = Join-Path $logDir "module-test-$timestamp.log"

& {
    $runStart = [System.Diagnostics.Stopwatch]::StartNew()
    Write-Output "=== AzVMAvailability v2.0.0 Module Test Run ==="
    Write-Output "Timestamp: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
    Write-Output "PowerShell: $($PSVersionTable.PSVersion)"
    Write-Output "Log: $logFile"
    Write-Output ""

    #region Module Import
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $importFailed = $false
    Write-Output "-- Section 1: Module Import --"
    Remove-Module AzVMAvailability -ErrorAction SilentlyContinue
    try {
        Import-Module .\AzVMAvailability -Force -DisableNameChecking -ErrorAction Stop
        $mod = Get-Module AzVMAvailability
        Write-Output "  PASS  Module loaded: $($mod.Name) v$($mod.Version)"
        Write-Output "  Exports: $($mod.ExportedFunctions.Keys -join ', ')"
    }
    catch {
        Write-Output "  FAIL  Module import failed: $($_.Exception.Message)"
        $importFailed = $true
    }
    $sw.Stop()
    Write-Output "  Duration: $($sw.Elapsed.TotalSeconds.ToString('F1'))s"
    Write-Output ""
    #endregion

    #region New Tests
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Write-Output "-- Section 2: New Tests (Module.Tests + ParameterParity.Tests) --"
    $newTests = @('./tests/Module.Tests.ps1', './tests/ParameterParity.Tests.ps1')
    $newResults = Invoke-Pester -Path $newTests -Output Detailed -PassThru
    Write-Output ""
    Write-Output "  Passed: $($newResults.PassedCount)  Failed: $($newResults.FailedCount)  Skipped: $($newResults.SkippedCount)"
    if ($newResults.FailedCount -gt 0) {
        Write-Output "  FAIL  New test failures:"
        foreach ($t in $newResults.Failed) {
            Write-Output "    [-] $($t.ExpandedPath)"
            Write-Output "        $($t.ErrorRecord.Exception.Message)"
        }
    } else {
        Write-Output "  PASS  All new tests passed"
    }
    $sw.Stop()
    Write-Output "  Duration: $($sw.Elapsed.TotalSeconds.ToString('F1'))s"
    Write-Output ""
    #endregion

    #region Existing Tests
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    Write-Output "-- Section 3: Existing Tests (excluding Integration, Module, ParameterParity) --"
    $existing = Get-ChildItem ./tests/*.Tests.ps1 | Where-Object {
        $_.Name -notin @('Integration.Tests.ps1', 'Module.Tests.ps1', 'ParameterParity.Tests.ps1')
    }
    Write-Output "  Files: $($existing.Count)"
    $existingResults = Invoke-Pester -Path $existing.FullName -Output Detailed -PassThru
    Write-Output ""
    Write-Output "  Passed: $($existingResults.PassedCount)  Failed: $($existingResults.FailedCount)  Skipped: $($existingResults.SkippedCount)"
    if ($existingResults.FailedCount -gt 0 -or $existingResults.FailedBlocksCount -gt 0) {
        Write-Output "  FAIL  Existing test failures:"
        foreach ($t in $existingResults.Failed) {
            Write-Output "    [-] $($t.ExpandedPath)"
            Write-Output "        $($t.ErrorRecord.Exception.Message)"
        }
        if ($existingResults.FailedBlocksCount -gt 0) {
            Write-Output "  Container failures: $($existingResults.FailedBlocksCount)"
            foreach ($c in $existingResults.FailedBlocks) {
                Write-Output "    [!] $($c.Name): $($c.ErrorRecord.Exception.Message)"
            }
        }
    } else {
        Write-Output "  PASS  All existing tests passed"
    }
    $sw.Stop()
    Write-Output "  Duration: $($sw.Elapsed.TotalSeconds.ToString('F1'))s"
    Write-Output ""
    #endregion

    #region Summary
    $totalPassed = $newResults.PassedCount + $existingResults.PassedCount
    $totalFailed = $newResults.FailedCount + $existingResults.FailedCount
    $containerFailed = if ($existingResults.FailedBlocksCount) { $existingResults.FailedBlocksCount } else { 0 }
    $runStart.Stop()
    Write-Output "-- Summary --"
    Write-Output "  Total Passed:  $totalPassed"
    Write-Output "  Total Failed:  $totalFailed"
    Write-Output "  Containers Failed: $containerFailed"
    Write-Output "  Total Duration: $($runStart.Elapsed.TotalSeconds.ToString('F1'))s"
    if ($totalFailed -eq 0 -and $containerFailed -eq 0 -and -not $importFailed) {
        Write-Output "  RESULT: ALL TESTS PASSED"
    } else {
        Write-Output "  RESULT: FAILURES DETECTED"
    }
    Write-Output ""
    Write-Output "Log: $logFile"
    #endregion

} *>&1 | Tee-Object -FilePath $logFile

# Exit with non-zero if any failures detected
$logContent = Get-Content $logFile -Raw
if ($logContent -match 'RESULT: FAILURES DETECTED') { exit 1 }
