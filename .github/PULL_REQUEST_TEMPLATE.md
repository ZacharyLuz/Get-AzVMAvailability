<!-- Verification-First Checklist is REQUIRED for this repo. -->
<!-- Structural claims must be evidence-backed: OBSERVED/SEARCHED/PROVIDED only. -->

## Description

<!-- Brief summary of what this PR does and why -->

## Verification Checklist

<!-- Structural claims must be evidence-backed: [OBSERVED] [SEARCHED] [PROVIDED]. -->

### Phase 0 — Repo Facts
- [ ] I inventoried repo entrypoints and structure (top-level files/folders). **[OBSERVED]**
- [ ] I verified which entrypoint is authoritative for behavior parity:
  - [ ] `Get-AzVMAvailability.ps1` still functions as entrypoint/wrapper **[OBSERVED]**
  - [ ] Module exports include the intended public cmdlet(s) **[OBSERVED]**
- [ ] I did **NOT** claim any line numbers or file lengths unless directly verified. **[OBSERVED]**
- [ ] I produced/updated a Verified Landmark Table (below). **[OBSERVED]**

### Verified Landmark Table
<!-- At least 5 entries required. Each must be tagged OBSERVED/SEARCHED/PROVIDED. -->
<!-- INFERRED claims cannot justify changes. -->

| Landmark / Claim | Evidence (file + how verified) | Tag |
|---|---|---|
| | | |
| | | |
| | | |
| | | |
| | | |

### Scope Guardrails (No Feature Creep)
- [ ] No new parameters, modes, report columns, file formats, or endpoints were introduced.
- [ ] Any behavior change is explicitly documented under "Behavior Changes" with justification and compatibility strategy.

### Behavior Parity
- [ ] Script wrapper path produces the same user-visible behavior as before for:
  - [ ] Interactive default UX
  - [ ] `-NoPrompt` mode
  - [ ] `-JsonOutput` mode (no Write-Host contamination)
  - [ ] Export paths (CSV / XLSX where applicable)
- [ ] I updated/added parity tests OR documented why test coverage is not possible.

## Behavior Changes
<!-- None / or list each with: Change, Previous behavior, New behavior, Why unavoidable, Compatibility mitigation -->

- None

## Type of Change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Code quality (refactoring, comments, tests — no behavior change)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Documentation update

## Quality Checklist

- [ ] **PR markdown renders correctly** — no literal escaped `\n` sequences in title/body
- [ ] **No AI instructional comments** — no "Must be after", "This ensures", "Handle potential" comments
- [ ] **No empty catch blocks** — every catch has at least `Write-Verbose`
- [ ] **No magic numbers** — numeric literals are named constants
- [ ] **Version strings in sync** — `.NOTES`, `$ScriptVersion`, and ROADMAP all match
- [ ] **PSScriptAnalyzer clean** — `Invoke-ScriptAnalyzer -Path . -Recurse -Settings PSScriptAnalyzerSettings.psd1` returns no warnings/errors
- [ ] **Pester tests pass** — `Invoke-Pester ./tests -Output Detailed`
- [ ] **Syntax valid** — `[scriptblock]::Create((Get-Content 'Get-AzVMAvailability.ps1' -Raw)) | Out-Null` succeeds
- [ ] **CHANGELOG.md updated** (if functional change)
- [ ] **New functions have Pester test coverage** (if adding functions to `Get-AzVMAvailability.ps1`)
- [ ] **Release/tag plan prepared for this version bump** (required when `$ScriptVersion` changes)

## Validation

- [ ] Ran `tools/Validate-Script.ps1` with all checks passing
- [ ] Tested with at least one Azure region (if applicable)
