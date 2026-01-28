# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.5.0] - 2026-01-28

### Added
- **Sovereign Cloud Support** - Automatic detection and support for all Azure cloud environments
  - Azure Commercial (`AzureCloud`)
  - Azure Government (`AzureUSGovernment`)
  - Azure China (`AzureChinaCloud`)
  - Azure Germany (`AzureGermanCloud`)
  - Azure Stack (`AzureStack`)
- **New `-Environment` Parameter** - Optional explicit override for cloud environment
  - Options: `AzureCloud`, `AzureUSGovernment`, `AzureChinaCloud`, `AzureGermanCloud`, `AzureStack`
  - Default: auto-detect from `Get-AzContext`
  - Example: `-Environment AzureUSGovernment`
- **New `Get-AzureEndpoints` Function** - Resolves API endpoints based on current Azure context
  - Automatically detects environment from `Get-AzContext`
  - Supports explicit override via `-EnvironmentName` parameter
  - Falls back gracefully to Commercial cloud if detection fails
- **Pester Tests** - Unit tests for endpoint resolution (`tests/Get-AzureEndpoints.Tests.ps1`)
  - Mock-based testing for all cloud environments
  - URL normalization validation
  - Integration tests for URL construction

### Changed
- Pricing API URL now derived from `ManagementPortalUrl` instead of hard-coded
- Cost Management API now uses environment-specific `ResourceManagerUrl`
- Token acquisition uses dynamic ARM endpoint for sovereign clouds

### Technical
- Endpoint resolution cached in `$script:AzureEndpoints` for performance
- Verbose output shows resolved endpoints for debugging

## [1.4.0] - 2026-01-27

### Added
- **Image Compatibility** - New `-ImageURN` parameter to check SKU compatibility with VM images
  - Validates VM Generation (Gen1 vs Gen2) requirements
  - Validates CPU Architecture (x64 vs ARM64) requirements
  - Shows Gen/Arch columns in drill-down view
  - Shows Img compatibility column (✓/✗) when image is specified
  - Color-coded rows: green for compatible, dark yellow for incompatible
- **Interactive Image Selection** - When not using `-NoPrompt`, offers image picker
  - 16 pre-configured common images organized by category:
    - Linux: Ubuntu, RHEL, Debian, Azure Linux (Mariner)
    - Windows: Server 2022/2019, Windows 11 Enterprise
    - Data Science: DSVM Ubuntu, DSVM Windows, Azure ML Workstation
    - HPC: Ubuntu HPC, AlmaLinux HPC
    - Gen1: Legacy images for older SKUs
  - `custom` option for manual URN entry
  - `search` option to browse Azure Marketplace
- **Enhanced Marketplace Search** - Search finds both publishers AND offer names
  - Searching "dsvm" or "data science" finds relevant images directly
  - Results show whether match is a Publisher or Offer for faster navigation
- **CompactOutput Parameter** - New `-CompactOutput` switch for narrow terminals

### Changed
- Drill-down tables expanded to 185 characters to accommodate Gen/Arch/Img columns
- Header now shows image URN and requirements when image compatibility is enabled
- Image requirements displayed at start of each family drill-down section

### Renamed
- **Script renamed** from `Azure-VM-Capacity-Checker.ps1` to `Get-AzVMAvailability.ps1`
- **Repository renamed** from `Azure-VM-Capacity-Checker` to `Get-AzVMAvailability`
- Export filenames now use `AzVMAvailability-` prefix instead of `Azure-VM-Capacity-`
- Default export folder changed to `C:\Temp\AzVMAvailability`

### Fixed
- `-NoPrompt` now works correctly with `-EnableDrillDown` - auto-selects all families and SKUs

### Technical
- New `Get-ImageRequirements` function to parse image URN and detect Gen/Arch
- New `Get-SkuCapabilities` function to extract HyperVGenerations and CpuArchitectureType
- New `Test-ImageSkuCompatibility` function to compare requirements against capabilities
- Detail objects now include Gen, Arch, ImgCompat, and ImgReason properties

## [1.3.0] - 2026-01-26

### Added
- **Pricing Information** - New `-ShowPricing` parameter to display estimated hourly and monthly costs
  - Fetches Linux pay-as-you-go pricing from Azure Retail Prices API
  - Shows `$/Hr` and `$/Mo` columns in SKU families table and drill-down views
  - Pricing data included in exports when enabled
  - Adds ~5-10 seconds to execution time (varies by region count)
- **Actual Pricing Support** - New `-UseActualPricing` parameter for negotiated rates
  - Uses Azure Cost Management API to fetch your organization's actual rates
  - Reflects EA/MCA/CSP discounts and negotiated pricing
  - Requires Billing Reader or Cost Management Reader role
  - Gracefully falls back to retail pricing if access is denied
- **Interactive Pricing Prompt** - When not using `-NoPrompt`, asks if user wants pricing
- **Fixed-Width Tables** - All tables now use consistent 175-character width for perfect alignment
  - Quota summary table with fixed columns
  - SKU families table with fixed columns
  - Drill-down detail table with fixed columns
  - Detailed breakdown table with fixed columns
  - No more column misalignment issues

### Changed
- All `Format-Table -AutoSize` replaced with custom fixed-width formatting
- Header now shows "Pricing: Enabled/Disabled" status
- Pricing data fetched before scanning to minimize delays during output
- Drill-down table includes pricing columns when `-ShowPricing` is active
- Table width expanded from 125 to 175 characters to accommodate all column data

### Technical
- New `Get-AzVMPricing` function for Azure Retail Prices API integration
- New `Get-AzActualPricing` function for Cost Management API integration
- Pricing data cached per region to minimize API calls
- API pagination handled (up to 20 pages per region for retail pricing)
- `$script:usingActualPricing` flag tracks which pricing source is active

## [1.2.0] - 2026-01-26

### Added
- **SKU Filtering** - New `-SkuFilter` parameter to filter output to specific SKUs
  - Supports exact SKU name matching (e.g., `Standard_D2s_v3`)
  - Supports wildcard patterns (e.g., `Standard_D*_v5`, `Standard_E?s_v5`)
  - Case-insensitive matching
  - Multiple SKU patterns can be specified
  - Filter indicator shown in output header when active
- Helper function `Test-SkuMatchesFilter` for pattern matching logic

### Changed
- Data collection now applies SKU filter during parallel execution for better performance
- Output sections (tables, matrix, exports) automatically respect SKU filter
- Updated documentation with `-SkuFilter` examples
- **Improved UX clarity throughout:**
  - Column headers renamed: "Full Capacity" → "Available Regions", "Constrained" → "Constrained Regions"
  - Empty values now show "(none)" instead of cryptic "-" dash
  - SKU table column "Avail" → "OK" for clarity
  - Zone status now shows "✓ Zones 1,2 | ⚠ Zones 3" instead of "OK[1,2] WARN[3]"
  - "Regional" → "Non-zonal" for VMs without zone support
  - Legend descriptions improved (removed "= " prefix)
  - "BEST DEPLOYMENT OPTIONS" → "DEPLOYMENT RECOMMENDATIONS" with better messaging
  - "No families with full capacity" → clearer explanation with alternatives

## [1.1.1] - 2026-01-26

### Fixed
- Removed unused `$colConstrained` variable from detailed breakdown formatting section

## [1.1.0] - 2026-01-23

### Added
- **Enhanced region selection**: Full interactive menu showing all Azure regions grouped by geography (Americas-US, Europe, Asia-Pacific, etc.)
- **Fast path for regions**: Type region codes directly to skip the menu, or press Enter for the full list
- **Enhanced family drill-down**: SKU selection within each family with numbered list
- **SKU selection modes**: Choose 'all' SKUs, 'none' to skip, or pick specific SKUs per family
- **Improved instructions**: Clear guidance at each prompt for better user experience

### Changed
- Region selection now shows display names with region codes (e.g., "East US (eastus)")
- Drill-down now shows SKU counts per family
- Added ZoneStatus column to drill-down output

## [1.0.0] - 2026-01-21

### Added
- Initial public release
- Multi-region parallel scanning (~5 seconds for 3 regions)
- Comprehensive VM SKU family discovery
- Capacity status reporting (OK, LIMITED, CAPACITY-CONSTRAINED, RESTRICTED)
- Zone-level availability details
- vCPU quota tracking per family
- Multi-region capacity comparison matrix
- Interactive drill-down by family/SKU
- CSV export support
- Styled XLSX export with conditional formatting (requires ImportExcel module)
- Auto-detection of terminal Unicode support
- ASCII icon fallback for non-Unicode terminals
- Color-coded console output

### Technical Details
- Requires PowerShell 7.0+ for ForEach-Object -Parallel
- Uses Az.Compute and Az.Resources modules
- Handles parallel execution string serialization with Get-SafeString function
