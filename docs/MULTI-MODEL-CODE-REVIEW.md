# Multi-Model Code Review — Scan Engine Hardening

**Date:** March 24, 2026 | **Result:** 7 improvements applied, 15.6% faster scans, ReDoS eliminated

## Methodology

We used the [Karpathy autoresearch pattern](https://x.com/karpathy/status/1886192184808149383) — give multiple AI models the same codebase independently, then assemble the best output from each.

### Setup

5 AI models each independently implemented the full `Get-AzVMAvailability.ps1` script from a shared specification:

| Model | Role |
|---|---|
| Claude Opus 4.6 | Baseline (dominant — 15 of 22 goals already present) |
| Claude Sonnet 4.6 | Won 3 applied improvements |
| GPT-5.4 | Won 4 applied improvements |
| GPT-5.3 Codex | No unique wins (implementations correct but not best) |
| GPT-5.4 Mini | Co-winner on 1 goal (identical to GPT-5.4) |

### Evaluation

22 improvement goals across 3 tiers:

- **Tier 1 — Timing-decisive (4 goals):** Run both versions, keep the faster one. Measured with 3-run averages on a single-region scan.
- **Tier 2 — Binary PASS/FAIL (7 goals):** Verify the improvement already exists in the baseline. If present, log and skip.
- **Tier 3 — Human judgment (11 goals):** Apply the recommended model's implementation, run the test suite, keep if PASS.

Every change followed a strict process: backup → hash before → apply → hash after → test → keep or revert → audit log entry.

### Results

| Outcome | Count | Goals |
|---|---|---|
| Already present in baseline | 15 | 1, 2, 4, 5, 8, 9, 10, 11, 13, 15, 18, 19, 20, 21, 22 |
| Applied (kept) | 7 | 3, 6, 7, 12, 14, 16, 17 |
| Reverted | 0 | — |
| Failed | 0 | — |

---

## Applied Improvements

### Performance: 15.6% Faster Scans

**The problem:** The scan engine fetched SKU catalog data and quota data sequentially — one REST call completed before the next started. For each region, this meant ~2.5 seconds of wasted wall-clock time waiting for independent API responses.

**The fix (Goal 6 — Claude Sonnet):** Use .NET `HttpClient` to fire both first-page requests concurrently via `Task.WaitAll`, then paginate sequentially after the first pages return. Since SKU and quota APIs are independent endpoints and the first page contains the bulk of the data, overlapping their network latency cuts wall-clock time significantly.

**Measurement:**
- Baseline: 15,895ms average (3 runs: 14,975 / 15,921 / 16,789)
- After: 13,411ms average (3 runs: 14,616 / 12,186 / 13,432)
- Improvement: **-2,484ms (-15.6%)**
- Test: single-region JsonOutput scan (`-Region eastus -NoPrompt -JsonOutput -SkipRegionValidation`)

### Performance: Get-CapValue Correctness (Goal 7 — Claude Sonnet)

Replaced a truthy check (`if ($Sku._CapIndex)`) with a defensive `PSObject.Properties` check. The truthy check silently failed for empty capability indexes and missed legitimate `'0'` or `'False'` capability values, causing incorrect SKU capability lookups.

### Security: ReDoS Elimination (Goal 14 — GPT-5.4)

User-supplied SKU filter patterns (`-SkuFilter "Standard_D*s_v5"`) were compiled as .NET regex. A malicious pattern like `(a+)+$` could cause catastrophic backtracking (ReDoS). Replaced with PowerShell's `-like` operator which uses simple glob matching (`*` and `?` wildcards) with zero ReDoS surface. Added 128-character limit and character whitelist validation as defense-in-depth.

### Resilience: HTTP 500 Retry (Goal 3 — GPT-5.4)

Added `InternalServerError` to the `Invoke-WithRetry` retry pattern. Some Azure SDK exceptions surface the .NET enum name rather than the HTTP status code or human-readable string. The retry logic now catches all three forms: `500`, `Internal Server Error`, and `InternalServerError`.

### Correctness: Per-Subscription Scan Timer (Goal 12 — GPT-5.4)

Added a `$subscriptionScanStartTime` timer that resets for each subscription. Previously, scan elapsed time included the one-time pricing phase, inflating reported scan duration. The global `$scanStartTime` is preserved for total elapsed time at script completion.

### Output: Write-Host Gating (Goal 16 — Claude Sonnet)

Replaced a conditional empty-function approach with a module-qualified `Write-Host` override that checks `$script:SuppressConsole` at runtime. When suppressed, Write-Host calls are no-ops. When not suppressed, the override delegates to `Microsoft.PowerShell.Utility\Write-Host` preserving all parameters. Unlike the empty-function approach, this is reversible at runtime.

### Output: Pipeline Emit Gate (Goal 17 — GPT-5.4)

Changed the pipeline emit condition from `-not $Quiet` to `-not $JsonOutput -and -not $Quiet -and $familyDetails.Count -gt 0`. Without the `-JsonOutput` check, the script would emit structured objects to the pipeline *after* already outputting JSON via `ConvertTo-Json`, breaking downstream parsers that expect clean JSON output.

---

## Model Scorecard

| Model | Base Wins | Applied Wins | Notes |
|---|---|---|---|
| **Claude Opus 4.6** | 15 | 0 | Dominant baseline — 15 of 22 improvements already present. Clean architecture, correct patterns. |
| **Claude Sonnet 4.6** | 0 | 3 | HttpClient parallel (15.6% faster), PSObject defensive check, module-qualified Write-Host. Strong engineering instincts. |
| **GPT-5.4** | 0 | 4 | HTTP 500 catch, dual timer, ReDoS elimination, pipeline gate. Best security and correctness contributions. |
| GPT-5.3 Codex | 0 | 0 | Correct but never best. |
| GPT-5.4 Mini | 0 | 0 (1 co-win) | Co-winner on pipeline gate (identical to GPT-5.4). |

## Key Takeaway

The baseline (Opus) was architecturally sound — 15 of 22 evaluation targets were already implemented. The 7 applied improvements came from models with complementary strengths: Sonnet excelled at performance engineering, GPT-5.4 excelled at security hardening and edge-case correctness. The multi-model approach surfaced improvements that no single model found on its own.
