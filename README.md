# Get-AzVMAvailability

A PowerShell tool for checking Azure VM SKU availability across regions - find where your VMs can deploy.

![PowerShell](https://img.shields.io/badge/PowerShell-7.0%2B-blue)
![Azure](https://img.shields.io/badge/Azure-Az%20Modules-0078D4)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-1.4.0-brightgreen)

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

### Check Specific Regions
```powershell
.\Get-AzVMAvailability.ps1 -Region "eastus","westus2","centralus"
```

### Check GPU SKU Availability
```powershell
.\Get-AzVMAvailability.ps1 -Region "eastus","eastus2","southcentralus" -FamilyFilter "NC","ND","NV"
```

### Export to Specific Location
```powershell
.\Get-AzVMAvailability.ps1 -ExportPath "C:\Reports" -AutoExport -OutputFormat XLSX
```

### Check Specific SKUs with Pricing
```powershell
# Check specific SKUs with pricing information
.\Get-AzVMAvailability.ps1 -Region "eastus","westus2" -SkuFilter "Standard_D*_v5" -ShowPricing

# Use actual negotiated pricing (requires billing permissions)
.\Get-AzVMAvailability.ps1 -Region "eastus" -ShowPricing -UseActualPricing
```

### Full Parameter Example
```powershell
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

| Parameter           | Type     | Description                                                              |
| ------------------- | -------- | ------------------------------------------------------------------------ |
| `-SubscriptionId`   | String[] | Azure subscription ID(s) to scan                                         |
| `-Region`           | String[] | Azure region code(s) (e.g., 'eastus', 'westus2')                         |
| `-ExportPath`       | String   | Directory for export files                                               |
| `-AutoExport`       | Switch   | Export without prompting                                                 |
| `-EnableDrillDown`  | Switch   | Interactive family/SKU exploration                                       |
| `-FamilyFilter`     | String[] | Filter to specific VM families                                           |
| `-SkuFilter`        | String[] | Filter to specific SKUs (supports wildcards)                             |
| `-ShowPricing`      | Switch   | Include hourly/monthly pricing columns                                   |
| `-UseActualPricing` | Switch   | Use Cost Management API for negotiated rates                             |
| `-ImageURN`         | String   | Check SKU compatibility with image (format: Publisher:Offer:Sku:Version) |
| `-CompactOutput`    | Switch   | Use compact output for narrow terminals                                  |
| `-NoPrompt`         | Switch   | Skip interactive prompts                                                 |
| `-OutputFormat`     | String   | 'Auto', 'CSV', or 'XLSX'                                                 |
| `-UseAsciiIcons`    | Switch   | Force ASCII instead of Unicode icons                                     |

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

### Pricing Options

**Retail Pricing (Default with `-ShowPricing`):**
- Uses the public Azure Retail Prices API
- No authentication required
- Shows Linux pay-as-you-go rates
- Does NOT include EA/MCA/Reserved discounts

**Actual Pricing (`-UseActualPricing`):**
- Uses Azure Cost Management API
- Requires Billing Reader or Cost Management Reader role
- Shows your negotiated rates (EA, MCA, or CSP discounts applied)
- Falls back to retail pricing if access is denied

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

**Zachary Luz**
Microsoft

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.
