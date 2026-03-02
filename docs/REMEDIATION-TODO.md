# Phased Remediation TODO

## Phase 0 — Baseline & Safety Net
- [ ] P0.1 Fix README version badge drift to 1.10.0
- [ ] P0.2 Remove broad `PSReviewUnusedParameter` suppression and triage findings
- [ ] P0.3 Add/adjust contract tests for recommend JSON + critical behaviors
- [ ] P0.4 Run analyzer/tests/validation script and capture pass

## Phase 1 — Security & Unsafe Patterns
- [ ] P1.1 Remove `Invoke-Expression` usage from repo tests
- [ ] P1.2 Replace regex extraction + eval test strategy with importable test harness/module approach
- [ ] P1.3 Verify no dynamic eval remains in this repo

## Phase 2 — Reliability & Operational Safety
- [ ] P2.1 Remove global `$ErrorActionPreference = 'Continue'`
- [ ] P2.2 Implement fail-closed region validation in non-interactive mode
- [ ] P2.3 Add explicit override switch for region validation bypass
- [ ] P2.4 Isolate/restore Az context around subscription switching
- [ ] P2.5 Add tests for failure paths and context restoration

## Phase 3 — Performance & Hot Loops
- [ ] P3.1 Replace recommend loop `+=` with `List[object]`
- [ ] P3.2 Replace image search accumulation `+=` with list accumulation
- [ ] P3.3 Verify functional parity with tests + smoke checks

## Phase 4 — Maintainability & Stable Contracts
- [ ] P4.1 Define stable output object contract for scan/recommend modes
- [ ] P4.2 Separate interactive output formatting from compute logic
- [ ] P4.3 Introduce explicit run context/cache object
- [ ] P4.4 Remove script-scoped mutable state where feasible

## Phase 5 — Module Conversion
- [ ] P5.1 Scaffold module structure (`Public/`, `Private/`, `.psm1`, `.psd1`)
- [ ] P5.2 Move public commands to `Public/`
- [ ] P5.3 Move internals to `Private/`
- [ ] P5.4 Export public functions only
- [ ] P5.5 Update tests to import module
- [ ] P5.6 Add `Test-ModuleManifest` to CI
- [ ] P5.7 Add migration notes in docs

## Global Gates (every phase)
- [ ] Analyzer passes
- [ ] Tests pass
- [ ] Validation script passes
- [ ] No accidental junk files staged
