function Get-ValidAzureRegions {
    <#
    .SYNOPSIS
        Returns list of valid Azure region names that support Compute, with caching.
    .DESCRIPTION
        Uses REST API for speed (2-3x faster than Get-AzLocation).
        Falls back to Get-AzLocation if REST API fails.
        Caches result in the passed-in -Caches dictionary to avoid repeated calls.
    #>
    [OutputType([string[]])]
    param(
        [int]$MaxRetries = 3,
        [hashtable]$AzureEndpoints,
        [System.Collections.IDictionary]$Caches = @{}
    )

    # Return cached result if available
    $cachedRegions = $Caches.ValidRegions
    if ($cachedRegions) {
        Write-Verbose "Using cached region list ($($cachedRegions.Count) regions)"
        return $cachedRegions
    }

    Write-Verbose "Fetching valid Azure regions..."

    try {
        # Get current subscription context
        $ctx = Get-AzContext -ErrorAction Stop
        if (-not $ctx) {
            throw "No Azure context available"
        }

        $subId = $ctx.Subscription.Id

        # Use environment-aware ARM URL (supports sovereign clouds)
        $armUrl = if ($AzureEndpoints) { $AzureEndpoints.ResourceManagerUrl } else { 'https://management.azure.com' }
        $armUrl = $armUrl.TrimEnd('/')

        $token = (Get-AzAccessToken -ResourceUrl $armUrl -ErrorAction Stop).Token

        # REST API call (faster than Get-AzLocation)
        $uri = "$armUrl/subscriptions/$subId/locations?api-version=2022-12-01"
        $headers = @{
            'Authorization' = "Bearer $token"
            'Content-Type'  = 'application/json'
        }

        try {
            $response = Invoke-WithRetry -MaxRetries $MaxRetries -OperationName 'Region list API' -ScriptBlock {
                Invoke-RestMethod -Uri $uri -Method Get -Headers $headers -ErrorAction Stop
            }
        }
        finally {
            $headers['Authorization'] = $null
            $token = $null
        }

        # Filter to regions with valid names (exclude logical/paired regions)
        $validRegions = $response.value | Where-Object {
            $_.metadata.regionCategory -ne 'Other' -and
            $_.name -match '^[a-z0-9]+$'
        } | Select-Object -ExpandProperty name | ForEach-Object { $_.ToLower() }

        if ($validRegions.Count -eq 0) {
            throw "REST API returned no valid regions"
        }

        Write-Verbose "Fetched $($validRegions.Count) regions via REST API"
        $Caches.ValidRegions = @($validRegions)
        return @($validRegions)
    }
    catch {
        Write-Verbose "REST API failed: $($_.Exception.Message). Falling back to Get-AzLocation..."

        try {
            # Fallback to Get-AzLocation (slower but more reliable)
            $validRegions = Get-AzLocation -ErrorAction Stop |
            Where-Object { $_.Providers -contains 'Microsoft.Compute' } |
            Select-Object -ExpandProperty Location |
            ForEach-Object { $_.ToLower() }

            if ($validRegions.Count -eq 0) {
                throw "Get-AzLocation returned no valid regions"
            }

            Write-Verbose "Fetched $($validRegions.Count) regions via Get-AzLocation"
            $Caches.ValidRegions = @($validRegions)
            return @($validRegions)
        }
        catch {
            Write-Warning "Failed to retrieve valid Azure regions: $($_.Exception.Message)"
            Write-Warning "Region validation metadata is unavailable."
            return $null
        }
    }
}
