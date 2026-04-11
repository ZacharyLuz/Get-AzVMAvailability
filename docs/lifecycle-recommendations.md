# Lifecycle Recommendations

[← Back to README](../README.md)

Analyze your current VM inventory to identify SKUs that need lifecycle planning (old generation, capacity-constrained, or deprecated) and get compatibility-validated replacement recommendations for each.

## Option 1: From a CSV/JSON file

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

## Option 2: From an Azure portal export (XLSX)

Export your VM list directly from the Azure portal (Virtual Machines blade → Export to CSV/Excel) and pass the XLSX file with no reformatting:

```powershell
.\Get-AzVMAvailability.ps1 -LifecycleRecommendations .\AzureVirtualMachines.xlsx -NoPrompt
```

The parser automatically maps the `SIZE` column to SKU and `LOCATION` to Region, converts display names (e.g., "West US" → `westus`, "USGov Virginia" → `usgovvirginia`), and aggregates one-VM-per-row into SKU+Region quantities. Requires the `ImportExcel` module.

## Option 3: Live scan from Azure (no file needed)

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

## What you get

For each SKU in your list:
1. **Hybrid recommendations (3 AI + up to 3 weighted)** — Up to 6 alternatives per SKU using a two-tier strategy:
   - **3 upgrade path recommendations** from a curated knowledge base ([`data/UpgradePath.json`](../data/UpgradePath.json)) based on Microsoft's official migration guidance:
     - `Upgrade: Drop-in` — lowest risk replacement (e.g., Dsv5 for Dv2)
     - `Upgrade: Future-proof` — latest generation (e.g., Dsv6 with NVMe)
     - `Upgrade: Cost-optimized` — AMD/alternative architecture at lower cost
   - **Up to 3 weighted recommendations** from the real-time 8-dimension scoring engine, validated against actual region availability, capacity, and quota
2. **Lifecycle risk assessment** — High / Medium / Low risk classification
3. **Quota analysis** — current quota usage vs. limit for both the target SKU family and the recommended replacement's family, factoring in VM quantity (Qty × vCPUs)
4. **Details column** — explains *why* each recommendation was selected (upgrade path rationale, family/version context, IOPS guarantees, resize impact, requirements like Gen2 OS or NVMe)
5. **Consolidated summary table** — all SKUs with Qty, region, risk level, quota status, and top replacement
6. **VM-count-aware summary** — footer shows total VM count at each risk level (e.g., "3 SKU(s) (35 VMs) at HIGH risk")

The upgrade path knowledge base covers 19 VM families (11 retired, 8 scheduled for retirement) with vCPU-matched size maps. See [`data/UpgradePath.md`](../data/UpgradePath.md) for the full reference.

Risk levels:
- **High** — Retired/retiring SKU, capacity issues, quota insufficient, or no compatible alternatives found
- **Medium** — Old generation (v3 or below); plan migration to current generation
- **Low** — Current generation with good availability and sufficient quota

## Pricing in Lifecycle Reports

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
