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