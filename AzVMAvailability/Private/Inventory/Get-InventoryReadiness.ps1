function Get-InventoryReadiness {
    [Alias('Get-FleetReadiness')]
    <#
    .SYNOPSIS
        Validates an inventory BOM against scan data to produce per-SKU and per-quota-family readiness.
    .DESCRIPTION
        Takes an Inventory hashtable (SKU=Qty) and scan data, then checks:
        1. Does each SKU exist in the scanned regions?
        2. What is the capacity status for each SKU?
        3. Does the quota family have enough available vCPUs for the aggregated demand?
    #>
    param(
        [Parameter(Mandatory)]
        [Alias('Fleet')]
        [hashtable]$Inventory,

        [Parameter(Mandatory)]
        [array]$SubscriptionData
    )

    $results = [System.Collections.Generic.List[PSCustomObject]]::new()
    $quotaDemandByFamily = @{}

    foreach ($skuName in $Inventory.Keys) {
        $normalizedSku = $skuName
        $qty = [int]$Inventory[$skuName]

        $foundInAnyRegion = $false
        $bestStatus = 'NOT FOUND'
        $bestRegion = $null
        $skuVcpu = 0
        $skuFamily = $null
        $skuMemGiB = 0
        $quotaAvailable = $null
        $quotaLimit = $null
        $quotaCurrent = $null

        foreach ($subData in $SubscriptionData) {
            foreach ($regionData in $subData.RegionData) {
                if ($regionData.Error) { continue }
                $region = Get-SafeString $regionData.Region

                foreach ($sku in $regionData.Skus) {
                    if ($sku.Name -ne $normalizedSku) { continue }
                    $foundInAnyRegion = $true
                    $skuVcpu = [int](Get-CapValue $sku 'vCPUs')
                    $skuMemGiB = [int](Get-CapValue $sku 'MemoryGB')
                    $skuFamily = $sku.Family

                    $restrictions = Get-RestrictionDetails $sku
                    $status = $restrictions.Status

                    # Rank: OK > LIMITED > CAPACITY-CONSTRAINED > RESTRICTED > BLOCKED
                    $statusRank = switch ($status) {
                        'OK' { 5 }
                        'LIMITED' { 4 }
                        'CAPACITY-CONSTRAINED' { 3 }
                        'PARTIAL' { 2 }
                        'RESTRICTED' { 1 }
                        default { 0 }
                    }
                    $bestRank = switch ($bestStatus) {
                        'OK' { 5 }
                        'LIMITED' { 4 }
                        'CAPACITY-CONSTRAINED' { 3 }
                        'PARTIAL' { 2 }
                        'RESTRICTED' { 1 }
                        'NOT FOUND' { -1 }
                        default { 0 }
                    }

                    if ($statusRank -gt $bestRank) {
                        $bestStatus = $status
                        $bestRegion = $region
                    }

                    # Build quota lookup for this region
                    $quotaLookup = @{}
                    foreach ($q in $regionData.Quotas) { $quotaLookup[$q.Name.Value] = $q }

                    # Try exact match first, then substring fallback
                    $matchedFamily = $skuFamily
                    if ($skuFamily -and -not $quotaLookup[$skuFamily]) {
                        $fallback = $quotaLookup.Keys | Where-Object { $skuFamily -like "*$_*" -or $_ -like "*$skuFamily*" } | Select-Object -First 1
                        if ($fallback) { $matchedFamily = $fallback }
                    }

                    if ($matchedFamily -and $quotaLookup[$matchedFamily]) {
                        $qInfo = Get-QuotaAvailable -QuotaLookup $quotaLookup -SkuFamily $matchedFamily
                        $quotaAvailable = $qInfo.Available
                        $quotaLimit = $qInfo.Limit
                        $quotaCurrent = $qInfo.Current
                    }
                }
            }
        }

        $totalVcpuDemand = $qty * $skuVcpu

        # Aggregate demand per quota family for cross-SKU quota check
        if ($skuFamily) {
            if (-not $quotaDemandByFamily.ContainsKey($skuFamily)) {
                $quotaDemandByFamily[$skuFamily] = @{ Demand = 0; Available = $quotaAvailable; Limit = $quotaLimit; Current = $quotaCurrent }
            }
            $quotaDemandByFamily[$skuFamily].Demand += $totalVcpuDemand
        }

        $results.Add([pscustomobject]@{
            SKU           = $normalizedSku
            Qty           = $qty
            vCPUEach      = $skuVcpu
            MemGiBEach    = $skuMemGiB
            TotalvCPU     = $totalVcpuDemand
            QuotaFamily   = if ($skuFamily) { $skuFamily } else { '?' }
            Capacity      = $bestStatus
            BestRegion    = if ($bestRegion) { $bestRegion } else { '-' }
            QuotaUsed     = if ($null -ne $quotaCurrent) { $quotaCurrent } else { '?' }
            QuotaAvail    = if ($null -ne $quotaAvailable) { $quotaAvailable } else { '?' }
            QuotaLimit    = if ($null -ne $quotaLimit) { $quotaLimit } else { '?' }
            Found         = $foundInAnyRegion
        })
    }

    # Compute per-family quota pass/fail
    $familyResults = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($family in $quotaDemandByFamily.Keys) {
        $entry = $quotaDemandByFamily[$family]
        $pass = if ($null -ne $entry.Available) { $entry.Available -ge $entry.Demand } else { $null }
        $familyResults.Add([pscustomobject]@{
            QuotaFamily   = $family
            TotalDemand   = $entry.Demand
            Used          = if ($null -ne $entry.Current) { $entry.Current } else { '?' }
            Available     = if ($null -ne $entry.Available) { $entry.Available } else { '?' }
            Limit         = if ($null -ne $entry.Limit) { $entry.Limit } else { '?' }
            Pass          = $pass
        })
    }

    return @{
        SKUs    = @($results)
        Quotas  = @($familyResults)
    }
}
