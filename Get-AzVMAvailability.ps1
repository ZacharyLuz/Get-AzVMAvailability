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
    Include estimated hourly pricing for VM SKUs from Azure Retail Prices API.
    Adds ~5-10 seconds to execution time. Without -NoPrompt, prompts interactively.

.PARAMETER UseActualPricing
    Use actual negotiated pricing from Cost Management API instead of retail prices.
    Requires Billing Reader or Cost Management Reader role on the subscription.

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

.NOTES
    Name:           Get-AzVMAvailability
    Author:         Zachary Luz
    Company:        Microsoft
    Created:        2026-01-21
    Version:        1.4.0
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

    [Parameter(Mandatory = $false, HelpMessage = "Show estimated hourly pricing for SKUs")]
    [switch]$ShowPricing,

    [Parameter(Mandatory = $false, HelpMessage = "Use actual pricing from Cost Management API (requires billing permissions)")]
    [switch]$UseActualPricing,

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
    [switch]$UseAsciiIcons
)

$ErrorActionPreference = 'Continue'
$ProgressPreference = 'SilentlyContinue'  # Suppress progress bars for faster execution

# === Configuration ==================================================
# Script metadata
$ScriptVersion = "1.5.0"

# Map parameters to internal variables
$TargetSubIds = $SubscriptionId
$Regions = $Region
$EnableDrill = $EnableDrillDown.IsPresent
$SelectedFamilyFilter = $FamilyFilter
$SelectedSkuFilter = @{}

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
$Icons = if ($supportsUnicode) {
    @{
        OK       = '✓ OK'
        CAPACITY = '⚠ CAPACITY'
        LIMITED  = '⚠ LIMITED'
        PARTIAL  = '⚡ PARTIAL'
        BLOCKED  = '✗ BLOCKED'
        UNKNOWN  = '? UNKNOWN'
        Check    = '✓'
        Warning  = '⚠'
        Error    = '✗'
    }
}
else {
    @{
        OK       = '[+] OK'
        CAPACITY = '[!] CAPACITY'
        LIMITED  = '[!] LIMITED'
        PARTIAL  = '[~] PARTIAL'
        BLOCKED  = '[-] BLOCKED'
        UNKNOWN  = '[?] UNKNOWN'
        Check    = '[+]'
        Warning  = '[!]'
        Error    = '[-]'
    }
}

if ($AutoExport -and -not $ExportPath) {
    $ExportPath = $defaultExportPath
}

# === Helper Functions ===============================================

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
    .OUTPUTS
        Hashtable with ResourceManagerUrl, PricingApiUrl, and EnvironmentName.
    .EXAMPLE
        $endpoints = Get-AzureEndpoints
        $endpoints.PricingApiUrl  # Returns https://prices.azure.com for Commercial
    #>
    param(
        [Parameter(Mandatory = $false)]
        [object]$AzEnvironment  # For testing - pass a mock environment object
    )

    # Get the current Azure environment if not provided (for testing)
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
    # Extracts a specific capability value (like vCPUs, MemoryGB) from a SKU object
    param([object]$Sku, [string]$Name)
    $cap = $Sku.Capabilities | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if ($cap) { return $cap.Value }
    return $null
}

function Get-SkuFamily {
    # Extracts the VM family prefix from a SKU name (e.g., Standard_D2s_v3 -> D)
    param([string]$SkuName)
    if ($SkuName -match 'Standard_([A-Z]+)\d') {
        return $matches[1]
    }
    return 'Unknown'
}

function Get-RestrictionReason {
    # Gets the primary restriction reason for a SKU (e.g., NotAvailableForSubscription)
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
    # Formats zone availability into a human-readable string
    param([array]$OK, [array]$Limited, [array]$Restricted)
    $parts = @()
    if ($OK.Count -gt 0) { $parts += "✓ Zones $($OK -join ',')" }
    if ($Limited.Count -gt 0) { $parts += "⚠ Zones $($Limited -join ',')" }
    if ($Restricted.Count -gt 0) { $parts += "✗ Zones $($Restricted -join ',')" }
    if ($parts.Count -eq 0) { return 'Non-zonal' }  # No zone info = regional deployment
    return $parts -join ' | '
}

function Get-SkuSizeAvailability {
    # Checks if any SKU sizes in a family are available (unrestricted or capacity-constrained)
    param([array]$Skus)
    foreach ($sku in $Skus) {
        $details = Get-RestrictionDetails $sku
        if ($details.Status -eq 'OK' -or $details.Status -eq 'CAPACITY-CONSTRAINED') {
            return $true
        }
    }
    return $false
}

function Get-QuotaAvailable {
    # Calculates available vCPU quota for a VM family in the subscription
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
    # Returns the appropriate status icon (Unicode or ASCII) based on capacity status
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
    # Checks if the ImportExcel module is available for styled XLSX export
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

# === Image Compatibility Functions ==================================

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
        $script:AzureEndpoints = Get-AzureEndpoints
    }

    # Azure region name to ARM location mapping
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
            $response = Invoke-RestMethod -Uri $nextLink -Method Get -TimeoutSec 30
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
                        Monthly  = [math]::Round($item.retailPrice * 730, 2)  # 730 hours/month avg
                        Currency = $item.currencyCode
                        Meter    = $item.meterName
                    }
                }
            }

            $nextLink = $response.NextPageLink
        }

        # Cache the results
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
            $script:AzureEndpoints = Get-AzureEndpoints
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

        $response = Invoke-RestMethod -Uri $apiUrl -Method Get -Headers $headers -TimeoutSec 60

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
                            Monthly      = [math]::Round($item.unitPrice * 730, 2)
                            Currency     = $item.currencyCode
                            Meter        = $item.meterName
                            IsNegotiated = $true
                        }
                    }
                }
            }
        }

        # Cache the results
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

function Format-FixedWidthTable {
    <#
    .SYNOPSIS
        Formats data as a fixed-width aligned table with customizable column widths.
    .DESCRIPTION
        Outputs a consistently aligned table regardless of data length.
        Truncates or pads values to fit specified widths.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [array]$Data,

        [Parameter(Mandatory = $true)]
        [hashtable]$ColumnWidths,  # @{ ColumnName = Width }

        [Parameter(Mandatory = $false)]
        [string]$HeaderColor = 'Cyan',

        [Parameter(Mandatory = $false)]
        [hashtable]$RowColors  # @{ ColumnName = { param($value) return 'Green' } }
    )

    if (-not $Data -or $Data.Count -eq 0) { return }

    # Get column names in order (from first row or ColumnWidths keys)
    $columns = @($ColumnWidths.Keys)

    # Build header
    $headerParts = @()
    foreach ($col in $columns) {
        $width = $ColumnWidths[$col]
        $headerParts += $col.PadRight($width).Substring(0, [Math]::Min($width, $col.Length + $width))
    }
    $headerLine = ($headerParts -join '  ')
    Write-Host $headerLine -ForegroundColor $HeaderColor
    Write-Host ('-' * $headerLine.Length) -ForegroundColor Gray

    # Build data rows
    foreach ($row in $Data) {
        $rowParts = @()
        $rowColor = 'White'

        foreach ($col in $columns) {
            $width = $ColumnWidths[$col]
            $value = if ($row.$col -ne $null) { "$($row.$col)" } else { '' }

            # Truncate if too long
            if ($value.Length -gt $width) {
                $value = $value.Substring(0, $width - 1) + '…'
            }

            $rowParts += $value.PadRight($width)

            # Determine row color from first matching color rule
            if ($RowColors -and $RowColors[$col]) {
                $colorResult = & $RowColors[$col] $row.$col
                if ($colorResult) { $rowColor = $colorResult }
            }
        }

        Write-Host ($rowParts -join '  ') -ForegroundColor $rowColor
    }
}

# === Interactive Prompts ============================================
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
        Write-Host ("=" * 175) -ForegroundColor Gray
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
                        catch { }
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

# === Data Collection ================================================

Write-Host "`n" -NoNewline
Write-Host ("=" * 175) -ForegroundColor Gray
Write-Host "GET-AZVMAVAILABILITY v$ScriptVersion" -ForegroundColor Green
Write-Host ("=" * 175) -ForegroundColor Gray
Write-Host "Subscriptions: $($TargetSubIds.Count) | Regions: $($Regions -join ', ')" -ForegroundColor Cyan
if ($SkuFilter -and $SkuFilter.Count -gt 0) {
    Write-Host "SKU Filter: $($SkuFilter -join ', ')" -ForegroundColor Yellow
}
Write-Host "Icons: $(if ($supportsUnicode) { 'Unicode' } else { 'ASCII' }) | Pricing: $(if ($FetchPricing) { 'Enabled' } else { 'Disabled' })" -ForegroundColor DarkGray
if ($script:ImageReqs) {
    Write-Host "Image: $ImageURN" -ForegroundColor Cyan
    Write-Host "Requirements: $($script:ImageReqs.Gen) | $($script:ImageReqs.Arch)" -ForegroundColor DarkCyan
}
Write-Host ""

# Fetch pricing data if enabled
$script:regionPricing = @{}
$script:usingActualPricing = $false

if ($FetchPricing) {
    if ($UseActualPricing) {
        Write-Host "Fetching actual pricing from Cost Management API..." -ForegroundColor DarkGray
        Write-Host "  (Requires Billing Reader or Cost Management Reader role)" -ForegroundColor DarkGray

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
            Write-Host "Actual pricing loaded for $($Regions.Count) region(s)" -ForegroundColor Green
            Write-Host "Note: Prices reflect your negotiated EA/MCA/CSP rates." -ForegroundColor DarkGreen
        }
        else {
            Write-Host "Falling back to retail pricing..." -ForegroundColor DarkYellow
            $script:regionPricing = @{}
        }
    }

    # Fall back to retail pricing if needed
    if (-not $script:usingActualPricing) {
        Write-Host "Fetching retail pricing data..." -ForegroundColor DarkGray
        foreach ($regionCode in $Regions) {
            $pricingResult = Get-AzVMPricing -Region $regionCode
            # Handle potential array wrapping from function return
            if ($pricingResult -is [array]) { $pricingResult = $pricingResult[0] }
            $script:regionPricing[$regionCode] = $pricingResult
        }
        Write-Host "Pricing data loaded for $($Regions.Count) region(s)" -ForegroundColor DarkGray
        Write-Host "Note: Prices shown are Linux pay-as-you-go retail rates. EA/MCA/Reserved discounts not included." -ForegroundColor DarkYellow
    }
}

$allSubscriptionData = @()

foreach ($subId in $TargetSubIds) {
    $ctx = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $ctx -or $ctx.Subscription.Id -ne $subId) {
        Set-AzContext -SubscriptionId $subId | Out-Null
    }

    $subName = (Get-AzSubscription -SubscriptionId $subId | Select-Object -First 1).Name
    Write-Host "[$subName] Scanning $($Regions.Count) region(s)..." -ForegroundColor Yellow

    $regionData = $Regions | ForEach-Object -Parallel {
        $region = [string]$_
        $skuFilterCopy = $using:SkuFilter  # Pass filter to parallel block
        try {
            $allSkus = Get-AzComputeResourceSku -Location $region -ErrorAction Stop |
            Where-Object { $_.ResourceType -eq 'virtualMachines' }

            # Apply SKU filter if specified
            if ($skuFilterCopy -and $skuFilterCopy.Count -gt 0) {
                $allSkus = $allSkus | Where-Object {
                    $skuName = $_.Name
                    $matches = $false
                    foreach ($pattern in $skuFilterCopy) {
                        $regexPattern = '^' + [regex]::Escape($pattern).Replace('\*', '.*').Replace('\?', '.') + '$'
                        if ($skuName -match $regexPattern) {
                            $matches = $true
                            break
                        }
                    }
                    $matches
                }
            }

            $quotas = Get-AzVMUsage -Location $region -ErrorAction Stop
            @{ Region = [string]$region; Skus = $allSkus; Quotas = $quotas; Error = $null }
        }
        catch {
            @{ Region = [string]$region; Skus = @(); Quotas = @(); Error = $_.Exception.Message }
        }
    } -ThrottleLimit 4

    $allSubscriptionData += @{
        SubscriptionId   = $subId
        SubscriptionName = $subName
        RegionData       = $regionData
    }
}

# === Process Results ================================================

$allFamilyStats = @{}
$familyDetails = @()
$familySkuIndex = @{}

foreach ($subscriptionData in $allSubscriptionData) {
    $subName = $subscriptionData.SubscriptionName

    foreach ($data in $subscriptionData.RegionData) {
        $region = Get-SafeString $data.Region

        Write-Host "`n" -NoNewline
        Write-Host ("=" * 175) -ForegroundColor Gray
        Write-Host "REGION: $region" -ForegroundColor Yellow
        Write-Host ("=" * 175) -ForegroundColor Gray

        if ($data.Error) {
            Write-Host "ERROR: $($data.Error)" -ForegroundColor Red
            continue
        }

        # Group SKUs by family
        $familyGroups = @{}
        foreach ($sku in $data.Skus) {
            $family = Get-SkuFamily $sku.Name
            if (-not $familyGroups[$family]) { $familyGroups[$family] = @() }
            $familyGroups[$family] += $sku
        }

        # Display quota summary
        Write-Host "`nQUOTA SUMMARY:" -ForegroundColor Cyan
        $quotaLines = $data.Quotas | Where-Object {
            $_.Name.Value -match 'Total Regional vCPUs|Family vCPUs'
        } | Select-Object @{n = 'Family'; e = { $_.Name.LocalizedValue } },
        @{n = 'Used'; e = { $_.CurrentValue } },
        @{n = 'Limit'; e = { $_.Limit } },
        @{n = 'Available'; e = { $_.Limit - $_.CurrentValue } }

        if ($quotaLines) {
            # Fixed-width quota table (175 chars total)
            $qColWidths = [ordered]@{ Family = 70; Used = 20; Limit = 20; Available = 25 }
            $qHeader = foreach ($c in $qColWidths.Keys) { $c.PadRight($qColWidths[$c]) }
            Write-Host ($qHeader -join '  ') -ForegroundColor Cyan
            Write-Host ('-' * 175) -ForegroundColor Gray
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

        # Display SKU families table
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
                    QuotaAvail   = if ($quotaInfo.Available) { $quotaInfo.Available } else { '?' }
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

            # Header
            $headerParts = foreach ($col in $colWidths.Keys) {
                $col.PadRight($colWidths[$col])
            }
            Write-Host ($headerParts -join '  ') -ForegroundColor Cyan
            Write-Host ('-' * 175) -ForegroundColor Gray

            # Data rows
            foreach ($row in $rows) {
                $rowParts = foreach ($col in $colWidths.Keys) {
                    $val = if ($row.$col -ne $null) { "$($row.$col)" } else { '' }
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

# === Drill-Down (if enabled) ========================================

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
        # Don't populate SelectedSkuFilter - this means all SKUs will be included
    }
    else {
        # Interactive mode
        Write-Host "`n" -NoNewline
        Write-Host ("=" * 175) -ForegroundColor Gray
        Write-Host "DRILL-DOWN: SELECT FAMILIES" -ForegroundColor Green
        Write-Host ("=" * 175) -ForegroundColor Gray

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
        Write-Host ""
        Write-Host ("=" * 175) -ForegroundColor Gray
        Write-Host "FAMILY / SKU DRILL-DOWN RESULTS" -ForegroundColor Green
        Write-Host ("=" * 175) -ForegroundColor Gray

        foreach ($fam in $SelectedFamilyFilter) {
            Write-Host "`nFamily: $fam" -ForegroundColor Cyan

            # Show image requirements if checking compatibility
            if ($script:ImageReqs) {
                Write-Host "Image: $ImageURN (Requires: $($script:ImageReqs.Gen) | $($script:ImageReqs.Arch))" -ForegroundColor DarkCyan
            }
            Write-Host ("-" * 185) -ForegroundColor Gray

            $skuFilter = $null
            if ($SelectedSkuFilter.ContainsKey($fam)) { $skuFilter = $SelectedSkuFilter[$fam] }

            $detailRows = $familyDetails | Where-Object {
                $_.Family -eq $fam -and (
                    -not $skuFilter -or $skuFilter -contains $_.SKU
                )
            }

            if ($detailRows.Count -gt 0) {
                $sortedRows = $detailRows | Sort-Object Region, SKU
                # Fixed-width drill-down table (185 chars to accommodate Gen/Arch/Img columns)
                $dColWidths = [ordered]@{ Region = 20; SKU = 26; vCPU = 5; MemGiB = 6; Gen = 6; Arch = 6; ZoneStatus = 26; Capacity = 20 }
                if ($FetchPricing) {
                    $dColWidths['$/Hr'] = 8
                    $dColWidths['$/Mo'] = 8
                }
                if ($script:ImageReqs) {
                    $dColWidths['Img'] = 4
                }
                $dColWidths['Reason'] = 28

                $dHeader = foreach ($c in $dColWidths.Keys) { $c.PadRight($dColWidths[$c]) }
                Write-Host ($dHeader -join '  ') -ForegroundColor Cyan
                Write-Host ('-' * 185) -ForegroundColor Gray
                foreach ($dr in $sortedRows) {
                    $dRow = foreach ($c in $dColWidths.Keys) {
                        # Map column names to object properties
                        $propName = switch ($c) {
                            'Img' { 'ImgCompat' }
                            default { $c }
                        }
                        $v = if ($dr.$propName -ne $null) { "$($dr.$propName)" } else { '' }
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
            else {
                Write-Host "No matching SKUs found for selection." -ForegroundColor DarkYellow
            }
        }
    }
}

# === Multi-Region Matrix ============================================

Write-Host "`n" -NoNewline
Write-Host ("=" * 175) -ForegroundColor Gray
Write-Host "MULTI-REGION CAPACITY MATRIX" -ForegroundColor Green
Write-Host ("=" * 175) -ForegroundColor Gray
Write-Host ""

# Build unique region list
$allRegions = @()
foreach ($family in $allFamilyStats.Keys) {
    foreach ($regionKey in $allFamilyStats[$family].Regions.Keys) {
        $regionStr = Get-SafeString $regionKey
        if ($allRegions -notcontains $regionStr) { $allRegions += $regionStr }
    }
}
$allRegions = @($allRegions | Sort-Object)

# Header
$headerLine = "Family".PadRight(10)
foreach ($r in $allRegions) { $headerLine += " | " + $r.PadRight(15) }
Write-Host $headerLine -ForegroundColor Cyan
Write-Host ("-" * 175) -ForegroundColor Gray

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
            $line += " | " + $icon.PadRight(15)
        }
        else {
            $line += " | " + "-".PadRight(15)
        }
    }

    $color = switch ($bestStatus) { 'OK' { 'Green' }; 'MIXED' { 'Yellow' }; default { 'Gray' } }
    Write-Host $line -ForegroundColor $color
}

Write-Host ""
Write-Host "LEGEND:" -ForegroundColor Cyan
Write-Host ("  $($Icons.OK)".PadRight(20) + "Full capacity available") -ForegroundColor Green
Write-Host ("  $($Icons.CAPACITY)".PadRight(20) + "Zone-level constraints") -ForegroundColor Yellow
Write-Host ("  $($Icons.LIMITED)".PadRight(20) + "Subscription restricted") -ForegroundColor Yellow
Write-Host ("  $($Icons.PARTIAL)".PadRight(20) + "Mixed zone availability") -ForegroundColor Yellow
Write-Host ("  $($Icons.BLOCKED)".PadRight(20) + "Not available") -ForegroundColor Red

# === Deployment Recommendations =====================================

Write-Host "`n" -NoNewline
Write-Host ("=" * 175) -ForegroundColor Gray
Write-Host "DEPLOYMENT RECOMMENDATIONS" -ForegroundColor Green
Write-Host ("=" * 175) -ForegroundColor Gray
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

# === Detailed Breakdown =============================================

Write-Host "`n" -NoNewline
Write-Host ("=" * 175) -ForegroundColor Gray
Write-Host "DETAILED CROSS-REGION BREAKDOWN" -ForegroundColor Green
Write-Host ("=" * 175) -ForegroundColor Gray
Write-Host ""

# Fixed-width formatted table (175 chars)
$colFamily = 14
$colFullCap = 55

$headerFmt = "{0,-$colFamily} {1,-$colFullCap} {2}" -f "Family", "Available Regions", "Constrained Regions"
Write-Host $headerFmt -ForegroundColor Cyan
Write-Host ("-" * 175) -ForegroundColor Gray

$summaryRowsForExport = @()
foreach ($family in ($allFamilyStats.Keys | Sort-Object)) {
    $stats = $allFamilyStats[$family]
    $regionsOK = @()
    $regionsConstrained = @()

    foreach ($regionKey in ($stats.Regions.Keys | Sort-Object)) {
        $region = Get-SafeString $regionKey
        $regionStat = $stats.Regions[$region]
        if ($regionStat) {
            if ($regionStat.Capacity -eq 'OK') {
                $regionsOK += $region
            }
            elseif ($regionStat.Capacity -match 'LIMITED|CAPACITY-CONSTRAINED|PARTIAL') {
                $regionsConstrained += "$region ($($regionStat.Capacity))"
            }
        }
    }

    $fullCapStr = if ($regionsOK.Count -gt 0) { $regionsOK -join ', ' } else { '(none)' }
    $constrainedStr = if ($regionsConstrained.Count -gt 0) { $regionsConstrained -join ' | ' } else { '(none)' }

    $line = "{0,-$colFamily} {1,-$colFullCap} {2}" -f $family, $fullCapStr, $constrainedStr
    $color = if ($regionsOK.Count -gt 0) { 'Green' } elseif ($regionsConstrained.Count -gt 0) { 'Yellow' } else { 'Gray' }
    Write-Host $line -ForegroundColor $color

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

# === Completion =====================================================

Write-Host "`n" -NoNewline
Write-Host ("=" * 175) -ForegroundColor Gray
Write-Host "SCAN COMPLETE" -ForegroundColor Green
Write-Host "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor DarkGray
Write-Host ("=" * 175) -ForegroundColor Gray

# === Export =========================================================

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

            # === Summary Sheet ===
            $excel = $summaryRowsForExport | Export-Excel -Path $xlsxFile -WorksheetName "Summary" -AutoSize -FreezeTopRow -PassThru

            $ws = $excel.Workbook.Worksheets["Summary"]
            $lastRow = $ws.Dimension.End.Row
            $lastCol = $ws.Dimension.End.Column

            # Style header row
            $headerRange = $ws.Cells["A1:$([char](64 + $lastCol))1"]
            $headerRange.Style.Font.Bold = $true
            $headerRange.Style.Font.Color.SetColor([System.Drawing.Color]::White)
            $headerRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
            $headerRange.Style.Fill.BackgroundColor.SetColor($headerBlue)
            $headerRange.Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center

            # Add alternating row colors
            for ($row = 2; $row -le $lastRow; $row++) {
                if ($row % 2 -eq 0) {
                    $rowRange = $ws.Cells["A$row`:$([char](64 + $lastCol))$row"]
                    $rowRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                    $rowRange.Style.Fill.BackgroundColor.SetColor($lightGray)
                }
            }

            # Apply conditional formatting to status columns (columns D onwards)
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

            # Add borders
            $dataRange = $ws.Cells["A1:$([char](64 + $lastCol))$lastRow"]
            $dataRange.Style.Border.Top.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Bottom.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Left.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Right.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin

            # Center numeric columns
            $ws.Cells["B2:C$lastRow"].Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center

            Close-ExcelPackage $excel

            # === Details Sheet ===
            $excel = $familyDetails | Export-Excel -Path $xlsxFile -WorksheetName "Details" -AutoSize -FreezeTopRow -Append -PassThru

            $ws = $excel.Workbook.Worksheets["Details"]
            $lastRow = $ws.Dimension.End.Row
            $lastCol = $ws.Dimension.End.Column

            # Style header row
            $headerRange = $ws.Cells["A1:$([char](64 + $lastCol))1"]
            $headerRange.Style.Font.Bold = $true
            $headerRange.Style.Font.Color.SetColor([System.Drawing.Color]::White)
            $headerRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
            $headerRange.Style.Fill.BackgroundColor.SetColor($headerBlue)
            $headerRange.Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center

            # Find Capacity column (usually column H or 8)
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

                # RESTRICTED - Red
                Add-ConditionalFormatting -Worksheet $ws -Range $capacityRange -RuleType Equal -ConditionValue "RESTRICTED" -BackgroundColor $redFill -ForegroundColor $redText
            }

            # Add borders to details
            $dataRange = $ws.Cells["A1:$([char](64 + $lastCol))$lastRow"]
            $dataRange.Style.Border.Top.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Bottom.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Left.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Right.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin

            # Center numeric columns (vCPU, MemGiB, QuotaAvail)
            $ws.Cells["E2:F$lastRow"].Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center
            $ws.Cells["J2:J$lastRow"].Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center

            # Add filter to header
            $ws.Cells["A1:$([char](64 + $lastCol))1"].AutoFilter = $true

            Close-ExcelPackage $excel

            Write-Host "  $($Icons.Check) XLSX: $xlsxFile" -ForegroundColor Green
            Write-Host "    - Summary sheet with color-coded status" -ForegroundColor DarkGray
            Write-Host "    - Details sheet with filters and conditional formatting" -ForegroundColor DarkGray
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
}
