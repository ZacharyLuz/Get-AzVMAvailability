# Lifecycle Recommendation vs. Core — Optimizations Applied & Recommendations for Core

**Status:** Working document. Tracks behavioral and performance differences introduced in the lifecycle recommendation pipeline that may eventually warrant adoption in core scan/output paths.

**Branch:** `GOV_Price_fix`
**Last updated:** 2026-04-29 (v2.2.0)

---

## Background

A 196-subscription × 3-region GOV-tenant scan with `-LifecycleRecommendations` revealed that the **scan phase is fast (~22 min)** but the **lifecycle recommendation phase took ~7 hours**. Profiling the pipeline pinpointed `Invoke-RecommendMode`'s per-target candidate loop as O(subs × regions × skus) — at scale, ~69 million candidate evaluations across 224 target SKUs.

The fix is scoped strictly to the lifecycle recommendation path; core scan/output behavior is untouched. This document captures:
1. **What changed** in the lifecycle path
2. **What did NOT change** (and why)
3. **Recommendations to consider for core**

---

## Fix #1 — Candidate Pool Deduplication (APPLIED, lifecycle only)

### Problem
`$allSubscriptionData` contains one entry per `(subscription × region)` pair. Each entry holds the full SKU list (~526 SKUs in GOV) returned by `Microsoft.Compute/skus`. With 196 subscriptions × 3 regions, the structure stores:

- **309,288 SKU rows** (196 × 3 × 526)
- but only **~1,578 unique `(region, sku)` combinations** worth scoring

`Invoke-RecommendMode` walks `$SubscriptionData → RegionData → Skus` for every target SKU. SKU **capability** data (`vCPUs`, `MemoryGB`, `Generation`, etc.) is identical across subscriptions; only **restrictions/quota** vary per sub. The recommender only consumes capability data → 99% of work is duplicated.

### Solution
Before entering the lifecycle loop, build a synthetic single-subscription view containing one row per `(region, sku)`. For status conflicts across subs, keep the row with the best (lowest-rank) status:

```
OK (0) > PARTIAL (1) > CAPACITY-CONSTRAINED (2) > LIMITED (3) > RESTRICTED (4) > BLOCKED (5)
```

Pass the deduped view to `Invoke-RecommendMode`. Per-sub status/quota detail is **preserved** in `$allSubscriptionData` and the lifecycle indexes (`$lcSkuIndex`, `$lcQuotaIndex`, `$lcPerSubQuota`, `$lcPerSubRestriction`) used by SubMap/RGMap output.

### Impact (projected)
| Metric | Before | After | Speedup |
|---|---|---|---|
| Candidates per target SKU | 309,288 | ~1,578 | 196× |
| Total candidate evaluations (224 targets) | ~69M | ~354K | 196× |
| Lifecycle phase (196 subs × 3 regions, 224 SKUs) | ~7 hours | ~3-5 minutes | ~100× |

### Location
- File: [AzVMAvailability/Public/Get-AzVMAvailability.ps1](../AzVMAvailability/Public/Get-AzVMAvailability.ps1)
- Inserted just before the `foreach ($entry in $lifecycleEntries)` loop (~line 2076)
- Builds `$lcDedupedSubscriptionData` and passes it to `Invoke-RecommendMode` instead of `$allSubscriptionData`
- The two **single-SKU `-Recommend`** call sites (~lines 3113, 3638) are unchanged — they only execute once per invocation so the optimization doesn't apply.

### Safety / scope
- ✅ `$allSubscriptionData` is not modified
- ✅ Per-sub status/quota for SubMap/RGMap output is unaffected (read from `$lcPerSubRestriction` / `$lcPerSubQuota`)
- ✅ Restricted-status SKUs are still filtered inside the recommender (line 117 of `Invoke-RecommendMode.ps1`)
- ✅ "Best status across subs" matches user intent for recommendations: *"Where could I deploy this SKU?"* — not *"Is it available everywhere?"*

---

## Fix #4 — Parallelize the per-SKU lifecycle loop (NOT APPLIED — requires core changes)

### Concept
After Fix #1, the lifecycle loop is `224 × ~1s` = ~4 min sequentially. Further parallelization (e.g., `ForEach-Object -Parallel -ThrottleLimit 8`) would reduce this to ~30s.

### Blocker — Why it requires core changes
`Invoke-RecommendMode` writes its result to:
```powershell
$script:RunContext.RecommendOutput = New-RecommendOutputContract -...
```
This is a **single-slot script-scope variable**. The lifecycle caller reads this slot immediately after each call:
```powershell
Invoke-RecommendMode ...
$recOutput = $script:RunContext.RecommendOutput
```

`ForEach-Object -Parallel` runs in separate runspaces with their own scope; the script-scope assignment is invisible to the caller. Two changes to core would be required:

1. **Modify `Invoke-RecommendMode` to return the contract object** (in addition to or instead of stashing it in `$RunContext`)
2. **Pass all needed module-private functions** (`Get-RestrictionDetails`, `Get-SkuCapabilities`, `Get-SkuSimilarityScore`, `Test-SkuCompatibility`, `Get-SkuFamily`, `Get-DiskCode`, `Get-ProcessorVendor`, `Get-CapValue`, `New-RecommendOutputContract`, `Get-PlacementScores`) and their dependencies into each parallel runspace via `using:` or module re-import

### Recommendation for core
Refactor `Invoke-RecommendMode` to **return** the contract object as a function output (current `$RunContext.RecommendOutput` write can remain for back-compat):
```powershell
$result = Invoke-RecommendMode -TargetSkuName $sku ...
# legacy: $script:RunContext.RecommendOutput = $result
return $result
```
This single change unlocks Fix #4 and makes the function cleaner/testable. After that, the lifecycle loop can use `ForEach-Object -Parallel -ThrottleLimit 8` for another ~8× speedup on the recommendation phase.

### Estimated effort
- ~30 lines changed in `Invoke-RecommendMode.ps1`
- ~50 lines changed at the lifecycle loop call site (parallel block + module import)
- New tests for parallel-safe execution

---

## Other Differences Worth Considering for Core

### A. SKU profile caching (already shared, but worth documenting)
`$lcProfileCache = @{}` is built up during the lifecycle loop and passed to every `Invoke-RecommendMode` call via `-SkuProfileCache`. This memoizes `Get-SkuCapabilities` / `Get-ProcessorVendor` / `Get-DiskCode` lookups across all 224 target SKUs.

**Recommendation:** the single-SKU `-Recommend` paths (~lines 3113, 3638) currently pass `@{}` for `-SkuProfileCache` and rebuild from scratch each call. Since they're single-shot, this is fine — but if `-Recommend` is ever used in a loop (e.g., bulk reporting tool), consider lifting the cache to the module/script scope.

### B. Pricing fetch ordering
Lifecycle pre-loads pricing once via `Get-AzActualPricing` (price sheet, single API call across all regions, 30-day disk cache). Core's per-region `Get-AzVMPricing` is a fallback retail path. No change needed — already optimal.

**v2.2.0 update — also affects Core (`-ShowPricing`):** `Get-AzActualPricing.ps1` had a resolver bug that caused **all commercial regions** to silently fall back to retail even when a populated negotiated cache existed. The Consumption Price Sheet API publishes `meterLocation` in `<geoShort><locality>` form (`uswest`, `useast2`, `euwest`, `apsoutheast`, `jaeast`, `dewestcentral`), but the resolver looked up by ARM `<locality><geo>` names (`westus`, `eastus2`, `westeurope`, `southeastasia`, `japaneast`, `germanywestcentral`). Only `uksouth/ukwest` and the US Gov aliases matched. Fix expanded `$armToMeterLocation` to ~70 explicit aliases covering every public commercial region observed in EA price sheets (note `japaneast → jaeast` uses `ja`, not `jp`) and added a generic geo-token permutation fallback (`$deriveAliasCandidates`) so future regions resolve without code changes. Diagnostic message also stops claiming "No sovereign keys present in cache" for non-sovereign lookups.

**Core relevance:** anyone running `-ShowPricing` (or accepting the interactive pricing prompt) in commercial regions now gets actual negotiated rates instead of retail. No Core code changes required; the function is shared. If Core gains additional pricing call sites, they inherit the fix automatically because resolution lives inside `Get-AzActualPricing`.

### B2. Scan progress bar UX (v2.2.0, Core + Lifecycle)
The parallel sub×region scanner in `Get-AzVMAvailability.ps1` (poll loop ~lines 2120–2180) is the universal scan engine — both Core and Lifecycle use it. Two issues fixed in v2.2.0:

1. **Straggler-aware ETA.** Average-throughput projection (`elapsed.TotalSeconds / done * remaining`) under-estimates badly when the last 1–3 work items are throttled subs / slow regions running 5–20× longer than average. Bar would freeze at e.g. `1263 / 1266 · 11s remaining` for several minutes. When `remaining ≤ max(3, totalItems * 0.005)`, the status now switches to `finalizing N straggler(s)...` instead of an inaccurate countdown.
2. **Force-clear after poll loop.** Some terminals leave the last `Write-Progress` frame visible during the regrouping/announce phase. Added an explicit `Write-Progress -Activity "Scanning Azure Regions" -Completed` immediately after the poll exits, plus a `$ProgressPreference = 'SilentlyContinue'` save/restore around the regrouping section so per-subscription `[N/total]` lines are the only visible activity from there on.

**Core relevance:** purely a UX change in shared scan code, no semantic impact on output. Worth being aware of if Core ever adds a competing progress writer near the same code path — the regrouping section currently expects `$ProgressPreference` to be silenced and restores it from `$savedRegroupProgressPref`.

### B3. Companion diagnostic tool (v2.2.0)
`tools/Inspect-PriceSheetCache.ps1` (in the `BoeColab/Get-AzVMLifecycle` companion repo) is a read-only inspector for the on-disk Price Sheet cache (`%TEMP%\AzVMLifecycle-PriceSheet-v4-<tenantId>.json`). It enumerates total regions / SKUs, lists every cache key, runs an ARM-name probe (the way the resolver did *before* the fix) and an alias probe (suspected meterLocation conventions), and dumps a sample SKU. Output is teed to a timestamped `results.<yyyyMMdd-HHmmss>.log` with embedded ANSI color escapes. No Azure API calls. Useful for Core if a similar resolver-mismatch class of bug ever recurs.

### C. UpgradePath.json cascading lookup
The fix in commit `d0bd321` added cascading path lookup (module root → repo root) in **both** call sites (line 830 SKU expansion + line 2044 lifecycle block). This is consistent across the script.

**Recommendation for core:** when packaging the module for PSGallery distribution, ensure `data/UpgradePath.json` is shipped inside the module directory (`AzVMAvailability/data/`) so the first-tier lookup succeeds. Currently only the repo-root location works.

### D. Restriction status normalization
The status rank used by Fix #1 (`OK > PARTIAL > CAPACITY-CONSTRAINED > LIMITED > RESTRICTED > BLOCKED`) duplicates the ranking already used in `Invoke-RecommendMode.ps1` (line 43) and elsewhere. This should be lifted into a shared helper: `Get-StatusRank` or `Compare-SkuStatus` in `Private/Format/` or `Private/Utility/`. Until then, the duplication is intentional to avoid touching core helpers.

### E. Memory footprint of `$allSubscriptionData`
At 196 subs × 3 regions × 526 SKUs × ~2 KB per SKU object, `$allSubscriptionData` consumes **~600 MB**. The deduped lifecycle view is ~3 MB. For very large tenants, core scan output could optionally store a deduped-with-per-sub-restriction-overlay structure to cut memory by ~99%.

**Recommendation for core:** consider a future option flag `-CompactScanData` that stores a `(region, sku) → capability` table plus a separate `(sub, region, sku) → (restriction, quota)` overlay. Excel export and SubMap/RGMap could read from the overlay; recommender reads the capability table. Not urgent for typical 1-10 sub usage.

---

## Summary Table

| Optimization | Applied | Scope | Impact | Core change required? |
|---|:---:|---|---|:---:|
| Fix #1 — Candidate dedup | ✅ | Lifecycle only | ~100× faster lifecycle phase | No |
| Fix #2 — Don't auto-trigger on `-Verbose` | ✅ (commit `e044677`) | LogFile param | UX | No |
| Fix #3 — Cache compatibility/score | ⏸ Deferred | Recommender | Marginal after #1 | Light |
| Fix #4 — Parallel lifecycle loop | ⏸ Blocked | Lifecycle only | ~8× on top of #1 | **Yes** (return contract) |
| Status rank helper | ⏸ Deferred | Shared | Code clarity | Light |
| Compact scan storage | ⏸ Future | Core scan | ~99% memory reduction at scale | **Yes** |
| v2.2.0 — Price Sheet alias resolver | ✅ (`5b5ff4d`) | **Shared** (Core `-ShowPricing` + Lifecycle) | Commercial regions return negotiated rates instead of silent retail | No |
| v2.2.0 — Straggler-aware scan ETA + force-clear bar | ✅ (`7ea4e3e`) | **Shared** scan engine | UX only, no output change | No |

---

## Decision Log

- **2026-04-27** — Fix #1 implemented, Fix #4 deferred per direction "do not mess with core".
- **2026-04-27** — Doc created to track recommendations for future core adoption.
- **2026-04-29 (v2.2.0)** — Price Sheet resolver alias fix and scan progress UX shipped in shared code paths. Both Core (`-ShowPricing`) and Lifecycle inherit. No Core API surface changes.
