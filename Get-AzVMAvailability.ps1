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

.PARAMETER TopN
    Number of alternative SKUs to return in Recommend mode. Default 5, max 25.

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

.NOTES
    Name:           Get-AzVMAvailability
    Author:         Zachary Luz
    Company:        Microsoft
    Created:        2026-01-21
    Version:        1.8.0
    License:        MIT
    Repository:     https://github.com/zacharyluz/Get-AzVMAvailability

    Requirements:   Az.Compute, Az.Resources modules
                    PowerShell 7+ (for parallel execution)

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
    .\Get-AzVMAvailability.ps1 -Recommend "E64pds_v6" -RegionPreset USMajor -TopN 10
    Find top 10 alternatives across major US regions (Standard_ prefix auto-added).

.EXAMPLE
    .\Get-AzVMAvailability.ps1 -Recommend "Standard_D4s_v5" -Region "eastus" -JsonOutput -NoPrompt
    Emit structured JSON instead of console tables. Designed for the AzVMAvailability-Agent
    (https://github.com/ZacharyLuz/AzVMAvailability-Agent) which parses this output to
    provide conversational VM recommendations. Also useful for piping into other tools
    or storing scan results programmatically.

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

    [Parameter(Mandatory = $false, HelpMessage = "Minimum vCPU count for recommended alternatives")]
    [ValidateRange(1, 416)]
    [int]$MinvCPU,

    [Parameter(Mandatory = $false, HelpMessage = "Minimum memory in GB for recommended alternatives")]
    [ValidateRange(1, 12288)]
    [int]$MinMemoryGB,

    [Parameter(Mandatory = $false, HelpMessage = "Emit structured JSON output for automation/agent consumption")]
    [switch]$JsonOutput
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'  # Suppress progress bars for faster execution

# Normalize string[] params — pwsh -File passes comma-delimited values as a single string
foreach ($paramName in @('SubscriptionId', 'Region', 'FamilyFilter', 'SkuFilter')) {
    $val = Get-Variable -Name $paramName -ValueOnly -ErrorAction SilentlyContinue
    if ($val -and $val.Count -eq 1 -and $val[0] -match ',') {
        Set-Variable -Name $paramName -Value @($val[0] -split ',' | ForEach-Object { $_.Trim().Trim('"', "'") } | Where-Object { $_ })
    }
}

#region Configuration
$ScriptVersion = "1.8.0"

#region Constants
$HoursPerMonth = 730
$ParallelThrottleLimit = 4
$OutputWidthWithPricing = 133
$OutputWidthBase = 113
$OutputWidthMin = 100
$OutputWidthMax = 150

# VM family purpose descriptions and category groupings
$FamilyInfo = @{
    'A'  = @{ Purpose = 'Entry-level/test';       Category = 'Basic' }
    'B'  = @{ Purpose = 'Burstable';              Category = 'General' }
    'D'  = @{ Purpose = 'General purpose';         Category = 'General' }
    'DC' = @{ Purpose = 'Confidential';            Category = 'General' }
    'E'  = @{ Purpose = 'Memory optimized';        Category = 'Memory' }
    'EC' = @{ Purpose = 'Confidential memory';     Category = 'Memory' }
    'F'  = @{ Purpose = 'Compute optimized';       Category = 'Compute' }
    'FX' = @{ Purpose = 'High-freq compute';       Category = 'Compute' }
    'G'  = @{ Purpose = 'Memory+storage';          Category = 'Memory' }
    'H'  = @{ Purpose = 'HPC';                     Category = 'HPC' }
    'HB' = @{ Purpose = 'HPC (AMD)';               Category = 'HPC' }
    'HC' = @{ Purpose = 'HPC (Intel)';             Category = 'HPC' }
    'HX' = @{ Purpose = 'HPC (large memory)';      Category = 'HPC' }
    'L'  = @{ Purpose = 'Storage optimized';       Category = 'Storage' }
    'M'  = @{ Purpose = 'Large memory (SAP/HANA)'; Category = 'Memory' }
    'NC' = @{ Purpose = 'GPU compute';             Category = 'GPU' }
    'ND' = @{ Purpose = 'GPU training (AI/ML)';    Category = 'GPU' }
    'NG' = @{ Purpose = 'GPU graphics';            Category = 'GPU' }
    'NP' = @{ Purpose = 'GPU FPGA';               Category = 'GPU' }
    'NV' = @{ Purpose = 'GPU visualization';       Category = 'GPU' }
}
$DefaultTerminalWidth = 80
$MinTableWidth = 70
$ExcelDescriptionColumnWidth = 70
#endregion Constants

# Map parameters to internal variables
$TargetSubIds = $SubscriptionId
$Regions = $Region
$EnableDrill = $EnableDrillDown.IsPresent

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

# Validate -Recommend mode conflicts
if ($Recommend) {
    if ($EnableDrillDown) {
        Write-Host "ERROR: -Recommend cannot be used with -EnableDrillDown" -ForegroundColor Red
        return
    }
    if ($ImageURN) {
        Write-Host "ERROR: -Recommend cannot be used with -ImageURN" -ForegroundColor Red
        return
    }
    # Normalize SKU name — add Standard_ prefix if missing
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
        OK          = '✓ OK'
        CAPACITY    = '⚠ CONSTRAINED'
        LIMITED     = '⚠ LIMITED'
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
        OK          = '[OK]'
        CAPACITY    = '[CONSTRAINED]'
        LIMITED     = '[LIMITED]'
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
#region Helper Functions

function Get-SafeString {
    <#
    .SYNOPSIS
        Safely converts a value to string, unwrapping arrays from parallel execution.
    .DESCRIPTION
        When using ForEach-Object -Parallel, PowerShell serializes objects which can
        wrap strings in arrays. This function recursively unwraps those arrays to
        get the underlying string value. Critical for hashtable key lookups.
    #>
    param([object]$Value)
    if ($null -eq $Value) { return '' }
    # Recursively unwrap nested arrays (parallel execution can create multiple levels)
    while ($Value -is [array] -and $Value.Count -gt 0) {
        $Value = $Value[0]
    }
    if ($null -eq $Value) { return '' }
    return "$Value"  # String interpolation is safer than .ToString()
}

function Invoke-WithRetry {
    <#
    .SYNOPSIS
        Executes a script block with retry logic for transient Azure API errors.
    .DESCRIPTION
        Wraps any API call with automatic retry on:
        - HTTP 429 (Too Many Requests) — reads Retry-After header
        - HTTP 503 (Service Unavailable) — transient Azure outages
        - Network timeouts and WebExceptions
        Uses exponential backoff with jitter between retries.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [string]$OperationName = 'API call'
    )

    $attempt = 0
    while ($true) {
        try {
            return & $ScriptBlock
        }
        catch {
            $attempt++
            $ex = $_.Exception
            $isRetryable = $false
            $waitSeconds = [math]::Pow(2, $attempt)  # Exponential: 2, 4, 8...

            # HTTP 429 — Too Many Requests (throttled)
            $statusCode = if ($ex.Response) { $ex.Response.StatusCode.value__ } else { $null }
            if ($statusCode -eq 429 -or $ex.Message -match '429|Too Many Requests') {
                $isRetryable = $true
                if ($ex.Response -and $ex.Response.Headers) {
                    $retryAfter = $ex.Response.Headers['Retry-After']
                    if ($retryAfter -and [int]::TryParse($retryAfter, [ref]$null)) {
                        $waitSeconds = [int]$retryAfter
                    }
                }
            }
            # HTTP 503 — Service Unavailable
            elseif ($statusCode -eq 503 -or $ex.Message -match '503|Service Unavailable') {
                $isRetryable = $true
            }
            # Network errors — timeouts, connection failures
            elseif ($ex -is [System.Net.WebException] -or
                $ex -is [System.Net.Http.HttpRequestException] -or
                $ex.InnerException -is [System.Net.WebException] -or
                $ex.InnerException -is [System.Net.Http.HttpRequestException] -or
                $ex.Message -match 'timed?\s*out|connection.*reset|connection.*refused') {
                $isRetryable = $true
            }

            if (-not $isRetryable -or $attempt -ge $MaxRetries) {
                throw
            }

            # Add jitter (0-25%) to prevent thundering herd
            $jitter = Get-Random -Minimum 0 -Maximum ([math]::Max(1, [int]($waitSeconds * 0.25)))
            $waitSeconds += $jitter

            Write-Verbose "$OperationName failed (attempt $attempt/$MaxRetries): $($ex.Message). Retrying in ${waitSeconds}s..."
            Start-Sleep -Seconds $waitSeconds
        }
    }
}

function Get-GeoGroup {
    param([string]$LocationCode)
    $code = $LocationCode.ToLower()
    switch -regex ($code) {
        '^(eastus|eastus2|westus|westus2|westus3|centralus|northcentralus|southcentralus|westcentralus)' { return 'Americas-US' }
        '^(usgov|usdod|usnat|ussec)' { return 'Americas-USGov' }
        '^canada' { return 'Americas-Canada' }
        '^(brazil|chile|mexico)' { return 'Americas-LatAm' }
        '^(westeurope|northeurope|france|germany|switzerland|uksouth|ukwest|swedencentral|norwayeast|norwaywest|poland|italy|spain)' { return 'Europe' }
        '^(eastasia|southeastasia|japaneast|japanwest|koreacentral|koreasouth)' { return 'Asia-Pacific' }
        '^(centralindia|southindia|westindia|jioindia)' { return 'India' }
        '^(uae|qatar|israel|saudi)' { return 'Middle East' }
        '^(southafrica|egypt|kenya)' { return 'Africa' }
        '^(australia|newzealand)' { return 'Australia' }
        default { return 'Other' }
    }
}

function Get-AzureEndpoints {
    <#
    .SYNOPSIS
        Resolves Azure endpoints based on the current cloud environment.
    .DESCRIPTION
        Automatically detects the Azure environment (Commercial, Government, China, etc.)
        from the current Az context and returns the appropriate API endpoints.
        Supports sovereign clouds and air-gapped environments.
        Can be overridden with explicit environment name.
    .PARAMETER AzEnvironment
        Environment object for testing (mock).
    .PARAMETER EnvironmentName
        Explicit environment name override (AzureCloud, AzureUSGovernment, etc.).
    .OUTPUTS
        Hashtable with ResourceManagerUrl, PricingApiUrl, and EnvironmentName.
    .EXAMPLE
        $endpoints = Get-AzureEndpoints
        $endpoints.PricingApiUrl  # Returns https://prices.azure.com for Commercial
    .EXAMPLE
        $endpoints = Get-AzureEndpoints -EnvironmentName 'AzureUSGovernment'
        $endpoints.PricingApiUrl  # Returns https://prices.azure.us
    #>
    param(
        [Parameter(Mandatory = $false)]
        [object]$AzEnvironment,  # For testing - pass a mock environment object

        [Parameter(Mandatory = $false)]
        [string]$EnvironmentName  # Explicit override by name
    )

    # If explicit environment name provided, look it up
    if ($EnvironmentName) {
        try {
            $AzEnvironment = Get-AzEnvironment -Name $EnvironmentName -ErrorAction Stop
            if (-not $AzEnvironment) {
                Write-Warning "Environment '$EnvironmentName' not found. Using default Commercial cloud."
            }
            else {
                Write-Verbose "Using explicit environment: $EnvironmentName"
            }
        }
        catch {
            Write-Warning "Could not get environment '$EnvironmentName': $_. Using default Commercial cloud."
            $AzEnvironment = $null
        }
    }

    # Get the current Azure environment if not provided
    if (-not $AzEnvironment) {
        try {
            $context = Get-AzContext -ErrorAction Stop
            if (-not $context) {
                Write-Warning "No Azure context found. Using default Commercial cloud endpoints."
                $AzEnvironment = $null
            }
            else {
                $AzEnvironment = $context.Environment
            }
        }
        catch {
            Write-Warning "Could not get Azure context: $_. Using default Commercial cloud endpoints."
            $AzEnvironment = $null
        }
    }

    # Default to Commercial cloud if no environment detected
    if (-not $AzEnvironment) {
        return @{
            EnvironmentName    = 'AzureCloud'
            ResourceManagerUrl = 'https://management.azure.com'
            PricingApiUrl      = 'https://prices.azure.com/api/retail/prices'
        }
    }

    # Get the Resource Manager URL directly from the environment
    $armUrl = $AzEnvironment.ResourceManagerUrl
    if (-not $armUrl) {
        $armUrl = 'https://management.azure.com'
    }
    # Ensure no trailing slash
    $armUrl = $armUrl.TrimEnd('/')

    # Derive pricing API URL from the portal URL
    # Commercial: portal.azure.com -> prices.azure.com
    # Government: portal.azure.us -> prices.azure.us
    # China: portal.azure.cn -> prices.azure.cn
    $portalUrl = $AzEnvironment.ManagementPortalUrl
    if ($portalUrl) {
        # Replace only the 'portal' subdomain with 'prices' (more precise than global replace)
        $pricingUrl = $portalUrl -replace '^(https?://)?portal\.', '${1}prices.'
        $pricingUrl = $pricingUrl.TrimEnd('/')
        $pricingApiUrl = "$pricingUrl/api/retail/prices"
    }
    else {
        # Fallback based on known environment names
        $pricingApiUrl = switch ($AzEnvironment.Name) {
            'AzureUSGovernment' { 'https://prices.azure.us/api/retail/prices' }
            'AzureChinaCloud' { 'https://prices.azure.cn/api/retail/prices' }
            'AzureGermanCloud' { 'https://prices.microsoftazure.de/api/retail/prices' }
            default { 'https://prices.azure.com/api/retail/prices' }
        }
    }

    $endpoints = @{
        EnvironmentName    = $AzEnvironment.Name
        ResourceManagerUrl = $armUrl
        PricingApiUrl      = $pricingApiUrl
    }

    Write-Verbose "Azure Environment: $($endpoints.EnvironmentName)"
    Write-Verbose "Resource Manager URL: $($endpoints.ResourceManagerUrl)"
    Write-Verbose "Pricing API URL: $($endpoints.PricingApiUrl)"

    return $endpoints
}

function Get-CapValue {
    param([object]$Sku, [string]$Name)
    $cap = $Sku.Capabilities | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if ($cap) { return $cap.Value }
    return $null
}

function Get-SkuFamily {
    param([string]$SkuName)
    if ($SkuName -match 'Standard_([A-Z]+)\d') {
        return $matches[1]
    }
    return 'Unknown'
}

function Get-RestrictionReason {
    param([object]$Sku)
    if ($Sku.Restrictions -and $Sku.Restrictions.Count -gt 0) {
        return $Sku.Restrictions[0].ReasonCode
    }
    return $null
}

function Get-RestrictionDetails {
    <#
    .SYNOPSIS
        Analyzes SKU restrictions and returns detailed zone-level availability status.
    .DESCRIPTION
        Examines Azure SKU restrictions to determine:
        - Which zones are fully available (OK)
        - Which zones have capacity constraints (LIMITED)
        - Which zones are completely restricted (RESTRICTED)
        Returns a hashtable with status and zone breakdowns.
    #>
    param([object]$Sku)

    # If no restrictions, SKU is fully available in all zones
    if (-not $Sku -or -not $Sku.Restrictions -or $Sku.Restrictions.Count -eq 0) {
        $zones = if ($Sku -and $Sku.LocationInfo -and $Sku.LocationInfo[0].Zones) {
            $Sku.LocationInfo[0].Zones
        }
        else { @() }
        return @{
            Status             = 'OK'
            ZonesOK            = @($zones)
            ZonesLimited       = @()
            ZonesRestricted    = @()
            RestrictionReasons = @()
        }
    }

    # Categorize zones based on restriction type
    $zonesOK = @()
    $zonesLimited = @()
    $zonesRestricted = @()
    $reasonCodes = @()

    foreach ($r in $Sku.Restrictions) {
        $reasonCodes += $r.ReasonCode
        if ($r.Type -eq 'Zone' -and $r.RestrictionInfo -and $r.RestrictionInfo.Zones) {
            foreach ($zone in $r.RestrictionInfo.Zones) {
                if ($r.ReasonCode -eq 'NotAvailableForSubscription') {
                    if ($zonesLimited -notcontains $zone) { $zonesLimited += $zone }
                }
                else {
                    if ($zonesRestricted -notcontains $zone) { $zonesRestricted += $zone }
                }
            }
        }
    }

    if ($Sku.LocationInfo -and $Sku.LocationInfo[0].Zones) {
        foreach ($zone in $Sku.LocationInfo[0].Zones) {
            if ($zonesLimited -notcontains $zone -and $zonesRestricted -notcontains $zone) {
                if ($zonesOK -notcontains $zone) { $zonesOK += $zone }
            }
        }
    }

    $status = if ($zonesRestricted.Count -gt 0) {
        if ($zonesOK.Count -eq 0) { 'RESTRICTED' } else { 'PARTIAL' }
    }
    elseif ($zonesLimited.Count -gt 0) {
        if ($zonesOK.Count -eq 0) { 'LIMITED' } else { 'CAPACITY-CONSTRAINED' }
    }
    else { 'OK' }

    return @{
        Status             = $status
        ZonesOK            = @($zonesOK | Sort-Object)
        ZonesLimited       = @($zonesLimited | Sort-Object)
        ZonesRestricted    = @($zonesRestricted | Sort-Object)
        RestrictionReasons = @($reasonCodes | Select-Object -Unique)
    }
}

function Format-ZoneStatus {
    param([array]$OK, [array]$Limited, [array]$Restricted)
    $parts = @()
    if ($OK.Count -gt 0) { $parts += "✓ Zones $($OK -join ',')" }
    if ($Limited.Count -gt 0) { $parts += "⚠ Zones $($Limited -join ',')" }
    if ($Restricted.Count -gt 0) { $parts += "✗ Zones $($Restricted -join ',')" }
    if ($parts.Count -eq 0) { return 'Non-zonal' }  # No zone info = regional deployment
    return $parts -join ' | '
}

function Format-RegionList {
    param(
        [Parameter(Mandatory = $false)]
        [object]$Regions,
        [int]$MaxWidth = 75
    )

    if ($null -eq $Regions) {
        return , @('(none)')
    }

    $regionArray = @($Regions)

    if ($regionArray.Count -eq 0) {
        return , @('(none)')
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $currentLine = ""

    foreach ($region in $regionArray) {
        $regionStr = [string]$region
        $separator = if ($currentLine) { ', ' } else { '' }
        $testLine = $currentLine + $separator + $regionStr

        if ($testLine.Length -gt $MaxWidth -and $currentLine) {
            $lines.Add($currentLine)
            $currentLine = $regionStr
        }
        else {
            $currentLine = $testLine
        }
    }

    if ($currentLine) {
        $lines.Add($currentLine)
    }

    return , @($lines.ToArray())
}

function Get-QuotaAvailable {
    param([object[]]$Quotas, [string]$FamilyName, [int]$RequiredvCPUs = 0)
    $quota = $Quotas | Where-Object { $_.Name.LocalizedValue -match $FamilyName } | Select-Object -First 1
    if (-not $quota) { return @{ Available = $null; OK = $null; Limit = $null; Current = $null } }
    $available = $quota.Limit - $quota.CurrentValue
    return @{
        Available = $available
        OK        = if ($RequiredvCPUs -gt 0) { $available -ge $RequiredvCPUs } else { $available -gt 0 }
        Limit     = $quota.Limit
        Current   = $quota.CurrentValue
    }
}

function Get-StatusIcon {
    param([string]$Status)
    switch ($Status) {
        'OK' { return $Icons.OK }
        'CAPACITY-CONSTRAINED' { return $Icons.CAPACITY }
        'LIMITED' { return $Icons.LIMITED }
        'PARTIAL' { return $Icons.PARTIAL }
        'RESTRICTED' { return $Icons.BLOCKED }
        default { return $Icons.UNKNOWN }
    }
}

function Test-ImportExcelModule {
    try {
        $module = Get-Module ImportExcel -ListAvailable -ErrorAction SilentlyContinue
        if ($module) {
            Import-Module ImportExcel -ErrorAction Stop -WarningAction SilentlyContinue
            return $true
        }
        return $false
    }
    catch { return $false }
}

function Test-SkuMatchesFilter {
    <#
    .SYNOPSIS
        Tests if a SKU name matches any of the filter patterns.
    .DESCRIPTION
        Supports exact matches and wildcard patterns (e.g., Standard_D*_v5).
        Case-insensitive matching.
    #>
    param([string]$SkuName, [string[]]$FilterPatterns)

    if (-not $FilterPatterns -or $FilterPatterns.Count -eq 0) {
        return $true  # No filter = include all
    }

    foreach ($pattern in $FilterPatterns) {
        # Convert wildcard pattern to regex
        $regexPattern = '^' + [regex]::Escape($pattern).Replace('\*', '.*').Replace('\?', '.') + '$'
        if ($SkuName -match $regexPattern) {
            return $true
        }
    }

    return $false
}

function Get-SkuSimilarityScore {
    <#
    .SYNOPSIS
        Scores how similar a candidate SKU is to a target SKU profile.
    .DESCRIPTION
        Weighted scoring across 6 dimensions: vCPU (25), memory (25), family (20),
        generation (13), architecture (12), premium IO (5). Max 100.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Target,
        [Parameter(Mandatory)][hashtable]$Candidate
    )

    $score = 0

    # vCPU closeness (25 points)
    if ($Target.vCPU -gt 0 -and $Candidate.vCPU -gt 0) {
        $maxCpu = [math]::Max($Target.vCPU, $Candidate.vCPU)
        $cpuScore = 1 - ([math]::Abs($Target.vCPU - $Candidate.vCPU) / $maxCpu)
        $score += [math]::Round($cpuScore * 25)
    }

    # Memory closeness (25 points)
    if ($Target.MemoryGB -gt 0 -and $Candidate.MemoryGB -gt 0) {
        $maxMem = [math]::Max($Target.MemoryGB, $Candidate.MemoryGB)
        $memScore = 1 - ([math]::Abs($Target.MemoryGB - $Candidate.MemoryGB) / $maxMem)
        $score += [math]::Round($memScore * 25)
    }

    # Family match (20 points) — exact = 20, same category = 15, same first letter = 10
    if ($Target.Family -eq $Candidate.Family) {
        $score += 20
    }
    else {
        $targetInfo = if ($script:FamilyInfo) { $script:FamilyInfo[$Target.Family] } else { $null }
        $candidateInfo = if ($script:FamilyInfo) { $script:FamilyInfo[$Candidate.Family] } else { $null }
        $targetCat = if ($targetInfo) { $targetInfo.Category } else { 'Unknown' }
        $candidateCat = if ($candidateInfo) { $candidateInfo.Category } else { 'Unknown' }
        if ($targetCat -ne 'Unknown' -and $targetCat -eq $candidateCat) {
            $score += 15
        }
        elseif ($Target.Family.Length -gt 0 -and $Candidate.Family.Length -gt 0 -and
                $Target.Family[0] -eq $Candidate.Family[0]) {
            $score += 10
        }
    }

    # Generation match (13 points)
    if ($Target.Generation -and $Candidate.Generation) {
        $targetGens = @($Target.Generation -split ',')
        $candidateGens = @($Candidate.Generation -split ',')
        $overlap = $targetGens | Where-Object { $_ -in $candidateGens }
        if ($overlap) { $score += 13 }
    }

    # Architecture match (12 points)
    if ($Target.Architecture -eq $Candidate.Architecture) {
        $score += 12
    }

    # Premium IO match (5 points) — if target needs premium, candidate must have it
    if ($Target.PremiumIO -eq $true -and $Candidate.PremiumIO -eq $true) {
        $score += 5
    }
    elseif ($Target.PremiumIO -ne $true) {
        $score += 5
    }

    return [math]::Min($score, 100)
}

#endregion Helper Functions
#region Image Compatibility Functions

function Get-ImageRequirements {
    <#
    .SYNOPSIS
        Parses an image URN and determines its Generation and Architecture requirements.
    .DESCRIPTION
        Analyzes the image URN (Publisher:Offer:Sku:Version) to determine if the image
        requires Gen1 or Gen2 VMs, and whether it needs x64 or ARM64 architecture.
        Uses pattern matching on SKU names for common Azure Marketplace images.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ImageURN
    )

    $parts = $ImageURN -split ':'
    if ($parts.Count -lt 3) {
        return @{ Gen = 'Unknown'; Arch = 'Unknown'; Valid = $false; Error = "Invalid URN format" }
    }

    $publisher = $parts[0]
    $offer = $parts[1]
    $sku = $parts[2]

    # Determine Generation from SKU name patterns
    $gen = 'Gen1'  # Default to Gen1 for compatibility
    if ($sku -match '-gen2|-g2|gen2|_gen2|arm64') {
        $gen = 'Gen2'
    }
    elseif ($sku -match '-gen1|-g1|gen1|_gen1') {
        $gen = 'Gen1'
    }
    # Some publishers use different patterns
    elseif ($offer -match 'gen2' -or $publisher -match 'gen2') {
        $gen = 'Gen2'
    }

    # Determine Architecture from SKU name patterns
    $arch = 'x64'  # Default to x64
    if ($sku -match 'arm64|aarch64') {
        $arch = 'ARM64'
    }

    return @{
        Gen       = $gen
        Arch      = $arch
        Publisher = $publisher
        Offer     = $offer
        Sku       = $sku
        Valid     = $true
    }
}

function Get-SkuCapabilities {
    <#
    .SYNOPSIS
        Extracts VM Generation and Architecture capabilities from a SKU object.
    .DESCRIPTION
        Parses the SKU's Capabilities array to find HyperVGenerations and
        CpuArchitectureType values that indicate what the SKU supports.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$Sku
    )

    $capabilities = @{
        HyperVGenerations = 'V1'  # Default
        CpuArchitecture   = 'x64' # Default
    }

    if ($Sku.Capabilities) {
        foreach ($cap in $Sku.Capabilities) {
            switch ($cap.Name) {
                'HyperVGenerations' { $capabilities.HyperVGenerations = $cap.Value }
                'CpuArchitectureType' { $capabilities.CpuArchitecture = $cap.Value }
            }
        }
    }

    return $capabilities
}

function Test-ImageSkuCompatibility {
    <#
    .SYNOPSIS
        Tests if a VM SKU is compatible with the specified image requirements.
    .DESCRIPTION
        Compares the image's Generation and Architecture requirements against
        the SKU's capabilities to determine compatibility.
    .OUTPUTS
        Hashtable with Compatible (bool), Reason (string), Gen (string), Arch (string)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ImageReqs,

        [Parameter(Mandatory = $true)]
        [hashtable]$SkuCapabilities
    )

    $compatible = $true
    $reasons = @()

    # Check Generation compatibility
    $skuGens = $SkuCapabilities.HyperVGenerations -split ','
    $requiredGen = $ImageReqs.Gen
    if ($requiredGen -eq 'Gen2' -and $skuGens -notcontains 'V2') {
        $compatible = $false
        $reasons += "Gen2 required"
    }
    elseif ($requiredGen -eq 'Gen1' -and $skuGens -notcontains 'V1') {
        $compatible = $false
        $reasons += "Gen1 required"
    }

    # Check Architecture compatibility
    $skuArch = $SkuCapabilities.CpuArchitecture
    $requiredArch = $ImageReqs.Arch
    if ($requiredArch -eq 'ARM64' -and $skuArch -ne 'Arm64') {
        $compatible = $false
        $reasons += "ARM64 required"
    }
    elseif ($requiredArch -eq 'x64' -and $skuArch -eq 'Arm64') {
        $compatible = $false
        $reasons += "x64 required"
    }

    # Format the SKU's supported generations for display
    $genDisplay = ($skuGens | ForEach-Object { $_ -replace 'V', '' }) -join ','

    return @{
        Compatible = $compatible
        Reason     = if ($reasons.Count -gt 0) { $reasons -join '; ' } else { 'OK' }
        Gen        = $genDisplay
        Arch       = $skuArch
    }
}

function Get-AzVMPricing {
    <#
    .SYNOPSIS
        Fetches VM pricing from Azure Retail Prices API.
    .DESCRIPTION
        Retrieves pay-as-you-go Linux pricing for VM SKUs in a given region.
        Uses the public Azure Retail Prices API (no auth required).
        Implements caching to minimize API calls.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Region,

        [Parameter(Mandatory = $false)]
        [string[]]$SkuNames
    )

    $script:PricingCache = if (-not $script:PricingCache) { @{} } else { $script:PricingCache }

    # Get environment-specific endpoints (supports sovereign clouds)
    if (-not $script:AzureEndpoints) {
        $script:AzureEndpoints = Get-AzureEndpoints -EnvironmentName $script:TargetEnvironment
    }

    $armLocation = $Region.ToLower() -replace '\s', ''

    # Build filter for the API - get Linux consumption pricing
    $filter = "armRegionName eq '$armLocation' and priceType eq 'Consumption' and serviceName eq 'Virtual Machines'"

    $allPrices = @{}
    $apiUrl = "$($script:AzureEndpoints.PricingApiUrl)?`$filter=$([uri]::EscapeDataString($filter))"

    try {
        $nextLink = $apiUrl
        $pageCount = 0
        $maxPages = 20  # Fetch up to 20 pages (~20,000 price entries)

        while ($nextLink -and $pageCount -lt $maxPages) {
            $uri = $nextLink
            $response = Invoke-WithRetry -MaxRetries $MaxRetries -OperationName "Retail Pricing API (page $($pageCount + 1))" -ScriptBlock {
                Invoke-RestMethod -Uri $uri -Method Get -TimeoutSec 30
            }
            $pageCount++

            foreach ($item in $response.Items) {
                # Filter for Linux spot/regular pricing, skip Windows and Low Priority
                if ($item.productName -match 'Windows' -or
                    $item.skuName -match 'Low Priority' -or
                    $item.meterName -match 'Low Priority') {
                    continue
                }

                # Extract the VM size from armSkuName
                $vmSize = $item.armSkuName
                if (-not $vmSize) { continue }

                # Prefer regular (non-spot) pricing
                if (-not $allPrices[$vmSize] -or $item.skuName -notmatch 'Spot') {
                    $allPrices[$vmSize] = @{
                        Hourly   = [math]::Round($item.retailPrice, 4)
                        Monthly  = [math]::Round($item.retailPrice * $HoursPerMonth, 2)
                        Currency = $item.currencyCode
                        Meter    = $item.meterName
                    }
                }
            }

            $nextLink = $response.NextPageLink
        }

        $script:PricingCache[$armLocation] = $allPrices

        return $allPrices
    }
    catch {
        Write-Verbose "Failed to fetch pricing for region $Region`: $_"
        return @{}
    }
}

function Get-AzActualPricing {
    <#
    .SYNOPSIS
        Fetches actual negotiated pricing from Azure Cost Management API.
    .DESCRIPTION
        Retrieves your organization's actual negotiated rates including EA/MCA/CSP discounts.
        Requires Billing Reader or Cost Management Reader role on the billing scope.
    .NOTES
        This function queries the Azure Cost Management Query API to get actual meter rates.
        It requires appropriate RBAC permissions on the billing account/subscription.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SubscriptionId,

        [Parameter(Mandatory = $true)]
        [string]$Region,

        [Parameter(Mandatory = $false)]
        [string[]]$SkuNames
    )

    $script:ActualPricingCache = if (-not $script:ActualPricingCache) { @{} } else { $script:ActualPricingCache }
    $cacheKey = "$SubscriptionId-$Region"

    if ($script:ActualPricingCache.ContainsKey($cacheKey)) {
        return $script:ActualPricingCache[$cacheKey]
    }

    $armLocation = $Region.ToLower() -replace '\s', ''
    $allPrices = @{}

    try {
        # Get environment-specific endpoints (supports sovereign clouds)
        if (-not $script:AzureEndpoints) {
            $script:AzureEndpoints = Get-AzureEndpoints -EnvironmentName $script:TargetEnvironment
        }
        $armUrl = $script:AzureEndpoints.ResourceManagerUrl

        # Get access token for Azure Resource Manager (uses environment-specific URL)
        $token = (Get-AzAccessToken -ResourceUrl $armUrl).Token
        $headers = @{
            'Authorization' = "Bearer $token"
            'Content-Type'  = 'application/json'
        }

        # Query Cost Management API for price sheet data
        # Using the consumption price sheet endpoint with environment-specific ARM URL
        $apiUrl = "$armUrl/subscriptions/$SubscriptionId/providers/Microsoft.Consumption/pricesheets/default?api-version=2023-05-01&`$filter=contains(meterCategory,'Virtual Machines')"

        $response = Invoke-WithRetry -MaxRetries $MaxRetries -OperationName "Cost Management API" -ScriptBlock {
            Invoke-RestMethod -Uri $apiUrl -Method Get -Headers $headers -TimeoutSec 60
        }

        if ($response.properties.pricesheets) {
            foreach ($item in $response.properties.pricesheets) {
                # Match VM SKUs by meter name pattern
                if ($item.meterCategory -eq 'Virtual Machines' -and
                    $item.meterRegion -eq $armLocation -and
                    $item.meterSubCategory -notmatch 'Windows') {

                    # Extract VM size from meter details
                    $vmSize = $item.meterDetails.meterName -replace ' .*$', ''
                    if ($vmSize -match '^[A-Z]') {
                        $vmSize = "Standard_$vmSize"
                    }

                    if ($vmSize -and -not $allPrices.ContainsKey($vmSize)) {
                        $allPrices[$vmSize] = @{
                            Hourly       = [math]::Round($item.unitPrice, 4)
                            Monthly      = [math]::Round($item.unitPrice * $HoursPerMonth, 2)
                            Currency     = $item.currencyCode
                            Meter        = $item.meterName
                            IsNegotiated = $true
                        }
                    }
                }
            }
        }

        $script:ActualPricingCache[$cacheKey] = $allPrices
        return $allPrices
    }
    catch {
        $errorMsg = $_.Exception.Message
        if ($errorMsg -match '403|401|Forbidden|Unauthorized') {
            Write-Warning "Cost Management API access denied. Requires Billing Reader or Cost Management Reader role."
            Write-Warning "Falling back to retail pricing."
        }
        elseif ($errorMsg -match '404|NotFound') {
            Write-Warning "Cost Management price sheet not available for this subscription type."
            Write-Warning "This feature requires EA, MCA, or CSP billing. Falling back to retail pricing."
        }
        else {
            Write-Verbose "Failed to fetch actual pricing: $errorMsg"
        }
        return $null  # Return null to signal fallback needed
    }
}

#endregion Image Compatibility Functions
#region Initialize Azure Endpoints
$script:AzureEndpoints = Get-AzureEndpoints -EnvironmentName $script:TargetEnvironment

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
            exit 1
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
                    exit 1
                }

                $invalidNumbers = $selectedNumbers | Where-Object { $_ -lt 1 -or $_ -gt $locations.Count }
                if ($invalidNumbers.Count -gt 0) {
                    Write-Host "ERROR: Invalid selection(s): $($invalidNumbers -join ', '). Valid range is 1-$($locations.Count)" -ForegroundColor Red
                    exit 1
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
            exit 0
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
                    $offerResults = @()
                    $searchPublishers = @('Canonical', 'MicrosoftWindowsServer', 'RedHat', 'microsoft-dsvm', 'MicrosoftCBLMariner', 'Debian', 'SUSE', 'Oracle', 'OpenLogic')
                    foreach ($pub in $searchPublishers) {
                        try {
                            $offers = Get-AzVMImageOffer -Location $Regions[0] -PublisherName $pub -ErrorAction SilentlyContinue |
                            Where-Object { $_.Offer -match $searchTerm }
                            foreach ($offer in $offers) {
                                $offerResults += @{ Publisher = $pub; Offer = $offer.Offer }
                            }
                        }
                        catch { Write-Verbose "Image search failed for publisher '$pub': $_" }
                    }

                    if ($publishers -or $offerResults) {
                        $allResults = @()
                        $idx = 1

                        # Add publisher matches
                        if ($publishers) {
                            $publishers | Select-Object -First 5 | ForEach-Object {
                                $allResults += @{ Num = $idx; Type = "Publisher"; Name = $_.PublisherName; Publisher = $_.PublisherName; Offer = $null }
                                $idx++
                            }
                        }

                        # Add offer matches
                        $offerResults | Select-Object -First 5 | ForEach-Object {
                            $allResults += @{ Num = $idx; Type = "Offer"; Name = "$($_.Publisher) > $($_.Offer)"; Publisher = $_.Publisher; Offer = $_.Offer }
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
$script:ImageReqs = $null
if ($ImageURN) {
    $script:ImageReqs = Get-ImageRequirements -ImageURN $ImageURN
    if (-not $script:ImageReqs.Valid) {
        Write-Host "Warning: Could not parse image URN - $($script:ImageReqs.Error)" -ForegroundColor DarkYellow
        $script:ImageReqs = $null
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
# Plus spacing (2 chars between each of 7 columns = 12) = 113 base
# With pricing: +20 (two 10-char columns) = 133
$script:OutputWidth = if ($FetchPricing) { $OutputWidthWithPricing } else { $OutputWidthBase }
$script:OutputWidth = [Math]::Max($script:OutputWidth, $OutputWidthMin)
$script:OutputWidth = [Math]::Min($script:OutputWidth, $OutputWidthMax)

Write-Host "`n" -NoNewline
Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
Write-Host "GET-AZVMAVAILABILITY v$ScriptVersion" -ForegroundColor Green
Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
Write-Host "Subscriptions: $($TargetSubIds.Count) | Regions: $($Regions -join ', ')" -ForegroundColor Cyan
if ($SkuFilter -and $SkuFilter.Count -gt 0) {
    Write-Host "SKU Filter: $($SkuFilter -join ', ')" -ForegroundColor Yellow
}
Write-Host "Icons: $(if ($supportsUnicode) { 'Unicode' } else { 'ASCII' }) | Pricing: $(if ($FetchPricing) { 'Enabled' } else { 'Disabled' })" -ForegroundColor DarkGray
if ($script:ImageReqs) {
    Write-Host "Image: $ImageURN" -ForegroundColor Cyan
    Write-Host "Requirements: $($script:ImageReqs.Gen) | $($script:ImageReqs.Arch)" -ForegroundColor DarkCyan
}
Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
Write-Host ""

# Fetch pricing data if enabled
$script:regionPricing = @{}
$script:usingActualPricing = $false

if ($FetchPricing) {
    # Auto-detect: Try negotiated pricing first, fall back to retail
    Write-Host "Checking for negotiated pricing (EA/MCA/CSP)..." -ForegroundColor DarkGray

    $actualPricingSuccess = $true
    foreach ($regionCode in $Regions) {
        $actualPrices = Get-AzActualPricing -SubscriptionId $TargetSubIds[0] -Region $regionCode
        if ($actualPrices -and $actualPrices.Count -gt 0) {
            if ($actualPrices -is [array]) { $actualPrices = $actualPrices[0] }
            $script:regionPricing[$regionCode] = $actualPrices
        }
        else {
            $actualPricingSuccess = $false
            break
        }
    }

    if ($actualPricingSuccess -and $script:regionPricing.Count -gt 0) {
        $script:usingActualPricing = $true
        Write-Host "$($Icons.Check) Using negotiated pricing (EA/MCA/CSP rates detected)" -ForegroundColor Green
    }
    else {
        # Fall back to retail pricing
        Write-Host "No negotiated rates found, using retail pricing..." -ForegroundColor DarkGray
        $script:regionPricing = @{}
        foreach ($regionCode in $Regions) {
            $pricingResult = Get-AzVMPricing -Region $regionCode
            if ($pricingResult -is [array]) { $pricingResult = $pricingResult[0] }
            $script:regionPricing[$regionCode] = $pricingResult
        }
        Write-Host "$($Icons.Check) Using retail pricing (Linux pay-as-you-go)" -ForegroundColor DarkGray
    }
}

$allSubscriptionData = @()
$scanStartTime = Get-Date

foreach ($subId in $TargetSubIds) {
    $ctx = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $ctx -or $ctx.Subscription.Id -ne $subId) {
        Set-AzContext -SubscriptionId $subId | Out-Null
    }

    $subName = (Get-AzSubscription -SubscriptionId $subId | Select-Object -First 1).Name
    Write-Host "[$subName] Scanning $($Regions.Count) region(s)..." -ForegroundColor Yellow

    # Progress indicator for parallel scanning
    $regionCount = $Regions.Count
    Write-Progress -Activity "Scanning Azure Regions" -Status "Querying $regionCount region(s) in parallel..." -PercentComplete 0

    $regionData = $Regions | ForEach-Object -Parallel {
        $region = [string]$_
        $skuFilterCopy = $using:SkuFilter
        $maxRetries = $using:MaxRetries

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
    } -ThrottleLimit $ParallelThrottleLimit

    Write-Progress -Activity "Scanning Azure Regions" -Completed

    $scanElapsed = (Get-Date) - $scanStartTime
    Write-Host "[$subName] Scan complete in $([math]::Round($scanElapsed.TotalSeconds, 1))s" -ForegroundColor Green

    $allSubscriptionData += @{
        SubscriptionId   = $subId
        SubscriptionName = $subName
        RegionData       = $regionData
    }
}

#endregion Data Collection
#region Recommend Mode

if ($Recommend) {
    # Build target profile from scanned data — find the target SKU in any region
    $targetSku = $null
    $targetRegionStatus = @()

    foreach ($subData in $allSubscriptionData) {
        foreach ($data in $subData.RegionData) {
            $region = Get-SafeString $data.Region
            if ($data.Error) { continue }
            foreach ($sku in $data.Skus) {
                if ($sku.Name -eq $Recommend) {
                    $restrictions = Get-RestrictionDetails $sku
                    $targetRegionStatus += [pscustomobject]@{
                        Region   = [string]$region
                        Status   = $restrictions.Status
                        ZonesOK  = $restrictions.ZonesOK.Count
                    }
                    if (-not $targetSku) { $targetSku = $sku }
                }
            }
        }
    }

    if (-not $targetSku) {
        Write-Host "`nSKU '$Recommend' was not found in any scanned region." -ForegroundColor Red
        Write-Host "Check the SKU name and ensure the scanned regions support this SKU family." -ForegroundColor Yellow
        return
    }

    # Extract target profile
    $targetCaps = Get-SkuCapabilities -Sku $targetSku
    $targetProfile = @{
        Name         = $targetSku.Name
        vCPU         = [int](Get-CapValue $targetSku 'vCPUs')
        MemoryGB     = [int](Get-CapValue $targetSku 'MemoryGB')
        Family       = Get-SkuFamily $targetSku.Name
        Generation   = $targetCaps.HyperVGenerations
        Architecture = $targetCaps.CpuArchitecture
        PremiumIO    = (Get-CapValue $targetSku 'PremiumIO') -eq 'True'
    }

    Write-Host "`n" -NoNewline
    Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
    Write-Host "CAPACITY RECOMMENDER" -ForegroundColor Green
    Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
    Write-Host ""

    # SKU name breakdown — parse suffixes for educational display
    $targetPurpose = if ($FamilyInfo[$targetProfile.Family]) { $FamilyInfo[$targetProfile.Family].Purpose } else { 'Unknown' }
    $skuSuffixes = @()
    $skuBody = ($targetProfile.Name -replace '^Standard_', '') -replace '_v\d+$', ''
    if ($skuBody -match 'a(?![\d])') { $skuSuffixes += 'a = AMD processor' }
    if ($skuBody -match 'p(?![\d])') { $skuSuffixes += 'p = ARM processor (Ampere)' }
    if ($skuBody -match 'd(?![\d])') { $skuSuffixes += 'd = Local temp disk (NVMe)' }
    if ($skuBody -match 's$') { $skuSuffixes += 's = Premium storage capable' }
    if ($skuBody -match 'i(?![\d])') { $skuSuffixes += 'i = Isolated (dedicated host)' }
    if ($skuBody -match 'm(?![\d])') { $skuSuffixes += 'm = High memory per vCPU' }
    if ($skuBody -match 'l(?![\d])') { $skuSuffixes += 'l = Low memory per vCPU' }
    if ($skuBody -match 't(?![\d])') { $skuSuffixes += 't = Constrained vCPU' }
    $genMatch = if ($targetProfile.Name -match '_v(\d+)$') { "v$($Matches[1]) = Generation $($Matches[1])" } else { $null }

    Write-Host "TARGET: $($targetProfile.Name)" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  Name breakdown:" -ForegroundColor DarkGray
    Write-Host "    $($targetProfile.Family)        $targetPurpose (family)" -ForegroundColor DarkGray
    Write-Host "    $($targetProfile.vCPU)       vCPUs" -ForegroundColor DarkGray
    foreach ($suffix in $skuSuffixes) {
        Write-Host "    $suffix" -ForegroundColor DarkGray
    }
    if ($genMatch) {
        Write-Host "    $genMatch" -ForegroundColor DarkGray
    }
    Write-Host ""
    Write-Host "  $($targetProfile.vCPU) vCPU / $($targetProfile.MemoryGB) GiB / $($targetProfile.Architecture) / Premium IO: $(if ($targetProfile.PremiumIO) { 'Yes' } else { 'No' })" -ForegroundColor White
    Write-Host ""

    # Show target availability per region
    $availableRegions = @($targetRegionStatus | Where-Object { $_.Status -eq 'OK' })
    $unavailableRegions = @($targetRegionStatus | Where-Object { $_.Status -ne 'OK' })

    if ($availableRegions.Count -gt 0) {
        Write-Host "  $($Icons.Check) Available in: $($availableRegions.ForEach({ $_.Region }) -join ', ')" -ForegroundColor Green
    }
    if ($unavailableRegions.Count -gt 0) {
        foreach ($ur in $unavailableRegions) {
            Write-Host "  $($Icons.Error) $($ur.Region): $($ur.Status)" -ForegroundColor Red
        }
    }

    # Score all candidate SKUs across all regions
    $candidates = @()
    foreach ($subData in $allSubscriptionData) {
        foreach ($data in $subData.RegionData) {
            $region = Get-SafeString $data.Region
            if ($data.Error) { continue }
            foreach ($sku in $data.Skus) {
                if ($sku.Name -eq $Recommend) { continue }

                $restrictions = Get-RestrictionDetails $sku
                if ($restrictions.Status -eq 'RESTRICTED') { continue }

                $caps = Get-SkuCapabilities -Sku $sku
                $candidateProfile = @{
                    Name         = $sku.Name
                    vCPU         = [int](Get-CapValue $sku 'vCPUs')
                    MemoryGB     = [int](Get-CapValue $sku 'MemoryGB')
                    Family       = Get-SkuFamily $sku.Name
                    Generation   = $caps.HyperVGenerations
                    Architecture = $caps.CpuArchitecture
                    PremiumIO    = (Get-CapValue $sku 'PremiumIO') -eq 'True'
                }

                $simScore = Get-SkuSimilarityScore -Target $targetProfile -Candidate $candidateProfile

                # Look up pricing if available
                $priceHr = $null
                $priceMo = $null
                if ($FetchPricing -and $script:regionPricing[[string]$region]) {
                    $regionPriceData = $script:regionPricing[[string]$region]
                    if ($regionPriceData -is [array]) { $regionPriceData = $regionPriceData[0] }
                    $skuPricing = $regionPriceData[$sku.Name]
                    if ($skuPricing) {
                        $priceHr = $skuPricing.Hourly
                        $priceMo = $skuPricing.Monthly
                    }
                }

                $candidates += [pscustomobject]@{
                    SKU      = $sku.Name
                    Region   = [string]$region
                    vCPU     = $candidateProfile.vCPU
                    MemGiB   = $candidateProfile.MemoryGB
                    Family   = $candidateProfile.Family
                    Purpose  = if ($FamilyInfo[$candidateProfile.Family]) { $FamilyInfo[$candidateProfile.Family].Purpose } else { '' }
                    Gen      = $caps.HyperVGenerations -replace 'V', '' -replace ',', ','
                    Arch     = $candidateProfile.Architecture
                    Score    = $simScore
                    Capacity = $restrictions.Status
                    ZonesOK  = $restrictions.ZonesOK.Count
                    PriceHr  = $priceHr
                    PriceMo  = $priceMo
                }
            }
        }
    }

    # Apply minimum spec filters and separate smaller options for callout
    $belowMinSpec = @()
    $filtered = $candidates
    if ($MinvCPU) {
        $belowMinSpec += @($filtered | Where-Object { $_.vCPU -lt $MinvCPU -and $_.Capacity -eq 'OK' })
        $filtered = @($filtered | Where-Object { $_.vCPU -ge $MinvCPU })
    }
    if ($MinMemoryGB) {
        $belowMinSpec += @($filtered | Where-Object { $_.MemGiB -lt $MinMemoryGB -and $_.Capacity -eq 'OK' })
        $filtered = @($filtered | Where-Object { $_.MemGiB -ge $MinMemoryGB })
    }

    # Rank: highest score first, break ties by capacity status and zone count
    $ranked = $filtered |
        Sort-Object @{Expression = 'Score'; Descending = $true},
                    @{Expression = { if ($_.Capacity -eq 'OK') { 0 } elseif ($_.Capacity -eq 'LIMITED') { 1 } else { 2 } }},
                    @{Expression = 'ZonesOK'; Descending = $true} |
        Group-Object SKU |
        ForEach-Object { $_.Group | Select-Object -First 1 } |
        Select-Object -First $TopN

    if ($JsonOutput) {
        $jsonResult = @{
            target              = $targetProfile
            targetAvailability  = @($targetRegionStatus)
            recommendations     = @($ranked | ForEach-Object {
                @{
                    rank     = 0
                    sku      = $_.SKU
                    region   = $_.Region
                    vCPU     = $_.vCPU
                    memGiB   = $_.MemGiB
                    family   = $_.Family
                    purpose  = $_.Purpose
                    gen      = $_.Gen
                    arch     = $_.Arch
                    score    = $_.Score
                    capacity = $_.Capacity
                    zonesOK  = $_.ZonesOK
                    priceHr  = $_.PriceHr
                    priceMo  = $_.PriceMo
                }
            })
        }
        # Number the ranks
        for ($i = 0; $i -lt $jsonResult.recommendations.Count; $i++) {
            $jsonResult.recommendations[$i].rank = $i + 1
        }
        $jsonResult | ConvertTo-Json -Depth 5
        return
    }

    # Console output — adjust columns based on whether pricing is available
    if ($ranked.Count -eq 0) {
        Write-Host "`nNo alternatives found in the scanned regions." -ForegroundColor Yellow
        return
    }

    Write-Host "`nRECOMMENDED ALTERNATIVES (top $($ranked.Count), sorted by similarity):" -ForegroundColor Green
    Write-Host ""

    if ($FetchPricing) {
        $headerFmt = " {0,-3} {1,-28} {2,-12} {3,-5} {4,-7} {5,-6} {6,-20} {7,-12} {8,-5} {9,-8} {10,-8}"
        Write-Host ($headerFmt -f '#', 'SKU', 'Region', 'vCPU', 'Mem(GB)', 'Score', 'Type', 'Capacity', 'Zones', '$/Hr', '$/Mo') -ForegroundColor White
        Write-Host (" " + ("-" * 118)) -ForegroundColor DarkGray
    }
    else {
        $headerFmt = " {0,-3} {1,-28} {2,-12} {3,-5} {4,-7} {5,-6} {6,-20} {7,-12} {8,-5}"
        Write-Host ($headerFmt -f '#', 'SKU', 'Region', 'vCPU', 'Mem(GB)', 'Score', 'Type', 'Capacity', 'Zones') -ForegroundColor White
        Write-Host (" " + ("-" * 102)) -ForegroundColor DarkGray
    }

    $rank = 1
    foreach ($r in $ranked) {
        $rowColor = switch ($r.Capacity) {
            'OK'      { 'Green' }
            'LIMITED' { 'Yellow' }
            default   { 'DarkYellow' }
        }
        if ($FetchPricing) {
            $hrStr = if ($null -ne $r.PriceHr) { '$' + $r.PriceHr.ToString('0.00') } else { '-' }
            $moStr = if ($null -ne $r.PriceMo) { '$' + $r.PriceMo.ToString('0') } else { '-' }
            $line = $headerFmt -f $rank, $r.SKU, $r.Region, $r.vCPU, $r.MemGiB, "$($r.Score)%", $r.Purpose, $r.Capacity, $r.ZonesOK, $hrStr, $moStr
        }
        else {
            $line = $headerFmt -f $rank, $r.SKU, $r.Region, $r.vCPU, $r.MemGiB, "$($r.Score)%", $r.Purpose, $r.Capacity, $r.ZonesOK
        }
        Write-Host $line -ForegroundColor $rowColor
        $rank++
    }

    # "Consider smaller" callout — only when filtered results lack OK capacity but smaller SKUs have it
    $rankedHasOK = ($ranked | Where-Object { $_.Capacity -eq 'OK' }).Count -gt 0
    if (-not $rankedHasOK -and $belowMinSpec.Count -gt 0) {
        $smallerOK = $belowMinSpec |
            Sort-Object @{Expression = 'Score'; Descending = $true} |
            Group-Object SKU |
            ForEach-Object { $_.Group | Select-Object -First 1 } |
            Select-Object -First 3
        if ($smallerOK.Count -gt 0) {
            Write-Host ""
            Write-Host "  $($Icons.Warning) CONSIDER SMALLER (better availability, if your workload supports it):" -ForegroundColor Yellow
            foreach ($s in $smallerOK) {
                Write-Host "    $($s.SKU) ($($s.vCPU) vCPU / $($s.MemGiB) GiB) — $($s.Capacity) in $($s.Region)" -ForegroundColor DarkYellow
            }
        }
    }

    Write-Host ""
    Write-Host "STATUS KEY:" -ForegroundColor DarkGray
    Write-Host "  OK       = Ready to deploy. No restrictions." -ForegroundColor Green
    Write-Host "  CONSTRAINED = Azure is low on hardware. Try a different zone or wait." -ForegroundColor Yellow
    Write-Host "  LIMITED  = Your subscription can't use this. Request access via support ticket." -ForegroundColor Yellow
    Write-Host "  PARTIAL  = Some zones work, others are blocked. No zone redundancy." -ForegroundColor Yellow
    Write-Host "  BLOCKED  = Cannot deploy. Pick a different region or SKU." -ForegroundColor Red
    Write-Host ""
    return
}

#endregion Recommend Mode
#region Process Results

$allFamilyStats = @{}
$familyDetails = @()
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

        $rows = @()
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
            $quotaInfo = Get-QuotaAvailable -Quotas $data.Quotas -FamilyName "Standard $family*"

            # Get pricing - find smallest SKU with pricing available
            $priceHrStr = '-'
            $priceMoStr = '-'
            # Get pricing data - handle potential array wrapping
            $regionPricingData = $script:regionPricing[$region]
            if ($regionPricingData -is [array]) { $regionPricingData = $regionPricingData[0] }
            if ($FetchPricing -and $regionPricingData -and $regionPricingData.Count -gt 1) {
                $sortedSkus = $skus | ForEach-Object {
                    @{ Sku = $_; vCPU = [int](Get-CapValue $_ 'vCPUs') }
                } | Sort-Object vCPU

                foreach ($skuInfo in $sortedSkus) {
                    $skuName = $skuInfo.Sku.Name
                    $pricing = $regionPricingData[$skuName]
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
                Quota   = if ($quotaInfo.Available) { $quotaInfo.Available } else { '?' }
            }

            if ($FetchPricing) {
                $row | Add-Member -NotePropertyName '$/Hr' -NotePropertyValue $priceHrStr
                $row | Add-Member -NotePropertyName '$/Mo' -NotePropertyValue $priceMoStr
            }

            $rows += $row

            # Track for drill-down
            if (-not $familySkuIndex.ContainsKey($family)) { $familySkuIndex[$family] = @{} }

            foreach ($sku in $skus) {
                $familySkuIndex[$family][$sku.Name] = $true
                $skuRestrictions = Get-RestrictionDetails $sku

                # Get individual SKU pricing
                $skuPriceHr = '-'
                $skuPriceMo = '-'
                if ($FetchPricing -and $regionPricingData) {
                    $skuPricing = $regionPricingData[$sku.Name]
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
                if ($script:ImageReqs) {
                    $compatResult = Test-ImageSkuCompatibility -ImageReqs $script:ImageReqs -SkuCapabilities $skuCaps
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
                }

                if ($FetchPricing) {
                    $detailObj | Add-Member -NotePropertyName '$/Hr' -NotePropertyValue $skuPriceHr
                    $detailObj | Add-Member -NotePropertyName '$/Mo' -NotePropertyValue $skuPriceMo
                }

                $familyDetails += $detailObj
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

#endregion Process Results
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
                exit 1
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
                        exit 1
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
            if ($script:ImageReqs) {
                Write-Host "Image: $ImageURN (Requires: $($script:ImageReqs.Gen) | $($script:ImageReqs.Arch))" -ForegroundColor DarkCyan
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
                    if ($FetchPricing) {
                        $dColWidths['$/Hr'] = 8
                        $dColWidths['$/Mo'] = 8
                    }
                    if ($script:ImageReqs) {
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
            $icon = Get-StatusIcon $status
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
