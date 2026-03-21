function Get-SpotPricingMap {
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

    if ($PricingContainer -is [System.Collections.IDictionary] -and $PricingContainer.Contains('Spot')) {
        return $PricingContainer.Spot
    }

    return @{}
}
