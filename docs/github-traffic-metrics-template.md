# GitHub Traffic Metrics Collection — Reusable Template

> **Purpose:** Drop this into any GitHub repo to collect and visualize traffic data that GitHub only retains for 14 days. Produces a hosted dashboard on GitHub Pages.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│  GitHub Actions (scheduled 2x/day)                      │
│  ┌───────────────────────────────────────────────┐      │
│  │ 1. Collect traffic via GitHub API              │      │
│  │ 2. Merge into CSV files (deduplicate by date)  │      │
│  │ 3. Generate static HTML dashboard              │      │
│  │ 4. Commit to traffic-data branch               │      │
│  └───────────────────────────────────────────────┘      │
│                         │                                │
│                         ▼                                │
│  traffic-data branch (orphan)                            │
│  ├── data/views.csv                                      │
│  ├── data/clones.csv                                     │
│  ├── data/stars.csv                                      │
│  ├── data/referrers.csv                                  │
│  ├── data/paths.csv                                      │
│  ├── data/repo-stats.csv                                 │
│  ├── data/release-downloads.csv                          │
│  ├── index.html  ← GitHub Pages serves this              │
│  └── dashboard.js                                        │
└─────────────────────────────────────────────────────────┘
```

**Key design decisions:**
- Data lives on an **orphan branch** (`traffic-data`) — keeps CSV history out of your main branch.
- Workflow runs **2x/day** (GitHub retains traffic only 14 days; 2x/day captures every day with margin).
- Also triggers on **star** and **fork** events for instant capture.
- Uses **concurrency control** so simultaneous triggers don't race on git push.
- Dashboard is a **static HTML file** with Chart.js — zero hosting cost via GitHub Pages.

---

## AI Implementation Instructions

> Give this entire section to an AI assistant (Copilot, Claude, etc.) along with the template files below.

### Prompt for AI

```
Implement GitHub traffic metrics collection for this repository. Follow the steps below exactly.

**Step 1 — Create the orphan branch**

Run these commands in the repo root:
  git checkout --orphan traffic-data
  mkdir -p data
  echo "Traffic data branch" > README.md
  git add README.md
  git commit -m "chore: initialize traffic-data branch"
  git push origin traffic-data
  git checkout main

**Step 2 — Create the workflow file**

Create `.github/workflows/collect-traffic.yml` using the template in this document.
Replace every instance of `YOUR_REPO_NAME` with the actual repo name (used only in the
dashboard title and HTML <title> tag — the workflow uses ${{ github.repository }}
automatically).

**Step 3 — Create the dashboard generator**

Create `tools/Generate-TrafficDashboard.ps1` using the template below. This script
reads CSVs from a data directory and produces a self-contained HTML file with Chart.js
charts. Adapt the HTML <title> and header to match the repo name.

If the project does not use PowerShell, convert the dashboard generator to a bash
script or Node.js script — the logic is: read CSVs → build JSON arrays → inject
into an HTML template → write output file.

**Step 4 — Enable GitHub Pages**

In the repo Settings → Pages:
  - Source: Deploy from a branch
  - Branch: traffic-data
  - Folder: / (root)

**Step 5 — (Optional) Create a Personal Access Token for private repos**

The built-in GITHUB_TOKEN can read traffic data for public repos. For private repos:
  1. Create a fine-grained PAT with Contents (read) + Metadata (read) permissions
  2. Add it as a repo secret named TRAFFIC_TOKEN
  3. The workflow template already falls back to TRAFFIC_TOKEN when present

**Step 6 — Protect the traffic-data branch from cleanup**

If you have a stale-branch-cleanup workflow, add 'traffic-data' to its protected list.

**Step 7 — Add a dashboard link to README**

Add this badge/link to your README:
  [![Traffic Dashboard](https://img.shields.io/badge/Dashboard-Traffic-blue)](https://YOUR_USERNAME.github.io/YOUR_REPO/)
```

---

## Template Files

### File 1: `.github/workflows/collect-traffic.yml`

```yaml
name: Collect Traffic Data

on:
  schedule:
    # Run 2x/day — 12:00 UTC and 00:00 UTC
    - cron: '0 0,12 * * *'
  watch:
    types: [started]   # star event — captures immediately
  fork:                # fork event — captures immediately
  workflow_dispatch:   # manual trigger for testing

# Prevent concurrent runs from racing on git push
concurrency:
  group: collect-traffic
  cancel-in-progress: true

permissions:
  contents: write

jobs:
  collect:
    runs-on: ubuntu-latest
    env:
      GH_TOKEN: ${{ github.token }}
    steps:
      - name: Checkout source branch (workflow + scripts)
        uses: actions/checkout@v4
        with:
          fetch-depth: 1

      - name: Checkout traffic-data branch
        uses: actions/checkout@v4
        with:
          ref: traffic-data
          path: traffic-data
          fetch-depth: 1

      - name: Ensure data directory exists
        run: mkdir -p traffic-data/data

      # ── Traffic API calls (use TRAFFIC_TOKEN for private repos) ──
      - name: Collect views
        env:
          GH_TOKEN: ${{ secrets.TRAFFIC_TOKEN || github.token }}
        run: |
          gh api repos/${{ github.repository }}/traffic/views > /tmp/views.json
          echo "Views collected"

      - name: Collect clones
        env:
          GH_TOKEN: ${{ secrets.TRAFFIC_TOKEN || github.token }}
        run: |
          gh api repos/${{ github.repository }}/traffic/clones > /tmp/clones.json
          echo "Clones collected"

      - name: Collect referrers
        env:
          GH_TOKEN: ${{ secrets.TRAFFIC_TOKEN || github.token }}
        run: |
          gh api repos/${{ github.repository }}/traffic/popular/referrers > /tmp/referrers.json
          echo "Referrers collected"

      - name: Collect popular paths
        env:
          GH_TOKEN: ${{ secrets.TRAFFIC_TOKEN || github.token }}
        run: |
          gh api repos/${{ github.repository }}/traffic/popular/paths > /tmp/paths.json
          echo "Paths collected"

      # ── Non-traffic endpoints (GITHUB_TOKEN is sufficient) ──
      - name: Collect stargazers
        run: |
          page=1
          echo "[]" > /tmp/stars.json
          while true; do
            response=$(gh api "repos/${{ github.repository }}/stargazers?per_page=100&page=$page" \
              -H "Accept: application/vnd.github.v3.star+json" 2>/dev/null || echo "[]")
            count=$(echo "$response" | jq length)
            if [ "$count" -eq 0 ]; then break; fi
            jq -s '.[0] + .[1]' /tmp/stars.json <(echo "$response") > /tmp/stars_merged.json
            mv /tmp/stars_merged.json /tmp/stars.json
            if [ "$count" -lt 100 ]; then break; fi
            page=$((page + 1))
          done
          echo "Stars collected: $(jq length /tmp/stars.json)"

      - name: Collect repo stats
        run: gh api repos/${{ github.repository }} > /tmp/repo.json

      - name: Collect releases
        run: gh api "repos/${{ github.repository }}/releases?per_page=100" > /tmp/releases.json

      # ── Merge into CSVs (deduplicate by date) ──
      - name: Merge into CSVs
        run: |
          TODAY=$(date -u +%Y-%m-%d)

          # ── Helper: merge daily records (skip dates already in CSV) ──
          merge_daily() {
            local csv_file="$1" header="$2" new_data="$3"
            if [ ! -f "$csv_file" ]; then echo "$header" > "$csv_file"; fi
            cp "$csv_file" /tmp/_existing.csv
            while IFS= read -r line; do
              date_val=$(echo "$line" | cut -d',' -f1 | tr -d '"')
              if ! grep -q "^\"*${date_val}" /tmp/_existing.csv 2>/dev/null; then
                echo "$line" >> /tmp/_existing.csv
              fi
            done <<< "$new_data"
            head -1 /tmp/_existing.csv > "$csv_file"
            tail -n +2 /tmp/_existing.csv | sort -t, -k1 >> "$csv_file"
          }

          # Views
          new_views=$(jq -r '.views[] | [(.timestamp | split("T")[0]), .count, .uniques] | @csv' /tmp/views.json)
          merge_daily "traffic-data/data/views.csv" "Date,TotalViews,UniqueViews" "$new_views"

          # Clones
          new_clones=$(jq -r '.clones[] | [(.timestamp | split("T")[0]), .count, .uniques] | @csv' /tmp/clones.json)
          merge_daily "traffic-data/data/clones.csv" "Date,TotalClones,UniqueClones" "$new_clones"

          # Referrers (snapshot per collection day)
          if [ ! -f traffic-data/data/referrers.csv ]; then
            echo "CollectedDate,Referrer,TotalViews,UniqueVisitors" > traffic-data/data/referrers.csv
          fi
          if ! grep -q "^\"*${TODAY}" traffic-data/data/referrers.csv 2>/dev/null; then
            jq -r --arg d "$TODAY" '.[] | [$d, .referrer, .count, .uniques] | @csv' \
              /tmp/referrers.json >> traffic-data/data/referrers.csv
          fi

          # Popular paths (snapshot per collection day)
          if [ ! -f traffic-data/data/paths.csv ]; then
            echo "CollectedDate,Path,Title,TotalViews,UniqueVisitors" > traffic-data/data/paths.csv
          fi
          if ! grep -q "^\"*${TODAY}" traffic-data/data/paths.csv 2>/dev/null; then
            jq -r --arg d "$TODAY" '.[] | [$d, .path, .title, .count, .uniques] | @csv' \
              /tmp/paths.json >> traffic-data/data/paths.csv
          fi

          # Stars (rebuild cumulative from API each time)
          echo "Date,User,CumulativeStars" > traffic-data/data/stars.csv
          count=0
          jq -r '.[] | [(.starred_at | split("T")[0]), .user.login] | @csv' /tmp/stars.json | \
          while IFS=, read -r date user; do
            count=$((count + 1))
            echo "$(echo $date | tr -d '"'),$(echo $user | tr -d '"'),$count"
          done >> traffic-data/data/stars.csv

          # Repo stats (daily snapshot)
          if [ ! -f traffic-data/data/repo-stats.csv ]; then
            echo "Date,Stars,Forks,Watchers,OpenIssues,Size_KB" > traffic-data/data/repo-stats.csv
          fi
          if ! grep -q "^\"*${TODAY}" traffic-data/data/repo-stats.csv 2>/dev/null; then
            jq -r --arg d "$TODAY" \
              '[$d, .stargazers_count, .forks_count, .subscribers_count, .open_issues_count, .size] | @csv' \
              /tmp/repo.json >> traffic-data/data/repo-stats.csv
          fi

          # Release downloads (daily snapshot)
          if [ ! -f traffic-data/data/release-downloads.csv ]; then
            echo "Date,TotalReleaseDownloads,ReleaseCount,AssetCount" > traffic-data/data/release-downloads.csv
          fi
          if ! grep -q "^\"*${TODAY}" traffic-data/data/release-downloads.csv 2>/dev/null; then
            total_dl=$(jq '[.[].assets[]?.download_count] | add // 0' /tmp/releases.json)
            rel_count=$(jq 'length' /tmp/releases.json)
            asset_count=$(jq '[.[].assets | length] | add // 0' /tmp/releases.json)
            echo "${TODAY},${total_dl},${rel_count},${asset_count}" >> traffic-data/data/release-downloads.csv
          fi

          echo "=== Collection Summary ==="
          for f in views clones stars referrers paths repo-stats release-downloads; do
            count=$(tail -n +2 "traffic-data/data/${f}.csv" 2>/dev/null | wc -l)
            echo "  ${f}: ${count} records"
          done

      # ── Generate dashboard ──
      # OPTION A: If you have PowerShell in the repo (see dashboard generator template below)
      # - name: Generate dashboard
      #   shell: pwsh
      #   run: |
      #     ./tools/Generate-TrafficDashboard.ps1 -InputDir "./traffic-data/data" -OutputFile "./traffic-data/index.html"

      # OPTION B: Inline bash dashboard (minimal — just a redirect or use the JS-only approach)
      - name: Generate dashboard
        run: |
          # Copy dashboard.js if it exists in source
          if [ -f tools/dashboard.js ]; then
            cp tools/dashboard.js traffic-data/dashboard.js
          fi
          # Generate index.html — see "Dashboard Generator" section for full template
          echo "<!-- Replace this with the full dashboard generator output -->" > traffic-data/index.html

      - name: Commit and push
        working-directory: traffic-data
        run: |
          git config user.name "github-actions[bot]"
          git config user.email "github-actions[bot]@users.noreply.github.com"
          git add data/ index.html
          # Also add dashboard.js if present
          [ -f dashboard.js ] && git add dashboard.js
          if git diff --cached --quiet; then
            echo "No new data to commit"
          else
            git commit -m "chore: collect traffic data $(date -u +%Y-%m-%d)"
            git push
          fi
```

### File 2: `tools/Generate-TrafficDashboard.ps1` (PowerShell — adapt to bash/node if needed)

```powershell
<#
.SYNOPSIS
    Generates a self-contained HTML traffic dashboard from CSV data files.
.PARAMETER InputDir
    Directory containing traffic CSV files.
.PARAMETER OutputFile
    Path for the generated HTML file.
.PARAMETER RepoName
    Display name for the dashboard header. Defaults to parent directory name.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$InputDir,
    [string]$OutputFile,
    [string]$RepoName
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $OutputFile) { $OutputFile = Join-Path $InputDir 'index.html' }
if (-not $RepoName)   { $RepoName = Split-Path (Split-Path $InputDir) -Leaf }

# ── Load CSVs ──
$views  = @(if (Test-Path "$InputDir/views.csv")  { Import-Csv "$InputDir/views.csv"  | Sort-Object Date })
$clones = @(if (Test-Path "$InputDir/clones.csv") { Import-Csv "$InputDir/clones.csv" | Sort-Object Date })
$stars  = @(if (Test-Path "$InputDir/stars.csv")  { Import-Csv "$InputDir/stars.csv"  | Sort-Object Date })
$repoStats = @(if (Test-Path "$InputDir/repo-stats.csv") { Import-Csv "$InputDir/repo-stats.csv" | Sort-Object Date })

# ── Build JSON arrays for Chart.js ──
$viewDates   = @($views  | ForEach-Object { $_.Date })            | ConvertTo-Json -Compress -AsArray
$viewTotals  = @($views  | ForEach-Object { [int]$_.TotalViews }) | ConvertTo-Json -Compress -AsArray
$viewUniques = @($views  | ForEach-Object { [int]$_.UniqueViews })| ConvertTo-Json -Compress -AsArray

$cloneDates   = @($clones | ForEach-Object { $_.Date })             | ConvertTo-Json -Compress -AsArray
$cloneTotals  = @($clones | ForEach-Object { [int]$_.TotalClones }) | ConvertTo-Json -Compress -AsArray
$cloneUniques = @($clones | ForEach-Object { [int]$_.UniqueClones })| ConvertTo-Json -Compress -AsArray

$starDates      = @($stars | ForEach-Object { $_.Date })                | ConvertTo-Json -Compress -AsArray
$starCumulative = @($stars | ForEach-Object { [int]$_.CumulativeStars })| ConvertTo-Json -Compress -AsArray

# Compute summary stats
$totalViews  = if ($views.Count -gt 0) { ($views  | ForEach-Object { [int]$_.TotalViews }  | Measure-Object -Sum).Sum } else { 0 }
$totalClones = if ($clones.Count -gt 0) { ($clones | ForEach-Object { [int]$_.TotalClones } | Measure-Object -Sum).Sum } else { 0 }
$totalStars  = if ($stars.Count -gt 0) { ($stars[-1]).CumulativeStars } else { 0 }
$generatedAt = (Get-Date).ToString('MMM d, yyyy')

# ── Generate HTML ──
$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Traffic — $RepoName</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4/dist/chart.umd.min.js"></script>
<style>
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
         background: #0d1117; color: #e6edf3; line-height: 1.5; }
  .container { max-width: 1200px; margin: 0 auto; padding: 2rem; }
  h1 { font-size: 1.5rem; margin-bottom: 0.5rem; }
  .subtitle { color: #8b949e; margin-bottom: 2rem; font-size: 0.875rem; }
  .cards { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 1rem; margin-bottom: 2rem; }
  .card { background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 1.25rem; }
  .card .label { color: #8b949e; font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em; }
  .card .value { font-size: 1.75rem; font-weight: 700; margin-top: 0.25rem; }
  .chart-box { background: #161b22; border: 1px solid #30363d; border-radius: 8px; padding: 1.5rem; margin-bottom: 1.5rem; }
  .chart-box h2 { font-size: 1rem; margin-bottom: 1rem; font-weight: 600; }
  canvas { width: 100% !important; }
</style>
</head>
<body>
<div class="container">
  <h1>$RepoName — Traffic Dashboard</h1>
  <p class="subtitle">Generated $generatedAt &bull; Updated 2&times;/day via GitHub Actions</p>

  <div class="cards">
    <div class="card"><div class="label">Total Views</div><div class="value">$totalViews</div></div>
    <div class="card"><div class="label">Total Clones</div><div class="value">$totalClones</div></div>
    <div class="card"><div class="label">Stars</div><div class="value">$totalStars</div></div>
    <div class="card"><div class="label">Days Tracked</div><div class="value">$($views.Count)</div></div>
  </div>

  <div class="chart-box"><h2>Page Views</h2><canvas id="viewsChart"></canvas></div>
  <div class="chart-box"><h2>Clones</h2><canvas id="clonesChart"></canvas></div>
  <div class="chart-box"><h2>Stars</h2><canvas id="starsChart"></canvas></div>
</div>
<script>
  Chart.defaults.color = '#8b949e';
  Chart.defaults.font.family = '-apple-system, BlinkMacSystemFont, system-ui, sans-serif';
  var gY = { grid: { color: 'rgba(255,255,255,0.06)' }, beginAtZero: true };
  var gX = { grid: { display: false } };
  function mkGrad(ctx, r, g, b) {
    var gr = ctx.createLinearGradient(0, 0, 0, 250);
    gr.addColorStop(0, 'rgba('+r+','+g+','+b+',0.2)');
    gr.addColorStop(1, 'rgba('+r+','+g+','+b+',0)');
    return gr;
  }
  var opts = { responsive: true, interaction: { intersect: false, mode: 'index' },
    plugins: { legend: { position: 'bottom', labels: { usePointStyle: true, boxWidth: 6 } } },
    scales: { y: gY, x: gX }, elements: { point: { radius: 0, hoverRadius: 4 }, line: { borderWidth: 2 } } };

  // Views chart
  new Chart(document.getElementById('viewsChart'), { type: 'line', data: {
    labels: $viewDates, datasets: [
      { label: 'Total', data: $viewTotals, borderColor: '#3b82f6',
        backgroundColor: mkGrad(document.getElementById('viewsChart').getContext('2d'), 59,130,246), fill: true },
      { label: 'Unique', data: $viewUniques, borderColor: '#22c55e', fill: false }
    ]}, options: opts });

  // Clones chart
  new Chart(document.getElementById('clonesChart'), { type: 'line', data: {
    labels: $cloneDates, datasets: [
      { label: 'Total', data: $cloneTotals, borderColor: '#a855f7',
        backgroundColor: mkGrad(document.getElementById('clonesChart').getContext('2d'), 168,85,247), fill: true },
      { label: 'Unique', data: $cloneUniques, borderColor: '#f59e0b', fill: false }
    ]}, options: opts });

  // Stars chart
  new Chart(document.getElementById('starsChart'), { type: 'line', data: {
    labels: $starDates, datasets: [
      { label: 'Total Stars', data: $starCumulative, borderColor: '#f59e0b',
        backgroundColor: mkGrad(document.getElementById('starsChart').getContext('2d'), 245,158,11), fill: true }
    ]}, options: { ...opts, plugins: { ...opts.plugins, legend: { display: false } } } });
</script>
</body>
</html>
"@

$html | Set-Content -Path $OutputFile -Encoding utf8
Write-Host "Dashboard generated: $OutputFile" -ForegroundColor Green
```

---

## CSV Data Schemas

| File | Columns | Dedup Key | Notes |
|------|---------|-----------|-------|
| `views.csv` | `Date,TotalViews,UniqueViews` | Date | One row per day |
| `clones.csv` | `Date,TotalClones,UniqueClones` | Date | One row per day |
| `stars.csv` | `Date,User,CumulativeStars` | Rebuilt each run | Full history from API |
| `referrers.csv` | `CollectedDate,Referrer,TotalViews,UniqueVisitors` | CollectedDate | Snapshot — one set of rows per collection day |
| `paths.csv` | `CollectedDate,Path,Title,TotalViews,UniqueVisitors` | CollectedDate | Snapshot — one set of rows per collection day |
| `repo-stats.csv` | `Date,Stars,Forks,Watchers,OpenIssues,Size_KB` | Date | Daily snapshot of repo metadata |
| `release-downloads.csv` | `Date,TotalReleaseDownloads,ReleaseCount,AssetCount` | Date | Daily snapshot of release asset downloads |

---

## Setup Checklist

- [ ] Create `traffic-data` orphan branch
- [ ] Add `.github/workflows/collect-traffic.yml`
- [ ] Add dashboard generator script (PowerShell, bash, or Node.js)
- [ ] Enable GitHub Pages (branch: `traffic-data`, folder: `/`)
- [ ] (Private repos only) Create `TRAFFIC_TOKEN` secret with `repo` scope PAT
- [ ] Protect `traffic-data` from stale branch cleanup
- [ ] Add dashboard badge/link to README
- [ ] Run workflow manually once (`workflow_dispatch`) to verify
- [ ] Confirm dashboard renders at `https://USERNAME.github.io/REPO/`

---

## FAQ

**Q: Why an orphan branch?**
A: Keeps hundreds of CSV commits out of your main branch history. The traffic-data branch has its own linear history of data commits only.

**Q: Why 2x/day?**
A: GitHub's traffic API returns the last 14 days of data. Collecting twice a day ensures no day is missed even if one run fails. More frequent runs don't add value since the API only updates daily.

**Q: Do I need a PAT?**
A: For **public repos**, the default `GITHUB_TOKEN` has read access to traffic endpoints. For **private repos**, you need a PAT with `repo` scope stored as the `TRAFFIC_TOKEN` secret.

**Q: How much storage does this use?**
A: Minimal. After a year of collection: ~365 rows in views/clones CSVs (~15 KB each), plus snapshots. The HTML dashboard is ~30-50 KB.

**Q: Can I use this without PowerShell?**
A: Yes. The workflow itself is pure bash. The dashboard generator is the only PowerShell piece — replace it with a bash script that builds the HTML from CSVs, or use a static site generator.
