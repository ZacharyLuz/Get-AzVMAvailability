function Get-AdvisorRetirementData {
    <#
    .SYNOPSIS
        Queries Azure Advisor for VM SKU retirement recommendations.
    .DESCRIPTION
        Fetches ServiceUpgradeAndRetirement recommendations from the Advisor API
        and builds a hashtable keyed by retirement series grouping for fast lookup.
        Results are cached in $script:RunContext.Caches.AdvisorRetirement for the session.
    #>
    param(
        [string]$SubscriptionId,
        [string]$ArmUrl = 'https://management.azure.com',
        [string]$BearerToken,
        [int]$MaxRetries = 3
    )

    # Return cached data if available
    # Return cached data if available (keyed by subscription)
    if ($script:RunContext -and $script:RunContext.Caches.AdvisorRetirement -and
        $script:RunContext.Caches.AdvisorRetirement.ContainsKey($SubscriptionId)) {
        return $script:RunContext.Caches.AdvisorRetirement[$SubscriptionId]
    }

    $result = @{}
    try {
        $uri = "$($ArmUrl.TrimEnd('/'))/subscriptions/$SubscriptionId/providers/Microsoft.Advisor/recommendations?api-version=2023-01-01&`$filter=Category eq 'HighAvailability'"
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

        Write-Verbose "Advisor: found $($result.Count) retirement group(s) covering $(@($result.Values | ForEach-Object { $_.VMs.Count } | Measure-Object -Sum).Sum) VM(s)"
    }
    catch {
        Write-Verbose "Advisor retirement query failed (non-fatal, falling back to pattern table): $_"
    }

    # Cache the result keyed by subscription
    if ($script:RunContext -and $script:RunContext.Caches) {
        if (-not $script:RunContext.Caches.AdvisorRetirement) {
            $script:RunContext.Caches.AdvisorRetirement = @{}
        }
        $script:RunContext.Caches.AdvisorRetirement[$SubscriptionId] = $result
    }

    return $result
}
