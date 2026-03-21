function New-ScanOutputContract {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$SubscriptionData,
        [Parameter(Mandatory)][hashtable]$FamilyStats,
        [Parameter(Mandatory)][AllowEmptyCollection()][array]$FamilyDetails,
        [Parameter(Mandatory)][string[]]$Regions,
        [Parameter(Mandatory)][string[]]$SubscriptionIds
    )

    $families = @(
        $FamilyStats.Keys | Sort-Object | ForEach-Object {
            $family = $_
            $familyData = $FamilyStats[$family]
            [pscustomobject]@{
                family                 = $family
                totalSkusDiscovered    = $familyData.TotalSkus
                availableRegionCount   = $familyData.AvailableRegions.Count
                constrainedRegionCount = $familyData.ConstrainedRegions.Count
                largestSku             = $familyData.LargestSKU
            }
        }
    )

    $regionErrors = @()
    foreach ($sub in $SubscriptionData) {
        foreach ($regionData in $sub.RegionData) {
            if ($regionData.Error) {
                $regionErrors += [pscustomobject]@{
                    subscriptionId = $sub.SubscriptionId
                    region         = [string](Get-SafeString $regionData.Region)
                    error          = $regionData.Error
                }
            }
        }
    }

    return [pscustomobject]@{
        schemaVersion = '1.0'
        mode          = 'scan'
        generatedAt   = (Get-Date).ToString('o')
        subscriptions = @($SubscriptionIds)
        regions       = @($Regions)
        summary       = [pscustomobject]@{
            familyCount      = $families.Count
            detailRowCount   = @($FamilyDetails).Count
            regionErrorCount = @($regionErrors).Count
        }
        families      = @($families)
        regionErrors  = @($regionErrors)
    }
}
