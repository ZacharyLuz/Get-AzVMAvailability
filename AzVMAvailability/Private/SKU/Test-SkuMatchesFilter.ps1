function Test-SkuMatchesFilter {
    <#
    .SYNOPSIS
        Tests if a SKU name matches any of the filter patterns.
    .DESCRIPTION
        Supports exact matches and wildcard patterns (e.g., Standard_D*_v5).
        Case-insensitive matching. Uses -like operator to eliminate ReDoS risk.
        Validates patterns via length limit and character whitelist before matching.
    #>
    param([string]$SkuName, [string[]]$FilterPatterns)

    if (-not $FilterPatterns -or $FilterPatterns.Count -eq 0) {
        return $true  # No filter = include all
    }

    foreach ($pattern in @($FilterPatterns)) {
        if ([string]::IsNullOrWhiteSpace($pattern)) { continue }
        if ($pattern.Length -gt 128) {
            Write-Warning "SKU filter pattern too long (>128 chars), skipping: $($pattern.Substring(0,50))..."
            continue
        }
        if ($pattern -notmatch '^[A-Za-z0-9_\-\*\?]+$') {
            Write-Warning "SKU filter pattern contains invalid characters, skipping: $pattern"
            continue
        }
        if ($SkuName -like $pattern) {
            return $true
        }
    }

    return $false
}
