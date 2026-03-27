# InputHandler.ps1
# Reference copy extracted from Get-AzVMAvailability.ps1 (lines 2665-3060)
# Contains: interactive subscription/region selection prompts, options menus,
#           image URN selection, and drill-down mode prompts.
# DO NOT execute this file directly — it is a documentation reference only.
# The authoritative source is Get-AzVMAvailability.ps1.
#
# NOTE: This file begins at the end of the module-import/inline-fallback block.
# Lines 621-2664 of the main script (preceding this section) contain:
#   - Module import logic (AzVMAvailability module or inline function fallback)
#   - All 34 function definitions (Get-SafeString through Get-AzActualPricing)
#   - Azure endpoint initialization
#   - Subscription and region prompt scaffolding
# The closing markers below (#endregion Inline Function Definitions, }) close
# the inline fallback block that began at line ~623 of the main script.

#endregion Inline Function Definitions
}
#endregion Module Import / Inline Fallback
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
