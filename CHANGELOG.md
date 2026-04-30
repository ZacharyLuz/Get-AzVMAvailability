# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [2.2.1] — 2026-04-29
**Theme: Negotiated pricing for commercial regions, scan UX polish**

### Fixed
- **Commercial regions silently used retail prices despite a populated negotiated cache.** The Consumption Price Sheet API publishes `meterLocation` values in `<geoShort><locality>` form (`uswest`, `useast2`, `euwest`, `apsoutheast`, `jaeast`, `dewestcentral`), but the resolver compared them against ARM `<locality><geo>` names (`westus`, `eastus2`, `westeurope`, `southeastasia`, `japaneast`, `germanywestcentral`). Only sovereign aliases were in the lookup table, so every commercial scan logged `no negotiated rates for '<region>' — falling back to retail` even when 70k+ SKUs across 87 regions were sitting in the cache. Resolver now (a) consults a 70+ entry explicit ARM→cache alias table covering every public commercial region observed in EA price sheets, including the non-obvious `japaneast → jaeast` (“ja”, not “jp”), and (b) falls back to a generic geo-token permutation derived from `australia↔au`, `germany↔de`, `europe↔eu`, `asia↔ap`, `india↔in`, `korea↔kr`, `brazil↔br`, `canada↔ca`, `mexico↔mx`, `france↔fr`, `sweden↔se`, `norway↔no`, `switzerland↔ch`, `italy↔it`, `spain↔es`, `poland↔pl`, `israel↔il`, `denmark↔dk`, `austria↔at`, `belgium↔be`, `newzealand↔nz`, `malaysia↔my`, `indonesia↔id`, `taiwan↔tw`, `uae↔ae`, `qatar↔qa`, `southafrica→za` so future regions auto-resolve before the table is updated. The cache-miss diagnostic also stops claiming “No sovereign keys present in cache” for non-sovereign regions where that hint is irrelevant.
- **Misleading `Ns remaining` ETA stuck near 100%.** The parallel sub×region scanner divides remaining work by average throughput, but the last few items are usually slow regions / throttled subscriptions whose runtime exceeds the average by 5–20×. The bar would freeze at e.g. `1263 / 1266 · 11s remaining` while the final stragglers ran for several minutes. When `remaining ≤ max(3, 0.5%)`, the status now shows `finalizing N straggler(s)...` instead of an inaccurate countdown.
- **Progress bar lingered during regrouping.** After the parallel poll loop exited, the bar's last frame stayed visible in some terminals while the per-subscription `[N/total]` announce lines scrolled. The bar is now force-completed immediately after the poll loop, and `$ProgressPreference` is pinned to `SilentlyContinue` for the regrouping phase so any stray inner write can't redraw it.

### Added (tools)
- **`tools/Inspect-PriceSheetCache.ps1`** (companion repo) — read-only diagnostic that loads the on-disk Price Sheet cache and reports total regions/SKUs, lists every cache key, runs an ARM-name probe (direct lookup the way the resolver did pre-fix), runs an alias probe against suspected meterLocation conventions, and dumps a sample SKU entry. Output is teed to a timestamped `results.<yyyyMMdd-HHmmss>.log` with embedded ANSI color escapes so it renders identically when re-played in any modern terminal. Used to prove the `<geoShort><locality>` mismatch above without making any Azure API calls.

## [2.2.0] — 2026-04-28
**Theme: Sovereign Pricing, Reservation/Savings-Plan Quality, Lifecycle UX**

### Added
- **`-AZ` switch — Availability Zones in lifecycle reports** — Adds two new zone columns; auto-enabled by `-LifecycleRecommendations` so the default lifecycle XLSX now includes zones with no extra flags.
  - **`Zones (Deployed)`** on the **SubMap** and **Resource Group Map** sheets — shows the union of zones the affected VMs are *currently* deployed to (e.g., `1,2,3` or `Non-zonal`). Sourced from the ARG `zones` projection in live mode and from `Zone`/`Zones`/`AvailabilityZone` columns in file mode.
  - **`Zones (Supported)`** on the **Lifecycle Summary**, **High Risk**, and **Medium Risk** sheets, inserted between `Alt Score` and `CPU +/-` — shows OK / Limited / Restricted zones for the *recommended alternative* SKU in the deployed region (e.g., `✓ Zones 1,2 | ⚠ Zones 3`, `Non-zonal`). Cross-region fallback applied when the SKU isn't indexed in the deployed region.
  - The `-AZ` switch is also accepted on non-lifecycle paths for forward compatibility (no-op today).
- **Negotiated Savings Plan harvesting (commercial only)** — Consumption Price Sheet rows carrying a `savingsPlan` sub-object with `effectivePrice` are now bucketed into per-term SP maps and overlaid onto retail SP for the region. SP cells render without a `*` marker when the rate is negotiated (Price Sheet) and with `*` when retail-fallback. Sovereign clouds skip this overlay (Savings Plans not offered).
- **Advisory upgrade-path recommendations** — When a Microsoft-documented successor SKU (`data/UpgradePath.json`) is not deployable in any scanned region, an *advisory* recommendation row is now emitted with `Capacity = Advisory` so the migration target is still visible. Capability fields default to `0` (rendered as `-`) and the price columns show `priceMo = $null`. The "No alternatives" risk is no longer flagged just because the documented successor isn't in scanned regions; it is now reserved for the genuinely high-risk case where neither a same-family/compatible-profile match nor a documented successor is available.
- **Reservation Instance / Savings Plan savings as percentage** — `RI 1-Year Savings`, `RI 3-Year Savings`, `SP 1-Year Savings`, `SP 3-Year Savings` cells now render as `<marker><amount> (<pct>%)`, e.g. `*4,810 (37%)`. Percentages are computed **retail-vs-retail** (denominator = retail PAYG fleet total), so the figure represents the inherent commitment discount off list price; the customer's EA/MCA discount stacks on top.
- **Lifecycle Summary legend block** — A dedicated `LEGEND` section at the bottom of the Lifecycle Summary sheet documents every marker used across the lifecycle report family (`*`, `* (RI)`, `+N`, `-N`, `0`, `-`, zone glyphs, `Non-zonal`, `No alternatives`, `Advisory`). Banner spans `A:J`; marker cell merged `A:B`, meaning cell merged `C:J`. Zebra-striped rows with thin row separators for readability.

### Fixed
- **Issue 1 — Generalized quota text on Summary** — Stripped per-sub `Quota: need NxNvCPU` fragments from the Lifecycle Summary `Risk Reasons` column. Per-sub quota detail remains on the SubMap / RGMap sheets where it is meaningful.
- **Issue 2 — Missing ACU values for upgrade-path candidates** — Added cross-region ACU fallback: if a recommended alternative isn't indexed in the deployed region, scan all scanned regions for the same SKU before reporting `-`.
- **Issue 3 — Savings Plan columns shown for sovereign clouds** — Auto-detect `$script:TargetEnvironment` (AzureCloud / AzureUSGovernment / AzureChinaCloud) and omit `SP 1-Year Savings` / `SP 3-Year Savings` columns entirely for tenants where Savings Plans aren't offered. RI columns are still emitted.
- **Issue 4 — Empty RI / Spot pricing values** — Negotiated Consumption Price Sheet only carries PAYG meters today, so when the price sheet succeeded we silently dropped the retail container's `Reservation1Yr`, `Reservation3Yr`, `SavingsPlan1Yr`, `SavingsPlan3Yr`, and `Spot` maps. Pricing container is now an ordered hashtable that overlays negotiated PAYG on `Regular` while preserving the retail RI / SP / Spot maps from Tier 2, so RI / SP / Spot columns populate correctly in both commercial and sovereign clouds.
- **SP/RI savings percentages were inflated** — Earlier in development the SP/RI percent denominator was the merged (negotiated) PAYG price, which compressed against the customer's already-discounted bill and made `(pct%)` non-stackable with the existing EA discount. Container now also preserves the unmerged retail PAYG map as `RegularRetail`; the SP/RI denominator uses retail PAYG so the displayed % is apples-to-apples against list and stacks cleanly on top of the customer's contract discount.
- **Spot / Low-Priority meter poisoning of negotiated PAYG cache** — v1 cache stripped a `" Spot"` / `" Low Priority"` suffix off `meterName` then accepted those rows as Regular PAYG, causing first-write-wins to overwrite the on-demand rate with the Spot rate (≈1/8 the price) for any SKU whose Spot meter paged first. Real-world impact: `Standard_B16as_v2` showed ~$858/yr 1Y cost and a -$2,772 RI savings. Fix: hard-skip any meter matching `\b(Spot|Low Priority)\b` with a skip-reason counter; cache filename bumped (v1 → v2 → v3 → v4) and stale caches auto-deleted on first run.
- **Paired meter names not split** — Price Sheet rows like `D3 v2/DS3 v2` (one meter, two ARM SKUs) populated only one ARM size. Parser now splits on `/` and emits both `Standard_D3_v2` and `Standard_DS3_v2`. Cache schema bumped (`-v4-`) so old caches are invalidated.
- **Expired meter suffix not stripped** — Some meters carry an `" Expired"` suffix that prevented SKU resolution. Suffix is now stripped before normalization.
- **Gov Price Sheet meterLocation aliases** — Sovereign meters use display-form region names (`USGov Virginia`) while ARM uses normalized codes (`usgovvirginia`). Added candidate alias lists so price-sheet rows match across both forms.
- **`Cannot convert value "-" to type "System.Int32"` runtime error** — Advisory upgrade-path recs previously emitted string `'-'` sentinels for numeric capability fields (`vCPU`, `ACU`, `memGiB`, `IOPS`, `MaxDisks`, `score`), which crashed downstream `[int]` casts in the IOPS-match guard and capability-delta formatter. Numeric fields now default to `0`; the existing `-le 0` guards in the delta formatter render `0` as `-` for display, preserving the visual without the cast failures.
- **Advisory rec being shown alongside "No alternatives" risk** — The "No alternatives" reason was being baked into the risk string before the advisory injection ran. Risk emission is now deferred via a `$shouldFlagNoAlternatives` boolean so the advisory rec suppresses the high-risk flag when a documented successor exists.
- **Per-sub quota deficit double-counting** — Quota check passed `$qty * $sourceVcpu` as `RequiredvCPUs`, but that vCPU usage is already counted in `$qi.Current`. The check effectively asked "can I deploy 100% of my running fleet again on top of itself?" — guaranteed false-positive when fleet ≥ ½ quota. Per-sub deficit now flags only when `Current > Limit` (family genuinely over its cap). Reason text reworded: `Quota: family over limit in N of M deploying sub(s)`.
- **Quota-only current-gen rows polluting Summary** — Current-generation SKUs with no retirement / capacity / availability issue were emitted to Lifecycle Summary, High Risk, and Medium Risk solely because of a per-sub quota signal. Such rows are now flagged `_QuotaOnlyCurrentGen` and excluded from the three summary-style sheets while remaining on SubMap / RGMap where the quota signal is in context.
- **Plain `0` instead of `+0` / `±0` for zero deltas** — Capability and price diff columns now render a clean `0` for equal values (was `+0` for prices, `±0` sentinel for capabilities) which dodges Excel's formula parser and reads cleaner.
- **Dollar signs removed from price cells; price columns forced to text** — `-NoNumberConversion` keeps marker prefixes (`*`, `+`, `-`) intact; `$` removed so cells align with non-currency deltas.
- **Token refresh in scan worker** — Long-running parallel scans now refresh the bearer token mid-scan instead of erroring out with 401 floods. DateTimeOffset `ExpiresOn` from newer Az SDK handled.
- **Live progress timer + ETA** — Parallel sub × region scan now ticks a live timer with ETA instead of stalling silently. Timer freezes at scan complete.
- **Repeated grouping cells in SubMap/RGMap** — Continuation rows in grouped maps no longer repeat the subscription/RG name in every cell; the grouping cell is blanked so the visual hierarchy reads cleanly.

### Performance
- **Dedupe candidate pool in lifecycle recommendation loop (~100×)** — At-scale lifecycle phase reduced from ~7 hr to ~3–5 min on 196-sub × 224-SKU fleets by deduping the candidate pool before scoring.
- **Parallel cross-sub scan** — `ForEach-Object -Parallel` across subscriptions for the lifecycle/quota path; per-region+restriction dedup before scoring.
- **Tenant-wide ARG Advisor query** — Replaced N-subscription REST calls with a single tenant-wide `Microsoft.Advisor/recommendations` ARG query at module start.

### Added (tools)
- **`tools/Probe-PriceSheetRI.ps1`** — Discovery probe that walks a subscription's Consumption Price Sheet API and buckets meters across 6 tiers (PAYG, Reservation 1Yr/3Yr, Savings Plan 1Yr/3Yr, Spot) to determine whether negotiated RI / SP rates are available for the parser to harvest. Supports both commercial and sovereign tenants.
- **`tools/Dump-PriceSheetRaw.ps1`** — Captures every Price Sheet row verbatim (no source-side filtering) into per-page JSON files + zip for offline parser/schema design and support evidence.

### Documentation
- Legend `* (RI)` and `* (SP)` entries plus the `RI 3-Year Savings` header tooltip now document the `(pct%)` format and the retail-vs-retail basis with a worked stacking example: `70% RI cell + 20% EA discount ≈ 50% realized incremental discount on top of the customer's bill`.

## [2.1.1] — 2026-04-14

### Changed
- **Pipeline capture detection** — When users pipe `Get-AzVMAvailability` output interactively (e.g., `| Select-Object SKU`) and no objects emit, a yellow TIP now appears explaining the three ways to get structured data: `-JsonOutput`, file redirection (`>`), or `-AutoExport`. Zero overhead when using `-JsonOutput` or file redirection — the call stack check only runs in interactive-no-redirect mode.

### Documentation
- **ROADMAP accuracy** — Marked v2.0.0 and v2.1.0 as Released with all shipped items checked. Corrected backlog items (Module Structure, Shared Helpers) to reference v2.0.0 shipment.

## [2.1.0] — 2026-07-17

### Added
- **Smart default regions** — Default regions now auto-detect based on cloud environment and user timezone. Sovereign clouds (Gov, China) use their native regions; commercial cloud defaults match the user's local timezone geo (Americas, Europe, India/ME, APAC, Australia). New private function `Get-SmartDefaultRegions`.
- **PSGallery download tracking** — Traffic collector and CI workflow now fetch PSGallery total download counts alongside GitHub views/clones/stars.

### Documentation
- Split README into focused docs/ pages — README is now a concise landing page linking to 11 topic guides under `docs/`

### Fixed
- **Traffic dashboard off-by-one** — Date filtering in `dashboard.js` used `>=` cutoff comparison, making 7-day windows span 8 days. Fixed `filterByDays`, `windowData`, and `rollingDelta` to use `>` with non-overlapping window boundaries.
- **Traffic dashboard delta display** — Views and Clones delta percentages showed misleading "→ 0%" when no prior-period data existed. Now displays "— N/A" when `hasData` is false.

## [2.0.0] — Module Conversion

### Changed
- **Module conversion** — Converted standalone script into a production-grade PowerShell module (`AzVMAvailability/`) with Public/Private layout
- **Get-AzVMAvailability.ps1** — Now a thin wrapper script that imports the module and forwards all parameters; produces identical behavior to the previous monolith
- **FunctionsToExport** — Module exports only `Get-AzVMAvailability`; 43 helper functions are now truly private
- **Write-Host override** — Moved to module scope (`.psm1`) so all Private/ functions see the `-JsonOutput` suppression gate
- **Version** — Bumped to 2.0.0 in `.psd1` manifest

### Added
- **PSGallery publishing** — `release-publish.yml` workflow publishes to PowerShell Gallery on GitHub Release, with idempotency guard and version verification
- **Module artifact** — CI workflow now uploads packaged module as build artifact
- **Module tests** — `tests/Module.Tests.ps1` validates module import, exports, version, and private function isolation
- **Parameter parity tests** — `tests/ParameterParity.Tests.ps1` validates all 39 parameters (types, aliases, defaults, ValidateSet, ValidateRange)
- **PR Verification Gate** — `pr-verification-gate.yml` CI gate enforces Verification-First checklist with evidence-tagged landmark table
- **PR template** — Added Verification-First Checklist (Anti-Hallucination + Parity) section to PR template
- **Build script** — `tools/Build-PublicFunction.ps1` assembles the Public function from verified script boundaries

### No behavior changes
- All parameters, defaults, aliases, validation attributes, interactive prompts, JSON output schema, CSV/XLSX export shapes, and console output are identical to v1.14.0

### Changed
- **README audit** — Added "What's New" section; expanded Features list with lifecycle, placement, spot, JSON output, inventory, and deployment mapping; added 8 missing parameters to Parameters table (`-ShowSpot`, `-ShowPlacement`, `-DesiredCount`, `-NoQuota`, `-SubMap`, `-RGMap`, `-AllowMixedArch`, `-MaxRetries`); added `Az.ResourceGraph` to Requirements; added lifecycle/retirement and inventory use cases; added lifecycle row to Quick Comparison table
- **ROADMAP audit** — Marked 9 shipped backlog items as complete (Fleet Planning, Agent Integration, Module Structure, Backward-Compatible Wrapper, ARG Current VM Inventory, Cross-Subscription Discovery, Deployment Density, Spot Pricing)
- **Branch cleanup** — Deleted 19 stale remote branches (15 squash-merged, 4 abandoned); enabled `delete_branch_on_merge` repo setting to auto-delete PR branches after merge

### Added
- `.github/workflows/stale-branches.yml` — Weekly scheduled workflow that auto-deletes branches older than 30 days with no open PRs (protects `main` and `traffic-data`)

## [1.14.0] - 2026-04-01

### Added
- **`-SubMap` deployment mapping** — New switch parameter that produces a Subscription Map sheet in the lifecycle XLSX export. Groups affected VMs by subscription with VM count, SKU list, and region list. Works with both `-LifecycleScan` (ARG-based) and `-LifecycleRecommendations` (file-based). Enriches each row with Risk Level and Risk Reasons from lifecycle analysis results, with color-coded cells (red=High, amber=Medium, green=Low).
- **`-RGMap` deployment mapping** — New switch parameter that produces a Resource Group Map sheet with the same enrichment as `-SubMap` but grouped by subscription + resource group. Both flags can be used together.
- **SubscriptionId extraction from RESOURCE LINK** — When input files lack a dedicated SubscriptionId column (common with Azure portal exports), the subscription GUID is extracted from the `RESOURCE LINK` URL via regex. Falls back gracefully when neither source is available.
- **Deployment map in JSON output** — `deploymentMap` object with `groupBy` and `rows` properties included in `-JsonOutput` when `-SubMap` or `-RGMap` is set.
- **`-Tag` filter for `-LifecycleScan`** — New hashtable parameter to filter live VM inventory scans by Azure resource tags. Supports key=value matching (case-insensitive) and wildcard `'*'` value to match any VM with a given tag key. Multiple tags are AND-combined. Can be used alongside `-SubscriptionId`, `-ManagementGroup`, and `-ResourceGroup`.
- **`-RateOptimization` flag** — New switch parameter that gates Savings Plan (SP) and Reserved Instance (RI) columns in lifecycle reports. By default, only PAYG pricing columns are shown with `-ShowPricing`. Adding `-RateOptimization` includes 4 savings columns: `SP 1-Year Savings`, `SP 3-Year Savings`, `RI 1-Year Savings`, `RI 3-Year Savings` showing fleet-wide savings vs PAYG for each commitment term. SP/RI pricing API calls are skipped entirely when the flag is not set, improving performance.
- **Lifecycle Recommendations mode** — `-LifecycleRecommendations` accepts CSV, JSON, or XLSX files (including native Azure portal exports) of deployed VM SKUs. Runs compatibility-validated recommendations for each SKU and produces a consolidated lifecycle risk summary with old-gen flagging, capacity/quota analysis, and up to 6 alternatives per SKU. `-LifecycleScan` pulls live inventory via Resource Graph. `-NoQuota` skips quota API calls. JSON output supported via `-JsonOutput`.
- **Hybrid recommendation strategy (3 AI + up to 3 weighted)** — Each retiring/old-gen SKU receives up to 6 recommendations: 3 from a curated upgrade path knowledge base (`data/UpgradePath.json`) and up to 3 from the real-time weighted scoring algorithm. Upgrade path recommendations are labeled `Upgrade: Drop-in` (lowest risk), `Upgrade: Future-proof` (latest gen), and `Upgrade: Cost-optimized` (AMD/alternative). Weighted recommendations provide availability-verified alternatives based on the 8-dimension scoring engine. The knowledge base covers 19 SKU families (11 retired, 8 scheduled) with vCPU-matched size maps and Microsoft's official migration guidance.
- **Upgrade path knowledge base** — `data/UpgradePath.json` (programmatic) and `data/UpgradePath.md` (human-readable reference) document Microsoft's recommended upgrade paths for every retired or retiring VM SKU family. Each entry provides 3 upgrade options with size maps, requirements (Gen2 OS, NVMe driver, etc.), and rationale.
- **Details column** — New column appended to console output and all XLSX sheets explaining *why* each recommendation was selected. Shows upgrade path reasons from the knowledge base (e.g., "Same family, SCSI disk, Gen1+Gen2 — safest migration from Dv2; Requires: Gen2 OS image, NVMe driver"), family upgrade context (e.g., "D-family v2→v5 upgrade"), cross-family explanations, IOPS guarantees, and resize impact.
- **Compatibility gate** — `Test-SkuCompatibility` enforces hard requirements (vCPU, memory, NICs, accelerated networking, premium IO, disk interface, ephemeral OS, Ultra SSD, burstable exclusion, vCPU ceiling 2x max) before scoring. Extended `Get-SkuCapabilities` extraction and 8-dimension similarity scoring (disk IOPS + data disk count added as soft dimensions).
- **Lifecycle XLSX auto-export** — styled 3-sheet XLSX report (Lifecycle Summary, High Risk, Medium Risk) with color-coded risk levels, Azure-blue headers, alternating rows, conditional formatting, and summary footer. Risk sheets correctly group continuation rows by parent SKU.
- **Pricing comparison** — monthly cost delta (`Price Diff`) and fleet-wide impact (`Total`) columns in console. XLSX adds 4 dedicated columns: `SP 1-Year`, `SP 3-Year`, `RI 1-Year`, `RI 3-Year` showing per-unit full-term costs for each alternative. Uses Azure Retail Pricing API `api-version=2023-01-01-preview`. Requires `-ShowPricing`.
- **VM retirement detection** — `Get-SkuRetirementInfo` flags SKUs on Microsoft's published retirement schedule as High risk. Shows "Retired YYYY-MM-DD" or "Retiring YYYY-MM-DD" in Risk Reasons. Covers 11 retired series (Av1, Dv1, G/GS, H, HBv1, HC, NCv1, NCv2, NDv1, NVv1, Lsv1) and 8 scheduled retirements (Dv2, Dv3, Ev3, Fsv1, NCv3, NDv2, NVv3, Mv1).
- `tools/Check-PRReadyToMerge.ps1` — pre-merge gate that lists all unreplied non-owner comment threads on the current PR (paginated, fails closed on API errors); exits non-zero if any are open
- `tools/Audit-AllPRComments.ps1` — audits all merged PRs (fetched dynamically from GitHub) for unreplied top-level non-owner threads; used for historical backlog review
- `tools/Reply-StaleThreads.ps1` — bulk-replies to unreplied non-owner threads on old PRs with a stale-finding notice (paginated, fails closed on API errors)
- **Branch protection**: enabled `required_review_thread_resolution` on main — GitHub now blocks merge until all PR conversation threads are resolved

### Fixed
- Added `edited` trigger type to `release-metadata-guard.yml` so PR body checkbox changes re-run the guard without needing an empty commit workaround
- **Corrected retirement dates** — Updated `Get-SkuRetirementInfo` with verified dates from Microsoft Learn: Dv1 (2028-05-01), Dv2 (2028-05-01), Fsv1 (2028-11-15), NVv3 (2026-09-30). Added Bv1 (2028-11-15) and Lsv2 (2028-11-15). Removed Dv3/Ev3 (no retirement announced). Marked NCv3 as Retired.
- **Lifecycle modes exempt from 5-region limit** — `-LifecycleRecommendations` and `-LifecycleScan` now scan all deployed regions regardless of the 5-region cap. Previously, `-NoPrompt` auto-truncated to 5 regions, causing missing pricing data for SKUs deployed in truncated regions.
- **Upgrade path recommendations now show real scan data** — Upgrade path target SKUs (v5, v6, AMD variants) are included in the Azure SKU scan filter and looked up from raw scan data when they fail the compatibility gate against the source SKU. Previously all upgrade recs showed "Not scanned" with missing fields; now they show real capacity status, vCPU/memory/disk/IOPS deltas, and pricing from the deployed region.
- Current-gen SKUs (v4+) no longer flagged High risk when no alternatives exist and no capacity/retirement issues present
- `Group-Object SKU` deduplication no longer reorders recommendations — explicit score sort before selection
- Quota-only current-gen SKUs correctly show "Request quota increase" instead of alternative SKUs
- XLSX High/Medium Risk sheets correctly filter by parent risk level, not row-level risk
- Lifecycle Summary sort stability via explicit group/row sequence numbers
- `tools/Validate-Script.ps1`: added `else` branch so a missing `AzVMAvailability.psd1` now registers as a version mismatch instead of silently skipping validation; error messages now use `$psd1Path` variable instead of hard-coded path string
- `artifacts/copilot-review-log.md`: removed duplicate PR #105 triage block

### Changed
- Similarity scoring rebalanced to 8 dimensions (added disk IOPS 8pts, data disk count 7pts). JSON contract includes `maxDisks`, `maxNICs`, `iops` fields.
- Broadened `.gitignore` for session/handoff docs

## [1.13.0] - 2026-03-31

### Added
- **Write-Host gating** — module-qualified `Write-Host` override; `-JsonOutput` suppresses all console output via `$script:SuppressConsole` flag
- **Pipeline emit guard** — objects only emitted to pipeline when `[Console]::IsOutputRedirected` is true; prevents noise in interactive terminal sessions
- New test files: `ConvertFrom-Rest.Tests.ps1`, `WriteHost-Gating.Tests.ps1`, `Invoke-WithRetry.Tests.ps1`
- 61 new test assertions in `HelperFunctions.Tests.ps1`

### Changed
- **HttpClient REST scan engine** — concurrent SKU+quota first-page fetch via `System.Net.Http.HttpClient`; parallel region scan via runspaces; ~20% faster scans
- **O(1) capability lookup** — `_CapIndex` hashtable in `Get-CapValue` replaces linear scan
- Broadened `.gitignore` patterns for session/handoff docs (`docs/*handoff*`, `docs/*session-notes*`)
- Removed accidentally committed session docs from tracking (local copies preserved in `docs/archive/`)

### Fixed
- **HTTP 500 retry** — `Invoke-WithRetry` now retries `InternalServerError`/`500` in addition to `429`/`503`
- **Scan timer** — per-subscription timer now excludes one-time pricing phase (was inflating reported scan time)
- **Regex injection** — SKU filter replaced `-match` (user input as regex) with `-like` operator + input validation
- **Write-Host pipeline bug** — added `process {}` block so piped input is handled per-item
- Added `edited` trigger type to `release-metadata-guard.yml` so PR body checkbox changes re-run the guard without needing an empty commit workaround

## [1.12.5] - 2026-03-27
- Adding GitHub Codespaces Support
- Updating Documentation

## [1.12.4] - 2026-03-21

### Fixed
- Restored inline function fallback so single-file downloads work without the AzVMAvailability/ module directory
- Added try/catch around Import-Module with graceful fallback to 34 inline function definitions
- Fixed silent auth failure: Get-AzAccessToken now uses -ErrorAction Stop
- Added cache check in Get-AzVMPricing to skip redundant API calls
- Replaced silent catch in Test-ImportExcelModule with Write-Verbose

## [1.12.3] - 2026-03-21

### Changed
- **Module scaffold:** Extracted all 34 functions from monolithic `Get-AzVMAvailability.ps1` into `AzVMAvailability/` module with Private/ subdirectory layout (#5)
- Root script now imports `AzVMAvailability` module instead of defining functions inline (2,028 lines removed from main script)
- Removed dead `$script:CachedValidRegions` variable

### Added
- `AzVMAvailability/AzVMAvailability.psd1` -- module manifest (declares Az module dependencies)
- `AzVMAvailability/AzVMAvailability.psm1` -- dependency-ordered dot-source loader
- 34 function files across `Private/Azure/`, `Private/SKU/`, `Private/Image/`, `Private/Fleet/`, `Private/Format/`, `Private/Utility/`
- `Find-FunctionInModule` in TestHarness.psm1 -- module-aware function discovery with AST caching and parse error checking

## [1.12.2] - 2026-03-20

### Fixed
- Synced 4 stale version references to 1.12.2: README badge, README sample output, ROADMAP Current Release, demo/DEMO-GUIDE.md
- Expanded `Validate-Script.ps1` Check 5 with 2 new validation points (README sample output, demo/DEMO-GUIDE.md) — now validates 7 locations for version drift

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
