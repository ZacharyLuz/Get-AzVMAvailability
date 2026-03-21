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
    Options: AzureCloud, AzureUSGovernment, AzureChinaCloud, AzureGermanCloud

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
    Version:        1.12.3
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
    .\Get-AzVMAvailability.ps1 -FleetFile .\fleet.csv -Region "eastus" -NoPrompt
    Load a fleet BOM from CSV file. The CSV needs SKU and Qty columns:
    SKU,Qty
    Standard_D2s_v5,17
    Standard_D4s_v5,4
    Standard_D8s_v5,5

.EXAMPLE
    .\Get-AzVMAvailability.ps1 -Fleet @{'Standard_D2s_v5'=17; 'Standard_D4s_v5'=4; 'Standard_D8s_v5'=5} -Region "eastus" -NoPrompt
    Inline fleet BOM using PowerShell hashtable syntax.

.EXAMPLE
    .\Get-AzVMAvailability.ps1 -GenerateFleetTemplate
    Creates fleet-template.csv and fleet-template.json in the current directory.
    Edit the files with your VM SKUs and quantities, then run:
    .\Get-AzVMAvailability.ps1 -FleetFile .\fleet-template.csv -Region "eastus" -NoPrompt

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

    [Parameter(Mandatory = $false, HelpMessage = "Export format: Auto, CSV, or XLSX")]
    [ValidateSet("Auto", "CSV", "XLSX")]
    [string]$OutputFormat = "Auto",

    [Parameter(Mandatory = $false, HelpMessage = "Force ASCII icons instead of Unicode")]
    [switch]$UseAsciiIcons,

    [Parameter(Mandatory = $false, HelpMessage = "Azure cloud environment (default: auto-detect from Az context)")]
    [ValidateSet("AzureCloud", "AzureUSGovernment", "AzureChinaCloud", "AzureGermanCloud")]
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

    [Parameter(Mandatory = $false, HelpMessage = "Fleet BOM: hashtable of SKU=Quantity pairs for fleet readiness validation (e.g., @{'Standard_D2s_v5'=17; 'Standard_D4s_v5'=4})")]
    [hashtable]$Fleet,

    [Parameter(Mandatory = $false, HelpMessage = "Path to a CSV or JSON fleet BOM file. CSV: columns SKU,Qty. JSON: array of {SKU:'...',Qty:N} objects. Duplicate SKUs are summed.")]
    [string]$FleetFile,

    [Parameter(Mandatory = $false, HelpMessage = "Generate fleet-template.csv and fleet-template.json in the current directory, then exit. No Azure login required.")]
    [switch]$GenerateFleetTemplate
)

$ProgressPreference = 'SilentlyContinue'  # Suppress progress bars for faster execution

#region GenerateFleetTemplate
if ($GenerateFleetTemplate) {
    if ($JsonOutput) { throw "Cannot use -GenerateFleetTemplate with -JsonOutput. Template generation writes files to disk, not JSON to stdout." }
    $csvPath = Join-Path $PWD 'fleet-template.csv'
    $jsonPath = Join-Path $PWD 'fleet-template.json'
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
    Write-Host "Created fleet templates:" -ForegroundColor Green
    Write-Host "  CSV: $csvPath" -ForegroundColor Cyan
    Write-Host "  JSON: $jsonPath" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Next steps:" -ForegroundColor Yellow
    Write-Host "  1. Edit the template with your VM SKUs and quantities"
    Write-Host "  2. Run: .\Get-AzVMAvailability.ps1 -FleetFile .\fleet-template.csv -Region 'eastus' -NoPrompt"
    return
}
#endregion GenerateFleetTemplate

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-Warning "PowerShell 7+ is required to run Get-AzVMAvailability.ps1."
    Write-Host "Current host: $($PSVersionTable.PSEdition) $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
    Write-Host "Install PowerShell 7 and rerun with: pwsh -File .\Get-AzVMAvailability.ps1" -ForegroundColor Cyan
    throw "PowerShell 7+ is required. Current version: $($PSVersionTable.PSVersion)"
}

# Normalize string[] params — pwsh -File passes comma-delimited values as a single string
foreach ($paramName in @('SubscriptionId', 'Region', 'FamilyFilter', 'SkuFilter')) {
    $val = Get-Variable -Name $paramName -ValueOnly -ErrorAction SilentlyContinue
    if ($val -and $val.Count -eq 1 -and $val[0] -match ',') {
        Set-Variable -Name $paramName -Value @($val[0] -split ',' | ForEach-Object { $_.Trim().Trim('"', "'") } | Where-Object { $_ })
    }
}

# FleetFile: load CSV/JSON into $Fleet hashtable
if ($FleetFile) {
    if ($Fleet) { throw "Cannot specify both -Fleet and -FleetFile. Use one or the other." }
    if (-not (Test-Path -LiteralPath $FleetFile -PathType Leaf)) { throw "Fleet file not found or is not a file: $FleetFile" }
    $ext = [System.IO.Path]::GetExtension($FleetFile).ToLower()
    if ($ext -notin '.csv', '.json') { throw "Unsupported file type '$ext'. FleetFile must be .csv or .json" }
    if ($ext -eq '.json') {
        $jsonData = @(Get-Content -LiteralPath $FleetFile -Raw | ConvertFrom-Json)
        $Fleet = @{}
        foreach ($item in $jsonData) {
            $skuProp = ($item.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
            $qtyProp = ($item.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
            if ($skuProp -and $qtyProp) {
                $skuClean = $skuProp.Trim()
                $qtyInt = [int]$qtyProp
                if ($qtyInt -le 0) { throw "Invalid quantity '$qtyProp' for SKU '$skuClean'. Qty must be a positive integer." }
                if ($Fleet.ContainsKey($skuClean)) { $Fleet[$skuClean] += $qtyInt }
                else { $Fleet[$skuClean] = $qtyInt }
            }
        }
    }
    else {
        $csvData = Import-Csv -LiteralPath $FleetFile
        $Fleet = @{}
        foreach ($row in $csvData) {
            $skuProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(SKU|Name|VmSize|Intel\.SKU)$' } | Select-Object -First 1).Value
            $qtyProp = ($row.PSObject.Properties | Where-Object { $_.Name -match '^(Qty|Quantity|Count)$' } | Select-Object -First 1).Value
            if ($skuProp -and $qtyProp) {
                $skuClean = $skuProp.Trim()
                $qtyInt = [int]$qtyProp
                if ($qtyInt -le 0) { throw "Invalid quantity '$qtyProp' for SKU '$skuClean'. Qty must be a positive integer." }
                if ($Fleet.ContainsKey($skuClean)) { $Fleet[$skuClean] += $qtyInt }
                else { $Fleet[$skuClean] = $qtyInt }
            }
        }
    }
    if ($Fleet.Count -eq 0) { throw "No valid SKU/Qty rows found in $FleetFile. Expected columns: SKU (or Name/VmSize), Qty (or Quantity/Count)" }
    if (-not $JsonOutput) { Write-Host "Loaded $($Fleet.Count) SKUs from $FleetFile" -ForegroundColor Cyan }
}

# Fleet mode: normalize keys (strip double-prefix) and derive SkuFilter
if ($Fleet -and $Fleet.Count -gt 0) {
    $normalizedFleet = @{}
    foreach ($key in @($Fleet.Keys)) {
        $clean = $key -replace '^Standard_Standard_', 'Standard_'
        if ($clean -notmatch '^Standard_') { $clean = "Standard_$clean" }
        $normalizedFleet[$clean] = $Fleet[$key]
    }
    $Fleet = $normalizedFleet
    $SkuFilter = @($Fleet.Keys)
    Write-Verbose "Fleet mode: derived SkuFilter from $($Fleet.Count) Fleet SKUs"
}

#region Configuration
$ScriptVersion = "1.12.3"

#region Constants
$HoursPerMonth = 730
$ParallelThrottleLimit = 4
$OutputWidthWithPricing = 140
$OutputWidthBase = 122
$OutputWidthMin = 100
$OutputWidthMax = 150

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
#region Module Import
$script:ModuleRoot = Join-Path $PSScriptRoot 'AzVMAvailability'
if (Test-Path (Join-Path $script:ModuleRoot 'AzVMAvailability.psd1')) {
    Import-Module $script:ModuleRoot -Force -DisableNameChecking -ErrorAction Stop
} else {
    throw "AzVMAvailability module not found at $script:ModuleRoot. Ensure the AzVMAvailability/ directory exists."
}
#endregion Module Import
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

if (-not $TargetSubIds) {
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

if (-not $Regions) {
    if ($NoPrompt) {
        $Regions = @('eastus', 'eastus2', 'centralus')
        Write-Host "Using default regions: $($Regions -join ', ')" -ForegroundColor Cyan
    }
    else {
        Write-Host "`nSTEP 2: SELECT REGION(S)" -ForegroundColor Green
        Write-Host ("=" * 100) -ForegroundColor Gray
        Write-Host ""
        Write-Host "FAST PATH: Type region codes now to skip the long list (comma/space separated)" -ForegroundColor Yellow
        Write-Host "Examples: eastus eastus2 westus3  |  Press Enter to show full menu" -ForegroundColor DarkGray
        Write-Host "Press Enter for defaults: eastus, eastus2, centralus" -ForegroundColor DarkGray
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
            Write-Host "  - Press Enter for defaults: eastus, eastus2, centralus" -ForegroundColor White
            Write-Host ""
            $regionsInput = Read-Host "Select region(s)"

            if ([string]::IsNullOrWhiteSpace($regionsInput)) {
                $Regions = @('eastus', 'eastus2', 'centralus')
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

# Validate region count limit
$maxRegions = 5
if ($Regions.Count -gt $maxRegions) {
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
if (-not $NoPrompt -and -not $EnableDrill) {
    Write-Host "`nDrill down into specific families/SKUs? (y/N): " -ForegroundColor Yellow -NoNewline
    $drillInput = Read-Host
    if ($drillInput -match '^y(es)?$') { $EnableDrill = $true }
}

# Export prompt
if (-not $ExportPath -and -not $NoPrompt -and -not $AutoExport) {
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
if (-not $ShowPricing -and -not $NoPrompt) {
    Write-Host "`nInclude estimated pricing? (adds ~5-10 sec) (y/N): " -ForegroundColor Yellow -NoNewline
    $pricingInput = Read-Host
    if ($pricingInput -match '^y(es)?$') { $FetchPricing = $true }
}

# Placement score prompt — fires independently (useful without pricing)
if (-not $ShowPlacement -and -not $NoPrompt) {
    Write-Host "`nShow allocation likelihood scores? (High/Medium/Low per SKU) (y/N): " -ForegroundColor Yellow -NoNewline
    $placementInput = Read-Host
    if ($placementInput -match '^y(es)?$') { $ShowPlacement = [switch]::new($true) }
}
$script:RunContext.ShowPlacement = $ShowPlacement.IsPresent

# Spot pricing prompt — only useful if pricing is enabled
if (-not $ShowSpot -and -not $NoPrompt -and $FetchPricing) {
    Write-Host "`nInclude Spot VM pricing alongside regular pricing? (y/N): " -ForegroundColor Yellow -NoNewline
    $spotInput = Read-Host
    if ($spotInput -match '^y(es)?$') { $ShowSpot = [switch]::new($true) }
}

# Image compatibility prompt
if (-not $ImageURN -and -not $NoPrompt) {
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
try {
    try {
        foreach ($subId in $TargetSubIds) {
        $scanStartTime = Get-Date
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

        $scanRegionScript = {
            param($region, $skuFilterCopy, $maxRetries)

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
                        $isThrottle = $msg -match '429' -or $msg -match 'Too Many Requests' -or
                        $msg -match '503' -or $msg -match 'ServiceUnavailable'
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
                $allSkus = & $retryCall -Action {
                    Get-AzComputeResourceSku -Location $region -ErrorAction Stop |
                    Where-Object { $_.ResourceType -eq 'virtualMachines' }
                } -Retries $maxRetries

                # Apply SKU filter if specified
                if ($skuFilterCopy -and $skuFilterCopy.Count -gt 0) {
                    $allSkus = $allSkus | Where-Object {
                        $skuName = $_.Name
                        $isMatch = $false
                        foreach ($pattern in $skuFilterCopy) {
                            $regexPattern = '^' + [regex]::Escape($pattern).Replace('\*', '.*').Replace('\?', '.') + '$'
                            if ($skuName -match $regexPattern) {
                                $isMatch = $true
                                break
                            }
                        }
                        $isMatch
                    }
                }

                $quotas = & $retryCall -Action {
                    Get-AzVMUsage -Location $region -ErrorAction Stop
                } -Retries $maxRetries

                @{ Region = [string]$region; Skus = $allSkus; Quotas = $quotas; Error = $null }
            }
            catch {
                @{ Region = [string]$region; Skus = @(); Quotas = @(); Error = $_.Exception.Message }
            }
        }

        $canUseParallel = $PSVersionTable.PSVersion.Major -ge 7
        if ($canUseParallel) {
            try {
                $regionData = $Regions | ForEach-Object -Parallel {
                    $region = [string]$_
                    $skuFilterCopy = $using:SkuFilter
                    $maxRetries = $using:MaxRetries

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
                                $isThrottle = $msg -match '429' -or $msg -match 'Too Many Requests' -or
                                $msg -match '503' -or $msg -match 'ServiceUnavailable' -or $msg -match 'Service Unavailable'
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
                        $allSkus = & $retryCall -Action {
                            Get-AzComputeResourceSku -Location $region -ErrorAction Stop |
                            Where-Object { $_.ResourceType -eq 'virtualMachines' }
                        } -Retries $maxRetries

                        if ($skuFilterCopy -and $skuFilterCopy.Count -gt 0) {
                            $allSkus = $allSkus | Where-Object {
                                $skuName = $_.Name
                                $isMatch = $false
                                foreach ($pattern in $skuFilterCopy) {
                                    $regexPattern = '^' + [regex]::Escape($pattern).Replace('\*', '.*').Replace('\?', '.') + '$'
                                    if ($skuName -match $regexPattern) {
                                        $isMatch = $true
                                        break
                                    }
                                }
                                $isMatch
                            }
                        }

                        $quotas = & $retryCall -Action {
                            Get-AzVMUsage -Location $region -ErrorAction Stop
                        } -Retries $maxRetries

                        @{ Region = [string]$region; Skus = $allSkus; Quotas = $quotas; Error = $null }
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
                & $scanRegionScript -region ([string]$region) -skuFilterCopy $SkuFilter -maxRetries $MaxRetries
            }
        }

        Write-Progress -Activity "Scanning Azure Regions" -Completed

        $scanElapsed = (Get-Date) - $scanStartTime
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
#region Fleet Readiness

if ($Fleet -and $Fleet.Count -gt 0) {
    $fleetResult = Get-FleetReadiness -Fleet $Fleet -SubscriptionData $allSubscriptionData
    Write-FleetReadinessSummary -FleetResult $fleetResult -Fleet $Fleet

    if ($JsonOutput) {
        $fleetResult | ConvertTo-Json -Depth 5
    }

    # Fleet mode exits after summary — no need to render full scan output
    return
}

#endregion Fleet Readiness
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
        'AzureGermanCloud' { 'https://portal.microsoftazure.de/#view/Microsoft_Azure_Capacity/QuotaMenuBlade/~/myQuotas' }
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

            $headerRange = $ws.Cells["A1:$([char](64 + $lastCol))1"]
            $headerRange.Style.Font.Bold = $true
            $headerRange.Style.Font.Color.SetColor([System.Drawing.Color]::White)
            $headerRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
            $headerRange.Style.Fill.BackgroundColor.SetColor($headerBlue)
            $headerRange.Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center

            for ($row = 2; $row -le $lastRow; $row++) {
                if ($row % 2 -eq 0) {
                    $rowRange = $ws.Cells["A$row`:$([char](64 + $lastCol))$row"]
                    $rowRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                    $rowRange.Style.Fill.BackgroundColor.SetColor($lightGray)
                }
            }

            for ($col = 4; $col -le $lastCol; $col++) {
                $colLetter = [char](64 + $col)
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

            $dataRange = $ws.Cells["A1:$([char](64 + $lastCol))$lastRow"]
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

            $headerRange = $ws.Cells["A1:$([char](64 + $lastCol))1"]
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
                $colLetter = [char](64 + $capacityCol)
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

            $dataRange = $ws.Cells["A1:$([char](64 + $lastCol))$lastRow"]
            $dataRange.Style.Border.Top.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Bottom.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Left.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Right.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin

            $ws.Cells["E2:F$lastRow"].Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center
            $ws.Cells["J2:J$lastRow"].Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center

            $ws.Cells["A1:$([char](64 + $lastCol))1"].AutoFilter = $true

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
    [void](Restore-OriginalSubscriptionContext -OriginalSubscriptionId $initialSubscriptionId)
}
