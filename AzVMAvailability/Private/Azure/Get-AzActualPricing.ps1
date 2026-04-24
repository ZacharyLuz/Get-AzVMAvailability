function Get-AzActualPricing {
    <#
    .SYNOPSIS
        Retrieves negotiated VM pricing using a tiered API strategy.
    .DESCRIPTION
        Tier 1: Consumption Price Sheet API — returns negotiated unitPrice AND
        retail pretaxStandardRate for ALL meters (deployed or not). Works for
        EA and MCA billing types.

        Tier 2: Cost Management Query API — derives effective hourly rate from
        actual month-to-date usage (cost / hours). Works for ALL billing types
        but only covers currently-deployed SKUs.

        Returns a hashtable keyed by ARM SKU name (e.g. Standard_D2s_v3) with
        Hourly, Monthly, Currency, Meter, and IsNegotiated fields.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $true)]
        [string]$Region,

        [int]$MaxRetries = 3,

        [int]$HoursPerMonth = 730,

        [hashtable]$AzureEndpoints,

        [string]$TargetEnvironment = 'AzureCloud',

        [System.Collections.IDictionary]$Caches = @{}
    )

    if (-not $Caches.ActualPricing) {
        $Caches.ActualPricing = @{}
    }

    $armLocation = $Region.ToLower() -replace '\s', ''

    # Price Sheet meterLocation uses abbreviated names for gov/sovereign regions
    # that don't match ARM region names. This map provides fallback lookups.
    $armToMeterLocation = @{
        'usgovarizona'  = 'usgovaz'
        'usgovtexas'    = 'usgovtx'
        'usgovvirginia' = 'usgov'
        'usdodcentral'  = 'usdod'
        'usdodeast'     = 'usdod'
    }

    # ── Disk cache ──
    # EA/MCA negotiated rates are enrollment-level (tenant-scoped). Cache by
    # TenantId so all subscriptions in the same tenant share one cache file.
    # Uses shared filename prefix so both AzVMAvailability and AzVMLifecycle
    # modules share the same disk cache (identical data format).
    $PriceSheetCacheTTLDays = 30
    $tenantId = try { (Get-AzContext -ErrorAction SilentlyContinue).Tenant.Id } catch { $null }
    $cacheKey = if ($tenantId) { $tenantId } else { $SubscriptionId }
    $cacheDir = if ($env:TEMP) { $env:TEMP } else { [System.IO.Path]::GetTempPath() }
    $cacheFile = Join-Path $cacheDir "AzVMLifecycle-PriceSheet-$cacheKey.json"

    # EA/MCA negotiated rates are set at the enrollment level — identical across
    # all subscriptions. Page through the Price Sheet once, group all Linux VM
    # meters by meterLocation, and serve every subsequent region from cache.
    if ($Caches.ActualPricing.ContainsKey('AllRegions')) {
        $allRegionPrices = $Caches.ActualPricing['AllRegions']
        $lookupKey = if ($allRegionPrices.ContainsKey($armLocation)) { $armLocation }
                     elseif ($armToMeterLocation.ContainsKey($armLocation)) { $armToMeterLocation[$armLocation] }
                     else { $null }
        $regionPrices = if ($lookupKey) { $allRegionPrices[$lookupKey] } else { @{} }
        if ($regionPrices.Count -gt 0) {
            Write-Host "  Tier 1 (Price Sheet): $($regionPrices.Count) negotiated SKU prices for '$Region' (cached)" -ForegroundColor DarkGray
        }
        return $regionPrices
    }

    # Check disk cache before calling the API
    if (Test-Path $cacheFile) {
        try {
            $cacheAge = (Get-Date) - (Get-Item $cacheFile).LastWriteTime
            if ($cacheAge.TotalDays -le $PriceSheetCacheTTLDays) {
                $ageDays = [math]::Floor($cacheAge.TotalDays)
                $ageLabel = if ($ageDays -eq 0) { 'today' } elseif ($ageDays -eq 1) { '1 day old' } else { "$ageDays days old" }
                Write-Host "  Loading cached discounted pricing data ($ageLabel)..." -ForegroundColor DarkGray
                $allRegionPrices = Get-Content $cacheFile -Raw | ConvertFrom-Json -AsHashtable
                $Caches.ActualPricing['AllRegions'] = $allRegionPrices
                $totalSkus = ($allRegionPrices.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
                Write-Host "  Tier 1 (Price Sheet): $totalSkus negotiated SKU prices across $($allRegionPrices.Count) region(s) (from cache file)" -ForegroundColor DarkGray

                $lookupKey = if ($allRegionPrices.ContainsKey($armLocation)) { $armLocation }
                             elseif ($armToMeterLocation.ContainsKey($armLocation)) { $armToMeterLocation[$armLocation] }
                             else { $null }
                $regionPrices = if ($lookupKey) { $allRegionPrices[$lookupKey] } else { @{} }
                return $regionPrices
            }
            else {
                Write-Verbose "Price Sheet cache expired ($([math]::Floor($cacheAge.TotalDays)) days old, TTL=$PriceSheetCacheTTLDays days). Refreshing from API."
            }
        }
        catch {
            Write-Verbose "Price Sheet cache file unreadable, will refresh from API: $($_.Exception.Message)"
        }
    }

    if (-not $AzureEndpoints) {
        $AzureEndpoints = Get-AzureEndpoints -EnvironmentName $TargetEnvironment
    }
    $armUrl = $AzureEndpoints.ResourceManagerUrl

    $token = $null
    $headers = $null
    try {
        $token = (Get-AzAccessToken -ResourceUrl $armUrl -ErrorAction Stop).Token
        $headers = @{
            'Authorization' = "Bearer $token"
            'Content-Type'  = 'application/json'
        }
    }
    catch {
        if (-not $Caches.NegotiatedPricingWarned) {
            $Caches.NegotiatedPricingWarned = $true
            Write-Warning "Cost Management: cannot obtain access token. Run: Connect-AzAccount"
            Write-Warning "Falling back to retail pricing (public list prices without negotiated discounts)."
        }
        return $null
    }

    # ── Tier 1: Consumption Price Sheet API ──
    # Returns negotiated unitPrice for ALL meters (deployed or not).
    # pretaxStandardRate = retail listing price (for discount calculation).
    # Requires $expand=properties/meterDetails to populate category/region/meter fields.
    # Only works for EA/MCA billing; returns 404 for PAYG/Sponsorship/MSDN.
    #
    # We page through the entire Price Sheet ONCE and group all Linux VM meters
    # by their normalized meterLocation. No region filtering — we capture everything.
    $tier1Success = $false
    $allRegionPrices = @{}  # key = normalized location, value = hashtable of SKU → pricing
    $MaxPricesheetPages = 500
    $EstimatedPages = 500  # Based on observed EA price sheets (~484 pages typical)
    try {
        $psUrl = "$armUrl/subscriptions/$SubscriptionId/providers/Microsoft.Consumption/pricesheets/default?api-version=2023-05-01&`$expand=properties/meterDetails&`$top=1000"
        Write-Verbose "Tier 1 (Price Sheet): calling $psUrl"
        Write-Host "  Initial download of discounted pricing data (duration varies by connection speed, one-time)..." -ForegroundColor Cyan
        Write-Host "  Subsequent runs will use cached data (valid $PriceSheetCacheTTLDays days)." -ForegroundColor DarkGray

        $totalItems = 0
        $pageCount = 0
        $totalVmMeters = 0
        $unitMeasureCounts = @{}  # Track unitOfMeasure values for diagnostics
        $firstVmPage = 0         # Track page distribution of VM meters
        $lastVmPage = 0
        $vmMetersPerPage = @{}   # page number → VM meter count on that page
        $savedProgressPref = $ProgressPreference
        $ProgressPreference = 'Continue'  # Restore progress bar (suppressed globally for Invoke-RestMethod noise)
        $scanStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        do {
            $pageCount++
            $pctComplete = [math]::Min(99, [math]::Floor(($pageCount / $EstimatedPages) * 100))
            $elapsed = $scanStopwatch.Elapsed
            $elapsedStr = '{0:mm\:ss}' -f $elapsed
            if ($pageCount -gt 2) {
                $secsPerPage = $elapsed.TotalSeconds / ($pageCount - 1)
                $remainPages = [math]::Max(0, $EstimatedPages - $pageCount)
                $etaSecs = [math]::Ceiling($secsPerPage * $remainPages)
                $etaMin = [math]::Floor($etaSecs / 60)
                $etaSec = $etaSecs % 60
                $etaStr = if ($etaMin -gt 0) { "${etaMin}m ${etaSec}s remaining" } else { "${etaSec}s remaining" }
            }
            else {
                $etaStr = 'estimating...'
            }
            Write-Progress -Activity "Downloading discounted pricing data" -Status "Page $pageCount - $totalVmMeters VM SKUs found - $elapsedStr elapsed - $etaStr" -PercentComplete $pctComplete

            $psResponse = Invoke-WithRetry -MaxRetries $MaxRetries -OperationName "Consumption Price Sheet (page $pageCount)" -ScriptBlock {
                Invoke-RestMethod -Uri $psUrl -Method Get -Headers $headers -TimeoutSec 120
            }

            if ($psResponse.properties.pricesheets) {
                $totalItems += $psResponse.properties.pricesheets.Count
                $pageVmCount = 0
                foreach ($item in $psResponse.properties.pricesheets) {
                    $md = $item.meterDetails
                    if (-not $md) { continue }

                    if ($md.meterCategory -ne 'Virtual Machines') { continue }
                    if ($md.meterSubCategory -match 'Windows') { continue }

                    # Normalize meterLocation to ARM-style key (lowercase, no spaces/hyphens)
                    $meterLoc = $md.meterLocation
                    $normalizedRegion = ($meterLoc -replace '[\s-]', '').ToLower()
                    if (-not $normalizedRegion) { continue }

                    # Convert billing meter name to ARM SKU name
                    $cleanName = $md.meterName -replace '\s+(Low Priority|Spot)\s*$', ''
                    $cleanName = $cleanName.Trim() -replace '^Standard[\s_]+', ''
                    if ($cleanName -notmatch '^[A-Z]') { continue }
                    $vmSize = "Standard_$($cleanName -replace '\s+', '_')"

                    # Determine the hourly divisor from unitOfMeasure
                    # Common values: "1 Hour", "100 Hours", "1/Month", "1/Day"
                    $unitOfMeasure = if ($item.unitOfMeasure) { $item.unitOfMeasure }
                                     elseif ($md.unit) { $md.unit }
                                     else { '1 Hour' }
                    $unitKey = $unitOfMeasure.Trim()
                    if ($unitMeasureCounts.ContainsKey($unitKey)) { $unitMeasureCounts[$unitKey]++ } else { $unitMeasureCounts[$unitKey] = 1 }

                    $hourlyDivisor = switch -Regex ($unitKey) {
                        '^\d+\s+Hour'  { if ($unitKey -match '^(\d+)') { [double]$Matches[1] } else { 1 } }
                        'Month'        { $HoursPerMonth }
                        'Day'          { 24 }
                        default        { 1 }
                    }

                    # Initialize region bucket if needed
                    if (-not $allRegionPrices.ContainsKey($normalizedRegion)) {
                        $allRegionPrices[$normalizedRegion] = @{}
                    }

                    if (-not $allRegionPrices[$normalizedRegion].ContainsKey($vmSize)) {
                        $rawRate = [double]$item.unitPrice
                        $negotiatedRate = $rawRate / $hourlyDivisor
                        $retailRate = if ($md.pretaxStandardRate) { [double]$md.pretaxStandardRate / $hourlyDivisor } else { $null }

                        $allRegionPrices[$normalizedRegion][$vmSize] = @{
                            Hourly       = [math]::Round($negotiatedRate, 4)
                            Monthly      = [math]::Round($negotiatedRate * $HoursPerMonth, 2)
                            Currency     = $item.currencyCode
                            Meter        = $md.meterName
                            IsNegotiated = $true
                        }
                        if ($retailRate -and $retailRate -gt 0) {
                            $allRegionPrices[$normalizedRegion][$vmSize].RetailHourly = [math]::Round($retailRate, 4)
                            $allRegionPrices[$normalizedRegion][$vmSize].DiscountPct  = [math]::Round((1 - ($negotiatedRate / $retailRate)) * 100, 1)
                        }
                        $totalVmMeters++
                        $pageVmCount++
                    }
                }
                if ($pageVmCount -gt 0) {
                    $vmMetersPerPage[$pageCount] = $pageVmCount
                    if ($firstVmPage -eq 0) { $firstVmPage = $pageCount }
                    $lastVmPage = $pageCount
                }
            }

            $psUrl = $psResponse.properties.nextLink
        } while ($psUrl -and $pageCount -lt $MaxPricesheetPages)

        if ($totalVmMeters -gt 0) {
            $tier1Success = $true
            $scanStopwatch.Stop()
            Write-Progress -Activity "Downloading discounted pricing data" -Completed
            $ProgressPreference = $savedProgressPref
            $scanDuration = $scanStopwatch.Elapsed
            $scanDurationStr = '{0:mm\:ss}' -f $scanDuration
            # Cache the full scan — all subsequent calls for any region are served from here
            $Caches.ActualPricing['AllRegions'] = $allRegionPrices

            # Persist to disk so subsequent runs skip the API entirely
            try {
                $cacheJson = ConvertTo-Json -InputObject $allRegionPrices -Depth 4 -Compress
                $tmpFile = "$cacheFile.tmp"
                [System.IO.File]::WriteAllText($tmpFile, $cacheJson, [System.Text.Encoding]::UTF8)
                Move-Item -Path $tmpFile -Destination $cacheFile -Force
                $cacheSizeMB = [math]::Round((Get-Item $cacheFile).Length / 1MB, 1)
                Write-Host "  Pricing data cached to disk (${cacheSizeMB}MB, valid $PriceSheetCacheTTLDays days): $cacheFile" -ForegroundColor DarkGray
            }
            catch {
                Write-Warning "Could not write Price Sheet cache file: $($_.Exception.Message)"
                Write-Verbose "Cache path: $cacheFile"
            }

            $locationSummary = ($allRegionPrices.GetEnumerator() | Sort-Object { $_.Value.Count } -Descending | ForEach-Object { "'$($_.Key)' ($($_.Value.Count))" }) -join ', '
            Write-Host "  Tier 1 (Price Sheet): $totalVmMeters negotiated SKU prices across $($allRegionPrices.Count) region(s) in $scanDurationStr" -ForegroundColor DarkGray
            Write-Verbose "Tier 1 (Price Sheet): $totalItems items across $pageCount page(s), $totalVmMeters VM SKU prices."
            Write-Verbose "  Regions: $locationSummary"
            $unitSummary = ($unitMeasureCounts.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { "'$($_.Key)' ($($_.Value))" }) -join ', '
            Write-Verbose "  unitOfMeasure values: $unitSummary"
            $sampleDiscount = $null
            foreach ($rp in $allRegionPrices.Values) {
                $sampleDiscount = $rp.Values | Where-Object { $_.DiscountPct } | Select-Object -First 1
                if ($sampleDiscount) { break }
            }
            if ($sampleDiscount) {
                Write-Verbose "  Sample discount: $($sampleDiscount.DiscountPct)% off retail"
            }
            Write-Verbose "  VM meter page distribution: first=$firstVmPage, last=$lastVmPage of $pageCount pages"
            if ($vmMetersPerPage.Count -gt 0) {
                $pagesWithVMs = $vmMetersPerPage.Count
                $pagesWithoutVMs = $pageCount - $pagesWithVMs
                Write-Verbose "  Pages with VM meters: $pagesWithVMs/$pageCount ($pagesWithoutVMs empty pages)"
            }
        }
        else {
            Write-Progress -Activity "Downloading discounted pricing data" -Completed
            $ProgressPreference = $savedProgressPref
            $scanStopwatch.Stop()
            Write-Host "  Tier 1 (Price Sheet): no VM matches ($totalItems items across $pageCount pages). Trying Tier 2..." -ForegroundColor DarkGray
            Write-Verbose "Tier 1 (Price Sheet): $totalItems items across $pageCount page(s), 0 VM matches. Falling through to Tier 2."
        }
    }
    catch {
        Write-Progress -Activity "Downloading discounted pricing data" -Completed
        $ProgressPreference = $savedProgressPref
        $psError = $_
        $psStatus = $null
        if ($psError.Exception.Response) { $psStatus = [int]$psError.Exception.Response.StatusCode }
        if (-not $psStatus -and $psError.Exception.Message -match '(\d{3})') { $psStatus = [int]$Matches[1] }
        Write-Host "  Tier 1 (Price Sheet): failed$(if ($psStatus) { " (HTTP $psStatus)" }) — trying Tier 2..." -ForegroundColor DarkGray
        Write-Verbose "Tier 1 (Price Sheet) failed$(if ($psStatus) { " (HTTP $psStatus)" }): $($psError.Exception.Message). Falling through to Tier 2."
    }

    # ── Tier 2: Cost Management Query API ──
    # Derives effective rate from actual usage. Covers deployed SKUs only.
    # Works for all billing types (EA, MCA, CSP, PAYG).
    # Tier 2 is region-specific (filters by ResourceLocation) since Cost Management
    # doesn't support unfiltered queries efficiently.
    if (-not $tier1Success) {
        try {
            $queryBody = @{
                type      = 'ActualCost'
                timeframe = 'MonthToDate'
                dataset   = @{
                    granularity = 'None'
                    aggregation = @{
                        PreTaxCost    = @{ name = 'PreTaxCost';    function = 'Sum' }
                        UsageQuantity = @{ name = 'UsageQuantity'; function = 'Sum' }
                    }
                    filter = @{
                        dimensions = @{ name = 'MeterCategory'; operator = 'In'; values = @('Virtual Machines') }
                    }
                    grouping = @(
                        @{ type = 'Dimension'; name = 'MeterSubcategory' }
                        @{ type = 'Dimension'; name = 'Meter' }
                    )
                }
            } | ConvertTo-Json -Depth 10

            $queryUrl = "$armUrl/subscriptions/$SubscriptionId/providers/Microsoft.CostManagement/query?api-version=2023-11-01"

            $cmResponse = Invoke-WithRetry -MaxRetries $MaxRetries -OperationName 'Cost Management Query' -ScriptBlock {
                Invoke-RestMethod -Uri $queryUrl -Method Post -Headers $headers -Body $queryBody -ContentType 'application/json' -TimeoutSec 60
            }

            $colMap = @{}
            for ($i = 0; $i -lt $cmResponse.properties.columns.Count; $i++) {
                $colMap[$cmResponse.properties.columns[$i].name] = $i
            }

            $costIdx   = $colMap['PreTaxCost']
            $qtyIdx    = $colMap['UsageQuantity']
            $subCatIdx = $colMap['MeterSubcategory']
            $meterIdx  = $colMap['Meter']
            $currIdx   = if ($colMap.ContainsKey('Currency')) { $colMap['Currency'] } else { $null }

            $rowCount = if ($cmResponse.properties.rows) { $cmResponse.properties.rows.Count } else { 0 }

            foreach ($row in $cmResponse.properties.rows) {
                $cost        = [double]$row[$costIdx]
                $quantity    = [double]$row[$qtyIdx]
                $subCategory = $row[$subCatIdx]
                $meterName   = $row[$meterIdx]
                $currency    = if ($null -ne $currIdx) { $row[$currIdx] } else { 'USD' }

                if ($subCategory -match 'Windows') { continue }
                if ($quantity -le 0 -or $cost -le 0) { continue }

                $hourlyRate = $cost / $quantity

                $cleanName = $meterName -replace '\s+(Low Priority|Spot)\s*$', ''
                $cleanName = $cleanName.Trim() -replace '^Standard[\s_]+', ''
                if ($cleanName -match '^[A-Z]') {
                    $vmSize = "Standard_$($cleanName -replace '\s+', '_')"
                }
                else { continue }

                # Tier 2 doesn't provide location per row — store under the requested region
                if (-not $allRegionPrices.ContainsKey($armLocation)) {
                    $allRegionPrices[$armLocation] = @{}
                }
                if (-not $allRegionPrices[$armLocation].ContainsKey($vmSize)) {
                    $allRegionPrices[$armLocation][$vmSize] = @{
                        Hourly       = [math]::Round($hourlyRate, 4)
                        Monthly      = [math]::Round($hourlyRate * $HoursPerMonth, 2)
                        Currency     = $currency
                        Meter        = $meterName
                        IsNegotiated = $true
                    }
                }
            }

            $tier2Count = if ($allRegionPrices[$armLocation]) { $allRegionPrices[$armLocation].Count } else { 0 }
            Write-Host "  Tier 2 (Cost Query): $tier2Count SKU prices from $rowCount usage rows for '$Region'" -ForegroundColor DarkGray
            Write-Verbose "Tier 2 (Cost Query): $rowCount usage rows, $tier2Count VM SKU prices for region '$armLocation'."
        }
        catch {
            $errorMsg = $_.Exception.Message
            $statusCode = $null
            if ($_.Exception.Response) { $statusCode = [int]$_.Exception.Response.StatusCode }
            if (-not $statusCode -and $errorMsg -match '(\d{3})') { $statusCode = [int]$Matches[1] }

            if (-not $Caches.NegotiatedPricingWarned) {
                $Caches.NegotiatedPricingWarned = $true

                switch ($statusCode) {
                    401 {
                        Write-Warning "Cost Management: authentication failed (HTTP 401). Run: Connect-AzAccount"
                    }
                    403 {
                        Write-Warning "Cost Management: access denied (HTTP 403). Required RBAC (any one):"
                        Write-Warning "  - Cost Management Reader  (scope: subscription)"
                        Write-Warning "  - Reader                   (scope: subscription)"
                        Write-Warning "  To assign:  New-AzRoleAssignment -SignInName <user@domain> -RoleDefinitionName 'Cost Management Reader' -Scope /subscriptions/$SubscriptionId"
                    }
                    {$_ -in 429, 503} {
                        Write-Warning "Cost Management: throttled/unavailable (HTTP $statusCode). Retries exhausted."
                    }
                    default {
                        Write-Warning "Cost Management failed$(if ($statusCode) { " (HTTP $statusCode)" }): $errorMsg"
                    }
                }
                Write-Warning "Falling back to retail pricing (public list prices without negotiated discounts)."
            }

            $headers['Authorization'] = $null
            $token = $null
            return $null
        }
    }

    $headers['Authorization'] = $null
    $token = $null

    $lookupKey = if ($allRegionPrices.ContainsKey($armLocation)) { $armLocation }
                 elseif ($armToMeterLocation.ContainsKey($armLocation)) { $armToMeterLocation[$armLocation] }
                 else { $null }
    $regionPrices = if ($lookupKey) { $allRegionPrices[$lookupKey] } else { @{} }
    return $regionPrices
}
