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
