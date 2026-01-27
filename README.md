# Azure VM Capacity Checker

A comprehensive PowerShell tool for checking Azure VM SKU availability, capacity status, and quota information across regions.

![PowerShell](https://img.shields.io/badge/PowerShell-7.0%2B-blue)
![Azure](https://img.shields.io/badge/Azure-Az%20Modules-0078D4)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-1.3.0-brightgreen)

## Overview

Azure VM Capacity Checker helps you identify which Azure regions have available capacity for your VM deployments. It scans multiple regions in parallel and provides detailed insights into SKU availability, zone restrictions, and quota limits.

## Why This Tool Matters

### The Problem

When deploying VMs in Azure, you've likely encountered these frustrating scenarios:

- **"The requested VM size is not available"** - You've configured your deployment, hit deploy, and... failed. The SKU you need isn't available in your chosen region.
- **Capacity constraints during critical moments** - Production is down, you need to scale, but your preferred region is at capacity.
- **Time-consuming manual checks** - Checking SKU availability through the Azure Portal means clicking through multiple regions one at a time.
- **Zone-specific restrictions** - A SKU might be available in a region but restricted in specific availability zones.
- **Quota surprises** - You have the SKU available, but your subscription quota won't allow the deployment.

### The Solution

This tool gives you **instant visibility** across multiple regions simultaneously:

| Before                              | After                                   |
| ----------------------------------- | --------------------------------------- |
| Check regions one-by-one in Portal  | Scan 10+ regions in seconds             |
| Deploy and hope it works            | Know capacity status before you start   |
| Guess which region has availability | See a color-coded matrix of all options |
| Manually track quota limits         | Quota info included automatically       |
| No historical record                | Export to Excel for documentation       |

### ⚡ Lightning Fast: Portal vs. Script Comparison

| Task                   | Azure Portal            | This Script | Time Saved   |
| ---------------------- | ----------------------- | ----------- | ------------ |
| Check 1 region         | ~30 seconds             | ~2 seconds  | **93%**      |
| Check 3 regions        | ~90 seconds             | ~5 seconds  | **94%**      |
| Check 10 regions       | ~5 minutes              | ~15 seconds | **95%**      |
| Get quota info         | Extra clicks per region | Automatic   | **100%**     |
| View zone availability | Multiple pages          | Single view | **Huge**     |
| Export results         | Manual copy/paste       | One command | **Instant**  |
| Check pricing          | Separate calculator     | Integrated  | **Seamless** |

**Why the Portal is Slow:**
1. Navigate to Virtual Machines → Create
2. Select region → Wait for SKU list to load (~5 sec)
3. Click through each size category
4. Check availability zones (separate dropdown)
5. Check quota (separate blade)
6. Repeat for every region

**Why This Script is Fast:**
- Uses `ForEach-Object -Parallel` to query multiple regions simultaneously
- Single API call per region for all SKU data
- Pre-fetches quota in parallel
- Caches pricing data to avoid redundant calls

```
Scanning 3 regions...
========================================================================
AZURE VM CAPACITY CHECKER v1.3.0
========================================================================
Subscriptions: 1 | Regions: eastus, eastus2, centralus
Icons: Unicode | Pricing: Enabled

Fetching retail pricing data...
Pricing data loaded for 3 region(s)
[Production-Sub] Scanning 3 region(s)... ✓ Done in 4.8 seconds
```

### Real-World Use Cases

- **Disaster Recovery Planning** - Identify backup regions with capacity for your VM families
- **Multi-Region Deployments** - Find regions where all your required SKUs are available
- **GPU/HPC Workloads** - NC, ND, and NV series are often constrained; find where they're available
- **Capacity Planning** - Document current availability for change management
- **Troubleshooting Deployments** - Quickly identify why a deployment might be failing

### 🚫 What the Portal Can't Do

The Azure Portal has no equivalent for these capabilities:

| Capability | Portal | This Script |
|------------|--------|-------------|
| **Compare pricing across regions** | ❌ Open pricing calculator separately | ✅ Side-by-side with availability |
| **Filter to specific SKUs** | ❌ Scroll through hundreds of sizes | ✅ `Standard_D*_v5` wildcard filtering |
| **See all zones at once** | ❌ Click each zone dropdown | ✅ `✓ Zones 1,2 \| ⚠ Zone 3` single view |
| **Multi-region matrix view** | ❌ Switch regions one at a time | ✅ All regions in one table |
| **Export with conditional formatting** | ❌ Manual screenshots | ✅ Color-coded Excel export |
| **See your negotiated pricing** | ❌ Check Cost Management separately | ✅ `-UseActualPricing` shows EA/MCA rates |
| **Combine quota + availability** | ❌ Different blades | ✅ Unified view per region |

## Features

- **Multi-Region Parallel Scanning** - Scan 3+ regions in ~5 seconds
- **Comprehensive SKU Analysis** - All VM families automatically discovered
- **SKU Filtering** - Filter output to specific SKUs with wildcard support (v1.2.0)
- **Pricing Information** - Show hourly and monthly pricing for SKUs (v1.3.0)
  - Retail pricing from Azure Retail Prices API (no auth required)
  - Actual negotiated pricing via Cost Management API (EA/MCA/CSP, requires billing permissions)
- **Capacity Status Reporting** - OK, LIMITED, CAPACITY-CONSTRAINED, RESTRICTED states
- **Zone Availability Details** - Per-zone availability information
- **Quota Tracking** - Available vCPU quota per family
- **Multi-Region Matrix** - Color-coded comparison view
- **Interactive Drill-Down** - Explore specific families and SKUs
- **Export Options** - CSV and styled XLSX with conditional formatting
- **Terminal Auto-Detection** - Unicode or ASCII icons based on capability

## Requirements

- **PowerShell 7.0+** (required for parallel execution)
- **Azure PowerShell Modules**:
  - `Az.Compute`
  - `Az.Resources`
- **Optional**: `ImportExcel` module for styled XLSX export

## Installation

```powershell
# Clone the repository
git clone https://github.com/zacharyluz/Azure-VM-Capacity-Checker.git
cd Azure-VM-Capacity-Checker

# Install required Azure modules (if needed)
Install-Module -Name Az.Compute -Scope CurrentUser
Install-Module -Name Az.Resources -Scope CurrentUser

# Optional: Install ImportExcel for styled exports
Install-Module -Name ImportExcel -Scope CurrentUser
```

## Quick Start

```powershell
# Interactive mode - prompts for all options
.\Azure-VM-Capacity-Checker.ps1

# Automated mode - uses current subscription
.\Azure-VM-Capacity-Checker.ps1 -NoPrompt -Region "eastus","westus2"

# With auto-export
.\Azure-VM-Capacity-Checker.ps1 -Region "eastus","eastus2" -AutoExport
```

## Usage Examples

### Check Specific Regions
```powershell
.\Azure-VM-Capacity-Checker.ps1 -Region "eastus","westus2","centralus"
```

### Check GPU SKU Availability
```powershell
.\Azure-VM-Capacity-Checker.ps1 -Region "eastus","eastus2","southcentralus" -FamilyFilter "NC","ND","NV"
```

### Export to Specific Location
```powershell
.\Azure-VM-Capacity-Checker.ps1 -ExportPath "C:\Reports" -AutoExport -OutputFormat XLSX
```

### Check Specific SKUs with Pricing
```powershell
# Check specific SKUs with pricing information
.\Azure-VM-Capacity-Checker.ps1 -Region "eastus","westus2" -SkuFilter "Standard_D*_v5" -ShowPricing

# Use actual negotiated pricing (requires billing permissions)
.\Azure-VM-Capacity-Checker.ps1 -Region "eastus" -ShowPricing -UseActualPricing
```

### Full Parameter Example
```powershell
.\Azure-VM-Capacity-Checker.ps1 `
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

| Parameter           | Type     | Description                                      |
| ------------------- | -------- | ------------------------------------------------ |
| `-SubscriptionId`   | String[] | Azure subscription ID(s) to scan                 |
| `-Region`           | String[] | Azure region code(s) (e.g., 'eastus', 'westus2') |
| `-ExportPath`       | String   | Directory for export files                       |
| `-AutoExport`       | Switch   | Export without prompting                         |
| `-EnableDrillDown`  | Switch   | Interactive family/SKU exploration               |
| `-FamilyFilter`     | String[] | Filter to specific VM families                   |
| `-SkuFilter`        | String[] | Filter to specific SKUs (supports wildcards)     |
| `-ShowPricing`      | Switch   | Include hourly/monthly pricing columns           |
| `-UseActualPricing` | Switch   | Use Cost Management API for negotiated rates     |
| `-NoPrompt`         | Switch   | Skip interactive prompts                         |
| `-OutputFormat`     | String   | 'Auto', 'CSV', or 'XLSX'                         |
| `-UseAsciiIcons`    | Switch   | Force ASCII instead of Unicode icons             |

## Output

### Console Output (with Pricing)
```
====================================================================================
AZURE VM CAPACITY CHECKER v1.3.0
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
- **v1.1**: Azure Resource Graph integration for VM inventory
- **v1.2**: HTML reports and trend tracking
- **v2.0**: Proactive monitoring and Azure Function deployment

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

## Author

**Zachary Luz**
Microsoft

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.
