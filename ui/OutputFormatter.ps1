# OutputFormatter.ps1
# Reference copy extracted from Get-AzVMAvailability.ps1 (lines 3062-3700)
# Contains: main scan results rendering loop, table headers, color-coded status display,
#           zone/restriction/pricing columns, and status key/legend output.
# DO NOT execute this file directly — it is a documentation reference only.
# The authoritative source is Get-AzVMAvailability.ps1.
                            else {
                                # Publisher selected - show offers
                                $offers = Get-AzVMImageOffer -Location $Regions[0] -PublisherName $selected.Publisher -ErrorAction SilentlyContinue |
                                Select-Object -First 10

                                if ($offers) {
                                    Write-Host ""
                                    Write-Host "Offers from $($selected.Publisher):" -ForegroundColor Cyan
                                    for ($i = 0; $i -lt $offers.Count; $i++) {
                                        Write-Host "  $($i + 1). $($offers[$i].Offer)" -ForegroundColor White
                                    }
                                    Write-Host ""
                                    Write-Host "Select offer (1-$($offers.Count)) or Enter to skip: " -ForegroundColor Yellow -NoNewline
                                    $offerSelect = Read-Host

                                    if ($offerSelect -match '^\d+$' -and [int]$offerSelect -le $offers.Count) {
                                        $selectedOffer = $offers[[int]$offerSelect - 1]
                                        $skus = Get-AzVMImageSku -Location $Regions[0] -PublisherName $selected.Publisher -Offer $selectedOffer.Offer -ErrorAction SilentlyContinue |
                                        Select-Object -First 15

                                        if ($skus) {
                                            Write-Host ""
                                            Write-Host "SKUs for $($selectedOffer.Offer):" -ForegroundColor Cyan
                                            for ($i = 0; $i -lt $skus.Count; $i++) {
                                                Write-Host "  $($i + 1). $($skus[$i].Skus)" -ForegroundColor White
                                            }
                                            Write-Host ""
                                            Write-Host "Select SKU (1-$($skus.Count)) or Enter to skip: " -ForegroundColor Yellow -NoNewline
                                            $skuSelect = Read-Host

                                            if ($skuSelect -match '^\d+$' -and [int]$skuSelect -le $skus.Count) {
                                                $selectedSku = $skus[[int]$skuSelect - 1]
                                                $ImageURN = "$($selected.Publisher):$($selectedOffer.Offer):$($selectedSku.Skus):latest"
                                                Write-Host "Selected: $ImageURN" -ForegroundColor Green
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    else {
                        Write-Host "No results found matching '$searchTerm'" -ForegroundColor DarkYellow
                        Write-Host "Try: 'ubuntu', 'windows', 'rhel', 'dsvm', 'mariner', 'debian', 'suse'" -ForegroundColor DarkGray
                    }
                }
                catch {
                    Write-Host "Search failed: $_" -ForegroundColor Red
                }

                if (-not $ImageURN) {
                    Write-Host "No image selected - skipping compatibility check" -ForegroundColor DarkGray
                }
            }
        }
        else {
            # Assume they entered a URN directly or pressed Enter to skip
            if (-not [string]::IsNullOrWhiteSpace($imageSelection)) {
                $ImageURN = $imageSelection
                Write-Host "Using: $ImageURN" -ForegroundColor Green
            }
        }
    }
}

# Parse image requirements if an image was specified
$script:RunContext.ImageReqs = $null
if ($ImageURN) {
    $script:RunContext.ImageReqs = Get-ImageRequirements -ImageURN $ImageURN
    if (-not $script:RunContext.ImageReqs.Valid) {
        Write-Host "Warning: Could not parse image URN - $($script:RunContext.ImageReqs.Error)" -ForegroundColor DarkYellow
        $script:RunContext.ImageReqs = $null
    }
}

if ($ExportPath -and -not (Test-Path $ExportPath)) {
    New-Item -Path $ExportPath -ItemType Directory -Force | Out-Null
    Write-Host "Created: $ExportPath" -ForegroundColor Green
}

#endregion Interactive Prompts
#region Data Collection

# Calculate consistent output width based on table columns
# Base columns: Family(12) + SKUs(6) + OK(5) + Largest(18) + Zones(28) + Status(22) + Quota(10) = 101
# Plus spacing and CPU/Disk columns = 122 base
# With pricing: +18 (two price columns) = 140
$script:OutputWidth = if ($FetchPricing) { $OutputWidthWithPricing } else { $OutputWidthBase }
if ($CompactOutput) {
    $script:OutputWidth = $OutputWidthMin
}
$script:OutputWidth = [Math]::Max($script:OutputWidth, $OutputWidthMin)
$script:OutputWidth = [Math]::Min($script:OutputWidth, $OutputWidthMax)
$script:RunContext.OutputWidth = $script:OutputWidth

Write-Host "`n" -NoNewline
Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
Write-Host "GET-AZVMAVAILABILITY v$ScriptVersion" -ForegroundColor Green
Write-Host "Personal project — not an official Microsoft product. Provided AS IS." -ForegroundColor DarkGray
Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
Write-Host "Subscriptions: $($TargetSubIds.Count) | Regions: $($Regions -join ', ')" -ForegroundColor Cyan
if ($SkuFilter -and $SkuFilter.Count -gt 0) {
    Write-Host "SKU Filter: $($SkuFilter -join ', ')" -ForegroundColor Yellow
}
Write-Host "Icons: $(if ($supportsUnicode) { 'Unicode' } else { 'ASCII' }) | Pricing: $(if ($FetchPricing) { 'Enabled' } else { 'Disabled' })" -ForegroundColor DarkGray
if ($script:RunContext.ImageReqs) {
    Write-Host "Image: $ImageURN" -ForegroundColor Cyan
    Write-Host "Requirements: $($script:RunContext.ImageReqs.Gen) | $($script:RunContext.ImageReqs.Arch)" -ForegroundColor DarkCyan
}
Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
Write-Host ""

# Fetch pricing data if enabled
$script:RunContext.RegionPricing = @{}
$script:RunContext.UsingActualPricing = $false

if ($FetchPricing) {
    # Auto-detect: Try negotiated pricing first, fall back to retail
    Write-Host "Checking for negotiated pricing (EA/MCA/CSP)..." -ForegroundColor DarkGray

    $actualPricingSuccess = $true
    foreach ($regionCode in $Regions) {
        $actualPrices = Get-AzActualPricing -SubscriptionId $TargetSubIds[0] -Region $regionCode -MaxRetries $MaxRetries -HoursPerMonth $HoursPerMonth -AzureEndpoints $script:AzureEndpoints -TargetEnvironment $script:TargetEnvironment -Caches $script:RunContext.Caches
        if ($actualPrices -and $actualPrices.Count -gt 0) {
            if ($actualPrices -is [array]) { $actualPrices = $actualPrices[0] }
            $script:RunContext.RegionPricing[$regionCode] = $actualPrices
        }
        else {
            $actualPricingSuccess = $false
            break
        }
    }

    if ($actualPricingSuccess -and $script:RunContext.RegionPricing.Count -gt 0) {
        $script:RunContext.UsingActualPricing = $true
        Write-Host "$($Icons.Check) Using negotiated pricing (EA/MCA/CSP rates detected)" -ForegroundColor Green
    }
    else {
        # Fall back to retail pricing
        Write-Host "No negotiated rates found, using retail pricing..." -ForegroundColor DarkGray
        $script:RunContext.RegionPricing = @{}
        foreach ($regionCode in $Regions) {
            $pricingResult = Get-AzVMPricing -Region $regionCode -MaxRetries $MaxRetries -HoursPerMonth $HoursPerMonth -AzureEndpoints $script:AzureEndpoints -TargetEnvironment $script:TargetEnvironment -Caches $script:RunContext.Caches
            if ($pricingResult -is [array]) { $pricingResult = $pricingResult[0] }
            $script:RunContext.RegionPricing[$regionCode] = $pricingResult
        }
        Write-Host "$($Icons.Check) Using retail pricing (Linux pay-as-you-go)" -ForegroundColor DarkGray
    }
}

$allSubscriptionData = @()

$initialAzContext = Get-AzContext -ErrorAction SilentlyContinue
$initialSubscriptionId = if ($initialAzContext -and $initialAzContext.Subscription) { [string]$initialAzContext.Subscription.Id } else { $null }

# Outer try/finally ensures Az context is restored even if Ctrl+C or PipelineStoppedException
# interrupts parallel scanning, results processing, or export
try {
    try {
        foreach ($subId in $TargetSubIds) {
        $scanStartTime = Get-Date
        try {
            Use-SubscriptionContextSafely -SubscriptionId $subId | Out-Null
        }
        catch {
            Write-Warning "Failed to switch Azure context to subscription '$subId': $($_.Exception.Message)"
            continue
        }

        $subName = (Get-AzSubscription -SubscriptionId $subId | Select-Object -First 1).Name
        Write-Host "[$subName] Scanning $($Regions.Count) region(s)..." -ForegroundColor Yellow

        # Progress indicator for parallel scanning
        $regionCount = $Regions.Count
        Write-Progress -Activity "Scanning Azure Regions" -Status "Querying $regionCount region(s) in parallel..." -PercentComplete 0

        $scanRegionScript = {
            param($region, $skuFilterCopy, $maxRetries)

            # Inline retry — parallel runspaces cannot see script-scope functions
            $retryCall = {
                param([scriptblock]$Action, [int]$Retries)
                $attempt = 0
                while ($true) {
                    try {
                        return (& $Action)
                    }
                    catch {
                        $attempt++
                        $msg = $_.Exception.Message
                        $isThrottle = $msg -match '429' -or $msg -match 'Too Many Requests' -or
                        $msg -match '503' -or $msg -match 'ServiceUnavailable'
                        if ($isThrottle -and $attempt -le $Retries) {
                            $baseDelay = [math]::Pow(2, $attempt)
                            $jitter = $baseDelay * (Get-Random -Minimum 0.0 -Maximum 0.25)
                            Start-Sleep -Milliseconds (($baseDelay + $jitter) * 1000)
                            continue
                        }
                        throw
                    }
                }
            }

            try {
                $allSkus = & $retryCall -Action {
                    Get-AzComputeResourceSku -Location $region -ErrorAction Stop |
                    Where-Object { $_.ResourceType -eq 'virtualMachines' }
                } -Retries $maxRetries

                # Apply SKU filter if specified
                if ($skuFilterCopy -and $skuFilterCopy.Count -gt 0) {
                    $allSkus = $allSkus | Where-Object {
                        $skuName = $_.Name
                        $isMatch = $false
                        foreach ($pattern in $skuFilterCopy) {
                            $regexPattern = '^' + [regex]::Escape($pattern).Replace('\*', '.*').Replace('\?', '.') + '$'
                            if ($skuName -match $regexPattern) {
                                $isMatch = $true
                                break
                            }
                        }
                        $isMatch
                    }
                }

                $quotas = & $retryCall -Action {
                    Get-AzVMUsage -Location $region -ErrorAction Stop
                } -Retries $maxRetries

                @{ Region = [string]$region; Skus = $allSkus; Quotas = $quotas; Error = $null }
            }
            catch {
                @{ Region = [string]$region; Skus = @(); Quotas = @(); Error = $_.Exception.Message }
            }
        }

        $canUseParallel = $PSVersionTable.PSVersion.Major -ge 7
        if ($canUseParallel) {
            try {
                $regionData = $Regions | ForEach-Object -Parallel {
                    $region = [string]$_
                    $skuFilterCopy = $using:SkuFilter
                    $maxRetries = $using:MaxRetries

                    # Inline retry — parallel runspaces cannot see script-scope functions or external scriptblocks
                    $retryCall = {
                        param([scriptblock]$Action, [int]$Retries)
                        $attempt = 0
                        while ($true) {
                            try {
                                return (& $Action)
                            }
                            catch {
                                $attempt++
                                $msg = $_.Exception.Message
                                $isThrottle = $msg -match '429' -or $msg -match 'Too Many Requests' -or
                                $msg -match '503' -or $msg -match 'ServiceUnavailable' -or $msg -match 'Service Unavailable'
                                if ($isThrottle -and $attempt -le $Retries) {
                                    $baseDelay = [math]::Pow(2, $attempt)
                                    $jitter = $baseDelay * (Get-Random -Minimum 0.0 -Maximum 0.25)
                                    Start-Sleep -Milliseconds (($baseDelay + $jitter) * 1000)
                                    continue
                                }
                                throw
                            }
                        }
                    }

                    try {
                        $allSkus = & $retryCall -Action {
                            Get-AzComputeResourceSku -Location $region -ErrorAction Stop |
                            Where-Object { $_.ResourceType -eq 'virtualMachines' }
                        } -Retries $maxRetries

                        if ($skuFilterCopy -and $skuFilterCopy.Count -gt 0) {
                            $allSkus = $allSkus | Where-Object {
                                $skuName = $_.Name
                                $isMatch = $false
                                foreach ($pattern in $skuFilterCopy) {
                                    $regexPattern = '^' + [regex]::Escape($pattern).Replace('\*', '.*').Replace('\?', '.') + '$'
                                    if ($skuName -match $regexPattern) {
                                        $isMatch = $true
                                        break
                                    }
                                }
                                $isMatch
                            }
                        }

                        $quotas = & $retryCall -Action {
                            Get-AzVMUsage -Location $region -ErrorAction Stop
                        } -Retries $maxRetries

                        @{ Region = [string]$region; Skus = $allSkus; Quotas = $quotas; Error = $null }
                    }
                    catch {
                        @{ Region = [string]$region; Skus = @(); Quotas = @(); Error = $_.Exception.Message }
                    }
                } -ThrottleLimit $ParallelThrottleLimit
            }
            catch {
                Write-Warning "Parallel region scan failed: $($_.Exception.Message)"
                Write-Warning "Falling back to sequential scan mode for compatibility."
                $canUseParallel = $false
            }
        }

        if (-not $canUseParallel) {
            $regionData = foreach ($region in $Regions) {
                & $scanRegionScript -region ([string]$region) -skuFilterCopy $SkuFilter -maxRetries $MaxRetries
            }
        }

        Write-Progress -Activity "Scanning Azure Regions" -Completed

        $scanElapsed = (Get-Date) - $scanStartTime
        Write-Host "[$subName] Scan complete in $([math]::Round($scanElapsed.TotalSeconds, 1))s" -ForegroundColor Green

        $allSubscriptionData += @{
            SubscriptionId   = $subId
            SubscriptionName = $subName
            RegionData       = $regionData
        }
    }
}
catch {
    Write-Verbose "Scan loop interrupted: $($_.Exception.Message)"
    throw
}

#endregion Data Collection
#region Fleet Readiness

if ($Fleet -and $Fleet.Count -gt 0) {
    $fleetResult = Get-FleetReadiness -Fleet $Fleet -SubscriptionData $allSubscriptionData
    Write-FleetReadinessSummary -FleetResult $fleetResult -Fleet $Fleet

    if ($JsonOutput) {
        $fleetResult | ConvertTo-Json -Depth 5
    }

    # Fleet mode exits after summary — no need to render full scan output
    return
}

#endregion Fleet Readiness
#region Recommend Mode

if ($Recommend) {
    Invoke-RecommendMode -TargetSkuName $Recommend -SubscriptionData $allSubscriptionData `
        -FamilyInfo $FamilyInfo -Icons $Icons -FetchPricing ([bool]$FetchPricing) `
        -ShowSpot $ShowSpot.IsPresent -ShowPlacement $ShowPlacement.IsPresent `
        -AllowMixedArch $AllowMixedArch.IsPresent -MinvCPU $MinvCPU -MinMemoryGB $MinMemoryGB `
        -MinScore $MinScore -TopN $TopN -DesiredCount $DesiredCount `
        -JsonOutput $JsonOutput.IsPresent -MaxRetries $MaxRetries `
        -RunContext $script:RunContext -OutputWidth $script:OutputWidth
    return
}

#endregion Recommend Mode
#region Process Results

$allFamilyStats = @{}
$familyDetails = [System.Collections.Generic.List[PSCustomObject]]::new()
$familySkuIndex = @{}
$processStartTime = Get-Date

foreach ($subscriptionData in $allSubscriptionData) {
    $subName = $subscriptionData.SubscriptionName
    $totalRegions = $subscriptionData.RegionData.Count
    $currentRegion = 0

    foreach ($data in $subscriptionData.RegionData) {
        $currentRegion++
        $region = Get-SafeString $data.Region

        # Progress bar for processing
        $percentComplete = [math]::Round(($currentRegion / $totalRegions) * 100)
        $elapsed = (Get-Date) - $processStartTime
        Write-Progress -Activity "Processing Region Data" -Status "$region ($currentRegion of $totalRegions)" -PercentComplete $percentComplete -CurrentOperation "Elapsed: $([math]::Round($elapsed.TotalSeconds, 1))s"

        Write-Host "`n" -NoNewline
        Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
        Write-Host "REGION: $region" -ForegroundColor Yellow
        Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray

        if ($data.Error) {
            Write-Host "ERROR: $($data.Error)" -ForegroundColor Red
            continue
        }

        $familyGroups = @{}
        $quotaLookup = @{}
        foreach ($q in $data.Quotas) { $quotaLookup[$q.Name.Value] = $q }
        foreach ($sku in $data.Skus) {
            $family = Get-SkuFamily $sku.Name
            if (-not $familyGroups[$family]) { $familyGroups[$family] = @() }
            $familyGroups[$family] += $sku
        }

        Write-Host "`nQUOTA SUMMARY:" -ForegroundColor Cyan
        $quotaLines = $data.Quotas | Where-Object {
            $_.Name.Value -match 'Total Regional vCPUs|Family vCPUs'
        } | Select-Object @{n = 'Family'; e = { $_.Name.LocalizedValue } },
        @{n = 'Used'; e = { $_.CurrentValue } },
        @{n = 'Limit'; e = { $_.Limit } },
        @{n = 'Available'; e = { $_.Limit - $_.CurrentValue } }

        if ($quotaLines) {
            # Fixed-width quota table (175 chars total)
            $qColWidths = [ordered]@{ Family = 50; Used = 15; Limit = 15; Available = 15 }
            $qHeader = foreach ($c in $qColWidths.Keys) { $c.PadRight($qColWidths[$c]) }
            Write-Host ($qHeader -join '  ') -ForegroundColor Cyan
            Write-Host ('-' * $script:OutputWidth) -ForegroundColor Gray
            foreach ($q in $quotaLines) {
                $qRow = foreach ($c in $qColWidths.Keys) {
                    $v = "$($q.$c)"
                    if ($v.Length -gt $qColWidths[$c]) { $v = $v.Substring(0, $qColWidths[$c] - 1) + '…' }
                    $v.PadRight($qColWidths[$c])
                }
                Write-Host ($qRow -join '  ') -ForegroundColor White
            }
            Write-Host ""
        }
        else {
            Write-Host "No quota data available" -ForegroundColor DarkYellow
        }

        Write-Host "SKU FAMILIES:" -ForegroundColor Cyan

        $rows = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($family in ($familyGroups.Keys | Sort-Object)) {
            $skus = $familyGroups[$family]

            $largestSku = $skus | ForEach-Object {
                @{
                    Sku    = $_
                    vCPU   = [int](Get-CapValue $_ 'vCPUs')
                    Memory = [int](Get-CapValue $_ 'MemoryGB')
                }
            } | Sort-Object vCPU -Descending | Select-Object -First 1

            $availableCount = ($skus | Where-Object { -not (Get-RestrictionReason $_) }).Count
            $restrictions = Get-RestrictionDetails $largestSku.Sku
            $capacity = $restrictions.Status
            $zoneStatus = Format-ZoneStatus $restrictions.ZonesOK $restrictions.ZonesLimited $restrictions.ZonesRestricted
            $quotaInfo = Get-QuotaAvailable -QuotaLookup $quotaLookup -SkuFamily $largestSku.Sku.Family

            # Get pricing - find smallest SKU with pricing available
            $priceHrStr = '-'
            $priceMoStr = '-'
            # Get pricing data - handle potential array wrapping
            $regionPricingData = $script:RunContext.RegionPricing[$region]
            $regularPriceMap = Get-RegularPricingMap -PricingContainer $regionPricingData
            if ($FetchPricing -and $regularPriceMap -and $regularPriceMap.Count -gt 0) {
                $sortedSkus = $skus | ForEach-Object {
                    @{ Sku = $_; vCPU = [int](Get-CapValue $_ 'vCPUs') }
                } | Sort-Object vCPU

                foreach ($skuInfo in $sortedSkus) {
                    $skuName = $skuInfo.Sku.Name
                    $pricing = $regularPriceMap[$skuName]
                    if ($pricing) {
                        $priceHrStr = '$' + $pricing.Hourly.ToString('0.00')
                        $priceMoStr = '$' + $pricing.Monthly.ToString('0')
                        break
                    }
                }
            }

            $row = [pscustomobject]@{
                Family  = $family
                SKUs    = $skus.Count
                OK      = $availableCount
                Largest = "{0}vCPU/{1}GB" -f $largestSku.vCPU, $largestSku.Memory
                Zones   = $zoneStatus
                Status  = $capacity
                Quota   = if ($null -ne $quotaInfo.Available) { $quotaInfo.Available } else { '?' }
            }

            if ($FetchPricing) {
                $row | Add-Member -NotePropertyName '$/Hr' -NotePropertyValue $priceHrStr
                $row | Add-Member -NotePropertyName '$/Mo' -NotePropertyValue $priceMoStr
            }

            $rows.Add($row)

            # Track for drill-down
            if (-not $familySkuIndex.ContainsKey($family)) { $familySkuIndex[$family] = @{} }

            foreach ($sku in $skus) {
                $familySkuIndex[$family][$sku.Name] = $true
                $skuRestrictions = Get-RestrictionDetails $sku

                # Per-SKU quota: use SKU's exact .Family property for specific quota bucket
                $quotaInfo = Get-QuotaAvailable -QuotaLookup $quotaLookup -SkuFamily $sku.Family

                # Get individual SKU pricing
                $skuPriceHr = '-'
                $skuPriceMo = '-'
                if ($FetchPricing -and $regularPriceMap) {
                    $skuPricing = $regularPriceMap[$sku.Name]
                    if ($skuPricing) {
                        $skuPriceHr = '$' + $skuPricing.Hourly.ToString('0.00')
                        $skuPriceMo = '$' + $skuPricing.Monthly.ToString('0')
                    }
                }

                # Get SKU capabilities for Gen/Arch
                $skuCaps = Get-SkuCapabilities -Sku $sku
                $genDisplay = $skuCaps.HyperVGenerations -replace 'V', '' -replace ',', ','
                $archDisplay = $skuCaps.CpuArchitecture

                # Check image compatibility if image was specified
                $imgCompat = '–'
                $imgReason = ''
                if ($script:RunContext.ImageReqs) {
                    $compatResult = Test-ImageSkuCompatibility -ImageReqs $script:RunContext.ImageReqs -SkuCapabilities $skuCaps
                    if ($compatResult.Compatible) {
                        $imgCompat = if ($supportsUnicode) { '✓' } else { '[+]' }
                    }
                    else {
                        $imgCompat = if ($supportsUnicode) { '✗' } else { '[-]' }
                        $imgReason = $compatResult.Reason
                    }
                }

                $detailObj = [pscustomobject]@{
                    Subscription = [string]$subName
                    Region       = Get-SafeString $region
                    Family       = [string]$family
                    SKU          = [string]$sku.Name
                    vCPU         = Get-CapValue $sku 'vCPUs'
                    MemGiB       = Get-CapValue $sku 'MemoryGB'
                    Gen          = $genDisplay
                    Arch         = $archDisplay
                    ZoneStatus   = Format-ZoneStatus $skuRestrictions.ZonesOK $skuRestrictions.ZonesLimited $skuRestrictions.ZonesRestricted
                    Capacity     = [string]$skuRestrictions.Status
                    Reason       = ($skuRestrictions.RestrictionReasons -join ', ')
                    QuotaAvail   = if ($null -ne $quotaInfo.Available) { $quotaInfo.Available } else { '?' }
                    QuotaLimit   = if ($null -ne $quotaInfo.Limit) { $quotaInfo.Limit } else { $null }
                    QuotaCurrent = if ($null -ne $quotaInfo.Current) { $quotaInfo.Current } else { $null }
                    ImgCompat    = $imgCompat
                    ImgReason    = $imgReason
                    Alloc        = '-'
                }

                if ($FetchPricing) {
                    $detailObj | Add-Member -NotePropertyName '$/Hr' -NotePropertyValue $skuPriceHr
                    $detailObj | Add-Member -NotePropertyName '$/Mo' -NotePropertyValue $skuPriceMo
                }

                $familyDetails.Add($detailObj)
            }

            # Track for summary
            if (-not $allFamilyStats[$family]) {
                $allFamilyStats[$family] = @{ Regions = @{}; TotalAvailable = 0 }
            }
            $regionKey = Get-SafeString $region
            $allFamilyStats[$family].Regions[$regionKey] = @{
                Count     = $skus.Count
                Available = $availableCount
                Capacity  = $capacity
            }
        }

        if ($rows.Count -gt 0) {
            # Fixed-width table formatting (total width = 175 chars with pricing)
            $colWidths = [ordered]@{
                Family  = 12
                SKUs    = 6
                OK      = 5
                Largest = 18
                Zones   = 28
                Status  = 22
                Quota   = 10
            }
            if ($FetchPricing) {
                $colWidths['$/Hr'] = 10
                $colWidths['$/Mo'] = 10
            }

            $headerParts = foreach ($col in $colWidths.Keys) {
                $col.PadRight($colWidths[$col])
            }
            Write-Host ($headerParts -join '  ') -ForegroundColor Cyan
            Write-Host ('-' * $script:OutputWidth) -ForegroundColor Gray

            foreach ($row in $rows) {
                $rowParts = foreach ($col in $colWidths.Keys) {
                    $val = if ($null -ne $row.$col) { "$($row.$col)" } else { '' }
                    $width = $colWidths[$col]
                    if ($val.Length -gt $width) { $val = $val.Substring(0, $width - 1) + '…' }
                    $val.PadRight($width)
                }

                $color = switch ($row.Status) {
                    'OK' { 'Green' }
                    { $_ -match 'LIMITED|CAPACITY' } { 'Yellow' }
                    { $_ -match 'RESTRICTED|BLOCKED' } { 'Red' }
                    default { 'White' }
                }
                Write-Host ($rowParts -join '  ') -ForegroundColor $color
            }
        }
    }
}

# Optional placement enrichment for filtered scan mode (SKU-level tables only)
if ($ShowPlacement -and $SkuFilter -and $SkuFilter.Count -gt 0) {
    $filteredSkuNames = @($familyDetails | Select-Object -ExpandProperty SKU -Unique)
    if ($filteredSkuNames.Count -gt 5) {
        Write-Warning "Placement score lookup skipped in scan mode: filtered set contains $($filteredSkuNames.Count) SKUs (limit is 5). Refine -SkuFilter to 5 or fewer SKUs."
    }
    elseif ($filteredSkuNames.Count -gt 0) {
        $scanPlacementScores = Get-PlacementScores -SkuNames $filteredSkuNames -Regions $Regions -DesiredCount $DesiredCount -MaxRetries $MaxRetries -Caches $script:RunContext.Caches
        foreach ($detail in $familyDetails) {
            $allocKey = "{0}|{1}" -f $detail.SKU, $detail.Region.ToLower()
            $allocValue = if ($scanPlacementScores.ContainsKey($allocKey)) { [string]$scanPlacementScores[$allocKey].Score } else { 'N/A' }
            $detail.Alloc = $allocValue
        }
    }
}

#endregion Process Results

$script:RunContext.ScanOutput = New-ScanOutputContract -SubscriptionData $allSubscriptionData -FamilyStats $allFamilyStats -FamilyDetails $familyDetails -Regions $Regions -SubscriptionIds $TargetSubIds

if ($JsonOutput) {
    $script:RunContext.ScanOutput | ConvertTo-Json -Depth 8
    return
}

#region Drill-Down (if enabled)

if ($EnableDrill -and $familySkuIndex.Keys.Count -gt 0) {
    $familyList = @($familySkuIndex.Keys | Sort-Object)

