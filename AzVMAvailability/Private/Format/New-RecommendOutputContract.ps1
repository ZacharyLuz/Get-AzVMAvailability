function New-RecommendOutputContract {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param(
        [Parameter(Mandatory)][hashtable]$TargetProfile,
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$TargetAvailability,
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$RankedRecommendations,
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$Warnings,
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$BelowMinSpec,
        [Parameter(Mandatory)][int]$MinScore,
        [Parameter(Mandatory)][int]$TopN,
        [Parameter(Mandatory)][bool]$FetchPricing,
        [Parameter(Mandatory)][bool]$ShowPlacement,
        [Parameter(Mandatory)][bool]$ShowSpot
    )

    $rankedPayload = [System.Collections.Generic.List[object]]::new()
    $rank = 1
    foreach ($item in @($RankedRecommendations)) {
        $rankedPayload.Add([pscustomobject]@{
            rank       = $rank
            sku        = $item.SKU
            region     = $item.Region
            vCPU       = $item.vCPU
            memGiB     = $item.MemGiB
            family     = $item.Family
            purpose    = $item.Purpose
            gen        = $item.Gen
            arch       = $item.Arch
            cpu        = $item.CPU
            disk       = $item.Disk
            tempDiskGB = $item.TempGB
            accelNet   = $item.AccelNet
            maxDisks   = $item.MaxDisks
            maxNICs    = $item.MaxNICs
            iops       = $item.IOPS
            score      = $item.Score
            capacity   = $item.Capacity
            allocScore = $item.AllocScore
            zonesOK    = $item.ZonesOK
            priceHr    = $item.PriceHr
            priceMo    = $item.PriceMo
            spotPriceHr = $item.SpotPriceHr
            spotPriceMo = $item.SpotPriceMo
        })
        $rank++
    }

    $belowMinSpecPayload = [System.Collections.Generic.List[object]]::new()
    foreach ($item in @($BelowMinSpec)) {
        $belowMinSpecPayload.Add([pscustomobject]@{
            sku      = $item.SKU
            region   = $item.Region
            vCPU     = $item.vCPU
            memGiB   = $item.MemGiB
            score    = $item.Score
            capacity = $item.Capacity
        })
    }

    return [pscustomobject]@{
        schemaVersion      = '1.0'
        mode               = 'recommend'
        generatedAt        = (Get-Date).ToString('o')
        minScore           = $MinScore
        topN               = $TopN
        pricingEnabled     = $FetchPricing
        placementEnabled   = $ShowPlacement
        spotPricingEnabled = ($FetchPricing -and $ShowSpot)
        target             = [pscustomobject]$TargetProfile
        targetAvailability = @($TargetAvailability)
        recommendations    = @($rankedPayload)
        warnings           = @($Warnings)
        belowMinSpec       = @($belowMinSpecPayload)
    }
}
