function Get-SkuFamilyVersion {
    param([string]$SkuName)
    if ($SkuName -match '_v(\d+)') {
        return [int]$matches[1]
    }
    return 1
}
