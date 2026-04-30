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

    # Price Sheet meterLocation values use a different naming convention than ARM:
    #   ARM is '<locality><geo>' or '<geoword><locality>' (westus, centralindia, japaneast)
    #   Cache key is '<geoshort><locality>' (uswest, incentral, jaeast)
    # Each ARM key maps to an *ordered list* of candidate meterLocation keys (after
    # normalization: lowercased, spaces/hyphens stripped). First candidate present
    # in the cache wins. Order: most-specific name first, then legacy fallbacks.
    #
    # Examples (normalized form):
    #   ARM 'westus'             -> meterLocation 'US West'      -> 'uswest'
    #   ARM 'eastus2'            -> meterLocation 'US East 2'    -> 'useast2'
    #   ARM 'westeurope'         -> meterLocation 'EU West'      -> 'euwest'
    #   ARM 'southeastasia'      -> meterLocation 'AP Southeast' -> 'apsoutheast'
    #   ARM 'germanywestcentral' -> meterLocation 'DE West Central' -> 'dewestcentral'
    #   ARM 'japaneast'          -> meterLocation 'JA East'      -> 'jaeast' (note: 'ja', not 'jp')
    #   ARM 'usgovvirginia'      -> meterLocation 'US Gov Virginia' / 'US Gov VA' / 'US Gov'
    $armToMeterLocation = @{
        # ── US commercial ──
        'westus'              = @('uswest')
        'westus2'             = @('uswest2')
        'westus3'             = @('uswest3')
        'eastus'              = @('useast')
        'eastus2'             = @('useast2')
        'eastus3'             = @('useast3')
        'centralus'           = @('uscentral')
        'northcentralus'      = @('usnorthcentral')
        'southcentralus'      = @('ussouthcentral')
        'southcentralus2'     = @('ussouthcentral2')
        'westcentralus'       = @('uswestcentral')
        'southeastus'         = @('ussoutheast')
        'southeastus3'        = @('ussoutheast3')
        'southeastus5'        = @('ussoutheast5')
        'southwestus'         = @('ussouthwest')
        # ── Europe ──
        'westeurope'          = @('euwest')
        'northeurope'         = @('eunorth')
        'uksouth'             = @('uksouth')
        'uksouth2'            = @('uksouth2')
        'ukwest'              = @('ukwest')
        'francecentral'       = @('frcentral')
        'francesouth'         = @('frsouth')
        'germanywestcentral'  = @('dewestcentral')
        'germanynorth'        = @('denorth')
        'swedencentral'       = @('secentral')
        'swedensouth'         = @('sesouth')
        'norwayeast'          = @('noeast')
        'norwaywest'          = @('nowest')
        'switzerlandnorth'    = @('chnorth')
        'switzerlandwest'     = @('chwest')
        'italynorth'          = @('itnorth')
        'spaincentral'        = @('escentral')
        'polandcentral'       = @('plcentral')
        'israelcentral'       = @('ilcentral')
        'israelnorthwest'     = @('ilnorthwest')
        'denmarkeast'         = @('dkeast')
        'austriaeast'         = @('ateast')
        'belgiumcentral'      = @('becentral')
        # ── Asia Pacific ──
        'southeastasia'       = @('apsoutheast')
        'eastasia'            = @('apeast')
        'japaneast'           = @('jaeast')   # NOT 'jp' — EA price sheet uses 'ja'
        'japanwest'           = @('jawest')
        'koreacentral'        = @('krcentral')
        'koreasouth'          = @('krsouth')
        'centralindia'        = @('incentral')
        'southindia'          = @('insouth')
        'westindia'           = @('inwest')
        'southcentralindia'   = @('insouthcentral')
        'australiaeast'       = @('aueast')
        'australiasoutheast'  = @('ausoutheast')
        'australiacentral'    = @('aucentral')
        'australiacentral2'   = @('aucentral2')
        'newzealandnorth'     = @('nznorth')
        'malaysiawest'        = @('mywest')
        'indonesiacentral'    = @('idcentral')
        'taiwannorth'         = @('twnorth')
        'taiwannorthwest'     = @('twnorthwest')
        # ── Americas (non-US) ──
        'canadacentral'       = @('cacentral')
        'canadaeast'          = @('caeast')
        'brazilsouth'         = @('brsouth')
        'brazilsoutheast'     = @('brsoutheast')
        'chilecentral'        = @('clcentral')
        'mexicocentral'       = @('mxcentral')
        # ── Middle East / Africa ──
        'uaecentral'          = @('aecentral')
        'uaenorth'            = @('aenorth')
        'qatarcentral'        = @('qacentral')
        'southafricanorth'    = @('zanorth')
        'southafricawest'     = @('zawest')
        # ── US sovereign (Gov / DoD) ──
        'usgovarizona'        = @('usgovarizona', 'usgovaz')
        'usgovtexas'          = @('usgovtexas', 'usgovtx')
        'usgovvirginia'       = @('usgovvirginia', 'usgovva', 'usgov')
        'usdodcentral'        = @('usdodcentral', 'usdodc', 'usdod')
        'usdodeast'           = @('usdodeast', 'usdode', 'usdod')
    }

    # Generic fallback: derive likely cache keys from an ARM region by swapping
    # locality and geo tokens. Catches future regions added before the explicit
    # table is updated. Tries every (locality, geoLong, geoShort) combo.
    $geoLongToShort = @{
        'us' = 'us'; 'europe' = 'eu'; 'asia' = 'ap'; 'uk' = 'uk'
        'australia' = 'au'; 'japan' = 'ja'; 'korea' = 'kr'; 'india' = 'in'
        'canada' = 'ca'; 'brazil' = 'br'; 'chile' = 'cl'; 'mexico' = 'mx'
        'france' = 'fr'; 'germany' = 'de'; 'sweden' = 'se'; 'norway' = 'no'
        'switzerland' = 'ch'; 'italy' = 'it'; 'spain' = 'es'; 'poland' = 'pl'
        'israel' = 'il'; 'denmark' = 'dk'; 'austria' = 'at'; 'belgium' = 'be'
        'newzealand' = 'nz'; 'malaysia' = 'my'; 'indonesia' = 'id'
        'taiwan' = 'tw'; 'uae' = 'ae'; 'qatar' = 'qa'; 'southafrica' = 'za'
    }
    $deriveAliasCandidates = {
        param($arn)
        $candidates = [System.Collections.Generic.List[string]]::new()
        foreach ($geoLong in $geoLongToShort.Keys) {
            $geoShort = $geoLongToShort[$geoLong]
            # Pattern A: ARM ends with geoLong (westeurope, japaneast, southeastasia)
            #            -> swap to <geoShort><locality> (euwest, jaeast, apsoutheast)
            if ($arn.EndsWith($geoLong) -and $arn.Length -gt $geoLong.Length) {
                $locality = $arn.Substring(0, $arn.Length - $geoLong.Length)
                $candidates.Add("$geoShort$locality") | Out-Null
            }
            # Pattern B: ARM starts with geoLong (centralindia would be 'india'+'central'
            #            but ARM is centralindia which is 'central'+'india', already pattern A)
            #            ARM germanywestcentral -> 'germany' prefix, locality 'westcentral'
            #            -> 'de' + 'westcentral' = 'dewestcentral'
            if ($arn.StartsWith($geoLong) -and $arn.Length -gt $geoLong.Length) {
                $locality = $arn.Substring($geoLong.Length)
                $candidates.Add("$geoShort$locality") | Out-Null
            }
            # Pattern C: ARM also ends with trailing digit (eastus2, westus3) — the
            #            digit is part of the locality+geo+digit pattern. Try
            #            stripping the digit for a locality match too.
            if ($arn -match "^(.+?)($geoLong)(\d+)$") {
                $candidates.Add("$geoShort$($Matches[1])$($Matches[3])") | Out-Null
            }
        }
        # Deduplicate while preserving order
        $seen = @{}
        $unique = [System.Collections.Generic.List[string]]::new()
        foreach ($c in $candidates) {
            if (-not $seen.ContainsKey($c)) { $seen[$c] = $true; $unique.Add($c) | Out-Null }
        }
        return $unique
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
    # Cache schema v3: structured container { Regular, SP1Yr, SP3Yr } per region.
    # Negotiated Savings Plan rates are now harvested from each row's savingsPlan
    # sub-object (effectivePrice + term=P1Y/P3Y per Consumption Price Sheet API spec).
    # v4 splits paired meter names like 'D3/DS3 v2' into both ARM SKUs (D3_v2 + DS3_v2).
    # v2 stored only the flat Regular map; v1 mistakenly accepted Spot meters as PAYG.
    $cacheFile = Join-Path $cacheDir "AzVMLifecycle-PriceSheet-v4-$cacheKey.json"
    # Negative cache sidecar \u2014 records last Tier 1 failure (typically HTTP 429) so we
    # don't keep banging the throttle wall for ~11 minutes per attempt across runs.
    $negCacheFile = Join-Path $cacheDir "AzVMLifecycle-PriceSheet-v4-$cacheKey.failed.json"
    # Best-effort cleanup of obsolete cache files.
    Get-ChildItem $cacheDir -Filter "AzVMLifecycle-PriceSheet-$cacheKey.json" -ErrorAction SilentlyContinue |
        Remove-Item -ErrorAction SilentlyContinue
    Get-ChildItem $cacheDir -Filter "AzVMLifecycle-PriceSheet-v2-$cacheKey.json" -ErrorAction SilentlyContinue |
        Remove-Item -ErrorAction SilentlyContinue
    Get-ChildItem $cacheDir -Filter "AzVMLifecycle-PriceSheet-v3-$cacheKey*.json" -ErrorAction SilentlyContinue |
        Remove-Item -ErrorAction SilentlyContinue

    # Helper: resolve an ARM region to the first matching cached meterLocation key.
    # Order: exact ARM name -> explicit alias table -> generic geo-permutation fallback.
    $resolvePriceSheetKey = {
        param($arn, $cache)
        if ($cache.ContainsKey($arn) -and $cache[$arn] -and $cache[$arn].Count -gt 0) { return $arn }
        if ($armToMeterLocation.ContainsKey($arn)) {
            foreach ($cand in @($armToMeterLocation[$arn])) {
                if ($cache.ContainsKey($cand) -and $cache[$cand] -and $cache[$cand].Count -gt 0) { return $cand }
            }
        }
        # Generic fallback — try permuted aliases derived from known geo tokens.
        foreach ($cand in (& $deriveAliasCandidates $arn)) {
            if ($cache.ContainsKey($cand) -and $cache[$cand] -and $cache[$cand].Count -gt 0) { return $cand }
        }
        return $null
    }

    # Helper: walk a region map and copy each meterLocation-keyed bucket to its
    # ARM-region key (e.g. 'useast2' -> 'eastus2'). Used for the Regular PAYG map
    # and both Savings Plan term maps so downstream consumers can look them up by
    # ARM region without needing the alias table. Mutates the input map in place
    # and returns a list of "arm -> alias (count)" strings for diagnostics.
    $applyArmAliases = {
        param($map)
        $applied = [System.Collections.Generic.List[string]]::new()
        if (-not $map) { return $applied }
        foreach ($arnKey in $armToMeterLocation.Keys) {
            if ($map.ContainsKey($arnKey) -and $map[$arnKey] -and $map[$arnKey].Count -gt 0) { continue }
            foreach ($cand in @($armToMeterLocation[$arnKey])) {
                if ($cand -eq $arnKey) { continue }
                if ($map.ContainsKey($cand) -and $map[$cand] -and $map[$cand].Count -gt 0) {
                    $map[$arnKey] = $map[$cand]
                    $applied.Add("$arnKey -> $cand ($($map[$cand].Count))") | Out-Null
                    break
                }
            }
        }
        return $applied
    }

    # EA/MCA negotiated rates are set at the enrollment level — identical across
    # all subscriptions. Page through the Price Sheet once, group all Linux VM
    # meters by meterLocation, and serve every subsequent region from cache.
    if ($Caches.ActualPricing.ContainsKey('AllRegions')) {
        $cached = $Caches.ActualPricing['AllRegions']
        # Schema v3: structured container. Schema v2 (legacy in-memory): flat region map.
        if ($cached -is [hashtable] -and $cached.ContainsKey('Regular')) {
            $allRegionPrices = $cached.Regular
            if (-not $Caches.NegotiatedSavingsPlan) {
                $Caches.NegotiatedSavingsPlan = @{ '1Yr' = $cached.SP1Yr; '3Yr' = $cached.SP3Yr }
            }
        }
        else {
            $allRegionPrices = $cached
        }
        $lookupKey = & $resolvePriceSheetKey $armLocation $allRegionPrices
        $regionPrices = if ($lookupKey) { $allRegionPrices[$lookupKey] } else { @{} }
        if ($regionPrices.Count -gt 0) {
            $aliasSuffix = if ($lookupKey -ne $armLocation) { " (alias → '$lookupKey')" } else { '' }
            Write-Host "  Tier 1 (Price Sheet): $($regionPrices.Count) negotiated SKU prices for '$Region'$aliasSuffix (cached)" -ForegroundColor DarkGray
        }
        else {
            $isSovereignRegion = $armLocation -match '^(usgov|usdod)'
            $candList = if ($armToMeterLocation.ContainsKey($armLocation)) { @($armToMeterLocation[$armLocation]) -join "', '" } else { '' }
            $aliasNote = if ($candList) { " (tried '$candList')" } else { '' }
            if ($isSovereignRegion) {
                $govKeys = @($allRegionPrices.Keys | Where-Object { $_ -match 'gov|dod|china|german|virginia|arizona|texas' } | Sort-Object)
                $hint = if ($govKeys.Count -gt 0) { " Sovereign keys present in cache: $($govKeys -join ', ')." } else { ' No sovereign keys present in cache.' }
            }
            else {
                $hint = if ($allRegionPrices.Count -gt 0) { " $($allRegionPrices.Count) other region(s) cached — enrollment may not have meters for this region." } else { '' }
            }
            Write-Host "  Tier 1 (Price Sheet): no negotiated rates for '$Region'$aliasNote — falling back to retail.$hint" -ForegroundColor DarkYellow
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
                $loaded = Get-Content $cacheFile -Raw | ConvertFrom-Json -AsHashtable
                # v3: structured. Older v2 caches were already wiped above; defensive fallback in case of partial schema.
                if ($loaded -is [hashtable] -and $loaded.ContainsKey('Regular')) {
                    $allRegionPrices = $loaded.Regular
                    $loadedSP1 = if ($loaded.ContainsKey('SP1Yr')) { $loaded.SP1Yr } else { @{} }
                    $loadedSP3 = if ($loaded.ContainsKey('SP3Yr')) { $loaded.SP3Yr } else { @{} }
                }
                else {
                    $allRegionPrices = $loaded
                    $loadedSP1 = @{}
                    $loadedSP3 = @{}
                }
                $Caches.NegotiatedSavingsPlan = @{ '1Yr' = $loadedSP1; '3Yr' = $loadedSP3 }

                # Resolve sovereign + commercial region pricing — meterLocation abbreviations
                # differ from ARM names. Apply the same alias pass to the Regular PAYG map
                # and both Savings Plan term maps so older v4 caches (written before the
                # SP-alias fix in v2.2.1) get fixed up on load instead of returning retail
                # SP rates for commercial regions.
                $aliasSummary = & $applyArmAliases $allRegionPrices
                $null         = & $applyArmAliases $loadedSP1
                $null         = & $applyArmAliases $loadedSP3
                if ($aliasSummary.Count -gt 0) {
                    Write-Host "  Tier 1 (Price Sheet): sovereign aliases resolved — $($aliasSummary -join '; ')" -ForegroundColor DarkGray
                }

                $Caches.ActualPricing['AllRegions'] = $allRegionPrices
                $totalSkus = ($allRegionPrices.Values | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum
                Write-Host "  Tier 1 (Price Sheet): $totalSkus negotiated SKU prices across $($allRegionPrices.Count) region(s) (from cache file)" -ForegroundColor DarkGray

                $lookupKey = & $resolvePriceSheetKey $armLocation $allRegionPrices
                $regionPrices = if ($lookupKey) { $allRegionPrices[$lookupKey] } else { @{} }
                if ($regionPrices.Count -gt 0) {
                    $aliasSuffix = if ($lookupKey -ne $armLocation) { " (alias → '$lookupKey')" } else { '' }
                    Write-Host "  Tier 1 (Price Sheet): $($regionPrices.Count) negotiated SKU prices for '$Region'$aliasSuffix (cached)" -ForegroundColor DarkGray
                }
                else {
                    $isSovereignRegion = $armLocation -match '^(usgov|usdod)'
                    $candList = if ($armToMeterLocation.ContainsKey($armLocation)) { @($armToMeterLocation[$armLocation]) -join "', '" } else { '' }
                    $aliasNote = if ($candList) { " (tried '$candList')" } else { '' }
                    if ($isSovereignRegion) {
                        $govKeys = @($allRegionPrices.Keys | Where-Object { $_ -match 'gov|dod|china|german|virginia|arizona|texas' } | Sort-Object)
                        $hint = if ($govKeys.Count -gt 0) { " Sovereign keys present in cache: $($govKeys -join ', ')." } else { ' No sovereign keys present in cache.' }
                    }
                    else {
                        $hint = if ($allRegionPrices.Count -gt 0) { " $($allRegionPrices.Count) other region(s) cached — enrollment may not have meters for this region." } else { '' }
                    }
                    Write-Host "  Tier 1 (Price Sheet): no negotiated rates for '$Region'$aliasNote — falling back to retail.$hint" -ForegroundColor DarkYellow
                }
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

    # Corporate-proxy support: Az.Accounts uses its own HttpClient that already
    # negotiates with the proxy, but plain Invoke-RestMethod calls (used below for
    # the Price Sheet API) inherit the system default proxy WITHOUT credentials,
    # which trips HTTP 407 (Proxy Authentication Required) on auth-required
    # corporate proxies (e.g. web-proxy.web.boeing.com). Attach the current
    # user's default credentials once so the Price Sheet calls can punch through.
    try {
        if ([System.Net.WebRequest]::DefaultWebProxy -and -not [System.Net.WebRequest]::DefaultWebProxy.Credentials) {
            [System.Net.WebRequest]::DefaultWebProxy.Credentials = [System.Net.CredentialCache]::DefaultCredentials
        }
    }
    catch {
        Write-Verbose "Could not set DefaultWebProxy.Credentials: $($_.Exception.Message)"
    }

    # Negative-cache check: if a recent Tier 1 attempt failed (e.g. HTTP 429), skip
    # straight to Tier 2 until the cool-down expires. Avoids 30+ minute throttling
    # storms across consecutive runs while the EA Price Sheet API is rate-limiting.
    if (Test-Path $negCacheFile) {
        try {
            $neg = Get-Content $negCacheFile -Raw | ConvertFrom-Json
            $negAt = [datetime]$neg.At
            $cool = [int]($neg.CoolDownSeconds)
            $negStatus = [int]($neg.Status)
            $remaining = ($negAt.AddSeconds($cool) - (Get-Date)).TotalSeconds
            # Discard stale cooldown entries whose status isn't a real HTTP error code
            # (e.g. older builds misparsed proxy port numbers as status 310). Without
            # this guard, those entries would keep us locked out of Tier 1 forever.
            if ($negStatus -lt 400 -or $negStatus -gt 599) {
                Write-Verbose "Discarding implausible Tier 1 negative-cache status ($negStatus); retrying."
                Remove-Item $negCacheFile -ErrorAction SilentlyContinue
            }
            elseif ($remaining -gt 0) {
                $remMin = [math]::Ceiling($remaining / 60)
                Write-Host "  Tier 1 (Price Sheet): skipped — prior failure ($negStatus) cooling down for ~$remMin min. Using retail." -ForegroundColor DarkYellow
                return $null
            }
            else {
                Remove-Item $negCacheFile -ErrorAction SilentlyContinue
            }
        }
        catch {
            Remove-Item $negCacheFile -ErrorAction SilentlyContinue
        }
    }

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
    $allRegionSP1Yr  = @{}  # negotiated Savings Plan P1Y per region
    $allRegionSP3Yr  = @{}  # negotiated Savings Plan P3Y per region
    $totalSP1Meters  = 0
    $totalSP3Meters  = 0
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
        # Skip-reason diagnostics — surface gaps in the negotiated price-sheet ingest
        # so we can see WHY a region might end up with zero negotiated SKUs.
        $skipReasons = [ordered]@{
            NoMeterDetails    = 0
            NotVirtualMachine = 0
            WindowsSubcategory = 0
            SpotOrLowPriority  = 0
            EmptyMeterLocation = 0
            UnparsableMeterName = 0
            ZeroOrNegativeUnitPrice = 0
        }
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
                    if (-not $md) { $skipReasons.NoMeterDetails++; continue }

                    if ($md.meterCategory -ne 'Virtual Machines') { $skipReasons.NotVirtualMachine++; continue }
                    if ($md.meterSubCategory -match 'Windows') { $skipReasons.WindowsSubcategory++; continue }

                    # CRITICAL: Skip non-PAYG VM meters (Spot, Low Priority).
                    # Previous code stripped these suffixes and treated them as Regular,
                    # causing Spot rates (~1/8 of PAYG) to be cached as negotiated PAYG
                    # whenever the Spot meter appeared first in the price sheet pages.
                    # meterSubCategory or meterName carry these markers; check both.
                    $meterNameRaw = [string]$md.meterName
                    $meterSub = [string]$md.meterSubCategory
                    if ($meterNameRaw -match '\b(Spot|Low Priority)\b' -or
                        $meterSub -match '\b(Spot|Low Priority)\b') {
                        $skipReasons.SpotOrLowPriority++; continue
                    }

                    # Normalize meterLocation to ARM-style key (lowercase, no spaces/hyphens)
                    $meterLoc = $md.meterLocation
                    $normalizedRegion = ($meterLoc -replace '[\s-]', '').ToLower()
                    if (-not $normalizedRegion) { $skipReasons.EmptyMeterLocation++; continue }

                    # Convert billing meter name to ARM SKU name(s).
                    # Older paired sizes (e.g. 'D3 v2/DS3 v2', 'D8 v3/D8s v3', 'D1 v2/DS1 v2')
                    # ship as a single combined meter where each side already carries its own
                    # version suffix and the slash sits between two space-separated tokens.
                    # The basic and premium-storage 's' variants share the exact same rate,
                    # so we split on '/' and emit one ARM SKU per fragment. We also strip the
                    # legacy " - Expired" suffix some meters carry so expired meters still
                    # resolve to the live ARM SKU name (rates remain valid for billing).
                    # No longer strip Spot/Low Priority — those meters are filtered out above.
                    $cleanName = $meterNameRaw.Trim() -replace '^Standard[\s_]+', ''
                    if ($cleanName -notmatch '^[A-Z]') { $skipReasons.UnparsableMeterName++; continue }
                    $cleanName = $cleanName -replace '\s*-\s*Expired\s*$', ''
                    $vmSizes = @()
                    if ($cleanName -like '*/*') {
                        foreach ($frag in ($cleanName -split '/')) {
                            $f = $frag.Trim()
                            if ($f) { $vmSizes += "Standard_$($f -replace '\s+', '_')" }
                        }
                    }
                    else {
                        $vmSizes = @("Standard_$($cleanName -replace '\s+', '_')")
                    }
                    if (-not $vmSizes -or $vmSizes.Count -eq 0) { $skipReasons.UnparsableMeterName++; continue }

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

                    # Savings Plan rows: per Consumption Price Sheet API spec, rows for SP-eligible
                    # meters carry a savingsPlan sub-object with effectivePrice (negotiated) +
                    # term (P1Y/P3Y). Route these to the per-term SP map and SKIP populating the
                    # Regular PAYG entry (those come from rows without savingsPlan). Sovereign
                    # regions don't expose SP product, so these rows simply won't appear there.
                    if ($item.savingsPlan -and $item.savingsPlan.term -and $item.savingsPlan.effectivePrice) {
                        $spRaw = [double]$item.savingsPlan.effectivePrice
                        if ($spRaw -gt 0) {
                            $spHourly  = $spRaw / $hourlyDivisor
                            $spMonthly = [math]::Round($spHourly * $HoursPerMonth, 2)
                            $spEntry = @{
                                Hourly       = [math]::Round($spHourly, 4)
                                Monthly      = $spMonthly
                                Total        = if ($item.savingsPlan.term -eq 'P1Y') { [math]::Round($spMonthly * 12, 2) } else { [math]::Round($spMonthly * 36, 2) }
                                Currency     = $item.currencyCode
                                IsNegotiated = $true
                            }
                            switch ($item.savingsPlan.term) {
                                'P1Y' {
                                    if (-not $allRegionSP1Yr.ContainsKey($normalizedRegion)) { $allRegionSP1Yr[$normalizedRegion] = @{} }
                                    foreach ($vmSize in $vmSizes) {
                                        if (-not $allRegionSP1Yr[$normalizedRegion].ContainsKey($vmSize)) {
                                            $allRegionSP1Yr[$normalizedRegion][$vmSize] = $spEntry
                                            $totalSP1Meters++
                                        }
                                    }
                                }
                                'P3Y' {
                                    if (-not $allRegionSP3Yr.ContainsKey($normalizedRegion)) { $allRegionSP3Yr[$normalizedRegion] = @{} }
                                    foreach ($vmSize in $vmSizes) {
                                        if (-not $allRegionSP3Yr[$normalizedRegion].ContainsKey($vmSize)) {
                                            $allRegionSP3Yr[$normalizedRegion][$vmSize] = $spEntry
                                            $totalSP3Meters++
                                        }
                                    }
                                }
                            }
                        }
                        continue  # SP rows do not populate the Regular PAYG map
                    }

                    # Initialize region bucket if needed
                    if (-not $allRegionPrices.ContainsKey($normalizedRegion)) {
                        $allRegionPrices[$normalizedRegion] = @{}
                    }

                    $rawRate = [double]$item.unitPrice
                    if ($rawRate -le 0) { $skipReasons.ZeroOrNegativeUnitPrice++; continue }
                    $negotiatedRate = $rawRate / $hourlyDivisor
                    $retailRate = if ($md.pretaxStandardRate) { [double]$md.pretaxStandardRate / $hourlyDivisor } else { $null }
                    $newEntry = @{
                        Hourly       = [math]::Round($negotiatedRate, 4)
                        Monthly      = [math]::Round($negotiatedRate * $HoursPerMonth, 2)
                        Currency     = $item.currencyCode
                        Meter        = $md.meterName
                        IsNegotiated = $true
                    }
                    if ($retailRate -and $retailRate -gt 0) {
                        $newEntry.RetailHourly = [math]::Round($retailRate, 4)
                        $newEntry.DiscountPct  = [math]::Round((1 - ($negotiatedRate / $retailRate)) * 100, 1)
                    }
                    foreach ($vmSize in $vmSizes) {
                        if (-not $allRegionPrices[$normalizedRegion].ContainsKey($vmSize)) {
                            $allRegionPrices[$normalizedRegion][$vmSize] = $newEntry
                            $totalVmMeters++
                            $pageVmCount++
                        }
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
            # Resolve sovereign + commercial region pricing — meterLocation abbreviations
            # differ from ARM names (e.g. 'useast2' vs 'eastus2'). Apply the same alias
            # pass to the Regular PAYG map and both Savings Plan term maps so downstream
            # consumers can look them up by ARM region without re-implementing the alias
            # table. Without this pass on SP maps, commercial-region overlays in
            # Get-AzVMAvailability silently fall back to retail SP rates.
            $aliasSummary = & $applyArmAliases $allRegionPrices
            $null         = & $applyArmAliases $allRegionSP1Yr
            $null         = & $applyArmAliases $allRegionSP3Yr
            if ($aliasSummary.Count -gt 0) {
                Write-Host "  Tier 1 (Price Sheet): sovereign aliases resolved — $($aliasSummary -join '; ')" -ForegroundColor DarkGray
            }

            # Cache the full scan — all subsequent calls for any region are served from here
            $Caches.ActualPricing['AllRegions'] = $allRegionPrices
            $Caches.NegotiatedSavingsPlan = @{ '1Yr' = $allRegionSP1Yr; '3Yr' = $allRegionSP3Yr }

            # Persist to disk so subsequent runs skip the API entirely (v3 structured shape).
            try {
                $cacheBundle = @{ Regular = $allRegionPrices; SP1Yr = $allRegionSP1Yr; SP3Yr = $allRegionSP3Yr }
                $cacheJson = ConvertTo-Json -InputObject $cacheBundle -Depth 5 -Compress
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
            if ($totalSP1Meters -gt 0 -or $totalSP3Meters -gt 0) {
                Write-Host "  Tier 1 (Price Sheet): negotiated Savings Plan rates — $totalSP1Meters x P1Y, $totalSP3Meters x P3Y" -ForegroundColor DarkGray
            }
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
            # Surface skip-reason counters to help diagnose missing regions/SKUs.
            $skipParts = @()
            foreach ($k in $skipReasons.Keys) { if ($skipReasons[$k] -gt 0) { $skipParts += "$k=$($skipReasons[$k])" } }
            if ($skipParts.Count -gt 0) {
                Write-Host "  Tier 1 (Price Sheet): $totalItems total meters, $totalVmMeters VM SKUs kept; skipped: $($skipParts -join ', ')" -ForegroundColor DarkGray
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
        if (-not $psStatus) {
            # Prefer explicit 'status code NNN' / 'HTTP NNN' patterns over any 3-digit
            # number — corporate-proxy errors embed port numbers (e.g. ':31060') that
            # otherwise misclassify as HTTP 310.
            $msg = $psError.Exception.Message
            if ($msg -match "status code\s*['""]?(\d{3})") { $psStatus = [int]$Matches[1] }
            elseif ($msg -match '\bHTTP\s+(\d{3})\b') { $psStatus = [int]$Matches[1] }
            elseif ($msg -match '\((\d{3})\)') { $psStatus = [int]$Matches[1] }
        }
        if ($psStatus -eq 407) {
            Write-Warning "Tier 1 (Price Sheet): proxy authentication required (HTTP 407) at '$([System.Net.WebRequest]::DefaultWebProxy.GetProxy($armUrl))'."
            Write-Warning "  The current user's default credentials were sent but rejected. Try one of:"
            Write-Warning "    \$cred = Get-Credential; [System.Net.WebRequest]::DefaultWebProxy.Credentials = \$cred"
            Write-Warning "    or set HTTPS_PROXY/HTTP_PROXY env vars with embedded credentials"
            Write-Warning "    or run from a network without a proxy in front of management.azure.com."
        }
        Write-Host "  Tier 1 (Price Sheet): failed$(if ($psStatus) { " (HTTP $psStatus)" }) — trying Tier 2..." -ForegroundColor DarkGray
        Write-Verbose "Tier 1 (Price Sheet) failed$(if ($psStatus) { " (HTTP $psStatus)" }): $($psError.Exception.Message). Falling through to Tier 2."
        # Persist negative cache so subsequent runs short-circuit straight to Tier 2.
        # 429 cools down for 30 min; other server-side errors get a shorter 5 min hold.
        $coolDown = if ($psStatus -eq 429) { 1800 } elseif ($psStatus -ge 500) { 300 } else { 300 }
        try {
            $negPayload = @{ At = (Get-Date).ToString('o'); Status = $psStatus; CoolDownSeconds = $coolDown; Message = ($psError.Exception.Message -replace '\s+', ' ').Substring(0, [math]::Min(200, $psError.Exception.Message.Length)) }
            $negJson = ConvertTo-Json -InputObject $negPayload -Compress
            [System.IO.File]::WriteAllText($negCacheFile, $negJson, [System.Text.Encoding]::UTF8)
            Write-Host "  Tier 1 cool-down: $([math]::Ceiling($coolDown / 60)) min (subsequent runs will skip Tier 1)." -ForegroundColor DarkGray
        }
        catch {
            Write-Verbose "Could not write Tier 1 negative-cache file: $($_.Exception.Message)"
        }
    }

    # ── Tier 2: Cost Management Query API ──
    # Derives effective rate from actual usage. Covers deployed SKUs only.
    # Works for all billing types (EA, MCA, CSP, PAYG).
    # Tier 2 is region-specific (filters by ResourceLocation) since Cost Management
    # doesn't support unfiltered queries efficiently.
    if (-not $tier1Success) {
        try {
            # Group by ResourceLocation so we can verify each row belongs to $armLocation
            # before adopting its rate. Cost Management does not honour ResourceLocation
            # in $filter for ActualCost queries, so we filter client-side after grouping.
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
                        @{ type = 'Dimension'; name = 'ResourceLocation' }
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
            $locIdx    = if ($colMap.ContainsKey('ResourceLocation')) { $colMap['ResourceLocation'] } else { $null }
            $subCatIdx = $colMap['MeterSubcategory']
            $meterIdx  = $colMap['Meter']
            $currIdx   = if ($colMap.ContainsKey('Currency')) { $colMap['Currency'] } else { $null }

            $rowCount = if ($cmResponse.properties.rows) { $cmResponse.properties.rows.Count } else { 0 }
            $tier2Skipped = [ordered]@{
                LocationMismatch  = 0
                SpotOrLowPriority = 0
                WindowsSubcategory = 0
                ZeroOrNegative    = 0
                UnparsableMeter   = 0
            }

            foreach ($row in $cmResponse.properties.rows) {
                $cost        = [double]$row[$costIdx]
                $quantity    = [double]$row[$qtyIdx]
                $subCategory = $row[$subCatIdx]
                $meterName   = $row[$meterIdx]
                $currency    = if ($null -ne $currIdx) { $row[$currIdx] } else { 'USD' }

                # Region scoping: skip rows whose ResourceLocation does not normalize to
                # the queried region. Without this guard, multi-region usage in the same
                # subscription would have other regions' rates written under $armLocation.
                if ($null -ne $locIdx) {
                    $rowLoc = [string]$row[$locIdx]
                    $rowLocNorm = ($rowLoc.ToLower() -replace '[\s-]', '')
                    if (-not $rowLocNorm -or $rowLocNorm -ne $armLocation) {
                        $tier2Skipped.LocationMismatch++
                        continue
                    }
                }

                if ($subCategory -match 'Windows') { $tier2Skipped.WindowsSubcategory++; continue }

                # Spot / Low Priority meters bill at ~1/8 of PAYG. Keeping them in the
                # negotiated PAYG map (which the v2.2.0 release surface used to do via a
                # regex strip) corrupts the cached rate. Drop them here; spot pricing is
                # served separately via the retail Spot map.
                if ($meterName -match '\b(Spot|Low Priority)\b' -or
                    $subCategory -match '\b(Spot|Low Priority)\b') {
                    $tier2Skipped.SpotOrLowPriority++
                    continue
                }

                if ($quantity -le 0 -or $cost -le 0) { $tier2Skipped.ZeroOrNegative++; continue }

                $hourlyRate = $cost / $quantity

                $cleanName = $meterName.Trim() -replace '^Standard[\s_]+', ''
                if ($cleanName -match '^[A-Z]') {
                    $vmSize = "Standard_$($cleanName -replace '\s+', '_')"
                }
                else { $tier2Skipped.UnparsableMeter++; continue }

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
            $skipParts = @()
            foreach ($k in $tier2Skipped.Keys) { if ($tier2Skipped[$k] -gt 0) { $skipParts += "$k=$($tier2Skipped[$k])" } }
            if ($skipParts.Count -gt 0) {
                Write-Verbose "Tier 2 skip reasons: $($skipParts -join ', ')"
            }
            Write-Verbose "Tier 2 (Cost Query): $rowCount usage rows, $tier2Count VM SKU prices for region '$armLocation'."
        }
        catch {
            $errorMsg = $_.Exception.Message
            $statusCode = $null
            if ($_.Exception.Response) { $statusCode = [int]$_.Exception.Response.StatusCode }
            if (-not $statusCode) {
                # See Tier 1 catch — avoid misclassifying proxy port numbers as the HTTP status.
                if ($errorMsg -match "status code\s*['""]?(\d{3})") { $statusCode = [int]$Matches[1] }
                elseif ($errorMsg -match '\bHTTP\s+(\d{3})\b') { $statusCode = [int]$Matches[1] }
                elseif ($errorMsg -match '\((\d{3})\)') { $statusCode = [int]$Matches[1] }
            }

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
                    407 {
                        $proxyUri = try { [System.Net.WebRequest]::DefaultWebProxy.GetProxy($armUrl) } catch { '<unknown>' }
                        Write-Warning "Cost Management: proxy authentication required (HTTP 407) at '$proxyUri'."
                        Write-Warning "  Default Windows credentials were sent but rejected. Options:"
                        Write-Warning "    \$cred = Get-Credential; [System.Net.WebRequest]::DefaultWebProxy.Credentials = \$cred"
                        Write-Warning "    or set HTTPS_PROXY/HTTP_PROXY env vars with embedded credentials"
                        Write-Warning "    or run from a network without a proxy in front of management.azure.com."
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

    $lookupKey = & $resolvePriceSheetKey $armLocation $allRegionPrices
    $regionPrices = if ($lookupKey) { $allRegionPrices[$lookupKey] } else { @{} }
    return $regionPrices
}
