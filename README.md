# Get-AzVMAvailability

A PowerShell tool for checking Azure VM SKU availability across regions - find where your VMs can deploy.

![PowerShell](https://img.shields.io/badge/PowerShell-7.0%2B-blue)
![Azure](https://img.shields.io/badge/Azure-Az%20Modules-0078D4)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-1.8.0-brightgreen)

## Disclosure & Disclaimer

The author is a Microsoft employee; however, this is a **personal open-source project**. It is **not** an official Microsoft product, nor is it endorsed, sponsored, or supported by Microsoft.

- **No warranty**: Provided "as-is" under the [MIT License](LICENSE).
- **No official support**: For Azure platform issues, use [Azure Support](https://azure.microsoft.com/support/).
- **No confidential information**: This tool uses only publicly documented Azure APIs. Please do not share internal or confidential information in issues, pull requests, or discussions.
- **Trademarks**: "Microsoft" and "Azure" are trademarks of Microsoft Corporation. Their use here is for identification only and does not imply endorsement.

## Overview

Get-AzVMAvailability helps you identify which Azure regions have available capacity for your VM deployments. It scans multiple regions in parallel and provides detailed insights into SKU availability, zone restrictions, quota limits, pricing, and image compatibility.

## Features

- **Multi-Region Parallel Scanning** - Scan 10+ regions in ~15 seconds
- **SKU Filtering** - Filter to specific SKUs with wildcard support (e.g., `Standard_D*_v5`)
- **Pricing Information** - Show hourly/monthly pricing (retail or negotiated EA/MCA rates)
- **Image Compatibility** - Verify Gen1/Gen2 and x64/ARM64 requirements
- **Zone Availability** - Per-zone availability details
- **Quota Tracking** - Available vCPU quota per family
- **Multi-Region Matrix** - Color-coded comparison view
- **Interactive Drill-Down** - Explore specific families and SKUs
- **Export Options** - CSV and styled XLSX with conditional formatting

## Quick Comparison

| Task                           | Azure Portal            | This Script          |
| ------------------------------ | ----------------------- | -------------------- |
| Check 10 regions               | ~5 minutes              | ~15 seconds          |
| Get quota + availability       | Multiple blades         | Single view          |
| Compare pricing across regions | Separate calculator     | Integrated           |
| Filter to specific SKUs        | Scroll through hundreds | Wildcard filtering   |
| Check image compatibility      | Manual research         | Automated validation |
| Export results                 | Manual copy/paste       | One command          |

## Use Cases

- **Disaster Recovery Planning** - Identify backup regions with capacity
- **Multi-Region Deployments** - Find regions where all required SKUs are available
- **GPU/HPC Workloads** - NC, ND, NV series are often constrained; find where they're available
- **Image Compatibility** - Verify SKUs support your Gen2 or ARM64 images before deployment
- **Troubleshooting Deployments** - Quickly identify why a deployment might be failing

## Requirements

- **PowerShell 7.0+** (required for parallel execution)
- **Azure PowerShell Modules**: `Az.Compute`, `Az.Resources`
- **Optional**: `ImportExcel` module for styled XLSX export

## Supported Cloud Environments

The script automatically detects your Azure environment and uses the correct API endpoints:

| Cloud            | Environment Name    | Supported |
| ---------------- | ------------------- | --------- |
| Azure Commercial | `AzureCloud`        | ✅         |
| Azure Government | `AzureUSGovernment` | ✅         |
| Azure China      | `AzureChinaCloud`   | ✅         |
| Azure Germany    | `AzureGermanCloud`  | ✅         |

**No configuration required** - the script reads your current `Az` context and resolves endpoints automatically.

## Installation

```powershell
# Clone the repository
git clone https://github.com/zacharyluz/Get-AzVMAvailability.git
cd Get-AzVMAvailability

# Install required Azure modules (if needed)
Install-Module -Name Az.Compute -Scope CurrentUser
Install-Module -Name Az.Resources -Scope CurrentUser

# Optional: Install ImportExcel for styled exports
Install-Module -Name ImportExcel -Scope CurrentUser
```

## Quick Start

```powershell
# Interactive mode - prompts for all options
.\Get-AzVMAvailability.ps1

# Automated mode - uses current subscription
.\Get-AzVMAvailability.ps1 -NoPrompt -Region "eastus","westus2"

# With auto-export
.\Get-AzVMAvailability.ps1 -Region "eastus","eastus2" -AutoExport
```

## Usage Examples

> **💡 Tip**: When copying multi-line commands, ensure backticks (`` ` ``) at the end of each line are preserved. If copying from GitHub, use the "Copy" button in code blocks.

### Check Specific Regions
```powershell
.\Get-AzVMAvailability.ps1 -Region "eastus","westus2","centralus"
```

### Check GPU SKU Availability
```powershell
# Multi-line with backticks for readability
.\Get-AzVMAvailability.ps1 `
    -Region "eastus","eastus2","southcentralus" `
    -FamilyFilter "NC","ND","NV"
```

### Export to Specific Location
```powershell
.\Get-AzVMAvailability.ps1 `
    -ExportPath "C:\Reports" `
    -AutoExport `
    -OutputFormat XLSX
```

### Check Specific SKUs with Pricing
```powershell
# Pricing auto-detects negotiated rates (EA/MCA/CSP), falls back to retail
.\Get-AzVMAvailability.ps1 `
    -Region "eastus","westus2" `
    -SkuFilter "Standard_D*_v5" `
    -ShowPricing
```

### Full Parameter Example
```powershell
# Multi-line format with backticks for readability
.\Get-AzVMAvailability.ps1 `
    -SubscriptionId "your-subscription-id" `
    -Region "eastus","westus2","centralus" `
    -ExportPath "C:\Reports" `
    -AutoExport `
    -EnableDrillDown `
    -FamilyFilter "D","E","M" `
    -OutputFormat "XLSX" `
    -UseAsciiIcons
```

## Parameters

| Parameter          | Type     | Description                                                                                                   |
| ------------------ | -------- | ------------------------------------------------------------------------------------------------------------- |
| `-SubscriptionId`  | String[] | Azure subscription ID(s) to scan                                                                              |
| `-Region`          | String[] | Azure region code(s) (e.g., 'eastus', 'westus2')                                                              |
| `-RegionPreset`    | String   | Predefined region set (see table below). Auto-sets environment for sovereign clouds.                          |
| `-Environment`     | String   | Azure cloud (default: auto-detect). Options: AzureCloud, AzureUSGovernment, AzureChinaCloud, AzureGermanCloud |
| `-ExportPath`      | String   | Directory for export files                                                                                    |
| `-AutoExport`      | Switch   | Export without prompting                                                                                      |
| `-EnableDrillDown` | Switch   | Interactive family/SKU exploration                                                                            |
| `-FamilyFilter`    | String[] | Filter to specific VM families                                                                                |
| `-SkuFilter`       | String[] | Filter to specific SKUs (supports wildcards)                                                                  |
| `-ShowPricing`     | Switch   | Show pricing (auto-detects negotiated EA/MCA/CSP rates, falls back to retail)                                 |
| `-ImageURN`        | String   | Check SKU compatibility with image (format: Publisher:Offer:Sku:Version)                                      |
| `-CompactOutput`   | Switch   | Use compact output for narrow terminals                                                                       |
| `-NoPrompt`        | Switch   | Skip interactive prompts                                                                                      |
| `-OutputFormat`    | String   | 'Auto', 'CSV', or 'XLSX'                                                                                      |
| `-UseAsciiIcons`   | Switch   | Force ASCII instead of Unicode icons                                                                          |
| `-Recommend`       | String   | Find alternatives for a target SKU (e.g., 'Standard_E64pds_v6' or just 'E64pds_v6')                          |
| `-TopN`            | Int      | Number of alternatives to return in Recommend mode (default 5, max 25)                                        |
| `-JsonOutput`      | Switch   | Emit structured JSON for the [AzVMAvailability-Agent](https://github.com/ZacharyLuz/AzVMAvailability-Agent) or automation |

## Region Presets

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

### Examples

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

> **Note**: Maximum 5 regions per scan for optimal performance and readability. Presets are limited accordingly.

### Manual Region Specification

You can still specify regions manually for custom scenarios:

| Scenario           | Region Parameter                         |
| ------------------ | ---------------------------------------- |
| **Custom regions** | `-Region "eastus","westus2","centralus"` |
| **Single region**  | `-Region "eastus"`                       |

## Image Compatibility Checking

The script can verify which VM SKUs are compatible with specific Azure Marketplace images, checking Generation (Gen1/Gen2) and Architecture (x64/ARM64) requirements.

### Option 1: Interactive Search (Recommended for Discovery)

Run the script **without** `-NoPrompt` and **without** `-ImageURN`:

```powershell
.\Get-AzVMAvailability.ps1 -Region eastus -EnableDrillDown
```

When prompted **"Check SKU compatibility with a specific VM image?"**, answer `y`, then you'll see options:

```
Select image (1-16, custom, search, or Enter to skip): search
```

Type **`search`** and enter keywords like:
- `ubuntu` - finds Ubuntu images
- `dsvm` or `data science` - finds Data Science VMs
- `windows` - finds Windows Server images
- `rhel` - finds Red Hat images
- `mariner` - finds Azure Linux (CBL-Mariner)

The script queries Azure Marketplace and shows matching publishers/offers, then lets you drill down to pick a specific SKU.

### Option 2: Common Images Quick-Pick

The interactive prompt shows **16 pre-defined common images** organized by category:

| Category     | Images                                             |
| ------------ | -------------------------------------------------- |
| Linux        | Ubuntu 22.04/24.04, RHEL 9, Debian 12, Azure Linux |
| Windows      | Server 2022, Server 2019, Windows 11               |
| Data Science | DSVM Ubuntu/Windows, Azure ML Workstation          |
| HPC          | Ubuntu HPC, AlmaLinux HPC                          |
| Gen1 Legacy  | Ubuntu 22.04 Gen1, Windows Server 2022 Gen1        |

Just type `1-16` to pick one directly, or type `custom` to enter a full URN manually.

### Option 3: Direct URN Parameter

If you already know the image URN, pass it directly:

```powershell
# Check ARM64 compatibility for Ubuntu ARM64 image
.\Get-AzVMAvailability.ps1 `
    -Region "eastus","westus2" `
    -ImageURN "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-arm64:latest" `
    -SkuFilter "Standard_D*ps*"

# Check Gen2 compatibility for Windows Server 2022
.\Get-AzVMAvailability.ps1 `
    -Region "eastus" `
    -ImageURN "MicrosoftWindowsServer:WindowsServer:2022-datacenter-g2:latest" `
    -EnableDrillDown
```

### Option 4: Combine with SKU Wildcards

Use `-SkuFilter` with wildcards to find specific VM types compatible with your image:

```powershell
# Find all ARM64-compatible D-series SKUs for ARM64 Ubuntu
.\Get-AzVMAvailability.ps1 `
    -Region "eastus" `
    -SkuFilter "Standard_D*ps*" `
    -ImageURN "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-arm64:latest"
```

### Interactive Search Flow Example

```
Check SKU compatibility with a specific VM image? (y/N): y

COMMON VM IMAGES:
-------------------------------------------------------------------------------------
#    Image Name                               Gen    Arch    Category
-------------------------------------------------------------------------------------
1    Ubuntu 22.04 LTS (Gen2)                  Gen2   x64     Linux
2    Ubuntu 24.04 LTS (Gen2)                  Gen2   x64     Linux
3    Ubuntu 22.04 ARM64                       Gen2   ARM64   Linux
...
16   Windows Server 2022 (Gen1)               Gen1   x64     Gen1
-------------------------------------------------------------------------------------
Or type: 'custom' for manual URN | 'search' to browse Azure Marketplace | Enter to skip

Select image (1-16, custom, search, or Enter to skip): search

Enter search term (e.g., 'ubuntu', 'data science', 'windows', 'dsvm'): data science
Searching Azure Marketplace...

Results matching 'data science':
   1. [Offer    ] microsoft-dsvm > ubuntu-2204
   2. [Offer    ] microsoft-dsvm > dsvm-win-2022

Select (1-2) or Enter to skip: 1
...
Selected: microsoft-dsvm:ubuntu-2204:2204-gen2:latest
```

### Image Compatibility Output

When an image is specified, the drill-down view shows additional columns:

| Column | Description                                       |
| ------ | ------------------------------------------------- |
| Gen    | SKU's supported generations (1, 2, or 1,2)        |
| Arch   | SKU's CPU architecture (x64 or Arm64)             |
| Img    | Compatibility: ✓ (compatible) or ✗ (incompatible) |

SKUs that are available but **incompatible** with your image are shown in dark yellow to help you quickly identify the issue.

## Output

### Console Output (with Pricing)
```
====================================================================================
GET-AZVMAVAILABILITY v1.4.0
====================================================================================
SKU Filter: Standard_D2s_v5 | Pricing: Enabled

REGION: eastus
====================================================================================

SKU FAMILIES:
Family    SKUs  OK   Largest       Zones            Status     Quota   $/Hr    $/Mo
------------------------------------------------------------------------------------
D         1     0    2vCPU/8GB     ⚠ Zones 1,2,3   LIMITED    100     $0.10   $70

====================================================================================
MULTI-REGION CAPACITY MATRIX
====================================================================================

Family     | eastus          | eastus2
------------------------------------------------------------------------------------
D          | ⚠ LIMITED       | ✓ OK
```

### Pricing (Auto-Detection)

With `-ShowPricing`, the script automatically detects the best pricing source:

1. **First, tries negotiated pricing** (EA/MCA/CSP)
   - Uses Azure Cost Management API
   - Requires Billing Reader or Cost Management Reader role
   - Shows your actual discounted rates

2. **Falls back to retail pricing** if negotiated rates unavailable
   - Uses the public Azure Retail Prices API
   - No special permissions required
   - Shows Linux pay-as-you-go rates

> **Note**: You'll see which pricing source is being used in the console output.

### Excel Export
- Color-coded status cells (green/yellow/red)
- Filterable columns with auto-filter
- Alternating row colors
- Azure-blue header styling

## Status Legend

| Icon | Status               | Description                    |
| ---- | -------------------- | ------------------------------ |
| ✓    | OK                   | Full capacity available        |
| ⚠    | CAPACITY-CONSTRAINED | Limited in some zones          |
| ⚠    | LIMITED              | Subscription-level restriction |
| ⚡    | PARTIAL              | Mixed zone availability        |
| ✗    | RESTRICTED           | Not available                  |

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Roadmap

See [ROADMAP.md](ROADMAP.md) for planned features including:
- Azure Resource Graph integration for VM inventory
- HTML reports and trend tracking
- PowerShell module for PSGallery distribution

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

## Author

**Zachary Luz** — Personal project (not an official Microsoft product)

## Support & Responsible Use

This tool queries only **public Azure APIs** (SKU availability, quota, retail pricing) against your own Azure subscriptions. It reads subscription metadata (such as subscription IDs/names, regions, quotas, and usage) and writes results locally (console output and CSV/XLSX exports); it does **not** transmit this data off your machine except as required to call Azure APIs.

- **Issues & PRs**: Welcome! Please do not include subscription IDs, tenant IDs, internal URLs, or any confidential information.
- **Azure support**: For Azure platform issues or outages, contact [Azure Support](https://azure.microsoft.com/support/) — not this repository.
- **Exported files**: Review CSV/XLSX exports before sharing externally — they may contain subscription IDs, region information, quotas, and usage details for your environment.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

