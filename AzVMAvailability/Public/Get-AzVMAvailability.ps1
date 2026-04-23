function Get-AzVMAvailability {
<#
.SYNOPSIS
    Get-AzVMAvailability - Comprehensive SKU availability and capacity scanner.

.DESCRIPTION
    Scans Azure regions for VM SKU availability and capacity status to help plan deployments.
    Provides a comprehensive view of:
    - All VM SKU families available in each region
    - Capacity status (OK, LIMITED, CAPACITY-CONSTRAINED, RESTRICTED)
    - Subscription-level restrictions
    - Available vCPU quota per family
    - Zone availability information
    - Multi-region comparison matrix

    Key features:
    - Parallel region scanning for speed (~5 seconds for 3 regions)
    - Scans ALL VM families automatically
    - Color-coded capacity reporting
    - Interactive drill-down by family/SKU
    - CSV/XLSX export with detailed breakdowns
    - Auto-detects Unicode support for icons

.PARAMETER SubscriptionId
    One or more Azure subscription IDs to scan. If not provided, prompts interactively.

.PARAMETER Region
    One or more Azure region codes to scan (e.g., 'eastus', 'westus2').
    If not provided, prompts interactively or uses defaults with -NoPrompt.

.PARAMETER ExportPath
    Directory path for CSV/XLSX export. If not specified with -AutoExport, uses:
    - Cloud Shell: /home/system
    - Local: C:\Temp\AzVMAvailability

.PARAMETER AutoExport
    Automatically export results without prompting.

.PARAMETER EnableDrillDown
    Enable interactive drill-down to select specific families and SKUs.

.PARAMETER FamilyFilter
    Pre-filter results to specific VM families (e.g., 'D', 'E', 'F').

.PARAMETER SkuFilter
    Filter to specific SKU names. Supports wildcards (e.g., 'Standard_D*_v5').

.PARAMETER ShowPricing
    Show hourly/monthly pricing for VM SKUs.
    Auto-detects negotiated rates (EA/MCA/CSP) via Cost Management API.
    Falls back to retail pricing if negotiated rates unavailable.
    Adds ~5-10 seconds to execution time.

.PARAMETER ShowSpot
    Include Spot VM pricing in pricing-enabled outputs.

.PARAMETER ImageURN
    Check SKU compatibility with a specific VM image.
    Format: Publisher:Offer:Sku:Version (e.g., 'Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest')
    Shows Gen/Arch columns and Img compatibility in drill-down view.

.PARAMETER CompactOutput
    Use compact output format for narrow terminals.
    Automatically enabled when terminal width is less than 150 characters.

.PARAMETER NoPrompt
    Skip all interactive prompts. Uses defaults or provided parameters.

.PARAMETER OutputFormat
    Export format: 'Auto' (detects XLSX capability), 'CSV', or 'XLSX'.
    Default is 'Auto'.

.PARAMETER UseAsciiIcons
    Force ASCII icons [+] [!] [-] instead of Unicode ✓ ⚠ ✗.
    By default, auto-detects terminal capability.

.PARAMETER Environment
    Azure cloud environment override. Auto-detects from Az context if not specified.
    Options: AzureCloud, AzureUSGovernment, AzureChinaCloud

.PARAMETER RegionPreset
    Predefined region sets for common scenarios (e.g., USMajor, Europe, USGov).
    Auto-sets cloud environment for sovereign cloud presets.

.PARAMETER MaxRetries
    Max retry attempts for transient API errors (429, 503, timeouts). Default 3, range 0-10.

.PARAMETER Recommend
    Find alternatives for a target SKU that may be unavailable or capacity-constrained.
    Scans specified regions, scores all available SKUs by similarity to the target
    (vCPU, memory, family category, VM generation, CPU architecture), and returns
    the closest available alternatives ranked by score.
    Accepts full name ('Standard_E64pds_v6') or short name ('E64pds_v6').
    Can be used with interactive drill-down mode; if not pre-specified, user is prompted
    to enter a SKU during interactive exploration to find alternatives.

.PARAMETER TopN
    Number of alternative SKUs to return in Recommend mode. Default 5, max 25.

.PARAMETER MinScore
    Minimum similarity score (0-100) for recommended alternatives. Defaults to 50.
    Set to 0 to show all candidates.

.PARAMETER MinvCPU
    Minimum vCPU count for recommended alternatives. SKUs below this are excluded.
    If smaller SKUs have better availability, a suggestion note is shown.

.PARAMETER MinMemoryGB
    Minimum memory in GB for recommended alternatives. SKUs below this are excluded.
    If smaller SKUs have better availability, a suggestion note is shown.

.PARAMETER JsonOutput
    Emit structured JSON instead of console tables. Designed for the AzVMAvailability-Agent
    (https://github.com/ZacharyLuz/AzVMAvailability-Agent) which parses this output to
    provide conversational VM recommendations via natural language. Also useful for
    piping results into other tools or storing scan results programmatically.

.PARAMETER SkipRegionValidation
    Skip all validation of region names against Azure region metadata.
    Use this only when Azure metadata lookup is unavailable; otherwise, mistyped or
    unsupported region names may not be detected. By default (without this switch),
    non-interactive mode fails closed when region validation is unavailable to prevent
    scans against invalid regions.

.NOTES
    Name:           Get-AzVMAvailability
    Author:         Zachary Luz
    Created:        2026-01-21
    Version:        2.1.1
    License:        MIT
    Repository:     https://github.com/zacharyluz/Get-AzVMAvailability

    Requirements:   Az.Compute, Az.Resources modules
                    PowerShell 7+ (required)

    DISCLAIMER
    The author is a Microsoft employee; however, this is a personal open-source
    project. It is not an official Microsoft product, nor is it endorsed,
    sponsored, or supported by Microsoft.

    This sample script is not supported under any Microsoft standard support
    program or service. The sample script is provided AS IS without warranty
    of any kind. Microsoft further disclaims all implied warranties including,
    without limitation, any implied warranties of merchantability or of fitness
    for a particular purpose. The entire risk arising out of the use or
    performance of the sample scripts and documentation remains with you.

.EXAMPLE
    .\Get-AzVMAvailability.ps1
    Run interactively with prompts for all options.

.EXAMPLE
    .\Get-AzVMAvailability.ps1 -Region "eastus","westus2" -AutoExport
    Scan specified regions with current subscription, auto-export results.

.EXAMPLE
    .\Get-AzVMAvailability.ps1 -NoPrompt -Region "eastus","centralus","westus2"
    Fully automated scan of three regions using current subscription context.

.EXAMPLE
    .\Get-AzVMAvailability.ps1 -EnableDrillDown -FamilyFilter "D","E","M"
    Interactive mode focused on D, E, and M series families.

.EXAMPLE
    .\Get-AzVMAvailability.ps1 -SkuFilter "Standard_D2s_v3","Standard_E4s_v5" -Region "eastus"
    Filter to show only specific SKUs in eastus region.

.EXAMPLE
    .\Get-AzVMAvailability.ps1 -SkuFilter "Standard_D*_v5" -Region "eastus","westus2"
    Use wildcard to filter all D-series v5 SKUs across multiple regions.

.EXAMPLE
    .\Get-AzVMAvailability.ps1 -ShowPricing -Region "eastus"
    Include estimated hourly pricing for VM SKUs in eastus.

.EXAMPLE
    .\Get-AzVMAvailability.ps1 -ImageURN "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest" -Region "eastus"
    Check SKU compatibility with Ubuntu 22.04 Gen2 image.

.EXAMPLE
    .\Get-AzVMAvailability.ps1 -ImageURN "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-arm64:latest" -SkuFilter "Standard_D*ps*"
    Find ARM64-compatible SKUs for Ubuntu ARM64 image.

.EXAMPLE
    .\Get-AzVMAvailability.ps1 -NoPrompt -ShowPricing -Region "eastus","westus2"
    Automated scan with pricing enabled, no interactive prompts.

.EXAMPLE
    .\Get-AzVMAvailability.ps1 -RegionPreset USEastWest -NoPrompt
    Scan US East/West regions (eastus, eastus2, westus, westus2) using a preset.

.EXAMPLE
    .\Get-AzVMAvailability.ps1 -RegionPreset ASR-EastWest -FamilyFilter "D","E" -ShowPricing
    Check DR region pair for Azure Site Recovery planning with pricing.

.EXAMPLE
    .\Get-AzVMAvailability.ps1 -RegionPreset Europe -NoPrompt -AutoExport
    Scan all major European regions with auto-export.

.EXAMPLE
    .\Get-AzVMAvailability.ps1 -RegionPreset USGov -NoPrompt
    Scan Azure Government regions (auto-sets environment to AzureUSGovernment).

.EXAMPLE
    .\Get-AzVMAvailability.ps1 -Recommend "Standard_E64pds_v6" -Region "eastus","westus2","centralus"
    Find alternatives to E64pds_v6 across three regions, ranked by similarity.

.EXAMPLE
    .\Get-AzVMAvailability.ps1 -Recommend "Standard_E64pds_v6" -RegionPreset USMajor -MinScore 0
    Show all candidates regardless of similarity score (useful when capacity is constrained).

.EXAMPLE
    .\Get-AzVMAvailability.ps1 -Recommend "E64pds_v6" -RegionPreset USMajor -TopN 10
    Find top 10 alternatives across major US regions (Standard_ prefix auto-added).

.EXAMPLE
    .\Get-AzVMAvailability.ps1 -Recommend "Standard_D4s_v5" -Region "eastus" -JsonOutput -NoPrompt
    Emit structured JSON instead of console tables. Designed for the AzVMAvailability-Agent
    (https://github.com/ZacharyLuz/AzVMAvailability-Agent) which parses this output to
    provide conversational VM recommendations. Also useful for piping into other tools
    or storing scan results programmatically.

.EXAMPLE
    .\Get-AzVMAvailability.ps1 -InventoryFile .\inventory.csv -Region "eastus" -NoPrompt
    Load an inventory BOM from CSV file. The CSV needs SKU and Qty columns:
    SKU,Qty
    Standard_D2s_v5,17
    Standard_D4s_v5,4
    Standard_D8s_v5,5

.EXAMPLE
    .\Get-AzVMAvailability.ps1 -Inventory @{'Standard_D2s_v5'=17; 'Standard_D4s_v5'=4; 'Standard_D8s_v5'=5} -Region "eastus" -NoPrompt
    Inline inventory BOM using PowerShell hashtable syntax.

.EXAMPLE
    .\Get-AzVMAvailability.ps1 -GenerateInventoryTemplate
    Creates inventory-template.csv and inventory-template.json in the current directory.
    Edit the files with your VM SKUs and quantities, then run:
    .\Get-AzVMAvailability.ps1 -InventoryFile .\inventory-template.csv -Region "eastus" -NoPrompt

.EXAMPLE
    .\Get-AzVMAvailability.ps1 -LifecycleRecommendations
    Lifecycle analysis: pulls live VM inventory from Azure Resource Graph and runs
    compatibility-validated recommendations with pricing, savings plan/reservation
    details, quota, and auto-exports to Excel in the current directory.

.EXAMPLE
    .\Get-AzVMAvailability.ps1 -LifecycleRecommendations -LifecycleFile .\my-vms.csv -Region "eastus"
    Lifecycle analysis from file: loads a list of current VM SKUs from a CSV/JSON/XLSX,
    runs recommendations for each, and produces a consolidated risk summary.
    The file supports optional columns: Region (deployed location) and Qty (VM count).
    When Qty is provided, quota is checked against the required vCPUs (Qty x vCPU)
    for both the current SKU and the recommended replacement.

.EXAMPLE
    .\Get-AzVMAvailability.ps1
    Run interactively. After exploring regions and families, you'll be prompted to optionally
    enter recommend mode to find alternatives for a specific SKU.

.LINK
    https://github.com/zacharyluz/Get-AzVMAvailability
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false, HelpMessage = "Azure subscription ID(s) to scan")]
    [Alias("SubId", "Subscription")]
    [string[]]$SubscriptionId,

    [Parameter(Mandatory = $false, HelpMessage = "Azure region(s) to scan")]
    [Alias("Location")]
    [string[]]$Region,

    [Parameter(Mandatory = $false, HelpMessage = "Predefined region sets for common scenarios")]
    [ValidateSet("USEastWest", "USCentral", "USMajor", "Europe", "AsiaPacific", "Global", "USGov", "China", "ASR-EastWest", "ASR-CentralUS")]
    [string]$RegionPreset,

    [Parameter(Mandatory = $false, HelpMessage = "Directory path for export")]
    [string]$ExportPath,

    [Parameter(Mandatory = $false, HelpMessage = "Automatically export results")]
    [switch]$AutoExport,

    [Parameter(Mandatory = $false, HelpMessage = "Enable interactive family/SKU drill-down")]
    [switch]$EnableDrillDown,

    [Parameter(Mandatory = $false, HelpMessage = "Pre-filter to specific VM families")]
    [string[]]$FamilyFilter,

    [Parameter(Mandatory = $false, HelpMessage = "Filter to specific SKUs (supports wildcards)")]
    [string[]]$SkuFilter,

    [Parameter(Mandatory = $false, HelpMessage = "Show hourly pricing (auto-detects negotiated rates, falls back to retail)")]
    [switch]$ShowPricing,

    [Parameter(Mandatory = $false, HelpMessage = "Include Spot VM pricing in outputs when pricing is enabled")]
    [switch]$ShowSpot,

    [Parameter(Mandatory = $false, HelpMessage = "Show allocation likelihood scores (High/Medium/Low) from Azure placement API")]
    [switch]$ShowPlacement,

    [Parameter(Mandatory = $false, HelpMessage = "Desired VM count for placement score API")]
    [ValidateRange(1, 1000)]
    [int]$DesiredCount = 1,

    [Parameter(Mandatory = $false, HelpMessage = "VM image URN to check compatibility (format: Publisher:Offer:Sku:Version)")]
    [string]$ImageURN,

    [Parameter(Mandatory = $false, HelpMessage = "Use compact output for narrow terminals")]
    [switch]$CompactOutput,

    [Parameter(Mandatory = $false, HelpMessage = "Skip all interactive prompts")]
    [switch]$NoPrompt,

    [Parameter(Mandatory = $false, HelpMessage = "Skip quota checks (use when analyzing a customer extract without subscription access)")]
    [switch]$NoQuota,

    [Parameter(Mandatory = $false, HelpMessage = "Export format: Auto, CSV, or XLSX")]
    [ValidateSet("Auto", "CSV", "XLSX")]
    [string]$OutputFormat = "Auto",

    [Parameter(Mandatory = $false, HelpMessage = "Force ASCII icons instead of Unicode")]
    [switch]$UseAsciiIcons,

    [Parameter(Mandatory = $false, HelpMessage = "Azure cloud environment (default: auto-detect from Az context)")]
    [ValidateSet("AzureCloud", "AzureUSGovernment", "AzureChinaCloud")]
    [string]$Environment,

    [Parameter(Mandatory = $false, HelpMessage = "Max retry attempts for transient API errors (429, 503, timeouts)")]
    [ValidateRange(0, 10)]
    [int]$MaxRetries = 3,

    [Parameter(Mandatory = $false, HelpMessage = "Find alternatives for a target SKU (e.g., 'Standard_E64pds_v6')")]
    [string]$Recommend,

    [Parameter(Mandatory = $false, HelpMessage = "Number of alternative SKUs to return (default 5)")]
    [ValidateRange(1, 25)]
    [int]$TopN = 5,

    [Parameter(Mandatory = $false, HelpMessage = "Minimum similarity score (0-100) for recommended alternatives; set 0 to show all")]
    [ValidateRange(0, 100)]
    [int]$MinScore,

    [Parameter(Mandatory = $false, HelpMessage = "Minimum vCPU count for recommended alternatives")]
    [ValidateRange(1, 416)]
    [int]$MinvCPU,

    [Parameter(Mandatory = $false, HelpMessage = "Minimum memory in GB for recommended alternatives")]
    [ValidateRange(1, 12288)]
    [int]$MinMemoryGB,

    [Parameter(Mandatory = $false, HelpMessage = "Emit structured JSON output for automation/agent consumption")]
    [switch]$JsonOutput,

    [Parameter(Mandatory = $false, HelpMessage = "Allow mixed CPU architectures (x64/ARM64) in recommendations (default: filter to target arch)")]
    [switch]$AllowMixedArch,

    [Parameter(Mandatory = $false, HelpMessage = "Skip validation of region names against Azure metadata")]
    [switch]$SkipRegionValidation,

    [Parameter(Mandatory = $false, HelpMessage = "Inventory BOM: hashtable of SKU=Quantity pairs for inventory readiness validation (e.g., @{'Standard_D2s_v5'=17; 'Standard_D4s_v5'=4})")]
    [Alias('Fleet')]
    [hashtable]$Inventory,

    [Parameter(Mandatory = $false, HelpMessage = "Path to a CSV or JSON inventory BOM file. CSV: columns SKU,Qty. JSON: array of {SKU:'...',Qty:N} objects. Duplicate SKUs are summed.")]
    [Alias('FleetFile')]
    [string]$InventoryFile,

    [Parameter(Mandatory = $false, HelpMessage = "Generate inventory-template.csv and inventory-template.json in the current directory, then exit. No Azure login required.")]
    [Alias('GenerateFleetTemplate')]
    [switch]$GenerateInventoryTemplate,

    [Parameter(Mandatory = $false, HelpMessage = "Include Savings Plan and Reserved Instance pricing columns in lifecycle reports. Requires -ShowPricing. Without this flag, only PAYG pricing is shown.")]
    [switch]$RateOptimization,

    [Parameter(Mandatory = $false, HelpMessage = "Run lifecycle recommendations with auto-enabled pricing, Excel export, savings plan/reservation details, and quota. Without -LifecycleFile, pulls live VM inventory from Azure via Resource Graph. With -LifecycleFile, loads SKUs from a CSV/JSON/XLSX file.")]
    [switch]$LifecycleRecommendations,

    [Parameter(Mandatory = $false, HelpMessage = "Path to a CSV, JSON, or XLSX file listing current VM SKUs for lifecycle analysis. Use with -LifecycleRecommendations. CSV: column SKU (or Size/VmSize). JSON: array of {SKU:'...'} objects. Qty column is optional. XLSX: supports native Azure portal VM exports (maps SIZE/LOCATION columns automatically).")]
    [string]$LifecycleFile,

    [Parameter(Mandatory = $false, HelpMessage = "Pull live VM inventory from Azure via Resource Graph for lifecycle analysis. Scopes to -SubscriptionId if specified; use -ManagementGroup or -ResourceGroup for further filtering.")]
    [switch]$LifecycleScan,

    [Parameter(Mandatory = $false, HelpMessage = "Filter -LifecycleScan to specific management group(s). Requires Az.ResourceGraph module.")]
    [string[]]$ManagementGroup,

    [Parameter(Mandatory = $false, HelpMessage = "Filter -LifecycleScan to specific resource group(s).")]
    [string[]]$ResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "Filter -LifecycleScan to VMs with specific tags. Hashtable of key=value pairs, e.g. @{Environment='prod'}. Use '*' as value to match any VM that has the tag key regardless of value.")]
    [Alias("Tags")]
    [hashtable]$Tag,

    [Parameter(Mandatory = $false, HelpMessage = "Add a 'Subscription Map' sheet to the lifecycle XLSX showing VM counts grouped by subscription, region, and SKU. Requires -LifecycleScan.")]
    [switch]$SubMap,

    [Parameter(Mandatory = $false, HelpMessage = "Add a 'Resource Group Map' sheet to the lifecycle XLSX showing VM counts grouped by resource group, subscription, region, and SKU. Requires -LifecycleScan.")]
    [switch]$RGMap
)

    # Set console suppression for this invocation (module-scope flag)
    $script:SuppressConsole = $JsonOutput.IsPresent

    $ProgressPreference = 'SilentlyContinue'

#region GenerateInventoryTemplate
if ($GenerateInventoryTemplate) {
    if ($JsonOutput) { throw "Cannot use -GenerateInventoryTemplate with -JsonOutput. Template generation writes files to disk, not JSON to stdout." }
    $csvPath = Join-Path $PWD 'inventory-template.csv'
    $jsonPath = Join-Path $PWD 'inventory-template.json'
    $csvContent = @"
SKU,Qty
Standard_D2s_v5,10
Standard_D4s_v5,5
Standard_D8s_v5,3
Standard_E4s_v5,2
Standard_E16s_v5,1
"@
    $jsonContent = @"
[
  { "SKU": "Standard_D2s_v5", "Qty": 10 },
  { "SKU": "Standard_D4s_v5", "Qty": 5 },
  { "SKU": "Standard_D8s_v5", "Qty": 3 },
  { "SKU": "Standard_E4s_v5", "Qty": 2 },
  { "SKU": "Standard_E16s_v5", "Qty": 1 }
]
"@
    Set-Content -Path $csvPath -Value $csvContent -Encoding utf8
    Set-Content -Path $jsonPath -Value $jsonContent -Encoding utf8
    Write-Host "Created inventory templates:" -ForegroundColor Green
    Write-Host "  CSV: $csvPath" -ForegroundColor Cyan
    Write-Host "  JSON: $jsonPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Edit the template with your VM SKUs and quantities"
    Write-Host "  2. Run: .\Get-AzVMAvailability.ps1 -InventoryFile .\inventory-template.csv -Region 'eastus' -NoPrompt"
    return
}
#endregion GenerateInventoryTemplate

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "PowerShell 7+ is required to run Get-AzVMAvailability.ps1."
    Write-Host "Current host: $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
    Write-Host "Install PowerShell 7 and rerun with: pwsh -File .\Get-AzVMAvailability.ps1" -ForegroundColor Cyan
    throw "PowerShell 7+ is required. Current version: $($PSVersionTable.PSVersion)"
}

# Normalize string[] params — pwsh -File passes comma-delimited values as a single string
foreach ($paramName in @('SubscriptionId', 'Region', 'FamilyFilter', 'SkuFilter', 'ManagementGroup', 'ResourceGroup')) {
    $val = Get-Variable -Name $paramName -ValueOnly -ErrorAction SilentlyContinue
    if ($val -and $val.Count -eq 1 -and $val[0] -match ',') {
        Set-Variable -Name $paramName -Value @($val[0] -split ',' | ForEach-Object { $_.Trim().Trim('"', "'") } | Where-Object { $_ })
    }
}

# Guard: -ManagementGroup, -ResourceGroup, and -Tag only valid with -LifecycleScan
if (($ManagementGroup -or $ResourceGroup -or $Tag) -and -not $LifecycleScan) {
    throw "-ManagementGroup, -ResourceGroup, and -Tag require -LifecycleScan. Use -LifecycleScan to pull live VM inventory."
}

# InventoryFile: load CSV/JSON into $Inventory hashtable
if ($InventoryFile) {
    if ($Inventory) { throw "Cannot specify both -Inventory and -InventoryFile. Use one or the other." }
    if (-not (Test-Path -LiteralPath $InventoryFile -PathType Leaf)) { throw "Inventory file not found or is not a file: $InventoryFile" }
    $ext = [System.IO.Path]::GetExtension($InventoryFile).ToLower()
    if ($ext -notin '.csv', '.json') { throw "Unsupported file type '$ext'. InventoryFile must be .csv or .json" }
    if ($ext -eq '.json') {
        $jsonData = @(Get-Content -LiteralPath $InventoryFile -Raw | ConvertFrom-Json)
        $Inventory = @{}
        foreach ($item in $jsonData) {
            $skuProp = ($item.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
            $qtyProp = ($item.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
            if ($skuProp -and $qtyProp) {
                $skuClean = $skuProp.Trim()
                $qtyInt = [int]$qtyProp
                if ($qtyInt -le 0) { throw "Invalid quantity '$qtyProp' for SKU '$skuClean'. Qty must be a positive integer." }
                if ($Inventory.ContainsKey($skuClean)) { $Inventory[$skuClean] += $qtyInt }
                else { $Inventory[$skuClean] = $qtyInt }
            }
        }
    }
    else {
        $csvData = Import-Csv -LiteralPath $InventoryFile
        $Inventory = @{}
        foreach ($row in $csvData) {
            $skuProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
            $qtyProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
            if ($skuProp -and $qtyProp) {
                $skuClean = $skuProp.Trim()
                $qtyInt = [int]$qtyProp
                if ($qtyInt -le 0) { throw "Invalid quantity '$qtyProp' for SKU '$skuClean'. Qty must be a positive integer." }
                if ($Inventory.ContainsKey($skuClean)) { $Inventory[$skuClean] += $qtyInt }
                else { $Inventory[$skuClean] = $qtyInt }
            }
        }
    }
    if ($Inventory.Count -eq 0) { throw "No valid SKU/Qty rows found in $InventoryFile. Expected columns: SKU (or Name/VmSize), Qty (or Quantity/Count)" }
    if (-not $JsonOutput) { Write-Host "Loaded $($Inventory.Count) SKUs from $InventoryFile" -ForegroundColor Cyan }
}

# Inventory mode: normalize keys (strip double-prefix) and derive SkuFilter
if ($Inventory -and $Inventory.Count -gt 0) {
    $normalizedInventory = @{}
    foreach ($key in @($Inventory.Keys)) {
        $clean = $key -replace '^Standard_Standard_', 'Standard_'
        if ($clean -notmatch '^Standard_') { $clean = "Standard_$clean" }
        $normalizedInventory[$clean] = $Inventory[$key]
    }
    $Inventory = $normalizedInventory
    $SkuFilter = @($Inventory.Keys)
    Write-Verbose "Inventory mode: derived SkuFilter from $($Inventory.Count) Inventory SKUs"
}

# LifecycleRecommendations: load from file (-LifecycleFile) or fall through to live ARG scan
if ($LifecycleRecommendations -and $LifecycleFile) {
    if ($LifecycleScan) { throw "Cannot specify both -LifecycleRecommendations and -LifecycleScan. Use one or the other." }
    if ($Recommend) { throw "Cannot specify both -Recommend and -LifecycleRecommendations. Use one or the other." }
    if ($Inventory -or $InventoryFile) { throw "Cannot specify both -LifecycleRecommendations and -Inventory/-InventoryFile. They are separate modes." }
    if (-not (Test-Path -LiteralPath $LifecycleFile -PathType Leaf)) { throw "Lifecycle file not found or is not a file: $LifecycleFile" }
    $ext = [System.IO.Path]::GetExtension($LifecycleFile).ToLower()
    if ($ext -notin '.csv', '.json', '.xlsx') { throw "Unsupported file type '$ext'. -LifecycleFile must be .csv, .json, or .xlsx" }
    if ($ext -eq '.xlsx' -and -not (Get-Module -ListAvailable ImportExcel)) { throw "ImportExcel module required for .xlsx files. Install with: Install-Module ImportExcel -Scope CurrentUser" }
    $lifecycleEntries = [System.Collections.Generic.List[PSCustomObject]]::new()
    $compositeKeys = @{}
    # When -SubMap or -RGMap is set, capture per-row subscription/RG data for the deployment map
    $captureDeploymentMap = ($SubMap -or $RGMap)
    if ($captureDeploymentMap) { $fileVMRows = [System.Collections.Generic.List[PSCustomObject]]::new() }
    $parseRow = {
        param($item)
        $skuProp = ($item.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Size|VmSize)$' } | Select-Object -First 1).Value
        if (-not $skuProp) { $skuProp = ($item.PSObject.Properties | Where-Object { $_.Name -match '^(Name|Intel\.SKU)$' } | Select-Object -First 1).Value }
        $regionProp = ($item.PSObject.Properties | Where-Object { $_.Name -match '^(Region|Location|AzureRegion)$' } | Select-Object -First 1).Value
        $qtyProp = ($item.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
        if ($skuProp) {
            $clean = $skuProp.Trim() -replace '^Standard_Standard_', 'Standard_'
            if ($clean -notmatch '^Standard_') { $clean = "Standard_$clean" }
            $regionClean = if ($regionProp) { ($regionProp.Trim() -replace '\s', '').ToLower() } else { $null }
            $qty = if ($qtyProp) { [int]$qtyProp } else { 1 }
            if ($qty -le 0) { throw "Invalid quantity '$qtyProp' for SKU '$clean'. Qty must be a positive integer." }
            $compositeKey = "$clean|$regionClean"
            if ($compositeKeys.ContainsKey($compositeKey)) {
                $existingIdx = $compositeKeys[$compositeKey]
                $existing = $lifecycleEntries[$existingIdx]
                $lifecycleEntries[$existingIdx] = [pscustomobject]@{ SKU = $clean; Region = $regionClean; Qty = $existing.Qty + $qty }
            }
            else {
                $compositeKeys[$compositeKey] = $lifecycleEntries.Count
                $lifecycleEntries.Add([pscustomobject]@{ SKU = $clean; Region = $regionClean; Qty = $qty })
            }
            # Capture per-row sub/RG data for deployment map
            if ($captureDeploymentMap) {
                $subIdProp = ($item.PSObject.Properties | Where-Object { $_.Name -match '^(SubscriptionId|Subscription_Id|SUBSCRIPTION ID)$' } | Select-Object -First 1).Value
                # Extract subscription ID from RESOURCE LINK URL if not found in a dedicated column
                if (-not $subIdProp) {
                    $linkProp = ($item.PSObject.Properties | Where-Object { $_.Name -match '^(RESOURCE LINK|ResourceLink|Resource_Link)$' } | Select-Object -First 1).Value
                    if ($linkProp -and $linkProp -match '/subscriptions/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') {
                        $subIdProp = $matches[1]
                    }
                }
                $subNameProp = ($item.PSObject.Properties | Where-Object { $_.Name -match '^(SubscriptionName|Subscription_Name|SUBSCRIPTION)$' } | Select-Object -First 1).Value
                $rgProp = ($item.PSObject.Properties | Where-Object { $_.Name -match '^(ResourceGroup|Resource_Group|RESOURCE GROUP)$' } | Select-Object -First 1).Value
                $fileVMRows.Add([pscustomobject]@{
                    subscriptionId   = if ($subIdProp) { $subIdProp.Trim() } else { '' }
                    subscriptionName = if ($subNameProp) { $subNameProp.Trim() } else { '' }
                    resourceGroup    = if ($rgProp) { $rgProp.Trim() } else { '' }
                    location         = $regionClean
                    vmSize           = $clean
                    qty              = $qty
                })
            }
        }
    }
    if ($ext -eq '.json') {
        $jsonData = @(Get-Content -LiteralPath $LifecycleFile -Raw | ConvertFrom-Json)
        foreach ($item in $jsonData) { & $parseRow $item }
    }
    elseif ($ext -eq '.xlsx') {
        $xlsxData = Import-Excel -Path $LifecycleFile
        foreach ($row in $xlsxData) { & $parseRow $row }
    }
    else {
        $csvData = Import-Csv -LiteralPath $LifecycleFile
        foreach ($row in $csvData) { & $parseRow $row }
    }
    if ($lifecycleEntries.Count -eq 0) { throw "No valid SKU rows found in $LifecycleFile. Expected column: SKU, Size, or VmSize (falls back to Name)" }
    $SkuFilter = @($lifecycleEntries | ForEach-Object { $_.SKU })

    # Auto-merge per-SKU regions into the -Region parameter so all needed regions get scanned
    $fileRegions = @($lifecycleEntries | Where-Object { $_.Region } | ForEach-Object { $_.Region } | Select-Object -Unique)
    if ($fileRegions.Count -gt 0) {
        if ($Region) {
            $mergedRegions = @($Region) + @($fileRegions) | Select-Object -Unique
            $Region = @($mergedRegions)
        }
        else {
            $Region = @($fileRegions)
        }
        Write-Verbose "Lifecycle mode: merged $($fileRegions.Count) file region(s) into scan regions: $($Region -join ', ')"
    }

    $totalVMs = ($lifecycleEntries | Measure-Object -Property Qty -Sum).Sum
    if (-not $JsonOutput) { Write-Host "Lifecycle analysis: loaded $($lifecycleEntries.Count) SKU entries ($totalVMs VMs) from $LifecycleFile" -ForegroundColor Cyan }

    #region Build Deployment Map from File Data (-SubMap / -RGMap)
    if ($captureDeploymentMap -and $fileVMRows.Count -gt 0) {
        $hasSubData = $fileVMRows | Where-Object { $_.subscriptionId -or $_.subscriptionName } | Select-Object -First 1
        $hasRGData = $fileVMRows | Where-Object { $_.resourceGroup } | Select-Object -First 1
        if ($RGMap -and -not $hasRGData) {
            Write-Warning "-RGMap: No ResourceGroup column found in file. The Resource Group Map sheet will show empty resource group values."
        }
        if (-not $hasSubData) {
            Write-Warning "$(if ($SubMap) { '-SubMap' } else { '-RGMap' }): No SubscriptionId/SubscriptionName column found in file. The map sheet will show empty subscription values."
        }
        if ($SubMap) {
            $subMapRows = [System.Collections.Generic.List[PSCustomObject]]::new()
            $grouped = $fileVMRows | Group-Object -Property subscriptionId, subscriptionName, location, vmSize
            foreach ($g in $grouped) {
                $sample = $g.Group[0]
                $subMapRows.Add([pscustomobject]@{
                    SubscriptionId   = $sample.subscriptionId
                    SubscriptionName = if ($sample.subscriptionName) { $sample.subscriptionName } else { $sample.subscriptionId }
                    Region           = $sample.location
                    SKU              = $sample.vmSize
                    Qty              = ($g.Group | Measure-Object -Property qty -Sum).Sum
                })
            }
            $subMapRows = [System.Collections.Generic.List[PSCustomObject]]@($subMapRows | Sort-Object SubscriptionName, Region, SKU)
            if (-not $JsonOutput) { Write-Host "Subscription map: $($subMapRows.Count) rows" -ForegroundColor Cyan }
        }
        if ($RGMap) {
            $rgMapRows = [System.Collections.Generic.List[PSCustomObject]]::new()
            $grouped = $fileVMRows | Group-Object -Property subscriptionId, subscriptionName, resourceGroup, location, vmSize
            foreach ($g in $grouped) {
                $sample = $g.Group[0]
                $rgMapRows.Add([pscustomobject]@{
                    SubscriptionId   = $sample.subscriptionId
                    SubscriptionName = if ($sample.subscriptionName) { $sample.subscriptionName } else { $sample.subscriptionId }
                    ResourceGroup    = $sample.resourceGroup
                    Region           = $sample.location
                    SKU              = $sample.vmSize
                    Qty              = ($g.Group | Measure-Object -Property qty -Sum).Sum
                })
            }
            $rgMapRows = [System.Collections.Generic.List[PSCustomObject]]@($rgMapRows | Sort-Object SubscriptionName, ResourceGroup, Region, SKU)
            if (-not $JsonOutput) { Write-Host "Resource Group map: $($rgMapRows.Count) rows" -ForegroundColor Cyan }
        }
    }
    #endregion Build Deployment Map from File Data
}

# -LifecycleRecommendations without -LifecycleFile: use live ARG scan
if ($LifecycleRecommendations -and -not $LifecycleFile -and -not $lifecycleEntries) {
    $LifecycleScan = [switch]::new($true)
}

# Guard: -LifecycleFile requires -LifecycleRecommendations
if ($LifecycleFile -and -not $LifecycleRecommendations) {
    throw "-LifecycleFile requires -LifecycleRecommendations. Use: -LifecycleRecommendations -LifecycleFile '$LifecycleFile'"
}

# Validate -SubMap / -RGMap require a lifecycle mode
if (($SubMap -or $RGMap) -and -not $LifecycleScan -and -not $LifecycleRecommendations) {
    throw "-SubMap and -RGMap require -LifecycleScan or -LifecycleRecommendations."
}

# LifecycleScan: pull live VM inventory from Azure Resource Graph
if ($LifecycleScan) {
    if ($Recommend) { throw "Cannot specify both -Recommend and -LifecycleScan. Use one or the other." }
    if ($Inventory -or $InventoryFile) { throw "Cannot specify both -LifecycleScan and -Inventory/-InventoryFile. They are separate modes." }
    if ($ManagementGroup -and $SubscriptionId) { throw "Cannot specify both -ManagementGroup and -SubscriptionId for -LifecycleScan. Use one or the other." }
    if (-not $ManagementGroup -and -not $SubscriptionId) {
        $currentCtx = Get-AzContext -ErrorAction SilentlyContinue
        if (-not $currentCtx -or -not $currentCtx.Subscription) { throw "No Azure context found. Run Connect-AzAccount first, or specify -SubscriptionId or -ManagementGroup." }
    }
    if (-not (Get-Module -ListAvailable Az.ResourceGraph)) { throw "Az.ResourceGraph module required for -LifecycleScan. Install with: Install-Module Az.ResourceGraph -Scope CurrentUser" }
    Import-Module Az.ResourceGraph -ErrorAction Stop

    # Build ARG query with optional resource group and tag filters
    $argQuery = "Resources`n| where type =~ 'microsoft.compute/virtualmachines'"
    if ($ResourceGroup) {
        $rgFilter = ($ResourceGroup | ForEach-Object { "'$($_ -replace "'", "''")'" }) -join ', '
        $argQuery += "`n| where resourceGroup in~ ($rgFilter)"
    }
    if ($Tag -and $Tag.Count -gt 0) {
        foreach ($tagKey in $Tag.Keys) {
            $safeKey = $tagKey -replace "'", "''"
            $tagVal = $Tag[$tagKey]
            if ($tagVal -eq '*') {
                $argQuery += "`n| where isnotnull(tags['$safeKey'])"
            }
            else {
                $safeVal = [string]$tagVal -replace "'", "''"
                $argQuery += "`n| where tags['$safeKey'] =~ '$safeVal'"
            }
        }
    }
    $argQuery += "`n| extend vmSize = tostring(properties.hardwareProfile.vmSize)"
    $argQuery += "`n| project vmSize, location, subscriptionId, resourceGroup"

    if (-not $JsonOutput) { Write-Host "Querying Azure Resource Graph for live VM inventory..." -ForegroundColor Cyan }

    # Execute ARG query with pagination
    $argParams = @{ Query = $argQuery; First = 1000 }
    if ($ManagementGroup) { $argParams['ManagementGroup'] = $ManagementGroup }
    elseif ($SubscriptionId) { $argParams['Subscription'] = $SubscriptionId }

    $allVMs = [System.Collections.Generic.List[PSCustomObject]]::new()
    do {
        $result = Search-AzGraph @argParams
        if ($result) {
            foreach ($vm in $result) { $allVMs.Add($vm) }
            if ($result.SkipToken) { $argParams['SkipToken'] = $result.SkipToken }
            else { break }
        }
        else { break }
    } while ($true)

    if ($allVMs.Count -eq 0) { throw "No VMs found matching the specified scope. Check your -SubscriptionId, -ManagementGroup, -ResourceGroup, or -Tag filters." }

    # Aggregate into lifecycle entries (same format as file-based input)
    $lifecycleEntries = [System.Collections.Generic.List[PSCustomObject]]::new()
    $compositeKeys = @{}
    foreach ($vm in $allVMs) {
        $clean = $vm.vmSize.Trim() -replace '^Standard_Standard_', 'Standard_'
        if ($clean -notmatch '^Standard_') { $clean = "Standard_$clean" }
        $regionClean = $vm.location.ToLower()
        $compositeKey = "$clean|$regionClean"
        if ($compositeKeys.ContainsKey($compositeKey)) {
            $existingIdx = $compositeKeys[$compositeKey]
            $existing = $lifecycleEntries[$existingIdx]
            $lifecycleEntries[$existingIdx] = [pscustomobject]@{ SKU = $clean; Region = $regionClean; Qty = $existing.Qty + 1 }
        }
        else {
            $compositeKeys[$compositeKey] = $lifecycleEntries.Count
            $lifecycleEntries.Add([pscustomobject]@{ SKU = $clean; Region = $regionClean; Qty = 1 })
        }
    }
    $SkuFilter = @($lifecycleEntries | ForEach-Object { $_.SKU })

    # Auto-merge discovered regions into -Region parameter
    $scanRegions = @($lifecycleEntries | ForEach-Object { $_.Region } | Select-Object -Unique)
    if ($scanRegions.Count -gt 0) {
        if ($Region) {
            $mergedRegions = @($Region) + @($scanRegions) | Select-Object -Unique
            $Region = @($mergedRegions)
        }
        else {
            $Region = @($scanRegions)
        }
    }

    $totalVMs = ($lifecycleEntries | Measure-Object -Property Qty -Sum).Sum
    $scopeDesc = if ($ManagementGroup) { "management group(s): $($ManagementGroup -join ', ')" } elseif ($SubscriptionId) { "subscription(s): $($SubscriptionId -join ', ')" } else { "current subscription" }
    if (-not $JsonOutput) { Write-Host "Lifecycle scan: found $($lifecycleEntries.Count) unique SKU+Region entries ($totalVMs VMs) across $($scanRegions.Count) region(s) from $scopeDesc" -ForegroundColor Cyan }

    #region Build Deployment Map Data (-SubMap / -RGMap)
    if ($SubMap -or $RGMap) {
        # Resolve subscription IDs to names via ARG ResourceContainers, filtered to only present subscriptions
        $subIds = @($allVMs | ForEach-Object { $_.subscriptionId } | Select-Object -Unique)
        $subNameMap = @{}
        if ($subIds.Count -gt 0) {
            $quotedSubIds = $subIds | ForEach-Object { "'$_'" }
            $subFilter = $quotedSubIds -join ','
            $subQuery = "ResourceContainers | where type =~ 'microsoft.resources/subscriptions' | where subscriptionId in~ ($subFilter) | project subscriptionId, name"
            $subParams = @{ Query = $subQuery; First = 1000 }
            if ($ManagementGroup) { $subParams['ManagementGroup'] = $ManagementGroup }
            elseif ($SubscriptionId) { $subParams['Subscription'] = $SubscriptionId }
            try {
                $subResults = Search-AzGraph @subParams
                foreach ($s in $subResults) { $subNameMap[$s.subscriptionId] = $s.name }
            }
            catch {
                Write-Verbose "Could not resolve subscription names via ARG: $_"
            }
        }

        if ($SubMap) {
            $subMapRows = [System.Collections.Generic.List[PSCustomObject]]::new()
            $grouped = $allVMs | Group-Object -Property subscriptionId, location, vmSize
            foreach ($g in $grouped) {
                $sample = $g.Group[0]
                $subId = $sample.subscriptionId
                $subMapRows.Add([pscustomobject]@{
                    SubscriptionId   = $subId
                    SubscriptionName = if ($subNameMap[$subId]) { $subNameMap[$subId] } else { $subId }
                    Region           = $sample.location
                    SKU              = $sample.vmSize
                    Qty              = $g.Count
                })
            }
            $subMapRows = [System.Collections.Generic.List[PSCustomObject]]@($subMapRows | Sort-Object SubscriptionName, Region, SKU)
            if (-not $JsonOutput) { Write-Host "Subscription map: $($subMapRows.Count) rows" -ForegroundColor Cyan }
        }
        if ($RGMap) {
            $rgMapRows = [System.Collections.Generic.List[PSCustomObject]]::new()
            $grouped = $allVMs | Group-Object -Property subscriptionId, resourceGroup, location, vmSize
            foreach ($g in $grouped) {
                $sample = $g.Group[0]
                $subId = $sample.subscriptionId
                $rgMapRows.Add([pscustomobject]@{
                    SubscriptionId   = $subId
                    SubscriptionName = if ($subNameMap[$subId]) { $subNameMap[$subId] } else { $subId }
                    ResourceGroup    = $sample.resourceGroup
                    Region           = $sample.location
                    SKU              = $sample.vmSize
                    Qty              = $g.Count
                })
            }
            $rgMapRows = [System.Collections.Generic.List[PSCustomObject]]@($rgMapRows | Sort-Object SubscriptionName, ResourceGroup, Region, SKU)
            if (-not $JsonOutput) { Write-Host "Resource Group map: $($rgMapRows.Count) rows" -ForegroundColor Cyan }
        }
    }
    #endregion Build Deployment Map Data
}

# Expand SKU filter to include upgrade path target SKUs so they get scanned
if ($lifecycleEntries -and $lifecycleEntries.Count -gt 0) {
    $upgradePathFile = Join-Path $PSScriptRoot 'data' 'UpgradePath.json'
    if (Test-Path -LiteralPath $upgradePathFile) {
        try {
            $upData = Get-Content -LiteralPath $upgradePathFile -Raw | ConvertFrom-Json
            $upgradeSkus = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            $existingFilter = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
            foreach ($s in $SkuFilter) { [void]$existingFilter.Add($s) }

            foreach ($entry in $lifecycleEntries) {
                $skuName = $entry.SKU
                # Extract family (inline logic matching Get-SkuFamily)
                $fam = if ($skuName -match 'Standard_([A-Z]+[a-z]*)[\d]') { $Matches[1].ToUpper() } else { '' }
                # Extract version (inline logic matching Get-SkuFamilyVersion)
                $ver = if ($skuName -match '_v(\d+)$') { [int]$Matches[1] } else { 1 }
                # Normalize family: DS→D, GS→G (Premium SSD suffix, same family)
                $normFam = if ($fam -cmatch '^([A-Z]+)S$' -and $fam -notin 'NVS','NCS','NDS','HBS','HCS','HXS','FXS') { $Matches[1] } else { $fam }
                $pathKey = "${normFam}v${ver}"
                $path = $upData.upgradePaths.$pathKey
                if (-not $path) { continue }

                foreach ($pType in @('dropIn','futureProof','costOptimized')) {
                    $pe = $path.$pType
                    if (-not $pe -or -not $pe.sizeMap) { continue }
                    foreach ($prop in $pe.sizeMap.PSObject.Properties) {
                        if ($prop.Value -and -not $existingFilter.Contains($prop.Value)) {
                            [void]$upgradeSkus.Add($prop.Value)
                        }
                    }
                }
            }

            if ($upgradeSkus.Count -gt 0) {
                $SkuFilter = @($SkuFilter) + @($upgradeSkus)
                Write-Verbose "Lifecycle mode: expanded SKU filter with $($upgradeSkus.Count) upgrade path target SKUs for scanning"
            }
        }
        catch {
            Write-Verbose "Failed to expand SKU filter from UpgradePath.json: $_"
        }
    }
}

#region Configuration
$ScriptVersion = (Get-Module AzVMAvailability).Version.ToString()

#region Constants
$HoursPerMonth = 730
$HoursPerYear = $HoursPerMonth * 12   # Reserved Instance pricing (1-year)
$HoursPer3Years = $HoursPerMonth * 36 # Reserved Instance pricing (3-year)
Write-Verbose "Pricing constants: $HoursPerMonth/mo, $HoursPerYear/yr, $HoursPer3Years/3yr"
$ParallelThrottleLimit = 4
$OutputWidthWithPricing = 200
$OutputWidthBase = 122
$OutputWidthMin = 100
$OutputWidthMax = 220

# VM family purpose descriptions and category groupings
$FamilyInfo = @{
    'A'  = @{ Purpose = 'Entry-level/test'; Category = 'Basic' }
    'B'  = @{ Purpose = 'Burstable'; Category = 'General' }
    'D'  = @{ Purpose = 'General purpose'; Category = 'General' }
    'DC' = @{ Purpose = 'Confidential'; Category = 'General' }
    'E'  = @{ Purpose = 'Memory optimized'; Category = 'Memory' }
    'EC' = @{ Purpose = 'Confidential memory'; Category = 'Memory' }
    'F'  = @{ Purpose = 'Compute optimized'; Category = 'Compute' }
    'FX' = @{ Purpose = 'High-freq compute'; Category = 'Compute' }
    'G'  = @{ Purpose = 'Memory+storage'; Category = 'Memory' }
    'H'  = @{ Purpose = 'HPC'; Category = 'HPC' }
    'HB' = @{ Purpose = 'HPC (AMD)'; Category = 'HPC' }
    'HC' = @{ Purpose = 'HPC (Intel)'; Category = 'HPC' }
    'HX' = @{ Purpose = 'HPC (large memory)'; Category = 'HPC' }
    'L'  = @{ Purpose = 'Storage optimized'; Category = 'Storage' }
    'M'  = @{ Purpose = 'Large memory (SAP/HANA)'; Category = 'Memory' }
    'NC' = @{ Purpose = 'GPU compute'; Category = 'GPU' }
    'ND' = @{ Purpose = 'GPU training (AI/ML)'; Category = 'GPU' }
    'NG' = @{ Purpose = 'GPU graphics'; Category = 'GPU' }
    'NP' = @{ Purpose = 'GPU FPGA'; Category = 'GPU' }
    'NV' = @{ Purpose = 'GPU visualization'; Category = 'GPU' }
}
$DefaultTerminalWidth = 80
$MinTableWidth = 70
$ExcelDescriptionColumnWidth = 70
$MinRecommendationScoreDefault = 50
#endregion Constants
# Runtime context for per-run state, outputs, and reusable caches
$script:RunContext = [pscustomobject]@{
    SchemaVersion      = '1.0'
    OutputWidth        = $null
    AzureEndpoints     = $null
    ImageReqs          = $null
    RegionPricing      = @{}
    UsingActualPricing = $false
    ScanOutput         = $null
    RecommendOutput    = $null
    ShowPlacement      = $false
    DesiredCount       = 1
    Caches             = [ordered]@{
        ValidRegions       = $null
        Pricing            = @{}
        ActualPricing      = @{}
        PlacementWarned403 = $false
    }
}


if (-not $PSBoundParameters.ContainsKey('MinScore')) {
    $MinScore = $MinRecommendationScoreDefault
}

# Map parameters to internal variables
$TargetSubIds = $SubscriptionId
# If LifecycleScan already discovered subscription IDs from ARG, use those
if (-not $TargetSubIds -and $allVMs -and $allVMs.Count -gt 0) {
    $TargetSubIds = @($allVMs | ForEach-Object { $_.subscriptionId } | Select-Object -Unique)
}
$Regions = $Region
$EnableDrill = $EnableDrillDown.IsPresent
$script:RunContext.ShowPlacement = $ShowPlacement.IsPresent
$script:RunContext.DesiredCount = $DesiredCount

# Region Presets - expand preset name to actual region array
# Note: All presets limited to 5 regions max for performance
$RegionPresets = @{
    'USEastWest'    = @('eastus', 'eastus2', 'westus', 'westus2')
    'USCentral'     = @('centralus', 'northcentralus', 'southcentralus', 'westcentralus')
    'USMajor'       = @('eastus', 'eastus2', 'centralus', 'westus', 'westus2')  # Top 5 US regions by usage
    'Europe'        = @('westeurope', 'northeurope', 'uksouth', 'francecentral', 'germanywestcentral')
    'AsiaPacific'   = @('eastasia', 'southeastasia', 'japaneast', 'australiaeast', 'koreacentral')
    'Global'        = @('eastus', 'westeurope', 'southeastasia', 'australiaeast', 'brazilsouth')
    'USGov'         = @('usgovvirginia', 'usgovtexas', 'usgovarizona')  # Azure Government (AzureUSGovernment)
    'China'         = @('chinaeast', 'chinanorth', 'chinaeast2', 'chinanorth2')  # Azure China / Mooncake (AzureChinaCloud)
    'ASR-EastWest'  = @('eastus', 'westus2')      # Azure Site Recovery pair
    'ASR-CentralUS' = @('centralus', 'eastus2')   # Azure Site Recovery pair
}

# If RegionPreset is specified, expand it (takes precedence over -Region if both specified)
if ($RegionPreset) {
    $Regions = $RegionPresets[$RegionPreset]
    Write-Verbose "Using region preset '$RegionPreset': $($Regions -join ', ')"

    # Auto-set environment for sovereign cloud presets
    if ($RegionPreset -eq 'USGov' -and -not $Environment) {
        $script:TargetEnvironment = 'AzureUSGovernment'
        Write-Verbose "Auto-setting environment to AzureUSGovernment for USGov preset"
    }
    elseif ($RegionPreset -eq 'China' -and -not $Environment) {
        $script:TargetEnvironment = 'AzureChinaCloud'
        Write-Verbose "Auto-setting environment to AzureChinaCloud for China preset"
    }
}
$SelectedFamilyFilter = $FamilyFilter
$SelectedSkuFilter = @{}

# Normalize -Recommend SKU name — trim whitespace and add Standard_ prefix if missing
if ($Recommend) {
    $Recommend = $Recommend.Trim()
    if ($Recommend -notmatch '^Standard_') {
        $Recommend = "Standard_$Recommend"
    }
}

# Only override environment if explicitly specified (preserve auto-detected sovereign clouds)
if ($Environment) {
    $script:TargetEnvironment = $Environment
}

# Detect execution environment (Azure Cloud Shell vs local)
$isCloudShell = $env:CLOUD_SHELL -eq "true" -or (Test-Path "/home/system" -ErrorAction SilentlyContinue)
$defaultExportPath = if ($isCloudShell) { "/home/system" } else { "C:\Temp\AzVMAvailability" }

# Auto-detect Unicode support for status icons
# Checks for modern terminals that support Unicode characters
# Can be overridden with -UseAsciiIcons parameter
$supportsUnicode = -not $UseAsciiIcons -and (
    $Host.UI.SupportsVirtualTerminal -or
    $env:WT_SESSION -or # Windows Terminal
    $env:TERM_PROGRAM -eq 'vscode' -or # VS Code integrated terminal
    ($env:TERM -and $env:TERM -match 'xterm|256color')  # Linux/macOS terminals
)

# Define icons based on terminal capability
# Shorter labels for narrow terminal support (Cloud Shell compatibility)
$Icons = if ($supportsUnicode) {
    @{
        OK       = '✓ OK'
        CAPACITY = '⚠ CONSTRAINED'
        LIMITED  = '⚠ LIMITED'
        PARTIAL  = '⚡ PARTIAL'
        BLOCKED  = '✗ BLOCKED'
        UNKNOWN  = '? N/A'
        Check    = '✓'
        Warning  = '⚠'
        Error    = '✗'
    }
}
else {
    @{
        OK       = '[OK]'
        CAPACITY = '[CONSTRAINED]'
        LIMITED  = '[LIMITED]'
        PARTIAL  = '[PARTIAL]'
        BLOCKED  = '[BLOCKED]'
        UNKNOWN  = '[N/A]'
        Check    = '[+]'
        Warning  = '[!]'
        Error    = '[-]'
    }
}

if ($AutoExport -and -not $ExportPath) {
    $ExportPath = $defaultExportPath
}

#endregion Configuration
#region Initialize Azure Endpoints
$script:AzureEndpoints = Get-AzureEndpoints -EnvironmentName $script:TargetEnvironment
if (-not $script:RunContext) {
    $script:RunContext = [pscustomobject]@{}
}
if (-not ($script:RunContext.PSObject.Properties.Name -contains 'AzureEndpoints')) {
    Add-Member -InputObject $script:RunContext -MemberType NoteProperty -Name AzureEndpoints -Value $null
}
$script:RunContext.AzureEndpoints = $script:AzureEndpoints

#endregion Initialize Azure Endpoints
#region Interactive Prompts
# Prompt user for subscription(s) if not provided via parameters
# LifecycleRecommendations: ARG scan already discovered subscriptions and regions from live VMs

if (-not $TargetSubIds -and -not $LifecycleRecommendations) {
    if ($NoPrompt) {
        $ctx = Get-AzContext -ErrorAction SilentlyContinue
        if ($ctx -and $ctx.Subscription.Id) {
            $TargetSubIds = @($ctx.Subscription.Id)
            Write-Host "Using current subscription: $($ctx.Subscription.Name)" -ForegroundColor Cyan
        }
        else {
            Write-Host "ERROR: No subscription context. Run Connect-AzAccount or specify -SubscriptionId" -ForegroundColor Red
            throw "No subscription context available. Run Connect-AzAccount or specify -SubscriptionId."
        }
    }
    else {
        $allSubs = Get-AzSubscription | Select-Object Name, Id, State
        Write-Host "`nSTEP 1: SELECT SUBSCRIPTION(S)" -ForegroundColor Green
        Write-Host ("=" * 60) -ForegroundColor Gray

        for ($i = 0; $i -lt $allSubs.Count; $i++) {
            Write-Host "$($i + 1). $($allSubs[$i].Name)" -ForegroundColor Cyan
            Write-Host "   $($allSubs[$i].Id)" -ForegroundColor DarkGray
        }

        Write-Host "`nEnter number(s) separated by commas (e.g., 1,3) or press Enter for #1:" -ForegroundColor Yellow
        $selection = Read-Host "Selection"

        if ([string]::IsNullOrWhiteSpace($selection)) {
            $TargetSubIds = @($allSubs[0].Id)
        }
        else {
            $nums = $selection -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
            $TargetSubIds = @($nums | ForEach-Object { $allSubs[$_ - 1].Id })
        }

        Write-Host "`nSelected: $($TargetSubIds.Count) subscription(s)" -ForegroundColor Green
    }
}

if (-not $Regions -and -not $LifecycleRecommendations) {
    $smartDefaults = Get-SmartDefaultRegions -CloudEnvironment $script:TargetEnvironment
    if ($NoPrompt) {
        $Regions = $smartDefaults.Regions
        Write-Host "Using default regions ($($smartDefaults.Source)): $($Regions -join ', ')" -ForegroundColor Cyan
    }
    else {
        Write-Host "`nSTEP 2: SELECT REGION(S)" -ForegroundColor Green
        Write-Host ("=" * 100) -ForegroundColor Gray
        Write-Host ""
        Write-Host "FAST PATH: Type region codes now to skip the long list (comma/space separated)" -ForegroundColor Yellow
        Write-Host "Examples: eastus eastus2 westus3  |  Press Enter to show full menu" -ForegroundColor DarkGray
        Write-Host "Press Enter for defaults: $($smartDefaults.Regions -join ', ')" -ForegroundColor DarkGray
        $quickRegions = Read-Host "Enter region codes or press Enter to load the menu"

        if (-not [string]::IsNullOrWhiteSpace($quickRegions)) {
            $Regions = @($quickRegions -split '[,\s]+' | Where-Object { $_ -ne '' } | ForEach-Object { $_.ToLower() })
            Write-Host "`nSelected regions (fast path): $($Regions -join ', ')" -ForegroundColor Green
        }
        else {
            # Show full region menu with geo-grouping
            Write-Host ""
            Write-Host "Available regions (filtered for Compute):" -ForegroundColor Cyan

            $geoOrder = @('Americas-US', 'Americas-Canada', 'Americas-LatAm', 'Europe', 'Asia-Pacific', 'India', 'Middle East', 'Africa', 'Australia', 'Other')

            $locations = Get-AzLocation | Where-Object { $_.Providers -contains 'Microsoft.Compute' } |
            ForEach-Object { $_ | Add-Member -NotePropertyName GeoGroup -NotePropertyValue (Get-GeoGroup $_.Location) -PassThru } |
            Sort-Object @{e = { $idx = $geoOrder.IndexOf($_.GeoGroup); if ($idx -ge 0) { $idx } else { 999 } } }, @{e = { $_.DisplayName } }

            Write-Host ""
            for ($i = 0; $i -lt $locations.Count; $i++) {
                Write-Host "$($i + 1). [$($locations[$i].GeoGroup)] $($locations[$i].DisplayName)" -ForegroundColor Cyan
                Write-Host "   Code: $($locations[$i].Location)" -ForegroundColor DarkGray
            }

            Write-Host ""
            Write-Host "INSTRUCTIONS:" -ForegroundColor Yellow
            Write-Host "  - Enter number(s) separated by commas (e.g., '1,5,10')" -ForegroundColor White
            Write-Host "  - Or use spaces (e.g., '1 5 10')" -ForegroundColor White
            Write-Host "  - Press Enter for defaults: $($smartDefaults.Regions -join ', ')" -ForegroundColor White
            Write-Host ""
            $regionsInput = Read-Host "Select region(s)"

            if ([string]::IsNullOrWhiteSpace($regionsInput)) {
                $Regions = $smartDefaults.Regions
                Write-Host "`nSelected regions (default): $($Regions -join ', ')" -ForegroundColor Green
            }
            else {
                $selectedNumbers = $regionsInput -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }

                if ($selectedNumbers.Count -eq 0) {
                    Write-Host "ERROR: No valid selections entered" -ForegroundColor Red
                    throw "No valid region selections entered."
                }

                $invalidNumbers = $selectedNumbers | Where-Object { $_ -lt 1 -or $_ -gt $locations.Count }
                if ($invalidNumbers.Count -gt 0) {
                    Write-Host "ERROR: Invalid selection(s): $($invalidNumbers -join ', '). Valid range is 1-$($locations.Count)" -ForegroundColor Red
                    throw "Invalid region selection(s): $($invalidNumbers -join ', '). Valid range is 1-$($locations.Count)."
                }

                $selectedNumbers = @($selectedNumbers | Sort-Object -Unique)
                $Regions = @()
                foreach ($num in $selectedNumbers) {
                    $Regions += $locations[$num - 1].Location
                }

                Write-Host "`nSelected regions:" -ForegroundColor Green
                foreach ($num in $selectedNumbers) {
                    Write-Host "  $($Icons.Check) $($locations[$num - 1].DisplayName) ($($locations[$num - 1].Location))" -ForegroundColor Green
                }
            }
        }
    }
}
else {
    $Regions = @($Regions | ForEach-Object { $_.ToLower() })
}

# Validate regions against Azure's available regions
$validRegions = if ($SkipRegionValidation) { $null } else { Get-ValidAzureRegions -MaxRetries $MaxRetries -AzureEndpoints $script:AzureEndpoints -Caches $script:RunContext.Caches }

$invalidRegions = @()
$validatedRegions = @()

# If region validation is skipped or failed entirely
if ($SkipRegionValidation) {
    Write-Warning "Region validation explicitly skipped via -SkipRegionValidation."
    $validatedRegions = $Regions
}
elseif ($null -eq $validRegions -or $validRegions.Count -eq 0) {
    if ($NoPrompt) {
        Write-Host "`nERROR: Region validation is unavailable in -NoPrompt mode." -ForegroundColor Red
        Write-Host "Use valid regions when connectivity is restored, or explicitly set -SkipRegionValidation to override." -ForegroundColor Yellow
        throw "Region validation unavailable in -NoPrompt mode. Use -SkipRegionValidation to override."
    }

    Write-Warning "Region validation unavailable — proceeding with user-provided regions in interactive mode."
    $validatedRegions = $Regions
}
else {
    foreach ($region in $Regions) {
        if ($validRegions -contains $region) {
            $validatedRegions += $region
        }
        else {
            $invalidRegions += $region
        }
    }
}

if ($invalidRegions.Count -gt 0) {
    Write-Host "`nWARNING: Invalid or unsupported region(s) detected:" -ForegroundColor Yellow
    foreach ($invalid in $invalidRegions) {
        Write-Host "  $($Icons.Error) $invalid (not found or does not support Compute)" -ForegroundColor Red
    }
    Write-Host "`nValid regions have been retained. To see all available regions, run:" -ForegroundColor Gray
    Write-Host "  Get-AzLocation | Where-Object { `$_.Providers -contains 'Microsoft.Compute' } | Select-Object Location, DisplayName" -ForegroundColor DarkGray
}

if ($validatedRegions.Count -eq 0) {
    Write-Host "`nERROR: No valid regions to scan. Please specify valid Azure region names." -ForegroundColor Red
    Write-Host "Example valid regions: eastus, westus2, centralus, westeurope, eastasia" -ForegroundColor Gray
    throw "No valid regions to scan. Specify valid Azure region names."
}

$Regions = $validatedRegions

# LifecycleRecommendations defaults: auto-enable pricing, Excel export, savings/reservation details, and quota
if ($LifecycleRecommendations) {
    if (-not $ShowPricing)      { $ShowPricing = [switch]::new($true) }
    if (-not $AutoExport)       { $AutoExport  = [switch]::new($true) }
    if (-not $RateOptimization) { $RateOptimization = [switch]::new($true) }
    if ($NoQuota)               { } else { $NoQuota = $false }
    if (-not $ExportPath)       { $ExportPath = $defaultExportPath }
    if (-not $JsonOutput) {
        Write-Host "Lifecycle mode: auto-enabled pricing, Excel export, savings plan/reservation details, and quota" -ForegroundColor DarkGray
    }
}

# Validate region count limit (skip for lifecycle scans — all deployed regions need pricing)
$maxRegions = 5
if ($Regions.Count -gt $maxRegions -and -not $lifecycleEntries) {
    if ($NoPrompt) {
        # In NoPrompt mode, auto-truncate with warning (don't hang on Read-Host)
        Write-Host "`nWARNING: " -ForegroundColor Yellow -NoNewline
        Write-Host "Specified $($Regions.Count) regions exceeds maximum of $maxRegions. Auto-truncating." -ForegroundColor White
        $Regions = @($Regions[0..($maxRegions - 1)])
        Write-Host "Proceeding with: $($Regions -join ', ')" -ForegroundColor Green
    }
    else {
        Write-Host "`n" -NoNewline
        Write-Host "WARNING: " -ForegroundColor Yellow -NoNewline
        Write-Host "You've specified $($Regions.Count) regions. For optimal performance and readability," -ForegroundColor White
        Write-Host "         the maximum recommended is $maxRegions regions per scan." -ForegroundColor White
        Write-Host "`nOptions:" -ForegroundColor Cyan
        Write-Host "  1. Continue with first $maxRegions regions: $($Regions[0..($maxRegions-1)] -join ', ')" -ForegroundColor Gray
        Write-Host "  2. Cancel and re-run with fewer regions" -ForegroundColor Gray
        Write-Host "`nContinue with first $maxRegions regions? (y/N): " -ForegroundColor Yellow -NoNewline
        $limitInput = Read-Host
        if ($limitInput -match '^y(es)?$') {
            $Regions = @($Regions[0..($maxRegions - 1)])
            Write-Host "Proceeding with: $($Regions -join ', ')" -ForegroundColor Green
        }
        else {
            Write-Host "Scan cancelled. Please re-run with $maxRegions or fewer regions." -ForegroundColor Yellow
            return
        }
    }
}

# Drill-down prompt
if (-not $NoPrompt -and -not $LifecycleRecommendations -and -not $EnableDrill) {
    Write-Host "`nDrill down into specific families/SKUs? (y/N): " -ForegroundColor Yellow -NoNewline
    $drillInput = Read-Host
    if ($drillInput -match '^y(es)?$') { $EnableDrill = $true }
}

# Export prompt
if (-not $ExportPath -and -not $NoPrompt -and -not $LifecycleRecommendations -and -not $AutoExport) {
    Write-Host "`nExport results to file? (y/N): " -ForegroundColor Yellow -NoNewline
    $exportInput = Read-Host
    if ($exportInput -match '^y(es)?$') {
        Write-Host "Export path (Enter for default: $defaultExportPath): " -ForegroundColor Yellow -NoNewline
        $pathInput = Read-Host
        $ExportPath = if ([string]::IsNullOrWhiteSpace($pathInput)) { $defaultExportPath } else { $pathInput }
    }
}

# Pricing prompt
$FetchPricing = $ShowPricing.IsPresent
if (-not $ShowPricing -and -not $NoPrompt -and -not $LifecycleRecommendations) {
    Write-Host "`nInclude estimated pricing? (first run downloads the price sheet, ~15-20 min; cached afterwards) (y/N): " -ForegroundColor Yellow -NoNewline
    $pricingInput = Read-Host
    if ($pricingInput -match '^y(es)?$') { $FetchPricing = $true }
}

# Placement score prompt — fires independently (useful without pricing)
if (-not $ShowPlacement -and -not $NoPrompt -and -not $LifecycleRecommendations) {
    Write-Host "`nShow allocation likelihood scores? (High/Medium/Low per SKU) (y/N): " -ForegroundColor Yellow -NoNewline
    $placementInput = Read-Host
    if ($placementInput -match '^y(es)?$') { $ShowPlacement = [switch]::new($true) }
}
$script:RunContext.ShowPlacement = $ShowPlacement.IsPresent

# Spot pricing prompt — only useful if pricing is enabled
if (-not $ShowSpot -and -not $NoPrompt -and -not $LifecycleRecommendations -and $FetchPricing) {
    Write-Host "`nInclude Spot VM pricing alongside regular pricing? (y/N): " -ForegroundColor Yellow -NoNewline
    $spotInput = Read-Host
    if ($spotInput -match '^y(es)?$') { $ShowSpot = [switch]::new($true) }
}

# Image compatibility prompt
if (-not $ImageURN -and -not $NoPrompt -and -not $LifecycleRecommendations) {
    Write-Host "`nCheck SKU compatibility with a specific VM image? (y/N): " -ForegroundColor Yellow -NoNewline
    $imageInput = Read-Host
    if ($imageInput -match '^y(es)?$') {
        # Common images list for easy selection - organized by category
        $commonImages = @(
            # Linux - General Purpose
            @{ Num = 1; Name = "Ubuntu 22.04 LTS (Gen2)"; URN = "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest"; Gen = "Gen2"; Arch = "x64"; Cat = "Linux" }
            @{ Num = 2; Name = "Ubuntu 24.04 LTS (Gen2)"; URN = "Canonical:ubuntu-24_04-lts:server-gen2:latest"; Gen = "Gen2"; Arch = "x64"; Cat = "Linux" }
            @{ Num = 3; Name = "Ubuntu 22.04 ARM64"; URN = "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-arm64:latest"; Gen = "Gen2"; Arch = "ARM64"; Cat = "Linux" }
            @{ Num = 4; Name = "RHEL 9 (Gen2)"; URN = "RedHat:RHEL:9-lvm-gen2:latest"; Gen = "Gen2"; Arch = "x64"; Cat = "Linux" }
            @{ Num = 5; Name = "Debian 12 (Gen2)"; URN = "Debian:debian-12:12-gen2:latest"; Gen = "Gen2"; Arch = "x64"; Cat = "Linux" }
            @{ Num = 6; Name = "Azure Linux (Mariner)"; URN = "MicrosoftCBLMariner:cbl-mariner:cbl-mariner-2-gen2:latest"; Gen = "Gen2"; Arch = "x64"; Cat = "Linux" }
            # Windows
            @{ Num = 7; Name = "Windows Server 2022 (Gen2)"; URN = "MicrosoftWindowsServer:WindowsServer:2022-datacenter-g2:latest"; Gen = "Gen2"; Arch = "x64"; Cat = "Windows" }
            @{ Num = 8; Name = "Windows Server 2019 (Gen2)"; URN = "MicrosoftWindowsServer:WindowsServer:2019-datacenter-gensecond:latest"; Gen = "Gen2"; Arch = "x64"; Cat = "Windows" }
            @{ Num = 9; Name = "Windows 11 Enterprise (Gen2)"; URN = "MicrosoftWindowsDesktop:windows-11:win11-22h2-ent:latest"; Gen = "Gen2"; Arch = "x64"; Cat = "Windows" }
            # Data Science & ML
            @{ Num = 10; Name = "Data Science VM Ubuntu 22.04"; URN = "microsoft-dsvm:ubuntu-2204:2204-gen2:latest"; Gen = "Gen2"; Arch = "x64"; Cat = "Data Science" }
            @{ Num = 11; Name = "Data Science VM Windows 2022"; URN = "microsoft-dsvm:dsvm-win-2022:winserver-2022:latest"; Gen = "Gen2"; Arch = "x64"; Cat = "Data Science" }
            @{ Num = 12; Name = "Azure ML Workstation Ubuntu"; URN = "microsoft-dsvm:aml-workstation:ubuntu22:latest"; Gen = "Gen2"; Arch = "x64"; Cat = "Data Science" }
            # HPC & GPU Optimized
            @{ Num = 13; Name = "Ubuntu HPC 22.04"; URN = "microsoft-dsvm:ubuntu-hpc:2204:latest"; Gen = "Gen2"; Arch = "x64"; Cat = "HPC" }
            @{ Num = 14; Name = "AlmaLinux HPC"; URN = "almalinux:almalinux-hpc:8_7-hpc-gen2:latest"; Gen = "Gen2"; Arch = "x64"; Cat = "HPC" }
            # Legacy/Gen1 (for older SKUs)
            @{ Num = 15; Name = "Ubuntu 22.04 LTS (Gen1)"; URN = "Canonical:0001-com-ubuntu-server-jammy:22_04-lts:latest"; Gen = "Gen1"; Arch = "x64"; Cat = "Gen1" }
            @{ Num = 16; Name = "Windows Server 2022 (Gen1)"; URN = "MicrosoftWindowsServer:WindowsServer:2022-datacenter:latest"; Gen = "Gen1"; Arch = "x64"; Cat = "Gen1" }
        )

        Write-Host ""
        Write-Host "COMMON VM IMAGES:" -ForegroundColor Cyan
        Write-Host ("-" * 85) -ForegroundColor Gray
        Write-Host ("{0,-4} {1,-40} {2,-6} {3,-7} {4}" -f "#", "Image Name", "Gen", "Arch", "Category") -ForegroundColor White
        Write-Host ("-" * 85) -ForegroundColor Gray
        foreach ($img in $commonImages) {
            $catColor = switch ($img.Cat) { "Linux" { "Cyan" } "Windows" { "Blue" } "Data Science" { "Magenta" } "HPC" { "Yellow" } "Gen1" { "DarkGray" } default { "Gray" } }
            Write-Host ("{0,-4} {1,-40} {2,-6} {3,-7} {4}" -f $img.Num, $img.Name, $img.Gen, $img.Arch, $img.Cat) -ForegroundColor $catColor
        }
        Write-Host ("-" * 85) -ForegroundColor Gray
        Write-Host "Or type: 'custom' for manual URN | 'search' to browse Azure Marketplace | Enter to skip" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "Select image (1-16, custom, search, or Enter to skip): " -ForegroundColor Yellow -NoNewline
        $imageSelection = Read-Host

        if ($imageSelection -match '^\d+$' -and [int]$imageSelection -ge 1 -and [int]$imageSelection -le $commonImages.Count) {
            $selectedImage = $commonImages[[int]$imageSelection - 1]
            $ImageURN = $selectedImage.URN
            Write-Host "Selected: $($selectedImage.Name)" -ForegroundColor Green
            Write-Host "URN: $ImageURN" -ForegroundColor DarkGray
        }
        elseif ($imageSelection -match '^custom$') {
            Write-Host "Enter image URN (Publisher:Offer:Sku:Version): " -ForegroundColor Yellow -NoNewline
            $customURN = Read-Host
            if (-not [string]::IsNullOrWhiteSpace($customURN)) {
                $ImageURN = $customURN
                Write-Host "Using custom URN: $ImageURN" -ForegroundColor Green
            }
            else {
                $ImageURN = $null
                Write-Host "No image specified - skipping compatibility check" -ForegroundColor DarkGray
            }
        }
        elseif ($imageSelection -match '^search$') {
            Write-Host ""
            Write-Host "Enter search term (e.g., 'ubuntu', 'data science', 'windows', 'dsvm'): " -ForegroundColor Yellow -NoNewline
            $searchTerm = Read-Host
            if (-not [string]::IsNullOrWhiteSpace($searchTerm) -and $Regions.Count -gt 0) {
                Write-Host "Searching Azure Marketplace..." -ForegroundColor DarkGray
                try {
                    # Search publishers first
                    $publishers = Get-AzVMImagePublisher -Location $Regions[0] -ErrorAction SilentlyContinue |
                    Where-Object { $_.PublisherName -match $searchTerm }

                    # Also search common publishers for offers matching the term
                    $offerResults = [System.Collections.Generic.List[object]]::new()
                    $searchPublishers = @('Canonical', 'MicrosoftWindowsServer', 'RedHat', 'microsoft-dsvm', 'MicrosoftCBLMariner', 'Debian', 'SUSE', 'Oracle', 'OpenLogic')
                    foreach ($pub in $searchPublishers) {
                        try {
                            $offers = Get-AzVMImageOffer -Location $Regions[0] -PublisherName $pub -ErrorAction SilentlyContinue |
                            Where-Object { $_.Offer -match $searchTerm }
                            foreach ($offer in $offers) {
                                $offerResults.Add(@{ Publisher = $pub; Offer = $offer.Offer }) | Out-Null
                            }
                        }
                        catch { Write-Verbose "Image search failed for publisher '$pub': $_" }
                    }

                    if ($publishers -or $offerResults.Count -gt 0) {
                        $allResults = [System.Collections.Generic.List[object]]::new()
                        $idx = 1

                        # Add publisher matches
                        if ($publishers) {
                            $publishers | Select-Object -First 5 | ForEach-Object {
                                $allResults.Add(@{ Num = $idx; Type = "Publisher"; Name = $_.PublisherName; Publisher = $_.PublisherName; Offer = $null }) | Out-Null
                                $idx++
                            }
                        }

                        # Add offer matches
                        $offerResults | Select-Object -First 5 | ForEach-Object {
                            $allResults.Add(@{ Num = $idx; Type = "Offer"; Name = "$($_.Publisher) > $($_.Offer)"; Publisher = $_.Publisher; Offer = $_.Offer }) | Out-Null
                            $idx++
                        }

                        Write-Host ""
                        Write-Host "Results matching '$searchTerm':" -ForegroundColor Cyan
                        Write-Host ("-" * 60) -ForegroundColor Gray
                        foreach ($result in $allResults) {
                            $color = if ($result.Type -eq "Offer") { "White" } else { "Gray" }
                            Write-Host ("  {0,2}. [{1,-9}] {2}" -f $result.Num, $result.Type, $result.Name) -ForegroundColor $color
                        }
                        Write-Host ""
                        Write-Host "Select (1-$($allResults.Count)) or Enter to skip: " -ForegroundColor Yellow -NoNewline
                        $resultSelect = Read-Host

                        if ($resultSelect -match '^\d+$' -and [int]$resultSelect -le $allResults.Count) {
                            $selected = $allResults[[int]$resultSelect - 1]

                            if ($selected.Type -eq "Offer") {
                                # Already have publisher and offer, just need SKU
                                $skus = Get-AzVMImageSku -Location $Regions[0] -PublisherName $selected.Publisher -Offer $selected.Offer -ErrorAction SilentlyContinue |
                                Select-Object -First 15

                                if ($skus) {
                                    Write-Host ""
                                    Write-Host "SKUs for $($selected.Offer):" -ForegroundColor Cyan
                                    for ($i = 0; $i -lt $skus.Count; $i++) {
                                        Write-Host "  $($i + 1). $($skus[$i].Skus)" -ForegroundColor White
                                    }
                                    Write-Host ""
                                    Write-Host "Select SKU (1-$($skus.Count)) or Enter to skip: " -ForegroundColor Yellow -NoNewline
                                    $skuSelect = Read-Host

                                    if ($skuSelect -match '^\d+$' -and [int]$skuSelect -le $skus.Count) {
                                        $selectedSku = $skus[[int]$skuSelect - 1]
                                        $ImageURN = "$($selected.Publisher):$($selected.Offer):$($selectedSku.Skus):latest"
                                        Write-Host "Selected: $ImageURN" -ForegroundColor Green
                                    }
                                }
                            }
                            else {
                                # Publisher selected - show offers
                                $offers = Get-AzVMImageOffer -Location $Regions[0] -PublisherName $selected.Publisher -ErrorAction SilentlyContinue |
                                Select-Object -First 10

                                if ($offers) {
                                    Write-Host ""
                                    Write-Host "Offers from $($selected.Publisher):" -ForegroundColor Cyan
                                    for ($i = 0; $i -lt $offers.Count; $i++) {
                                        Write-Host "  $($i + 1). $($offers[$i].Offer)" -ForegroundColor White
                                    }
                                    Write-Host ""
                                    Write-Host "Select offer (1-$($offers.Count)) or Enter to skip: " -ForegroundColor Yellow -NoNewline
                                    $offerSelect = Read-Host

                                    if ($offerSelect -match '^\d+$' -and [int]$offerSelect -le $offers.Count) {
                                        $selectedOffer = $offers[[int]$offerSelect - 1]
                                        $skus = Get-AzVMImageSku -Location $Regions[0] -PublisherName $selected.Publisher -Offer $selectedOffer.Offer -ErrorAction SilentlyContinue |
                                        Select-Object -First 15

                                        if ($skus) {
                                            Write-Host ""
                                            Write-Host "SKUs for $($selectedOffer.Offer):" -ForegroundColor Cyan
                                            for ($i = 0; $i -lt $skus.Count; $i++) {
                                                Write-Host "  $($i + 1). $($skus[$i].Skus)" -ForegroundColor White
                                            }
                                            Write-Host ""
                                            Write-Host "Select SKU (1-$($skus.Count)) or Enter to skip: " -ForegroundColor Yellow -NoNewline
                                            $skuSelect = Read-Host

                                            if ($skuSelect -match '^\d+$' -and [int]$skuSelect -le $skus.Count) {
                                                $selectedSku = $skus[[int]$skuSelect - 1]
                                                $ImageURN = "$($selected.Publisher):$($selectedOffer.Offer):$($selectedSku.Skus):latest"
                                                Write-Host "Selected: $ImageURN" -ForegroundColor Green
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    else {
                        Write-Host "No results found matching '$searchTerm'" -ForegroundColor DarkYellow
                        Write-Host "Try: 'ubuntu', 'windows', 'rhel', 'dsvm', 'mariner', 'debian', 'suse'" -ForegroundColor DarkGray
                    }
                }
                catch {
                    Write-Host "Search failed: $_" -ForegroundColor Red
                }

                if (-not $ImageURN) {
                    Write-Host "No image selected - skipping compatibility check" -ForegroundColor DarkGray
                }
            }
        }
        else {
            # Assume they entered a URN directly or pressed Enter to skip
            if (-not [string]::IsNullOrWhiteSpace($imageSelection)) {
                $ImageURN = $imageSelection
                Write-Host "Using: $ImageURN" -ForegroundColor Green
            }
        }
    }
}

# Parse image requirements if an image was specified
$script:RunContext.ImageReqs = $null
if ($ImageURN) {
    $script:RunContext.ImageReqs = Get-ImageRequirements -ImageURN $ImageURN
    if (-not $script:RunContext.ImageReqs.Valid) {
        Write-Host "Warning: Could not parse image URN - $($script:RunContext.ImageReqs.Error)" -ForegroundColor DarkYellow
        $script:RunContext.ImageReqs = $null
    }
}

if ($ExportPath -and -not (Test-Path $ExportPath)) {
    New-Item -Path $ExportPath -ItemType Directory -Force | Out-Null
    Write-Host "Created: $ExportPath" -ForegroundColor Green
}

#endregion Interactive Prompts
#region Data Collection

# Calculate consistent output width based on table columns
# Base columns: Family(12) + SKUs(6) + OK(5) + Largest(18) + Zones(28) + Status(22) + Quota(10) = 101
# Plus spacing and CPU/Disk columns = 122 base
# With pricing: +18 (two price columns) = 140
$script:OutputWidth = if ($FetchPricing) { $OutputWidthWithPricing } else { $OutputWidthBase }
if ($CompactOutput) {
    $script:OutputWidth = $OutputWidthMin
}
$script:OutputWidth = [Math]::Max($script:OutputWidth, $OutputWidthMin)
$script:OutputWidth = [Math]::Min($script:OutputWidth, $OutputWidthMax)
$script:RunContext.OutputWidth = $script:OutputWidth

Write-Host "`n" -NoNewline
Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
Write-Host "GET-AZVMAVAILABILITY v$ScriptVersion" -ForegroundColor Green
Write-Host "Personal project — not an official Microsoft product. Provided AS IS." -ForegroundColor DarkGray
Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
Write-Host "Subscriptions: $($TargetSubIds.Count) | Regions: $($Regions -join ', ')" -ForegroundColor Cyan
if ($SkuFilter -and $SkuFilter.Count -gt 0) {
    Write-Host "SKU Filter: $($SkuFilter -join ', ')" -ForegroundColor Yellow
}
Write-Host "Icons: $(if ($supportsUnicode) { 'Unicode' } else { 'ASCII' }) | Pricing: $(if ($FetchPricing) { 'Enabled' } else { 'Disabled' })" -ForegroundColor DarkGray
if ($script:RunContext.ImageReqs) {
    Write-Host "Image: $ImageURN" -ForegroundColor Cyan
    Write-Host "Requirements: $($script:RunContext.ImageReqs.Gen) | $($script:RunContext.ImageReqs.Arch)" -ForegroundColor DarkCyan
}
Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
Write-Host ""

# Check for newer version on PSGallery (once per session, silent on failure)
Test-ModuleUpdateAvailable -CurrentVersion $ScriptVersion

# Fetch pricing data if enabled
$script:RunContext.RegionPricing = @{}
$script:RunContext.UsingActualPricing = $false

if ($FetchPricing) {
    # Auto-detect: Try negotiated pricing first, fall back to retail
    Write-Host "Checking for negotiated pricing (EA/MCA/CSP)..." -ForegroundColor DarkGray

    $actualPricingSuccess = $true
    foreach ($regionCode in $Regions) {
        $actualPrices = Get-AzActualPricing -SubscriptionId $TargetSubIds[0] -Region $regionCode -MaxRetries $MaxRetries -HoursPerMonth $HoursPerMonth -AzureEndpoints $script:AzureEndpoints -TargetEnvironment $script:TargetEnvironment -Caches $script:RunContext.Caches
        if ($actualPrices -and $actualPrices.Count -gt 0) {
            if ($actualPrices -is [array]) { $actualPrices = $actualPrices[0] }
            $script:RunContext.RegionPricing[$regionCode] = $actualPrices
        }
        else {
            $actualPricingSuccess = $false
            break
        }
    }

    if ($actualPricingSuccess -and $script:RunContext.RegionPricing.Count -gt 0) {
        $script:RunContext.UsingActualPricing = $true
        Write-Host "$($Icons.Check) Using negotiated pricing (EA/MCA/CSP rates detected)" -ForegroundColor Green
    }
    else {
        # Fall back to retail pricing
        Write-Host "No negotiated rates found, using retail pricing..." -ForegroundColor DarkGray
        $script:RunContext.RegionPricing = @{}
        foreach ($regionCode in $Regions) {
            $pricingResult = Get-AzVMPricing -Region $regionCode -MaxRetries $MaxRetries -HoursPerMonth $HoursPerMonth -AzureEndpoints $script:AzureEndpoints -TargetEnvironment $script:TargetEnvironment -Caches $script:RunContext.Caches
            if ($pricingResult -is [array]) { $pricingResult = $pricingResult[0] }
            $script:RunContext.RegionPricing[$regionCode] = $pricingResult
        }
        Write-Host "$($Icons.Check) Using retail pricing (Linux pay-as-you-go)" -ForegroundColor DarkGray
    }
}

$allSubscriptionData = @()

$initialAzContext = Get-AzContext -ErrorAction SilentlyContinue
$initialSubscriptionId = if ($initialAzContext -and $initialAzContext.Subscription) { [string]$initialAzContext.Subscription.Id } else { $null }

# Outer try/finally ensures Az context is restored even if Ctrl+C or PipelineStoppedException
# interrupts parallel scanning, results processing, or export
$scanStartTime = Get-Date
try {
    try {
        foreach ($subId in $TargetSubIds) {
        $subscriptionScanStartTime = Get-Date
        try {
            Use-SubscriptionContextSafely -SubscriptionId $subId | Out-Null
        }
        catch {
            Write-Warning "Failed to switch Azure context to subscription '$subId': $($_.Exception.Message)"
            continue
        }

        $subName = (Get-AzSubscription -SubscriptionId $subId | Select-Object -First 1).Name
        Write-Host "[$subName] Scanning $($Regions.Count) region(s)..." -ForegroundColor Yellow

        # Progress indicator for parallel scanning
        $regionCount = $Regions.Count
        Write-Progress -Activity "Scanning Azure Regions" -Status "Querying $regionCount region(s) in parallel..." -PercentComplete 0

        # Shared retry error pattern for all scan paths
        $retryErrorPattern = '429|Too Many Requests|500|Internal Server Error|InternalServerError|503|ServiceUnavailable|Service Unavailable'

        $scanRegionScript = {
            param($region, $skuFilterCopy, $maxRetries, $armUrl, $bearerToken, $retryPattern, $skipQuota)
            $boundRetryPattern = $retryPattern

            # Inline retry — parallel runspaces cannot see script-scope functions
            $retryCall = {
                param([scriptblock]$Action, [int]$Retries)
                $attempt = 0
                while ($true) {
                    try {
                        return (& $Action)
                    }
                    catch {
                        $attempt++
                        $msg = $_.Exception.Message
                        $isThrottle = $msg -match $boundRetryPattern
                        if ($isThrottle -and $attempt -le $Retries) {
                            $baseDelay = [math]::Pow(2, $attempt)
                            $jitter = $baseDelay * (Get-Random -Minimum 0.0 -Maximum 0.25)
                            Start-Sleep -Milliseconds (($baseDelay + $jitter) * 1000)
                            continue
                        }
                        throw
                    }
                }
            }

            try {
                $headers = @{ 'Authorization' = "Bearer $bearerToken"; 'Content-Type' = 'application/json' }

                $skuUri = "$armUrl/subscriptions/$subId/providers/Microsoft.Compute/skus?api-version=2021-07-01&`$filter=location eq '$region'"
                $quotaUri = "$armUrl/subscriptions/$subId/providers/Microsoft.Compute/locations/$region/usages?api-version=2023-09-01"

                # Fetch SKUs with pagination
                $skuResult = [System.Collections.Generic.List[object]]::new()
                $nextLink = $skuUri
                while ($nextLink) {
                    $capturedLink = $nextLink
                    $resp = & $retryCall -Action { Invoke-RestMethod -Uri $capturedLink -Headers $headers -Method Get -TimeoutSec 60 -ErrorAction Stop } -Retries $maxRetries
                    foreach ($item in $resp.value) { $skuResult.Add($item) }
                    $nextLink = $resp.nextLink
                }

                # Fetch quotas
                $capturedQuotaUri = $quotaUri
                $quotaResp = & $retryCall -Action { Invoke-RestMethod -Uri $capturedQuotaUri -Headers $headers -Method Get -TimeoutSec 60 -ErrorAction Stop } -Retries $maxRetries
                $quotaResult = $quotaResp.value

                # Filter to virtualMachines only
                $allSkus = @($skuResult | Where-Object { $_.resourceType -eq 'virtualMachines' })

                # Apply SKU filter if specified
                if ($skuFilterCopy -and $skuFilterCopy.Count -gt 0) {
                    $allSkus = @($allSkus | Where-Object {
                        $skuName = $_.name
                        $isMatch = $false
                        foreach ($pattern in $skuFilterCopy) {
                            if ($skuName -like $pattern) {
                                $isMatch = $true
                                break
                            }
                        }
                        $isMatch
                    })
                }

                # Normalize REST response objects to match cmdlet output shape
                $normalizedSkus = foreach ($sku in $allSkus) { ConvertFrom-RestSku -RestSku $sku }
                $normalizedQuotas = if ($skipQuota) { @() } else {
                    foreach ($q in $quotaResult) { ConvertFrom-RestQuota -RestQuota $q }
                }

                @{ Region = [string]$region; Skus = @($normalizedSkus); Quotas = @($normalizedQuotas); Error = $null }
            }
            catch {
                @{ Region = [string]$region; Skus = @(); Quotas = @(); Error = $_.Exception.Message }
            }
        }

        # Get bearer token for REST calls
        $armUrl = if ($script:AzureEndpoints) { $script:AzureEndpoints.ResourceManagerUrl } else { 'https://management.azure.com' }
        $armUrl = $armUrl.TrimEnd('/')
        $tokenResult = Get-AzAccessToken -ResourceUrl $armUrl -ErrorAction Stop
        $bearerToken = if ($tokenResult.Token -is [System.Security.SecureString]) {
            [System.Net.NetworkCredential]::new('', $tokenResult.Token).Password
        } else { $tokenResult.Token }

        $canUseParallel = $PSVersionTable.PSVersion.Major -ge 7
        if ($canUseParallel) {
            try {
                $regionData = $Regions | ForEach-Object -Parallel {
                    $region = [string]$_
                    $skuFilterCopy = $using:SkuFilter
                    $maxRetries = $using:MaxRetries
                    $armUrl = $using:armUrl
                    $bearerToken = $using:bearerToken
                    $subId = $using:subId
                    $retryPattern = $using:retryErrorPattern
                    $skipQuota = $using:NoQuota.IsPresent

                    # Inline retry — parallel runspaces cannot see script-scope functions or external scriptblocks
                    $retryCall = {
                        param([scriptblock]$Action, [int]$Retries)
                        $attempt = 0
                        while ($true) {
                            try {
                                return (& $Action)
                            }
                            catch {
                                $attempt++
                                $msg = $_.Exception.Message
                                $isThrottle = $msg -match $retryPattern
                                if ($isThrottle -and $attempt -le $Retries) {
                                    $baseDelay = [math]::Pow(2, $attempt)
                                    $jitter = $baseDelay * (Get-Random -Minimum 0.0 -Maximum 0.25)
                                    Start-Sleep -Milliseconds (($baseDelay + $jitter) * 1000)
                                    continue
                                }
                                throw
                            }
                        }
                    }

                    try {
                        $headers = @{ 'Authorization' = "Bearer $bearerToken"; 'Content-Type' = 'application/json' }

                        $skuUri = "$armUrl/subscriptions/$subId/providers/Microsoft.Compute/skus?api-version=2021-07-01&`$filter=location eq '$region'"
                        $quotaUri = "$armUrl/subscriptions/$subId/providers/Microsoft.Compute/locations/$region/usages?api-version=2023-09-01"

                        # Concurrent first-page fetch: HttpClient fires SKU + quota in parallel
                        $client = [System.Net.Http.HttpClient]::new()
                        $client.DefaultRequestHeaders.TryAddWithoutValidation('Authorization', "Bearer $bearerToken") | Out-Null
                        $skuTask   = $client.GetStringAsync($skuUri)
                        $quotaTask = $client.GetStringAsync($quotaUri)
                        [System.Threading.Tasks.Task]::WaitAll(@($skuTask, $quotaTask))
                        $client.Dispose()

                        if ($skuTask.IsFaulted)   { throw $skuTask.Exception.GetBaseException() }
                        if ($quotaTask.IsFaulted) { throw $quotaTask.Exception.GetBaseException() }

                        $skuJson   = $skuTask.Result   | ConvertFrom-Json
                        $quotaJson = $quotaTask.Result | ConvertFrom-Json

                        $skuItems = [System.Collections.Generic.List[object]]::new()
                        foreach ($item in $skuJson.value) { $skuItems.Add($item) }

                        # Paginate remaining SKU pages sequentially
                        $nextLink = $skuJson.nextLink
                        while ($nextLink) {
                            $capturedUri = $nextLink
                            $resp = & $retryCall -Action { Invoke-RestMethod -Uri $capturedUri -Headers $headers -Method Get -TimeoutSec 60 -ErrorAction Stop } -Retries $maxRetries
                            foreach ($item in $resp.value) { $skuItems.Add($item) }
                            $nextLink = $resp.nextLink
                        }

                        # Filter to virtualMachines
                        $allSkus = @($skuItems | Where-Object { $_.resourceType -eq 'virtualMachines' })

                        if ($skuFilterCopy -and $skuFilterCopy.Count -gt 0) {
                            $allSkus = @($allSkus | Where-Object {
                                $skuName = $_.name
                                $isMatch = $false
                                foreach ($pattern in $skuFilterCopy) {
                                    if ($skuName -like $pattern) {
                                        $isMatch = $true
                                        break
                                    }
                                }
                                $isMatch
                            })
                        }

                        # Normalize REST response inline (can't call script-scope functions from parallel runspace)
                        $normalizedSkus = foreach ($sku in $allSkus) {
                            $locInfo = if ($sku.locationInfo) {
                                foreach ($li in $sku.locationInfo) {
                                    [pscustomobject]@{ Location = $li.location; Zones = @($li.zones) }
                                }
                            } else { @() }

                            $restrictions = if ($sku.restrictions) {
                                foreach ($r in $sku.restrictions) {
                                    [pscustomobject]@{
                                        Type            = $r.type
                                        ReasonCode      = $r.reasonCode
                                        RestrictionInfo = if ($r.restrictionInfo) {
                                            [pscustomobject]@{ Zones = @($r.restrictionInfo.zones); Locations = @($r.restrictionInfo.locations) }
                                        } else { $null }
                                    }
                                }
                            } else { @() }

                            $caps = if ($sku.capabilities) {
                                foreach ($c in $sku.capabilities) {
                                    [pscustomobject]@{ Name = $c.name; Value = $c.value }
                                }
                            } else { @() }

                            $capIndex = @{}
                            foreach ($c in $caps) { $capIndex[$c.Name] = $c.Value }

                            [pscustomobject]@{
                                Name         = $sku.name
                                ResourceType = $sku.resourceType
                                Family       = $sku.family
                                LocationInfo = @($locInfo)
                                Restrictions = @($restrictions)
                                Capabilities = @($caps)
                                _CapIndex    = $capIndex
                            }
                        }

                        $normalizedQuotas = if ($skipQuota) { @() } else {
                            foreach ($q in $quotaJson.value) {
                                [pscustomobject]@{
                                    Name = [pscustomobject]@{
                                        Value          = $q.name.value
                                        LocalizedValue = $q.name.localizedValue
                                    }
                                    CurrentValue = $q.currentValue
                                    Limit        = $q.limit
                                }
                            }
                        }

                        @{ Region = [string]$region; Skus = @($normalizedSkus); Quotas = @($normalizedQuotas); Error = $null }
                    }
                    catch {
                        @{ Region = [string]$region; Skus = @(); Quotas = @(); Error = $_.Exception.Message }
                    }
                } -ThrottleLimit $ParallelThrottleLimit
            }
            catch {
                Write-Warning "Parallel region scan failed: $($_.Exception.Message)"
                Write-Warning "Falling back to sequential scan mode for compatibility."
                $canUseParallel = $false
            }
        }

        if (-not $canUseParallel) {
            $regionData = foreach ($region in $Regions) {
                & $scanRegionScript -region ([string]$region) -skuFilterCopy $SkuFilter -maxRetries $MaxRetries -armUrl $armUrl -bearerToken $bearerToken -retryPattern $retryErrorPattern -skipQuota $NoQuota.IsPresent
            }
        }

        # Zero out bearer token after use
        $bearerToken = $null

        Write-Progress -Activity "Scanning Azure Regions" -Completed

        $scanElapsed = (Get-Date) - $subscriptionScanStartTime
        Write-Host "[$subName] Scan complete in $([math]::Round($scanElapsed.TotalSeconds, 1))s" -ForegroundColor Green

        $allSubscriptionData += @{
            SubscriptionId   = $subId
            SubscriptionName = $subName
            RegionData       = $regionData
        }
    }
}
catch {
    Write-Verbose "Scan loop interrupted: $($_.Exception.Message)"
    throw
}

#endregion Data Collection
#region Inventory Readiness

if ($Inventory -and $Inventory.Count -gt 0) {
    $inventoryResult = Get-InventoryReadiness -Inventory $Inventory -SubscriptionData $allSubscriptionData
    Write-InventoryReadinessSummary -InventoryResult $inventoryResult -Inventory $Inventory

    if ($JsonOutput) {
        $inventoryResult | ConvertTo-Json -Depth 5
    }

    # Inventory mode exits after summary — no need to render full scan output
    return
}

#endregion Inventory Readiness
#region Lifecycle Recommendations

if (($LifecycleRecommendations -or $LifecycleScan) -and $lifecycleEntries.Count -gt 0) {
    $lifecycleResults = [System.Collections.Generic.List[PSCustomObject]]::new()
    $skuIndex = 0

    # Pre-build indexes for O(1) lookups during the lifecycle loop
    $lcSkuIndex = @{}       # "SKUName|region" → raw SKU object (for .Family quota key)
    $lcQuotaIndex = @{}     # "region" → hashtable of quota name → quota object
    foreach ($subData in $allSubscriptionData) {
        foreach ($rd in $subData.RegionData) {
            if ($rd.Error) { continue }
            $regionKey = [string]$rd.Region
            if (-not $lcQuotaIndex.ContainsKey($regionKey)) {
                $qLookup = @{}
                foreach ($q in $rd.Quotas) { $qLookup[$q.Name.Value] = $q }
                $lcQuotaIndex[$regionKey] = $qLookup
            }
            foreach ($sku in $rd.Skus) {
                $skuRegionKey = "$($sku.Name)|$regionKey"
                if (-not $lcSkuIndex.ContainsKey($skuRegionKey)) {
                    $lcSkuIndex[$skuRegionKey] = $sku
                }
            }
        }
    }

    # Candidate profile cache — populated on first Invoke-RecommendMode call, reused for all subsequent
    $lcProfileCache = @{}

    # Load upgrade path knowledge base for AI-curated recommendations
    $upgradePathData = $null
    $upgradePathFile = Join-Path $PSScriptRoot 'data' 'UpgradePath.json'
    if (Test-Path -LiteralPath $upgradePathFile) {
        try {
            $upgradePathData = Get-Content -LiteralPath $upgradePathFile -Raw | ConvertFrom-Json
            Write-Verbose "Loaded upgrade path knowledge base v$($upgradePathData._metadata.version) ($($upgradePathData._metadata.lastUpdated))"
        }
        catch {
            Write-Verbose "Failed to load UpgradePath.json: $_"
        }
    }

    # Fetch retirement data from Azure Advisor (authoritative source, supersedes pattern table)
    try {
        $advisorArmUrl = if ($script:AzureEndpoints) { $script:AzureEndpoints.ResourceManagerUrl } else { 'https://management.azure.com' }
        $advisorTokenResult = Get-AzAccessToken -ResourceUrl $advisorArmUrl -ErrorAction Stop
        $advisorToken = if ($advisorTokenResult.Token -is [System.Security.SecureString]) {
            [System.Net.NetworkCredential]::new('', $advisorTokenResult.Token).Password
        } else { $advisorTokenResult.Token }
        $advisorRetirement = Get-AdvisorRetirementData -SubscriptionId $subId -ArmUrl $advisorArmUrl -BearerToken $advisorToken -MaxRetries $MaxRetries
        $advisorToken = $null
        if ($advisorRetirement.Count -gt 0) {
            Write-Host "  Advisor: $($advisorRetirement.Count) retirement group(s) detected" -ForegroundColor DarkYellow
        }
    }
    catch {
        Write-Verbose "Advisor retirement fetch skipped: $_"
    }

    foreach ($entry in $lifecycleEntries) {
        $targetSku = $entry.SKU
        $deployedRegion = $entry.Region
        $entryQty = $entry.Qty
        $skuIndex++
        $regionLabel = if ($deployedRegion) { " (deployed: $deployedRegion)" } else { '' }
        $qtyLabel = if ($entryQty -gt 1) { " x$entryQty" } else { '' }
        if (-not $JsonOutput) {
            Write-Host ""
            Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
            Write-Host "LIFECYCLE ANALYSIS [$skuIndex/$($lifecycleEntries.Count)]: $targetSku$qtyLabel$regionLabel" -ForegroundColor Cyan
            Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
        }

        Invoke-RecommendMode -TargetSkuName $targetSku -SubscriptionData $allSubscriptionData `
            -FamilyInfo $FamilyInfo -Icons $Icons -FetchPricing ([bool]$FetchPricing) `
            -ShowSpot $ShowSpot.IsPresent -ShowPlacement $ShowPlacement.IsPresent `
            -AllowMixedArch $AllowMixedArch.IsPresent -MinvCPU $MinvCPU -MinMemoryGB $MinMemoryGB `
            -MinScore $MinScore -TopN $TopN -DesiredCount $DesiredCount `
            -JsonOutput $false -MaxRetries $MaxRetries `
            -RunContext $script:RunContext -OutputWidth $script:OutputWidth `
            -SkuProfileCache $lcProfileCache

        # Capture lifecycle risk signals from the recommend output
        $recOutput = $script:RunContext.RecommendOutput
        if ($recOutput) {
            $target = $recOutput.target
            $allRecs = @($recOutput.recommendations)

            # Look up target SKU monthly price for cost-diff calculation
            $targetPriceMo = $null
            if ($FetchPricing -and $deployedRegion -and $script:RunContext.RegionPricing[$deployedRegion]) {
                $tgtPriceMap = Get-RegularPricingMap -PricingContainer $script:RunContext.RegionPricing[$deployedRegion]
                $tgtPriceEntry = $tgtPriceMap[$target.Name]
                if ($tgtPriceEntry) { $targetPriceMo = [double]$tgtPriceEntry.Monthly }
            }

            # Detect lifecycle risk: old generation, capacity issues, no alternatives
            $generation = if ($target.Name -match '_v(\d+)$') { [int]$Matches[1] } else { 1 }
            $targetAvail = $recOutput.targetAvailability

            # If a deployed region was specified, check availability specifically in that region
            $hasCapacityIssues = $false
            if ($deployedRegion) {
                $deployedStatus = $targetAvail | Where-Object { $_.Region -eq $deployedRegion } | Select-Object -First 1
                if ($deployedStatus -and $deployedStatus.Status -notin 'OK','LIMITED') {
                    $hasCapacityIssues = $true
                }
                elseif (-not $deployedStatus) {
                    $hasCapacityIssues = $true
                }
            }
            else {
                $hasCapacityIssues = @($targetAvail | Where-Object { $_.Status -notin 'OK','LIMITED' }).Count -gt 0
            }

            # Quota analysis for target SKU: use pre-built indexes for O(1) lookup
            $targetQuotaStatus = '-'
            $targetQuotaAvail = $null
            $quotaInsufficient = $false
            if (-not $NoQuota) {
                $lookupRegions = if ($deployedRegion) { @($deployedRegion) } else { @($lcQuotaIndex.Keys) }
                foreach ($qRegion in $lookupRegions) {
                    if ($targetQuotaAvail) { break }
                    $regionQuotas = $lcQuotaIndex[$qRegion]
                    if (-not $regionQuotas) { continue }
                    $rawSku = $lcSkuIndex["$($target.Name)|$qRegion"]
                    if ($rawSku) {
                        $requiredvCPUs = $entryQty * [int]$target.vCPU
                        $qi = Get-QuotaAvailable -QuotaLookup $regionQuotas -SkuFamily $rawSku.Family -RequiredvCPUs $requiredvCPUs
                        if ($null -ne $qi.Available) {
                            $targetQuotaAvail = $qi
                            $targetQuotaStatus = "$($qi.Current)/$($qi.Limit) (avail: $($qi.Available))"
                            if (-not $qi.OK) { $quotaInsufficient = $true }
                        }
                    }
                }
            }

            $isOldGen = $generation -le 3
            $noAlternatives = $allRecs.Count -eq 0

            $riskLevel = 'Low'
            $riskReasons = [System.Collections.Generic.List[string]]::new()
            if ($isOldGen) { $riskReasons.Add("Gen v$generation"); $riskLevel = 'Medium' }
            $retirementInfo = Get-SkuRetirementInfo -SkuName $target.Name
            if ($retirementInfo) {
                $retireLabel = if ($retirementInfo.Status -eq 'Retired') { "Retired $($retirementInfo.RetireDate)" } else { "Retiring $($retirementInfo.RetireDate)" }
                $riskReasons.Add($retireLabel)
                $riskLevel = 'High'
            }
            if ($hasCapacityIssues) { $riskReasons.Add("Capacity$(if ($deployedRegion) { " ($deployedRegion)" } else { '' })"); $riskLevel = 'High' }
            if ($quotaInsufficient) { $riskReasons.Add("Quota: need $($entryQty)x$($target.vCPU)vCPU"); $riskLevel = 'High' }
            if ($noAlternatives -and ($isOldGen -or $hasCapacityIssues -or $retirementInfo)) { $riskReasons.Add("No alternatives"); $riskLevel = 'High' }

            # Current-gen (v4+) SKUs with quota as the only risk → recommend quota increase, not SKU change
            $isQuotaOnlyCurrentGen = (-not $isOldGen) -and (-not $hasCapacityIssues) -and (-not $retirementInfo) -and $quotaInsufficient

            # Select up to 3 weighted recommendations: like-for-like, best fit, alternative
            $ScoreCloseThreshold = 10
            $MaxWeightedRecs = 3
            $selectedRecs = [System.Collections.Generic.List[pscustomobject]]::new()
            $usedSkus = [System.Collections.Generic.HashSet[string]]::new()

            # Inject upgrade path recommendations from knowledge base FIRST (up to 3)
            # Upgrade paths get priority so weighted recs fill remaining slots with different SKUs
            if ($upgradePathData -and $riskLevel -ne 'Low' -and (-not $isQuotaOnlyCurrentGen)) {
                $targetFamily = $target.Family
                $targetVersion = [int]$target.FamilyVersion
                $targetvCPU = [string][int]$target.vCPU
                # Normalize family: DS→D, GS→G (the S suffix indicates Premium SSD, same family)
                $normalizedFamily = if ($targetFamily -cmatch '^([A-Z]+)S$' -and $targetFamily -notin 'NVS','NCS','NDS','HBS','HCS','HXS','FXS') { $Matches[1] } else { $targetFamily }
                $pathKey = "${normalizedFamily}v${targetVersion}"
                $upgradePath = $upgradePathData.upgradePaths.$pathKey

                if ($upgradePath) {
                    $upgradeRecs = [System.Collections.Generic.List[pscustomobject]]::new()
                    $pathLabels = @(
                        @{ Key = 'dropIn'; Label = 'Upgrade: Drop-in' }
                        @{ Key = 'futureProof'; Label = 'Upgrade: Future-proof' }
                        @{ Key = 'costOptimized'; Label = 'Upgrade: Cost-optimized' }
                    )

                    foreach ($pl in $pathLabels) {
                        $pathEntry = $upgradePath.$($pl.Key)
                        if (-not $pathEntry) { continue }

                        # Look up the size-matched SKU from the sizeMap
                        $mappedSku = $pathEntry.sizeMap.$targetvCPU
                        if (-not $mappedSku) {
                            # Find nearest vCPU match (next size up)
                            $availSizes = @($pathEntry.sizeMap.PSObject.Properties.Name | ForEach-Object { [int]$_ } | Sort-Object)
                            $nearestSize = $availSizes | Where-Object { $_ -ge [int]$targetvCPU } | Select-Object -First 1
                            if ($nearestSize) { $mappedSku = $pathEntry.sizeMap."$nearestSize" }
                            elseif ($availSizes.Count -gt 0) { $mappedSku = $pathEntry.sizeMap."$($availSizes[-1])" }
                        }
                        if (-not $mappedSku) { continue }

                        # Skip if already used by a prior upgrade path entry
                        if ($usedSkus.Contains($mappedSku)) { continue }

                        # Check if this SKU exists in the scored candidates
                        $scoredMatch = $allRecs | Where-Object { $_.sku -eq $mappedSku } | Select-Object -First 1
                        if ($scoredMatch) {
                            $upgradeRecs.Add([pscustomobject]@{ Rec = $scoredMatch; MatchType = $pl.Label })
                            $usedSkus.Add($mappedSku) | Out-Null
                        }
                        else {
                            # SKU not in scored candidates — check raw scan data (may have failed compat gate)
                            $rawUpgradeSku = $null
                            $rawSkuRegion = $deployedRegion
                            if ($deployedRegion) {
                                $rawUpgradeSku = $lcSkuIndex["$mappedSku|$deployedRegion"]
                            }
                            if (-not $rawUpgradeSku) {
                                foreach ($rk in $lcSkuIndex.Keys) {
                                    if ($rk.StartsWith("$mappedSku|")) {
                                        $rawUpgradeSku = $lcSkuIndex[$rk]
                                        $rawSkuRegion = $rk.Substring($mappedSku.Length + 1)
                                        break
                                    }
                                }
                            }

                            if ($rawUpgradeSku) {
                                # Build rec from actual scan data and profile cache
                                $upRestrictions = Get-RestrictionDetails $rawUpgradeSku
                                $cached = if ($lcProfileCache.ContainsKey($mappedSku)) { $lcProfileCache[$mappedSku] } else { $null }
                                if ($cached) {
                                    $upVcpu = $cached.Profile.vCPU
                                    $upMemGiB = $cached.Profile.MemoryGB
                                    $upIOPS = $cached.Caps.UncachedDiskIOPS
                                    $upMaxDisks = $cached.Caps.MaxDataDiskCount
                                    $upCandidateProfile = $cached.Profile
                                }
                                else {
                                    $upCaps = Get-SkuCapabilities -Sku $rawUpgradeSku
                                    $upVcpu = [int](Get-CapValue $rawUpgradeSku 'vCPUs')
                                    $upMemGiB = [int](Get-CapValue $rawUpgradeSku 'MemoryGB')
                                    $upIOPS = $upCaps.UncachedDiskIOPS
                                    $upMaxDisks = $upCaps.MaxDataDiskCount
                                    $upCandidateProfile = @{
                                        Name     = $mappedSku
                                        vCPU     = $upVcpu
                                        MemoryGB = $upMemGiB
                                        Family   = Get-SkuFamily $mappedSku
                                        Generation               = $upCaps.HyperVGenerations
                                        Architecture             = $upCaps.CpuArchitecture
                                        PremiumIO                = (Get-CapValue $rawUpgradeSku 'PremiumIO') -eq 'True'
                                        DiskCode                 = Get-DiskCode -HasTempDisk ($upCaps.TempDiskGB -gt 0) -HasNvme $upCaps.NvmeSupport
                                        AccelNet                 = $upCaps.AcceleratedNetworkingEnabled
                                        MaxDataDiskCount         = $upCaps.MaxDataDiskCount
                                        MaxNetworkInterfaces     = $upCaps.MaxNetworkInterfaces
                                        EphemeralOSDiskSupported  = $upCaps.EphemeralOSDiskSupported
                                        UltraSSDAvailable        = $upCaps.UltraSSDAvailable
                                        UncachedDiskIOPS         = $upCaps.UncachedDiskIOPS
                                        UncachedDiskBytesPerSecond = $upCaps.UncachedDiskBytesPerSecond
                                        EncryptionAtHostSupported = $upCaps.EncryptionAtHostSupported
                                    }
                                }
                                # Compute similarity score against the target profile
                                $targetProfileHt = @{}
                                foreach ($p in $target.PSObject.Properties) { $targetProfileHt[$p.Name] = $p.Value }
                                $upScore = Get-SkuSimilarityScore -Target $targetProfileHt -Candidate $upCandidateProfile -FamilyInfo $FamilyInfo
                                $upPriceMo = $null
                                if ($FetchPricing -and $rawSkuRegion -and $script:RunContext.RegionPricing[$rawSkuRegion]) {
                                    $prMap = Get-RegularPricingMap -PricingContainer $script:RunContext.RegionPricing[$rawSkuRegion]
                                    $prEntry = $prMap[$mappedSku]
                                    if ($prEntry) { $upPriceMo = $prEntry.Monthly }
                                }
                                $upgradeRecs.Add([pscustomobject]@{
                                    Rec = [pscustomobject]@{
                                        sku      = $mappedSku
                                        vCPU     = $upVcpu
                                        memGiB   = $upMemGiB
                                        family   = Get-SkuFamily $mappedSku
                                        score    = $upScore
                                        capacity = $upRestrictions.Status
                                        IOPS     = $upIOPS
                                        MaxDisks = $upMaxDisks
                                        priceMo  = $upPriceMo
                                    }
                                    MatchType = $pl.Label
                                })
                                $usedSkus.Add($mappedSku) | Out-Null
                            }
                            else {
                                # SKU not in any scanned region — skip (no data to compare)
                                continue
                            }
                        }
                    }

                    # Add upgrade recs to selectedRecs (weighted recs will be appended after)
                    foreach ($ur in $upgradeRecs) { $selectedRecs.Add($ur) }
                }
            }

            # Build weighted recommendations from scored candidates (excluding upgrade path SKUs)
            if ($riskLevel -ne 'Low' -and (-not $isQuotaOnlyCurrentGen) -and $allRecs.Count -gt 0) {
                $filteredRecs = if ($usedSkus.Count -gt 0) {
                    @($allRecs | Where-Object { -not $usedSkus.Contains($_.sku) })
                } else { $allRecs }

                if ($filteredRecs.Count -gt 0) {
                    $bestFit = $filteredRecs | Sort-Object -Property score -Descending | Select-Object -First 1
                    $likeForLike = $filteredRecs | Where-Object { $_.vCPU -eq [int]$target.vCPU } | Sort-Object -Property score -Descending | Select-Object -First 1

                    $weightedRecs = [System.Collections.Generic.List[pscustomobject]]::new()
                    if ($likeForLike -and $likeForLike.sku -ne $bestFit.sku) {
                        $weightedRecs.Add([pscustomobject]@{ Rec = $likeForLike; MatchType = 'Like-for-like' })
                        $weightedRecs.Add([pscustomobject]@{ Rec = $bestFit; MatchType = 'Best fit' })
                    }
                    else {
                        $matchLabel = if ($likeForLike -and $likeForLike.sku -eq $bestFit.sku) { 'Like-for-like' } else { 'Best fit' }
                        $weightedRecs.Add([pscustomobject]@{ Rec = $bestFit; MatchType = $matchLabel })
                    }

                    foreach ($s in $weightedRecs) { $usedSkus.Add($s.Rec.sku) | Out-Null }

                    foreach ($altRec in $filteredRecs) {
                        if ($weightedRecs.Count -ge $MaxWeightedRecs) { break }
                        if ($usedSkus.Contains($altRec.sku)) { continue }
                        if ($altRec.score -ge ($bestFit.score - $ScoreCloseThreshold)) {
                            $weightedRecs.Add([pscustomobject]@{ Rec = $altRec; MatchType = 'Alternative' })
                            $usedSkus.Add($altRec.sku) | Out-Null
                        }
                    }

                    # Guarantee at least one rec with IOPS >= target (no performance downgrade)
                    $targetIOPS = [int]$target.UncachedDiskIOPS
                    if ($targetIOPS -gt 0) {
                        $hasIopsMatch = $selectedRecs + @($weightedRecs) | Where-Object { [int]$_.Rec.IOPS -ge $targetIOPS }
                        if (-not $hasIopsMatch) {
                            $iopsCandidate = $allRecs |
                                Where-Object { [int]$_.IOPS -ge $targetIOPS -and -not $usedSkus.Contains($_.sku) } |
                                Sort-Object -Property score -Descending |
                                Select-Object -First 1
                            if ($iopsCandidate) {
                                $weightedRecs.Add([pscustomobject]@{ Rec = $iopsCandidate; MatchType = 'IOPS match' })
                                $usedSkus.Add($iopsCandidate.sku) | Out-Null
                            }
                        }
                    }

                    # Append weighted recs after upgrade path recs
                    foreach ($wr in $weightedRecs) { $selectedRecs.Add($wr) }
                }
            }

            # Look up savings plan and reservation pricing maps for this region
            $sp1YrMap = @{}; $sp3YrMap = @{}; $ri1YrMap = @{}; $ri3YrMap = @{}
            if ($RateOptimization -and $FetchPricing -and $deployedRegion -and $script:RunContext.RegionPricing[$deployedRegion]) {
                $regionContainer = $script:RunContext.RegionPricing[$deployedRegion]
                $sp1YrMap = Get-SavingsPlanPricingMap -PricingContainer $regionContainer -Term '1Yr'
                $sp3YrMap = Get-SavingsPlanPricingMap -PricingContainer $regionContainer -Term '3Yr'
                $ri1YrMap = Get-ReservationPricingMap -PricingContainer $regionContainer -Term '1Yr'
                $ri3YrMap = Get-ReservationPricingMap -PricingContainer $regionContainer -Term '3Yr'
            }

            # Build lifecycle result rows — one per selected recommendation (or one summary row)
            if ($selectedRecs.Count -eq 0) {
                $lifecycleResults.Add([pscustomobject]@{
                    SKU              = $target.Name
                    DeployedRegion   = if ($deployedRegion) { $deployedRegion } else { '-' }
                    Qty              = $entryQty
                    vCPU             = $target.vCPU
                    MemoryGB         = $target.MemoryGB
                    Generation       = "v$generation"
                    RiskLevel        = $riskLevel
                    RiskReasons      = ($riskReasons -join '; ')
                    QuotaStatus      = $targetQuotaStatus
                    MatchType        = '-'
                    TopAlternative   = if ($riskLevel -eq 'Low') { 'N/A' } elseif ($isQuotaOnlyCurrentGen) { 'Request quota increase' } else { '-' }
                    AltScore         = ''
                    CpuDelta         = '-'
                    MemDelta         = '-'
                    DiskDelta        = '-'
                    IopsDelta        = '-'
                    AltCapacity      = '-'
                    AltQuotaStatus   = '-'
                    PriceDiff        = '-'
                    TotalPriceDiff   = '-'
                    PAYG1Yr          = '-'
                    PAYG3Yr          = '-'
                    SP1YrSavings     = '-'
                    SP3YrSavings     = '-'
                    RI1YrSavings     = '-'
                    RI3YrSavings     = '-'
                    AlternativeCount = 0
                    Details          = if ($riskLevel -eq 'Low') { '-' } elseif ($isQuotaOnlyCurrentGen) { 'Current gen; quota increase recommended' } else { 'No suitable alternatives found in scanned regions' }
                })
            }
            else {
                $isFirstRow = $true
                foreach ($sel in $selectedRecs) {
                    $rec = $sel.Rec
                    # Quota lookup for this specific alternative
                    $thisAltQuota = '-'
                    if (-not $NoQuota) {
                        $lookupRegions = if ($deployedRegion) { @($deployedRegion) } else { @($lcQuotaIndex.Keys) }
                        foreach ($qRegion in $lookupRegions) {
                            $altRawSku = $lcSkuIndex["$($rec.sku)|$qRegion"]
                            if ($altRawSku) {
                                $regionQuotas = $lcQuotaIndex[$qRegion]
                                if ($regionQuotas) {
                                    $altRequiredvCPUs = $entryQty * [int]$rec.vCPU
                                    $altQi = Get-QuotaAvailable -QuotaLookup $regionQuotas -SkuFamily $altRawSku.Family -RequiredvCPUs $altRequiredvCPUs
                                    if ($null -ne $altQi.Available) {
                                        $thisAltQuota = "$($altQi.Current)/$($altQi.Limit) (avail: $($altQi.Available))"
                                        break
                                    }
                                }
                            }
                        }
                    }

                    # Calculate price difference for this alternative
                    $priceDiffStr = '-'
                    $totalDiffStr = '-'
                    $payg1YrStr = '-'
                    $payg3YrStr = '-'
                    if ($null -ne $targetPriceMo -and $null -ne $rec.priceMo) {
                        $diff = [double]$rec.priceMo - $targetPriceMo
                        $priceDiffStr = if ($diff -ge 0) { '+$' + $diff.ToString('0') } else { '-$' + ([Math]::Abs($diff)).ToString('0') }
                        $totalDiff = $diff * $entryQty
                        $totalDiffStr = if ($totalDiff -ge 0) { '+$' + $totalDiff.ToString('N0') } else { '-$' + ([Math]::Abs($totalDiff)).ToString('N0') }
                        $payg1Yr = [double]$rec.priceMo * 12 * $entryQty
                        $payg1YrStr = '$' + $payg1Yr.ToString('N0')
                        $payg3Yr = [double]$rec.priceMo * 36 * $entryQty
                        $payg3YrStr = '$' + $payg3Yr.ToString('N0')
                    }

                    # Look up savings plan and reservation savings vs PAYG fleet total
                    $sp1YrSavingsStr = '-'; $sp3YrSavingsStr = '-'; $ri1YrSavingsStr = '-'; $ri3YrSavingsStr = '-'
                    if ($RateOptimization -and $FetchPricing -and $null -ne $rec.priceMo) {
                        $recPaygFleet1Yr = [double]$rec.priceMo * 12 * $entryQty
                        $recPaygFleet3Yr = [double]$rec.priceMo * 36 * $entryQty
                        $sp1Entry = $sp1YrMap[$rec.sku]
                        if ($sp1Entry) { $sp1Fleet = [double]$sp1Entry.Monthly * 12 * $entryQty; $sp1Savings = $recPaygFleet1Yr - $sp1Fleet; $sp1YrSavingsStr = '$' + $sp1Savings.ToString('N0') }
                        $sp3Entry = $sp3YrMap[$rec.sku]
                        if ($sp3Entry) { $sp3Fleet = [double]$sp3Entry.Monthly * 36 * $entryQty; $sp3Savings = $recPaygFleet3Yr - $sp3Fleet; $sp3YrSavingsStr = '$' + $sp3Savings.ToString('N0') }
                        $ri1Entry = $ri1YrMap[$rec.sku]
                        if ($ri1Entry) { $ri1Fleet = [double]$ri1Entry.Total * $entryQty; $ri1Savings = $recPaygFleet1Yr - $ri1Fleet; $ri1YrSavingsStr = '$' + $ri1Savings.ToString('N0') }
                        $ri3Entry = $ri3YrMap[$rec.sku]
                        if ($ri3Entry) { $ri3Fleet = [double]$ri3Entry.Total * $entryQty; $ri3Savings = $recPaygFleet3Yr - $ri3Fleet; $ri3YrSavingsStr = '$' + $ri3Savings.ToString('N0') }
                    }

                    # Compute CPU, memory, and disk deltas
                    $isUnscannedUpgrade = ($rec.capacity -eq 'Not scanned')
                    if ($isUnscannedUpgrade) {
                        $cpuDiff = 0; $cpuDeltaStr = '-'
                        $memDiff = 0; $memDeltaStr = '-'
                        $diskDeltaStr = '-'
                        $iopsDiff = 0; $iopsDeltaStr = '-'
                    }
                    else {
                        $cpuDiff = [int]$rec.vCPU - [int]$target.vCPU
                        $cpuDeltaStr = if ($cpuDiff -eq 0) { '=' } elseif ($cpuDiff -gt 0) { "+$cpuDiff" } else { "$cpuDiff" }
                        $memDiff = [double]$rec.memGiB - [double]$target.MemoryGB
                        $memDeltaStr = if ($memDiff -eq 0) { '=' } elseif ($memDiff -gt 0) { "+$memDiff" } else { "$memDiff" }
                        $diskDiff = [int]$rec.MaxDisks - [int]$target.MaxDataDiskCount
                        $diskDeltaStr = if ($diskDiff -eq 0) { '=' } elseif ($diskDiff -gt 0) { "+$diskDiff" } else { "$diskDiff" }
                        $iopsDiff = [int]$rec.IOPS - [int]$target.UncachedDiskIOPS
                        $iopsDeltaStr = if ($iopsDiff -eq 0) { '=' } elseif ($iopsDiff -gt 0) { "+$iopsDiff" } else { "$iopsDiff" }
                    }

                    # Build Details string explaining why this recommendation was selected
                    $targetFamily = $target.Family
                    $targetVersion = [int]$target.FamilyVersion
                    $recFamily = Get-SkuFamily $rec.sku
                    $recVersion = if ($rec.sku -match '_v(\d+)$') { [int]$Matches[1] } else { 1 }

                    $detailParts = [System.Collections.Generic.List[string]]::new()

                    # Upgrade path recommendations get their reason from the knowledge base
                    if ($sel.MatchType -like 'Upgrade:*' -and $upgradePathData) {
                        $detailNormFamily = if ($targetFamily -cmatch '^([A-Z]+)S$' -and $targetFamily -notin 'NVS','NCS','NDS','HBS','HCS','HXS','FXS') { $Matches[1] } else { $targetFamily }
                        $pathKey = "${detailNormFamily}v${targetVersion}"
                        $upgradePath = $upgradePathData.upgradePaths.$pathKey
                        if ($upgradePath) {
                            $pathTypeKey = switch -Wildcard ($sel.MatchType) {
                                '*Drop-in'        { 'dropIn' }
                                '*Future-proof'    { 'futureProof' }
                                '*Cost-optimized'  { 'costOptimized' }
                            }
                            $pathEntry = if ($pathTypeKey) { $upgradePath.$pathTypeKey } else { $null }
                            if ($pathEntry -and $pathEntry.reason) {
                                $detailParts.Add($pathEntry.reason)
                            }
                            if ($pathEntry -and $pathEntry.requirements -and $pathEntry.requirements.Count -gt 0) {
                                $detailParts.Add("Requires: $($pathEntry.requirements -join ', ')")
                            }
                        }
                        if ($rec.capacity -eq 'Not scanned') {
                            $detailParts.Add("availability not verified (region not scanned)")
                        }
                    }
                    else {
                        # Weighted recommendation — existing family/version analysis
                        if ($recFamily -eq $targetFamily) {
                            if ($recVersion -gt $targetVersion) {
                                $detailParts.Add("$targetFamily-family v$targetVersion→v$recVersion upgrade")
                            }
                            elseif ($recVersion -eq $targetVersion) {
                                $detailParts.Add("Same $targetFamily-family v$recVersion")
                            }
                            else {
                                $detailParts.Add("$targetFamily-family v$recVersion (older generation)")
                            }
                        }
                        else {
                            $hasSameFamily = $allRecs | Where-Object { (Get-SkuFamily $_.sku) -eq $targetFamily } | Select-Object -First 1
                            if ($hasSameFamily) {
                                $detailParts.Add("Cross-family: $recFamily-family v$recVersion selected (same-family options scored lower)")
                            }
                            else {
                                $detailParts.Add("Cross-family: $recFamily-family v$recVersion (no $targetFamily-family v${targetVersion}+ available)")
                            }
                        }

                        if ($sel.MatchType -eq 'Like-for-like') {
                            $detailParts.Add("same vCPU count ($($rec.vCPU))")
                        }
                        elseif ($sel.MatchType -eq 'IOPS match') {
                            $detailParts.Add("IOPS guarantee: maintains ≥$($target.UncachedDiskIOPS) IOPS")
                        }
                    }

                    if ($cpuDiff -ne 0 -or $memDiff -ne 0) {
                        $resizeParts = @()
                        if ($cpuDiff -gt 0) { $resizeParts += "+$cpuDiff vCPU" }
                        elseif ($cpuDiff -lt 0) { $resizeParts += "$cpuDiff vCPU" }
                        if ($memDiff -gt 0) { $resizeParts += "+$memDiff GB RAM" }
                        elseif ($memDiff -lt 0) { $resizeParts += "$memDiff GB RAM" }
                        if ($resizeParts.Count -gt 0) { $detailParts.Add("resize: $($resizeParts -join ', ')") }
                    }

                    $detailsStr = $detailParts -join '; '

                    $lifecycleResults.Add([pscustomobject]@{
                        SKU              = if ($isFirstRow) { $target.Name } else { '' }
                        DeployedRegion   = if ($isFirstRow) { if ($deployedRegion) { $deployedRegion } else { '-' } } else { '' }
                        Qty              = if ($isFirstRow) { $entryQty } else { '' }
                        vCPU             = if ($isFirstRow) { $target.vCPU } else { '' }
                        MemoryGB         = if ($isFirstRow) { $target.MemoryGB } else { '' }
                        Generation       = if ($isFirstRow) { "v$generation" } else { '' }
                        RiskLevel        = if ($isFirstRow) { $riskLevel } else { '' }
                        RiskReasons      = if ($isFirstRow) { ($riskReasons -join '; ') } else { '' }
                        QuotaStatus      = if ($isFirstRow) { $targetQuotaStatus } else { '' }
                        MatchType        = $sel.MatchType
                        TopAlternative   = $rec.sku
                        AltScore         = if ($rec.score -is [ValueType] -and $rec.score -isnot [bool]) { "$([int]$rec.score)%" } else { '' }
                        CpuDelta         = $cpuDeltaStr
                        MemDelta         = $memDeltaStr
                        DiskDelta        = $diskDeltaStr
                        IopsDelta        = $iopsDeltaStr
                        AltCapacity      = $rec.capacity
                        AltQuotaStatus   = $thisAltQuota
                        PriceDiff        = $priceDiffStr
                        TotalPriceDiff   = $totalDiffStr
                        PAYG1Yr          = $payg1YrStr
                        PAYG3Yr          = $payg3YrStr
                        SP1YrSavings     = $sp1YrSavingsStr
                        SP3YrSavings     = $sp3YrSavingsStr
                        RI1YrSavings     = $ri1YrSavingsStr
                        RI3YrSavings     = $ri3YrSavingsStr
                        AlternativeCount = if ($isFirstRow) { $allRecs.Count } else { '' }
                        Details          = $detailsStr
                    })

                    $isFirstRow = $false
                }
            }
        }
    }

    # Print lifecycle summary
    $uniqueSkuCount = @($lifecycleResults | Where-Object { $_.SKU -ne '' }).Count
    $totalVMCount = ($lifecycleResults | Where-Object { $_.Qty -ne '' } | Measure-Object -Property Qty -Sum).Sum
    if (-not $JsonOutput) {
        Write-Host ""
        Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
        Write-Host "LIFECYCLE RECOMMENDATIONS SUMMARY  ($uniqueSkuCount SKUs, $totalVMCount VMs)" -ForegroundColor Green
        Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
        Write-Host ""

        if ($NoQuota) {
            if ($FetchPricing) {
                $sumFmt = " {0,-26} {1,-13} {2,-4} {3,-5} {4,-7} {5,-4} {6,-7} {7,-33} {8,-24} {9,-26} {10,-6} {11,-5} {12,-5} {13,-7} {14,-8} {15,-10} {16,-12}"
                Write-Host ($sumFmt -f 'Current SKU', 'Region', 'Qty', 'vCPU', 'Mem(GB)', 'Gen', 'Risk', 'Risk Reasons', 'Match Type', 'Alternative', 'Score', 'CPU+/-', 'Mem+/-', 'Disk+/-', 'IOPS+/-', 'Price Diff', 'Total') -ForegroundColor White
            }
            else {
                $sumFmt = " {0,-26} {1,-13} {2,-4} {3,-5} {4,-7} {5,-4} {6,-7} {7,-33} {8,-24} {9,-26} {10,-6} {11,-5} {12,-5} {13,-7} {14,-8}"
                Write-Host ($sumFmt -f 'Current SKU', 'Region', 'Qty', 'vCPU', 'Mem(GB)', 'Gen', 'Risk', 'Risk Reasons', 'Match Type', 'Alternative', 'Score', 'CPU+/-', 'Mem+/-', 'Disk+/-', 'IOPS+/-') -ForegroundColor White
            }
        }
        else {
            if ($FetchPricing) {
                $sumFmt = " {0,-26} {1,-13} {2,-4} {3,-5} {4,-7} {5,-4} {6,-7} {7,-22} {8,-33} {9,-24} {10,-26} {11,-6} {12,-5} {13,-5} {14,-7} {15,-8} {16,-10} {17,-10} {18,-12}"
                Write-Host ($sumFmt -f 'Current SKU', 'Region', 'Qty', 'vCPU', 'Mem(GB)', 'Gen', 'Risk', 'Quota (used/limit)', 'Risk Reasons', 'Match Type', 'Alternative', 'Score', 'CPU+/-', 'Mem+/-', 'Disk+/-', 'IOPS+/-', 'Alt Quota', 'Price Diff', 'Total') -ForegroundColor White
            }
            else {
                $sumFmt = " {0,-26} {1,-13} {2,-4} {3,-5} {4,-7} {5,-4} {6,-7} {7,-22} {8,-33} {9,-24} {10,-26} {11,-6} {12,-5} {13,-5} {14,-7} {15,-8} {16,-10}"
                Write-Host ($sumFmt -f 'Current SKU', 'Region', 'Qty', 'vCPU', 'Mem(GB)', 'Gen', 'Risk', 'Quota (used/limit)', 'Risk Reasons', 'Match Type', 'Alternative', 'Score', 'CPU+/-', 'Mem+/-', 'Disk+/-', 'IOPS+/-', 'Alt Quota') -ForegroundColor White
            }
        }
        Write-Host (' ' + ('-' * ($script:OutputWidth - 2))) -ForegroundColor DarkGray

        $lastSeenRiskColor = 'Gray'
        foreach ($r in $lifecycleResults) {
            if ($r.RiskLevel -and $r.RiskLevel -ne '') {
                $riskColor = switch ($r.RiskLevel) {
                    'High'   { 'Red' }
                    'Medium' { 'Yellow' }
                    'Low'    { 'Green' }
                    default  { 'Gray' }
                }
                $lastSeenRiskColor = $riskColor
            }
            else {
                $riskColor = $lastSeenRiskColor
            }
            if ($NoQuota) {
                [object[]]$fmtArgs = @($r.SKU, $r.DeployedRegion, $r.Qty, $r.vCPU, $r.MemoryGB, $r.Generation, $r.RiskLevel, $r.RiskReasons, $r.MatchType, $r.TopAlternative, $r.AltScore, $r.CpuDelta, $r.MemDelta, $r.DiskDelta, $r.IopsDelta)
            }
            else {
                [object[]]$fmtArgs = @($r.SKU, $r.DeployedRegion, $r.Qty, $r.vCPU, $r.MemoryGB, $r.Generation, $r.RiskLevel, $r.QuotaStatus, $r.RiskReasons, $r.MatchType, $r.TopAlternative, $r.AltScore, $r.CpuDelta, $r.MemDelta, $r.DiskDelta, $r.IopsDelta, $r.AltQuotaStatus)
            }
            if ($FetchPricing) { $fmtArgs += @($r.PriceDiff, $r.TotalPriceDiff) }
            $line = $sumFmt -f $fmtArgs
            Write-Host $line -ForegroundColor $riskColor
        }

        $highRisk = @($lifecycleResults | Where-Object { $_.RiskLevel -eq 'High' })
        $medRisk = @($lifecycleResults | Where-Object { $_.RiskLevel -eq 'Medium' })
        $highVMs = ($highRisk | Measure-Object -Property Qty -Sum).Sum
        $medVMs = ($medRisk | Measure-Object -Property Qty -Sum).Sum
        Write-Host ""
        if ($highRisk.Count -gt 0) {
            Write-Host "  $($highRisk.Count) SKU(s) ($highVMs VMs) at HIGH risk — immediate action recommended" -ForegroundColor Red
        }
        if ($medRisk.Count -gt 0) {
            Write-Host "  $($medRisk.Count) SKU(s) ($medVMs VMs) at MEDIUM risk — plan migration to current generation" -ForegroundColor Yellow
        }
        if ($highRisk.Count -eq 0 -and $medRisk.Count -eq 0) {
            Write-Host "  All SKUs are current generation with good availability" -ForegroundColor Green
        }
        Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
    }

    # XLSX Export — auto-export lifecycle results
    if (-not $JsonOutput -and (Test-ImportExcelModule)) {
        $lcTimestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
        if ($LifecycleFile) {
            $sourceDir = [System.IO.Path]::GetDirectoryName((Resolve-Path -LiteralPath $LifecycleFile).Path)
            $sourceBase = [System.IO.Path]::GetFileNameWithoutExtension($LifecycleFile)
        }
        else {
            $sourceDir = $PWD.Path
            $sourceBase = 'AzVMAvailability'
        }
        $lcXlsxFile = Join-Path $sourceDir "${sourceBase}_Lifecycle_Recommendations_${lcTimestamp}.xlsx"

        try {
            $greenFill = [System.Drawing.Color]::FromArgb(198, 239, 206)
            $greenText = [System.Drawing.Color]::FromArgb(0, 97, 0)
            $yellowFill = [System.Drawing.Color]::FromArgb(255, 235, 156)
            $yellowText = [System.Drawing.Color]::FromArgb(156, 101, 0)
            $redFill = [System.Drawing.Color]::FromArgb(255, 199, 206)
            $redText = [System.Drawing.Color]::FromArgb(156, 0, 6)
            $headerBlue = [System.Drawing.Color]::FromArgb(0, 120, 212)
            $lightGray = [System.Drawing.Color]::FromArgb(242, 242, 242)
            $naGray = [System.Drawing.Color]::FromArgb(191, 191, 191)

            #region Lifecycle Summary Sheet
            # Tag continuation rows with parent's risk level, SKU, and group sequence for sorting
            $lastParentRisk = 'Low'
            $lastParentSKU = ''
            $groupSeq = 0
            $rowSeq = 0
            foreach ($lr in $lifecycleResults) {
                if ($lr.SKU -and $lr.SKU -ne '') {
                    $lastParentRisk = $lr.RiskLevel
                    $lastParentSKU = $lr.SKU
                    $groupSeq++
                    $rowSeq = 0
                }
                $lr | Add-Member -NotePropertyName '_ParentRisk' -NotePropertyValue $lastParentRisk -Force
                $lr | Add-Member -NotePropertyName '_ParentSKU' -NotePropertyValue $lastParentSKU -Force
                $lr | Add-Member -NotePropertyName '_GroupSeq' -NotePropertyValue $groupSeq -Force
                $lr | Add-Member -NotePropertyName '_RowSeq' -NotePropertyValue $rowSeq -Force
                $rowSeq++
            }

            $lcSortedResults = $lifecycleResults | Sort-Object @{e={switch($_._ParentRisk){'High'{0}'Medium'{1}'Low'{2}default{3}}}}, _ParentSKU, _GroupSeq, _RowSeq

            # SP/RI columns included only with -RateOptimization flag
            $rateOptCols = if ($RateOptimization) {
                @(
                    @{N='SP 1-Year Savings';E={$_.SP1YrSavings}},
                    @{N='SP 3-Year Savings';E={$_.SP3YrSavings}},
                    @{N='RI 1-Year Savings';E={$_.RI1YrSavings}},
                    @{N='RI 3-Year Savings';E={$_.RI3YrSavings}}
                )
            } else { @() }

            # PAYG pricing columns included only with -ShowPricing
            $pricingCols = if ($FetchPricing) {
                @(
                    @{N='Price Diff';E={$_.PriceDiff}}, @{N='Total';E={$_.TotalPriceDiff}},
                    @{N='1-Year Cost';E={$_.PAYG1Yr}}, @{N='3-Year Cost';E={$_.PAYG3Yr}}
                ) + $rateOptCols
            } else { @() }

            if ($NoQuota) {
                $lcProps = @(
                    @{N='SKU';E={$_.SKU}}, @{N='Region';E={$_.DeployedRegion}}, @{N='Qty';E={$_.Qty}},
                    @{N='vCPU';E={$_.vCPU}}, @{N='Memory (GB)';E={$_.MemoryGB}}, @{N='Generation';E={$_.Generation}},
                    @{N='Risk Level';E={$_.RiskLevel}}, @{N='Risk Reasons';E={$_.RiskReasons}},
                    @{N='Match Type';E={$_.MatchType}}, @{N='Alternative';E={$_.TopAlternative}}, @{N='Alt Score';E={$_.AltScore}},
                    @{N='CPU +/-';E={$_.CpuDelta}}, @{N='Mem +/-';E={$_.MemDelta}},
                    @{N='Disk +/-';E={$_.DiskDelta}}, @{N='IOPS +/-';E={$_.IopsDelta}}
                ) + $pricingCols + @(@{N='Details';E={$_.Details}})
                $lcExportRows = $lcSortedResults | Select-Object -Property $lcProps
                $riskColLetter = 'G'
                $altColLetter = 'J'
                $riskReasonsColNum = 8
            }
            else {
                $lcProps = @(
                    @{N='SKU';E={$_.SKU}}, @{N='Region';E={$_.DeployedRegion}}, @{N='Qty';E={$_.Qty}},
                    @{N='vCPU';E={$_.vCPU}}, @{N='Memory (GB)';E={$_.MemoryGB}}, @{N='Generation';E={$_.Generation}},
                    @{N='Risk Level';E={$_.RiskLevel}}, @{N='Risk Reasons';E={$_.RiskReasons}},
                    @{N='Quota (Used/Limit)';E={$_.QuotaStatus}},
                    @{N='Match Type';E={$_.MatchType}}, @{N='Alternative';E={$_.TopAlternative}}, @{N='Alt Score';E={$_.AltScore}},
                    @{N='CPU +/-';E={$_.CpuDelta}}, @{N='Mem +/-';E={$_.MemDelta}},
                    @{N='Disk +/-';E={$_.DiskDelta}}, @{N='IOPS +/-';E={$_.IopsDelta}},
                    @{N='Alt Quota';E={$_.AltQuotaStatus}}
                ) + $pricingCols + @(@{N='Details';E={$_.Details}})
                $lcExportRows = $lcSortedResults | Select-Object -Property $lcProps
                $riskColLetter = 'G'
                $altColLetter = 'K'
                $riskReasonsColNum = 8
            }

            $excel = $lcExportRows | Export-Excel -Path $lcXlsxFile -WorksheetName "Lifecycle Summary" -AutoSize -AutoFilter -FreezeTopRow -PassThru

            $ws = $excel.Workbook.Worksheets["Lifecycle Summary"]
            $lastRow = $ws.Dimension.End.Row
            $lastCol = $ws.Dimension.End.Column

            # Azure-blue header row
            $headerRange = $ws.Cells["A1:$(ConvertTo-ExcelColumnLetter $lastCol)1"]
            $headerRange.Style.Font.Bold = $true
            $headerRange.Style.Font.Color.SetColor([System.Drawing.Color]::White)
            $headerRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
            $headerRange.Style.Fill.BackgroundColor.SetColor($headerBlue)
            $headerRange.Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center

            # Alternating row colors
            for ($row = 2; $row -le $lastRow; $row++) {
                if ($row % 2 -eq 0) {
                    $rowRange = $ws.Cells["A$row`:$(ConvertTo-ExcelColumnLetter $lastCol)$row"]
                    $rowRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                    $rowRange.Style.Fill.BackgroundColor.SetColor($lightGray)
                }
            }

            # Risk Level column — conditional formatting
            $riskRange = "${riskColLetter}2:${riskColLetter}$lastRow"
            Add-ConditionalFormatting -Worksheet $ws -Range $riskRange -RuleType ContainsText -ConditionValue "High" -BackgroundColor $redFill -ForegroundColor $redText
            Add-ConditionalFormatting -Worksheet $ws -Range $riskRange -RuleType ContainsText -ConditionValue "Medium" -BackgroundColor $yellowFill -ForegroundColor $yellowText
            Add-ConditionalFormatting -Worksheet $ws -Range $riskRange -RuleType ContainsText -ConditionValue "Low" -BackgroundColor $greenFill -ForegroundColor $greenText

            # Alternative column — highlight N/A
            $altRange = "${altColLetter}2:${altColLetter}$lastRow"
            Add-ConditionalFormatting -Worksheet $ws -Range $altRange -RuleType Equal -ConditionValue "N/A" -BackgroundColor $lightGray -ForegroundColor $naGray
            Add-ConditionalFormatting -Worksheet $ws -Range $altRange -RuleType Equal -ConditionValue "-" -BackgroundColor $redFill -ForegroundColor $redText

            # Thin borders on all data cells
            $dataRange = $ws.Cells["A1:$(ConvertTo-ExcelColumnLetter $lastCol)$lastRow"]
            $dataRange.Style.Border.Top.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Bottom.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Left.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Right.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin

            # Center-align numeric and short columns
            $ws.Cells["C2:F$lastRow"].Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center
            $ws.Cells["${riskColLetter}2:${riskColLetter}$lastRow"].Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center

            # Widen Risk Reasons column
            $ws.Column($riskReasonsColNum).Width = 50

            # Summary footer rows
            $footerStart = $lastRow + 2
            $highRisk = @($lifecycleResults | Where-Object { $_.RiskLevel -eq 'High' })
            $medRisk = @($lifecycleResults | Where-Object { $_.RiskLevel -eq 'Medium' })
            $lowRisk = @($lifecycleResults | Where-Object { $_.RiskLevel -eq 'Low' })
            $highVMs = ($highRisk | Measure-Object -Property Qty -Sum).Sum
            $medVMs = ($medRisk | Measure-Object -Property Qty -Sum).Sum
            $lowVMs = ($lowRisk | Measure-Object -Property Qty -Sum).Sum

            $ws.Cells["A$footerStart"].Value = "SUMMARY"
            $ws.Cells["A$footerStart`:F$footerStart"].Merge = $true
            $ws.Cells["A$footerStart"].Style.Font.Bold = $true
            $ws.Cells["A$footerStart"].Style.Font.Size = 11
            $ws.Cells["A$footerStart`:F$footerStart"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
            $ws.Cells["A$footerStart`:F$footerStart"].Style.Fill.BackgroundColor.SetColor($headerBlue)
            $ws.Cells["A$footerStart`:F$footerStart"].Style.Font.Color.SetColor([System.Drawing.Color]::White)

            $summaryItems = @(
                @{ Label = "Total SKUs"; Value = "$uniqueSkuCount"; VMs = "$totalVMCount VMs" }
                @{ Label = "HIGH Risk"; Value = "$($highRisk.Count) SKUs"; VMs = "$highVMs VMs — immediate action" }
                @{ Label = "MEDIUM Risk"; Value = "$($medRisk.Count) SKUs"; VMs = "$medVMs VMs — plan migration" }
                @{ Label = "LOW Risk"; Value = "$($lowRisk.Count) SKUs"; VMs = "$lowVMs VMs — no action needed" }
            )

            $sRow = $footerStart + 1
            foreach ($si in $summaryItems) {
                $ws.Cells["A$sRow"].Value = $si.Label
                $ws.Cells["A$sRow"].Style.Font.Bold = $true
                $ws.Cells["B$sRow"].Value = $si.Value
                $ws.Cells["C$sRow`:F$sRow"].Merge = $true
                $ws.Cells["C$sRow"].Value = $si.VMs

                $ws.Cells["A$sRow`:F$sRow"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                switch ($si.Label) {
                    "HIGH Risk" { $ws.Cells["A$sRow`:F$sRow"].Style.Fill.BackgroundColor.SetColor($redFill); $ws.Cells["A$sRow`:F$sRow"].Style.Font.Color.SetColor($redText) }
                    "MEDIUM Risk" { $ws.Cells["A$sRow`:F$sRow"].Style.Fill.BackgroundColor.SetColor($yellowFill); $ws.Cells["A$sRow`:F$sRow"].Style.Font.Color.SetColor($yellowText) }
                    "LOW Risk" { $ws.Cells["A$sRow`:F$sRow"].Style.Fill.BackgroundColor.SetColor($greenFill); $ws.Cells["A$sRow`:F$sRow"].Style.Font.Color.SetColor($greenText) }
                    default { $ws.Cells["A$sRow`:F$sRow"].Style.Fill.BackgroundColor.SetColor($lightGray) }
                }
                $sRow++
            }
            #endregion Lifecycle Summary Sheet

            #region Risk Breakdown Sheet
            $highBase = @($lifecycleResults | Where-Object { $_._ParentRisk -eq 'High' })
            if ($NoQuota) {
                $hrProps = @(
                    @{N='SKU';E={$_.SKU}}, @{N='Region';E={$_.DeployedRegion}}, @{N='Qty';E={$_.Qty}},
                    @{N='vCPU';E={$_.vCPU}}, @{N='Memory (GB)';E={$_.MemoryGB}}, @{N='Generation';E={$_.Generation}},
                    @{N='Risk Reasons';E={$_.RiskReasons}},
                    @{N='Match Type';E={$_.MatchType}}, @{N='Alternative';E={$_.TopAlternative}}, @{N='Alt Score';E={$_.AltScore}},
                    @{N='CPU +/-';E={$_.CpuDelta}}, @{N='Mem +/-';E={$_.MemDelta}},
                    @{N='Disk +/-';E={$_.DiskDelta}}, @{N='IOPS +/-';E={$_.IopsDelta}}
                ) + $pricingCols + @(@{N='Details';E={$_.Details}})
                $highRows = @($highBase | Select-Object -Property $hrProps)
            }
            else {
                $hrProps = @(
                    @{N='SKU';E={$_.SKU}}, @{N='Region';E={$_.DeployedRegion}}, @{N='Qty';E={$_.Qty}},
                    @{N='vCPU';E={$_.vCPU}}, @{N='Memory (GB)';E={$_.MemoryGB}}, @{N='Generation';E={$_.Generation}},
                    @{N='Risk Reasons';E={$_.RiskReasons}},
                    @{N='Quota (Used/Limit)';E={$_.QuotaStatus}},
                    @{N='Match Type';E={$_.MatchType}}, @{N='Alternative';E={$_.TopAlternative}}, @{N='Alt Score';E={$_.AltScore}},
                    @{N='CPU +/-';E={$_.CpuDelta}}, @{N='Mem +/-';E={$_.MemDelta}},
                    @{N='Disk +/-';E={$_.DiskDelta}}, @{N='IOPS +/-';E={$_.IopsDelta}},
                    @{N='Alt Quota';E={$_.AltQuotaStatus}}
                ) + $pricingCols + @(@{N='Details';E={$_.Details}})
                $highRows = @($highBase | Select-Object -Property $hrProps)
            }

            if ($highRows.Count -gt 0) {
                $excel = $highRows | Export-Excel -ExcelPackage $excel -WorksheetName "High Risk" -AutoSize -AutoFilter -FreezeTopRow -PassThru
                $wsH = $excel.Workbook.Worksheets["High Risk"]
                $hLastRow = $wsH.Dimension.End.Row
                $hLastCol = $wsH.Dimension.End.Column

                $hHeader = $wsH.Cells["A1:$(ConvertTo-ExcelColumnLetter $hLastCol)1"]
                $hHeader.Style.Font.Bold = $true
                $hHeader.Style.Font.Color.SetColor([System.Drawing.Color]::White)
                $hHeader.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                $hHeader.Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::FromArgb(156, 0, 6))

                for ($row = 2; $row -le $hLastRow; $row++) {
                    $rowRange = $wsH.Cells["A$row`:$(ConvertTo-ExcelColumnLetter $hLastCol)$row"]
                    $rowRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                    $rowRange.Style.Fill.BackgroundColor.SetColor($(if ($row % 2 -eq 0) { $redFill } else { [System.Drawing.Color]::White }))
                }
            }

            $medBase = @($lifecycleResults | Where-Object { $_._ParentRisk -eq 'Medium' })
            if ($NoQuota) {
                $mrProps = @(
                    @{N='SKU';E={$_.SKU}}, @{N='Region';E={$_.DeployedRegion}}, @{N='Qty';E={$_.Qty}},
                    @{N='vCPU';E={$_.vCPU}}, @{N='Memory (GB)';E={$_.MemoryGB}}, @{N='Generation';E={$_.Generation}},
                    @{N='Risk Reasons';E={$_.RiskReasons}},
                    @{N='Match Type';E={$_.MatchType}}, @{N='Alternative';E={$_.TopAlternative}}, @{N='Alt Score';E={$_.AltScore}},
                    @{N='CPU +/-';E={$_.CpuDelta}}, @{N='Mem +/-';E={$_.MemDelta}},
                    @{N='Disk +/-';E={$_.DiskDelta}}, @{N='IOPS +/-';E={$_.IopsDelta}}
                ) + $pricingCols + @(@{N='Details';E={$_.Details}})
                $medRows = @($medBase | Select-Object -Property $mrProps)
            }
            else {
                $mrProps = @(
                    @{N='SKU';E={$_.SKU}}, @{N='Region';E={$_.DeployedRegion}}, @{N='Qty';E={$_.Qty}},
                    @{N='vCPU';E={$_.vCPU}}, @{N='Memory (GB)';E={$_.MemoryGB}}, @{N='Generation';E={$_.Generation}},
                    @{N='Risk Reasons';E={$_.RiskReasons}},
                    @{N='Quota (Used/Limit)';E={$_.QuotaStatus}},
                    @{N='Match Type';E={$_.MatchType}}, @{N='Alternative';E={$_.TopAlternative}}, @{N='Alt Score';E={$_.AltScore}},
                    @{N='CPU +/-';E={$_.CpuDelta}}, @{N='Mem +/-';E={$_.MemDelta}},
                    @{N='Disk +/-';E={$_.DiskDelta}}, @{N='IOPS +/-';E={$_.IopsDelta}},
                    @{N='Alt Quota';E={$_.AltQuotaStatus}}
                ) + $pricingCols + @(@{N='Details';E={$_.Details}})
                $medRows = @($medBase | Select-Object -Property $mrProps)
            }

            if ($medRows.Count -gt 0) {
                $excel = $medRows | Export-Excel -ExcelPackage $excel -WorksheetName "Medium Risk" -AutoSize -AutoFilter -FreezeTopRow -PassThru
                $wsM = $excel.Workbook.Worksheets["Medium Risk"]
                $mLastRow = $wsM.Dimension.End.Row
                $mLastCol = $wsM.Dimension.End.Column

                $mHeader = $wsM.Cells["A1:$(ConvertTo-ExcelColumnLetter $mLastCol)1"]
                $mHeader.Style.Font.Bold = $true
                $mHeader.Style.Font.Color.SetColor([System.Drawing.Color]::White)
                $mHeader.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                $mHeader.Style.Fill.BackgroundColor.SetColor([System.Drawing.Color]::FromArgb(156, 101, 0))

                for ($row = 2; $row -le $mLastRow; $row++) {
                    $rowRange = $wsM.Cells["A$row`:$(ConvertTo-ExcelColumnLetter $mLastCol)$row"]
                    $rowRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                    $rowRange.Style.Fill.BackgroundColor.SetColor($(if ($row % 2 -eq 0) { $yellowFill } else { [System.Drawing.Color]::White }))
                }
            }
            #endregion Risk Breakdown Sheet

            #region Deployment Map Sheets (-SubMap / -RGMap)
            # Build risk lookup once for all map sheets
            $riskLookup = @{}
            if ($SubMap -or $RGMap) {
                foreach ($lr in $lifecycleResults) {
                    $riskKey = "$($lr.SKU)|$($lr.DeployedRegion)"
                    if (-not $riskLookup.ContainsKey($riskKey)) {
                        $riskLookup[$riskKey] = @{ RiskLevel = $lr.RiskLevel; RiskReasons = $lr.RiskReasons }
                    }
                }
            }

            # Helper scriptblock to enrich, export, and style a deployment map sheet
            $exportMapSheet = {
                param($mapRows, $sheetName, $hasRG)
                $enriched = [System.Collections.Generic.List[PSCustomObject]]::new()
                foreach ($mapRow in $mapRows) {
                    $rKey = "$($mapRow.SKU)|$($mapRow.Region)"
                    $risk = $riskLookup[$rKey]
                    $props = [ordered]@{
                        SubscriptionId   = $mapRow.SubscriptionId
                        SubscriptionName = $mapRow.SubscriptionName
                    }
                    if ($hasRG) { $props['ResourceGroup'] = $mapRow.ResourceGroup }
                    $props['Region']      = $mapRow.Region
                    $props['SKU']         = $mapRow.SKU
                    $props['Qty']         = $mapRow.Qty
                    $props['RiskLevel']   = if ($risk) { $risk.RiskLevel } else { 'Low' }
                    $props['RiskReasons'] = if ($risk) { $risk.RiskReasons } else { '' }
                    $enriched.Add([pscustomobject]$props)
                }
                $excel = $enriched | Export-Excel -ExcelPackage $excel -WorksheetName $sheetName -AutoSize -AutoFilter -FreezeTopRow -PassThru
                $wsMap = $excel.Workbook.Worksheets[$sheetName]
                $mapLastRow = $wsMap.Dimension.End.Row
                $mapLastCol = $wsMap.Dimension.End.Column
                $mapHeader = $wsMap.Cells["A1:$(ConvertTo-ExcelColumnLetter $mapLastCol)1"]
                $mapHeader.Style.Font.Bold = $true
                $mapHeader.Style.Font.Color.SetColor([System.Drawing.Color]::White)
                $mapHeader.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                $mapHeader.Style.Fill.BackgroundColor.SetColor($headerBlue)
                $riskColNum = if ($hasRG) { 7 } else { 6 }
                $riskColLtr = ConvertTo-ExcelColumnLetter $riskColNum
                for ($row = 2; $row -le $mapLastRow; $row++) {
                    $rowRange = $wsMap.Cells["A$row`:$(ConvertTo-ExcelColumnLetter $mapLastCol)$row"]
                    $rowRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                    $rowRange.Style.Fill.BackgroundColor.SetColor($(if ($row % 2 -eq 0) { $lightGray } else { [System.Drawing.Color]::White }))
                    $riskCell = $wsMap.Cells["$riskColLtr$row"]
                    $riskVal = $riskCell.Value
                    if ($riskVal -eq 'High') {
                        $riskCell.Style.Font.Color.SetColor($redText)
                        $riskCell.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                        $riskCell.Style.Fill.BackgroundColor.SetColor($redFill)
                    }
                    elseif ($riskVal -eq 'Medium') {
                        $riskCell.Style.Font.Color.SetColor($yellowText)
                        $riskCell.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                        $riskCell.Style.Fill.BackgroundColor.SetColor($yellowFill)
                    }
                    elseif ($riskVal -eq 'Low') {
                        $riskCell.Style.Font.Color.SetColor($greenText)
                        $riskCell.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                        $riskCell.Style.Fill.BackgroundColor.SetColor($greenFill)
                    }
                }
                return $excel
            }

            if ($SubMap -and $subMapRows -and $subMapRows.Count -gt 0) {
                $excel = & $exportMapSheet $subMapRows "Subscription Map" $false
            }
            if ($RGMap -and $rgMapRows -and $rgMapRows.Count -gt 0) {
                $excel = & $exportMapSheet $rgMapRows "Resource Group Map" $true
            }
            #endregion Deployment Map Sheets

            Close-ExcelPackage $excel

            Write-Host ""
            Write-Host "Lifecycle report exported: $lcXlsxFile" -ForegroundColor Green
            $sheetList = "Lifecycle Summary"
            if ($highRows.Count -gt 0) { $sheetList += ", High Risk" }
            if ($medRows.Count -gt 0) { $sheetList += ", Medium Risk" }
            if ($SubMap -and $subMapRows -and $subMapRows.Count -gt 0) {
                $sheetList += ", Subscription Map"
            }
            if ($RGMap -and $rgMapRows -and $rgMapRows.Count -gt 0) {
                $sheetList += ", Resource Group Map"
            }
            Write-Host "  Sheets: $sheetList" -ForegroundColor Cyan
        }
        catch {
            Write-Warning "Failed to export lifecycle XLSX: $_"
        }
    }
    elseif (-not $JsonOutput -and -not (Test-ImportExcelModule)) {
        Write-Host ""
        Write-Host "Tip: Install ImportExcel for styled XLSX export: Install-Module ImportExcel -Scope CurrentUser" -ForegroundColor DarkGray
    }

    if ($JsonOutput) {
        $jsonResult = @{
            schemaVersion = '1.0'
            mode          = 'lifecycle'
            skuCount      = $lifecycleEntries.Count
            totalVMs      = $totalVMCount
            results       = @($lifecycleResults)
        }
        if ($SubMap -and $subMapRows -and $subMapRows.Count -gt 0) {
            $jsonResult['subscriptionMap'] = @{
                groupBy = 'Subscription'
                rows    = @($subMapRows)
            }
        }
        if ($RGMap -and $rgMapRows -and $rgMapRows.Count -gt 0) {
            $jsonResult['resourceGroupMap'] = @{
                groupBy = 'ResourceGroup'
                rows    = @($rgMapRows)
            }
        }
        $jsonResult | ConvertTo-Json -Depth 5
    }

    return
}

#endregion Lifecycle Recommendations
#region Recommend Mode

if ($Recommend) {
    Invoke-RecommendMode -TargetSkuName $Recommend -SubscriptionData $allSubscriptionData `
        -FamilyInfo $FamilyInfo -Icons $Icons -FetchPricing ([bool]$FetchPricing) `
        -ShowSpot $ShowSpot.IsPresent -ShowPlacement $ShowPlacement.IsPresent `
        -AllowMixedArch $AllowMixedArch.IsPresent -MinvCPU $MinvCPU -MinMemoryGB $MinMemoryGB `
        -MinScore $MinScore -TopN $TopN -DesiredCount $DesiredCount `
        -JsonOutput $JsonOutput.IsPresent -MaxRetries $MaxRetries `
        -RunContext $script:RunContext -OutputWidth $script:OutputWidth
    return
}

#endregion Recommend Mode
#region Process Results

$allFamilyStats = @{}
$familyDetails = [System.Collections.Generic.List[PSCustomObject]]::new()
$familySkuIndex = @{}
$processStartTime = Get-Date

foreach ($subscriptionData in $allSubscriptionData) {
    $subName = $subscriptionData.SubscriptionName
    $totalRegions = $subscriptionData.RegionData.Count
    $currentRegion = 0

    foreach ($data in $subscriptionData.RegionData) {
        $currentRegion++
        $region = Get-SafeString $data.Region

        # Progress bar for processing
        $percentComplete = [math]::Round(($currentRegion / $totalRegions) * 100)
        $elapsed = (Get-Date) - $processStartTime
        Write-Progress -Activity "Processing Region Data" -Status "$region ($currentRegion of $totalRegions)" -PercentComplete $percentComplete -CurrentOperation "Elapsed: $([math]::Round($elapsed.TotalSeconds, 1))s"

        Write-Host "`n" -NoNewline
        Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
        Write-Host "REGION: $region" -ForegroundColor Yellow
        Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray

        if ($data.Error) {
            Write-Host "ERROR: $($data.Error)" -ForegroundColor Red
            continue
        }

        $familyGroups = @{}
        $quotaLookup = @{}
        foreach ($q in $data.Quotas) { $quotaLookup[$q.Name.Value] = $q }
        foreach ($sku in $data.Skus) {
            $family = Get-SkuFamily $sku.Name
            if (-not $familyGroups[$family]) { $familyGroups[$family] = @() }
            $familyGroups[$family] += $sku
        }

        Write-Host "`nQUOTA SUMMARY:" -ForegroundColor Cyan
        $quotaLines = $data.Quotas | Where-Object {
            $_.Name.Value -match 'Total Regional vCPUs|Family vCPUs'
        } | Select-Object @{n = 'Family'; e = { $_.Name.LocalizedValue } },
        @{n = 'Used'; e = { $_.CurrentValue } },
        @{n = 'Limit'; e = { $_.Limit } },
        @{n = 'Available'; e = { $_.Limit - $_.CurrentValue } }

        if ($quotaLines) {
            # Fixed-width quota table (175 chars total)
            $qColWidths = [ordered]@{ Family = 50; Used = 15; Limit = 15; Available = 15 }
            $qHeader = foreach ($c in $qColWidths.Keys) { $c.PadRight($qColWidths[$c]) }
            Write-Host ($qHeader -join '  ') -ForegroundColor Cyan
            Write-Host ('-' * $script:OutputWidth) -ForegroundColor Gray
            foreach ($q in $quotaLines) {
                $qRow = foreach ($c in $qColWidths.Keys) {
                    $v = "$($q.$c)"
                    if ($v.Length -gt $qColWidths[$c]) { $v = $v.Substring(0, $qColWidths[$c] - 1) + '…' }
                    $v.PadRight($qColWidths[$c])
                }
                Write-Host ($qRow -join '  ') -ForegroundColor White
            }
            Write-Host ""
        }
        else {
            Write-Host "No quota data available" -ForegroundColor DarkYellow
        }

        Write-Host "SKU FAMILIES:" -ForegroundColor Cyan

        $rows = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($family in ($familyGroups.Keys | Sort-Object)) {
            $skus = $familyGroups[$family]

            $largestSku = $skus | ForEach-Object {
                @{
                    Sku    = $_
                    vCPU   = [int](Get-CapValue $_ 'vCPUs')
                    Memory = [int](Get-CapValue $_ 'MemoryGB')
                }
            } | Sort-Object vCPU -Descending | Select-Object -First 1

            $availableCount = ($skus | Where-Object { -not (Get-RestrictionReason $_) }).Count
            $restrictions = Get-RestrictionDetails $largestSku.Sku
            $capacity = $restrictions.Status
            $zoneStatus = Format-ZoneStatus $restrictions.ZonesOK $restrictions.ZonesLimited $restrictions.ZonesRestricted
            $quotaInfo = Get-QuotaAvailable -QuotaLookup $quotaLookup -SkuFamily $largestSku.Sku.Family

            # Get pricing - find smallest SKU with pricing available
            $priceHrStr = '-'
            $priceMoStr = '-'
            # Get pricing data - handle potential array wrapping
            $regionPricingData = $script:RunContext.RegionPricing[$region]
            $regularPriceMap = Get-RegularPricingMap -PricingContainer $regionPricingData
            if ($FetchPricing -and $regularPriceMap -and $regularPriceMap.Count -gt 0) {
                $sortedSkus = $skus | ForEach-Object {
                    @{ Sku = $_; vCPU = [int](Get-CapValue $_ 'vCPUs') }
                } | Sort-Object vCPU

                foreach ($skuInfo in $sortedSkus) {
                    $skuName = $skuInfo.Sku.Name
                    $pricing = $regularPriceMap[$skuName]
                    if ($pricing) {
                        $priceHrStr = '$' + $pricing.Hourly.ToString('0.00')
                        $priceMoStr = '$' + $pricing.Monthly.ToString('0')
                        break
                    }
                }
            }

            $row = [pscustomobject]@{
                Family  = $family
                SKUs    = $skus.Count
                OK      = $availableCount
                Largest = "{0}vCPU/{1}GB" -f $largestSku.vCPU, $largestSku.Memory
                Zones   = $zoneStatus
                Status  = $capacity
                Quota   = if ($null -ne $quotaInfo.Available) { $quotaInfo.Available } else { '?' }
            }

            if ($FetchPricing) {
                $row | Add-Member -NotePropertyName '$/Hr' -NotePropertyValue $priceHrStr
                $row | Add-Member -NotePropertyName '$/Mo' -NotePropertyValue $priceMoStr
            }

            $rows.Add($row)

            # Track for drill-down
            if (-not $familySkuIndex.ContainsKey($family)) { $familySkuIndex[$family] = @{} }

            foreach ($sku in $skus) {
                $familySkuIndex[$family][$sku.Name] = $true
                $skuRestrictions = Get-RestrictionDetails $sku

                # Per-SKU quota: use SKU's exact .Family property for specific quota bucket
                $quotaInfo = Get-QuotaAvailable -QuotaLookup $quotaLookup -SkuFamily $sku.Family

                # Get individual SKU pricing
                $skuPriceHr = '-'
                $skuPriceMo = '-'
                if ($FetchPricing -and $regularPriceMap) {
                    $skuPricing = $regularPriceMap[$sku.Name]
                    if ($skuPricing) {
                        $skuPriceHr = '$' + $skuPricing.Hourly.ToString('0.00')
                        $skuPriceMo = '$' + $skuPricing.Monthly.ToString('0')
                    }
                }

                # Get SKU capabilities for Gen/Arch
                $skuCaps = Get-SkuCapabilities -Sku $sku
                $genDisplay = $skuCaps.HyperVGenerations -replace 'V', '' -replace ',', ','
                $archDisplay = $skuCaps.CpuArchitecture

                # Check image compatibility if image was specified
                $imgCompat = '–'
                $imgReason = ''
                if ($script:RunContext.ImageReqs) {
                    $compatResult = Test-ImageSkuCompatibility -ImageReqs $script:RunContext.ImageReqs -SkuCapabilities $skuCaps
                    if ($compatResult.Compatible) {
                        $imgCompat = if ($supportsUnicode) { '✓' } else { '[+]' }
                    }
                    else {
                        $imgCompat = if ($supportsUnicode) { '✗' } else { '[-]' }
                        $imgReason = $compatResult.Reason
                    }
                }

                $detailObj = [pscustomobject]@{
                    Subscription = [string]$subName
                    Region       = Get-SafeString $region
                    Family       = [string]$family
                    SKU          = [string]$sku.Name
                    vCPU         = Get-CapValue $sku 'vCPUs'
                    MemGiB       = Get-CapValue $sku 'MemoryGB'
                    Gen          = $genDisplay
                    Arch         = $archDisplay
                    ZoneStatus   = Format-ZoneStatus $skuRestrictions.ZonesOK $skuRestrictions.ZonesLimited $skuRestrictions.ZonesRestricted
                    Capacity     = [string]$skuRestrictions.Status
                    Reason       = ($skuRestrictions.RestrictionReasons -join ', ')
                    QuotaAvail   = if ($null -ne $quotaInfo.Available) { $quotaInfo.Available } else { '?' }
                    QuotaLimit   = if ($null -ne $quotaInfo.Limit) { $quotaInfo.Limit } else { $null }
                    QuotaCurrent = if ($null -ne $quotaInfo.Current) { $quotaInfo.Current } else { $null }
                    ImgCompat    = $imgCompat
                    ImgReason    = $imgReason
                    Alloc        = '-'
                }

                if ($FetchPricing) {
                    $detailObj | Add-Member -NotePropertyName '$/Hr' -NotePropertyValue $skuPriceHr
                    $detailObj | Add-Member -NotePropertyName '$/Mo' -NotePropertyValue $skuPriceMo
                }

                $familyDetails.Add($detailObj)
            }

            # Track for summary
            if (-not $allFamilyStats[$family]) {
                $allFamilyStats[$family] = @{ Regions = @{}; TotalAvailable = 0 }
            }
            $regionKey = Get-SafeString $region
            $allFamilyStats[$family].Regions[$regionKey] = @{
                Count     = $skus.Count
                Available = $availableCount
                Capacity  = $capacity
            }
        }

        if ($rows.Count -gt 0) {
            # Fixed-width table formatting (total width = 175 chars with pricing)
            $colWidths = [ordered]@{
                Family  = 12
                SKUs    = 6
                OK      = 5
                Largest = 18
                Zones   = 28
                Status  = 22
                Quota   = 10
            }
            if ($FetchPricing) {
                $colWidths['$/Hr'] = 10
                $colWidths['$/Mo'] = 10
            }

            $headerParts = foreach ($col in $colWidths.Keys) {
                $col.PadRight($colWidths[$col])
            }
            Write-Host ($headerParts -join '  ') -ForegroundColor Cyan
            Write-Host ('-' * $script:OutputWidth) -ForegroundColor Gray

            foreach ($row in $rows) {
                $rowParts = foreach ($col in $colWidths.Keys) {
                    $val = if ($null -ne $row.$col) { "$($row.$col)" } else { '' }
                    $width = $colWidths[$col]
                    if ($val.Length -gt $width) { $val = $val.Substring(0, $width - 1) + '…' }
                    $val.PadRight($width)
                }

                $color = switch ($row.Status) {
                    'OK' { 'Green' }
                    { $_ -match 'LIMITED|CAPACITY' } { 'Yellow' }
                    { $_ -match 'RESTRICTED|BLOCKED' } { 'Red' }
                    default { 'White' }
                }
                Write-Host ($rowParts -join '  ') -ForegroundColor $color
            }
        }
    }
}

# Optional placement enrichment for filtered scan mode (SKU-level tables only)
if ($ShowPlacement -and $SkuFilter -and $SkuFilter.Count -gt 0) {
    $filteredSkuNames = @($familyDetails | Select-Object -ExpandProperty SKU -Unique)
    if ($filteredSkuNames.Count -gt 5) {
        Write-Warning "Placement score lookup skipped in scan mode: filtered set contains $($filteredSkuNames.Count) SKUs (limit is 5). Refine -SkuFilter to 5 or fewer SKUs."
    }
    elseif ($filteredSkuNames.Count -gt 0) {
        $scanPlacementScores = Get-PlacementScores -SkuNames $filteredSkuNames -Regions $Regions -DesiredCount $DesiredCount -MaxRetries $MaxRetries -Caches $script:RunContext.Caches
        foreach ($detail in $familyDetails) {
            $allocKey = "{0}|{1}" -f $detail.SKU, $detail.Region.ToLower()
            $allocValue = if ($scanPlacementScores.ContainsKey($allocKey)) { [string]$scanPlacementScores[$allocKey].Score } else { 'N/A' }
            $detail.Alloc = $allocValue
        }
    }
}

#endregion Process Results

$script:RunContext.ScanOutput = New-ScanOutputContract -SubscriptionData $allSubscriptionData -FamilyStats $allFamilyStats -FamilyDetails $familyDetails -Regions $Regions -SubscriptionIds $TargetSubIds

if ($JsonOutput) {
    $script:RunContext.ScanOutput | ConvertTo-Json -Depth 8
    return
}

# Emit structured objects to pipeline only when console stdout is redirected (e.g., > file.txt or Start-Transcript).
# [Console]::IsOutputRedirected detects console-level redirection only — it does NOT detect PS pipeline usage.
# For interactive pipeline scenarios, use -JsonOutput. A dedicated -PassThru switch is planned for a future version.
if (-not $JsonOutput -and $familyDetails.Count -gt 0 -and [Console]::IsOutputRedirected) {
    Write-Verbose "Pipeline emit: outputting $($familyDetails.Count) detail objects (stdout is redirected)"
    Write-Verbose "  If this output is unexpected, use -JsonOutput for structured data or run without redirection for console-only display."
    $familyDetails
}
elseif (-not $JsonOutput -and $familyDetails.Count -gt 0 -and -not [Console]::IsOutputRedirected) {
    # Detect common capture patterns that WON'T trigger IsOutputRedirected but users expect to capture data.
    # Only inspect call stack when this command is actually in a pipeline (PipelineLength > 1).
    # Show tip once per session to avoid noise on repeated runs.
    if ($MyInvocation.PipelineLength -gt 1 -and -not $script:PipelineTipShown) {
        $callStack = Get-PSCallStack
        $pipelineCmdlets = @('Tee-Object', 'ForEach-Object', 'Select-Object', 'Where-Object', 'Out-File', 'Export-Csv', 'ConvertTo-Json', 'ConvertTo-Csv', 'Sort-Object', 'Group-Object', 'Measure-Object')
        $capturePatterns = $callStack | Where-Object { $_.Command -in $pipelineCmdlets }
        if ($capturePatterns) {
            $script:PipelineTipShown = $true
            Write-Host ''
            Write-Host '  TIP: Pipeline capture detected but no objects were emitted.' -ForegroundColor Yellow
            Write-Host '  Get-AzVMAvailability outputs colored tables to the console by default.' -ForegroundColor Yellow
            Write-Host '  To get structured data for pipeline processing, use one of:' -ForegroundColor DarkGray
            Write-Host '    -JsonOutput              → JSON string (recommended for automation)' -ForegroundColor DarkGray
            Write-Host '    > output.txt             → stdout redirection; triggers automatic object emit' -ForegroundColor DarkGray
            Write-Host '    -AutoExport -ExportPath . → CSV/XLSX file export' -ForegroundColor DarkGray
            Write-Host ''
        }
    }
}

#region Drill-Down (if enabled)

if ($EnableDrill -and $familySkuIndex.Keys.Count -gt 0) {
    $familyList = @($familySkuIndex.Keys | Sort-Object)

    if ($NoPrompt) {
        # Auto-select all families and all SKUs when -NoPrompt is used
        $SelectedFamilyFilter = if ($FamilyFilter -and $FamilyFilter.Count -gt 0) {
            # Use provided family filter
            $FamilyFilter | Where-Object { $familyList -contains $_ }
        }
        else {
            # Select all families
            $familyList
        }
    }
    else {
        # Interactive mode
        $drillWidth = if ($script:OutputWidth) { $script:OutputWidth } else { 100 }
        Write-Host "`n" -NoNewline
        Write-Host ("=" * $drillWidth) -ForegroundColor Gray
        Write-Host "DRILL-DOWN: SELECT FAMILIES" -ForegroundColor Green
        Write-Host ("=" * $drillWidth) -ForegroundColor Gray

        for ($i = 0; $i -lt $familyList.Count; $i++) {
            $fam = $familyList[$i]
            $skuCount = $familySkuIndex[$fam].Keys.Count
            Write-Host "$($i + 1). $fam (SKUs: $skuCount)" -ForegroundColor Cyan
        }

        Write-Host ""
        Write-Host "INSTRUCTIONS:" -ForegroundColor Yellow
        Write-Host "  - Enter numbers to pick one or more families (e.g., '1', '1,3,5', '1 3 5')" -ForegroundColor White
        Write-Host "  - Press Enter to include ALL families" -ForegroundColor White
        $famSel = Read-Host "Select families"

        if ([string]::IsNullOrWhiteSpace($famSel)) {
            $SelectedFamilyFilter = $familyList
        }
        else {
            $nums = $famSel -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
            $nums = @($nums | Sort-Object -Unique)
            $invalidNums = $nums | Where-Object { $_ -lt 1 -or $_ -gt $familyList.Count }
            if ($invalidNums.Count -gt 0) {
                Write-Host "ERROR: Invalid family selection(s): $($invalidNums -join ', ')" -ForegroundColor Red
                throw "Invalid family selection(s): $($invalidNums -join ', ')."
            }
            $SelectedFamilyFilter = @($nums | ForEach-Object { $familyList[$_ - 1] })
        }

        # SKU selection mode
        Write-Host ""
        Write-Host "SKU SELECTION MODE" -ForegroundColor Green
        Write-Host "  - Press Enter: pick SKUs per family (prompts for each)" -ForegroundColor White
        Write-Host "  - Type 'all' : include ALL SKUs for every selected family (skip prompts)" -ForegroundColor White
        Write-Host "  - Type 'none': cancel SKU drill-down and return to reports" -ForegroundColor White
        $skuMode = Read-Host "Choose SKU selection mode"

        if ($skuMode -match '^(none|cancel|skip)$') {
            Write-Host "Skipping SKU drill-down as requested." -ForegroundColor Yellow
            $SelectedFamilyFilter = @()
        }
        elseif ($skuMode -match '^(all)$') {
            foreach ($fam in $SelectedFamilyFilter) {
                $SelectedSkuFilter[$fam] = $null  # null means all SKUs
            }
        }
        else {
            foreach ($fam in $SelectedFamilyFilter) {
                $skus = @($familySkuIndex[$fam].Keys | Sort-Object)
                Write-Host ""
                Write-Host "Family: $fam" -ForegroundColor Green
                for ($j = 0; $j -lt $skus.Count; $j++) {
                    Write-Host "   $($j + 1). $($skus[$j])" -ForegroundColor Cyan
                }
                Write-Host ""
                Write-Host "INSTRUCTIONS:" -ForegroundColor Yellow
                Write-Host "  - Enter numbers to focus on specific SKUs (e.g., '1', '1,2', '1 2')" -ForegroundColor White
                Write-Host "  - Press Enter to include ALL SKUs in this family" -ForegroundColor White
                $skuSel = Read-Host "Select SKUs for family $fam"

                if ([string]::IsNullOrWhiteSpace($skuSel)) {
                    $SelectedSkuFilter[$fam] = $null  # null means all
                }
                else {
                    $skuNums = $skuSel -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { [int]$_ }
                    $skuNums = @($skuNums | Sort-Object -Unique)
                    $invalidSku = $skuNums | Where-Object { $_ -lt 1 -or $_ -gt $skus.Count }
                    if ($invalidSku.Count -gt 0) {
                        Write-Host "ERROR: Invalid SKU selection(s): $($invalidSku -join ', ')" -ForegroundColor Red
                        throw "Invalid SKU selection(s): $($invalidSku -join ', ')."
                    }
                    $SelectedSkuFilter[$fam] = @($skuNums | ForEach-Object { $skus[$_ - 1] })
                }
            }
        }
    }  # End of else (interactive mode)

    # Display drill-down results
    if ($SelectedFamilyFilter.Count -gt 0) {
        $drillWidth = if ($script:OutputWidth) { $script:OutputWidth } else { 100 }
        Write-Host ""
        Write-Host ("=" * $drillWidth) -ForegroundColor Gray
        Write-Host "FAMILY / SKU DRILL-DOWN RESULTS" -ForegroundColor Green
        Write-Host ("=" * $drillWidth) -ForegroundColor Gray
        Write-Host "Note: Avail shows the family's shared vCPU pool per region (not per SKU)." -ForegroundColor DarkGray

        foreach ($fam in $SelectedFamilyFilter) {
            Write-Host "`nFamily: $fam (shared quota per region)" -ForegroundColor Cyan

            # Show image requirements if checking compatibility
            if ($script:RunContext.ImageReqs) {
                Write-Host "Image: $ImageURN (Requires: $($script:RunContext.ImageReqs.Gen) | $($script:RunContext.ImageReqs.Arch))" -ForegroundColor DarkCyan
            }

            $skuFilter = $null
            if ($SelectedSkuFilter.ContainsKey($fam)) { $skuFilter = $SelectedSkuFilter[$fam] }

            $detailRows = $familyDetails | Where-Object {
                $_.Family -eq $fam -and (
                    -not $skuFilter -or $skuFilter -contains $_.SKU
                )
            }

            if ($detailRows.Count -gt 0) {
                # Group by region and display with region sub-headers
                $regionGroups = $detailRows | Group-Object Region | Sort-Object Name

                foreach ($regionGroup in $regionGroups) {
                    $regionName = $regionGroup.Name
                    $regionRows = $regionGroup.Group | Sort-Object SKU

                    # Get quota info for this family in this region
                    $regionQuota = $regionRows | Select-Object -First 1
                    $quotaHeader = if ($null -ne $regionQuota.QuotaLimit -and $null -ne $regionQuota.QuotaCurrent) {
                        $avail = $regionQuota.QuotaLimit - $regionQuota.QuotaCurrent
                        "Quota: $($regionQuota.QuotaCurrent) of $($regionQuota.QuotaLimit) vCPUs used | $avail available"
                    }
                    elseif ($regionQuota.QuotaAvail -and $regionQuota.QuotaAvail -ne '?') {
                        "Quota: $($regionQuota.QuotaAvail) vCPUs available"
                    }
                    else {
                        "Quota: N/A"
                    }

                    Write-Host "`nRegion: $regionName ($quotaHeader)" -ForegroundColor Yellow
                    Write-Host ("-" * $drillWidth) -ForegroundColor Gray

                    # Fixed-width drill-down table (no Region column since it's in header)
                    $dColWidths = [ordered]@{ SKU = 26; vCPU = 5; MemGiB = 6; Gen = 5; Arch = 5; ZoneStatus = 22; Capacity = 12; Avail = 8 }
                    if ($ShowPlacement -and $SkuFilter -and $SkuFilter.Count -gt 0) {
                        $dColWidths['Alloc'] = 8
                    }
                    if ($FetchPricing) {
                        $dColWidths['$/Hr'] = 8
                        $dColWidths['$/Mo'] = 8
                    }
                    if ($script:RunContext.ImageReqs) {
                        $dColWidths['Img'] = 4
                    }
                    $dColWidths['Reason'] = 24

                    $dHeader = foreach ($c in $dColWidths.Keys) { $c.PadRight($dColWidths[$c]) }
                    Write-Host ($dHeader -join '  ') -ForegroundColor Cyan

                    foreach ($dr in $regionRows) {
                        $dRow = foreach ($c in $dColWidths.Keys) {
                            # Map column names to object properties
                            $propName = switch ($c) {
                                'Img' { 'ImgCompat' }
                                'Avail' { 'QuotaAvail' }
                                default { $c }
                            }
                            $v = if ($null -ne $dr.$propName) { "$($dr.$propName)" } else { '' }
                            $w = $dColWidths[$c]
                            if ($v.Length -gt $w) { $v = $v.Substring(0, $w - 1) + '…' }
                            $v.PadRight($w)
                        }
                        # Determine row color based on capacity and image compatibility
                        $color = switch ($dr.Capacity) {
                            'OK' { if ($dr.ImgCompat -eq '✗' -or $dr.ImgCompat -eq '[-]') { 'DarkYellow' } else { 'Green' } }
                            { $_ -match 'LIMITED|CAPACITY' } { 'Yellow' }
                            { $_ -match 'RESTRICTED|BLOCKED' } { 'Red' }
                            default { 'White' }
                        }
                        Write-Host ($dRow -join '  ') -ForegroundColor $color
                    }
                }
            }
            else {
                Write-Host "No matching SKUs found for selection." -ForegroundColor DarkYellow
            }
        }
    }
}

#endregion Drill-Down (if enabled)
#region Interactive Recommend Mode Prompt

if (-not $NoPrompt -and -not $Recommend) {
    Write-Host "`nFind alternative SKUs for a specific VM? (y/N): " -ForegroundColor Yellow -NoNewline
    $recommendInput = Read-Host
    if ($recommendInput -match '^y(es)?$') {
        Write-Host "`nEnter VM SKU name (e.g., 'Standard_D4s_v5' or 'D4s_v5'): " -ForegroundColor Cyan -NoNewline
        $recommendSku = Read-Host
        if ($recommendSku -and $recommendSku.Trim()) {
            $recommendSku = $recommendSku.Trim()
            if ($recommendSku -notmatch '^Standard_') {
                $recommendSku = "Standard_$recommendSku"
            }
            Invoke-RecommendMode -TargetSkuName $recommendSku -SubscriptionData $allSubscriptionData `
                -FamilyInfo $FamilyInfo -Icons $Icons -FetchPricing ([bool]$FetchPricing) `
                -ShowSpot $ShowSpot.IsPresent -ShowPlacement $ShowPlacement.IsPresent `
                -AllowMixedArch $AllowMixedArch.IsPresent -MinvCPU $MinvCPU -MinMemoryGB $MinMemoryGB `
                -MinScore $MinScore -TopN $TopN -DesiredCount $DesiredCount `
                -JsonOutput $JsonOutput.IsPresent -MaxRetries $MaxRetries `
                -RunContext $script:RunContext -OutputWidth $script:OutputWidth
        }
        else {
            Write-Host "Skipping recommend mode (no SKU provided)." -ForegroundColor Yellow
        }
    }
}

#endregion Interactive Recommend Mode Prompt
#region Multi-Region Matrix

Write-Host "`n" -NoNewline

# Build unique region list
$allRegions = @()
foreach ($family in $allFamilyStats.Keys) {
    foreach ($regionKey in $allFamilyStats[$family].Regions.Keys) {
        $regionStr = Get-SafeString $regionKey
        if ($allRegions -notcontains $regionStr) { $allRegions += $regionStr }
    }
}
$allRegions = @($allRegions | Sort-Object)

$colWidth = 12
$headerLine = "Family".PadRight(10)
foreach ($r in $allRegions) { $headerLine += " | " + $r.PadRight($colWidth) }
$matrixWidth = $headerLine.Length

# Set script-level output width for consistent separators
$script:OutputWidth = [Math]::Max($matrixWidth, $DefaultTerminalWidth)

# Display section header with dynamic width
Write-Host ("=" * $matrixWidth) -ForegroundColor Gray
Write-Host "MULTI-REGION CAPACITY MATRIX" -ForegroundColor Green
Write-Host ("=" * $matrixWidth) -ForegroundColor Gray
Write-Host ""
Write-Host "SUMMARY: Best-case status for each VM family (e.g., D, F, NC) per region." -ForegroundColor DarkGray
Write-Host "This shows if ANY SKUs in the family are available - not all SKUs." -ForegroundColor DarkGray
Write-Host "For individual SKU details, see the detailed table above." -ForegroundColor DarkGray
Write-Host ""

# Display table header
Write-Host $headerLine -ForegroundColor Cyan
Write-Host ("-" * $matrixWidth) -ForegroundColor Gray

# Data rows
foreach ($family in ($allFamilyStats.Keys | Sort-Object)) {
    $stats = $allFamilyStats[$family]
    $line = $family.PadRight(10)
    $bestStatus = $null

    foreach ($regionItem in $allRegions) {
        $region = Get-SafeString $regionItem
        $regionStats = $stats.Regions[$region]

        if ($regionStats) {
            $status = $regionStats.Capacity
            $icon = Get-StatusIcon -Status $status -Icons $Icons
            if ($status -eq 'OK') { $bestStatus = 'OK' }
            elseif ($status -match 'CONSTRAINED|PARTIAL' -and $bestStatus -ne 'OK') { $bestStatus = 'MIXED' }
            $line += " | " + $icon.PadRight($colWidth)
        }
        else {
            $line += " | " + "-".PadRight($colWidth)
        }
    }

    $color = switch ($bestStatus) { 'OK' { 'Green' }; 'MIXED' { 'Yellow' }; default { 'Gray' } }
    Write-Host $line -ForegroundColor $color
}

Write-Host ""
Write-Host "HOW TO READ THIS:" -ForegroundColor Cyan
Write-Host "  Green row  = At least one SKU in this family is fully available." -ForegroundColor Green
Write-Host "  Yellow row = Some SKUs may work, but there are constraints." -ForegroundColor Yellow
Write-Host "  Gray row   = No SKUs from this family available in scanned regions." -ForegroundColor Gray
Write-Host ""
Write-Host "STATUS MEANINGS:" -ForegroundColor Cyan
Write-Host ("  $($Icons.OK)".PadRight(16) + "= Ready to deploy. No restrictions.") -ForegroundColor Green
Write-Host ("  $($Icons.CAPACITY)".PadRight(16) + "= Azure is low on hardware. Try a different zone or wait.") -ForegroundColor Yellow
Write-Host ("  $($Icons.LIMITED)".PadRight(16) + "= Your subscription can't use this. Request access via support ticket.") -ForegroundColor Yellow
Write-Host ("  $($Icons.PARTIAL)".PadRight(16) + "= Some zones work, others are blocked. No zone redundancy.") -ForegroundColor Yellow
Write-Host ("  $($Icons.BLOCKED)".PadRight(16) + "= Cannot deploy. Pick a different region or SKU.") -ForegroundColor Red
Write-Host ""
Write-Host "NOTE: 'OK' means SOME SKUs work, not ALL. Check the detailed table above" -ForegroundColor DarkYellow
Write-Host "      for specific SKU availability (e.g., Standard_D4s_v5 vs Standard_D8s_v5)." -ForegroundColor DarkYellow
Write-Host ""
Write-Host "NEED MORE CAPACITY?" -ForegroundColor Cyan
Write-Host "  LIMITED status: Request quota increase at:" -ForegroundColor Yellow
# Use environment-aware portal URL
$quotaPortalUrl = if ($script:AzureEndpoints -and $script:AzureEndpoints.EnvironmentName) {
    switch ($script:AzureEndpoints.EnvironmentName) {
        'AzureUSGovernment' { 'https://portal.azure.us/#view/Microsoft_Azure_Capacity/QuotaMenuBlade/~/myQuotas' }
        'AzureChinaCloud' { 'https://portal.azure.cn/#view/Microsoft_Azure_Capacity/QuotaMenuBlade/~/myQuotas' }
        default { 'https://portal.azure.com/#view/Microsoft_Azure_Capacity/QuotaMenuBlade/~/myQuotas' }
    }
}
else {
    'https://portal.azure.com/#view/Microsoft_Azure_Capacity/QuotaMenuBlade/~/myQuotas'
}
Write-Host "  $quotaPortalUrl" -ForegroundColor DarkCyan
if ($FetchPricing) {
    Write-Host ""
    Write-Host "PRICING NOTE:" -ForegroundColor Cyan
    Write-Host "  Prices shown are Pay-As-You-Go (Linux). Azure Hybrid Benefit can reduce costs 40-60%." -ForegroundColor DarkGray
}

#endregion Multi-Region Matrix
#region Deployment Recommendations

Write-Host "`n" -NoNewline
Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
Write-Host "DEPLOYMENT RECOMMENDATIONS" -ForegroundColor Green
Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
Write-Host ""

$bestPerRegion = @{}
foreach ($r in $allRegions) { $bestPerRegion[$r] = @() }

foreach ($family in $allFamilyStats.Keys) {
    $stats = $allFamilyStats[$family]
    foreach ($regionKey in $stats.Regions.Keys) {
        $region = Get-SafeString $regionKey
        if ($stats.Regions[$regionKey].Capacity -eq 'OK') {
            $bestPerRegion[$region] += $family
        }
    }
}

$hasBest = ($bestPerRegion.Values | Measure-Object -Property Count -Sum).Sum -gt 0
if ($hasBest) {
    Write-Host "Regions with full capacity:" -ForegroundColor Green
    foreach ($r in $allRegions) {
        $families = @($bestPerRegion[$r])
        if ($families.Count -gt 0) {
            Write-Host "  $r`:" -ForegroundColor Green -NoNewline
            Write-Host " $($families -join ', ')" -ForegroundColor White
        }
    }
}
else {
    Write-Host "No regions have full capacity for the scanned families." -ForegroundColor Yellow
    Write-Host "Best available options (with constraints):" -ForegroundColor Yellow
    foreach ($family in ($allFamilyStats.Keys | Sort-Object | Select-Object -First 5)) {
        $stats = $allFamilyStats[$family]
        $bestRegion = $stats.Regions.Keys | Sort-Object { $stats.Regions[$_].Available } -Descending | Select-Object -First 1
        if ($bestRegion) {
            $regionStat = $stats.Regions[$bestRegion]
            Write-Host "  $family in $bestRegion" -ForegroundColor Yellow -NoNewline
            Write-Host " ($($regionStat.Capacity))" -ForegroundColor DarkYellow
        }
    }
}

#endregion Deployment Recommendations
#region Detailed Breakdown

Write-Host "`n" -NoNewline
Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
Write-Host "DETAILED CROSS-REGION BREAKDOWN" -ForegroundColor Green
Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
Write-Host ""
Write-Host "SUMMARY: Shows which regions have capacity for each VM family." -ForegroundColor DarkGray
Write-Host "  'Available'   = At least one SKU in this family can be deployed here" -ForegroundColor DarkGray
Write-Host "  'Constrained' = Family has issues in this region (see reason in parentheses)" -ForegroundColor DarkGray
Write-Host "  '(none)'      = No regions in that category for this family" -ForegroundColor DarkGray
Write-Host ""
Write-Host "IMPORTANT: This is a family-level summary. Individual SKUs within a family" -ForegroundColor DarkYellow
Write-Host "           may have different availability. Check the detailed table above." -ForegroundColor DarkYellow
Write-Host ""

# Calculate column widths based on ACTUAL terminal width for better Cloud Shell support
# Try to detect actual console width, fall back to a safe default
$actualWidth = try {
    $hostWidth = $Host.UI.RawUI.WindowSize.Width
    if ($hostWidth -gt 0) { $hostWidth } else { $DefaultTerminalWidth }
}
catch { $DefaultTerminalWidth }

# Use the smaller of OutputWidth or actual terminal width for this table
$tableWidth = [Math]::Min($script:OutputWidth, $actualWidth - 2)
$tableWidth = [Math]::Max($tableWidth, $MinTableWidth)

# Fixed column widths for consistent alignment
# Family: 8 chars, Available: 20 chars, Constrained: rest
$colFamily = 8
$colAvailable = 20
$colConstrained = [Math]::Max(30, $tableWidth - $colFamily - $colAvailable - 4)

$headerFamily = "Family".PadRight($colFamily)
$headerAvail = "Available".PadRight($colAvailable)
$headerConst = "Constrained"
Write-Host "$headerFamily  $headerAvail  $headerConst" -ForegroundColor Cyan
Write-Host ("-" * $tableWidth) -ForegroundColor Gray

$summaryRowsForExport = @()
foreach ($family in ($allFamilyStats.Keys | Sort-Object)) {
    $stats = $allFamilyStats[$family]
    $regionsOK = [System.Collections.Generic.List[string]]::new()
    $regionsConstrained = [System.Collections.Generic.List[string]]::new()

    foreach ($regionKey in ($stats.Regions.Keys | Sort-Object)) {
        $regionKeyStr = Get-SafeString $regionKey
        $regionStat = $stats.Regions[$regionKey]  # Use original key for lookup
        if ($regionStat) {
            if ($regionStat.Capacity -eq 'OK') {
                $regionsOK.Add($regionKeyStr)
            }
            elseif ($regionStat.Capacity -match 'LIMITED|CAPACITY-CONSTRAINED|PARTIAL|RESTRICTED|BLOCKED') {
                # Shorten status labels for narrow terminals
                $shortStatus = switch -Regex ($regionStat.Capacity) {
                    'CAPACITY-CONSTRAINED' { 'CONSTRAINED' }
                    default { $regionStat.Capacity }
                }
                $regionsConstrained.Add("$regionKeyStr ($shortStatus)")
            }
        }
    }

    # Format multi-line output
    $okLines = @(Format-RegionList -Regions $regionsOK.ToArray() -MaxWidth $colAvailable)
    $constrainedLines = @(Format-RegionList -Regions $regionsConstrained.ToArray() -MaxWidth $colConstrained)

    # Flatten if nested (PowerShell array quirk)
    if ($okLines.Count -eq 1 -and $okLines[0] -is [array]) { $okLines = $okLines[0] }
    if ($constrainedLines.Count -eq 1 -and $constrainedLines[0] -is [array]) { $constrainedLines = $constrainedLines[0] }

    # Determine how many lines we need (max of both columns)
    $maxLines = [Math]::Max(@($okLines).Count, @($constrainedLines).Count)

    # Determine color for the family name based on availability
    # Green  = Perfect (All regions OK)
    # White  = Mixed (Some OK, some constrained - check details)
    # Yellow = Constrained (No regions strictly OK, all have limitations)
    # Gray   = Unavailable
    $familyColor = if ($regionsOK.Count -gt 0 -and $regionsConstrained.Count -eq 0) { 'Green' }
    elseif ($regionsOK.Count -gt 0 -and $regionsConstrained.Count -gt 0) { 'White' }
    elseif ($regionsConstrained.Count -gt 0) { 'Yellow' }
    else { 'Gray' }

    # Iterate through lines to print
    for ($i = 0; $i -lt $maxLines; $i++) {
        $familyStr = if ($i -eq 0) { $family } else { '' }
        $okStr = if ($i -lt @($okLines).Count) { @($okLines)[$i] } else { '' }
        $constrainedStr = if ($i -lt @($constrainedLines).Count) { @($constrainedLines)[$i] } else { '' }

        # Write each column with appropriate color (use 2 spaces between columns for clarity)
        Write-Host ("{0,-$colFamily}  " -f $familyStr) -ForegroundColor $familyColor -NoNewline
        Write-Host ("{0,-$colAvailable}  " -f $okStr) -ForegroundColor Green -NoNewline
        Write-Host $constrainedStr -ForegroundColor Yellow
    }

    # Export data
    $exportRow = [ordered]@{
        Family     = $family
        Total_SKUs = ($stats.Regions.Values | Measure-Object -Property Count -Sum).Sum
        SKUs_OK    = (($stats.Regions.Values | Where-Object { $_.Capacity -eq 'OK' } | Measure-Object -Property Available -Sum).Sum)
    }
    foreach ($r in $allRegions) {
        $regionStat = $stats.Regions[$r]
        if ($regionStat) {
            $exportRow["$r`_Status"] = "$($regionStat.Capacity) ($($regionStat.Available)/$($regionStat.Count))"
        }
        else {
            $exportRow["$r`_Status"] = 'N/A'
        }
    }
    $summaryRowsForExport += [pscustomobject]$exportRow
}

Write-Progress -Activity "Processing Region Data" -Completed

#endregion Detailed Breakdown
#region Completion

$totalElapsed = (Get-Date) - $scanStartTime

Write-Host "`n" -NoNewline
Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
Write-Host "SCAN COMPLETE" -ForegroundColor Green
Write-Host "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Total time: $([math]::Round($totalElapsed.TotalSeconds, 1)) seconds" -ForegroundColor DarkGray
Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray

#endregion Completion
#region Export

if ($ExportPath) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

    # Determine format
    $useXLSX = ($OutputFormat -eq 'XLSX') -or ($OutputFormat -eq 'Auto' -and (Test-ImportExcelModule))

    Write-Host "`nEXPORTING..." -ForegroundColor Cyan

    if ($useXLSX -and (Test-ImportExcelModule)) {
        $xlsxFile = Join-Path $ExportPath "AzVMAvailability-$timestamp.xlsx"
        try {
            # Define colors for conditional formatting
            $greenFill = [System.Drawing.Color]::FromArgb(198, 239, 206)
            $greenText = [System.Drawing.Color]::FromArgb(0, 97, 0)
            $yellowFill = [System.Drawing.Color]::FromArgb(255, 235, 156)
            $yellowText = [System.Drawing.Color]::FromArgb(156, 101, 0)
            $redFill = [System.Drawing.Color]::FromArgb(255, 199, 206)
            $redText = [System.Drawing.Color]::FromArgb(156, 0, 6)
            $headerBlue = [System.Drawing.Color]::FromArgb(0, 120, 212)  # Azure blue
            $lightGray = [System.Drawing.Color]::FromArgb(242, 242, 242)

            #region Summary Sheet
            $excel = $summaryRowsForExport | Export-Excel -Path $xlsxFile -WorksheetName "Summary" -AutoSize -FreezeTopRow -PassThru

            $ws = $excel.Workbook.Worksheets["Summary"]
            $lastRow = $ws.Dimension.End.Row
            $lastCol = $ws.Dimension.End.Column

            $headerRange = $ws.Cells["A1:$(ConvertTo-ExcelColumnLetter $lastCol)1"]
            $headerRange.Style.Font.Bold = $true
            $headerRange.Style.Font.Color.SetColor([System.Drawing.Color]::White)
            $headerRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
            $headerRange.Style.Fill.BackgroundColor.SetColor($headerBlue)
            $headerRange.Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center

            for ($row = 2; $row -le $lastRow; $row++) {
                if ($row % 2 -eq 0) {
                    $rowRange = $ws.Cells["A$row`:$(ConvertTo-ExcelColumnLetter $lastCol)$row"]
                    $rowRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                    $rowRange.Style.Fill.BackgroundColor.SetColor($lightGray)
                }
            }

            for ($col = 4; $col -le $lastCol; $col++) {
                $colLetter = ConvertTo-ExcelColumnLetter $col
                $statusRange = "$colLetter`2:$colLetter$lastRow"

                # OK status - Green
                Add-ConditionalFormatting -Worksheet $ws -Range $statusRange -RuleType ContainsText -ConditionValue "OK (" -BackgroundColor $greenFill -ForegroundColor $greenText

                # LIMITED status - Yellow/Orange
                Add-ConditionalFormatting -Worksheet $ws -Range $statusRange -RuleType ContainsText -ConditionValue "LIMITED" -BackgroundColor $yellowFill -ForegroundColor $yellowText

                # CAPACITY-CONSTRAINED - Light orange
                Add-ConditionalFormatting -Worksheet $ws -Range $statusRange -RuleType ContainsText -ConditionValue "CAPACITY" -BackgroundColor $yellowFill -ForegroundColor $yellowText

                # N/A - Gray
                Add-ConditionalFormatting -Worksheet $ws -Range $statusRange -RuleType Equal -ConditionValue "N/A" -BackgroundColor $lightGray -ForegroundColor ([System.Drawing.Color]::Gray)
            }

            $dataRange = $ws.Cells["A1:$(ConvertTo-ExcelColumnLetter $lastCol)$lastRow"]
            $dataRange.Style.Border.Top.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Bottom.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Left.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Right.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin

            $ws.Cells["B2:C$lastRow"].Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center

            #region Add Compact Legend to Summary Sheet
            $legendStartRow = $lastRow + 3  # Leave 2 blank rows

            # Legend title - Capacity Status
            $ws.Cells["A$legendStartRow"].Value = "CAPACITY STATUS"
            $ws.Cells["A$legendStartRow`:C$legendStartRow"].Merge = $true
            $ws.Cells["A$legendStartRow"].Style.Font.Bold = $true
            $ws.Cells["A$legendStartRow"].Style.Font.Size = 11
            $ws.Cells["A$legendStartRow"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
            $ws.Cells["A$legendStartRow"].Style.Fill.BackgroundColor.SetColor($headerBlue)
            $ws.Cells["A$legendStartRow"].Style.Font.Color.SetColor([System.Drawing.Color]::White)

            # Status codes table
            $statusItems = @(
                @{ Status = "OK"; Desc = "Ready to deploy. No restrictions." }
                @{ Status = "LIMITED"; Desc = "Your subscription can't use this. Request access via support ticket." }
                @{ Status = "CAPACITY-CONSTRAINED"; Desc = "Azure is low on hardware. Try a different zone or wait." }
                @{ Status = "PARTIAL"; Desc = "Some zones work, others are blocked. No zone redundancy." }
                @{ Status = "RESTRICTED"; Desc = "Cannot deploy. Pick a different region or SKU." }
            )

            $currentRow = $legendStartRow + 1
            foreach ($item in $statusItems) {
                $ws.Cells["A$currentRow"].Value = $item.Status
                $ws.Cells["B$currentRow`:C$currentRow"].Merge = $true
                $ws.Cells["B$currentRow"].Value = $item.Desc
                $ws.Cells["A$currentRow"].Style.Font.Bold = $true
                $ws.Cells["A$currentRow"].Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center

                # Apply matching colors to status cell
                $ws.Cells["A$currentRow"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                switch ($item.Status) {
                    "OK" {
                        $ws.Cells["A$currentRow"].Style.Fill.BackgroundColor.SetColor($greenFill)
                        $ws.Cells["A$currentRow"].Style.Font.Color.SetColor($greenText)
                    }
                    { $_ -in "LIMITED", "CAPACITY-CONSTRAINED", "PARTIAL" } {
                        $ws.Cells["A$currentRow"].Style.Fill.BackgroundColor.SetColor($yellowFill)
                        $ws.Cells["A$currentRow"].Style.Font.Color.SetColor($yellowText)
                    }
                    "RESTRICTED" {
                        $ws.Cells["A$currentRow"].Style.Fill.BackgroundColor.SetColor($redFill)
                        $ws.Cells["A$currentRow"].Style.Font.Color.SetColor($redText)
                    }
                }

                $ws.Cells["A$currentRow`:C$currentRow"].Style.Border.Top.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
                $ws.Cells["A$currentRow`:C$currentRow"].Style.Border.Bottom.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
                $ws.Cells["A$currentRow`:C$currentRow"].Style.Border.Left.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
                $ws.Cells["A$currentRow`:C$currentRow"].Style.Border.Right.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin

                $currentRow++
            }

            # Image Compatibility section (if image checking was used)
            $currentRow += 2  # Skip a row
            $ws.Cells["A$currentRow"].Value = "IMAGE COMPATIBILITY (Img Column)"
            $ws.Cells["A$currentRow`:C$currentRow"].Merge = $true
            $ws.Cells["A$currentRow"].Style.Font.Bold = $true
            $ws.Cells["A$currentRow"].Style.Font.Size = 11
            $ws.Cells["A$currentRow"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
            $ws.Cells["A$currentRow"].Style.Fill.BackgroundColor.SetColor($headerBlue)
            $ws.Cells["A$currentRow"].Style.Font.Color.SetColor([System.Drawing.Color]::White)

            $imgItems = @(
                @{ Symbol = "✓"; Desc = "SKU is compatible with selected image (Gen & Arch match)" }
                @{ Symbol = "✗"; Desc = "SKU is NOT compatible (wrong generation or architecture)" }
                @{ Symbol = "[-]"; Desc = "Unable to determine compatibility" }
            )

            $currentRow++
            foreach ($item in $imgItems) {
                $ws.Cells["A$currentRow"].Value = $item.Symbol
                $ws.Cells["B$currentRow`:C$currentRow"].Merge = $true
                $ws.Cells["B$currentRow"].Value = $item.Desc
                $ws.Cells["A$currentRow"].Style.Font.Bold = $true
                $ws.Cells["A$currentRow"].Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center
                $ws.Cells["A$currentRow"].Style.Font.Size = 12

                $ws.Cells["A$currentRow"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                switch ($item.Symbol) {
                    "✓" {
                        $ws.Cells["A$currentRow"].Style.Fill.BackgroundColor.SetColor($greenFill)
                        $ws.Cells["A$currentRow"].Style.Font.Color.SetColor($greenText)
                    }
                    "✗" {
                        $ws.Cells["A$currentRow"].Style.Fill.BackgroundColor.SetColor($redFill)
                        $ws.Cells["A$currentRow"].Style.Font.Color.SetColor($redText)
                    }
                    "[-]" {
                        $ws.Cells["A$currentRow"].Style.Fill.BackgroundColor.SetColor($lightGray)
                        $ws.Cells["A$currentRow"].Style.Font.Color.SetColor([System.Drawing.Color]::Gray)
                    }
                }

                $ws.Cells["A$currentRow`:C$currentRow"].Style.Border.Top.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
                $ws.Cells["A$currentRow`:C$currentRow"].Style.Border.Bottom.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
                $ws.Cells["A$currentRow`:C$currentRow"].Style.Border.Left.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
                $ws.Cells["A$currentRow`:C$currentRow"].Style.Border.Right.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin

                $currentRow++
            }

            $currentRow += 2
            $ws.Cells["A$currentRow"].Value = "FORMAT:"
            $ws.Cells["A$currentRow"].Style.Font.Bold = $true
            $ws.Cells["B$currentRow"].Value = "STATUS (X/Y) = X SKUs available out of Y total"
            $currentRow++
            $ws.Cells["A$currentRow`:C$currentRow"].Merge = $true
            $ws.Cells["A$currentRow"].Value = "See 'Legend' tab for detailed column descriptions"
            $ws.Cells["A$currentRow"].Style.Font.Italic = $true
            $ws.Cells["A$currentRow"].Style.Font.Color.SetColor([System.Drawing.Color]::Gray)

            $ws.Column(1).Width = 22
            $ws.Column(2).Width = 35
            $ws.Column(3).Width = 25

            Close-ExcelPackage $excel

            #region Details Sheet
            $excel = $familyDetails | Export-Excel -Path $xlsxFile -WorksheetName "Details" -AutoSize -FreezeTopRow -Append -PassThru

            $ws = $excel.Workbook.Worksheets["Details"]
            $lastRow = $ws.Dimension.End.Row
            $lastCol = $ws.Dimension.End.Column

            $headerRange = $ws.Cells["A1:$(ConvertTo-ExcelColumnLetter $lastCol)1"]
            $headerRange.Style.Font.Bold = $true
            $headerRange.Style.Font.Color.SetColor([System.Drawing.Color]::White)
            $headerRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
            $headerRange.Style.Fill.BackgroundColor.SetColor($headerBlue)
            $headerRange.Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center

            $capacityCol = $null
            for ($c = 1; $c -le $lastCol; $c++) {
                if ($ws.Cells[1, $c].Value -eq "Capacity") {
                    $capacityCol = $c
                    break
                }
            }

            if ($capacityCol) {
                $colLetter = ConvertTo-ExcelColumnLetter $capacityCol
                $capacityRange = "$colLetter`2:$colLetter$lastRow"

                # OK - Green
                Add-ConditionalFormatting -Worksheet $ws -Range $capacityRange -RuleType Equal -ConditionValue "OK" -BackgroundColor $greenFill -ForegroundColor $greenText

                # LIMITED - Yellow
                Add-ConditionalFormatting -Worksheet $ws -Range $capacityRange -RuleType Equal -ConditionValue "LIMITED" -BackgroundColor $yellowFill -ForegroundColor $yellowText

                # CAPACITY-CONSTRAINED - Light orange
                Add-ConditionalFormatting -Worksheet $ws -Range $capacityRange -RuleType ContainsText -ConditionValue "CAPACITY" -BackgroundColor $yellowFill -ForegroundColor $yellowText

                # PARTIAL - Yellow (mixed zone availability)
                Add-ConditionalFormatting -Worksheet $ws -Range $capacityRange -RuleType Equal -ConditionValue "PARTIAL" -BackgroundColor $yellowFill -ForegroundColor $yellowText

                # RESTRICTED - Red
                Add-ConditionalFormatting -Worksheet $ws -Range $capacityRange -RuleType Equal -ConditionValue "RESTRICTED" -BackgroundColor $redFill -ForegroundColor $redText
            }

            $dataRange = $ws.Cells["A1:$(ConvertTo-ExcelColumnLetter $lastCol)$lastRow"]
            $dataRange.Style.Border.Top.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Bottom.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Left.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Right.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin

            $ws.Cells["E2:F$lastRow"].Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center
            $ws.Cells["J2:J$lastRow"].Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center

            $ws.Cells["A1:$(ConvertTo-ExcelColumnLetter $lastCol)1"].AutoFilter = $true

            Close-ExcelPackage $excel

            #region Legend Sheet
            $legendData = @(
                [PSCustomObject]@{ Category = "STATUS FORMAT"; Item = "STATUS (X/Y)"; Description = "X = SKUs with full availability, Y = Total SKUs in family for that region" }
                [PSCustomObject]@{ Category = "STATUS FORMAT"; Item = "Example: OK (5/8)"; Description = "5 out of 8 SKUs are fully available with OK status" }
                [PSCustomObject]@{ Category = ""; Item = ""; Description = "" }
                [PSCustomObject]@{ Category = "CAPACITY STATUS"; Item = "OK"; Description = "Ready to deploy. No restrictions." }
                [PSCustomObject]@{ Category = "CAPACITY STATUS"; Item = "LIMITED"; Description = "Your subscription can't use this. Request access via support ticket." }
                [PSCustomObject]@{ Category = "CAPACITY STATUS"; Item = "CAPACITY-CONSTRAINED"; Description = "Azure is low on hardware. Try a different zone or wait." }
                [PSCustomObject]@{ Category = "CAPACITY STATUS"; Item = "PARTIAL"; Description = "Some zones work, others are blocked. No zone redundancy." }
                [PSCustomObject]@{ Category = "CAPACITY STATUS"; Item = "RESTRICTED"; Description = "Cannot deploy. Pick a different region or SKU." }
                [PSCustomObject]@{ Category = "CAPACITY STATUS"; Item = "N/A"; Description = "SKU family not available in this region." }
                [PSCustomObject]@{ Category = ""; Item = ""; Description = "" }
                [PSCustomObject]@{ Category = "SUMMARY COLUMNS"; Item = "Family"; Description = "VM family identifier (e.g., Dv5, Ev5, Mv2)" }
                [PSCustomObject]@{ Category = "SUMMARY COLUMNS"; Item = "Total_SKUs"; Description = "Total number of SKUs scanned across all regions" }
                [PSCustomObject]@{ Category = "SUMMARY COLUMNS"; Item = "SKUs_OK"; Description = "Number of SKUs with full availability (OK status)" }
                [PSCustomObject]@{ Category = "SUMMARY COLUMNS"; Item = "<Region>_Status"; Description = "Capacity status for that region with (Available/Total) count" }
                [PSCustomObject]@{ Category = ""; Item = ""; Description = "" }
                [PSCustomObject]@{ Category = "DETAILS COLUMNS"; Item = "Family"; Description = "VM family identifier" }
                [PSCustomObject]@{ Category = "DETAILS COLUMNS"; Item = "SKU"; Description = "Full SKU name (e.g., Standard_D2s_v5)" }
                [PSCustomObject]@{ Category = "DETAILS COLUMNS"; Item = "Region"; Description = "Azure region code" }
                [PSCustomObject]@{ Category = "DETAILS COLUMNS"; Item = "vCPU"; Description = "Number of virtual CPUs" }
                [PSCustomObject]@{ Category = "DETAILS COLUMNS"; Item = "MemGiB"; Description = "Memory in GiB" }
                [PSCustomObject]@{ Category = "DETAILS COLUMNS"; Item = "Zones"; Description = "Availability zones where SKU is available" }
                [PSCustomObject]@{ Category = "DETAILS COLUMNS"; Item = "Capacity"; Description = "Current capacity status" }
                [PSCustomObject]@{ Category = "DETAILS COLUMNS"; Item = "Restrictions"; Description = "Any restrictions or capacity messages" }
                [PSCustomObject]@{ Category = "DETAILS COLUMNS"; Item = "QuotaAvail"; Description = "Available vCPU quota for this family (Limit - Current Usage)" }
                [PSCustomObject]@{ Category = ""; Item = ""; Description = "" }
                [PSCustomObject]@{ Category = "COLOR CODING"; Item = "Green"; Description = "Ready to deploy. No restrictions." }
                [PSCustomObject]@{ Category = "COLOR CODING"; Item = "Yellow/Orange"; Description = "Constrained. Check status for what to do next." }
                [PSCustomObject]@{ Category = "COLOR CODING"; Item = "Red"; Description = "Cannot deploy. Pick a different region or SKU." }
                [PSCustomObject]@{ Category = "COLOR CODING"; Item = "Gray"; Description = "Not available in this region." }
            )

            $excel = $legendData | Export-Excel -Path $xlsxFile -WorksheetName "Legend" -AutoSize -Append -PassThru

            $ws = $excel.Workbook.Worksheets["Legend"]
            $legendLastRow = $ws.Dimension.End.Row

            $ws.Cells["A1:C1"].Style.Font.Bold = $true
            $ws.Cells["A1:C1"].Style.Font.Color.SetColor([System.Drawing.Color]::White)
            $ws.Cells["A1:C1"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
            $ws.Cells["A1:C1"].Style.Fill.BackgroundColor.SetColor($headerBlue)

            $ws.Cells["A2:A$legendLastRow"].Style.Font.Bold = $true

            $ws.Cells["A1:C$legendLastRow"].Style.Border.Top.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $ws.Cells["A1:C$legendLastRow"].Style.Border.Bottom.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $ws.Cells["A1:C$legendLastRow"].Style.Border.Left.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $ws.Cells["A1:C$legendLastRow"].Style.Border.Right.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin

            # Apply colors to color coding rows
            for ($row = 2; $row -le $legendLastRow; $row++) {
                $itemValue = $ws.Cells["B$row"].Value
                if ($itemValue -eq "Green") {
                    $ws.Cells["B$row"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                    $ws.Cells["B$row"].Style.Fill.BackgroundColor.SetColor($greenFill)
                    $ws.Cells["B$row"].Style.Font.Color.SetColor($greenText)
                }
                elseif ($itemValue -eq "Yellow/Orange") {
                    $ws.Cells["B$row"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                    $ws.Cells["B$row"].Style.Fill.BackgroundColor.SetColor($yellowFill)
                    $ws.Cells["B$row"].Style.Font.Color.SetColor($yellowText)
                }
                elseif ($itemValue -eq "Red") {
                    $ws.Cells["B$row"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                    $ws.Cells["B$row"].Style.Fill.BackgroundColor.SetColor($redFill)
                    $ws.Cells["B$row"].Style.Font.Color.SetColor($redText)
                }
                elseif ($itemValue -eq "Gray") {
                    $ws.Cells["B$row"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                    $ws.Cells["B$row"].Style.Fill.BackgroundColor.SetColor($lightGray)
                    $ws.Cells["B$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Gray)
                }
                # Style status values in Legend
                elseif ($itemValue -eq "OK") {
                    $ws.Cells["B$row"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                    $ws.Cells["B$row"].Style.Fill.BackgroundColor.SetColor($greenFill)
                    $ws.Cells["B$row"].Style.Font.Color.SetColor($greenText)
                }
                elseif ($itemValue -eq "LIMITED" -or $itemValue -eq "CAPACITY-CONSTRAINED" -or $itemValue -eq "PARTIAL") {
                    $ws.Cells["B$row"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                    $ws.Cells["B$row"].Style.Fill.BackgroundColor.SetColor($yellowFill)
                    $ws.Cells["B$row"].Style.Font.Color.SetColor($yellowText)
                }
                elseif ($itemValue -eq "RESTRICTED") {
                    $ws.Cells["B$row"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                    $ws.Cells["B$row"].Style.Fill.BackgroundColor.SetColor($redFill)
                    $ws.Cells["B$row"].Style.Font.Color.SetColor($redText)
                }
                elseif ($itemValue -eq "N/A") {
                    $ws.Cells["B$row"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                    $ws.Cells["B$row"].Style.Fill.BackgroundColor.SetColor($lightGray)
                    $ws.Cells["B$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Gray)
                }
            }

            $ws.Column(1).Width = 20
            $ws.Column(2).Width = 25
            $ws.Column(3).Width = $ExcelDescriptionColumnWidth

            Close-ExcelPackage $excel

            Write-Host "  $($Icons.Check) XLSX: $xlsxFile" -ForegroundColor Green
            Write-Host "    - Summary sheet with color-coded status" -ForegroundColor DarkGray
            Write-Host "    - Details sheet with filters and conditional formatting" -ForegroundColor DarkGray
            Write-Host "    - Legend sheet explaining status codes and format" -ForegroundColor DarkGray
        }
        catch {
            Write-Host "  $($Icons.Warning) XLSX formatting failed: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "  $($Icons.Warning) Falling back to basic XLSX..." -ForegroundColor Yellow
            try {
                $summaryRowsForExport | Export-Excel -Path $xlsxFile -WorksheetName "Summary" -AutoSize -FreezeTopRow
                $familyDetails | Export-Excel -Path $xlsxFile -WorksheetName "Details" -AutoSize -FreezeTopRow -Append
                Write-Host "  $($Icons.Check) XLSX (basic): $xlsxFile" -ForegroundColor Green
            }
            catch {
                Write-Host "  $($Icons.Warning) XLSX failed, falling back to CSV" -ForegroundColor Yellow
                $useXLSX = $false
            }
        }
    }

    if (-not $useXLSX) {
        $summaryFile = Join-Path $ExportPath "AzVMAvailability-Summary-$timestamp.csv"
        $detailFile = Join-Path $ExportPath "AzVMAvailability-Details-$timestamp.csv"

        $summaryRowsForExport | Export-Csv -Path $summaryFile -NoTypeInformation -Encoding UTF8
        $familyDetails | Export-Csv -Path $detailFile -NoTypeInformation -Encoding UTF8

        Write-Host "  $($Icons.Check) Summary: $summaryFile" -ForegroundColor Green
        Write-Host "  $($Icons.Check) Details: $detailFile" -ForegroundColor Green
    }

    Write-Host "`nExport complete!" -ForegroundColor Green

    # Prompt to open Excel file
    if ($useXLSX -and (Test-Path $xlsxFile)) {
        if (-not $NoPrompt) {
            Write-Host ""
            $openExcel = Read-Host "Open Excel file now? (Y/n)"
            if ($openExcel -eq '' -or $openExcel -match '^[Yy]') {
                Write-Host "Opening $xlsxFile..." -ForegroundColor Cyan
                Start-Process $xlsxFile
            }
        }
    }
}
#endregion Export
}
finally {
    $script:SuppressConsole = $false
    [void](Restore-OriginalSubscriptionContext -OriginalSubscriptionId $initialSubscriptionId)
}
}
