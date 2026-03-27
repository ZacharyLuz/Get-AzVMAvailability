# GitHub Copilot Instructions

## Tech Stack & Architecture

- **Primary Language:** PowerShell 7+
- **Cloud Platform:** Microsoft Azure (requires Az PowerShell modules)
- **Purpose:** Scans Azure regions for VM SKU availability, capacity, quota, pricing, and image compatibility.
- **Key Scripts:** All main logic is implemented in PowerShell scripts; no Node.js, Python, or other language dependencies.

## Key Files & Directories

- `Get-AzVMAvailability.ps1`: Main script for multi-region, multi-SKU Azure VM capacity and quota scanning.
- `dev/`: Experimental and advanced scripts, including:
  - `Azure-VM-Capacity-Planner.ps1`
  - `Azure-SKU-Scanner-Fast.ps1`
  - `Azure-SKU-Scanner-All-Families.ps1`
  - `Azure-SKU-Scanner-All-Families-v2.ps1`
- `tests/`: Pester tests for endpoint and logic validation.
- `examples/`: Usage examples and ARG queries.
- `.github/ISSUE_TEMPLATE/`: Issue templates for bug reports and feature requests.

## Build, Test, and Run

- **Run Main Script:**
  ```powershell
  .\Get-AzVMAvailability.ps1
  ```
- **Run Tests:**
  ```powershell
  Invoke-Pester .\tests\Get-AzureEndpoints.Tests.ps1 -Output Detailed
  ```
- **Requirements:**
  - PowerShell 7+
  - Az.Compute, Az.Resources modules
  - Azure login (`Connect-AzAccount`)

## Project Conventions

- **Parameterization:** Scripts prompt for SubscriptionId and Region if not provided.
- **Exports:** Results can be exported to CSV/XLSX (default export paths: `C:\Temp\...` or `/home/system` in Cloud Shell).
- **Parallelism:** Uses `ForEach-Object -Parallel` for fast region scanning.
- **Color-coded Output:** Capacity and quota status are visually highlighted.
- **No Azure CLI dependency:** Only Az PowerShell modules required.

## Branch Protection

- Main/master branches are protected from deletion and require PRs for changes.

## Release Process

- **All changes to main must go through PRs** — direct pushes are blocked by repository rules.
- **Tag and release only after PR merge** — never tag before merging.
- For detailed workflow, see [release-process-guardrails/SKILL.md](skills/release-process-guardrails/SKILL.md).

## PR Body Formatting Standard

- PR descriptions must be valid rendered Markdown (no literal escaped newline text like `\n`).
- When using GitHub CLI, prefer `--body-file` over inline `--body` for multi-line content.
- If using `--body`, build it from a PowerShell here-string to preserve real newlines.
- Before merging, verify rendered content with:
  - `gh pr view <pr-number> --json body --jq .body`

## PR Review Comment Triage Standard

- Before implementing additional changes on an active PR branch, always pull the latest PR review feedback first.
- Required commands:
  - `gh pr view <pr-number> --json reviews,comments --jq '.reviews[] | {author: .author.login, submittedAt: .submittedAt, body: .body}'`
  - `gh api repos/<owner>/<repo>/pulls/<pr-number>/comments --jq '.[] | {author: .user.login, path: .path, line: (.line // .original_line), body: .body, created_at: .created_at}'`
- Resolve or explicitly disposition each comment before moving to the next remediation item.
- **GitHub Copilot auto-reviews every PR.** After fetching comments, filter for the Copilot reviewer and assess each finding:
  - Classify each as: **Agree** / **Disagree** / **Partially Agree**
  - Append assessment to `artifacts/copilot-review-log.md` (never overwrite — always append)
  - Fix all Agree/Partially-Agree findings before merging
  - Add inline suppression comments in source for justified Disagree findings
  - Log entry format: PR number, branch, commit SHA, file:line, Copilot finding (quoted), assessment, specific reasoning (reference project context), action taken

## Contribution & Security

- See `CONTRIBUTING.md` for guidelines.
- See `SECURITY.md` for vulnerability reporting.
- **Always update `CHANGELOG.md`** when making functional changes (new features, bug fixes, breaking changes).

## Additional Notes

- All scripts are MIT licensed.
- For advanced usage, see scripts in `dev/` and documentation in `README.md` and `examples/`.

## Code Quality Guardrails

### Before Every Commit
Run the validation script to catch issues before they reach GitHub:
```powershell
.\tools\Validate-Script.ps1
```
This runs five checks: syntax validation, PSScriptAnalyzer linting, Pester tests, AI-comment pattern scan, and version consistency.

### Linting
- PSScriptAnalyzer settings are in `PSScriptAnalyzerSettings.psd1` at the repo root.
- The same settings file is used by VS Code (on-save) and CI (GitHub Actions).
- To run manually: `Invoke-ScriptAnalyzer -Path . -Recurse -Settings PSScriptAnalyzerSettings.psd1`

### Comment Standards
- **Keep** comments that explain *why* something non-obvious is done.
- **Remove** comments that restate what the next line of code does.
- **Never** leave instructional comments like "Must be after", "This ensures", "Handle potential" — these are AI artifacts.
- Use `#region`/`#endregion` for section organization, not `# ===` ASCII banners.

### Constants and Magic Numbers
- All numeric literals with non-obvious meaning must be named constants in the `#region Constants` block.
- Example: `$HoursPerMonth = 730` instead of bare `730`.

### Error Handling
- Every `catch` block must have at least `Write-Verbose` — no silent `catch { }`.
- API calls should use `Invoke-WithRetry` for transient error resilience (429, 503, timeouts).

---

## Architecture Details

- **Script metrics (current):** 4,442 lines, 34 functions, 349 `Write-Host` calls,
  0 `Write-Output` calls, 0 `exit` calls, 0 pipeline-emitted objects.
- **`$script:RunContext`** — centralized runtime state object. All functions should
  access state through this object — however, several functions still read parent-scope
  variables implicitly (see Known Technical Debt below). Contains caches, pricing
  maps, image requirements, and output contracts.
- **`Invoke-WithRetry`** — exponential backoff wrapper for all Azure API calls.
  Handles 429 (with Retry-After header), 503, WebException, HttpRequestException.
  Does NOT yet handle HTTP 500 (transient ARM error). Always wrap new Azure API calls.
- **JSON contracts** — `New-RecommendOutputContract` / `New-ScanOutputContract`
  include `schemaVersion`. Never change field names without a version bump.
- **TestHarness.psm1** — AST-based function extraction for Pester test isolation.
  Do not use dot-sourcing for test isolation.
- **Parallel scanning** — `ForEach-Object -Parallel` with explicit `$using:`
  references. The parallel block duplicates retry logic inline (necessary — parallel
  runspaces cannot see script-scope functions).
- **Test suite** — 189 Pester tests across 11 files. Always redirect Pester output
  to log file: `Invoke-Pester ... *> artifacts/test-run.log`

## Known Technical Debt

These are confirmed issues from code review. The agent should know them without
having to rediscover them by reading 4,442 lines.

### Performance Hotspots (exact locations)
| Line | Issue | Status |
|------|-------|--------|
| **3470** | `$familyDetails` per-SKU loop accumulation | **Fixed** — converted to `List[PSCustomObject]` + `.Add()` |
| **3403** | `$rows` per-family per-region accumulation | **Fixed** — converted to `List[T]` + `.Add()` |
| **1041–1057** | `$zonesOK/Limited/Restricted` in `Get-RestrictionDetails` | **Fixed** — converted to `List[string]` + `.Add()` |
| **3242** | `$allSubscriptionData += @{...}` per-subscription | Low impact (1–3 iterations typically) |
| **~862** | `Get-CapValue` uses `Where-Object` pipeline (~18,000 calls per scan) | Pre-index SKU capabilities as hashtable at scan time |
| **~2498+** | Pricing fallback is all-or-nothing: one failure abandons all regions to retail | Per-region fallback |

### Parent-Scope Implicit Dependencies (blocks module extraction)
These functions read variables from the parent scope without receiving them as
parameters. Every one is a hidden wire that must be cut before module conversion.

| Function | Hidden variable | Fix for v2.0.0 |
|----------|----------------|----------------|
| `Get-StatusIcon` | `$Icons` | Add `-Icons` parameter |
| `Get-SkuCapabilities` | `$MBPerGB` | Inline constant (1024) or add parameter |
| `Get-SkuSimilarityScore` | `$script:FamilyInfo` | Add `-FamilyInfo` parameter |
| `Write-RecommendOutputContract` | `$FamilyInfo`, `$Icons` | Add both as parameters |
| `Invoke-RecommendMode` | 10+ parent-scope vars | Convert to `Get-AzVMRecommendation` cmdlet with all as explicit params |
| `Get-AzVMPricing` | `$script:RunContext.Caches`, `$HoursPerMonth`, `$MaxRetries`, `$script:AzureEndpoints` | Pass `$Cache` hashtable + endpoints as parameters |
| `Get-AzActualPricing` | Same as above + `$script:RunContext.Caches.PlacementWarned403` | Same fix |
| `Get-PlacementScores` | `$MaxRetries`, `$script:RunContext.Caches.PlacementWarned403` | Add `-MaxRetries` param, pass cache |
| `Get-ValidAzureRegions` | `$MaxRetries`, `$script:RunContext.Caches`, `$script:AzureEndpoints` | Add params |

### `exit` vs `throw` — **Fixed**
All 9 original `exit` calls (Lines 394, 2611, 2691, 2697, 2733, 2762, 2793, 3597, 3642)
have been replaced with `throw` (error paths) and `return` (user-initiated cancellation).
The script no longer kills the caller's session when dot-sourced or called from another script.

### Pipeline Composability (zero pipeline output)
The script emits nothing to the pipeline — all data rendered via `Write-Host`.
`$familyDetails` (built at L3470) and the output contracts contain properly
structured `[PSCustomObject]` arrays but are never emitted. The minimal fix is
adding `$familyDetails` output after the processing loop for non-JSON mode.

### Module Conversion — Function Extraction Order (v2.0.0)
Extract in this order to minimize risk:

**Phase 1 — Zero risk (no dependencies):** `Get-SafeString`, `Get-GeoGroup`,
`Get-SkuFamily`, `Get-ProcessorVendor`, `Get-DiskCode`, `Get-RestrictionReason`,
`Format-ZoneStatus`, `Format-RegionList`, `Get-QuotaAvailable`,
`Test-SkuMatchesFilter`, `Get-ImageRequirements`, `Test-ImageSkuCompatibility`,
`Get-InventoryReadiness`, `Write-InventoryReadinessSummary`

**Phase 2 — Minor coupling (fix hidden deps):** `Get-StatusIcon`, `Get-SkuCapabilities`,
`Get-SkuSimilarityScore`, `Get-RestrictionDetails`

**Phase 3 — Azure API functions:** `Invoke-WithRetry`, `Get-AzureEndpoints`,
`Get-ValidAzureRegions`, `Get-AzVMPricing`, `Get-AzActualPricing`,
`Get-PlacementScores`, `Get-RegularPricingMap`, `Get-SpotPricingMap`

**Phase 4 — Recommend engine:** `Invoke-RecommendMode` → `Get-AzVMRecommendation`

**Phase 5 — Export:** XLSX/CSV block (L4047–4442, ~395 lines) → `Export-AzVMAvailabilityReport`

**Phase 6 — Interactive shell:** Prompts (L2599–3060, ~461 lines) → optional
`Invoke-AzVMAvailabilityWizard` wrapper

### Target Module Structure (v2.0.0)
```
AzVMAvailability/
├── AzVMAvailability.psd1
├── AzVMAvailability.psm1
├── Public/
│   ├── Get-AzVMAvailability.ps1        # scan (emits objects)
│   ├── Get-AzVMRecommendation.ps1      # current Invoke-RecommendMode
│   └── Export-AzVMAvailabilityReport.ps1
├── Private/
│   ├── Azure/   (endpoints, regions, pricing, retry)
│   ├── SKU/     (family, capabilities, similarity, restrictions, filter)
│   ├── Image/   (requirements, compatibility)
│   ├── Inventory/   (readiness, summary)
│   ├── Format/  (icons, zone status, recommend output)
│   └── Utility/ (SafeString, GeoGroup, SubscriptionContext)
└── Get-AzVMAvailability.ps1            # thin backward-compat wrapper
```

### Cmdlet Naming Convention
Az module convention uses `AzVM` (capital VM), not `AzVm`. Always follow:
`Get-AzVMAvailability`, `Get-AzVMRecommendation`, `Export-AzVMAvailabilityReport`
**Not:** `Get-AzVmAvailability`, `Get-AzVmRecommendation` (Copilot gets this wrong).

### Internal Process Artifacts
`docs/REMEDIATION-PROGRAM.md` and `docs/REMEDIATION-TODO.md` are internal
execution trackers that should not be in a public repo. They signal "this project
had problems that needed a formal remediation program." Options: remove via PR,
move to gitignored directory, or reframe as architecture decision records (ADRs)
with a forward-looking tone. Do not commit new files of this type.

---

## Roadmap

| Version | Theme | Status | Key Work |
|---------|-------|--------|----------|
| v1.12.0 | Inventory MVP | **Released** | `-Inventory` hashtable BOM validation, `Get-InventoryReadiness`, `Write-InventoryReadinessSummary`, fuzzy quota matching, used/available/limit display (originally shipped as `-Fleet`, aliases preserved) |
| v1.12.1 | Inventory UX | **Released** | `-InventoryFile` CSV/JSON input, `-GenerateInventoryTemplate`, example files, README Quick Start, input validation (`-LiteralPath`, trim, qty guard) (originally `-FleetFile`/`-GenerateFleetTemplate`, aliases preserved) |
| v2.0.0 | Module Conversion | Planned | Public/Private layout, PSGallery publishing, gate 349 Write-Host behind `-JsonOutput` (#65), pipeline composability, `exit` → `throw` |
| v2.1.0 | MCP Server | Planned | 4 tools: `check_vm_availability`, `find_alternatives`, `get_vm_pricing`, `check_quota` — depends on v2.0.0 |
| v2.2.0 | Proactive Monitoring | Planned | Watch mode, capacity alerts, Azure Monitor, Azure Functions |
