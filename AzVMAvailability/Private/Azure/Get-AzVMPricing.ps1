function Get-AzVMPricing {
    <#
    .SYNOPSIS
        Fetches VM pricing from Azure Retail Prices API.
    .DESCRIPTION
        Retrieves Linux VM pricing from the public Azure Retail Prices API (no auth required).
        Returns PAYG, Spot, Savings Plan (1yr/3yr), and Reserved Instance (1yr/3yr) pricing maps.
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

    # Build filter for the API - get all VM pricing (consumption + reservation)
    $filter = "armRegionName eq '$armLocation' and serviceName eq 'Virtual Machines'"

    $regularPrices = @{}
    $spotPrices = @{}

    $savingsPlan1YrPrices = @{}
    $savingsPlan3YrPrices = @{}
    $reservation1YrPrices = @{}
    $reservation3YrPrices = @{}

    $apiUrl = "$($AzureEndpoints.PricingApiUrl)?api-version=2023-01-01-preview&`$filter=$([uri]::EscapeDataString($filter))"

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
                # Filter for Linux pricing, skip Windows, Low Priority, and DevTest
                if ($item.productName -match 'Windows' -or
                    $item.skuName -match 'Low Priority' -or
                    $item.meterName -match 'Low Priority' -or
                    $item.type -eq 'DevTestConsumption') {
                    continue
                }

                # Extract the VM size from armSkuName
                $vmSize = $item.armSkuName
                if (-not $vmSize) { continue }

                if ($item.type -eq 'Reservation') {
                    if ($item.reservationTerm -eq '1 Year' -and -not $reservation1YrPrices[$vmSize]) {
                        $reservation1YrPrices[$vmSize] = @{
                            Total    = [math]::Round($item.retailPrice, 2)
                            Monthly  = [math]::Round($item.retailPrice / 12, 2)
                            Currency = $item.currencyCode
                        }
                    }
                    elseif ($item.reservationTerm -eq '3 Years' -and -not $reservation3YrPrices[$vmSize]) {
                        $reservation3YrPrices[$vmSize] = @{
                            Total    = [math]::Round($item.retailPrice, 2)
                            Monthly  = [math]::Round($item.retailPrice / 36, 2)
                            Currency = $item.currencyCode
                        }
                    }
                    continue
                }

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

                # Capture savings plan pricing from consumption items
                if (-not $isSpot -and $item.savingsPlan) {
                    foreach ($sp in $item.savingsPlan) {
                        if ($sp.term -eq '1 Year' -and -not $savingsPlan1YrPrices[$vmSize]) {
                            $savingsPlan1YrPrices[$vmSize] = @{
                                Hourly   = [math]::Round($sp.retailPrice, 4)
                                Monthly  = [math]::Round($sp.retailPrice * $HoursPerMonth, 2)
                                Total    = [math]::Round($sp.retailPrice * 8760, 2)
                                Currency = $item.currencyCode
                            }
                        }
                        elseif ($sp.term -eq '3 Years' -and -not $savingsPlan3YrPrices[$vmSize]) {
                            $savingsPlan3YrPrices[$vmSize] = @{
                                Hourly   = [math]::Round($sp.retailPrice, 4)
                                Monthly  = [math]::Round($sp.retailPrice * $HoursPerMonth, 2)
                                Total    = [math]::Round($sp.retailPrice * 26280, 2)
                                Currency = $item.currencyCode
                            }
                        }
                    }
                }
            }

            $nextLink = $response.NextPageLink
        }

        $result = [ordered]@{
            Regular          = $regularPrices
            Spot             = $spotPrices
            SavingsPlan1Yr   = $savingsPlan1YrPrices
            SavingsPlan3Yr   = $savingsPlan3YrPrices
            Reservation1Yr   = $reservation1YrPrices
            Reservation3Yr   = $reservation3YrPrices
        }

        $Caches.Pricing[$armLocation] = $result

        return $result
    }
    catch {
        Write-Verbose "Failed to fetch pricing for region $Region`: $_"
        return [ordered]@{
            Regular          = @{}
            Spot             = @{}
            SavingsPlan1Yr   = @{}
            SavingsPlan3Yr   = @{}
            Reservation1Yr   = @{}
            Reservation3Yr   = @{}
        }
    }
}
