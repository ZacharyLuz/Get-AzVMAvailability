<p align="center">
  <img src="assets/header-dark.png" alt="Get-AzVMAvailability — Discover Available Azure VM Capacity Across Regions" />
</p>

A PowerShell tool for checking Azure VM SKU availability across regions - find where your VMs can deploy.

![PowerShell](https://img.shields.io/badge/PowerShell-7.0%2B-blue)
![Azure](https://img.shields.io/badge/Azure-Az%20Modules-0078D4)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-2.0.0-brightgreen)

## Overview

Get-AzVMAvailability helps you identify which Azure regions have available capacity for your VM deployments. It scans multiple regions in parallel and provides detailed insights into SKU availability, zone restrictions, quota limits, pricing, and image compatibility.

## What's New

### v2.0.0 — Module Conversion (April 2026)
- **PowerShell module** — install via `Install-Module AzVMAvailability` from PSGallery, or import directly from the repo
- **No behavior changes** — all 39 parameters, output formats, and interactive prompts are identical to v1.14.0
- **Thin wrapper** — `Get-AzVMAvailability.ps1` still works as a standalone entry point (imports the module and forwards parameters)
- **Private functions** — 43 helper functions are now truly private; only `Get-AzVMAvailability` is exported
- **CI/CD publishing** — automated PSGallery + GitHub Release publishing on merge to main

### v1.14.0 — Lifecycle & Deployment Mapping (April 2026)
- **Lifecycle Recommendations** — feed a CSV/JSON/XLSX of deployed VMs and get retirement risk analysis with up to 6 upgrade alternatives per SKU, powered by a curated upgrade-path knowledge base
- **`-SubMap` / `-RGMap`** — new deployment mapping sheets in XLSX exports, grouping affected VMs by subscription or resource group with risk-level enrichment
- **`-Tag` filter** — filter live VM inventory scans by Azure resource tags (key=value or key=`*`)
- **`-RateOptimization`** — opt-in Savings Plan and Reserved Instance pricing columns alongside PAYG

> Full history: [CHANGELOG.md](CHANGELOG.md)

## Features

- **Multi-Region Parallel Scanning** - Scan 10+ regions in ~15 seconds using concurrent HttpClient-based REST calls
- **SKU Filtering** - Filter to specific SKUs with wildcard support (e.g., `Standard_D*_v5`)
- **Lifecycle Recommendations** - Analyze deployed VMs for retirement risk; get up to 6 upgrade alternatives per SKU from a curated knowledge base + real-time scoring engine
- **Live Lifecycle Scan** - Pull VM inventory directly from Azure via Resource Graph with management group, resource group, and tag filters
- **Deployment Mapping** - `-SubMap` / `-RGMap` sheets group affected VMs by subscription or resource group with risk enrichment
- **Pricing Information** - Show hourly/monthly pricing (retail or negotiated EA/MCA rates) with optional Savings Plan and Reserved Instance comparisons
- **Spot VM Pricing** - Include Spot pricing alongside on-demand rates
- **Placement Scores** - Show allocation likelihood (High/Medium/Low) for each SKU via Azure Spot Placement API
- **Image Compatibility** - Verify Gen1/Gen2 and x64/ARM64 requirements
- **Zone Availability** - Per-zone availability details
- **Quota Tracking** - Available vCPU quota per family
- **Multi-Region Matrix** - Color-coded comparison view
- **Interactive Drill-Down** - Explore specific families and SKUs
- **Export Options** - CSV and styled XLSX with conditional formatting
- **JSON Output** - Structured JSON for AI agent integration and automation pipelines
- **Inventory Readiness** - Validate capacity and quota for an entire VM BOM in one command
- **Compatibility-Validated Recommendations** - Alternatives are validated to meet or exceed the target SKU's NICs, accelerated networking, premium IO, disk interface, ephemeral OS disk, and Ultra SSD requirements. Data disks and IOPS are scored as soft dimensions

## Quick Comparison

| Task                           | Azure Portal            | This Script          |
| ------------------------------ | ----------------------- | -------------------- |
| Check 10 regions               | ~5 minutes              | ~15 seconds          |
| Get quota + availability       | Multiple blades         | Single view          |
| Compare pricing across regions | Separate calculator     | Integrated           |
| Filter to specific SKUs        | Scroll through hundreds | Wildcard filtering   |
| Check image compatibility      | Manual research         | Automated validation |
| Analyze VM retirement risk     | Azure Advisor + manual  | Single command       |
| Export results                 | Manual copy/paste       | One command          |

## Use Cases

- **VM Lifecycle & Retirement Planning** - Identify old-gen and retiring SKUs across your fleet and get validated upgrade paths
- **Disaster Recovery Planning** - Identify backup regions with capacity
- **Multi-Region Deployments** - Find regions where all required SKUs are available
- **GPU/HPC Workloads** - NC, ND, NV series are often constrained; find where they're available
- **Inventory Readiness Validation** - Verify capacity and quota for an entire VM BOM before deployment
- **Image Compatibility** - Verify SKUs support your Gen2 or ARM64 images before deployment
- **Troubleshooting Deployments** - Quickly identify why a deployment might be failing

## Requirements

- **PowerShell 7.0+** (required)
- **Azure PowerShell Modules**: `Az.Accounts`, `Az.Compute`, `Az.Resources`
- **Optional**: `ImportExcel` module for styled XLSX export
- **Optional**: `Az.ResourceGraph` module for `-LifecycleScan` live VM inventory

## Quick Start

### Option A: Module (recommended)

```powershell
# Install from PSGallery (available after v2.0.0 release)
Install-Module AzVMAvailability -Repository PSGallery

# Or import directly from the repo
Import-Module .\AzVMAvailability

# Login and scan
Connect-AzAccount
Get-AzVMAvailability -Region "eastus" -NoPrompt
```

### Option B: Script (unchanged)

```powershell
# Interactive Login to Azure
Connect-AzAccount -Tenant YourTenantIdHere -subscription YourSubIdHere

# Interactive mode - prompts for all options
.\Get-AzVMAvailability.ps1

# Automated mode - uses current subscription
.\Get-AzVMAvailability.ps1 -NoPrompt -Region "eastus","westus2"

# With auto-export
.\Get-AzVMAvailability.ps1 -Region "eastus","eastus2" -AutoExport

# Inventory readiness check from CSV file
.\Get-AzVMAvailability.ps1 -InventoryFile .\examples\fleet-bom.csv -Region "eastus" -NoPrompt

# Lifecycle analysis — find old-gen SKUs and recommend replacements
.\Get-AzVMAvailability.ps1 -LifecycleRecommendations .\my-vms.csv -Region "eastus" -NoPrompt

# Lifecycle analysis — from Azure portal VM export (XLSX)
.\Get-AzVMAvailability.ps1 -LifecycleRecommendations .\AzureVirtualMachines.xlsx -NoPrompt

# Live lifecycle scan — pull VM inventory directly from Azure
.\Get-AzVMAvailability.ps1 -LifecycleScan -NoPrompt
```

## Script vs Module

As of v2.0.0, Get-AzVMAvailability is available as both a standalone script and a PowerShell module. **Existing script users see no changes** — the `.ps1` file still works exactly as before.

| | Script (`.\Get-AzVMAvailability.ps1`) | Module (`Get-AzVMAvailability`) |
|---|---|---|
| **Install** | `git clone` or download ZIP | `Install-Module AzVMAvailability` |
| **Run** | `.\Get-AzVMAvailability.ps1 -Region eastus` | `Get-AzVMAvailability -Region eastus` |
| **Works from any directory** | No — requires full path or `cd` to repo | Yes — available globally after install |
| **Update** | `git pull` | `Update-Module AzVMAvailability` |
| **Tab completion & Get-Help** | Requires dot-sourcing first | Works immediately |
| **Use in automation scripts** | `. .\Get-AzVMAvailability.ps1` (dot-source) | `Import-Module AzVMAvailability` |
| **Parameters & output** | Identical | Identical |

### Staying Up to Date

- **Module users**: Run `Update-Module AzVMAvailability` periodically, or check your installed version with `Get-Module AzVMAvailability -ListAvailable`.
- **Script users**: Run `git pull` to get the latest version.
- **Release notifications**: Click **Watch** → **Custom** → **Releases** on the [GitHub repo](https://github.com/ZacharyLuz/Get-AzVMAvailability) to be notified of new versions.

## Documentation

| Topic | Description |
|-------|-------------|
| [Parameters](docs/parameters.md) | All 39 parameters organized by group with types, defaults, and aliases |
| [Usage Examples](docs/usage-examples.md) | Common scanning patterns — GPU, pricing, export, multi-region |
| [Inventory Planning](docs/inventory-planning.md) | Validate capacity and quota for an entire VM BOM |
| [Lifecycle Recommendations](docs/lifecycle-recommendations.md) | Retirement risk analysis with upgrade alternatives |
| [Region Presets](docs/region-presets.md) | Pre-built region sets for US, Europe, Asia-Pacific, sovereign clouds |
| [Image Compatibility](docs/image-compatibility.md) | Gen1/Gen2 and x64/ARM64 image checking |
| [Output & Pricing](docs/output-and-pricing.md) | Console output, pricing auto-detection, Excel export, status legend |
| [Cloud Environments](docs/cloud-environments.md) | Supported Azure clouds (Commercial, Government, China, Germany) |
| [AI Agent Integration](docs/agent-integration.md) | Copilot skill for natural-language VM capacity queries |
| [GitHub Codespaces](docs/codespaces.md) | Run in a browser with zero local setup |
| [Local Installation](docs/local-installation.md) | Clone, install modules, and import |

## Contributing

Contributions are welcome! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## Roadmap

See [ROADMAP.md](ROADMAP.md) for planned features. Recently shipped:
- **Azure Resource Graph integration** — live VM inventory via `-LifecycleScan` (v1.14.0)
- **PowerShell module** — `Install-Module AzVMAvailability` from PSGallery (v2.0.0)

Up next:
- HTML reports and trend tracking

## License

This project is licensed under the MIT License - see [LICENSE](LICENSE) for details.

## Author

**Zachary Luz** — Personal project (not an official Microsoft product)

## Support & Responsible Use

This tool queries only **public Azure APIs** (SKU availability, quota, retail pricing) against your own Azure subscriptions. It reads subscription metadata (such as subscription IDs/names, regions, quotas, and usage) and writes results locally (console output and CSV/XLSX exports); it does **not** transmit this data off your machine except as required to call Azure APIs.

- **Issues & PRs**: Welcome! Please do not include subscription IDs, tenant IDs, internal URLs, or any confidential information.
- **Azure support**: For Azure platform issues or outages, contact [Azure Support](https://azure.microsoft.com/support/) — not this repository.
- **Exported files**: Review CSV/XLSX exports before sharing externally — they may contain subscription IDs, region information, quotas, and usage details for your environment.

## Disclosure & Disclaimer

The author is a Microsoft employee; however, this is a **personal open-source project**. It is **not** an official Microsoft product, nor is it endorsed, sponsored, or supported by Microsoft.

- **No warranty**: Provided "as-is" under the [MIT License](LICENSE).
- **No official support**: For Azure platform issues, use [Azure Support](https://azure.microsoft.com/support/).
- **No confidential information**: This tool uses only publicly documented Azure APIs. Please do not share internal or confidential information in issues, pull requests, or discussions.
- **Trademarks**: "Microsoft" and "Azure" are trademarks of Microsoft Corporation. Their use here is for identification only and does not imply endorsement.

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.

## Troubleshooting

### Security warning when running downloaded script

If Windows warns that the script came from the internet, unblock it once:

```powershell
Unblock-File .\Get-AzVMAvailability.ps1
```

### `AzureEndpoints` property error at startup

If you see an error like `The property 'AzureEndpoints' cannot be found on this object`, you are likely running an older script copy.

```powershell
Select-String -Path .\Get-AzVMAvailability.ps1 -Pattern 'AzureEndpoints\s*=\s*\$null'
```

