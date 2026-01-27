<#
.SYNOPSIS
    Azure VM Capacity Checker - Comprehensive SKU availability and capacity scanner.

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
    - Local: C:\Temp\AzureVMCapacityChecker

.PARAMETER AutoExport
    Automatically export results without prompting.

.PARAMETER EnableDrillDown
    Enable interactive drill-down to select specific families and SKUs.

.PARAMETER FamilyFilter
    Pre-filter results to specific VM families (e.g., 'D', 'E', 'F').

.PARAMETER NoPrompt
    Skip all interactive prompts. Uses defaults or provided parameters.

.PARAMETER OutputFormat
    Export format: 'Auto' (detects XLSX capability), 'CSV', or 'XLSX'.
    Default is 'Auto'.

.PARAMETER UseAsciiIcons
    Force ASCII icons [+] [!] [-] instead of Unicode ✓ ⚠ ✗.
    By default, auto-detects terminal capability.

.NOTES
    Name:           Azure VM Capacity Checker
    Author:         Zachary Luz
    Company:        Microsoft
    Created:        2026-01-21
    Version:        1.1.0
    License:        MIT
    Repository:     https://github.com/zacharyluz/Azure-VM-Capacity-Checker

    Requirements:   Az.Compute, Az.Resources modules
                    PowerShell 7+ (for parallel execution)

.EXAMPLE
    .\Azure-VM-Capacity-Checker.ps1
    Run interactively with prompts for all options.

.EXAMPLE
    .\Azure-VM-Capacity-Checker.ps1 -Region "eastus","westus2" -AutoExport
    Scan specified regions with current subscription, auto-export results.

.EXAMPLE
    .\Azure-VM-Capacity-Checker.ps1 -NoPrompt -Region "eastus","centralus","westus2"
    Fully automated scan of three regions using current subscription context.

.EXAMPLE
    .\Azure-VM-Capacity-Checker.ps1 -EnableDrillDown -FamilyFilter "D","E","M"
    Interactive mode focused on D, E, and M series families.

.LINK
    https://github.com/zacharyluz/Azure-VM-Capacity-Checker
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
$ScriptVersion = "1.1.1"

# Map parameters to internal variables
$TargetSubIds = $SubscriptionId
$Regions = $Region
$EnableDrill = $EnableDrillDown.IsPresent
$SelectedFamilyFilter = $FamilyFilter
$SelectedSkuFilter = @{}

# Detect execution environment (Azure Cloud Shell vs local)
$isCloudShell = $env:CLOUD_SHELL -eq "true" -or (Test-Path "/home/system" -ErrorAction SilentlyContinue)
$defaultExportPath = if ($isCloudShell) { "/home/system" } else { "C:\Temp\AzureVMCapacityChecker" }

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
    # Formats zone availability into a human-readable string (e.g., "OK[1,2] WARN[3]")
    param([array]$OK, [array]$Limited, [array]$Restricted)
    $parts = @()
    if ($OK.Count -gt 0) { $parts += "OK[$($OK -join ',')]" }
    if ($Limited.Count -gt 0) { $parts += "WARN[$($Limited -join ',')]" }
    if ($Restricted.Count -gt 0) { $parts += "BLOCK[$($Restricted -join ',')]" }
    if ($parts.Count -eq 0) { return 'Regional' }  # No zone info = regional deployment
    return $parts -join ' '
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
        Write-Host ("=" * 80) -ForegroundColor Gray
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

if ($ExportPath -and -not (Test-Path $ExportPath)) {
    New-Item -Path $ExportPath -ItemType Directory -Force | Out-Null
    Write-Host "Created: $ExportPath" -ForegroundColor Green
}

# === Data Collection ================================================

Write-Host "`n" -NoNewline
Write-Host ("=" * 70) -ForegroundColor Gray
Write-Host "AZURE VM CAPACITY CHECKER v$ScriptVersion" -ForegroundColor Green
Write-Host ("=" * 70) -ForegroundColor Gray
Write-Host "Subscriptions: $($TargetSubIds.Count) | Regions: $($Regions -join ', ')" -ForegroundColor Cyan
Write-Host "Icons: $(if ($supportsUnicode) { 'Unicode' } else { 'ASCII' })" -ForegroundColor DarkGray
Write-Host ""

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
        try {
            $allSkus = Get-AzComputeResourceSku -Location $region -ErrorAction Stop |
            Where-Object { $_.ResourceType -eq 'virtualMachines' }
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
        Write-Host ("=" * 70) -ForegroundColor Gray
        Write-Host "REGION: $region" -ForegroundColor Yellow
        Write-Host ("=" * 70) -ForegroundColor Gray

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
            $quotaLines | Format-Table -AutoSize
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

            $rows += [pscustomobject]@{
                Family  = $family
                SKUs    = $skus.Count
                Avail   = $availableCount
                Largest = "{0}vCPU/{1}GB" -f $largestSku.vCPU, $largestSku.Memory
                Zones   = $zoneStatus
                Status  = $capacity
                Quota   = if ($quotaInfo.Available) { $quotaInfo.Available } else { '?' }
            }

            # Track for drill-down
            if (-not $familySkuIndex.ContainsKey($family)) { $familySkuIndex[$family] = @{} }

            foreach ($sku in $skus) {
                $familySkuIndex[$family][$sku.Name] = $true
                $skuRestrictions = Get-RestrictionDetails $sku

                $familyDetails += [pscustomobject]@{
                    Subscription = [string]$subName
                    Region       = Get-SafeString $region
                    Family       = [string]$family
                    SKU          = [string]$sku.Name
                    vCPU         = Get-CapValue $sku 'vCPUs'
                    MemGiB       = Get-CapValue $sku 'MemoryGB'
                    ZoneStatus   = Format-ZoneStatus $skuRestrictions.ZonesOK $skuRestrictions.ZonesLimited $skuRestrictions.ZonesRestricted
                    Capacity     = [string]$skuRestrictions.Status
                    Reason       = ($skuRestrictions.RestrictionReasons -join ', ')
                    QuotaAvail   = if ($quotaInfo.Available) { $quotaInfo.Available } else { '?' }
                }
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
            $rows | Format-Table -AutoSize
        }
    }
}

# === Drill-Down (if enabled) ========================================

if ($EnableDrill -and $familySkuIndex.Keys.Count -gt 0) {
    Write-Host "`n" -NoNewline
    Write-Host ("=" * 80) -ForegroundColor Gray
    Write-Host "DRILL-DOWN: SELECT FAMILIES" -ForegroundColor Green
    Write-Host ("=" * 80) -ForegroundColor Gray

    $familyList = @($familySkuIndex.Keys | Sort-Object)
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

    # Display drill-down results
    if ($SelectedFamilyFilter.Count -gt 0) {
        Write-Host ""
        Write-Host ("=" * 80) -ForegroundColor Gray
        Write-Host "FAMILY / SKU DRILL-DOWN RESULTS" -ForegroundColor Green
        Write-Host ("=" * 80) -ForegroundColor Gray

        foreach ($fam in $SelectedFamilyFilter) {
            Write-Host "`nFamily: $fam" -ForegroundColor Cyan
            Write-Host ("-" * 40) -ForegroundColor Gray

            $skuFilter = $null
            if ($SelectedSkuFilter.ContainsKey($fam)) { $skuFilter = $SelectedSkuFilter[$fam] }

            $detailRows = $familyDetails | Where-Object {
                $_.Family -eq $fam -and (
                    -not $skuFilter -or $skuFilter -contains $_.SKU
                )
            }

            if ($detailRows.Count -gt 0) {
                $detailRows | Sort-Object Region, SKU | Format-Table Region, SKU, vCPU, MemGiB, ZoneStatus, Capacity, Reason -AutoSize
            }
            else {
                Write-Host "No matching SKUs found for selection." -ForegroundColor DarkYellow
            }
        }
    }
}

# === Multi-Region Matrix ============================================

Write-Host "`n" -NoNewline
Write-Host ("=" * 90) -ForegroundColor Gray
Write-Host "MULTI-REGION CAPACITY MATRIX" -ForegroundColor Green
Write-Host ("=" * 90) -ForegroundColor Gray
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
Write-Host ("-" * $headerLine.Length) -ForegroundColor Gray

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
Write-Host "  $($Icons.OK)".PadRight(20) + "= Full capacity" -ForegroundColor Green
Write-Host "  $($Icons.CAPACITY)".PadRight(20) + "= Zone constraints" -ForegroundColor Yellow
Write-Host "  $($Icons.LIMITED)".PadRight(20) + "= Limited capacity" -ForegroundColor Yellow
Write-Host "  $($Icons.PARTIAL)".PadRight(20) + "= Mixed availability" -ForegroundColor Yellow
Write-Host "  $($Icons.BLOCKED)".PadRight(20) + "= Not available" -ForegroundColor Red

# === Best Options ===================================================

Write-Host "`n" -NoNewline
Write-Host ("=" * 90) -ForegroundColor Gray
Write-Host "BEST DEPLOYMENT OPTIONS" -ForegroundColor Green
Write-Host ("=" * 90) -ForegroundColor Gray
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
    foreach ($r in $allRegions) {
        $families = @($bestPerRegion[$r])
        if ($families.Count -gt 0) {
            Write-Host "$r - Full Capacity:" -ForegroundColor Green
            Write-Host "  $($families -join ', ')" -ForegroundColor White
        }
    }
}
else {
    Write-Host "No families with full capacity. Consider:" -ForegroundColor Yellow
    foreach ($family in ($allFamilyStats.Keys | Sort-Object | Select-Object -First 5)) {
        $stats = $allFamilyStats[$family]
        $bestRegion = $stats.Regions.Keys | Sort-Object { $stats.Regions[$_].Available } -Descending | Select-Object -First 1
        if ($bestRegion) {
            $regionStat = $stats.Regions[$bestRegion]
            Write-Host "  $family in $bestRegion ($($regionStat.Capacity))" -ForegroundColor Yellow
        }
    }
}

# === Detailed Breakdown =============================================

Write-Host "`n" -NoNewline
Write-Host ("=" * 90) -ForegroundColor Gray
Write-Host "DETAILED CROSS-REGION BREAKDOWN" -ForegroundColor Green
Write-Host ("=" * 90) -ForegroundColor Gray
Write-Host ""

# Fixed-width formatted table
$colFamily = 8
$colFullCap = 25

$headerFmt = "{0,-$colFamily} {1,-$colFullCap} {2}" -f "Family", "Full Capacity", "Constrained"
Write-Host $headerFmt -ForegroundColor Cyan
Write-Host ("-" * 85) -ForegroundColor Gray

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

    $fullCapStr = if ($regionsOK.Count -gt 0) { $regionsOK -join ', ' } else { '-' }
    $constrainedStr = if ($regionsConstrained.Count -gt 0) { $regionsConstrained -join ' | ' } else { '-' }

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
Write-Host ("=" * 70) -ForegroundColor Gray
Write-Host "SCAN COMPLETE" -ForegroundColor Green
Write-Host "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')" -ForegroundColor DarkGray
Write-Host ("=" * 70) -ForegroundColor Gray

# === Export =========================================================

if ($ExportPath) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

    # Determine format
    $useXLSX = ($OutputFormat -eq 'XLSX') -or ($OutputFormat -eq 'Auto' -and (Test-ImportExcelModule))

    Write-Host "`nEXPORTING..." -ForegroundColor Cyan

    if ($useXLSX -and (Test-ImportExcelModule)) {
        $xlsxFile = Join-Path $ExportPath "Azure-VM-Capacity-$timestamp.xlsx"
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
        $summaryFile = Join-Path $ExportPath "Azure-VM-Capacity-Summary-$timestamp.csv"
        $detailFile = Join-Path $ExportPath "Azure-VM-Capacity-Details-$timestamp.csv"

        $summaryRowsForExport | Export-Csv -Path $summaryFile -NoTypeInformation -Encoding UTF8
        $familyDetails | Export-Csv -Path $detailFile -NoTypeInformation -Encoding UTF8

        Write-Host "  $($Icons.Check) Summary: $summaryFile" -ForegroundColor Green
        Write-Host "  $($Icons.Check) Details: $detailFile" -ForegroundColor Green
    }

    Write-Host "`nExport complete!" -ForegroundColor Green
}
