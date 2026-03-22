# Test-SkuMatchesFilter.ps1
# Extracted from Get-AzVMAvailability.ps1 (line 1436)
# Tests whether a VM SKU matches the active family/SKU filter criteria
# DO NOT execute this file directly — it is a documentation reference only.
function Test-SkuMatchesFilter {
    <#
    .SYNOPSIS
        Tests if a SKU name matches any of the filter patterns.
    .DESCRIPTION
        Supports exact matches and wildcard patterns (e.g., Standard_D*_v5).
        Case-insensitive matching.
    #>
    param([string]$SkuName, [string[]]$FilterPatterns)

    if (-not $FilterPatterns -or $FilterPatterns.Count -eq 0) {
        return $true  # No filter = include all
    }

    foreach ($pattern in $FilterPatterns) {
        # Convert wildcard pattern to regex
        $regexPattern = '^' + [regex]::Escape($pattern).Replace('\*', '.*').Replace('\?', '.') + '$'
        if ($SkuName -match $regexPattern) {
            return $true
        }
    }

    return $false
}
