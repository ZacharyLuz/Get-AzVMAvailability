function Get-PlacementScores {
    <#
    .SYNOPSIS
        Retrieves Azure VM placement likelihood scores for SKU and region combinations.
    .DESCRIPTION
        Calls Invoke-AzSpotPlacementScore (API name includes "Spot", but returned placement
        signal is broadly useful for VM allocation planning). Returns a hashtable keyed by
        "sku|region" with score metadata.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'DesiredCount', Justification = 'Used inside Invoke-WithRetry scriptblock closure')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'IncludeAvailabilityZone', Justification = 'Used inside Invoke-WithRetry scriptblock closure')]
    param(
        [Parameter(Mandatory)]
        [string[]]$SkuNames,

        [Parameter(Mandatory)]
        [string[]]$Regions,

        [ValidateRange(1, 1000)]
        [int]$DesiredCount = 1,

        [switch]$IncludeAvailabilityZone,

        [int]$MaxRetries = 3,

        [System.Collections.IDictionary]$Caches = @{}
    )

    $scores = @{}
    $uniqueSkus = @($SkuNames | Where-Object { $_ } | ForEach-Object { $_.Trim() } | Where-Object { $_ } | Select-Object -Unique)
    $uniqueRegions = @($Regions | Where-Object { $_ } | ForEach-Object { $_.Trim().ToLower() } | Where-Object { $_ } | Select-Object -Unique)
    if ($uniqueSkus.Count -gt 5) {
        Write-Verbose "Placement score: truncating from $($uniqueSkus.Count) to 5 SKUs (API limit)."
    }
    if ($uniqueRegions.Count -gt 8) {
        Write-Verbose "Placement score: truncating from $($uniqueRegions.Count) to 8 regions (API limit)."
    }
    $normalizedSkus = @($uniqueSkus | Select-Object -First 5)
    $normalizedRegions = @($uniqueRegions | Select-Object -First 8)

    if ($normalizedSkus.Count -eq 0 -or $normalizedRegions.Count -eq 0) {
        return $scores
    }

    if (-not (Get-Command -Name 'Invoke-AzSpotPlacementScore' -ErrorAction SilentlyContinue)) {
        Write-Verbose 'Invoke-AzSpotPlacementScore is not available in the current Az.Compute module.'
        return $scores
    }

    try {
        $response = Invoke-WithRetry -MaxRetries $MaxRetries -OperationName 'Spot Placement Score API' -ScriptBlock {
            Invoke-AzSpotPlacementScore -Location $normalizedRegions -Sku $normalizedSkus -DesiredCount $DesiredCount -IsZonePlacement:$IncludeAvailabilityZone.IsPresent -ErrorAction Stop
        }
    }
    catch {
        $errorText = $_.Exception.Message
        $isForbidden = $errorText -match '403|forbidden|authorization|not authorized|insufficient privileges'
        if ($isForbidden) {
            if (-not $Caches.PlacementWarned403) {
                Write-Warning 'Placement score lookup skipped: missing permissions (Compute Recommendations Role).'
                $Caches.PlacementWarned403 = $true
            }
            return $scores
        }

        Write-Verbose "Failed to retrieve placement scores: $errorText"
        return $scores
    }

    $rows = @()
    if ($null -eq $response) {
        return $scores
    }

    if ($response -is [System.Collections.IEnumerable] -and $response -isnot [string]) {
        $rows = @($response)
    }
    else {
        $rows = @($response)
    }

    foreach ($row in $rows) {
        if ($null -eq $row) { continue }

        $sku = @($row.Sku, $row.SkuName, $row.VmSize, $row.ArmSkuName) | Where-Object { $_ } | Select-Object -First 1
        $region = @($row.Region, $row.Location, $row.ArmRegionName) | Where-Object { $_ } | Select-Object -First 1
        $score = @($row.Score, $row.PlacementScore, $row.AvailabilityScore) | Where-Object { $_ } | Select-Object -First 1

        if (-not $sku -or -not $region) { continue }

        $key = "$sku|$($region.ToString().ToLower())"
        $scores[$key] = [pscustomobject]@{
            Score        = if ($score) { $score.ToString() } else { 'N/A' }
            IsAvailable  = if ($null -ne $row.IsAvailable) { [bool]$row.IsAvailable } else { $null }
            IsRestricted = if ($null -ne $row.IsRestricted) { [bool]$row.IsRestricted } else { $null }
        }
    }

    return $scores
}
