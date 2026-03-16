# Phased Remediation TODO

## Active Execution Tracker (from 2026-03-01)
- [x] E0.1 Pull PR #20 Copilot reviews/comments before additional remediation work
- [x] E0.2 Evaluate each Copilot comment for agreement before remediating
- [x] E0.3 Commit PR #20 comment remediations as an incremental checkpoint
- [x] E0.4 Push branch and verify PR #20 reflects remediations
- [x] E0.5 Implement P2.1 remove global `$ErrorActionPreference = 'Continue'`
- [x] E0.6 Implement P2.4/P2.5 Az context isolation + restoration tests
- [x] E0.7 Run analyzer/tests/validation with output logged to files and summarize results
- [x] E0.8 Update tracker checkboxes and progress notes after each incremental commit

### Execution Constraints
- No deletes for remediation artifacts; use backup/archive or safe moves when cleanup is needed.
- Commit as you go (small, revertable commits).
- Always triage Copilot PR comments before new remediation changes.

## Phase 0 — Baseline & Safety Net
- [x] P0.1 Fix README version badge drift to 1.10.0
- [x] P0.2 Remove broad `PSReviewUnusedParameter` suppression and triage findings
- [x] P0.3 Add/adjust contract tests for recommend JSON + critical behaviors
- [x] P0.4 Run analyzer/tests/validation script and capture pass

## Phase 1 — Security & Unsafe Patterns
- [x] P1.1 Remove `Invoke-Expression` usage from repo tests
- [x] P1.2 Replace regex extraction + eval test strategy with importable test harness/module approach
- [x] P1.3 Verify no dynamic eval remains in this repo

## Phase 2 — Reliability & Operational Safety
- [x] P2.1 Remove global `$ErrorActionPreference = 'Continue'`
- [x] P2.2 Implement fail-closed region validation in non-interactive mode
- [x] P2.3 Add explicit override switch for region validation bypass
- [x] P2.4 Isolate/restore Az context around subscription switching
- [x] P2.5 Add tests for failure paths and context restoration

## Phase 3 — Performance & Hot Loops
- [x] P3.1 Replace recommend loop `+=` with `List[object]`
- [x] P3.2 Replace image search accumulation `+=` with list accumulation
- [x] P3.3 Verify functional parity with tests + smoke checks

## Phase 4 — Maintainability & Stable Contracts
- [x] P4.1 Define stable output object contract for scan/recommend modes
- [x] P4.2 Separate interactive output formatting from compute logic
- [x] P4.3 Introduce explicit run context/cache object
- [x] P4.4 Remove script-scoped mutable state where feasible

## Phase 4.5 — Gemini Code Review Hardening (2026-03-16)
Source: Gemini 3.1 Pro architectural review of `Get-AzVMAvailability.ps1` v1.11.2.
Findings triaged into Security, Critical Bugs, and Performance categories.

### Security
- [ ] G-S1 Token leakage: wrap `Invoke-RestMethod` in `try/finally` in `Get-ValidAzureRegions` and `Get-AzActualPricing`; clear `$headers['Authorization']` and `$token = $null` in the `finally` block regardless of success or failure.

### Critical Bugs
- [ ] G-B1 `Invoke-WithRetry`: `Retry-After` header only handles integer seconds; Azure can return an absolute HTTP-date string (`'R'` format). Add `[datetime]::TryParseExact($retryAfter, 'R', [CultureInfo]::InvariantCulture, [DateTimeStyles]::None, [ref]$retryDate)` fallback to compute `$waitSeconds` from `($retryDate.ToUniversalTime() - [datetime]::UtcNow).TotalSeconds`.
- [ ] G-B2 Ctrl+C bypass: the outer `try/finally` around per-subscription scanning does not guarantee context restoration if a `PipelineStoppedException` is thrown during parallel execution. Wrap the entire main execution body (subscription loop through export) in a single top-level `try/finally` that calls `Restore-OriginalSubscriptionContext`.

### Performance
- [ ] G-P1 `Get-RestrictionDetails` (lines 880–896): replace `$zonesOK/Limited/Restricted += $zone` array concat with `[System.Collections.Generic.List[string]]::new()` + `.Add()`.
- [ ] G-P2 `$familyDetails += $detailObj` per-SKU inner loop (~line 2776): replace with `[System.Collections.Generic.List[PSCustomObject]]::new()` + `.Add()`.
- [ ] G-P3 `$rows += $row` per-family per-region loop (~line 2710): same List[T] pattern.
- [ ] G-P4 `Get-AzActualPricing` OData filter: change `contains(meterCategory,'Virtual Machines')` to exact `meterCategory eq 'Virtual Machines'` — `contains()` forces a full-scan on the Azure backend.

### Deferred / Needs Decision Before Implementing
- [ ] G-D1 Explicit `-DefaultProfile $azContext` in parallel runspaces — Az 7+ handles context inheritance per-runspace; validate empirically before adding noise. Decision required before P5.
- [ ] G-D2 `-ForceRefresh` switch to bypass `$script:RunContext.Caches` in persistent/automation sessions — low-risk add; target v1.12.0 or Phase 5.

### Global Gates (Phase 4.5)
- [ ] Analyzer passes
- [ ] Tests pass
- [ ] Validation script passes

---

## Phase 5 — Module Conversion
- [ ] P5.1 Scaffold module structure (`Public/`, `Private/`, `.psm1`, `.psd1`)
- [ ] P5.2 Move public commands to `Public/`
- [ ] P5.3 Move internals to `Private/`
- [ ] P5.4 Export public functions only
- [ ] P5.5 Update tests to import module
- [ ] P5.6 Add `Test-ModuleManifest` to CI
- [ ] P5.7 Add migration notes in docs
- [ ] P5.8 Document how to operate the module, and how it differs from the original project and code. Additionally create full documentation on the module, along with examples.  Lastly I need a full demo script and presentation flow to present this on a meeting.  Use a crawl > Walk > Run approach and build upon the demo from a novice to advance usage tactics.

## Global Gates (every phase)
- [x] Analyzer passes
- [x] Tests pass
- [x] Validation script passes
- [x] No accidental junk files staged
