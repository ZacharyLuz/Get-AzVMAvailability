# Test-ImportExcelModule.ps1
# Extracted from Get-AzVMAvailability.ps1 (line 1421)
# Tests whether the ImportExcel module is available and importable
# DO NOT execute this file directly — it is a documentation reference only.
function Test-ImportExcelModule {
    try {
        $module = Get-Module ImportExcel -ListAvailable -ErrorAction SilentlyContinue
        if ($module) {
            Import-Module ImportExcel -ErrorAction Stop -WarningAction SilentlyContinue
            return $true
        }
        return $false
    }
    catch {
        Write-Verbose "Failed to load ImportExcel module: $($_.Exception.Message)"
        return $false
    }
}
