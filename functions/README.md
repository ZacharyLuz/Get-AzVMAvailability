# functions/

> **⚠️ As of v2.0.0, the authoritative implementations are in `AzVMAvailability/Private/`.** This folder contains legacy reference copies only and is no longer updated.

This folder contains one `.ps1` file per function extracted from `Get-AzVMAvailability.ps1` for **documentation and navigation purposes only**.

## Important Notes

- **Files are reference copies only** — they cannot be executed independently. Each function depends on shared state, helper functions, and variables defined in the full script context.
- **The authoritative source is `AzVMAvailability/Private/`** (module layout, v2.0.0+).
- These copies are updated manually; they may temporarily lag behind the main script.

## Function Index

| # | File | Start Line | Description |
|---|------|-----------|-------------|
| 1 | `Get-SafeString.ps1` | 640 | Sanitizes a string for safe use in output by trimming and escaping |
| 2 | `Invoke-WithRetry.ps1` | 659 | Exponential backoff wrapper for Azure API calls handling 429, 503, timeouts |
| 3 | `Get-GeoGroup.ps1` | 741 | Returns a geographic grouping label for an Azure region name |
| 4 | `Get-AzureEndpoints.ps1` | 759 | Returns the Azure API endpoints hashtable for the target cloud environment |
| 5 | `Get-CapValue.ps1` | 875 | Extracts a named capability value from a VM SKU capabilities array |
| 6 | `Get-SkuFamily.ps1` | 882 | Parses the VM family prefix letter(s) from a Standard_Xnn_vN SKU name |
| 7 | `Get-ProcessorVendor.ps1` | 890 | Returns the CPU vendor (Intel/AMD/Ampere) from SKU capabilities |
| 8 | `Get-DiskCode.ps1` | 901 | Returns the disk type code (P/E/S) from a VM SKU name |
| 9 | `Get-ValidAzureRegions.ps1` | 912 | Retrieves and caches the list of valid Azure regions for the subscription |
| 10 | `Get-RestrictionReason.ps1` | 1009 | Returns a human-readable reason code for a SKU restriction |
| 11 | `Get-RestrictionDetails.ps1` | 1017 | Parses restriction details from a VM SKU and returns zone/region status |
| 12 | `Format-ZoneStatus.ps1` | 1090 | Formats zone availability status into a compact display string |
| 13 | `Format-RegionList.ps1` | 1100 | Formats a list of Azure regions into a display-friendly string |
| 14 | `Get-QuotaAvailable.ps1` | 1141 | Returns available quota for a VM family in a given region |
| 15 | `Get-FleetReadiness.ps1` | 1154 | Evaluates fleet BOM readiness across regions checking quota and SKU availability |
| 16 | `Write-FleetReadinessSummary.ps1` | 1296 | Writes the fleet readiness summary table to the console |
| 17 | `Get-StatusIcon.ps1` | 1370 | Returns a Unicode or ASCII status icon character for a given status |
| 18 | `Use-SubscriptionContextSafely.ps1` | 1386 | Switches to a target subscription and saves the original context |
| 19 | `Restore-OriginalSubscriptionContext.ps1` | 1398 | Restores the original subscription context saved before scanning |
| 20 | `Test-ImportExcelModule.ps1` | 1421 | Tests whether the ImportExcel module is available and importable |
| 21 | `Test-SkuMatchesFilter.ps1` | 1436 | Tests whether a VM SKU matches the active family/SKU filter criteria |
| 22 | `Get-SkuSimilarityScore.ps1` | 1461 | Computes a 0–100 similarity score between two VM SKUs for recommendations |
| 23 | `New-RecommendOutputContract.ps1` | 1533 | Creates a structured output contract object for recommendation results |
| 24 | `Write-RecommendOutputContract.ps1` | 1606 | Renders the recommendation output contract to the console or JSON |
| 25 | `New-ScanOutputContract.ps1` | 1792 | Creates a structured output contract object for scan results |
| 26 | `Invoke-RecommendMode.ps1` | 1845 | Runs the SKU recommendation engine to find alternatives for a target VM |
| 27 | `Get-ImageRequirements.ps1` | 2147 | Returns VM image requirements (generation, accelerated networking, etc.) for an image URN |
| 28 | `Get-SkuCapabilities.ps1` | 2199 | Extracts and returns a structured capabilities object for a VM SKU |
| 29 | `Test-ImageSkuCompatibility.ps1` | 2243 | Tests whether a VM SKU is compatible with the specified image requirements |
| 30 | `Get-AzVMPricing.ps1` | 2299 | Retrieves VM pricing from the Azure Retail Prices API |
| 31 | `Get-RegularPricingMap.ps1` | 2404 | Builds a region→SKU→price hashtable for regular (pay-as-you-go) pricing |
| 32 | `Get-SpotPricingMap.ps1` | 2425 | Builds a region→SKU→price hashtable for Spot VM pricing |
| 33 | `Get-PlacementScores.ps1` | 2446 | Retrieves VM placement likelihood scores from the Azure placement API |
| 34 | `Get-AzActualPricing.ps1` | 2547 | Retrieves actual/negotiated pricing via the Azure Cost Management API |
