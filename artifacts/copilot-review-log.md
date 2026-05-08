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
