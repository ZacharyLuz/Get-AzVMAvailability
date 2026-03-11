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

## Safe File Editing Practices

When making code changes to PowerShell scripts, follow these guidelines to avoid file corruption:

### Small, Targeted Edits
- **Make small, focused edits** rather than large structural changes in a single operation.
- When fixing indentation or brace structure, edit one block at a time.
- Avoid combining multiple unrelated changes into one replacement.

### Verify After Every Edit
- **Always verify syntax immediately** after each edit using:
  ```powershell
  [scriptblock]::Create((Get-Content 'script.ps1' -Raw)) | Out-Null
  # Returns True if valid, throws error if invalid
  ```
- Run `git diff` to inspect changes before testing the script.

### Git as Safety Net
- **Commit frequently** before making structural changes.
- Use `git checkout HEAD -- <file>` to restore from last commit if edits corrupt the file.
- The `replace_string_in_file` tool can fail silently or make unexpected changes if the `oldString` doesn't match exactly (whitespace, newlines matter!).

### Common Pitfalls
- Large replacement blocks can misalign if whitespace doesn't match character-for-character.
- Removing `else` blocks or changing loop structures requires careful brace counting.
- When code ends up in the wrong location after an edit, restore from git and retry with smaller edits.

### Testing Requirements
- Run Pester tests after changes: `Invoke-Pester .\tests\*.Tests.ps1 -Output Detailed`
- Requires Pester v5+ (install with: `Install-Module Pester -Force -SkipPublisherCheck`)

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

## Current Project Status

### Shipped Versions (on `main`)
| Version | Theme |
|---------|-------|
| 1.0–1.2 | Foundation — parallel scanning, zone details, quota, matrix |
| 1.3 | Pricing — Retail Prices API, `$ShowPricing` |
| 1.4 | Images — image compatibility checker, 16 common images |
| 1.5 | Negotiated Pricing — EA/MCA/CSP via Cost Management API |
| 1.6 | Cloud Shell — fixed-width tables, XLSX legend, terminal width |
| 1.7 | Code Quality — PSScriptAnalyzer, retry logic, `#region` blocks |
| 1.8 | Recommender — `-Recommend`, similarity scoring, `-JsonOutput` |
| 1.9 | Interactive Recommend — post-scan prompt, region validation |
| 1.10.0 | Fleet Safety — CPU/Disk columns, arch filtering, `-AllowMixedArch` |
| **1.10.1** | **Remediation — Phase 0–4 hardening (current `main`)** |

### In Progress: v1.11.0 (branch: `feature/placement-score-phase1`)
**DONE:** `Get-PlacementScores`, `-ShowPlacement` switch, placement in filtered
scan, spot pricing split in `Get-AzVMPricing`, `-ShowSpot` switch, JSON contract
fields (`placementEnabled`, `spotPricingEnabled`, `allocScore`, `spotPriceHr`,
`spotPriceMo`), tests (`PlacementScore.Tests.ps1`, `SpotPricing.Tests.ps1`,
`RecommendJsonContract.Tests.ps1`), RunContext bug fix (uncommitted — adds missing
`ShowPlacement`, `DesiredCount`, `AzureEndpoints` properties).

**NOT DONE:** Interactive prompts for `-ShowPlacement`/`-ShowSpot`, version bump
to 1.11.0, CHANGELOG `[Unreleased]` → `[1.11.0]`.

### Interactive Prompt Coverage Gap (affects v1.11.0 and beyond)
Several switches added across recent versions have **no interactive prompt path** —
users must know to pass them explicitly, which breaks the unified UX where the
script guides users through available options at runtime.

**Switches that require interactive prompts to be added:**
- `-ShowPlacement` — added in v1.11.0, switch-only
- `-ShowSpot` — added in v1.11.0, switch-only
- Any switches added during Phase 0–4 remediation (v1.10.1) that were
  not wired into the interactive prompt flow at the time

**Design requirement:** Every user-facing switch that affects output or behavior
must have a corresponding interactive prompt that fires when the switch is not
explicitly provided. The prompt must:
1. Be skipped entirely when `$script:RunContext.NoPrompt` is `$true`
2. Mirror the tone and style of existing prompts (see the post-scan recommend
   prompt as the reference implementation)
3. Default to `$false` / "No" so that non-interactive/automation callers are
   unaffected if `-NoPrompt` is accidentally omitted
4. Be placed at the appropriate point in the execution flow (after scan completes,
   before output rendering) — not at script startup

**Goal:** A user who runs `.\Get-AzVMAvailability.ps1` with no switches must be
offered the same capabilities as a user who knows every switch by name. The
interactive flow is the UX contract; switches are the automation contract.
Both must reach full feature parity.

---

## Architecture Details

- **`$script:RunContext`** — centralized runtime state object. All functions access
  state through this object only — never via implicit parent scope reads. Contains
  caches, pricing maps, image requirements, and output contracts.
- **`Invoke-WithRetry`** — exponential backoff wrapper for all Azure API calls.
  Handles 429 (throttle) and 503 (transient) automatically. Always use this for
  any new Azure API call.
- **JSON contracts** — `New-RecommendOutputContract` / `New-ScanOutputContract`
  include `schemaVersion`. Never change field names in existing contracts without
  a version bump — downstream consumers depend on them.
- **TestHarness.psm1** — AST-based function extraction module used by all Pester
  tests to isolate functions without running the full script. Replaced a fragile
  regex approach. Do not use dot-sourcing for test isolation.
- **Parallel scanning** — `ForEach-Object -Parallel` with explicit `$using:`
  references for all variables. Never rely on automatic variable capture in
  parallel blocks.
- **Test suite** — 142 Pester tests across 10 files in `tests/`. Always redirect
  Pester output to a log file before parsing results (prevents VS Code terminal
  freeze): `Invoke-Pester ... *> artifacts/test-run.log`

---

## Roadmap

| Version | Theme | Key Work |
|---------|-------|----------|
| v1.12.0 | Fleet Planning | `-FleetSize`, `Get-FleetAllocation`, `-GenerateScript`, `-FleetStrategy` (Balanced/HighAvailability/CostOptimized/MaxSavings) |
| v2.0.0 | Module Conversion | Public/Private layout, PSGallery publishing, Phase 5 remediation (P5.1–P5.8) |
| v2.1.0 | MCP Server | 4 tools: `check_vm_availability`, `find_alternatives`, `get_vm_pricing`, `check_quota` — depends on v2.0.0 |
| v2.2.0 | Proactive Monitoring | Watch mode, capacity alerts, Azure Monitor, Azure Functions |

---

## Runtime Notes

- **Multi-tenant auth warnings** — "Unable to acquire token" messages from
  `Connect-AzAccount` are cosmetic noise from 9+ MSFT tenants. Do not add error
  handling for them.
- **Pester log-first pattern** — always redirect Pester output to a log file;
  never stream directly to VS Code terminal (causes terminal freeze).
- **Placement Score API constraints** — `Invoke-AzSpotPlacementScore` accepts
  ≤5 SKUs × ≤8 regions per call. Requires "Compute Recommendations Role" RBAC.
  The name is misleading — the score reflects general allocation likelihood, not
  spot-VM-specific likelihood. Keep placement score separate from similarity score
  (volatile API data vs. deterministic algorithm).
- **Pricing fallback chain** — negotiated (EA/MCA/CSP via Cost Management API)
  → retail. Only call retail if negotiated fails; avoid redundant API calls.
- **Self-audit tool** — `tools/Invoke-RepoSelfAudit.ps1` generates
  `artifacts/audit/` reports (Markdown + JSON + CSV). Run at session start for
  baseline and again after completing work to measure quality delta.
