function Invoke-RecommendMode {
    param(
        [Parameter(Mandatory)]
        [string]$TargetSkuName,

        [Parameter(Mandatory)]
        [array]$SubscriptionData,

        [hashtable]$FamilyInfo = @{},

        [hashtable]$Icons = @{},

        [bool]$FetchPricing = $false,

        [bool]$ShowSpot = $false,

        [bool]$ShowPlacement = $false,

        [bool]$AllowMixedArch = $false,

        [int]$MinvCPU = 0,

        [int]$MinMemoryGB = 0,

        [Nullable[int]]$MinScore,

        [int]$TopN = 5,

        [int]$DesiredCount = 1,

        [bool]$JsonOutput = $false,

        [int]$MaxRetries = 3,

        [Parameter(Mandatory)]
        [pscustomobject]$RunContext,

        [int]$OutputWidth = 122,

        [hashtable]$SkuProfileCache = $null
    )

    $targetSku = $null
    $targetRegionStatus = @()

    foreach ($subData in $SubscriptionData) {
        foreach ($data in $subData.RegionData) {
            $region = Get-SafeString $data.Region
            if ($data.Error) { continue }
            foreach ($sku in $data.Skus) {
                if ($sku.Name -eq $TargetSkuName) {
                    $restrictions = Get-RestrictionDetails $sku
                    $targetRegionStatus += [pscustomobject]@{
                        Region  = [string]$region
                        Status  = $restrictions.Status
                        ZonesOK = $restrictions.ZonesOK.Count
                    }
                    if (-not $targetSku) { $targetSku = $sku }
                }
            }
        }
    }

    if (-not $targetSku) {
        Write-Host "`nSKU '$TargetSkuName' was not found in any scanned region." -ForegroundColor Red
        Write-Host "Check the SKU name and ensure the scanned regions support this SKU family." -ForegroundColor Yellow
        return
    }

    $targetCaps = Get-SkuCapabilities -Sku $targetSku
    $targetProcessor = Get-ProcessorVendor -SkuName $targetSku.Name
    $targetHasNvme = $targetCaps.NvmeSupport
    $targetDiskCode = Get-DiskCode -HasTempDisk ($targetCaps.TempDiskGB -gt 0) -HasNvme $targetHasNvme
    $targetProfile = @{
        Name                     = $targetSku.Name
        vCPU                     = [int](Get-CapValue $targetSku 'vCPUs')
        MemoryGB                 = [int](Get-CapValue $targetSku 'MemoryGB')
        Family                   = Get-SkuFamily $targetSku.Name
        FamilyVersion            = Get-SkuFamilyVersion $targetSku.Name
        Generation               = $targetCaps.HyperVGenerations
        Architecture             = $targetCaps.CpuArchitecture
        PremiumIO                = (Get-CapValue $targetSku 'PremiumIO') -eq 'True'
        Processor                = $targetProcessor
        TempDiskGB               = $targetCaps.TempDiskGB
        DiskCode                 = $targetDiskCode
        AccelNet                 = $targetCaps.AcceleratedNetworkingEnabled
        MaxDataDiskCount         = $targetCaps.MaxDataDiskCount
        MaxNetworkInterfaces     = $targetCaps.MaxNetworkInterfaces
        EphemeralOSDiskSupported = $targetCaps.EphemeralOSDiskSupported
        UltraSSDAvailable        = $targetCaps.UltraSSDAvailable
        UncachedDiskIOPS         = $targetCaps.UncachedDiskIOPS
        UncachedDiskBytesPerSecond = $targetCaps.UncachedDiskBytesPerSecond
        EncryptionAtHostSupported = $targetCaps.EncryptionAtHostSupported
    }

    # Score all candidate SKUs across all regions
    $candidates = [System.Collections.Generic.List[object]]::new()
    foreach ($subData in $SubscriptionData) {
        foreach ($data in $subData.RegionData) {
            $region = Get-SafeString $data.Region
            if ($data.Error) { continue }
            foreach ($sku in $data.Skus) {
                if ($sku.Name -eq $TargetSkuName) { continue }

                $restrictions = Get-RestrictionDetails $sku
                if ($restrictions.Status -eq 'RESTRICTED') { continue }

                # Use cached profile if available; otherwise build and cache it
                $candidateProfile = $null
                $caps = $null
                $candidateProcessor = $null
                $candidateDiskCode = $null
                if ($SkuProfileCache -and $SkuProfileCache.ContainsKey($sku.Name)) {
                    $cached = $SkuProfileCache[$sku.Name]
                    $candidateProfile = $cached.Profile
                    $caps = $cached.Caps
                    $candidateProcessor = $cached.Processor
                    $candidateDiskCode = $cached.DiskCode
                }
                else {
                    $caps = Get-SkuCapabilities -Sku $sku
                    $candidateProcessor = Get-ProcessorVendor -SkuName $sku.Name
                    $candidateHasNvme = $caps.NvmeSupport
                    $candidateDiskCode = Get-DiskCode -HasTempDisk ($caps.TempDiskGB -gt 0) -HasNvme $candidateHasNvme
                    $candidateProfile = @{
                        Name                     = $sku.Name
                        vCPU                     = [int](Get-CapValue $sku 'vCPUs')
                        MemoryGB                 = [int](Get-CapValue $sku 'MemoryGB')
                        Family                   = Get-SkuFamily $sku.Name
                        FamilyVersion            = Get-SkuFamilyVersion $sku.Name
                        Generation               = $caps.HyperVGenerations
                        Architecture             = $caps.CpuArchitecture
                        PremiumIO                = (Get-CapValue $sku 'PremiumIO') -eq 'True'
                        DiskCode                 = $candidateDiskCode
                        AccelNet                 = $caps.AcceleratedNetworkingEnabled
                        MaxDataDiskCount         = $caps.MaxDataDiskCount
                        MaxNetworkInterfaces     = $caps.MaxNetworkInterfaces
                        EphemeralOSDiskSupported = $caps.EphemeralOSDiskSupported
                        UltraSSDAvailable        = $caps.UltraSSDAvailable
                        UncachedDiskIOPS         = $caps.UncachedDiskIOPS
                        UncachedDiskBytesPerSecond = $caps.UncachedDiskBytesPerSecond
                        EncryptionAtHostSupported = $caps.EncryptionAtHostSupported
                    }
                    if ($SkuProfileCache) {
                        $SkuProfileCache[$sku.Name] = @{ Profile = $candidateProfile; Caps = $caps; Processor = $candidateProcessor; DiskCode = $candidateDiskCode }
                    }
                }

                # Architecture filtering — skip candidates that don't match target arch unless opted out
                if (-not $AllowMixedArch -and $candidateProfile.Architecture -ne $targetProfile.Architecture) {
                    continue
                }

                # Hard compatibility gate — candidate must meet or exceed target on critical dimensions
                $compat = Test-SkuCompatibility -Target $targetProfile -Candidate $candidateProfile
                if (-not $compat.Compatible) { continue }

                $simScore = Get-SkuSimilarityScore -Target $targetProfile -Candidate $candidateProfile -FamilyInfo $FamilyInfo

                $priceHr = $null
                $priceMo = $null
                $spotPriceHr = $null
                $spotPriceMo = $null
                if ($FetchPricing -and $RunContext.RegionPricing[[string]$region]) {
                    $regionPriceData = $RunContext.RegionPricing[[string]$region]
                    $regularPriceMap = Get-RegularPricingMap -PricingContainer $regionPriceData
                    $spotPriceMap = Get-SpotPricingMap -PricingContainer $regionPriceData
                    $skuPricing = $regularPriceMap[$sku.Name]
                    if ($skuPricing) {
                        $priceHr = $skuPricing.Hourly
                        $priceMo = $skuPricing.Monthly
                    }
                    if ($ShowSpot) {
                        $spotPricing = $spotPriceMap[$sku.Name]
                        if ($spotPricing) {
                            $spotPriceHr = $spotPricing.Hourly
                            $spotPriceMo = $spotPricing.Monthly
                        }
                    }
                }

                $candidates.Add([pscustomobject]@{
                        SKU      = $sku.Name
                        Region   = [string]$region
                        vCPU     = $candidateProfile.vCPU
                        MemGiB   = $candidateProfile.MemoryGB
                        Family   = $candidateProfile.Family
                        Purpose  = if ($FamilyInfo[$candidateProfile.Family]) { $FamilyInfo[$candidateProfile.Family].Purpose } else { '' }
                        Gen      = (($caps.HyperVGenerations -replace 'V', '') -replace ',', ',')
                        Arch     = $candidateProfile.Architecture
                        CPU      = $candidateProcessor
                        Disk     = $candidateDiskCode
                        TempGB   = $caps.TempDiskGB
                        AccelNet = $caps.AcceleratedNetworkingEnabled
                        MaxDisks = $caps.MaxDataDiskCount
                        MaxNICs  = $caps.MaxNetworkInterfaces
                        IOPS     = $caps.UncachedDiskIOPS
                        Score    = $simScore
                        Capacity = $restrictions.Status
                        ZonesOK  = $restrictions.ZonesOK.Count
                        PriceHr  = $priceHr
                        PriceMo  = $priceMo
                        SpotPriceHr = $spotPriceHr
                        SpotPriceMo = $spotPriceMo
                    }) | Out-Null
            }
        }
    }

    # Apply minimum spec filters and separate smaller options for callout
    $belowMinSpecDict = @{}
    $filtered = @($candidates)
    if ($MinvCPU) {
        $filtered | Where-Object { $_.vCPU -lt $MinvCPU -and $_.Capacity -eq 'OK' } | ForEach-Object {
            if (-not $belowMinSpecDict.ContainsKey($_.SKU)) { $belowMinSpecDict[$_.SKU] = $_ }
        }
        $filtered = @($filtered | Where-Object { $_.vCPU -ge $MinvCPU })
    }
    if ($MinMemoryGB) {
        $filtered | Where-Object { $_.MemGiB -lt $MinMemoryGB -and $_.Capacity -eq 'OK' } | ForEach-Object {
            if (-not $belowMinSpecDict.ContainsKey($_.SKU)) { $belowMinSpecDict[$_.SKU] = $_ }
        }
        $filtered = @($filtered | Where-Object { $_.MemGiB -ge $MinMemoryGB })
    }
    $belowMinSpec = @($belowMinSpecDict.Values)

    if ($null -ne $MinScore) {
        $filtered = @($filtered | Where-Object { $_.Score -ge $MinScore })
    }

    if (-not $filtered -or $filtered.Count -eq 0) {
        $RunContext.RecommendOutput = New-RecommendOutputContract -TargetProfile $targetProfile -TargetAvailability @($targetRegionStatus) -RankedRecommendations @() -Warnings @() -BelowMinSpec @($belowMinSpec) -MinScore $MinScore -TopN $TopN -FetchPricing ([bool]$FetchPricing) -ShowPlacement ([bool]$ShowPlacement) -ShowSpot ([bool]$ShowSpot
        )
        if ($JsonOutput) {
            $RunContext.RecommendOutput | ConvertTo-Json -Depth 6
            return
        }

        Write-RecommendOutputContract -Contract $RunContext.RecommendOutput -Icons $Icons -FetchPricing ([bool]$FetchPricing) -FamilyInfo $FamilyInfo -OutputWidth $OutputWidth
        return
    }

    $ranked = $filtered |
    Sort-Object @{Expression = 'Score'; Descending = $true },
    @{Expression = { if ($_.Capacity -eq 'OK') { 0 } elseif ($_.Capacity -eq 'LIMITED') { 1 } else { 2 } } },
    @{Expression = 'ZonesOK'; Descending = $true } |
    Group-Object SKU |
    ForEach-Object { $_.Group | Select-Object -First 1 } |
    Select-Object -First $TopN

    if ($ShowPlacement) {
        $placementScores = Get-PlacementScores -SkuNames @($ranked | Select-Object -ExpandProperty SKU) -Regions @($ranked | Select-Object -ExpandProperty Region) -DesiredCount $DesiredCount -MaxRetries $MaxRetries -Caches $RunContext.Caches
        $ranked = @($ranked | ForEach-Object {
                $item = $_
                $key = "{0}|{1}" -f $item.SKU, $item.Region.ToLower()
                $allocScore = if ($placementScores.ContainsKey($key)) { $placementScores[$key].Score } else { 'N/A' }
                [pscustomobject]@{
                    SKU       = $item.SKU
                    Region    = $item.Region
                    vCPU      = $item.vCPU
                    MemGiB    = $item.MemGiB
                    Family    = $item.Family
                    Purpose   = $item.Purpose
                    Gen       = $item.Gen
                    Arch      = $item.Arch
                    CPU       = $item.CPU
                    Disk      = $item.Disk
                    TempGB    = $item.TempGB
                    AccelNet  = $item.AccelNet
                    MaxDisks  = $item.MaxDisks
                    MaxNICs   = $item.MaxNICs
                    IOPS      = $item.IOPS
                    Score     = $item.Score
                    Capacity  = $item.Capacity
                    AllocScore = $allocScore
                    ZonesOK   = $item.ZonesOK
                    PriceHr   = $item.PriceHr
                    PriceMo   = $item.PriceMo
                    SpotPriceHr = $item.SpotPriceHr
                    SpotPriceMo = $item.SpotPriceMo
                }
            })
    }
    else {
        $ranked = @($ranked | ForEach-Object {
                $item = $_
                [pscustomobject]@{
                    SKU       = $item.SKU
                    Region    = $item.Region
                    vCPU      = $item.vCPU
                    MemGiB    = $item.MemGiB
                    Family    = $item.Family
                    Purpose   = $item.Purpose
                    Gen       = $item.Gen
                    Arch      = $item.Arch
                    CPU       = $item.CPU
                    Disk      = $item.Disk
                    TempGB    = $item.TempGB
                    AccelNet  = $item.AccelNet
                    MaxDisks  = $item.MaxDisks
                    MaxNICs   = $item.MaxNICs
                    IOPS      = $item.IOPS
                    Score     = $item.Score
                    Capacity  = $item.Capacity
                    AllocScore = $null
                    ZonesOK   = $item.ZonesOK
                    PriceHr   = $item.PriceHr
                    PriceMo   = $item.PriceMo
                    SpotPriceHr = $item.SpotPriceHr
                    SpotPriceMo = $item.SpotPriceMo
                }
            })
    }

    # Compatibility warning detection (shared by JSON and console output)
    $compatWarnings = @()
    $uniqueCPUs = @($ranked | Select-Object -ExpandProperty CPU -Unique)
    $uniqueAccelNet = @($ranked | Select-Object -ExpandProperty AccelNet -Unique)
    if ($AllowMixedArch) {
        $uniqueArchs = @($ranked | Select-Object -ExpandProperty Arch -Unique)
        if ($uniqueArchs.Count -gt 1) {
            $compatWarnings += "Mixed architectures (x64 + ARM64) — each requires a separate OS image."
        }
    }
    if ($uniqueCPUs.Count -gt 1) {
        $compatWarnings += "Mixed CPU vendors ($($uniqueCPUs -join ', ')) — performance characteristics vary."
    }
    $hasTempDisk = @($ranked | Where-Object { $_.Disk -match 'T' })
    $noTempDisk = @($ranked | Where-Object { $_.Disk -notmatch 'T' })
    if ($hasTempDisk.Count -gt 0 -and $noTempDisk.Count -gt 0) {
        $compatWarnings += "Mixed temp disk configs — some SKUs have local temp disk, others don't. Drive paths differ."
    }
    $hasNvme = @($ranked | Where-Object { $_.Disk -match 'NV' })
    $hasScsi = @($ranked | Where-Object { $_.Disk -match 'SC' })
    if ($hasNvme.Count -gt 0 -and $hasScsi.Count -gt 0) {
        $compatWarnings += "Mixed storage interfaces (NVMe vs SCSI) — disk driver and device path differences."
    }
    if ($uniqueAccelNet.Count -gt 1) {
        $compatWarnings += "Mixed accelerated networking support — network performance will vary across the inventory."
    }

    $RunContext.RecommendOutput = New-RecommendOutputContract -TargetProfile $targetProfile -TargetAvailability @($targetRegionStatus) -RankedRecommendations @($ranked) -Warnings @($compatWarnings) -BelowMinSpec @($belowMinSpec) -MinScore $MinScore -TopN $TopN -FetchPricing ([bool]$FetchPricing) -ShowPlacement ([bool]$ShowPlacement) -ShowSpot ([bool]$ShowSpot
    )

    if ($JsonOutput) {
        $RunContext.RecommendOutput | ConvertTo-Json -Depth 6
        return
    }

    Write-RecommendOutputContract -Contract $RunContext.RecommendOutput -Icons $Icons -FetchPricing ([bool]$FetchPricing) -FamilyInfo $FamilyInfo -OutputWidth $OutputWidth
}
