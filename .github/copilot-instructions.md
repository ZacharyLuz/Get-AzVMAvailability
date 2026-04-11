# GitHub Copilot Instructions

## Anti-Hallucination Rules (Non-Negotiable)

### Verification-First Requirement
Before proposing refactors, architecture diagrams, or structural claims:
1. Inventory the repo structure (top-level files/folders).
2. Verify entrypoints (script vs module).
3. Produce a **Verified Landmark Table** with columns: What you observed | How you observed it (read/search) | What remains unknown.

### No "Plausible Precision"
You MUST NOT invent or estimate:
- Line numbers, file lengths, or "near end of file" claims
- Section boundaries or function counts
- Test counts or Write-Host call counts

If you need counts, **compute them** from the current branch via search/AST and report as "observed."

### Evidence Tags
Any structural statement MUST be tagged:
- **[OBSERVED]** — read directly from file
- **[SEARCHED]** — found via grep/search
- **[PROVIDED]** — user stated
- **[INFERRED]** — hypothesis (cannot be used as a dependency for plans)

Plans and refactors may rely ONLY on [OBSERVED], [SEARCHED], or [PROVIDED] facts.

### Large File Reasoning
When reasoning about files >1,500 lines:
- Treat the file as segmented — do not assume you know what follows a given anchor.
- Default to "file continues" unless EOF is explicitly observed.
- Use function definitions and `#region` markers for navigation, **never** line numbers.

### Retractions
If an earlier assumption is wrong: retract it explicitly, explain why, and recompute downstream reasoning.

### Confidence Rule
If you are not 100% certain about a structural fact, you MUST say "I don't know yet." Confidence without verification is an error.

---

## Project Goal

The standalone `Get-AzVMAvailability.ps1` script has been converted into a **production-grade PowerShell module** (`AzVMAvailability/`) preserving **100% behavioral parity**.

- **Do not add new features.** Changes are allowed only for: modularization, testing, validation, CI/CD packaging, and publishing.
- Publishing targets: **PowerShell Gallery (PSGallery)** + **GitHub Releases**.
- Private function extraction into `AzVMAvailability/Private/` is **complete** (43 functions across 6 subdirectories).
- Public function `Get-AzVMAvailability` wraps the orchestration body in `AzVMAvailability/Public/`.
- `Get-AzVMAvailability.ps1` at repo root is now a **thin wrapper** that imports the module and forwards `@PSBoundParameters`.
- See `ROADMAP.md` for the full version plan.

---

## Tech Stack & Architecture

- **Primary Language:** PowerShell 7+
- **Cloud Platform:** Microsoft Azure (Az PowerShell modules)
- **Purpose:** Scan Azure regions for VM SKU availability, capacity, quota, pricing, image compatibility, lifecycle risk, and upgrade paths.
- **No Azure CLI dependency** — only Az PowerShell modules required.

---

## Key Files & Directories

- `Get-AzVMAvailability.ps1` — **Thin wrapper script** that imports the module and forwards all parameters. Preserves backward compatibility for users who run the script directly.
- `AzVMAvailability/` — **Module folder** (authoritative source):
  - `AzVMAvailability.psd1` — Module manifest (v2.0.0, exports only `Get-AzVMAvailability`).
  - `AzVMAvailability.psm1` — Module loader: Write-Host override at module scope, dot-sources Private/ in dependency order, then Public/.
  - `Public/Get-AzVMAvailability.ps1` — The primary exported function containing the full orchestration body.
  - `Private/Azure/` — Endpoint, region, pricing, retry functions (11 files).
  - `Private/SKU/` — Family, capabilities, similarity, restrictions, filter, retirement (12 files).
  - `Private/Image/` — Image requirements and compatibility (2 files).
  - `Private/Inventory/` — Readiness validation and summary (2 files).
  - `Private/Format/` — Icons, zone status, recommend output, contracts (7 files).
  - `Private/Utility/` — SafeString, GeoGroup, QuotaAvailable, context management (9 files).
- `functions/` — ⚠️ **Legacy reference copies only.** Not loaded by the module. Do not edit these files — the authoritative source is `AzVMAvailability/Private/`.
- `config/` — Reference copy of configuration (documentation only, not executed).
- `data/` — Knowledge base files (`UpgradePath.json`, `UpgradePath.md`).
- `tests/` — Pester test suite (`TestHarness.psm1` + unit/integration test files).
- `tools/` — Validation and CI helper scripts (`Validate-Script.ps1`, `Build-PublicFunction.ps1`, etc.).
- `backups/` — Pre-conversion backups of the monolith script and other files.
- `dev/` — Experimental and advanced scripts.
- `examples/` — Usage examples and ARG queries.
- `.github/workflows/` — CI/CD workflows: lint + test, release metadata guard, release-on-main, release-publish (PSGallery), PR verification gate, scheduled health check, traffic collection, stale branch cleanup.
- `.github/ISSUE_TEMPLATE/` — Bug report and feature request templates.
- `copilot-standing-rules.md` — 5 non-negotiable standing rules (never delete files, atomic commits, backup before changes, validate before commit, PR comment triage). See that file for details.

---

## Build, Test, and Run

### Preferred: Full Validation
```powershell
.\tools\Validate-Script.ps1
```
Runs six checks: syntax validation, PSScriptAnalyzer linting, Pester tests, AI-comment pattern scan, version consistency, and gh CLI anti-pattern detection.

### Run via Module (recommended)
```powershell
Import-Module .\AzVMAvailability
Get-AzVMAvailability -Region eastus -NoPrompt
```

### Run via Wrapper Script (backward compatible)
```powershell
.\Get-AzVMAvailability.ps1 -Region eastus -NoPrompt
```

### Run Tests
```powershell
Invoke-Pester -Path .\tests -Output Detailed
```
Always redirect Pester output to log file in CI: `Invoke-Pester ... *> artifacts/test-run.log`

### Requirements
- PowerShell 7+
- Required modules: `Az.Accounts`, `Az.Compute`, `Az.Resources`
- Optional: `ImportExcel` (XLSX export), `Az.ResourceGraph` (`-LifecycleScan` mode)
- Azure login: `Connect-AzAccount`

---

## Current Parameters

All 39 parameters are preserved with identical names, types, defaults, aliases, and validation attributes. See `Get-Help Get-AzVMAvailability -Full` after module import for complete reference. Key parameter groups:

- **Region & Subscription**: `SubscriptionId` (aliases: SubId, Subscription), `Region` (alias: Location), `RegionPreset`, `Environment`, `SkipRegionValidation`
- **Filtering**: `FamilyFilter`, `SkuFilter`, `ImageURN`
- **Pricing & Placement**: `ShowPricing`, `ShowSpot`, `ShowPlacement`, `DesiredCount`, `RateOptimization`
- **Recommend Mode**: `Recommend`, `TopN`, `MinScore`, `MinvCPU`, `MinMemoryGB`, `AllowMixedArch`
- **Lifecycle Analysis**: `LifecycleRecommendations`, `LifecycleScan`, `ManagementGroup`, `ResourceGroup`, `Tag` (alias: Tags), `SubMap`, `RGMap`
- **Inventory Readiness**: `Inventory` (alias: Fleet), `InventoryFile` (alias: FleetFile), `GenerateInventoryTemplate` (alias: GenerateFleetTemplate)
- **Output & Behavior**: `NoPrompt`, `NoQuota`, `JsonOutput`, `AutoExport`, `ExportPath`, `OutputFormat`, `CompactOutput`, `EnableDrillDown`, `UseAsciiIcons`, `MaxRetries`

---

## Behavior Parity Guardrail

The module must produce **identical behavior** to the original script for all existing parameters, modes, and output formats.

**Do not change:**
- Parameter names, types, defaults, aliases, or validation attributes
- Interactive prompting behavior (except where `-NoPrompt` / `-JsonOutput` already suppress it)
- JSON schema emitted by `-JsonOutput`
- CSV/XLSX export column names and shapes
- Error behavior and throw/return semantics

**If a behavior change seems necessary**, STOP and document:
1. Current behavior (observed, with evidence)
2. Proposed change
3. Why it is unavoidable
4. How backward compatibility will be preserved (shim/wrapper)

---

## Module Conventions

### Cmdlet Naming
Az module convention uses `AzVM` (capital VM), not `AzVm`. Always follow:
- ✅ `Get-AzVMAvailability`, `Get-AzVMRecommendation`, `Export-AzVMAvailabilityReport`
- ❌ `Get-AzVmAvailability`, `Get-AzVmRecommendation` (Copilot gets this wrong)

### Pipeline & Output
- Preserve current UX: `Write-Host` for interactive terminal, structured output for `-JsonOutput`.
- Pipeline objects are emitted only when `[Console]::IsOutputRedirected` is true.
- Do not introduce unconditional pipeline emission.
- Any pipeline changes must be explicitly parity-tested.

### Error Handling
- No silent catch blocks — every `catch` must have at least `Write-Verbose`.
- Prefer terminating errors with actionable messages.
- Do not kill caller sessions — use `throw` (error paths) and `return` (user cancellation), never `exit` in reusable code.
- API calls should use `Invoke-WithRetry` for transient error resilience (429, 500, 503, timeouts).

---

## Code Quality Guardrails

> See also `copilot-standing-rules.md` for the 5 non-negotiable standing rules (never delete files, atomic commits, backup before changes, validate before commit, PR comment triage).

### Before Every Commit
```powershell
.\tools\Validate-Script.ps1
```

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

### gh CLI Script Patterns
Scripts in `tools/` that call `gh api` or `gh pr` must follow these rules:
- Every `gh api` call MUST use `--paginate` unless you explicitly want only page 1.
- Every `gh api` / `gh pr` call MUST capture output to a variable, then check `$LASTEXITCODE -ne 0` before proceeding.
- Never use `2>$null` on `gh` commands — use `2>&1` and inspect the error.
- CI gate scripts MUST be fail-closed: any API error → `exit 1`, never silently `exit 0`.
- Remove debug/preview variables before committing — PSScriptAnalyzer catches unused assignments.

---

## Branch Protection & Release Process

- Main/master branches are protected from deletion and require PRs for changes.
- **All changes to main must go through PRs** — direct pushes are blocked by repository rules.
- **Tag and release only after PR merge** — never tag before merging.
- For detailed workflow, see [release-process-guardrails/SKILL.md](skills/release-process-guardrails/SKILL.md).

---

## PR Standards

### PR Body Formatting
- PR descriptions must be valid rendered Markdown (no literal escaped newline text like `\n`).
- When using GitHub CLI, prefer `--body-file` over inline `--body` for multi-line content.
- If using `--body`, build it from a PowerShell here-string to preserve real newlines.
- Before merging, verify rendered content with:
  - `gh pr view <pr-number> --json body --jq .body`

### PR Review Comment Triage
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

---

## Architecture Concepts

Do not rely on static metrics. Line counts, function counts, and test counts change frequently. Discover current values via search/AST.

- **Module structure** — `AzVMAvailability.psm1` defines a Write-Host override at module scope (gates output when `-JsonOutput` is active via `$script:SuppressConsole` flag), then dot-sources Private/ in dependency order, then Public/. The override delegates to `Microsoft.PowerShell.Utility\Write-Host` when not suppressed.
- **`$script:RunContext`** — centralized runtime state object initialized in `Get-AzVMAvailability`. Contains caches, pricing maps, image requirements, and output contracts.
- **`Invoke-WithRetry`** — exponential backoff wrapper for all Azure API calls. Handles 429 (with Retry-After header), 500, 503, WebException, HttpRequestException. Always wrap new Azure API calls.
- **JSON contracts** — `New-RecommendOutputContract` / `New-ScanOutputContract` include `schemaVersion = '1.0'`. Never change field names without a version bump.
- **Pipeline emit guard** — `$familyDetails` emitted to pipeline only when `[Console]::IsOutputRedirected` is true. In interactive mode, objects are suppressed to preserve the Write-Host UX.
- **O(1) capability lookup** — SKU capabilities are pre-indexed into a `_CapIndex` hashtable at scan time. `Get-CapValue` checks this index first, falling back to `Where-Object` pipeline.
- **TestHarness.psm1** — Dual-path function extraction: tries `AzVMAvailability/Private/` module files first, falls back to AST parsing for backward compatibility. Do not use dot-sourcing for test isolation.
- **Parallel scanning** — `ForEach-Object -Parallel` with explicit `$using:` references. The parallel block duplicates retry logic inline (necessary — parallel runspaces cannot see module-scope functions).
- **`$ScriptVersion`** — In the wrapper script, this is a static string for `Validate-Script.ps1` version parity checks. In the Public function, this is derived dynamically from `(Get-Module AzVMAvailability).Version.ToString()`.

---

## Contribution & Security

- See `CONTRIBUTING.md` for guidelines.
- See `SECURITY.md` for vulnerability reporting.
- **Always update `CHANGELOG.md`** when making functional changes (new features, bug fixes, breaking changes).
- All scripts are MIT licensed.
- See `ROADMAP.md` for version plan and priorities.
