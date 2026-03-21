function Get-AzVMPricing {
    <#
    .SYNOPSIS
        Fetches VM pricing from Azure Retail Prices API.
    .DESCRIPTION
        Retrieves pay-as-you-go Linux pricing for VM SKUs in a given region.
        Uses the public Azure Retail Prices API (no auth required).
        Implements caching to minimize API calls.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Region,

        [int]$MaxRetries = 3,

        [int]$HoursPerMonth = 730,

        [hashtable]$AzureEndpoints,

        [string]$TargetEnvironment = 'AzureCloud',

        [System.Collections.IDictionary]$Caches = @{}
    )

    if (-not $Caches.Pricing) {
        $Caches.Pricing = @{}
    }

    $armLocation = $Region.ToLower() -replace '\s', ''

    # Return cached pricing if already fetched this region
    if ($Caches.Pricing.ContainsKey($armLocation) -and $Caches.Pricing[$armLocation]) {
        return $Caches.Pricing[$armLocation]
    }

    # Get environment-specific endpoints (supports sovereign clouds)
    if (-not $AzureEndpoints) {
        $AzureEndpoints = Get-AzureEndpoints -EnvironmentName $TargetEnvironment
    }

    # Build filter for the API - get Linux consumption pricing
    $filter = "armRegionName eq '$armLocation' and priceType eq 'Consumption' and serviceName eq 'Virtual Machines'"

    $regularPrices = @{}
    $spotPrices = @{}
    $apiUrl = "$($AzureEndpoints.PricingApiUrl)?`$filter=$([uri]::EscapeDataString($filter))"

    try {
        $nextLink = $apiUrl
        $pageCount = 0
        $maxPages = 20  # Fetch up to 20 pages (~20,000 price entries)

        while ($nextLink -and $pageCount -lt $maxPages) {
            $uri = $nextLink
            $response = Invoke-WithRetry -MaxRetries $MaxRetries -OperationName "Retail Pricing API (page $($pageCount + 1))" -ScriptBlock {
                Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 30
            }
            $pageCount++

            foreach ($item in $response.Items) {
                # Filter for Linux spot/regular pricing, skip Windows and Low Priority
                if ($item.productName -match 'Windows' -or
                    $item.skuName -match 'Low Priority' -or
                    $item.meterName -match 'Low Priority') {
                    continue
                }

                # Extract the VM size from armSkuName
                $vmSize = $item.armSkuName
                if (-not $vmSize) { continue }

                $isSpot = ($item.skuName -match 'Spot' -or $item.meterName -match 'Spot')
                $targetMap = if ($isSpot) { $spotPrices } else { $regularPrices }

                if (-not $targetMap[$vmSize]) {
                    $targetMap[$vmSize] = @{
                        Hourly   = [math]::Round($item.retailPrice, 4)
                        Monthly  = [math]::Round($item.retailPrice * $HoursPerMonth, 2)
                        Currency = $item.currencyCode
                        Meter    = $item.meterName
                    }
                }
            }

            $nextLink = $response.NextPageLink
        }

        $result = [ordered]@{
            Regular = $regularPrices
            Spot    = $spotPrices
        }

        $Caches.Pricing[$armLocation] = $result

        return $result
    }
    catch {
        Write-Verbose "Failed to fetch pricing for region $Region`: $_"
        return [ordered]@{
            Regular = @{}
            Spot    = @{}
        }
    }
}
