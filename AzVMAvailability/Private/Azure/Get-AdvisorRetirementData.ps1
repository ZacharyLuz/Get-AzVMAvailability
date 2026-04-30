function Get-AdvisorRetirementData {
    <#
    .SYNOPSIS
        Queries Azure Advisor for VM SKU retirement recommendations.
    .DESCRIPTION
        Uses Azure Resource Graph (advisorresources table) for a single tenant-wide query
        when Az.ResourceGraph is available. Falls back to the per-subscription Advisor REST API.
        Results are cached in $script:RunContext.Caches.AdvisorRetirement for the session.
    #>
    param(
        [string[]]$SubscriptionId,
        [string[]]$ManagementGroup,
        [string]$ArmUrl = 'https://management.azure.com',
        [string]$BearerToken,
        [int]$MaxRetries = 3
    )

    # Return cached data if available (single tenant-wide cache)
    if ($script:RunContext -and $script:RunContext.Caches.AdvisorRetirement) {
        return $script:RunContext.Caches.AdvisorRetirement
    }

    $result = @{}

    # Strategy 1: Azure Resource Graph — single query across all subscriptions
    $useARG = $false
    try {
        if (Get-Command -Name 'Search-AzGraph' -ErrorAction SilentlyContinue) {
            $useARG = $true
        }
    }
    catch { Write-Verbose "Search-AzGraph availability check failed: $($_.Exception.Message)" }

    if ($useARG) {
        try {
            $argQuery = @"
advisorresources
| where type =~ 'microsoft.advisor/recommendations'
| where properties.category =~ 'HighAvailability'
| where properties.extendedProperties.recommendationSubCategory =~ 'ServiceUpgradeAndRetirement'
| where properties.impactedField has 'VIRTUALMACHINES'
| project
    seriesName = tostring(properties.extendedProperties.retirementFeatureName),
    retireDate = tostring(properties.extendedProperties.retirementDate),
    impact = tostring(properties.impact),
    vmName = tostring(properties.impactedValue),
    subscriptionId
"@
            $argParams = @{ Query = $argQuery; First = 1000 }
            if ($ManagementGroup) { $argParams['ManagementGroup'] = $ManagementGroup }
            elseif ($SubscriptionId) { $argParams['Subscription'] = $SubscriptionId }

            $allRecs = [System.Collections.Generic.List[PSCustomObject]]::new()
            do {
                $page = Search-AzGraph @argParams
                if ($page) {
                    foreach ($r in $page) { $allRecs.Add($r) }
                    if ($page.SkipToken) { $argParams['SkipToken'] = $page.SkipToken }
                    else { break }
                }
                else { break }
            } while ($true)

            foreach ($rec in $allRecs) {
                $seriesName = $rec.seriesName
                $retireDate = $rec.retireDate
                $vmName     = $rec.vmName

                if ($seriesName -and $retireDate) {
                    if (-not $result[$seriesName]) {
                        $result[$seriesName] = @{
                            RetireDate = $retireDate
                            Series     = $seriesName
                            Impact     = $rec.impact
                            Status     = if ([datetime]$retireDate -lt [datetime]::UtcNow) { 'Retired' } else { 'Retiring' }
                            VMs        = [System.Collections.Generic.List[string]]::new()
                        }
                    }
                    if ($vmName) { $result[$seriesName].VMs.Add($vmName) }
                }
            }

            $totalVMs = @($result.Values | ForEach-Object { $_.VMs.Count } | Measure-Object -Sum).Sum
            Write-Verbose "Advisor (ARG): found $($result.Count) retirement group(s) covering $totalVMs VM(s) across tenant"
        }
        catch {
            Write-Verbose "ARG advisor query failed, falling back to REST API: $_"
            $useARG = $false
            $result = @{}
        }
    }

    # Strategy 2: Fallback — per-subscription REST API (single subscription only)
    if (-not $useARG) {
        $fallbackSubId = if ($SubscriptionId) { $SubscriptionId[0] } else { $null }
        if ($fallbackSubId -and $BearerToken) {
            try {
                $uri = "$($ArmUrl.TrimEnd('/'))/subscriptions/$fallbackSubId/providers/Microsoft.Advisor/recommendations?api-version=2023-01-01&`$filter=Category eq 'HighAvailability'"
                $headers = @{ Authorization = "Bearer $BearerToken" }
                $advisorResp = Invoke-WithRetry -ScriptBlock {
                    Invoke-RestMethod -Uri $uri -Headers $headers -Method Get -TimeoutSec 30 -ErrorAction Stop
                } -MaxRetries $MaxRetries

                if ($advisorResp.value) {
                    foreach ($rec in $advisorResp.value) {
                        $props = $rec.properties
                        if ($props.extendedProperties.recommendationSubCategory -ne 'ServiceUpgradeAndRetirement') { continue }
                        if ($props.impactedField -notmatch 'VIRTUALMACHINES') { continue }

                        $retireDate = $props.extendedProperties.retirementDate
                        $seriesName = $props.extendedProperties.retirementFeatureName
                        $vmName = $props.impactedValue

                        if ($seriesName -and $retireDate) {
                            if (-not $result[$seriesName]) {
                                $result[$seriesName] = @{
                                    RetireDate = $retireDate
                                    Series     = $seriesName
                                    Impact     = $props.impact
                                    Status     = if ([datetime]$retireDate -lt [datetime]::UtcNow) { 'Retired' } else { 'Retiring' }
                                    VMs        = [System.Collections.Generic.List[string]]::new()
                                }
                            }
                            $result[$seriesName].VMs.Add($vmName)
                        }
                    }
                }

                $totalVMs = @($result.Values | ForEach-Object { $_.VMs.Count } | Measure-Object -Sum).Sum
                Write-Verbose "Advisor (REST): found $($result.Count) retirement group(s) covering $totalVMs VM(s) in subscription $fallbackSubId"
            }
            catch {
                Write-Verbose "Advisor retirement query failed (non-fatal, falling back to pattern table): $_"
            }
        }
    }

    # Cache the result (single tenant-wide hashtable)
    if ($script:RunContext -and $script:RunContext.Caches) {
        $script:RunContext.Caches.AdvisorRetirement = $result
    }

    return $result
}
