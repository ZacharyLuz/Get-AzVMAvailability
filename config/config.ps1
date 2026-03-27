# config.ps1
# Reference copy extracted from Get-AzVMAvailability.ps1
# Contains: [CmdletBinding()] param block, $ProgressPreference, FleetFile/Fleet normalization,
#           #region Configuration constants, $MinScore default, and parameter mappings.
# DO NOT execute this file directly — it is a documentation reference only.
# The authoritative source is Get-AzVMAvailability.ps1.
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
$ScriptVersion = "1.12.4"

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
