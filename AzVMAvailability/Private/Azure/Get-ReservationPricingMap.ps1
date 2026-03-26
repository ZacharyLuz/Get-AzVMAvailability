function Get-ReservationPricingMap {
    param(
        [Parameter(Mandatory = $false)]
        [object]$PricingContainer,
        [Parameter(Mandatory = $true)]
        [ValidateSet('1Yr','3Yr')]
        [string]$Term
    )

    if ($null -eq $PricingContainer) { return @{} }
    if ($PricingContainer -is [array]) { $PricingContainer = $PricingContainer[0] }

    $key = "Reservation$Term"
    if ($PricingContainer -is [System.Collections.IDictionary] -and $PricingContainer.Contains($key)) {
        return $PricingContainer[$key]
    }
    return @{}
}
