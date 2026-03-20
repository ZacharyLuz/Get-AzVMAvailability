# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- Replaced all 9 `exit` calls with `throw` (error paths) and `return` (user cancellation) for module safety — script no longer kills the caller's session when dot-sourced (#68)
- Converted 3 hot-loop `+=` array accumulations to `[System.Collections.Generic.List[T]]` in `Get-RestrictionDetails`, `$rows`, and `$familyDetails` (#70)
- Archived 9 internal process documents to `docs/archive/` (gitignored) — removes remediation artifacts from public repo (#74)
- Updated `copilot-instructions.md` with current metrics (4,442 lines, 34 functions, 349 Write-Host, 0 exit calls, 189 tests/11 files), line numbers, parent-scope dependency table, and module extraction order
- Updated `.github/workflows/collect-traffic.yml` to dual-checkout source + `traffic-data`, generate `dashboard.html`/`index.html` from `data/*.csv`, and commit static site files for GitHub Pages publishing
- Added daily release asset download snapshot collection (`data/release-downloads.csv`) and surfaced the metric in `Generate-TrafficDashboard-Premium-v2.ps1` dashboard cards

### Added
- 19 Pester tests for `-FleetFile` CSV/JSON parsing: column name matching, duplicate detection, validation rules, normalization, and `-Fleet`/`-FleetFile` mutual exclusion (#62)

### Fixed
- Inlined parallel scan logic into `ForEach-Object -Parallel` scriptblock — PowerShell prohibits `$using:` references to ScriptBlock variables, causing runtime errors in multi-region scans (#53)
- Fixed all parent-scope implicit dependencies in 9 functions — every function now takes explicit parameters instead of reading from parent scope (#72)
- Scoped `TRAFFIC_TOKEN` in traffic workflow to only the 4 `/traffic/*` API steps; non-traffic endpoints (stargazers, repo stats, releases) use `GITHUB_TOKEN` (Copilot review, PR #82)
- Set job-level `env.GH_TOKEN` in traffic workflow to reduce per-step duplication (Copilot review, PR #82)

## [1.12.1] - 2026-03-18

### Added
- **`-FleetFile` parameter** — load fleet BOM from CSV or JSON file instead of inline hashtable. Accepts flexible column names (SKU/Name/VmSize, Qty/Quantity/Count). Removes the biggest adoption barrier for fleet readiness validation.
- **`-GenerateFleetTemplate` switch** — creates `fleet-template.csv` and `fleet-template.json` in the current directory with sample SKUs. No Azure login required. Eliminates guesswork about file format.
- Example fleet CSV at `examples/fleet-bom.csv` and JSON at `examples/fleet-bom.json`
- Fleet Planning Quick Start section in README with step-by-step guide
- Fleet workflow added to SKILL.md decision tree and Workflow 7 section for AI agent routing
- Fleet demo scenarios (7B, 7C) added to `demo/Demo-Commands.ps1`

## [1.12.0] - 2026-03-18

### Added
- **Fleet Readiness Mode** — `-Fleet` hashtable parameter for BOM-level capacity and quota validation (`-Fleet @{'Standard_D2s_v5'=17; 'Standard_D4s_v5'=4}`)
- Fleet auto-derives `-SkuFilter` from Fleet keys with double-prefix guard (`Standard_Standard_` → `Standard_`)
- `Get-FleetReadiness` function — validates fleet BOM against scan data, checks per-SKU capacity, aggregates vCPU demand per quota family with fuzzy family name matching fallback
- `Write-FleetReadinessSummary` function — color-coded console output with per-SKU table, per-family quota pass/fail (Used/Available/Limit), and overall verdict

### Changed
- Release workflow: push-to-main releases now auto-publish (not draft) — release notes are editable on GitHub without a new PR; manual dispatch still defaults to draft via `draft_release` input
- CI: Release workflow now fails on version stagnation — if `$ScriptVersion` matches an existing tag but HEAD has new commits, the workflow throws instead of silently passing. Every merge to main requires a version bump.

### Fixed
- Tooling: `Validate-Script.ps1` Check 5 docs scan now uses `git ls-files` instead of `Get-ChildItem` so only committed/staged files can trigger version-consistency failures — prevents false positives from local untracked scratch notes under `docs/`
- Tooling: `Validate-Script.ps1` Check 5 now guards `git ls-files` with `Get-Command git` — falls back to `Get-ChildItem` with a `WARN` when git is unavailable (e.g. source ZIP install), preventing a `CommandNotFoundException` crash
- Tooling: `Validate-Script.ps1` Check 5 now checks `$LASTEXITCODE` after `git ls-files` — if git exits non-zero (not a git worktree), emits `WARN` and falls back to `Get-ChildItem` instead of silently returning an empty file list and passing Check 5 trivially
- Tests: Strengthened RFC1123 `Invoke-WithRetry` integration test — changed `AddSeconds(3)` to `AddSeconds(300)` and assertion from `-ge 1` to `-ge 60`; default backoff (2s + jitter) can no longer satisfy the threshold, so header-parsing regressions are reliably caught
- Tests: Added end-to-end `Invoke-WithRetry` integration tests for `Retry-After` header parsing using `Add-Type` fake exception class with real `Response.Headers` dictionary and `Mock Start-Sleep` to exercise the actual `catch` path (189 tests total)

### Chores
- CI: Updated `actions/checkout` from `@v4` to `@v4.2.2` across all 4 workflow files — eliminates Node.js 20 deprecation warnings (Node.js 24 required by GitHub Actions from June 2026)

## [1.11.3] - 2026-03-16

### Fixed
- CI: Fixed `[Unreleased]` changelog guard regex that allowed empty sections to pass — `\s*` consumed newlines past the heading boundary, causing `(.*?)` to capture the next version's content instead of detecting an empty section
- Security: Clear auth token (`$headers['Authorization']` and `$token`) in `finally` blocks in `Get-ValidAzureRegions` and `Get-AzActualPricing` to prevent credential leakage on exception paths (G-S1)
- Resilience: `Invoke-WithRetry` now handles RFC 1123 HTTP-date `Retry-After` values (e.g. `Sun, 16 Mar 2026 14:00:00 GMT`) in addition to integer seconds, preventing premature retries under heavy throttling (G-B1)
- Reliability: Extended outer `try/finally` to cover the export section so `Restore-OriginalSubscriptionContext` is guaranteed to run even if the user presses Ctrl+C during XLSX/CSV generation (G-B2)

### Performance
- `Get-AzActualPricing`: Changed Cost Management OData filter from `contains(meterCategory,'Virtual Machines')` to exact `meterCategory eq 'Virtual Machines'`, eliminating a server-side full-scan (G-P4)

## [1.11.2] - 2026-03-12

### Added
- Startup version check gate (issue #41): `release-metadata-guard.yml` now requires at least one entry under `## [Unreleased]` for PRs that do not bump `$ScriptVersion`, closing the loophole where maintenance PRs bypassed all CHANGELOG enforcement
- Version regression guard: `release-on-main.yml` drift check now fails if `$ScriptVersion` is lower than the latest existing git tag — uses `[version]::TryParse()` for safe comparison (non-semver tags degrade to `Write-Warning` instead of hard-failing)

### Fixed
- `$ScriptVersion` corrected to `1.11.2` — the constant was never bumped past `1.11.0` despite v1.11.1 and three subsequent maintenance PRs shipping to `main`

### Changed (CI / Tooling — PRs #38–40, previously undocumented)
- **PR #38** — Expanded test coverage from 142 to 182 tests: added `tests/HelperFunctions.Tests.ps1` covering `Get-QuotaAvailable`, `Get-SkuCapabilities`, and `Get-RestrictionReason`; added `tests/FleetSafety.Tests.ps1` coverage for `Get-ProcessorVendor`; added `tests/ImageCompatibility.Tests.ps1` covering `Get-ImageRequirements` and `Test-ImageSkuCompatibility`; updated `$script:RunContext.Caches` to include an explicit `PlacementWarned403` key for placement-score 403 warning deduplication
- **PR #39** — Added `.github/workflows/scheduled-health-check.yml` (weekly PSScriptAnalyzer + Pester run on `main`); added PR template coverage gate requiring checklist completion before merge
- **PR #40** — Fixed 4 Copilot post-merge findings: cross-platform temp path (replaced hard-coded Windows temp path with `[System.IO.Path]::GetTempPath()` + `Join-Path`); backtick-escaped `$ScriptVersion` in YAML double-quoted PowerShell strings; `github.base_ref || 'main'` fallback for `workflow_dispatch` triggers

## [1.11.1] - 2026-03-12

### Added
- Copilot skill (`.github/skills/azure-vm-availability/SKILL.md`) for AI agent integration -- teaches coding agents when and how to invoke Get-AzVMAvailability via terminal
- README "AI Agent Integration" section with example agent invocations and installation instructions

## [1.11.0] - 2026-03-12

### Added
- `-ShowPlacement` parameter to display allocation likelihood scores (High/Medium/Low) for each SKU
- `-ShowSpot` parameter to include Spot VM pricing in pricing-enabled outputs
- `Get-PlacementScores` helper using `Invoke-AzSpotPlacementScore` (batched ≤5 SKUs × ≤8 regions)
- Placement score fields in Recommend JSON contract: `placementEnabled`, `allocScore`
- Spot pricing fields in Recommend JSON contract: `spotPricingEnabled`, `spotPriceHr`, `spotPriceMo`
- New helper `Get-SpotPricingMap` to safely read Spot pricing from region pricing containers
- New helper `Get-RegularPricingMap` to extract regular pricing from split pricing containers
- Interactive post-scan prompts for `-ShowPlacement` and `-ShowSpot` (fires after scan, before rendering; skipped when `-NoPrompt`)
- Placement score enrichment in filtered scan mode (when `-SkuFilter` selects ≤5 SKUs)
- New test files: `tests/PlacementScore.Tests.ps1`, `tests/SpotPricing.Tests.ps1`
- Contract coverage tests in `tests/RecommendJsonContract.Tests.ps1`

### Fixed
- `$script:RunContext` initialization missing `ShowPlacement`, `DesiredCount`, and `AzureEndpoints` properties (caused silent failures when placement or endpoint logic accessed these fields)

### Changed
- `Get-AzVMPricing` now returns separate Regular and Spot pricing maps instead of a single combined map
- Recommend console rendering now supports pricing/placement/spot combinations without breaking existing output modes

## [1.10.4] - 2026-03-04

### Fixed
- **Family summary Quota column now correctly displays `0`** — the truthiness check `if ($quotaInfo.Available)` treated `0` as falsy and showed `?` instead. Changed to explicit null check `if ($null -ne $quotaInfo.Available)` to match the per-SKU drill-down logic. Discovered via Copilot PR review triage on #26.

## [1.10.3] - 2026-03-04

### Fixed
- **Quota column now shows correct per-SKU family quota** — previously matched the broad family bucket (e.g., `Standard NC Family vCPUs`) instead of the specific sub-family (e.g., `Standard NCADS_A100_v4 Family vCPUs`), causing the tool to report available quota for GPU/HPC SKUs that actually had zero quota. Now uses each SKU's `.Family` property as an exact hash key into the quota data, eliminating regex-based matching entirely. Fixes #25.
- Built per-region quota lookup hash table for O(1) quota resolution instead of linear regex search per SKU.

## [1.10.2] - 2026-03-03

### Fixed
- Prevent startup failure when assigning `$script:RunContext.AzureEndpoints` by ensuring the property exists before assignment.
- `New-ScanOutputContract` now accepts empty scan collections so upstream scan errors do not cascade into contract-construction failures.
- Contract payload builders now use list-backed accumulation to avoid O(n^2) array append behavior in recommend JSON output construction.
- Family pricing lookup now consistently reads from `$script:RunContext.RegionPricing`.
- Per-subscription scan timing now reports elapsed time for each subscription independently.

### Changed
- PowerShell 7+ is now explicitly required; script emits a clear warning and exits when run in Windows PowerShell 5.1.
- Added README troubleshooting for execution-policy warnings (`Unblock-File`) and stale single-file download detection.

## [1.10.1] - 2026-03-02

### Added
- **"Consider Smaller" fallback** — when no recommended SKUs have OK capacity but smaller options exist, interactive output now suggests top 3 smaller alternatives
- New helper functions: `Use-SubscriptionContextSafely`, `Restore-OriginalSubscriptionContext`
- New test files: `tests/ContextManagement.Tests.ps1`, `tests/RecommendJsonContract.Tests.ps1`
- Stable output contract helpers: `New-RecommendOutputContract`, `New-ScanOutputContract`
- Recommend output renderer wrapper: `Write-RecommendOutputContract`
- Explicit run context object: `$script:RunContext` for scoped runtime/cache state

### Changed
- Non-interactive runs (`-NoPrompt`) now fail closed when Azure region validation metadata is unavailable
- Removed global `$ErrorActionPreference = 'Continue'` mutation; error behavior is now locally scoped
- Subscription scanning now isolates and restores Az context via `try/finally` to avoid caller context side effects
- Hot-loop `+=` accumulation replaced with `List[object]` in recommendation and image-search paths
- Recommend mode now builds a contract first and renders via wrapper in non-JSON output mode
- JSON output for scan mode now emits a stable contract envelope (`schemaVersion`, `mode`, `generatedAt`, `summary`, `families`, `regionErrors`)
- Region/pricing/image/runtime mutable state migrated to `$script:RunContext` scoped properties
- Removed `ShouldProcess` boilerplate from contract builder functions (pure in-memory, no side effects)
- Completed `$script:ImageReqs` → `$script:RunContext.ImageReqs` migration
- Session handoff docs excluded from git tracking via `.gitignore`

### Fixed
- `$script:ImageReqs` references were stale after Phase 4 contract refactor, silently disabling image compatibility checks
- Empty `List[object]` truthiness bug in offer search results (always evaluated `$true` unlike empty `@()`)
- `CompactOutput` parameter was declared but never referenced after suppression removal
- Code scanning alert: unused `$restored` variable in context management tests

## [1.10.0] - 2026-03-01

### Added
- **Fleet Safety Warnings** — detects and warns about mixed architectures, CPU vendors, temp disk configs, storage interfaces, and accelerated networking across recommended SKUs
- **`-AllowMixedArch` parameter** — opt-in to include ARM64 candidates when targeting x64 (or vice versa); default now filters to target architecture
- **`-SkipRegionValidation` parameter** — explicit override to bypass region validation when metadata lookup is unavailable
- **CPU column** in Recommend output — shows Intel/AMD/ARM for each candidate
- **Disk column** in Recommend output — shows storage config shortcode (NV+T, NVMe, SC+T, SCSI)
- **Disk codes legend** added to Recommend output footer
- New helper functions: `Get-ProcessorVendor`, `Get-DiskCode`
- JSON output now includes `cpu`, `disk`, `tempDiskGB`, `accelNet` fields and a `warnings` array
- 13 new Pester tests for `Get-ProcessorVendor` and `Get-DiskCode`

### Changed
- `Get-SkuCapabilities` now extracts `TempDiskGB`, `AcceleratedNetworkingEnabled`, and `NvmeSupport`
- Recommend table widened to accommodate new columns (base: 113→122, with pricing: 133→140)
- Architecture filtering enabled by default in Recommend mode (candidates must match target arch)

## [1.9.0] - 2026-02-25

### Added
- **Interactive Recommend Mode** — users can now discover VMs first, then find alternatives
  - After scanning/drill-down, prompted: *Find alternative SKUs for a specific VM? (y/N)*
  - Enter any discovered SKU name to run the capacity recommender on-the-fly
  - Works with `-EnableDrillDown` and `-ImageURN` (previously blocked)
- **Region validation** — new `Get-ValidAzureRegions` helper with REST API + `Get-AzLocation` fallback
  - Caches results per subscription for faster repeated calls
  - Filters invalid/unsupported regions before scanning

### Changed
- `-Recommend` parameter no longer conflicts with `-EnableDrillDown` or `-ImageURN`
- SKU name normalization (auto-adds `Standard_` prefix) works for both pre-specified and interactive inputs

## [1.8.1] - 2026-02-24

### Fixed
- **Tests**: avoid PowerShell automatic variable conflict by renaming local test data
- **Tests**: improved regex extraction for `Get-SkuSimilarityScore` to capture full function body

## [1.8.0] - 2026-02-24

### Added
- **Capacity Recommender** — new `-Recommend` parameter finds alternatives when a target SKU
  is unavailable or capacity-constrained
  - Scores all available SKUs by similarity to target (vCPU, memory, family, generation, architecture, premium IO)
  - Ranks results by availability + similarity score
  - Deduplicates across regions (keeps best region per SKU)
  - Color-coded console output: green (OK), yellow (LIMITED), dark yellow (constrained)
- **New parameters:**
  - `-Recommend` — target SKU name (auto-adds `Standard_` prefix if missing)
  - `-TopN` — number of alternatives to return (default 5, max 25)
  - `-MinvCPU` — minimum vCPU count filter for alternatives
  - `-MinMemoryGB` — minimum memory (GB) filter for alternatives
  - `-MinScore` — minimum similarity score threshold (default 50)
  - `-JsonOutput` — structured JSON output for Agent/automation consumption
- **New helper function:** `Get-SkuSimilarityScore` — weighted scoring across 6 dimensions
- **16 new Pester tests** for similarity scoring (isolated per-dimension + combined scenarios)
- **Documentation**: clarified `-MinScore` tuning (set to 0 to show all candidates)

## [1.7.0] - 2026-02-09

### Added
- **Retry resilience** — `Invoke-WithRetry` function with exponential backoff + jitter
  - Handles HTTP 429 (reads Retry-After header), 503, WebException, and timeouts
  - Wraps Retail Pricing API, Cost Management API, and parallel region scanning calls
  - Configurable via new `-MaxRetries` parameter (default 3, range 0-10)
- **Developer guardrails** — automated quality checks for contributors
  - `tools/Validate-Script.ps1` — 5-check pre-commit gate (syntax, lint, tests, AI-comment scan, version consistency)
  - `.editorconfig` — enforced formatting (UTF-8 BOM, CRLF, 4-space indent)
  - `PSScriptAnalyzerSettings.psd1` — shared lint settings for VS Code and CI
  - `.github/PULL_REQUEST_TEMPLATE.md` — quality checklist
- **Expanded test coverage** — 76 Pester tests (was 20)
  - 11 tests for `Invoke-WithRetry` (success, retry on 429/503/timeout, exhaustion)
  - 45 tests for helper functions (`Get-SafeString`, `Get-CapValue`, `Get-SkuFamily`,
    `Get-RestrictionDetails`, `Format-ZoneStatus`, `Test-SkuMatchesFilter`, `Get-GeoGroup`)

### Changed
- **Named constants** — replaced magic numbers with descriptive variables
  - `$HoursPerMonth` (730), `$ParallelThrottleLimit` (4), `$OutputWidthWithPricing` (133), etc.
- **Collapsible sections** — converted `# ===` banners to `#region`/`#endregion` markers
- **Code cleanup** — removed ~30 "what" comments, 5 AI-pattern comments, 2 dead functions
  - Deleted `Format-FixedWidthTable` (63 lines, zero call sites)
  - Deleted `Get-SkuSizeAvailability` (12 lines, zero call sites)
  - Relocated `Format-RegionList` to helper functions section

### Fixed
- Empty catch block in image search now logs via `Write-Verbose`
- `$matches` automatic variable shadowing renamed to `$isMatch`
- Null comparisons moved to correct side (`$null -ne $value`)
- CI workflow updated to use shared PSScriptAnalyzer settings file

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
