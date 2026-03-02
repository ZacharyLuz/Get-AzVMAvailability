# Remediation Program — Get-AzVMAvailability

Date: 2026-03-01
Scope: Systematic remediation of review findings with release-quality guardrails.

## Principles
- Every change must reduce risk, improve testability, or improve operator safety.
- Behavior-preserving by default.
- One concern per commit.
- No repo junk (logs/transcripts/temp artifacts).

## 1) Findings Backlog (Mapped)

### Critical
1. Remove dynamic test evaluation (`Invoke-Expression`) in tests.
2. Fail closed on region validation in non-interactive mode.
3. Remove/contain Az context side effects (`Set-AzContext`).

### High
4. Remove global `$ErrorActionPreference = 'Continue'` pattern.
5. Decompose monolith concerns (interactive UX vs compute/output engine).
6. Replace mutable script-scoped state with explicit context/cache objects.
7. Replace hot-loop array `+=` patterns with list-based accumulation.
8. Stabilize output contract (objects/JSON first, formatting wrapper second).

### Medium
9. Remove broad analyzer suppression (`PSReviewUnusedParameter`).
10. Improve exception observability in silent catch paths.
11. Introduce parameter sets for public command surfaces.
12. Standardize logging stream strategy (Verbose/Information).

### Low
13. Fix version drift in docs (README badge).
14. Add strict-mode hardening during module migration.

## 2) Phased Plan + Gates

### Phase 0 — Baseline & Safety Net
- Add/strengthen contract tests around critical behavior.
- Ensure analyzer baseline is meaningful.
- Fix release metadata drift.

Gates:
- `Invoke-ScriptAnalyzer` passes with justified suppressions only.
- `Invoke-Pester` passes.
- `tools/Validate-Script.ps1` passes.

### Phase 1 — Security & Unsafe Patterns
- Remove dynamic eval in tests.
- Ensure no unsafe dynamic execution patterns remain.

Gates:
- No `Invoke-Expression` in this repo test suite.
- Tests and analyzer pass.

### Phase 2 — Reliability & Operational Safety
- Remove global error mode anti-pattern.
- Make region validation fail closed by default for non-interactive mode.
- Isolate and restore Azure context changes.

Gates:
- Failure-path tests pass.
- Context is unchanged after run.

### Phase 3 — Performance & Hot Loops
- Replace `+=` accumulations in hot loops with `List[object]`.
- Reduce repeated calls while avoiding hidden mutable state.

Gates:
- Tests pass.
- Basic timed smoke runs are not slower.

### Phase 4 — Maintainability & Contracts
- Split UX/interactive layer from compute engine.
- Stabilize object output contracts.
- Move formatting to wrapper layer.

Gates:
- Contract tests pass.
- Interactive and non-interactive smoke runs pass.

### Phase 5 — Module Conversion
- Scaffold module (`Public/`, `Private/`, `.psm1`, `.psd1`).
- Export only public cmdlets.
- Update tests to import module.
- Add `Test-ModuleManifest` to CI.

Gates:
- Module import + manifest test pass.
- Analyzer + tests pass.

## 3) Commit Strategy
- One concern per commit, each revertable.
- PR batches by phase.
- No generated artifact commits.

## 4) Documentation During Remediation
- Update README usage and non-interactive guidance.
- Add troubleshooting guidance for common failures.
- Record architectural decisions for module boundary and state handling.

## 5) Repo Cleanliness Rules
- Keep only maintainership-standard files.
- Enforce `.gitignore` for local/editor/OS noise.
- Use forward-fix cleanup over history rewriting unless absolutely necessary.

## 6) Upstream GitHub Security & Best Practices
- Branch protection with required checks/reviews.
- Dependabot + secret scanning + code scanning.
- Least-privilege workflow permissions.
- CODEOWNERS + SECURITY.md validation.

## 7) Definition of Done
- All critical/high findings fixed or explicitly accepted with rationale.
- Analyzer/tests green.
- Docs updated.
- Repo clean.
- GitHub security controls enabled and verified.

## Validation Commands
```powershell
Invoke-ScriptAnalyzer -Path . -Recurse -Settings PSScriptAnalyzerSettings.psd1
Invoke-Pester .\tests -Output Detailed
pwsh -File .\tools\Validate-Script.ps1
```
