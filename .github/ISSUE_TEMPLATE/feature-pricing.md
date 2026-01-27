---
name: 'Feature: Pricing Information'
about: Display VM pricing next to SKU information
title: '[FEATURE] Add pricing information for SKUs'
labels: enhancement, v1.2.0
assignees: ''
---

## Feature Description

Display hourly and monthly pricing for each VM SKU next to capacity information to help users make cost-informed decisions.

## Background

**Requested by:** Omar
**Use Case:** When selecting VMs, cost is a critical factor. Users want to see pricing alongside capacity to make informed decisions without switching to Azure Pricing Calculator.

## Proposed Solution

### New Parameters
```powershell
-ShowPricing           # Include pricing in output
-PricingType <string>  # 'Linux' (default), 'Windows', 'Both'
-Currency <string>     # 'USD' (default), 'EUR', 'GBP', etc.
```

**Examples:**
```powershell
# Show Linux pricing (default)
.\Azure-VM-Capacity-Checker.ps1 -ShowPricing -Region "eastus","westus2"

# Show Windows pricing
.\Azure-VM-Capacity-Checker.ps1 -ShowPricing -PricingType Windows

# Show both Linux and Windows pricing
.\Azure-VM-Capacity-Checker.ps1 -ShowPricing -PricingType Both
```

### Output Format

**Console table:**
```
Family  SKUs  Avail  Largest           Price/Hr   Price/Mo   Status
------  ----  -----  ----------------  ---------  ---------  ------
D       12    12     8vCPU/32GB        $0.385     $281.05    ✓ OK
E       15    15     16vCPU/128GB      $0.756     $551.88    ✓ OK
```

**Excel export:**
- Add columns: `PricePerHour_Linux`, `PricePerMonth_Linux`, `PricePerHour_Windows`, `PricePerMonth_Windows`
- Format as currency with 2 decimals
- Conditional formatting: highlight expensive SKUs (>$1/hr) in orange

### Technical Implementation

#### Azure Retail Prices API
```powershell
function Get-AzVMPricing {
    param([string]$Region, [string]$SkuName, [string]$OS = 'Linux')

    $baseUrl = "https://prices.azure.com/api/retail/prices"
    $filter = "serviceName eq 'Virtual Machines' and armRegionName eq '$Region' and armSkuName eq '$SkuName' and priceType eq 'Consumption'"

    if ($OS -eq 'Linux') {
        $filter += " and productName contains 'Linux'"
    } elseif ($OS -eq 'Windows') {
        $filter += " and productName contains 'Windows'"
    }

    $response = Invoke-RestMethod -Uri "$baseUrl?`$filter=$filter" -Method Get
    return $response.Items[0].retailPrice  # Price per hour
}
```

#### Caching Strategy
- Cache pricing data in memory per session (prices don't change frequently)
- Cache file: `~/.azure-vm-capacity-checker/pricing-cache.json`
- Cache expiry: 24 hours
- Manual refresh with `-RefreshPricingCache`

### Performance Considerations
- Pricing API calls add ~100-200ms per SKU
- For 50 SKUs: ~5-10 seconds additional time
- Run pricing queries in parallel (throttle limit: 10)
- Display progress: "Fetching pricing for 50 SKUs..."

## Acceptance Criteria
- [ ] `-ShowPricing` parameter implemented
- [ ] Support for Linux, Windows, and Both pricing
- [ ] Price displayed in console output (per hour and per month)
- [ ] Price columns in Excel export with currency formatting
- [ ] Caching mechanism to avoid repeated API calls
- [ ] Graceful error handling if pricing API fails
- [ ] `-Currency` parameter for international users
- [ ] Documentation updated with examples

## Optional Enhancements
- [ ] Spot pricing comparison
- [ ] Savings plan / Reserved Instance pricing
- [ ] Cost comparison chart in Excel
- [ ] "Best value" indicator (lowest price for required specs)

## Related Issues
- #[TBD] - Add SKU filtering (v1.2.0)

## References
- [Azure Retail Prices API](https://learn.microsoft.com/en-us/rest/api/cost-management/retail-prices/azure-retail-prices)
- [Azure VM Pricing Page](https://azure.microsoft.com/en-us/pricing/details/virtual-machines/linux/)
