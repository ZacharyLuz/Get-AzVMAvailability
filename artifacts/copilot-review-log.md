# Copilot Review Log

## PR #150 — fix/release-publish-manual-dispatch

- Branch: fix/release-publish-manual-dispatch
- Reviewed head SHA: a46e275f21807e90226982662446e5cb3d8589f7
- `.github/workflows/release-publish.yml:10` — "The new manual entry point accepts any existing tag, but the workflow never verifies that a matching GitHub Release exists before publishing to PSGallery." Assessment: **Agree**. Action: added a `gh release view "$RELEASE_TAG"` gate before packaging/publishing so missing releases fail before `Publish-Module`.
- `.github/workflows/release-publish.yml:18` — "Adding a manual trigger creates a second way to publish the same tag, but this workflow still has no concurrency guard." Assessment: **Agree**. Action: added workflow-level concurrency keyed by release tag with `cancel-in-progress: false` so publishes for the same version do not overlap.

## PR #151 — fix/release-publish-filter-blocking-errors

- Branch: fix/release-publish-filter-blocking-errors
- Reviewed head SHA: a5b7862ecf9ed3a6e1d188a99971dad361eb1e70
- `.github/workflows/release-publish.yml:54` — "The new `$blockingResults` filtering prevents warnings from blocking the gate, but it also means non-Error diagnostics returned by `Invoke-ScriptAnalyzer` are never printed to the job log." Assessment: **Agree**. Action: log non-blocking diagnostics with `Format-Table` before filtering to blocking errors.

---

## PR #154 — fix/psgallery-package-parity — commit c96cd24 — 2026-05-06

**Reviewer batch:** Sourcery-AI + GitHub Copilot inline reviews
**Independent re-analysis:** Claude Opus 4.7 (Extra high reasoning) + GPT 5.5 (cross-model consensus)

### Inline review threads

| # | ID | Reviewer | File:Line | Finding (quoted) | Assessment | Action |
|---|----|----------|-----------|------------------|------------|--------|
| 1 | 3196766360 | sourcery-ai | .github/workflows/release-publish.yml:115 | "Consider cleaning the staging directory between runs to avoid stale files leaking into the package" | **Agree** | Fixed in c96cd24 (auto-resolved by Sourcery) |
| 2 | 3196781953 | copilot-pull-request-reviewer | tools/Stage-ModulePackage.ps1:47 | "The staging directory is created (or reused) but never cleaned. If the script is rerun against an existing staging folder..." | **Agree** | Same fix as #1; replied + resolved |
| 3 | 3196781989 | copilot-pull-request-reviewer | tools/Stage-ModulePackage.ps1:17 | "The script exposes a -ModuleName parameter but the comment-based help doesn't document it. Add a .PARAMETER ModuleName..." | **Agree** | Removed the parameter (fake parameterization — only callers always pass the default). Per project anti-speculative-flexibility rule. Replied + resolved |
| 4 | 3196766361 | sourcery-ai | tools/Stage-ModulePackage.ps1:32 | "Guard against StagingRoot being an existing file rather than a directory" | **Disagree** | Defensive code for an impossible scenario — both known callers (release-publish.yml workflow, Pester tests) always pass directory paths. New-Item -ItemType Directory will throw a clear actionable error if a future caller violates this. Per "Simplicity First / No error handling for impossible scenarios" rule. Replied + resolved as intentionally not fixed |

### Sourcery review-level recommendations (general comment, not inline threads)

| # | Finding | Assessment | Reasoning |
|---|---------|------------|-----------|
| F4 | "Verify excluded directories with case-insensitive comparison and absolute path matching" | **Disagree** | Excluded directory list (`tests`, `examples`, `dev`, etc.) is hard-coded and known to be lowercase. Adding case-insensitive matching is defensive code for a non-existent scenario. PowerShell on Windows is case-insensitive by default for path comparison; Linux runner uses the same hard-coded constants. |
| F5 | "Add a Pester / unit test for the staging script that asserts the expected layout end-to-end" | **Partially Agree** | The existing `tests/PackageLayout.Tests.ps1` already validates layout (5 tests). The new test added in c96cd24 covers the regression. Additional end-to-end CI testing is captured by the workflow itself running the script — duplicating that in unit tests adds maintenance burden without catching new failure modes. |
| F6 | "Validate that copied required asset files are non-empty and exist after copy" | **Disagree** | Copy-Item throws on missing source files; the staging output already includes an IncludedAssetCount and IncludedAssets array consumed by the workflow's verification step. Adding per-file size assertions inside the staging script duplicates existing test coverage in PackageLayout.Tests.ps1. |

### Outcome

- 4/4 inline threads addressed (3 replied + resolved, 1 auto-resolved by Sourcery on the fix commit).
- All 11 required CI checks: PASS (Pester ubuntu + windows, PSScriptAnalyzer x2, CodeQL, Sourcery review, Repo Self-Audit, Release Metadata Guard, Verification-First Checklist).
- Net diff: +24 / -2 across 2 files (`tools/Stage-ModulePackage.ps1`, `tests/PackageLayout.Tests.ps1`).

### Follow-up — Copilot review of commit `162e39f` (this entry)

| # | ID | Reviewer | File:Line | Finding (quoted) | Assessment | Action |
|---|----|----------|-----------|------------------|------------|--------|
| 5 | 3208645739 | Copilot | artifacts/copilot-review-log.md:44 | "This log entry contains stray control characters / corrupted words (e.g., '\tests' / '^[xamples') which makes the review log hard to read and can break Markdown rendering/search." | **Agree** | Sanitized in this commit. |
| 6 | review 4252223212 (low-confidence suppressed) | copilot-pull-request-reviewer[bot] | artifacts/copilot-review-log.md:45 | "The 'Net diff' line also includes corrupted file paths (e.g., missing leading characters like 'ools/' and 'ests/')." | **Agree** | Same root cause; addressed by the same sanitization. |

**Root cause:** The previous append used a PowerShell double-quoted here-string (`@"..."@`) where backticks are escape characters. The markdown-quoted paths `` `tests`` and `` `tools`` were interpreted as `` `t`` (TAB, 0x09), and `` `examples`` was interpreted as `` `e`` (ESC, 0x1B). Result: `\tests` rendered as TAB+`ests`, `\examples` as ESC+`xamples`, etc.

**Prevention:** When appending to this log from PowerShell, use either (a) a single-quoted here-string `@'...'@` (no interpolation, no escape interpretation), or (b) direct file editing tools that take literal text. Avoid `@"..."@` for content that contains markdown backticks.


## PR #154 — fix/psgallery-package-parity (post-bump review pass)

- Branch: fix/psgallery-package-parity
- Reviewed head SHA: 09f78c4 (fix in follow-up commit)
- `ROADMAP.md:5` (Copilot) — "The ROADMAP header was bumped to v2.2.2, but the 'Current Release' summary immediately below still describes v2.2.1. This makes the roadmap internally inconsistent; update the blockquote section to describe v2.2.2 (or add a new v2.2.2 summary entry above the v2.2.1 entry)." Assessment: **Agree**. Action: added a new v2.2.2 summary blockquote above the existing v2.2.1 summary, mirroring the wording style used for v2.2.1 / v2.2.0 (subject + theme + see CHANGELOG.md). The summary covers the four PR #154 fixes: PSGallery package staging + Pester guard, version-bump.yml stamp coverage, release-publish lint filter, and manual release-publish retry / serialization.


## PR #155 — ci/auto-publish-on-merge

- Branch: ci/auto-publish-on-merge
- Reviewed head SHA: e035495 (fixes in follow-up commit)
- `.github/workflows/auto-publish.yml:102` (Sourcery, bug_risk) — "Version parsing error handling never triggers because the TryParse results are not actually validated. `[version]::TryParse` returns a `bool` and always assigns a (non-nullable) `[version]` struct to the out parameter, so `$parsedCurrent` / `$parsedLatest` will never be falsy." Assessment: **Agree**. Action: capture the `bool` return values into `$okCurrent` / `$okLatest` and check those in the `throw` guard.
- `.github/workflows/auto-publish.yml:215` (Sourcery, suggestion) — "The CHANGELOG `[Unreleased]` promotion logic fails if `[Unreleased]` is the last section in the file." Assessment: **Agree**. Action: changed regex lookahead from `(?=\n##\s+\[)` to `(?=(\n##\s+\[|\Z))` so a trailing `[Unreleased]` block is still promoted.
- `.github/workflows/auto-publish.yml:189` (Copilot) — "`[regex]::Replace($text, $t.Pattern, $replacement, 1)` is not a reliable way to limit replacements to a single match. In .NET, the 4-argument overload commonly binds the last argument as `RegexOptions` (so `1` becomes `IgnoreCase`)." Assessment: **Agree**. Action: replaced static call with a `[regex]::new($t.Pattern)` instance and called the instance `.Replace(input, replacement, 1)` overload, which genuinely accepts a count.
- `.github/workflows/auto-publish.yml:398` (Copilot) — "The dry-run output line uses `"$(${{ steps.detect.outputs.latest_tag }})"`, which will be expanded by Actions into something like `$(v2.2.2)` and then executed as a PowerShell subexpression, causing a parse/runtime error." Assessment: **Agree**. Action: removed the `$(...)` wrapper so Actions interpolation is printed verbatim, matching the previous two `Write-Host` lines.
- `.github/workflows/auto-publish.yml:195` (Copilot) — "The workflow writes PowerShell files (`*.ps1`/`*.psd1`) using `Set-Content -Encoding utf8`, which in pwsh writes UTF-8 **without BOM** and may also introduce LF-only line endings where the repo requires CRLF." Assessment: **Partially Agree** (intentional non-fix in this PR). The `.editorconfig` does require UTF-8-BOM for `*.ps1`/`*.psm1`/`*.psd1`, but `.github/workflows/version-bump.yml` already uses the identical `Set-Content -Encoding utf8` / `Add-Content -Encoding utf8` pattern on the same file set. Fixing it only in `auto-publish.yml` would create asymmetry between the two workflows that share these targets, and would risk diverging output. Action: leaving as-is in PR #155 to preserve parity with the established `version-bump.yml` pattern; tracked as a separate cleanup that should fix both workflows in one pass.


## PR (follow-up to #154) — fix/post-merge-roadmap-reviewlog (PR #156)

- Branch: fix/post-merge-roadmap-reviewlog
- Reviewed head SHA: ee4d447 (Copilot review pass on PR #156); follow-up corrections in subsequent commit on the same branch
- `ROADMAP.md:5` (Copilot, ID 3209405083 on PR #154) — "The current-release blockquote claims `release-publish.yml reports PSScriptAnalyzer warnings via SARIF and only blocks on errors`, but that workflow has no `upload-sarif` step or `security-events: write` permission, and uses `-Severity Error,Warning` so it blocks on warnings too. The SARIF + errors-only claim is not accurate." Assessment: **Agree** (SARIF claim) / **Disagree** (severity claim — `release-publish.yml` actually invokes `Invoke-ScriptAnalyzer ... -Severity Error`, only Error-severity findings block). Action: rewrote the blockquote to read `release-publish.yml runs PSScriptAnalyzer with -Severity Error (only Error-severity findings block; uses shared PSScriptAnalyzerSettings.psd1) before publishing, supports manual retry against an existing tag, and serializes runs per release.` This wording matches the actual workflow at `.github/workflows/release-publish.yml:47-48`. No SARIF emitter added (out of scope per Simplicity First).
- `artifacts/copilot-review-log.md:33` (Copilot, ID 3209405138 on PR #154) — "This PR adds a new PR #154 block above an existing PR #155 entry, which isn't an append-at-end update." Assessment: **Partially Agree**. Initial action swapped the PR #154 (post-bump) and PR #155 sections to honor chronological order. **Reverted** after Copilot ID 3211981185 (on PR #156) flagged that swap as a violation of the documented "never overwrite — always append" rule. Final state: PR #154 (post-bump) and PR #155 sections restored to their original (append-arrival) order; this follow-up entry remains appended at strict EOF.
- `ROADMAP.md:5` (Copilot, ID 3211981166 on PR #156) — "The ROADMAP entry says `release-publish.yml` runs PSScriptAnalyzer with 'Error/Warning severity', but the workflow currently invokes `Invoke-ScriptAnalyzer` with `-Severity Error` only (warnings are not requested or surfaced)." Assessment: **Agree**. Action: replaced the inaccurate "Error/Warning severity" wording with `-Severity Error (only Error-severity findings block; uses shared PSScriptAnalyzerSettings.psd1)`, matching `.github/workflows/release-publish.yml:47-48`.
- `artifacts/copilot-review-log.md:72` (Copilot, ID 3211981185 on PR #156) — "`artifacts/copilot-review-log.md` is documented as append-only ('never overwrite — always append'). Moving the PR #154 (post-bump) section below PR #155 rewrites existing log history." Assessment: **Agree**. Action: reverted the section swap so PR #154 (post-bump) is restored above PR #155 (original on-disk order). Append-only history preserved; new entries continue to land at strict EOF.
- `artifacts/copilot-review-log.md:78` (Copilot, ID 3211981197 on PR #156) — "The log entry uses a placeholder `Reviewed head SHA: pending`. For auditability/traceability, please replace this with the actual head commit SHA for this PR branch before merge." Assessment: **Agree**. Action: replaced `pending` with `ee4d447` (the head SHA Copilot reviewed). Subsequent fix-up commits on the same branch are noted alongside the SHA so audit trail remains complete.

## PR #174 — fix/dedupe-public-function

- Branch: fix/dedupe-public-function
- Reviewed head SHA: df4bfb6
- `tools/Validate-Script.ps1:103` (Copilot, thread PRRT_kwDOQ-syKc6WFi7l) — "The Pester availability check treats Pester 6 as acceptable (`Major -ge 5`), but the subsequent `Import-Module Pester -MaximumVersion 5.99.99 -ErrorAction Stop` will throw if only Pester 6 is installed. This error is currently uncaught, so the validation script can terminate abruptly instead of reporting a skip/failure." Assessment: **Agree**. This is precisely the drift scenario this PR exists to fix: CI installed an unpinned Pester, landed on 6.x, and `Assert-MockCalled` vanished. Adding a 5.x ceiling to the import while leaving the probe at `-ge 5` would convert a clean SKIP into an unhandled terminating error on any machine that has only Pester 6 — trading one silent failure for a louder one. Action: narrowed the probe from `$_.Version.Major -ge 5` to `$_.Version.Major -eq 5` so it matches the `-MinimumVersion 5.0 -MaximumVersion 5.99.99` window actually used by the import, and updated the SKIP text to name 5.x explicitly with a `-RequiredVersion 5.7.1` install hint.
- `tools/Validate-Script.ps1:470` (Copilot, thread PRRT_kwDOQ-syKc6WFi76) — "`$dupFindings` also includes parse errors (see earlier `$parseErrors` handling), so the failure message is misleading when the findings are not strictly 'duplicate definitions'. Consider using a neutral term like 'finding(s)' here so the output stays accurate." Assessment: **Agree**. Check 8 deliberately folds parse failures into the same collection so an unparseable module file cannot pass the guard by default, which means the collection is genuinely heterogeneous. Labelling every entry a "duplicate definition" would misreport a parse error and send a reader looking for a duplicate that does not exist. Action: changed the failure header from `$($dupFindings.Count) duplicate definition(s) found:` to `$($dupFindings.Count) finding(s):`. The per-item detail lines already distinguish the two cases, so no other wording changed and the PASS message stays specific.

## PR #175 — fix/auto-publish-null-lsremote

- Branch: fix/auto-publish-null-lsremote
- Reviewed head SHA: be47eb9
- `.github/workflows/auto-publish.yml:138` (Copilot, thread PRRT_kwDOQ-syKc6WF6LQ) — "`-join` will iterate a single string character-by-character. Since `git ls-remote` typically returns a single line when the branch exists, `$existing` can become the ref line with newlines inserted between every character. That still works for `IsNullOrWhiteSpace`, but it's surprising and could break future uses (e.g., logging or parsing). Wrap the native output in `@(...)` so `-join` always operates on a string array and remains null-safe." Assessment: **Partially Agree**. The stated mechanism is factually incorrect and was disproved empirically before acting: PowerShell's `-join` treats a scalar `[string]` as a single-element collection and returns it unchanged. Verified with `'abc123def' -join "`n"` -> `'abc123def'` (`-ceq` True, length 9 -> 9) and with a realistic `<sha>`+TAB+`refs/heads/...` payload (`-ceq` True). Bare and `@()`-wrapped forms produce byte-identical results across all three real cases: absent branch (`IsNullOrWhiteSpace` True, len 0), single ref (False, len 48), multiple refs (False, len 97). So there is no character-splitting defect and no behavioral difference to fix. The recommendation itself is nonetheless sound on readability grounds — this line exists specifically because native-command output has ambiguous arity (null / scalar / array), and `@(...)` states the array intent explicitly at the call site rather than relying on the reader knowing `-join`'s scalar semantics. Action: adopted `@(& git ls-remote --heads origin $branch) -join "`n"` and extended the adjacent comment with "`@(...)` forces array semantics so `-join` always sees a collection." No functional change; the null-safety fix that motivated this PR is unaffected.

## PR #176 - chore/auto-publish-3.0.1 - commit f1847b2

**File:** `AzVMAvailability/AzVMAvailability.psd1:26`
**Copilot finding:** "`ReleaseNotes` is indented differently than the other `PSData` keys in this hashtable, which makes the manifest harder to read and can look like it's at a different nesting level. Align its indentation with `Tags`, `LicenseUri`, and `ProjectUri`."
**Assessment:** Agree
**Reasoning:** Verified directly. `Tags`, `LicenseUri`, and `ProjectUri` are indented 12 spaces inside the `PSData` hashtable; `ReleaseNotes` was at 8. Root cause is `.github/workflows/auto-publish.yml` line 282, where `\` hardcodes an 8-space prefix. Because the regex `(?m)^\s*ReleaseNotes\s*=\s*'[^']+'` consumes the leading whitespace, the replacement string fully controls indentation, so every auto-published release would reintroduce the same misalignment.
**Action taken:** Corrected the indentation to 12 spaces in the manifest AND fixed the generator in `auto-publish.yml` so the defect does not recur. The 12-space form also naturally aligns the `=` with the sibling keys.

## PR #177 - test/exportrow-regression-170 - branch commit for ExportRow test

**File:** `tests/ExportRow.Tests.ps1:33`
**Copilot finding:** "The parse-failure exception omits the target file path, which makes failures harder to diagnose in CI logs (especially when multiple AST parses happen in the suite). Include `\` in the thrown message (similar to tests/TestHarness.psm1)."
**Assessment:** Agree
**Reasoning:** Verified. The throw read `"Public file failed to parse: $messages"` with no path. Multiple test files in this suite parse module files via AST, so a bare parse-failure message is ambiguous in CI output. `tests/TestHarness.psm1` already includes the path in comparable errors, so this also aligns the new file with existing convention. Low risk - the change touches only an error string on a path that is not exercised when the module parses cleanly.
**Action taken:** Changed the throw to `"Public file failed to parse: $publicFile :: $messages"`. Full validation re-run: 8/8 checks PASS, 611 tests pass, exit 0.

## PRs #180, #173, #172 - Copilot review outcomes (batch entry)

**PR #180** (`chore/auto-publish-3.0.2` @ `1dd1f46`) - bot exemption for `release-metadata-guard.yml` + changelog blurb placement fix in `auto-publish.yml`.
**Copilot finding:** None. Review body: "Copilot reviewed 9 out of 9 changed files in this pull request and generated no comments."
**Assessment:** N/A - no findings to triage.
**Action taken:** None required. Sourcery also reviewed with no issues. Merged after code-owner approval with 12/12 checks green and 0 unresolved threads.

**PR #173** (`dependabot/github_actions/actions-minor-patch-83bd6e4a5a` @ `f981faa4`) - `github/codeql-action` 4 -> 4.37.4.
**Copilot finding:** None. Review state COMMENTED with no inline comments.
**Assessment:** N/A - no findings to triage.
**Action taken:** None required. This PR was also the first verification that the new bot exemption works: its `Release Metadata Guard` check went from FAILURE (pre-fix) to SUCCESS (post-fix).

**PR #172** (`dependabot/github_actions/actions/checkout-7` @ `2f2dc8ce`) - `actions/checkout` 6 -> 7 across 9 workflows.
**Copilot finding:** None. Review state APPROVED, body reports "Comments generated: 0".
**Assessment:** N/A - no findings to triage.
**Action taken:** None required. Major-version action bump accepted on the evidence that both Pester suites (ubuntu-latest and windows-latest) exercise the updated checkout action end to end and passed on the rebased head.

## PR #181 - fix/dashboard-empty-json-array - commit 422bc53

**File:** `tools/Generate-TrafficDashboard-Premium-v2.ps1:92`
**Copilot finding:** "The #region header still says it is using @() to guarantee arrays for ConvertTo-Json, but this block now relies on ConvertTo-SafeJsonArray to guarantee `[]` on empty input. Updating the header will keep the comment accurate for future maintenance."
**Assessment:** Agree
**Reasoning:** Correct and worth fixing. The header read "Build JSON - use @() to guarantee arrays for ConvertTo-Json", which described the exact mechanism this PR replaced because it does not work: `@()` guarantees an array in PowerShell, but piping that array to `ConvertTo-Json -AsArray` still emits nothing when it is empty. Leaving the header would assert the failed approach as the current one, which is the comment-rot pattern the project explicitly guards against.
**Action taken:** Changed the header to "Build JSON - ConvertTo-SafeJsonArray guarantees a literal [] on empty input". Re-ran full validation: 8/8 checks PASS, 611 tests, exit 0.

**Reviewer:** sourcery-ai (PR-level comment, not an inline thread)
**Finding:** "ConvertTo-SafeJsonArray assumes `\` is non-null; consider defensively handling `\` input (e.g., treating it as an empty array) to avoid potential .Count access errors if future callers change."
**Assessment:** Disagree
**Reasoning:** Tested rather than assumed, on PowerShell 7.6.4. The `[array]` parameter cast turns `\` into `\`, and `\.Count` returns `0` in PowerShell 3.0+ instead of throwing. All three null-passing forms were exercised - positional `\`, named `-Data \`, and omitting the parameter entirely - and each returned `'[]'` with no error. The described `.Count` access error is therefore not reachable. Adding a guard would be error handling for an impossible scenario, which the project's Simplicity First rule prohibits. Every call site also wraps its argument in `@()`, so a null can never reach the parameter in practice.
**Action taken:** None. Replied on the PR with the test results so the reasoning is visible to future reviewers.

## PR #184 - fix/release-schedule-safety-net - commit 997d6fb

**File:** `.github/workflows/release-on-main.yml:12`
**Copilot finding:** "With the new `schedule` trigger, this workflow can run concurrently with a `workflow_dispatch` (or a later `push`) run. Because the drift check and auto-publish step are not atomic, two runs can both observe `tag_exists == 'False'` and then race to `git tag`/`git push`, causing one run to fail or generate noisy errors. Consider adding a workflow-level `concurrency` group to serialize release-control runs."
**Assessment:** Agree
**Reasoning:** Correct, and this PR is what makes it likely. Tag creation is read-then-write across two separate steps - the drift step reads `tag_exists`, and a later step runs `git tag` then `git push` - so there is a real window where two runs both see a missing tag. Before this change overlap required a human to dispatch while a push run was in flight; adding a 6-hourly cron means a scheduled run can now start while any other run is mid-flight, on a fixed cadence. It also turns out `release-on-main.yml` was the only release-path workflow WITHOUT a concurrency group: `auto-publish.yml`, `release-publish.yml`, and `version-bump.yml` all already have one, so this was an existing gap in the house pattern that the schedule would have exposed.
**Action taken:** Added a workflow-level `concurrency` group `release-on-main` with `cancel-in-progress: false`, matching the sibling workflows. Chose serialize over cancel deliberately: a run already past the drift check may have created the tag but not yet the release, and cancelling it would strand a tag with no release attached. Full validation re-run: 8/8 checks PASS, 611 tests, exit 0.

**File:** `.github/workflows/release-on-main.yml:182`
**Copilot finding:** "Adding `schedule` to the auto-publish condition means the workflow may tag whatever commit happens to be at `main` when the cron fires (`github.sha`). If additional PRs merge between the version-bump commit and the scheduled run, the tag/release will point at a newer commit than the version bump / CHANGELOG entry [...] consider targeting the most recent commit that changed `Get-AzVMAvailability.ps1` instead of the current HEAD."
**Assessment:** Partially Agree
**Reasoning:** The mechanical observation is right - scheduled runs tag `github.sha`, which is main HEAD at cron time, and the delay window means later commits can land first. But the framing that this is a defect does not hold, and the proposed remedy would make things worse. Tagging HEAD is already the established behavior on every path: `v3.0.3` points at `0a7c51c` and contains four PRs (#172, #173, #181, #183), not just the version bump. That is correct - a release contains everything on main carrying that version, and the drift step validates `ScriptVersion` against manifest `ModuleVersion` at whatever SHA it checks out, so the tagged tree is always internally consistent. The release notes stay accurate because they are extracted from the `## [x.y.z]` CHANGELOG section, which is version-scoped rather than commit-scoped and accumulates every merged change. The suggested alternative - tag the most recent commit touching `Get-AzVMAvailability.ps1` - is arbitrary, because that file changes for reasons other than version bumps, and it would produce a release whose tree omits commits that are on main and already covered by the same version number. The stagnation guard explicitly blesses the inverse case, logging "only non-script files changed since - no version bump required".
**Action taken:** No change to the tagging target. The concurrency group added for the first finding also narrows the overlap window this concern depends on. Replied on the thread with the `v3.0.3` evidence so the reasoning is recorded rather than re-litigated.
