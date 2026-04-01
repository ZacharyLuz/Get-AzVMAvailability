# Get-AzVMAvailability

A PowerShell tool for checking Azure VM SKU availability across regions - find where your VMs can deploy.

![PowerShell](https://img.shields.io/badge/PowerShell-7.0%2B-blue)
![Azure](https://img.shields.io/badge/Azure-Az%20Modules-0078D4)
![License](https://img.shields.io/badge/License-MIT-green)
![Version](https://img.shields.io/badge/Version-1.14.0-brightgreen)

## What's New

### v1.14.0 — Lifecycle & Deployment Mapping (April 2026)
- **Lifecycle Recommendations** — feed a CSV/JSON/XLSX of deployed VMs and get retirement risk analysis with up to 6 upgrade alternatives per SKU, powered by a curated upgrade-path knowledge base
- **`-SubMap` / `-RGMap`** — new deployment mapping sheets in XLSX exports, grouping affected VMs by subscription or resource group with risk-level enrichment
- **`-Tag` filter** — filter live VM inventory scans by Azure resource tags (key=value or key=`*`)
- **`-RateOptimization`** — opt-in Savings Plan and Reserved Instance pricing columns alongside PAYG

### v1.13.0 — Performance & JSON Output (March 2026)
- **HttpClient scan engine** — concurrent SKU+quota fetch via `System.Net.Http.HttpClient` with runspace parallelism (~20% faster scans)
- **`-JsonOutput`** — suppresses all `Write-Host` output for clean JSON pipeline consumption
- **O(1) capability lookup** — hashtable index replaces linear scan in `Get-CapValue`

### v1.12.5 — Codespaces Support (March 2026)
- GitHub Codespaces support and documentation updates

### v1.12.1–1.12.4 — Fleet Readiness & Module Extraction (March 2026)
- **`-FleetFile`** — load fleet BOM from CSV/JSON for capacity and quota validation
- **`-GenerateFleetTemplate`** — scaffolds example fleet template files
- **Module extraction** — 34 functions extracted to `AzVMAvailability/` module with inline fallback
- **`exit` → `throw`** — script no longer kills the caller's session when dot-sourced

### v1.12.0 — Fleet Readiness MVP (March 2026)
- **`-Fleet` hashtable** — BOM-level capacity and quota validation with per-family pass/fail verdicts

> Full history: [CHANGELOG.md](CHANGELOG.md)

## Disclosure & Disclaimer

The author is a Microsoft employee; however, this is a **personal open-source project**. It is **not** an official Microsoft product, nor is it endorsed, sponsored, or supported by Microsoft.

- **No warranty**: Provided "as-is" under the [MIT License](LICENSE).
- **No official support**: For Azure platform issues, use [Azure Support](https://azure.microsoft.com/support/).
- **No confidential information**: This tool uses only publicly documented Azure APIs. Please do not share internal or confidential information in issues, pull requests, or discussions.
- **Trademarks**: "Microsoft" and "Azure" are trademarks of Microsoft Corporation. Their use here is for identification only and does not imply endorsement.

## Overview

Get-AzVMAvailability helps you identify which Azure regions have available capacity for your VM deployments. It scans multiple regions in parallel and provides detailed insights into SKU availability, zone restrictions, quota limits, pricing, and image compatibility.

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
- **Azure PowerShell Modules**: `Az.Compute`, `Az.Resources`
- **Optional**: `ImportExcel` module for styled XLSX export
- **Optional**: `Az.ResourceGraph` module for `-LifecycleScan` live VM inventory

## Supported Cloud Environments

The script automatically detects your Azure environment and uses the correct API endpoints:

| Cloud            | Environment Name    | Supported |
| ---------------- | ------------------- | --------- |
| Azure Commercial | `AzureCloud`        | ✅         |
| Azure Government | `AzureUSGovernment` | ✅         |
| Azure China      | `AzureChinaCloud`   | ✅         |
| Azure Germany    | `AzureGermanCloud`  | ✅         |

**No configuration required** - the script reads your current `Az` context and resolves endpoints automatically.

## Using GitHub Codespaces
A pre-configured codespace that automatically installs the required modules when first created has been defined in the `.devcontainer` folder of this repo.  This means no downloading or installing of any code on your local machine.  Simply follow these steps: 
- In GitHub, select the **Codespaces** tab from the **Code** dropdown in GitHub on the Repo's (or your fork's) main page.
- Click on the plus (+) icon to create a new codespace
- Wait for the codespace to finish installing/creating
- Run the following commands

```powershell
# Use this instead if calling from a codespace
Connect-AzAccount -Tenant YourTenantIdHere -subscription YourSubIdHere -UseDeviceAuthentication

# Interactive mode - prompts for all options
.\Get-AzVMAvailability.ps1

# See further in this document for other examples outside of interactive mode
```

## Local Installation

```powershell
# Clone the repository
git clone https://github.com/zacharyluz/Get-AzVMAvailability.git
cd Get-AzVMAvailability

# Install required Azure modules (if needed)
# Windows only: enable running scripts from the PowerShell Gallery in your profile
if ($IsWindows) {
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
}
Install-Module -Name Az.Compute -Scope CurrentUser -Repository PSGallery -Force
Install-Module -Name Az.Resources -Scope CurrentUser -Repository PSGallery -Force

# Optional: Install ImportExcel for styled exports
Install-Module -Name ImportExcel -Scope CurrentUser -Repository PSGallery -Force

# Register a local PowerShell repository for this repo (idempotent)
if (-not (Get-PSRepository -Name Get-AzVMAvailability -ErrorAction SilentlyContinue)) {
    Register-PSRepository -Name Get-AzVMAvailability -SourceLocation . -InstallationPolicy Trusted
}

```

## Quick Start

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

| Parameter               | Type     | Description                                                                                                               |
| ----------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------- |
| `-SubscriptionId`       | String[] | Azure subscription ID(s) to scan                                                                                          |
| `-Region`               | String[] | Azure region code(s) (e.g., 'eastus', 'westus2')                                                                          |
| `-RegionPreset`         | String   | Predefined region set (see table below). Auto-sets environment for sovereign clouds.                                      |
| `-Environment`          | String   | Azure cloud (default: auto-detect). Options: AzureCloud, AzureUSGovernment, AzureChinaCloud, AzureGermanCloud             |
| `-ExportPath`           | String   | Directory for export files                                                                                                |
| `-AutoExport`           | Switch   | Export without prompting                                                                                                  |
| `-EnableDrillDown`      | Switch   | Interactive family/SKU exploration                                                                                        |
| `-FamilyFilter`         | String[] | Filter to specific VM families                                                                                            |
| `-SkuFilter`            | String[] | Filter to specific SKUs (supports wildcards)                                                                              |
| `-ShowPricing`          | Switch   | Show pricing (auto-detects negotiated EA/MCA/CSP rates, falls back to retail)                                             |
| `-ShowSpot`             | Switch   | Include Spot VM pricing in output. Requires `-ShowPricing`                                                                |
| `-ShowPlacement`        | Switch   | Show allocation likelihood scores (High/Medium/Low) for each SKU via Azure Spot Placement API                            |
| `-DesiredCount`         | Int      | Number of VMs to evaluate for placement scores (default 1). Affects allocation likelihood thresholds                      |
| `-RateOptimization`     | Switch   | Include Savings Plan and Reserved Instance savings columns in lifecycle reports. Requires `-ShowPricing`. Shows fleet-wide savings vs PAYG for each commitment term |
| `-ImageURN`             | String   | Check SKU compatibility with image (format: Publisher:Offer:Sku:Version)                                                  |
| `-CompactOutput`        | Switch   | Use compact output for narrow terminals                                                                                   |
| `-NoPrompt`             | Switch   | Skip interactive prompts                                                                                                  |
| `-NoQuota`              | Switch   | Skip quota API calls in lifecycle modes. Useful when analyzing customer VM exports without subscription access             |
| `-OutputFormat`         | String   | 'Auto', 'CSV', or 'XLSX'                                                                                                  |
| `-UseAsciiIcons`        | Switch   | Force ASCII instead of Unicode icons                                                                                      |
| `-Recommend`            | String   | Find alternatives for a target SKU. Works interactively too — prompted after scan/drill-down if not specified             |
| `-TopN`                 | Int      | Number of alternatives to return in Recommend mode (default 5, max 25)                                                    |
| `-MinvCPU`              | Int      | Minimum vCPU count filter for recommended alternatives (optional)                                                         |
| `-MinMemoryGB`          | Int      | Minimum memory (GB) filter for recommended alternatives (optional)                                                        |
| `-MinScore`             | Int      | Minimum similarity score (0-100) for recommended alternatives; set 0 to show all (default 50)                             |
| `-AllowMixedArch`       | Switch   | Allow x64/ARM64 cross-architecture recommendations (excluded by default)                                                  |
| `-MaxRetries`           | Int      | Maximum retry attempts for transient API errors (default 3). Uses exponential backoff                                     |
| `-JsonOutput`           | Switch   | Emit structured JSON for the [AzVMAvailability-Agent](https://github.com/ZacharyLuz/AzVMAvailability-Agent) or automation |
| `-SkipRegionValidation` | Switch   | Skip Azure region metadata validation (use only when Azure metadata lookup is unavailable)                                |
| `-Inventory`            | Hashtable| Inventory BOM as hashtable: `@{'Standard_D2s_v5'=17; 'Standard_D4s_v5'=4}` — validates capacity + quota for entire inventory     |
| `-InventoryFile`        | String   | Path to CSV or JSON file with inventory BOM. CSV: columns `SKU,Qty`. JSON: array of `{"SKU":"...","Qty":N}` objects. Easiest input method for spreadsheet users |
| `-GenerateInventoryTemplate`| Switch   | Creates `inventory-template.csv` and `inventory-template.json` in the current directory, then exits. No Azure login required |
| `-LifecycleRecommendations`| String  | Path to CSV, JSON, or XLSX file listing current VM SKUs (column: SKU/Size/VmSize, optional: Region, Qty). XLSX files exported from the Azure portal VM blade are supported natively. Runs compatibility-validated recommendations with quantity-aware quota analysis |
| `-LifecycleScan`        | Switch   | Pull live VM inventory from Azure via Resource Graph for lifecycle analysis. No file required — queries all deployed VMs from your tenant. Requires `Az.ResourceGraph` module |
| `-ManagementGroup`      | String[] | Scope `-LifecycleScan` to specific management group(s) for cross-subscription scanning |
| `-ResourceGroup`        | String[] | Filter `-LifecycleScan` to specific resource group(s) |
| `-Tag`                  | Hashtable| Filter `-LifecycleScan` to VMs with specific tags. Hashtable of key=value pairs (e.g., `@{Environment='prod'}`). Use `'*'` as value to match any VM that has the tag key regardless of value |
| `-SubMap`               | Switch   | Include a Subscription Map sheet in lifecycle XLSX exports, grouping affected VMs by subscription with risk-level enrichment |
| `-RGMap`                | Switch   | Include a Resource Group Map sheet in lifecycle XLSX exports, grouping affected VMs by subscription + resource group with risk-level enrichment |

> **Backward compatibility:** The previous parameter names `-Fleet`, `-FleetFile`, and `-GenerateFleetTemplate` still work as aliases.

> **Tuning tip:** Use `-MinScore 0` to see all candidates when capacity is tight, or raise it (e.g., 70) to prioritize closer matches.

### Compatibility Gate

Recommendations are **compatibility-validated** before scoring. A candidate SKU is only shown if it meets or exceeds the target on every critical dimension:

| Dimension | Rule |
|-----------|------|
| vCPU | Candidate ≥ Target (and ≤ 2× to avoid licensing risk) |
| Memory (GiB) | Candidate ≥ Target |
| Max NICs | Candidate ≥ Target (when target uses multi-NIC) |
| Accelerated networking | Required if target has it |
| Premium IO | Required if target has it |
| Disk interface | NVMe target requires NVMe candidate |
| Ephemeral OS disk | Required if target supports it |
| Ultra SSD | Required if target has it |

After passing the compatibility gate, candidates are ranked by an 8-dimension similarity score:

| Dimension | Weight |
|-----------|--------|
| vCPU closeness | 20 pts |
| Memory closeness | 20 pts |
| Family match | 18 pts |
| Family version newness | 12 pts |
| Architecture match | 10 pts |
| Disk IOPS closeness | 8 pts |
| Data disk count closeness | 7 pts |
| Premium IO match | 5 pts |

## Inventory Planning Quick Start

Validate whether your entire VM deployment can be provisioned in a target region.

### Step 1: Create your inventory file

**Option A — Generate a template** (easiest):
```powershell
.\Get-AzVMAvailability.ps1 -GenerateInventoryTemplate
# Creates inventory-template.csv and inventory-template.json in current directory
# Edit with your actual SKUs and quantities
```

**Option B — Write a CSV** (Excel / text editor):
```csv
SKU,Qty
Standard_D2s_v5,17
Standard_D4s_v5,4
Standard_D8s_v5,5
```

**Option C — Write a JSON file**:
```json
[
  { "SKU": "Standard_D2s_v5", "Qty": 17 },
  { "SKU": "Standard_D4s_v5", "Qty": 4 },
  { "SKU": "Standard_D8s_v5", "Qty": 5 }
]
```

> **Column names are flexible:** `SKU`, `Name`, or `VmSize` for the SKU column; `Qty`, `Quantity`, or `Count` for quantity. Duplicate SKU rows are summed automatically. The `Standard_` prefix is optional.

### Step 2: Run the scan

```powershell
.\Get-AzVMAvailability.ps1 -InventoryFile .\inventory-template.csv -Region "eastus" -NoPrompt
```

### Step 3: Read the verdict

The output shows per-SKU capacity status, per-family quota pass/fail (Used/Available/Limit), and an overall **PASS/FAIL** verdict.

## Lifecycle Recommendations

Analyze your current VM inventory to identify SKUs that need lifecycle planning (old generation, capacity-constrained, or deprecated) and get compatibility-validated replacement recommendations for each.

### Option 1: From a CSV/JSON file

```csv
SKU,Region,Qty
Standard_D4s_v3,eastus,10
Standard_E8s_v3,westus2,5
Standard_F4s_v2,eastus,3
Standard_D8s_v5,centralus,20
```

All columns except **SKU** are optional:
- **Region** — where the SKU is deployed. When provided, capacity and quota are checked specifically in that region. Regions are auto-merged into the scan.
- **Qty** — number of VMs using this SKU (defaults to 1). Used to calculate required vCPUs for quota analysis. Duplicate SKU+Region rows have their quantities aggregated.

Minimal format (SKU only):

```csv
SKU
Standard_D4s_v3
Standard_E8s_v3
Standard_F4s_v2
```

> **Column names are flexible:** `SKU`, `Size`, or `VmSize` (falls back to `Name`) for the SKU column; `Region`, `Location`, or `AzureRegion` for region; `Qty`, `Quantity`, or `Count` for quantity.

```powershell
.\Get-AzVMAvailability.ps1 -LifecycleRecommendations .\my-vms.csv -Region "eastus" -NoPrompt
```

### Option 2: From an Azure portal export (XLSX)

Export your VM list directly from the Azure portal (Virtual Machines blade → Export to CSV/Excel) and pass the XLSX file with no reformatting:

```powershell
.\Get-AzVMAvailability.ps1 -LifecycleRecommendations .\AzureVirtualMachines.xlsx -NoPrompt
```

The parser automatically maps the `SIZE` column to SKU and `LOCATION` to Region, converts display names (e.g., "West US" → `westus`, "USGov Virginia" → `usgovvirginia`), and aggregates one-VM-per-row into SKU+Region quantities. Requires the `ImportExcel` module.

### Option 3: Live scan from Azure (no file needed)

Pull your VM inventory directly from Azure using Resource Graph:

```powershell
# Scan current subscription
.\Get-AzVMAvailability.ps1 -LifecycleScan -NoPrompt

# Scan specific subscriptions
.\Get-AzVMAvailability.ps1 -LifecycleScan -SubscriptionId "sub-id-1","sub-id-2" -NoPrompt

# Scan an entire management group (all child subscriptions)
.\Get-AzVMAvailability.ps1 -LifecycleScan -ManagementGroup "mg-production" -NoPrompt

# Scan specific resource groups within a subscription
.\Get-AzVMAvailability.ps1 -LifecycleScan -SubscriptionId "sub-id" -ResourceGroup "rg-app","rg-data" -NoPrompt

# Scan only VMs tagged with Environment=prod
.\Get-AzVMAvailability.ps1 -LifecycleScan -Tag @{Environment='prod'} -NoPrompt

# Combine tag filter with subscription and resource group
.\Get-AzVMAvailability.ps1 -LifecycleScan -SubscriptionId "sub-id" -Tag @{CostCenter='12345'; Environment='prod'} -NoPrompt

# Scan all VMs that have a "Department" tag (any value)
.\Get-AzVMAvailability.ps1 -LifecycleScan -Tag @{Department='*'} -NoPrompt
```

Requires the `Az.ResourceGraph` module (`Install-Module Az.ResourceGraph -Scope CurrentUser`).

> **Scoping rules:** `-ManagementGroup` and `-SubscriptionId` are mutually exclusive. `-ResourceGroup` and `-Tag` can be combined with either. If neither is specified, the current subscription context is used.

### What you get

For each SKU in your list:
1. **Hybrid recommendations (3 AI + up to 3 weighted)** — Up to 6 alternatives per SKU using a two-tier strategy:
   - **3 upgrade path recommendations** from a curated knowledge base ([`data/UpgradePath.json`](data/UpgradePath.json)) based on Microsoft's official migration guidance:
     - `Upgrade: Drop-in` — lowest risk replacement (e.g., Dsv5 for Dv2)
     - `Upgrade: Future-proof` — latest generation (e.g., Dsv6 with NVMe)
     - `Upgrade: Cost-optimized` — AMD/alternative architecture at lower cost
   - **Up to 3 weighted recommendations** from the real-time 8-dimension scoring engine, validated against actual region availability, capacity, and quota
2. **Lifecycle risk assessment** — High / Medium / Low risk classification
3. **Quota analysis** — current quota usage vs. limit for both the target SKU family and the recommended replacement's family, factoring in VM quantity (Qty × vCPUs)
4. **Details column** — explains *why* each recommendation was selected (upgrade path rationale, family/version context, IOPS guarantees, resize impact, requirements like Gen2 OS or NVMe)
5. **Consolidated summary table** — all SKUs with Qty, region, risk level, quota status, and top replacement
6. **VM-count-aware summary** — footer shows total VM count at each risk level (e.g., "3 SKU(s) (35 VMs) at HIGH risk")

The upgrade path knowledge base covers 19 VM families (11 retired, 8 scheduled for retirement) with vCPU-matched size maps. See [`data/UpgradePath.md`](data/UpgradePath.md) for the full reference.

Risk levels:
- **High** — Retired/retiring SKU, capacity issues, quota insufficient, or no compatible alternatives found
- **Medium** — Old generation (v3 or below); plan migration to current generation
- **Low** — Current generation with good availability and sufficient quota

### Pricing in Lifecycle Reports

By default, lifecycle reports include only PAYG (pay-as-you-go) cost columns when `-ShowPricing` is used:

```powershell
# PAYG pricing only (Price Diff, Total, 1-Year Cost, 3-Year Cost)
.\Get-AzVMAvailability.ps1 -LifecycleRecommendations .\my-vms.csv -ShowPricing -NoPrompt
```

To include Savings Plan (SP) and Reserved Instance (RI) savings columns, add `-RateOptimization`:

```powershell
# Full pricing: PAYG + SP/RI savings vs PAYG fleet total
.\Get-AzVMAvailability.ps1 -LifecycleRecommendations .\my-vms.csv -ShowPricing -RateOptimization -NoPrompt

# Live scan with rate optimization and auto-export to XLSX
.\Get-AzVMAvailability.ps1 -LifecycleScan -ShowPricing -RateOptimization -AutoExport -NoPrompt

# Azure portal export with full pricing comparison
.\Get-AzVMAvailability.ps1 -LifecycleRecommendations .\AzureVirtualMachines.xlsx -ShowPricing -RateOptimization -NoQuota -AutoExport
```

With `-RateOptimization`, the XLSX report adds 4 savings columns: `SP 1-Year Savings`, `SP 3-Year Savings`, `RI 1-Year Savings`, `RI 3-Year Savings` — showing how much the fleet saves compared to PAYG by committing to each term.

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

> **Note**: Maximum 5 regions per scan for optimal performance and readability. Presets are limited accordingly. Lifecycle modes (`-LifecycleRecommendations`, `-LifecycleScan`) are exempt — all deployed regions are scanned automatically.

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
GET-AZVMAVAILABILITY v1.14.0
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

## AI Agent Integration (Copilot Skill)

This repo includes a **Copilot skill** that teaches AI coding agents (VS Code Copilot, Claude, Copilot CLI) how to invoke Get-AzVMAvailability for live capacity scanning. The skill provides routing logic, parameter mapping, and JSON output schema documentation so agents can translate natural language requests into the correct CLI invocations.

**Skill file:** [.github/skills/azure-vm-availability/SKILL.md](.github/skills/azure-vm-availability/SKILL.md)

### What the skill enables

| User says | Agent runs |
|-----------|-----------|
| "Where can I deploy NC-series GPUs?" | `.\Get-AzVMAvailability.ps1 -NoPrompt -FamilyFilter "NC","ND","NV" -RegionPreset USMajor -JsonOutput` |
| "E64pds_v6 is constrained, find alternatives" | `.\Get-AzVMAvailability.ps1 -NoPrompt -Recommend "Standard_E64pds_v6" -Region "eastus","westus2" -JsonOutput` |
| "Check placement scores for D4s_v5" | `.\Get-AzVMAvailability.ps1 -NoPrompt -Recommend "Standard_D4s_v5" -Region "eastus" -ShowPlacement -JsonOutput` |

### Installing the skill for VS Code Copilot

This skill is already referenced in `.github/copilot-instructions.md` and loads automatically when you open this repo in VS Code with GitHub Copilot enabled.

To use it in **other repositories**, copy the skill to your local skills directory and reference it in that repo's Copilot instructions:

```powershell
# Windows
Copy-Item -Recurse ".github\skills\azure-vm-availability" "$env:USERPROFILE\.agents\skills\azure-vm-availability"

# macOS/Linux
cp -r .github/skills/azure-vm-availability ~/.agents/skills/azure-vm-availability
```

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

No match indicates the file is stale. Download the latest `Get-AzVMAvailability.ps1` from the repository and re-run.

### Running in Windows PowerShell 5.1

PowerShell 5.1 is not supported. The script now warns and exits early if launched in 5.1.

Use PowerShell 7+ (`pwsh`):

```powershell
pwsh -File .\Get-AzVMAvailability.ps1
```

