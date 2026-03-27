# Get-RestrictionReason.ps1
# Extracted from Get-AzVMAvailability.ps1 (line 1009)
# Returns a human-readable reason code for a SKU restriction
# DO NOT execute this file directly — it is a documentation reference only.
function Get-RestrictionReason {
    param([object]$Sku)
    if ($Sku.Restrictions -and $Sku.Restrictions.Count -gt 0) {
        return $Sku.Restrictions[0].ReasonCode
    }
    return $null
}
