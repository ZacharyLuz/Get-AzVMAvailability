function Test-ImportExcelModule {
    try {
        $module = Get-Module ImportExcel -ListAvailable -ErrorAction SilentlyContinue
        if ($module) {
            Import-Module ImportExcel -ErrorAction Stop -WarningAction SilentlyContinue
            return $true
        }
        return $false
    }
    catch { return $false }
}
