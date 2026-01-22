# Azure VM Capacity Checker

A comprehensive PowerShell tool for checking Azure VM SKU availability, capacity status, and quota information across regions.

![PowerShell](https://img.shields.io/badge/PowerShell-7.0%2B-blue)
![Azure](https://img.shields.io/badge/Azure-Az%20Modules-0078D4)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-1.0.0-brightgreen)

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

### ⚡ Lightning Fast

Traditional approaches to checking VM availability are painfully slow:

- **Azure Portal**: ~30 seconds per region (click, wait, scroll, repeat)
- **Azure CLI/PowerShell sequential**: ~10 seconds per region
- **This tool**: **~5 seconds for 3 regions** (parallel execution)

How? The script uses PowerShell 7's `ForEach-Object -Parallel` to query multiple regions simultaneously. What would take **5+ minutes** checking 10 regions manually takes **under 15 seconds** with this tool.

```
Scanning 3 regions...
======================================================================
AZURE VM CAPACITY CHECKER v1.0.0
======================================================================
Subscriptions: 1 | Regions: eastus, eastus2, centralus
[Production-Sub] Scanning 3 region(s)... ✓ Done in 4.8 seconds
```

### Real-World Use Cases

- **Disaster Recovery Planning** - Identify backup regions with capacity for your VM families
- **Multi-Region Deployments** - Find regions where all your required SKUs are available
- **GPU/HPC Workloads** - NC, ND, and NV series are often constrained; find where they're available
- **Capacity Planning** - Document current availability for change management
- **Troubleshooting Deployments** - Quickly identify why a deployment might be failing

## Features

- **Multi-Region Parallel Scanning** - Scan 3+ regions in ~5 seconds
- **Comprehensive SKU Analysis** - All VM families automatically discovered
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

| Parameter          | Type     | Description                                      |
| ------------------ | -------- | ------------------------------------------------ |
| `-SubscriptionId`  | String[] | Azure subscription ID(s) to scan                 |
| `-Region`          | String[] | Azure region code(s) (e.g., 'eastus', 'westus2') |
| `-ExportPath`      | String   | Directory for export files                       |
| `-AutoExport`      | Switch   | Export without prompting                         |
| `-EnableDrillDown` | Switch   | Interactive family/SKU exploration               |
| `-FamilyFilter`    | String[] | Filter to specific VM families                   |
| `-NoPrompt`        | Switch   | Skip interactive prompts                         |
| `-OutputFormat`    | String   | 'Auto', 'CSV', or 'XLSX'                         |
| `-UseAsciiIcons`   | Switch   | Force ASCII instead of Unicode icons             |

## Output

### Console Output
```
======================================================================
MULTI-REGION CAPACITY MATRIX
======================================================================

Family     | centralus       | eastus          | eastus2
----------------------------------------------------------------
B          | ⚠ LIMITED       | ⚠ LIMITED       | ✓ OK
D          | ⚠ LIMITED       | ⚠ LIMITED       | ✓ OK
E          | ⚠ LIMITED       | ⚠ LIMITED       | ✓ OK
NC         | ⚠ LIMITED       | ⚠ LIMITED       | ✓ OK
```

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
📧 zachary.luz@microsoft.com

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.
