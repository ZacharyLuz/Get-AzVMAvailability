<p align="center">
  <img src="assets/header-dark.png" alt="Get-AzVMAvailability — Discover Available Azure VM Capacity Across Regions" />
</p>

A PowerShell tool for checking Azure VM SKU availability across regions - find where your VMs can deploy.

![PowerShell](https://img.shields.io/badge/PowerShell-7.0%2B-blue)
![Azure](https://img.shields.io/badge/Azure-Az%20Modules-0078D4)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-2.3.0-brightgreen)

## Overview

Get-AzVMAvailability helps you identify which Azure regions have available capacity for your VM deployments. It scans multiple regions in parallel and provides detailed insights into SKU availability, zone restrictions, quota limits, pricing, and image compatibility.

## What's New

### v2.3.0 — Architecture Filter (May 2026)
- **`-ArchFilter` parameter** — filter scan results to specific CPU architectures (`x64`, `ARM64`). Supports multiple values, applied during SKU enumeration for cleaner results and faster scans. Header displays an interpretability hint when active.

### v2.2.2 — PSGallery Package Parity (May 2026)
- **PSGallery installs now include all runtime assets** — UpgradePath data, README, LICENSE, CHANGELOG, examples, and curated docs are staged into the module package before publishing. A Pester test guards the layout.
- **Version bump workflow coverage** — README badge, demo guide, ROADMAP header, and psd1 `ReleaseNotes` are now updated atomically alongside existing version stamps.

### v2.2.1 — Pricing Correctness Follow-up (April 2026)
- **Tier 2 region scoping** — Cost Management fallback now groups by `ResourceLocation` so multi-region subscriptions don't cross-contaminate cached rates.
- **Spot/Low-Priority laundering fix** — Tier 2 no longer silently caches spot rates as negotiated PAYG.
- **Savings Plan alias resolution** — SP1Yr/SP3Yr maps now apply the same ARM→cache alias pass as the Regular PAYG map, fixing silent retail fallback in commercial regions.

### v2.2.0 — Pricing Correctness & Lifecycle UX (April 2026)
- **`-AZ` switch** — adds `Zones (Deployed)` and `Zones (Supported)` columns in lifecycle reports (auto-enabled by `-LifecycleRecommendations`)
- **Commercial pricing fix** — 70+ region ARM→cache alias table resolves negotiated rates that were silently falling back to retail
- **GOV / sovereign cloud fixes** — Savings Plan columns omitted for sovereign tenants; RI/SP/Spot retail rates preserved when negotiated price sheet succeeds

### v2.1.1 — Retirement Data & CI Fixes (April 2026)
- **Retirement data freshness** — staleness check is opt-in via environment variable; structural assertions are always-on
- **CI reliability** — PSScriptAnalyzer empty-catch fixes, UTF-8 BOM alignment, unreachable bash heredoc removed

> Full history: [CHANGELOG.md](CHANGELOG.md)

## Features

- **Multi-Region Parallel Scanning** - Scan 10+ regions in ~15 seconds using concurrent HttpClient-based REST calls
- **SKU Filtering** - Filter to specific SKUs with wildcard support (e.g., `Standard_D*_v5`)
- **Lifecycle Recommendations** - Run fully autonomous with `-LifecycleRecommendations` — no prompts, auto-enables pricing, Excel export, savings plan/reservation details, and quota. Without `-LifecycleFile`, pulls live VM inventory from Azure via Resource Graph. With `-LifecycleFile`, loads VMs from a CSV/JSON/XLSX file. Legacy positional form `-LifecycleRecommendations .\my-vms.csv` is also supported
- **Live Lifecycle Scan** - `-LifecycleScan` pulls VM inventory directly from Azure via Resource Graph with management group, resource group, and tag filters
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
- **Optional**: `Az.ResourceGraph` module for `-LifecycleRecommendations` and `-LifecycleScan` live VM inventory

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

# Lifecycle scan — pull live VM inventory from Azure and analyze retirement risk
# Runs fully autonomous: no prompts, auto-enables pricing, Excel export, and quota
.\Get-AzVMAvailability.ps1 -LifecycleRecommendations

# Lifecycle analysis — load VMs from a CSV/JSON/XLSX file instead of live scan
.\Get-AzVMAvailability.ps1 -LifecycleRecommendations -LifecycleFile .\my-vms.csv -Region "eastus"

# Lifecycle analysis — from Azure portal VM export (XLSX)
.\Get-AzVMAvailability.ps1 -LifecycleRecommendations -LifecycleFile .\AzureVirtualMachines.xlsx

# Live lifecycle scan with filters — management group, resource group, or tag scoping
.\Get-AzVMAvailability.ps1 -LifecycleScan -ManagementGroup "Corp" -Tag @{Environment='prod'} -NoPrompt
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
| [Parameters](docs/parameters.md) | Reference table for all parameters, including names, types, and descriptions |
| [Usage Examples](docs/usage-examples.md) | Common scanning patterns — GPU, pricing, export, multi-region |
| [Inventory Planning](docs/inventory-planning.md) | Validate capacity and quota for an entire VM BOM |
| [Lifecycle Recommendations](docs/lifecycle-recommendations.md) | Retirement risk analysis with upgrade alternatives |
| [Region Presets](docs/region-presets.md) | Pre-built region sets for US, Europe, Asia-Pacific, sovereign clouds |
| [Image Compatibility](docs/image-compatibility.md) | Gen1/Gen2 and x64/ARM64 image checking |
| [Output & Pricing](docs/output-and-pricing.md) | Console output, pricing auto-detection, Excel export, status legend |
| [Cloud Environments](docs/cloud-environments.md) | Supported Azure clouds (Commercial, Government, China) |
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

If this command returns a match, the file you are running still contains the old code path and should be replaced with the current `Get-AzVMAvailability.ps1` wrapper from this repo, or you should run the module directly with `Import-Module .\AzVMAvailability`.

If the command returns no output, that stale-copy marker is not present in this file. Confirm you are launching the expected script path and not another older copy from a different folder.

