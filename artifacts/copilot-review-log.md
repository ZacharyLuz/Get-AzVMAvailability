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

## PR #155 — ci/auto-publish-on-merge

- Branch: ci/auto-publish-on-merge
- Reviewed head SHA: e035495 (fixes in follow-up commit)
- `.github/workflows/auto-publish.yml:102` (Sourcery, bug_risk) — "Version parsing error handling never triggers because the TryParse results are not actually validated. `[version]::TryParse` returns a `bool` and always assigns a (non-nullable) `[version]` struct to the out parameter, so `$parsedCurrent` / `$parsedLatest` will never be falsy." Assessment: **Agree**. Action: capture the `bool` return values into `$okCurrent` / `$okLatest` and check those in the `throw` guard.
- `.github/workflows/auto-publish.yml:215` (Sourcery, suggestion) — "The CHANGELOG `[Unreleased]` promotion logic fails if `[Unreleased]` is the last section in the file." Assessment: **Agree**. Action: changed regex lookahead from `(?=\n##\s+\[)` to `(?=(\n##\s+\[|\Z))` so a trailing `[Unreleased]` block is still promoted.
- `.github/workflows/auto-publish.yml:189` (Copilot) — "`[regex]::Replace($text, $t.Pattern, $replacement, 1)` is not a reliable way to limit replacements to a single match. In .NET, the 4-argument overload commonly binds the last argument as `RegexOptions` (so `1` becomes `IgnoreCase`)." Assessment: **Agree**. Action: replaced static call with a `[regex]::new($t.Pattern)` instance and called the instance `.Replace(input, replacement, 1)` overload, which genuinely accepts a count.
- `.github/workflows/auto-publish.yml:398` (Copilot) — "The dry-run output line uses `"$(${{ steps.detect.outputs.latest_tag }})"`, which will be expanded by Actions into something like `$(v2.2.2)` and then executed as a PowerShell subexpression, causing a parse/runtime error." Assessment: **Agree**. Action: removed the `$(...)` wrapper so Actions interpolation is printed verbatim, matching the previous two `Write-Host` lines.
- `.github/workflows/auto-publish.yml:195` (Copilot) — "The workflow writes PowerShell files (`*.ps1`/`*.psd1`) using `Set-Content -Encoding utf8`, which in pwsh writes UTF-8 **without BOM** and may also introduce LF-only line endings where the repo requires CRLF." Assessment: **Partially Agree** (intentional non-fix in this PR). The `.editorconfig` does require UTF-8-BOM for `*.ps1`/`*.psm1`/`*.psd1`, but `.github/workflows/version-bump.yml` already uses the identical `Set-Content -Encoding utf8` / `Add-Content -Encoding utf8` pattern on the same file set. Fixing it only in `auto-publish.yml` would create asymmetry between the two workflows that share these targets, and would risk diverging output. Action: leaving as-is in PR #155 to preserve parity with the established `version-bump.yml` pattern; tracked as a separate cleanup that should fix both workflows in one pass.
