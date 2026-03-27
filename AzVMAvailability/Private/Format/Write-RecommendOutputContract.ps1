function Write-RecommendOutputContract {
    param(
        [Parameter(Mandatory)][pscustomobject]$Contract,
        [Parameter(Mandatory)][hashtable]$Icons,
        [Parameter(Mandatory)][bool]$FetchPricing,
        [Parameter(Mandatory)][hashtable]$FamilyInfo,
        [int]$OutputWidth = 122
    )

    $targetProfile = $Contract.target
    $targetAvailability = @($Contract.targetAvailability)
    $recommendations = @($Contract.recommendations)
    $placementEnabled = [bool]$Contract.placementEnabled
    $spotPricingEnabled = [bool]$Contract.spotPricingEnabled
    $compatWarnings = @($Contract.warnings)

    Write-Host "`n" -NoNewline
    Write-Host ("=" * $OutputWidth) -ForegroundColor Gray
    Write-Host "CAPACITY RECOMMENDER" -ForegroundColor Green
    Write-Host ("=" * $OutputWidth) -ForegroundColor Gray
    Write-Host ""

    $targetPurpose = if ($FamilyInfo[$targetProfile.Family]) { $FamilyInfo[$targetProfile.Family].Purpose } else { 'Unknown' }
    $skuSuffixes = @()
    $skuBody = ($targetProfile.Name -replace '^Standard_', '') -replace '_v\d+$', ''
    if ($skuBody -match 'a(?![\d])') { $skuSuffixes += 'a = AMD processor' }
    if ($skuBody -match 'p(?![\d])') { $skuSuffixes += 'p = ARM processor (Ampere)' }
    if ($skuBody -notmatch '[ap](?![\d])') { $skuSuffixes += '(no a/p suffix) = Intel processor' }
    if ($skuBody -match 'd(?![\d])') {
        if ($targetProfile.TempDiskGB -gt 0) {
            $skuSuffixes += "d = Local temp disk ($($targetProfile.TempDiskGB) GB)"
        }
        else {
            $skuSuffixes += 'd = Local temp disk'
        }
    }
    if ($skuBody -match 's$') { $skuSuffixes += 's = Premium storage capable' }
    if ($skuBody -match 'i(?![\d])') { $skuSuffixes += 'i = Isolated (dedicated host)' }
    if ($skuBody -match 'm(?![\d])') { $skuSuffixes += 'm = High memory per vCPU' }
    if ($skuBody -match 'l(?![\d])') { $skuSuffixes += 'l = Low memory per vCPU' }
    if ($skuBody -match 't(?![\d])') { $skuSuffixes += 't = Constrained vCPU' }
    $genMatch = if ($targetProfile.Name -match '_v(\d+)$') { "v$($Matches[1]) = Generation $($Matches[1])" } else { $null }

    Write-Host "TARGET: $($targetProfile.Name)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host '  Name breakdown:' -ForegroundColor DarkGray
    Write-Host "    $($targetProfile.Family)        $targetPurpose (family)" -ForegroundColor DarkGray
    Write-Host "    $($targetProfile.vCPU)       vCPUs" -ForegroundColor DarkGray
    foreach ($suffix in $skuSuffixes) {
        Write-Host "    $suffix" -ForegroundColor DarkGray
    }
    if ($genMatch) {
        Write-Host "    $genMatch" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "  $($targetProfile.vCPU) vCPU / $($targetProfile.MemoryGB) GiB / $($targetProfile.Architecture) / $($targetProfile.Processor) / $($targetProfile.DiskCode) / Premium IO: $(if ($targetProfile.PremiumIO) { 'Yes' } else { 'No' })" -ForegroundColor White
    Write-Host ""

    $availableRegions = @($targetAvailability | Where-Object { $_.Status -eq 'OK' })
    $unavailableRegions = @($targetAvailability | Where-Object { $_.Status -ne 'OK' })
    if ($availableRegions.Count -gt 0) {
        $availableRegionNames = @($availableRegions | ForEach-Object { $_.Region })
        Write-Host "  $($Icons.Check) Available in: $($availableRegionNames -join ', ')" -ForegroundColor Green
    }
    foreach ($ur in $unavailableRegions) {
        Write-Host "  $($Icons.Error) $($ur.Region): $($ur.Status)" -ForegroundColor Red
    }

    if ($recommendations.Count -eq 0) {
        Write-Host "`nNo alternatives met the minimum similarity score of $($Contract.minScore)%." -ForegroundColor Yellow
        Write-Host 'Try lowering -MinScore or adding -MinvCPU / -MinMemoryGB filters.' -ForegroundColor DarkYellow
        return
    }

    Write-Host "`nRECOMMENDED ALTERNATIVES (top $($recommendations.Count), sorted by similarity):" -ForegroundColor Green
    Write-Host ""

    if ($FetchPricing -and $placementEnabled -and $spotPricingEnabled) {
        $headerFmt = " {0,-3} {1,-28} {2,-12} {3,-5} {4,-7} {5,-6} {6,-6} {7,-5} {8,-20} {9,-12} {10,-8} {11,-5} {12,-8} {13,-8} {14,-10} {15,-10}"
        Write-Host ($headerFmt -f '#', 'SKU', 'Region', 'vCPU', 'Mem(GB)', 'Score', 'CPU', 'Disk', 'Type', 'Capacity', 'Alloc', 'Zones', '$/Hr', '$/Mo', 'Spot$/Hr', 'Spot$/Mo') -ForegroundColor White
        Write-Host (' ' + ('-' * 169)) -ForegroundColor DarkGray
    }
    elseif ($FetchPricing -and $placementEnabled) {
        $headerFmt = " {0,-3} {1,-28} {2,-12} {3,-5} {4,-7} {5,-6} {6,-6} {7,-5} {8,-20} {9,-12} {10,-8} {11,-5} {12,-8} {13,-8}"
        Write-Host ($headerFmt -f '#', 'SKU', 'Region', 'vCPU', 'Mem(GB)', 'Score', 'CPU', 'Disk', 'Type', 'Capacity', 'Alloc', 'Zones', '$/Hr', '$/Mo') -ForegroundColor White
        Write-Host (' ' + ('-' * 147)) -ForegroundColor DarkGray
    }
    elseif ($FetchPricing -and $spotPricingEnabled) {
        $headerFmt = " {0,-3} {1,-28} {2,-12} {3,-5} {4,-7} {5,-6} {6,-6} {7,-5} {8,-20} {9,-12} {10,-5} {11,-8} {12,-8} {13,-10} {14,-10}"
        Write-Host ($headerFmt -f '#', 'SKU', 'Region', 'vCPU', 'Mem(GB)', 'Score', 'CPU', 'Disk', 'Type', 'Capacity', 'Zones', '$/Hr', '$/Mo', 'Spot$/Hr', 'Spot$/Mo') -ForegroundColor White
        Write-Host (' ' + ('-' * 159)) -ForegroundColor DarkGray
    }
    elseif ($FetchPricing) {
        $headerFmt = " {0,-3} {1,-28} {2,-12} {3,-5} {4,-7} {5,-6} {6,-6} {7,-5} {8,-20} {9,-12} {10,-5} {11,-8} {12,-8}"
        Write-Host ($headerFmt -f '#', 'SKU', 'Region', 'vCPU', 'Mem(GB)', 'Score', 'CPU', 'Disk', 'Type', 'Capacity', 'Zones', '$/Hr', '$/Mo') -ForegroundColor White
        Write-Host (' ' + ('-' * 137)) -ForegroundColor DarkGray
    }
    elseif ($placementEnabled) {
        $headerFmt = " {0,-3} {1,-28} {2,-12} {3,-5} {4,-7} {5,-6} {6,-6} {7,-5} {8,-20} {9,-12} {10,-8} {11,-5}"
        Write-Host ($headerFmt -f '#', 'SKU', 'Region', 'vCPU', 'Mem(GB)', 'Score', 'CPU', 'Disk', 'Type', 'Capacity', 'Alloc', 'Zones') -ForegroundColor White
        Write-Host (' ' + ('-' * 129)) -ForegroundColor DarkGray
    }
    else {
        $headerFmt = " {0,-3} {1,-28} {2,-12} {3,-5} {4,-7} {5,-6} {6,-6} {7,-5} {8,-20} {9,-12} {10,-5}"
        Write-Host ($headerFmt -f '#', 'SKU', 'Region', 'vCPU', 'Mem(GB)', 'Score', 'CPU', 'Disk', 'Type', 'Capacity', 'Zones') -ForegroundColor White
        Write-Host (' ' + ('-' * 119)) -ForegroundColor DarkGray
    }

    foreach ($r in $recommendations) {
        $rowColor = switch ($r.capacity) {
            'OK' { 'Green' }
            'LIMITED' { 'Yellow' }
            default { 'DarkYellow' }
        }
        if ($FetchPricing) {
            $hrStr = if ($null -ne $r.priceHr) { '$' + ([double]$r.priceHr).ToString('0.00') } else { '-' }
            $moStr = if ($null -ne $r.priceMo) { '$' + ([double]$r.priceMo).ToString('0') } else { '-' }
            $spotHrStr = if ($null -ne $r.spotPriceHr) { '$' + ([double]$r.spotPriceHr).ToString('0.00') } else { '-' }
            $spotMoStr = if ($null -ne $r.spotPriceMo) { '$' + ([double]$r.spotPriceMo).ToString('0') } else { '-' }
            if ($placementEnabled -and $spotPricingEnabled) {
                $allocStr = if ($r.allocScore) { [string]$r.allocScore } else { '-' }
                $line = $headerFmt -f $r.rank, $r.sku, $r.region, $r.vCPU, $r.memGiB, ("$($r.score)%"), $r.cpu, $r.disk, $r.purpose, $r.capacity, $allocStr, $r.zonesOK, $hrStr, $moStr, $spotHrStr, $spotMoStr
            }
            elseif ($placementEnabled) {
                $allocStr = if ($r.allocScore) { [string]$r.allocScore } else { '-' }
                $line = $headerFmt -f $r.rank, $r.sku, $r.region, $r.vCPU, $r.memGiB, ("$($r.score)%"), $r.cpu, $r.disk, $r.purpose, $r.capacity, $allocStr, $r.zonesOK, $hrStr, $moStr
            }
            elseif ($spotPricingEnabled) {
                $line = $headerFmt -f $r.rank, $r.sku, $r.region, $r.vCPU, $r.memGiB, ("$($r.score)%"), $r.cpu, $r.disk, $r.purpose, $r.capacity, $r.zonesOK, $hrStr, $moStr, $spotHrStr, $spotMoStr
            }
            else {
                $line = $headerFmt -f $r.rank, $r.sku, $r.region, $r.vCPU, $r.memGiB, ("$($r.score)%"), $r.cpu, $r.disk, $r.purpose, $r.capacity, $r.zonesOK, $hrStr, $moStr
            }
        }
        else {
            if ($placementEnabled) {
                $allocStr = if ($r.allocScore) { [string]$r.allocScore } else { '-' }
                $line = $headerFmt -f $r.rank, $r.sku, $r.region, $r.vCPU, $r.memGiB, ("$($r.score)%"), $r.cpu, $r.disk, $r.purpose, $r.capacity, $allocStr, $r.zonesOK
            }
            else {
                $line = $headerFmt -f $r.rank, $r.sku, $r.region, $r.vCPU, $r.memGiB, ("$($r.score)%"), $r.cpu, $r.disk, $r.purpose, $r.capacity, $r.zonesOK
            }
        }
        Write-Host $line -ForegroundColor $rowColor
    }

    $hasOkCapacity = (@($recommendations | Where-Object { $_.capacity -eq 'OK' }).Count -gt 0)
    if (-not $hasOkCapacity -and @($Contract.belowMinSpec).Count -gt 0) {
        $smallerOK = $Contract.belowMinSpec |
        Sort-Object @{Expression = 'score'; Descending = $true } |
        Group-Object sku |
        ForEach-Object { $_.Group | Select-Object -First 1 } |
        Select-Object -First 3

        if ($smallerOK.Count -gt 0) {
            Write-Host ""
            Write-Host "  $($Icons.Warning) CONSIDER SMALLER (better availability, if your workload supports it):" -ForegroundColor Yellow
            foreach ($s in $smallerOK) {
                Write-Host "    $($s.sku) ($($s.vCPU) vCPU / $($s.memGiB) GiB) — $($s.capacity) in $($s.region)" -ForegroundColor DarkYellow
            }
        }
    }

    Write-Host ''
    Write-Host 'STATUS KEY:' -ForegroundColor DarkGray
    Write-Host '  OK                    = Ready to deploy. No restrictions.' -ForegroundColor Green
    Write-Host '  CAPACITY-CONSTRAINED  = Azure is low on hardware. Try a different zone or wait.' -ForegroundColor Yellow
    Write-Host "  LIMITED               = Your subscription can't use this. Request access via support ticket." -ForegroundColor Yellow
    Write-Host '  PARTIAL               = Some zones work, others are blocked. No zone redundancy.' -ForegroundColor Yellow
    Write-Host '  BLOCKED               = Cannot deploy. Pick a different region or SKU.' -ForegroundColor Red
    Write-Host ''
    Write-Host 'DISK CODES:' -ForegroundColor DarkGray
    Write-Host '  NV+T = NVMe + local temp disk   NVMe = NVMe only (no temp disk)' -ForegroundColor DarkGray
    Write-Host '  SC+T = SCSI + local temp disk   SCSI = SCSI only (no temp disk)' -ForegroundColor DarkGray

    if ($compatWarnings.Count -gt 0) {
        Write-Host ''
        Write-Host 'COMPATIBILITY NOTES:' -ForegroundColor Yellow
        foreach ($warning in $compatWarnings) {
            Write-Host "  $($Icons.Warning) $warning" -ForegroundColor Yellow
        }
    }

    Write-Host ''
}
