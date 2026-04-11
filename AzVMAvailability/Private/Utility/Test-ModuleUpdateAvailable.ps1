function Test-ModuleUpdateAvailable {
    <#
    .SYNOPSIS
        Checks PSGallery for a newer version of AzVMAvailability and notifies the user.
    .DESCRIPTION
        Non-blocking, silent-on-failure check that runs once per session.
        Skipped when -JsonOutput is active (Write-Host is suppressed).
    #>
    param(
        [string]$CurrentVersion
    )

    # Only check once per session
    if ($script:VersionChecked) { return }
    $script:VersionChecked = $true

    try {
        $uri = 'https://www.powershellgallery.com/api/v2/FindPackagesById()?id=%27AzVMAvailability%27&$orderby=Version%20desc&$top=1'
        $response = Invoke-RestMethod -Uri $uri -TimeoutSec 3 -ErrorAction Stop

        if (-not $response) { return }

        $latestVersion = ($response | Select-Object -First 1).properties.Version
        if (-not $latestVersion) { return }

        $current = [version]$CurrentVersion
        $latest  = [version]$latestVersion

        if ($latest -gt $current) {
            Write-Host "  Update available: v$CurrentVersion → v$latestVersion — Run: " -ForegroundColor DarkYellow -NoNewline
            Write-Host "Update-Module AzVMAvailability" -ForegroundColor Yellow
        }
    }
    catch {
        # Silent — no network, no PSGallery, no problem
        Write-Verbose "Update check skipped: $($_.Exception.Message)"
    }
}
