# Get-RegularPricingMap.ps1
# Extracted from Get-AzVMAvailability.ps1 (line 2404)
# Builds a region→SKU→price hashtable for regular (pay-as-you-go) pricing
# DO NOT execute this file directly — it is a documentation reference only.
function Get-RegularPricingMap {
    param(
        [Parameter(Mandatory = $false)]
        [object]$PricingContainer
    )

    if ($null -eq $PricingContainer) {
        return @{}
    }

    if ($PricingContainer -is [array]) {
        $PricingContainer = $PricingContainer[0]
    }

    if ($PricingContainer -is [System.Collections.IDictionary] -and $PricingContainer.Contains('Regular')) {
        return $PricingContainer.Regular
    }

    return $PricingContainer
}
