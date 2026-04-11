# Parameters

[← Back to README](../README.md)

| Parameter               | Type     | Description                                                                                                               |
| ----------------------- | -------- | ------------------------------------------------------------------------------------------------------------------------- |
| `-SubscriptionId`       | String[] | Azure subscription ID(s) to scan                                                                                          |
| `-Region`               | String[] | Azure region code(s) (e.g., 'eastus', 'westus2')                                                                          |
| `-RegionPreset`         | String   | Predefined region set (see [Region Presets](region-presets.md)). Auto-sets environment for sovereign clouds.               |
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
| `-JsonOutput`           | Switch   | Emit structured JSON for GitHub Copilot CLI, AI agent integration, or automation pipelines                                |
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

## Compatibility Gate

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

## Scoring Weights

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
