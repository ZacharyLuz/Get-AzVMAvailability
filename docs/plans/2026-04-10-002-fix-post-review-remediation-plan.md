---
title: "fix: Post-Review Remediation Plan for AzVMAvailability v2.0.0"
type: fix
status: active
date: 2026-04-10
---

# Post-Review Remediation Plan

## Overview

Consolidated findings from 4 reviews conducted during the v2.0.0 module conversion session. Organized by priority tier with clear dependencies.

## Source Reviews

- **Request 81**: Maintainability review (6 findings, 3 already fixed)
- **Request 82**: Repo analysis — 10 dimensions (3 P0, 5 P1, 7 P2)
- **Request 83**: Documentation review (3 critical, 5 medium)
- **Request 84**: Correctness review (5 medium bugs, 1 low)

---

## Already Fixed (in this session)

| Finding | Fix | Commit |
|---|---|---|
| Module.Tests.ps1 hardcoded version | Dynamic manifest read | `53e10d5` |
| Wrapper param drift — no automated guard | AST-based parity test added | `53e10d5` |
| Write-Host override missing justification comment | Comment added to .psm1 | `53e10d5` |

---

## Tier 1: Fix Before Merge (blocks release correctness)

- [x] **1.1 — release-on-main.yml reads version from wrapper, not manifest**
  - Risk: Wrong tag created if wrapper `$ScriptVersion` diverges from `.psd1 ModuleVersion`
  - Fix: Add a step that reads ModuleVersion from `.psd1` and validates it matches `$ScriptVersion`
  - Files: `.github/workflows/release-on-main.yml`
  - Source: Repo analysis P0 #1

- [x] **1.2 — release-metadata-guard.yml has no manifest ↔ wrapper version check**
  - Risk: PR passes all guards despite version mismatch between wrapper and manifest
  - Fix: Add a check that `$ScriptVersion` in wrapper matches `ModuleVersion` in `.psd1`
  - Files: `.github/workflows/release-metadata-guard.yml`
  - Source: Repo analysis P0 #2

- [x] **1.3 — release-publish.yml gate job missing Az module install**
  - Risk: Release gate fails on publish day if any test needs Az types at parse time
  - Fix: Add Az.Accounts/Compute/Resources install step matching `powershell-lint.yml`
  - Files: `.github/workflows/release-publish.yml`
  - Source: Repo analysis P0 #3

- [x] **1.4 — Add Test-ModuleManifest before PSGallery publish**
  - Risk: First publish fails with opaque error from malformed manifest
  - Fix: Add `Test-ModuleManifest ./staging/AzVMAvailability/AzVMAvailability.psd1` step
  - Files: `.github/workflows/release-publish.yml`
  - Source: Repo analysis P1 #6

- [x] **1.5 — Module GUID verification**
  - Risk: `a7f3b2c1-4d5e-6f78-9a0b-1c2d3e4f5a6b` looks fabricated; potential PSGallery collision
  - Fix: Verify uniqueness or regenerate with `[guid]::NewGuid()` before first publish
  - Files: `AzVMAvailability/AzVMAvailability.psd1`
  - Source: Correctness review #6

---

## Tier 2: Fix After Merge (quality + correctness bugs)

- [ ] **2.1 — Write-Host override missing -Separator parameter**
  - Bug: If any module code calls `Write-Host 'a','b' -Separator ', '`, it throws
  - Fix: Add `[string]$Separator` to the param block in `.psm1`
  - Files: `AzVMAvailability/AzVMAvailability.psm1`
  - Source: Correctness review #1

- [ ] **2.2 — Invoke-WithRetry off-by-one**
  - Bug: `MaxRetries=3` yields 2 retries (uses `-ge` instead of `-gt`)
  - Fix: Change guard to `$attempt -gt $MaxRetries`
  - Files: `AzVMAvailability/Private/Azure/Invoke-WithRetry.ps1`
  - Test: Add test verifying exact attempt count for MaxRetries=3
  - Source: Correctness review #2

- [ ] **2.3 — Get-AzVMPricing discards valid data on mid-pagination error**
  - Bug: Outer try/catch wraps entire pagination loop; page 15 failure discards pages 1-14
  - Fix: Move try/catch inside the pagination loop or wrap individual item processing
  - Files: `AzVMAvailability/Private/Azure/Get-AzVMPricing.ps1`
  - Source: Correctness review #3

- [ ] **2.4 — Get-AdvisorRetirementData unchecked datetime cast**
  - Bug: `[datetime]$retireDate` throws on malformed API data like `'TBD'`
  - Fix: Use `[datetime]::TryParse($retireDate, [ref]$parsedDate)` with fallback
  - Files: `AzVMAvailability/Private/Azure/Get-AdvisorRetirementData.ps1`
  - Source: Correctness review #4

- [ ] **2.5 — Get-AdvisorRetirementData missing token cleanup**
  - Bug: `$headers` and `$BearerToken` not nulled after use (other Azure functions do this)
  - Fix: Add `finally { $headers['Authorization'] = $null; $BearerToken = $null }` pattern
  - Files: `AzVMAvailability/Private/Azure/Get-AdvisorRetirementData.ps1`
  - Source: Repo analysis P1 #4

- [ ] **2.6 — Get-AdvisorRetirementData coupled to $script:RunContext**
  - Bug: Only Private function that reads module-scope state directly instead of via parameter
  - Fix: Add `$Caches` parameter, pass from caller
  - Files: `AzVMAvailability/Private/Azure/Get-AdvisorRetirementData.ps1`, `AzVMAvailability/Public/Get-AzVMAvailability.ps1`
  - Source: Repo analysis P1 #5

- [ ] **2.7 — Test-SkuCompatibility silently passes null capabilities**
  - Bug: Missing `vCPU` key → `$null -gt 0` = `$false` → check skipped entirely
  - Fix: Treat missing values as incompatible (add failure when vCPU/MemoryGB is null)
  - Files: `AzVMAvailability/Private/SKU/Test-SkuCompatibility.ps1`
  - Test: Add test with null capability hashtable
  - Source: Correctness review #5

---

## Tier 3: Documentation Fixes

- [ ] **3.1 — README "What's New" missing v2.0.0 entry**
  - Fix: Add `### v2.0.0 — Module Conversion (April 2026)` section at top of What's New
  - Files: `README.md`
  - Source: Documentation review #1

- [ ] **3.2 — README requirements missing Az.Accounts**
  - Fix: Add `Az.Accounts` alongside `Az.Compute`, `Az.Resources`
  - Files: `README.md`
  - Source: Documentation review #2

- [ ] **3.3 — SECURITY.md supported versions stale**
  - Fix: Update table to include v1.7 through v2.0.0; clarify support policy
  - Files: `SECURITY.md`
  - Source: Documentation review #3

- [ ] **3.4 — README PSGallery install note**
  - Fix: Add "(available after v2.0.0 release)" next to `Install-Module` example
  - Files: `README.md`
  - Source: Documentation review #4

- [ ] **3.5 — functions/README.md obsolescence note**
  - Fix: Add v2.0.0 note: "As of v2.0.0, authoritative implementations are in AzVMAvailability/Private/"
  - Files: `functions/README.md`
  - Source: Documentation review #5

- [ ] **3.6 — demo/DEMO-GUIDE.md missing Az.Accounts**
  - Fix: Add to prerequisites section
  - Files: `demo/DEMO-GUIDE.md`
  - Source: Documentation review #7

---

## Tier 4: Backlog (future PRs)

- [ ] **4.1 — Add unit tests for 23 untested Private functions**
  - Priority: Pricing subsystem (6 functions), Get-CapValue, Get-SkuRetirementInfo
  - Source: Repo analysis P2 #9

- [ ] **4.2 — Create docs/ARCHITECTURE.md**
  - Content: Public/Private layout, RunContext lifecycle, Write-Host override rationale, parallel model
  - Source: Documentation review #8, Repo analysis P2 #10

- [ ] **4.3 — Add CmdletBinding and OutputType to Private functions**
  - Batch PR touching all 43 files
  - Source: Repo analysis P2 #11

- [ ] **4.4 — Pre-index SKU lookup in Get-InventoryReadiness**
  - Performance fix for large inventories (50+ SKUs × 10+ regions)
  - Source: Repo analysis P2 #12

- [ ] **4.5 — Replace 30s Start-Sleep with retry loop in PSGallery verification**
  - In release-publish.yml verification step
  - Source: Repo analysis P2 #13

- [ ] **4.6 — CONTRIBUTING.md module workflow section**
  - Add: how to run Validate-Script.ps1, module development workflow, test patterns
  - Source: Documentation review #6

- [ ] **4.7 — Build-PublicFunction.ps1 clarity**
  - Move to scratch/ or rename to make one-time-use nature explicit
  - Source: Maintainability review #4

---

## Execution Order

1. **Tier 1** (1.1-1.5): Fix in the current `feat/v2-module` branch before merge. Single commit.
2. **Tier 2** (2.1-2.7): Separate PR after v2.0.0 merge. Each is a small focused fix.
3. **Tier 3** (3.1-3.6): Can be bundled into one docs PR after merge.
4. **Tier 4** (4.1-4.7): Individual PRs as bandwidth allows.

## Total: 25 items (5 already fixed, 5 pre-merge, 7 post-merge bugs, 6 docs, 7 backlog)
