#Requires -Version 7.0
<#
.SYNOPSIS
    Get-AzVMAvailability - Comprehensive SKU availability and capacity scanner.

.DESCRIPTION
    Thin wrapper script that imports the AzVMAvailability module and calls
    Get-AzVMAvailability. All parameters, behavior, and output are identical
    to the module cmdlet.

    For direct module usage:
        Import-Module .\AzVMAvailability
        Get-AzVMAvailability -Region eastus -NoPrompt

.NOTES
    Name:           Get-AzVMAvailability
    Author:         Zachary Luz
    Created:        2026-01-21
    Version:        2.1.0
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

    [Parameter(Mandatory = $false, HelpMessage = "Path to a CSV, JSON, or XLSX file listing current VM SKUs for lifecycle analysis.")]
    [string]$LifecycleRecommendations,

    [Parameter(Mandatory = $false, HelpMessage = "Pull live VM inventory from Azure via Resource Graph for lifecycle analysis.")]
    [switch]$LifecycleScan,

    [Parameter(Mandatory = $false, HelpMessage = "Filter -LifecycleScan to specific management group(s). Requires Az.ResourceGraph module.")]
    [string[]]$ManagementGroup,

    [Parameter(Mandatory = $false, HelpMessage = "Filter -LifecycleScan to specific resource group(s).")]
    [string[]]$ResourceGroup,

    [Parameter(Mandatory = $false, HelpMessage = "Filter -LifecycleScan to VMs with specific tags. Hashtable of key=value pairs, e.g. @{Environment='prod'}. Use '*' as value to match any VM that has the tag key regardless of value.")]
    [Alias("Tags")]
    [hashtable]$Tag,

    [Parameter(Mandatory = $false, HelpMessage = "Add a 'Subscription Map' sheet to the lifecycle XLSX.")]
    [switch]$SubMap,

    [Parameter(Mandatory = $false, HelpMessage = "Add a 'Resource Group Map' sheet to the lifecycle XLSX.")]
    [switch]$RGMap
)

# Version for Validate-Script.ps1 parity check (must match .psd1 ModuleVersion)
$ScriptVersion = "2.1.1"
Write-Verbose "Get-AzVMAvailability wrapper v$ScriptVersion"

# Import the AzVMAvailability module from the same directory as this script
$modulePath = Join-Path $PSScriptRoot 'AzVMAvailability'
if (-not (Test-Path (Join-Path $modulePath 'AzVMAvailability.psd1'))) {
    throw @"
AzVMAvailability module not found at '$modulePath'.

To fix this, choose one of the following:

  Option A — Install the module from PSGallery (recommended):
    Install-Module AzVMAvailability -Repository PSGallery
    Get-AzVMAvailability -Region eastus -NoPrompt

  Option B — Clone the full repository:
    git clone https://github.com/ZacharyLuz/Get-AzVMAvailability.git
    cd Get-AzVMAvailability
    .\Get-AzVMAvailability.ps1 -Region eastus -NoPrompt

This script requires the AzVMAvailability/ module folder alongside it.
If you downloaded only the .ps1 file, use Option A instead.
"@
}
Import-Module $modulePath -Force -DisableNameChecking -ErrorAction Stop

# Forward all parameters to the module cmdlet
Get-AzVMAvailability @PSBoundParameters
