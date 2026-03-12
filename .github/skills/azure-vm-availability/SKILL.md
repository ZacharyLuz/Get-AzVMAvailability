---
name: azure-vm-availability
description: "Scan Azure regions for real-time VM SKU availability, capacity status, quota, pricing, and image compatibility using Get-AzVMAvailability. USE FOR: where can I deploy VMs, check VM capacity, GPU availability, find available regions, VM SKU restricted, capacity constrained, find alternative SKU, recommend replacement VM, compare regions for VMs, DR region planning, check zone availability, is this SKU available, scan regions. DO NOT USE FOR: general VM size recommendations without Azure login (use azure-compute), quota management via CLI (use azure-quotas), deploying VMs (use azure-prepare)."
license: MIT
metadata:
  author: Zachary Luz
  version: "1.1.0"  # Skill version (independent of script version 1.11.0)
---

# Azure VM Availability — Live Capacity Scanner

> **AUTHORITATIVE GUIDANCE** — This skill teaches you when and how to invoke
> the `Get-AzVMAvailability.ps1` script via terminal for real-time Azure VM
> capacity scanning. The script is the execution engine; this skill is the
> routing layer.

## When to Use This Skill

Invoke this skill when the user wants to:
- Check **real-time** VM SKU availability across Azure regions
- Find which regions have capacity for a specific VM family or SKU
- Discover GPU/HPC SKU availability (NC, ND, NV series are often constrained)
- Find **alternative SKUs** when a target VM is capacity-constrained or restricted
- Plan **disaster recovery** by comparing capacity across region pairs
- Verify **image compatibility** (Gen1/Gen2, x64/ARM64) before deployment
- See **pricing** alongside availability (retail or negotiated EA/MCA/CSP)
- Export availability data to CSV/XLSX for reporting
- Troubleshoot why a VM deployment is failing (restricted, quota exceeded)

### When NOT to Use This Skill

| Scenario | Use Instead |
|----------|-------------|
| General VM size recommendation (no Azure login needed) | `azure-compute` |
| Check/manage quota limits via `az quota` CLI | `azure-quotas` |
| Deploy VMs or infrastructure | `azure-prepare` → `azure-validate` → `azure-deploy` |
| Diagnose portal-vs-programmatic quota mismatch | `azure-quota-subfamily-mismatch-diagnosis` |
| Verify local script is up to date | `azvmavailability-release-verification-workflow` |

---

## Prerequisites

Before running, verify these requirements. **Stop and help the user fix any missing prerequisite.**

### 1. Script Must Be On The Machine

```powershell
# Check if the script exists in common locations
$paths = @(
    "$env:USERPROFILE\Get-AzVMAvailability\Get-AzVMAvailability.ps1",
    "$env:USERPROFILE\source\repos\Get-AzVMAvailability\Get-AzVMAvailability.ps1",
    "$env:USERPROFILE\OneDrive - Microsoft\Get-AzVMAvailability\Get-AzVMAvailability.ps1"
)
$found = $paths | Where-Object { Test-Path $_ } | Select-Object -First 1
if ($found) { Write-Host "Found: $found" } else { Write-Host "NOT FOUND" }
```

**If not found**, tell the user:
```powershell
git clone https://github.com/ZacharyLuz/Get-AzVMAvailability.git
cd Get-AzVMAvailability
```

### 2. PowerShell 7+ Required

```powershell
$PSVersionTable.PSVersion  # Must be 7.0+
```

If running in Windows PowerShell 5.1, prefix commands with `pwsh -File`.

### 3. Azure Modules & Login

```powershell
Get-Module Az.Compute -ListAvailable   # Must be installed
Get-AzContext                          # Must have active login
```

If not logged in: `Connect-AzAccount`

---

## Decision Tree

```
User request
    │
    ├─ "What VM should I use for X workload?"
    │   └─ Use azure-compute skill (no login needed)
    │
    ├─ "Check my quota limits"
    │   └─ Use azure-quotas skill (az quota CLI)
    │
    ├─ "Where can I deploy Standard_D4s_v5?"
    │   └─ THIS SKILL → Scan mode
    │
    ├─ "Is GPU capacity available in eastus?"
    │   └─ THIS SKILL → Scan mode with FamilyFilter
    │
    ├─ "E64pds_v6 is constrained, what else can I use?"
    │   └─ THIS SKILL → Recommend mode
    │
    ├─ "Compare eastus vs westus2 for D-series"
    │   └─ THIS SKILL → Scan mode, multi-region
    │
    └─ "Check if my image works with this SKU"
        └─ THIS SKILL → Scan mode with ImageURN
```

---

## Core Workflows

### Workflow 1: Region Capacity Scan

**Scenario:** Check which regions have capacity for specific VM SKUs or families.

```powershell
# Basic scan — specific SKU across regions
.\Get-AzVMAvailability.ps1 -NoPrompt -Region "eastus","westus2","centralus" -SkuFilter "Standard_D4s_v5" -JsonOutput

# Scan a VM family across US regions
.\Get-AzVMAvailability.ps1 -NoPrompt -RegionPreset USMajor -FamilyFilter "D","E" -JsonOutput

# GPU availability scan
.\Get-AzVMAvailability.ps1 -NoPrompt -Region "eastus","southcentralus","westus2" -FamilyFilter "NC","ND","NV" -JsonOutput
```

**Always use `-NoPrompt -JsonOutput`** when running from Copilot to get structured output.

### Workflow 2: Find Alternative SKUs (Recommend Mode)

**Scenario:** A target SKU is constrained or restricted — find similar available alternatives.

```powershell
# Find alternatives for a constrained SKU
.\Get-AzVMAvailability.ps1 -NoPrompt -Recommend "Standard_E64pds_v6" -Region "eastus","westus2","centralus" -JsonOutput

# Show more results with lower threshold
.\Get-AzVMAvailability.ps1 -NoPrompt -Recommend "Standard_NC24ads_A100_v4" -RegionPreset USMajor -TopN 10 -MinScore 0 -JsonOutput

# Filter by minimum specs
.\Get-AzVMAvailability.ps1 -NoPrompt -Recommend "Standard_D8s_v5" -Region "eastus" -MinvCPU 8 -MinMemoryGB 32 -JsonOutput
```

### Workflow 3: Scan with Pricing

```powershell
# Auto-detects negotiated EA/MCA/CSP rates, falls back to retail
.\Get-AzVMAvailability.ps1 -NoPrompt -Region "eastus","westus2" -FamilyFilter "D" -ShowPricing -JsonOutput
```

### Workflow 4: Image Compatibility Check

```powershell
# Verify ARM64 image compatibility
.\Get-AzVMAvailability.ps1 -NoPrompt -Region "eastus" -SkuFilter "Standard_D*ps*" -ImageURN "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-arm64:latest" -JsonOutput

# Check Gen2 Windows image
.\Get-AzVMAvailability.ps1 -NoPrompt -Region "eastus","westus2" -ImageURN "MicrosoftWindowsServer:WindowsServer:2022-datacenter-g2:latest" -JsonOutput
```

### Workflow 5: DR Region Planning

```powershell
# Azure Site Recovery pair
.\Get-AzVMAvailability.ps1 -NoPrompt -RegionPreset ASR-EastWest -FamilyFilter "D","E" -ShowPricing -JsonOutput

# Custom DR pair
.\Get-AzVMAvailability.ps1 -NoPrompt -Region "eastus","westus2" -ShowPricing -JsonOutput
```

### Workflow 6: Placement Scores and Spot Pricing

**Scenario:** See allocation likelihood and spot pricing alongside recommendations.

```powershell
# Recommend with placement scores (shows High/Medium/Low allocation likelihood)
.\Get-AzVMAvailability.ps1 -NoPrompt -Recommend "Standard_D4s_v5" -Region "eastus","westus2" -ShowPlacement -JsonOutput

# Full enrichment: pricing + placement + spot pricing
.\Get-AzVMAvailability.ps1 -NoPrompt -Recommend "Standard_D4s_v5" -Region "eastus" -ShowPricing -ShowPlacement -ShowSpot -JsonOutput

# Placement scores in filtered scan mode (max 5 SKUs)
.\Get-AzVMAvailability.ps1 -NoPrompt -Region "eastus" -SkuFilter "Standard_D4s_v5" -ShowPlacement -JsonOutput
```

**Notes:**
- `-ShowPlacement` requires "Compute Recommendations Role" RBAC -- fails gracefully with a warning if missing
- `-ShowSpot` only adds value when `-ShowPricing` is also set (spot dollar values need pricing context)
- Placement API accepts max 5 SKUs x 8 regions per call -- larger sets are truncated with a verbose warning

### Workflow 7: Export for Reporting

```powershell
# Auto-export to XLSX (styled, color-coded)
.\Get-AzVMAvailability.ps1 -NoPrompt -RegionPreset USMajor -AutoExport -OutputFormat XLSX

# Export to specific path
.\Get-AzVMAvailability.ps1 -NoPrompt -Region "eastus","westus2" -ExportPath "C:\Reports" -AutoExport
```

---

## Parameter Quick Reference

| Parameter | Type | Purpose |
|-----------|------|---------|
| `-Region` | String[] | Azure region codes (e.g., "eastus","westus2") |
| `-RegionPreset` | String | Predefined set: USEastWest, USCentral, USMajor, Europe, AsiaPacific, Global, USGov, China, ASR-EastWest, ASR-CentralUS |
| `-FamilyFilter` | String[] | Filter to families: D, E, F, M, NC, ND, NV, etc. |
| `-SkuFilter` | String[] | Specific SKUs with wildcards: "Standard_D*_v5" |
| `-Recommend` | String | Target SKU for alternative finding |
| `-ShowPricing` | Switch | Include hourly/monthly pricing |
| `-ImageURN` | String | Check image compatibility (Publisher:Offer:Sku:Version) |
| `-NoPrompt` | Switch | **Always use from Copilot** — skip interactive prompts |
| `-JsonOutput` | Switch | **Always use from Copilot** — structured JSON output |
| `-AutoExport` | Switch | Export without prompting |
| `-OutputFormat` | String | Auto, CSV, or XLSX |
| `-TopN` | Int | Recommendations to return (default 5, max 25) |
| `-MinScore` | Int | Min similarity score 0-100 (default 50, use 0 for all) |
| `-MinvCPU` | Int | Min vCPU filter for recommendations |
| `-MinMemoryGB` | Int | Min memory filter for recommendations |
| `-ShowPlacement` | Switch | Show allocation likelihood scores (High/Medium/Low) per SKU |
| `-ShowSpot` | Switch | Include Spot VM pricing (requires `-ShowPricing`) |
| `-DesiredCount` | Int | VM count for placement score API (default 1) |
| `-AllowMixedArch` | Switch | Include x64+ARM64 mix in recommendations |

---

## Region Presets

| Preset | Regions | Notes |
|--------|---------|-------|
| USEastWest | eastus, eastus2, westus, westus2 | US coastal |
| USCentral | centralus, northcentralus, southcentralus, westcentralus | US central |
| USMajor | eastus, eastus2, centralus, westus, westus2 | Top 5 US |
| Europe | westeurope, northeurope, uksouth, francecentral, germanywestcentral | EU |
| AsiaPacific | eastasia, southeastasia, japaneast, australiaeast, koreacentral | APAC |
| Global | eastus, westeurope, southeastasia, australiaeast, brazilsouth | Worldwide |
| USGov | usgovvirginia, usgovtexas, usgovarizona | Auto-sets AzureUSGovernment |
| China | chinaeast, chinanorth, chinaeast2, chinanorth2 | Auto-sets AzureChinaCloud |
| ASR-EastWest | eastus, westus2 | DR pair |
| ASR-CentralUS | centralus, eastus2 | DR pair |

Max 5 regions per scan for performance.

---

## JSON Output Schema

### Scan Mode

```json
{
  "schemaVersion": "1.0",
  "mode": "scan",
  "generatedAt": "ISO8601",
  "subscriptions": ["sub-id"],
  "regions": ["eastus", "westus2"],
  "summary": {
    "familyCount": 20,
    "detailRowCount": 150,
    "regionErrorCount": 0
  },
  "families": [
    {
      "family": "D",
      "totalSkusDiscovered": 25,
      "availableRegionCount": 3,
      "constrainedRegionCount": 0,
      "largestSku": "Standard_D96s_v5"
    }
  ],
  "regionErrors": []
}
```

### Recommend Mode

```json
{
  "schemaVersion": "1.0",
  "mode": "recommend",
  "generatedAt": "ISO8601",
  "minScore": 50,
  "topN": 5,
  "pricingEnabled": false,
  "placementEnabled": false,
  "spotPricingEnabled": false,
  "target": {
    "Name": "Standard_E64pds_v6",
    "vCPU": 64,
    "MemoryGB": 512,
    "Family": "E",
    "Generation": "V1,V2",
    "Architecture": "x64",
    "PremiumIO": true,
    "Processor": "ARM",
    "DiskCode": "NV+T"
  },
  "targetAvailability": [
    { "Region": "eastus", "Status": "LIMITED", "ZonesOK": 0 }
  ],
  "recommendations": [
    {
      "rank": 1,
      "sku": "Standard_E64ds_v5",
      "region": "eastus",
      "vCPU": 64,
      "memGiB": 512,
      "family": "E",
      "score": 93,
      "capacity": "OK",
      "allocScore": "N/A",
      "zonesOK": 3,
      "priceHr": null,
      "priceMo": null,
      "spotPriceHr": null,
      "spotPriceMo": null
    }
  ],
  "warnings": ["Mixed CPU vendors (Intel, ARM)"],
  "belowMinSpec": []
}
```

> **Note:** The examples above show key fields for brevity. In actual output,
> each `recommendations` object also includes `purpose`, `gen`, `arch`, `cpu`,
> `disk`, `tempDiskGB`, and `accelNet`. The `target` object also includes
> `TempDiskGB` and `AccelNet`. Treat the schema as additive -- new fields may
> appear in future versions, but existing fields will not be removed without
> a `schemaVersion` change.

---

## Capacity Status Meanings

| Status | Meaning | Action |
|--------|---------|--------|
| OK | Ready to deploy, no restrictions | Proceed |
| LIMITED | Subscription can't use this SKU | Request access via support ticket |
| CAPACITY-CONSTRAINED | Azure low on hardware | Try different zone or wait |
| PARTIAL | Some zones work, others blocked | No zone redundancy available |
| RESTRICTED | Cannot deploy | Pick different region or SKU |

---

## Interpreting Results

When presenting results to the user:

1. **Scan mode**: Summarize which families/SKUs are available (OK) vs constrained, highlight best regions
2. **Recommend mode**: Present the top alternatives ranked by similarity score, note any fleet warnings (mixed CPU vendors, mixed disk types)
3. **Always mention**: quota availability, zone coverage, and pricing if shown
4. **If no OK results**: Suggest expanding regions, lowering MinScore, or trying different families

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Script not found | `git clone https://github.com/ZacharyLuz/Get-AzVMAvailability.git` |
| PowerShell 5.1 error | Use `pwsh -File .\Get-AzVMAvailability.ps1` |
| No Azure context | Run `Connect-AzAccount` first |
| `AzureEndpoints` error | Script is stale — pull latest from repo |
| Region validation fails | Add `-SkipRegionValidation` as last resort |
| Quota shows `?` | Quota API didn't return data for that family |
