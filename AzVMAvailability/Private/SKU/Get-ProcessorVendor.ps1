function Get-ProcessorVendor {
    param([string]$SkuName)
    $body = ($SkuName -replace '^Standard_', '') -replace '_v\d+$', ''
    # 'p' suffix = ARM/Ampere; must check before 'a' since some SKUs have both (e.g., E64pds)
    if ($body -match 'p(?![\d])') { return 'ARM' }
    # 'a' suffix = AMD; exclude A-family where 'a' is the family letter not a suffix
    $family = if ($SkuName -match 'Standard_([A-Z]+)\d') { $matches[1] } else { '' }
    if ($family -ne 'A' -and $body -match 'a(?![\d])') { return 'AMD' }
    return 'Intel'
}
