# CI/CD Workflows

This document describes every GitHub Actions workflow in `.github/workflows/` — what it does, when it triggers, and what failures mean.

---

## Workflows at a Glance

| Workflow file | Display name | Trigger | Purpose |
|---|---|---|---|
| `powershell-lint.yml` | PowerShell Linting | Push/PR to `main`, manual | Lint, test, and audit gate |
| `release-metadata-guard.yml` | Release Metadata Guard | PR to `main`, manual | Version/changelog parity check |
| `release-on-main.yml` | Release Drift Check and Publish | Push to `main`, manual | Auto tag + draft release |
| `scheduled-health-check.yml` | Scheduled Tooling Health Check | Weekly (Mon 09:00 UTC), manual | Tooling freshness check |
| `collect-traffic.yml` | Collect Traffic Data | Daily (06:00 UTC), manual | Repository traffic data + dashboard |

---

## 1. PowerShell Linting (`powershell-lint.yml`)

**Triggers:** push to `main`, pull request targeting `main`, manual dispatch.

This workflow runs three parallel jobs:

### `lint` — PSScriptAnalyzer

Runs `microsoft/psscriptanalyzer-action` with `PSScriptAnalyzerSettings.psd1` on every `.ps1` and `.psm1` file in the repository. Results are uploaded as a SARIF file to GitHub code scanning (Security → Code scanning alerts).

**Failure means:** a lint rule defined in `PSScriptAnalyzerSettings.psd1` was violated. Fix the flagged lines, or if the violation is intentional, add a `[SuppressMessage]` attribute.

### `test` — Pester Tests

Installs Pester 5+ and runs `Invoke-Pester ./tests`. The job fails if any test reports a failure.

**Failure means:** a Pester test in `./tests/` failed. Run `Invoke-Pester ./tests -Output Detailed` locally to reproduce.

### `audit` — Repo Self-Audit

Runs `tools/Invoke-RepoSelfAudit.ps1` with `-FailOnCritical -MaxAllowedCritical 2`. The audit report is uploaded as a workflow artifact named `audit-report` (available in the run's Artifacts section).

**Failure means:** the repo self-audit found more than 2 critical findings. Download the `audit-report` artifact and review `artifacts/audit/` to see what needs to be fixed.

---

## 2. Release Metadata Guard (`release-metadata-guard.yml`)

**Triggers:** pull request targeting `main`, manual dispatch.

This is the primary PR gate. It validates that every pull request leaves the repository in a releasable state.

### What it checks

| Check | How it passes |
|---|---|
| `docs/VERIFY-RELEASE.md` exists | File must be present |
| `.github/skills/release-verification-checklist/SKILL.md` exists | File must be present |
| `.NOTES Version` matches `$ScriptVersion` | Both version strings in `Get-AzVMAvailability.ps1` must be identical |
| CHANGELOG entry exists | If `$ScriptVersion` changed → `## [X.Y.Z]` heading must appear; if version unchanged → `## [Unreleased]` section must contain at least one entry |
| PR checklist box ticked (version bumps only) | When `$ScriptVersion` changed, the PR body must contain a checked `Release/tag plan prepared for this version bump` checkbox |

**Failure means:** one of the checks above failed. The error message in the workflow log identifies which check and what to fix.

---

## 3. Release Drift Check and Publish (`release-on-main.yml`)

**Triggers:** push to `main`, manual dispatch.

This workflow runs after every merge to `main`. It compares the `$ScriptVersion` in `Get-AzVMAvailability.ps1` against existing git tags and creates a release when a new version is detected.

### Flow

```
Push to main
    └── Detect version/tag drift
            ├── Tag exists and only non-script files changed → pass silently
            ├── Tag exists but script changed → FAIL (version stagnation)
            ├── ScriptVersion is lower than latest tag → FAIL (version regression)
            └── Tag does not exist
                    ├── Extract CHANGELOG section for release notes
                    ├── Create git tag on HEAD
                    └── Create GitHub release (published by default; draft on manual dispatch)
```

### Manual dispatch inputs

| Input | Default | Description |
|---|---|---|
| `auto_publish` | `true` | Set to `false` to open a drift issue instead of auto-publishing |
| `draft_release` | `true` | Set to `true` to create a draft release instead of a published one |

**Failure means:**

- **Version stagnation** — `Get-AzVMAvailability.ps1` changed since the last tag but `$ScriptVersion` was not bumped. Bump the version, add a CHANGELOG entry, and push.
- **Version regression** — `$ScriptVersion` is lower than the latest existing tag. Correct the version string.
- **Missing CHANGELOG section** — `$ScriptVersion` changed but `CHANGELOG.md` is missing `## [X.Y.Z]`. Add the heading and release notes.
- **Release not found post-create** — the release creation step succeeded but the verify step could not find it. This is rare; check the GitHub releases page and re-run the workflow.

---

## 4. Scheduled Tooling Health Check (`scheduled-health-check.yml`)

**Triggers:** every Monday at 09:00 UTC, manual dispatch.

Runs `tools/Validate-Script.ps1` against `main` weekly to detect tooling rot (broken linter settings, failing tests, version drift) before it affects contributors.

### What `Validate-Script.ps1` checks

1. **PowerShell syntax** — `[System.Management.Automation.Language.Parser]::ParseFile`
2. **PSScriptAnalyzer** — same settings as CI
3. **Pester tests** — `Invoke-Pester ./tests`
4. **AI-comment pattern scan** — flags comments like `# This ensures`, `# Must be after`, `# Handle potential`
5. **Version consistency** — scans `docs/*.md` (via `git ls-files`) for version strings that don't match `$ScriptVersion`

**Failure behavior:** if `Validate-Script.ps1` exits non-zero, the workflow opens a GitHub issue titled `Tooling health check failed -- YYYY-MM-DD` (idempotent — no duplicate issues) and then fails the job. The issue body includes a link to the failed run.

**Failure means:** run `.\tools\Validate-Script.ps1` locally and fix whatever it reports.

---

## 5. Collect Traffic Data (`collect-traffic.yml`)

**Triggers:** daily at 06:00 UTC, manual dispatch.

Collects GitHub traffic metrics (views, clones, referrers, popular paths, stargazers, repo stats, release downloads) and commits the results to the `traffic-data` branch. Also regenerates `dashboard.html` / `index.html` for GitHub Pages.

### Data files (committed to `traffic-data` branch)

| File | Contents |
|---|---|
| `data/views.csv` | Daily page views and unique visitors |
| `data/clones.csv` | Daily clone count and unique cloners |
| `data/referrers.csv` | Referring sites snapshot (per collection date) |
| `data/paths.csv` | Popular paths snapshot (per collection date) |
| `data/stars.csv` | All-time stargazers with timestamps and cumulative count |
| `data/repo-stats.csv` | Daily snapshot: stars, forks, watchers, open issues, repo size |
| `data/release-downloads.csv` | Daily snapshot: total release asset downloads |
| `dashboard.html` / `index.html` | Generated GitHub Pages traffic dashboard |

### Required secrets

| Secret | Used for |
|---|---|
| `TRAFFIC_TOKEN` (optional) | The four `/traffic/*` API endpoints require a PAT with `repo` scope. Falls back to `GITHUB_TOKEN` if the secret is absent, but traffic data will be empty for repositories you don't own. |

**Failure means:** an API call failed or the `traffic-data` branch is missing. Verify that the `traffic-data` branch exists and that `TRAFFIC_TOKEN` is configured if the repository is not owned by the workflow actor.

---

## Common Failure Remediation

| Symptom | Likely cause | Fix |
|---|---|---|
| Release guard fails on version check | `.NOTES Version` ≠ `$ScriptVersion` | Update both to match in `Get-AzVMAvailability.ps1` |
| Release guard fails on `[Unreleased]` | CHANGELOG `[Unreleased]` section is empty | Add at least one entry under `## [Unreleased]` |
| Release workflow fails with "version stagnation" | Script changed but version not bumped | Bump `$ScriptVersion`, add CHANGELOG entry |
| Pester tests fail in CI but pass locally | PowerShell version difference | Run `pwsh -File .\...` (PowerShell 7+), not `powershell` |
| Audit fails with >2 critical findings | New regressions introduced | Run `tools/Invoke-RepoSelfAudit.ps1` locally and review output |
| Weekly health check opens a new issue | Tooling regression on `main` | Run `.\tools\Validate-Script.ps1` locally and fix |
