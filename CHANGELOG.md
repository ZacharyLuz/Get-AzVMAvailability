# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.6.0] - 2026-02-06

### Improved
- **Cloud Shell compatibility** - Optimized table output for narrow terminals (80-char width)
  - Reduced Matrix column width from 15 to 12 characters
  - Shortened ASCII status labels (`[OK]` instead of `[+] OK`)
  - Cross-Region Breakdown now detects actual terminal width
  - Fixed column widths for consistent alignment (Family: 8, Available: 20, Constrained: 30+)
  - Shortened `CAPACITY-CONSTRAINED` to `CAPACITY` in output

### Added
- **User-friendly explanations** - Added clear guidance to help users interpret summary tables
  - Matrix intro: explains this shows "ANY SKUs" not "ALL SKUs" per family
  - Row color guide: Green (available), Yellow (constrained), Gray (unavailable)
  - Expanded status meanings with actionable descriptions
  - Warning note: "'OK' means SOME SKUs work, not ALL"
  - Cross-Region Breakdown intro explaining Available/Constrained/(none) meanings
  - Important note clarifying family-level vs SKU-level results

## [1.5.1] - 2026-02-04

### Fixed
- **Function definition order** - Fixed `Get-AzureEndpoints` function being called before it was defined, causing "term not recognized" error on script startup
  - Moved Azure endpoints initialization to after all function definitions
  - Script now executes correctly without errors

## [1.5.0] - 2026-02-03

### Added
- **Excel Legend Sheet** - New "Legend" worksheet in XLSX exports explaining:
  - Status format `(X/Y)` where X = available SKUs, Y = total SKUs
  - Capacity status codes with color coding (OK, LIMITED, CAPACITY-CONSTRAINED, PARTIAL, RESTRICTED, N/A)
  - Column definitions for Summary and Details sheets
- **Region Presets (`-RegionPreset`)** - Quick access to common region sets:
  - `USEastWest` - eastus, eastus2, westus, westus2
  - `USCentral` - centralus, northcentralus, southcentralus, westcentralus
  - `USMajor` - Top 5 US regions (eastus, eastus2, centralus, westus, westus2)
  - `Europe` - westeurope, northeurope, uksouth, francecentral, germanywestcentral
  - `AsiaPacific` - eastasia, southeastasia, japaneast, australiaeast, koreacentral
  - `Global` - One region per major geography
  - `USGov` - Azure Government regions (auto-sets environment)
  - `China` - Azure China/Mooncake regions (auto-sets environment)
  - `ASR-EastWest` / `ASR-CentralUS` - Azure Site Recovery DR pairs
- **Sovereign Cloud Support** - Automatic detection and support for Azure cloud environments
  - Azure Commercial (`AzureCloud`)
  - Azure Government (`AzureUSGovernment`)
  - Azure China (`AzureChinaCloud`)
  - Azure Germany (`AzureGermanCloud` - deprecated)
- **New `-Environment` Parameter** - Optional explicit override for cloud environment
- **Region Limit (5 max)** - Warns when >5 regions specified for readability
  - Interactive mode: prompts to truncate or cancel
  - `-NoPrompt` mode: auto-truncates with warning
- **Drill-Down Quota Breakdown** - Region sub-headers show full quota info:
  - Format: `Region: eastus (Quota: 0 of 100 vCPUs used | 100 available)`
  - Fixed: Now correctly shows `0` when no quota is used (was showing simplified format)
- **NEED MORE CAPACITY? Section** - Guidance for quota increases
  - Environment-aware portal link (Commercial/Gov/China)
  - Hybrid Benefit pricing note when `-ShowPricing` enabled
- **Pester Tests** - Unit tests for endpoint resolution (`tests/Get-AzureEndpoints.Tests.ps1`)
- **Documentation**
  - `docs/Excel-Legend-Reference.md` - Comprehensive Legend explanation
  - Region Presets section in README with examples
  - Image Compatibility Checking section in README with interactive search guide
  - Sovereign Clouds explanation (why presets are hardcoded)

### Changed
- **Breaking**: Removed `-UseActualPricing` switch; `-ShowPricing` now auto-detects negotiated rates (EA/MCA/CSP) and falls back to retail pricing automatically
- **Detailed Cross-Region Breakdown** - Improved color logic:
  - Family name: **Green** (100% OK), **White** (mixed), **Yellow** (all constrained), **Gray** (unavailable)
  - Available column: Always **Green**
  - Constrained column: Always **Yellow**
  - Now includes `RESTRICTED` and `BLOCKED` statuses (were being hidden)
- **Dynamic Separator Widths** - Calculated early based on table column widths
  - With pricing: 133 characters
  - Without pricing: 113 characters
  - No more misaligned separators
- Multi-region output now wraps long region lists intelligently across lines
- Pricing API URL derived from `ManagementPortalUrl` instead of hard-coded
- Cost Management API uses environment-specific `ResourceManagerUrl`
- Quota URL in help text now environment-aware (Gov/China use correct portal)
- README version badge updated to 1.5.0

### Fixed
- **Quota display** - Fixed `$null` vs `0` comparison; now shows "0 of 100 used" instead of just "100 available"
- **Region truncation bug** - Fixed single-character region names in Detailed Breakdown (was showing 'e' instead of 'eastus')
- **Separator line widths** - Now consistent across all sections (was using different widths)
- **Duplicate print loop** - Removed accidentally duplicated for-loop in Detailed Breakdown
- **Stray characters** - Removed debug text that was appearing in output
- Excel Legend export now uses `-Append` (was overwriting Summary/Details sheets)
- PARTIAL status now included in Legend and has yellow styling in Excel
- Region limit prompt respects `-NoPrompt` (was hanging in automation)
- **Sovereign cloud quota URLs** - Fixed environment detection being overwritten; quota portal URLs now correctly point to sovereign cloud portals (portal.azure.us, portal.azure.cn) even without `-ShowPricing`

### Added (CI/CD)
- **GitHub Actions workflow** - PSScriptAnalyzer linting and Pester tests on pull requests
- **Branch protection** - Main branch now requires passing PSScriptAnalyzer checks

### Removed
- `AzureStack` from `-Environment` options (not applicable for this tool's use case)
- `USAll` preset renamed to `USMajor` (was misleading - not all US regions)

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
