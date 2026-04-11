# Region Presets

[← Back to README](../README.md)

Use `-RegionPreset` for quick access to common region sets:

| Preset          | Regions                                                             | Use Case                                 |
| --------------- | ------------------------------------------------------------------- | ---------------------------------------- |
| `USEastWest`    | eastus, eastus2, westus, westus2                                    | US coastal regions                       |
| `USCentral`     | centralus, northcentralus, southcentralus, westcentralus            | US central regions                       |
| `USMajor`       | eastus, eastus2, centralus, westus, westus2                         | Top 5 US regions by usage                |
| `Europe`        | westeurope, northeurope, uksouth, francecentral, germanywestcentral | European regions                         |
| `AsiaPacific`   | eastasia, southeastasia, japaneast, australiaeast, koreacentral     | Asia-Pacific regions                     |
| `Global`        | eastus, westeurope, southeastasia, australiaeast, brazilsouth       | Global distribution                      |
| `USGov`         | usgovvirginia, usgovtexas, usgovarizona                             | Azure Government (auto-sets environment) |
| `China`         | chinaeast, chinanorth, chinaeast2, chinanorth2                      | Azure China / Mooncake (auto-sets env)   |
| `ASR-EastWest`  | eastus, westus2                                                     | Azure Site Recovery DR pair              |
| `ASR-CentralUS` | centralus, eastus2                                                  | Azure Site Recovery DR pair              |

> **Sovereign Clouds Note**:
> - `USGov` and `China` presets are **hardcoded** because `Get-AzLocation` only returns regions for the cloud you're logged into (commercial Azure won't show government regions)
> - `USGov` automatically sets `-Environment AzureUSGovernment` - you still need credentials for that environment
> - `China` automatically sets `-Environment AzureChinaCloud` (Mooncake) - you still need credentials for that environment
> - Azure Germany (AzureGermanCloud) was deprecated in October 2021 and is no longer available
> - There is no separate "European Government" cloud; EU data residency is handled via standard Azure regions with compliance certifications (e.g., France Central, Germany West Central)

## Examples

```powershell
# Quick US East/West scan
.\Get-AzVMAvailability.ps1 -RegionPreset USEastWest -NoPrompt

# Top 5 US regions
.\Get-AzVMAvailability.ps1 -RegionPreset USMajor -NoPrompt

# DR planning for Azure Site Recovery
.\Get-AzVMAvailability.ps1 -RegionPreset ASR-EastWest -FamilyFilter "D","E" -ShowPricing

# European regions with export
.\Get-AzVMAvailability.ps1 -RegionPreset Europe -AutoExport

# Azure Government (environment auto-detected)
.\Get-AzVMAvailability.ps1 -RegionPreset USGov -NoPrompt

# Azure China / Mooncake (environment auto-detected)
.\Get-AzVMAvailability.ps1 -RegionPreset China -NoPrompt
```

> **Note**: Maximum 5 regions per scan for optimal performance and readability. Presets are limited accordingly. Lifecycle modes (`-LifecycleRecommendations`, `-LifecycleScan`) are exempt — all deployed regions are scanned automatically.

## Manual Region Specification

You can still specify regions manually for custom scenarios:

| Scenario           | Region Parameter                         |
| ------------------ | ---------------------------------------- |
| **Custom regions** | `-Region "eastus","westus2","centralus"` |
| **Single region**  | `-Region "eastus"`                       |
