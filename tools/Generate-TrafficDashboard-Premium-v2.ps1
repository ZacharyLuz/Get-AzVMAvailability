<#
.SYNOPSIS
    Generates a premium v2 HTML traffic dashboard — full-width charts.

.DESCRIPTION
    Reads CSV files from artifacts/traffic/ and produces a self-contained HTML
    dashboard with glassmorphism cards, smooth gradients, fluid animations,
    and interactive Chart.js visualizations.

.PARAMETER InputDir
    Directory containing traffic CSV files. Defaults to artifacts/traffic/.

.PARAMETER OutputFile
    Path for the generated HTML file. Defaults to artifacts/traffic/dashboard-premium-v2.html.

.EXAMPLE
    .\tools\Generate-TrafficDashboard-Premium-v2.ps1
#>

[CmdletBinding()]
param(
    [string]$InputDir,
    [string]$OutputFile
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Setup Paths
if (-not $InputDir) {
    $InputDir = Join-Path $PSScriptRoot '..' 'artifacts' 'traffic'
    $InputDir = [System.IO.Path]::GetFullPath($InputDir)
}
if (-not $OutputFile) {
    $OutputFile = Join-Path $InputDir 'dashboard-premium-v2.html'
}
if (-not (Test-Path $InputDir)) {
    Write-Error "Input directory not found: $InputDir. Run Collect-TrafficData.ps1 first."
    return
}
#endregion

#region Load CSV Data
$viewsPath     = Join-Path $InputDir 'views.csv'
$clonesPath    = Join-Path $InputDir 'clones.csv'
$starsPath     = Join-Path $InputDir 'stars.csv'
$referrersPath = Join-Path $InputDir 'referrers.csv'
$pathsPath     = Join-Path $InputDir 'paths.csv'
$repoStatsPath = Join-Path $InputDir 'repo-stats.csv'
$releaseDownloadsPath = Join-Path $InputDir 'release-downloads.csv'

$views     = if (Test-Path $viewsPath)     { @(Import-Csv $viewsPath     | Sort-Object Date) } else { @() }
$clones    = if (Test-Path $clonesPath)    { @(Import-Csv $clonesPath    | Sort-Object Date) } else { @() }
$stars     = if (Test-Path $starsPath)     { @(Import-Csv $starsPath     | Sort-Object Date) } else { @() }
$repoStats = if (Test-Path $repoStatsPath) { @(Import-Csv $repoStatsPath | Sort-Object Date) } else { @() }
$releaseDownloads = if (Test-Path $releaseDownloadsPath) { @(Import-Csv $releaseDownloadsPath | Sort-Object Date) } else { @() }

$referrers = @()
if (Test-Path $referrersPath) {
    $allRefs = @(Import-Csv $referrersPath)
    $latestDate = ($allRefs | Sort-Object CollectedDate -Descending | Select-Object -First 1).CollectedDate
    $referrers = @($allRefs | Where-Object { $_.CollectedDate -eq $latestDate } | Sort-Object { [int]$_.TotalViews } -Descending)
}

$paths = @()
if (Test-Path $pathsPath) {
    $allPaths = @(Import-Csv $pathsPath)
    $latestDate = ($allPaths | Sort-Object CollectedDate -Descending | Select-Object -First 1).CollectedDate
    $paths = @($allPaths | Where-Object { $_.CollectedDate -eq $latestDate } | Sort-Object { [int]$_.TotalViews } -Descending | Select-Object -First 10)
}

Write-Host "Loaded: $($views.Count) view days, $($clones.Count) clone days, $($stars.Count) stars, $($referrers.Count) referrers, $($paths.Count) paths, $(@($releaseDownloads).Count) release download snapshots" -ForegroundColor Cyan
#endregion

#region Build JSON
$viewDates    = ($views  | ForEach-Object { $_.Date })            | ConvertTo-Json -Compress
$viewTotals   = ($views  | ForEach-Object { [int]$_.TotalViews }) | ConvertTo-Json -Compress
$viewUniques  = ($views  | ForEach-Object { [int]$_.UniqueViews })| ConvertTo-Json -Compress

$cloneDates   = ($clones | ForEach-Object { $_.Date })             | ConvertTo-Json -Compress
$cloneTotals  = ($clones | ForEach-Object { [int]$_.TotalClones }) | ConvertTo-Json -Compress
$cloneUniques = ($clones | ForEach-Object { [int]$_.UniqueClones })| ConvertTo-Json -Compress

$starDates      = ($stars | ForEach-Object { $_.Date })               | ConvertTo-Json -Compress
$starCumulative = ($stars | ForEach-Object { [int]$_.CumulativeStars })| ConvertTo-Json -Compress
$starUsers      = ($stars | ForEach-Object { $_.User })               | ConvertTo-Json -Compress

$refLabels  = ($referrers | ForEach-Object { $_.Referrer })           | ConvertTo-Json -Compress
$refViews   = ($referrers | ForEach-Object { [int]$_.TotalViews })    | ConvertTo-Json -Compress
$refUniques = ($referrers | ForEach-Object { [int]$_.UniqueVisitors }) | ConvertTo-Json -Compress

$pathLabels = ($paths | ForEach-Object { $_.Path -replace '^/ZacharyLuz/Get-AzVMAvailability', '' -replace '^$', '/' }) | ConvertTo-Json -Compress
$pathViews  = ($paths | ForEach-Object { [int]$_.TotalViews }) | ConvertTo-Json -Compress

# All-time totals
$totalViewsAllTime  = ($views  | ForEach-Object { [int]$_.TotalViews }  | Measure-Object -Sum).Sum
$uniqueViewsAllTime = ($views  | ForEach-Object { [int]$_.UniqueViews } | Measure-Object -Sum).Sum
$totalClonesAllTime = ($clones | ForEach-Object { [int]$_.TotalClones } | Measure-Object -Sum).Sum
$uniqueClonesAllTime= ($clones | ForEach-Object { [int]$_.UniqueClones }| Measure-Object -Sum).Sum
$totalStars     = if ($stars.Count -gt 0) { ($stars[-1]).CumulativeStars } else { 0 }
$latestStats    = if ($repoStats.Count -gt 0) { $repoStats[-1] } else { $null }
$latestReleaseDownloads = if (@($releaseDownloads).Count -gt 0) { @($releaseDownloads)[-1] } else { $null }
$generatedAt    = (Get-Date).ToString('MMM d, yyyy \a\t h:mm tt')
$dateRange      = if ($views.Count -gt 0) { "$($views[0].Date) — $($views[-1].Date)" } else { 'No data' }

#region Rolling Window Calculations
function Get-RollingDelta {
    param(
        [array]$Data,
        [string]$ValueProperty,
        [int]$WindowDays
    )
    if ($Data.Count -eq 0) { return @{ Current = 0; Prior = 0; Delta = 0; HasData = $false } }
    $sorted = $Data | Sort-Object Date
    $cutoff = ([datetime]$sorted[-1].Date).AddDays(-$WindowDays)
    $priorCutoff = $cutoff.AddDays(-$WindowDays)

    $current = ($sorted | Where-Object { [datetime]$_.Date -gt $cutoff } |
        ForEach-Object { [int]$_.$ValueProperty } | Measure-Object -Sum).Sum
    $prior = ($sorted | Where-Object { [datetime]$_.Date -gt $priorCutoff -and [datetime]$_.Date -le $cutoff } |
        ForEach-Object { [int]$_.$ValueProperty } | Measure-Object -Sum).Sum

    $delta = if ($prior -gt 0) { [math]::Round(($current - $prior) / $prior * 100) } else { 0 }
    return @{ Current = $current; Prior = $prior; Delta = $delta; HasData = ($prior -gt 0) }
}

# Week-over-week (7d vs prior 7d)
$viewsWoW  = Get-RollingDelta -Data $views  -ValueProperty 'TotalViews'  -WindowDays 7
$clonesWoW = Get-RollingDelta -Data $clones -ValueProperty 'TotalClones' -WindowDays 7

# Unique counts for current 7d window
$uniqueViewsWoW  = if ($views.Count -ge 7) {
    $cutoff = ([datetime]($views | Sort-Object Date | Select-Object -Last 1).Date).AddDays(-7)
    ($views | Where-Object { [datetime]$_.Date -gt $cutoff } | ForEach-Object { [int]$_.UniqueViews } | Measure-Object -Sum).Sum
} else { $uniqueViewsAllTime }
$uniqueClonesWoW = if ($clones.Count -ge 7) {
    $cutoff = ([datetime]($clones | Sort-Object Date | Select-Object -Last 1).Date).AddDays(-7)
    ($clones | Where-Object { [datetime]$_.Date -gt $cutoff } | ForEach-Object { [int]$_.UniqueClones } | Measure-Object -Sum).Sum
} else { $uniqueClonesAllTime }

# Use WoW delta as the primary badge
$viewDelta  = $viewsWoW.Delta
$cloneDelta = $clonesWoW.Delta
#endregion
#endregion

#region Generate HTML
$html = @'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Traffic — Get-AzVMAvailability</title>
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.7/dist/chart.umd.min.js"></script>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Inter:wght@400;500;600;700&display=swap" rel="stylesheet">
<style>
  :root {
    --bg: #050507;
    --surface: rgba(255,255,255,0.03);
    --surface-raised: rgba(255,255,255,0.05);
    --border: rgba(255,255,255,0.06);
    --text-1: #ededed;
    --text-2: #888;
    --text-3: #555;
    --blue: #3b82f6;
    --green: #22c55e;
    --purple: #a855f7;
    --amber: #f59e0b;
    --rose: #f43f5e;
    --cyan: #06b6d4;
    --r: 14px;
  }
  *, *::before, *::after { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: 'Inter', -apple-system, BlinkMacSystemFont, system-ui, sans-serif;
    background: var(--bg);
    color: var(--text-1);
    -webkit-font-smoothing: antialiased;
    line-height: 1.5;
  }

  /* Background atmosphere */
  .bg-glow {
    position: fixed; inset: 0; z-index: 0; pointer-events: none; overflow: hidden;
  }
  .bg-glow::before {
    content: '';
    position: absolute;
    top: -20%; left: 10%;
    width: 600px; height: 600px;
    background: radial-gradient(circle, rgba(59,130,246,0.07) 0%, transparent 70%);
    filter: blur(60px);
    animation: float1 30s ease-in-out infinite;
  }
  .bg-glow::after {
    content: '';
    position: absolute;
    bottom: -10%; right: 5%;
    width: 500px; height: 500px;
    background: radial-gradient(circle, rgba(168,85,247,0.05) 0%, transparent 70%);
    filter: blur(60px);
    animation: float2 25s ease-in-out infinite;
  }
  @keyframes float1 { 0%,100% { transform: translate(0,0); } 50% { transform: translate(80px,50px); } }
  @keyframes float2 { 0%,100% { transform: translate(0,0); } 50% { transform: translate(-60px,-40px); } }

  .page {
    position: relative; z-index: 1;
    max-width: 1400px; margin: 0 auto; padding: 0 32px 48px;
  }

  /* Header */
  header { padding: 48px 0 32px; }
  header .tag {
    display: inline-block;
    font-size: 12px; font-weight: 600;
    letter-spacing: 1px; text-transform: uppercase;
    color: var(--blue);
    background: rgba(59,130,246,0.1);
    padding: 4px 12px; border-radius: 5px;
    margin-bottom: 14px;
  }
  header h1 {
    font-size: 36px; font-weight: 700;
    color: var(--text-1);
    letter-spacing: -0.03em;
  }
  header p {
    font-size: 14px; color: var(--text-3);
    margin-top: 6px;
  }

  /* Metric row */
  .metrics {
    display: grid;
    grid-template-columns: repeat(7, 1fr);
    gap: 1px;
    background: var(--border);
    border-radius: var(--r);
    overflow: hidden;
    margin-bottom: 24px;
  }
  @media (max-width: 900px) { .metrics { grid-template-columns: repeat(4, 1fr); } }
  @media (max-width: 560px) { .metrics { grid-template-columns: repeat(2, 1fr); } }

  .metric {
    background: var(--bg);
    padding: 22px 24px;
    transition: background 0.2s;
  }
  .metric:hover { background: var(--surface-raised); }
  .metric .m-label {
    font-size: 12px; font-weight: 500;
    color: var(--text-3);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin-bottom: 8px;
  }
  .metric .m-value {
    font-size: 32px; font-weight: 700;
    color: var(--text-1);
    letter-spacing: -0.03em;
    line-height: 1;
  }
  .metric .m-sub {
    font-size: 12px; color: var(--text-3);
    margin-top: 5px;
  }
  .metric .m-delta {
    display: inline-flex; align-items: center;
    font-size: 12px; font-weight: 600;
    padding: 2px 8px; border-radius: 4px;
    margin-top: 8px;
  }
  .m-delta.up { background: rgba(34,197,94,0.1); color: #4ade80; }
  .m-delta.down { background: rgba(244,63,94,0.1); color: #fb7185; }
  .m-delta.flat { background: rgba(136,136,136,0.1); color: var(--text-3); }

  /* Chart cards — full-width with header row */
  .chart-card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--r);
    padding: 28px 32px;
    margin-bottom: 16px;
  }
  .chart-header {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    margin-bottom: 20px;
  }
  .chart-header .ch-left h3 {
    font-size: 16px; font-weight: 700;
    color: var(--text-1);
    margin: 0;
  }
  .chart-header .ch-left .ch-sub {
    font-size: 13px; color: var(--text-3);
    margin-top: 2px;
  }
  .chart-header .ch-right {
    text-align: right;
  }
  .chart-header .ch-right .ch-stat-label {
    font-size: 11px; font-weight: 500;
    color: var(--text-3);
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
  .chart-header .ch-right .ch-stat-value {
    font-size: 28px; font-weight: 700;
    color: var(--text-1);
    letter-spacing: -0.03em;
    line-height: 1.1;
  }
  .chart-card canvas { width: 100% !important; max-height: 300px; }

  /* Star timeline — horizontal flow */
  .stars-section {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--r);
    padding: 24px;
    margin-bottom: 24px;
  }
  .stars-section h3 {
    font-size: 15px; font-weight: 600;
    color: var(--text-2);
    margin-bottom: 14px;
  }
  .stars-flow {
    display: flex; flex-wrap: wrap; gap: 8px;
  }
  .star-pill {
    display: inline-flex; align-items: center; gap: 8px;
    padding: 7px 16px;
    background: rgba(245,158,11,0.06);
    border: 1px solid rgba(245,158,11,0.12);
    border-radius: 6px;
    font-size: 14px;
    transition: background 0.15s, transform 0.15s;
    cursor: default;
  }
  .star-pill:hover {
    background: rgba(245,158,11,0.12);
    transform: translateY(-1px);
  }
  .star-pill .s-name { color: var(--amber); font-weight: 600; }
  .star-pill .s-date { color: var(--text-3); }

  /* Footer */
  footer {
    text-align: center; padding: 32px 0;
    font-size: 12px; color: var(--text-3);
  }
  footer a { color: var(--text-2); text-decoration: none; }
  footer a:hover { color: var(--text-1); }

  /* Toolbar with time range picker */
  .toolbar {
    display: flex; justify-content: flex-end; align-items: center;
    margin-bottom: 20px; gap: 10px;
    position: relative;
    z-index: 50;
  }
  .toolbar .tb-label {
    font-size: 12px; color: var(--text-3);
  }
  .range-picker {
    position: relative;
    display: inline-block;
  }
  .range-btn {
    display: inline-flex; align-items: center; gap: 6px;
    padding: 7px 14px;
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 8px;
    color: var(--text-1);
    font-size: 13px; font-weight: 500;
    font-family: inherit;
    cursor: pointer;
    transition: background 0.15s, border-color 0.15s;
  }
  .range-btn:hover { background: var(--surface-raised); border-color: rgba(255,255,255,0.12); }
  .range-btn .cal-icon { font-size: 14px; }
  .range-btn .arrow { font-size: 10px; color: var(--text-3); }
  .range-menu {
    display: none;
    position: absolute; top: calc(100% + 4px); right: 0;
    background: #1a1a1e;
    border: 1px solid rgba(255,255,255,0.1);
    border-radius: 10px;
    padding: 4px;
    min-width: 170px;
    z-index: 100;
    box-shadow: 0 8px 30px rgba(0,0,0,0.5);
  }
  .range-menu.open { display: block; }
  .range-opt {
    display: flex; justify-content: space-between; align-items: center;
    padding: 8px 12px;
    border-radius: 6px;
    font-size: 13px;
    color: var(--text-2);
    cursor: pointer;
    transition: background 0.12s;
  }
  .range-opt:hover { background: rgba(255,255,255,0.06); color: var(--text-1); }
  .range-opt.active { color: var(--text-1); }
  .range-opt .check { font-size: 14px; color: var(--blue); visibility: hidden; }
  .range-opt.active .check { visibility: visible; }

  /* Weekly trend table */
  .trend-table-card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--r);
    padding: 28px 32px;
    margin-bottom: 16px;
  }
  .trend-table-card h3 {
    font-size: 16px; font-weight: 700;
    color: var(--text-1);
    margin: 0 0 4px;
  }
  .trend-table-card .tt-sub {
    font-size: 13px; color: var(--text-3);
    margin-bottom: 16px;
  }
  .trend-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
    font-variant-numeric: tabular-nums;
  }
  .trend-table th {
    text-align: left;
    font-size: 11px; font-weight: 600;
    color: var(--text-3);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    padding: 8px 12px;
    border-bottom: 1px solid var(--border);
  }
  .trend-table td {
    padding: 10px 12px;
    border-bottom: 1px solid var(--border);
    color: var(--text-2);
  }
  .trend-table tr:last-child td { border-bottom: none; }
  .trend-table tr:hover td { background: var(--surface-raised); }
  .trend-table .td-up { color: #4ade80; }
  .trend-table .td-down { color: #fb7185; }
  .trend-table .td-flat { color: var(--text-3); }
  .trend-table .td-value { color: var(--text-1); font-weight: 600; }

  /* Insights row */
  .insights {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 12px;
    margin-bottom: 16px;
  }
  @media (max-width: 900px) { .insights { grid-template-columns: repeat(2, 1fr); } }
  @media (max-width: 560px) { .insights { grid-template-columns: 1fr; } }
  .insight-card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: var(--r);
    padding: 20px 24px;
    transition: background 0.2s;
  }
  .insight-card:hover { background: var(--surface-raised); }
  .insight-card .ic-label {
    font-size: 11px; font-weight: 600;
    color: var(--text-3);
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin-bottom: 6px;
  }
  .insight-card .ic-value {
    font-size: 24px; font-weight: 700;
    color: var(--text-1);
    letter-spacing: -0.02em;
    line-height: 1;
  }
  .insight-card .ic-sub {
    font-size: 12px; color: var(--text-3);
    margin-top: 4px;
  }

  /* Entrance animation */
  @keyframes enter { from { opacity: 0; transform: translateY(8px); } to { opacity: 1; transform: translateY(0); } }
  .reveal { animation: enter 0.4s ease both; }
  .d1 { animation-delay: .04s } .d2 { animation-delay: .08s } .d3 { animation-delay: .12s }
  .d4 { animation-delay: .16s } .d5 { animation-delay: .2s } .d6 { animation-delay: .24s }
</style>
</head>
<body>
<div class="bg-glow"></div>
<div class="page">

'@

# Header
$html += @"
  <header class="reveal">
    <div class="tag">Repository Analytics</div>
    <h1>Get-AzVMAvailability</h1>
    <p>$generatedAt &middot; $dateRange</p>
  </header>
"@

# Metrics — single unified bar with 6 cells, no orphans
$viewDeltaClass = if ($viewDelta -gt 0) { 'up' } elseif ($viewDelta -lt 0) { 'down' } else { 'flat' }
$viewDeltaArrow = if ($viewDelta -gt 0) { '&#8593;' } elseif ($viewDelta -lt 0) { '&#8595;' } else { '&#8594;' }
$cloneDeltaClass = if ($cloneDelta -gt 0) { 'up' } elseif ($cloneDelta -lt 0) { 'down' } else { 'flat' }
$cloneDeltaArrow = if ($cloneDelta -gt 0) { '&#8593;' } elseif ($cloneDelta -lt 0) { '&#8595;' } else { '&#8594;' }

$html += @"
  <div class="metrics reveal d1">
    <div class="metric">
      <div class="m-label" id="hdr-views-label">Views (All Time)</div>
      <div class="m-value" id="hdr-views-value">$totalViewsAllTime</div>
      <div class="m-sub" id="hdr-views-sub">$uniqueViewsAllTime unique</div>
      <div class="m-delta $viewDeltaClass" id="hdr-views-delta">$viewDeltaArrow ${viewDelta}% WoW</div>
    </div>
    <div class="metric">
      <div class="m-label" id="hdr-clones-label">Clones (All Time)</div>
      <div class="m-value" id="hdr-clones-value">$totalClonesAllTime</div>
      <div class="m-sub" id="hdr-clones-sub">$uniqueClonesAllTime unique</div>
      <div class="m-delta $cloneDeltaClass" id="hdr-clones-delta">$cloneDeltaArrow ${cloneDelta}% WoW</div>
    </div>
    <div class="metric">
      <div class="m-label">Stars</div>
      <div class="m-value">$totalStars</div>
      <div class="m-sub">$(if($stars.Count -gt 0) { "by $($stars[-1].User)" } else { '—' })</div>
    </div>
    <div class="metric">
      <div class="m-label">Forks</div>
      <div class="m-value">$(if($latestStats) { $latestStats.Forks } else { '0' })</div>
      <div class="m-sub">$(if($latestStats) { "$($latestStats.Watchers) watching" } else { '—' })</div>
    </div>
    <div class="metric">
      <div class="m-label">Release Downloads</div>
      <div class="m-value">$(if($latestReleaseDownloads) { $latestReleaseDownloads.TotalReleaseDownloads } else { '0' })</div>
      <div class="m-sub">$(if($latestReleaseDownloads) { "$($latestReleaseDownloads.AssetCount) assets / $($latestReleaseDownloads.ReleaseCount) releases" } else { '0 assets / 0 releases' })</div>
    </div>
    <div class="metric">
      <div class="m-label">Top Source</div>
      <div class="m-value" style="font-size:20px;margin-top:2px">$(if($referrers.Count -gt 0) { $referrers[0].Referrer } else { '—' })</div>
      <div class="m-sub">$(if($referrers.Count -gt 0) { "$($referrers[0].TotalViews) views" } else { '' })</div>
    </div>
    <div class="metric">
      <div class="m-label">Sources</div>
      <div class="m-value">$($referrers.Count)</div>
      <div class="m-sub">referrers</div>
    </div>
  </div>
"@

# Insights row — computed metrics
$html += @'
  <div class="insights reveal d1">
    <div class="insight-card">
      <div class="ic-label">View → Clone Rate</div>
      <div class="ic-value" id="ins-clone-rate">—</div>
      <div class="ic-sub" id="ins-clone-rate-sub">of visitors clone the repo</div>
    </div>
    <div class="insight-card">
      <div class="ic-label">Avg Daily Views</div>
      <div class="ic-value" id="ins-avg-views">—</div>
      <div class="ic-sub" id="ins-avg-views-sub">over selected window</div>
    </div>
    <div class="insight-card">
      <div class="ic-label">Peak Day</div>
      <div class="ic-value" id="ins-peak-day">—</div>
      <div class="ic-sub" id="ins-peak-sub">highest single-day views</div>
    </div>
    <div class="insight-card">
      <div class="ic-label">Days Since Last Star</div>
      <div class="ic-value" id="ins-star-gap">—</div>
      <div class="ic-sub" id="ins-star-gap-sub">—</div>
    </div>
  </div>
'@

# Weekly trend table
$html += @'
  <div class="trend-table-card reveal d2" id="trend-table-section">
    <h3>Weekly Trends</h3>
    <div class="tt-sub">Week-over-week totals with % change</div>
    <table class="trend-table">
      <thead>
        <tr>
          <th>Week</th>
          <th>Views</th>
          <th>WoW</th>
          <th>Clones</th>
          <th>WoW</th>
          <th>Clone Rate</th>
        </tr>
      </thead>
      <tbody id="trend-table-body"></tbody>
    </table>
  </div>
'@

# Charts — full-width cards with title/subtitle + summary stat
$html += @'
  <div class="toolbar reveal d2">
    <div class="range-picker">
      <button class="range-btn" onclick="toggleMenu()">
        <span class="cal-icon">&#x1F4C5;</span>
        <span id="rangeLabel">All Time</span>
        <span class="arrow">&#x25BC;</span>
      </button>
      <div class="range-menu" id="rangeMenu">
        <div class="range-opt" data-days="7" onclick="setRange(7, this)">Last 7 Days <span class="check">&#x2713;</span></div>
        <div class="range-opt" data-days="14" onclick="setRange(14, this)">Last 14 Days <span class="check">&#x2713;</span></div>
        <div class="range-opt" data-days="28" onclick="setRange(28, this)">Last 28 Days <span class="check">&#x2713;</span></div>
        <div class="range-opt" data-days="91" onclick="setRange(91, this)">Last 91 Days <span class="check">&#x2713;</span></div>
        <div class="range-opt active" data-days="0" onclick="setRange(0, this)">All Time <span class="check">&#x2713;</span></div>
      </div>
    </div>
  </div>
'@

$html += @"
  <div class="chart-card reveal d2">
    <div class="chart-header">
      <div class="ch-left"><h3>Page Views</h3><div class="ch-sub">Daily views and unique visitors</div></div>
      <div class="ch-right"><div class="ch-stat-label">Total Views</div><div class="ch-stat-value" id="viewsStat">$totalViewsAllTime</div></div>
    </div>
    <canvas id="viewsChart"></canvas>
  </div>
  <div class="chart-card reveal d3">
    <div class="chart-header">
      <div class="ch-left"><h3>Git Clones</h3><div class="ch-sub">Daily clones and unique cloners</div></div>
      <div class="ch-right"><div class="ch-stat-label">Total Clones</div><div class="ch-stat-value" id="clonesStat">$totalClonesAllTime</div></div>
    </div>
    <canvas id="clonesChart"></canvas>
  </div>
  <div class="chart-card reveal d3">
    <div class="chart-header">
      <div class="ch-left"><h3>Stars Over Time</h3><div class="ch-sub">Cumulative star growth</div></div>
      <div class="ch-right"><div class="ch-stat-label">Total Stars</div><div class="ch-stat-value" id="starsStat">$totalStars</div></div>
    </div>
    <canvas id="starsChart"></canvas>
  </div>
  <div class="chart-card reveal d4">
    <div class="chart-header">
      <div class="ch-left"><h3>Top Referrers</h3><div class="ch-sub">Traffic sources over last 14 days</div></div>
      <div class="ch-right"><div class="ch-stat-label">Sources</div><div class="ch-stat-value">$($referrers.Count)</div></div>
    </div>
    <canvas id="referrersChart"></canvas>
  </div>
  <div class="chart-card reveal d5">
    <div class="chart-header">
      <div class="ch-left"><h3>Popular Content</h3><div class="ch-sub">Most visited pages</div></div>
      <div class="ch-right"><div class="ch-stat-label">Pages Tracked</div><div class="ch-stat-value">$($paths.Count)</div></div>
    </div>
    <canvas id="pathsChart"></canvas>
  </div>
"@

# Star timeline
$html += "  <div class=`"stars-section reveal d4`">`n    <h3>&#x2B50; Star Timeline</h3>`n    <div class=`"stars-flow`">`n"
foreach ($s in $stars) {
    $html += "      <div class=`"star-pill`"><span class=`"s-name`">$($s.User)</span><span class=`"s-date`">$($s.Date)</span></div>`n"
}
$html += "    </div>`n  </div>`n"

# Footer
$html += @'
  <footer class="reveal d5">
    Built with <a href="https://github.com/ZacharyLuz/Get-AzVMAvailability">Get-AzVMAvailability</a> &mdash; Collect-TrafficData.ps1 &plus; Generate-TrafficDashboard-Premium-v2.ps1
  </footer>
</div>
'@

# Chart.js
$html += @"
<script>
// ── All raw data (for time filtering) ──
const allData = {
  views:  { dates: $viewDates, total: $viewTotals, unique: $viewUniques },
  clones: { dates: $cloneDates, total: $cloneTotals, unique: $cloneUniques },
  stars:  { dates: $starDates, cumulative: $starCumulative, users: $starUsers }
};

// ── Custom tooltip (dark card with colored dots) ──
const tooltipPlugin = {
  enabled: false,
  external: function(context) {
    let el = document.getElementById('chartjs-tooltip');
    if (!el) {
      el = document.createElement('div');
      el.id = 'chartjs-tooltip';
      el.style.cssText = 'position:absolute;pointer-events:none;background:#1a1a1e;border:1px solid rgba(255,255,255,0.12);border-radius:10px;padding:10px 14px;font-family:Inter,system-ui,sans-serif;font-size:12px;color:#ededed;z-index:200;box-shadow:0 8px 24px rgba(0,0,0,0.6);transition:opacity 0.15s ease;min-width:140px';
      document.body.appendChild(el);
    }
    const tooltip = context.tooltip;
    if (tooltip.opacity === 0) { el.style.opacity = '0'; return; }

    let html = '<div style="font-weight:600;margin-bottom:6px;color:#aaa">' + tooltip.title[0] + '</div>';
    tooltip.body.forEach((item, i) => {
      const colors = tooltip.labelColors[i];
      const dot = '<span style="display:inline-block;width:8px;height:8px;border-radius:50%;background:' + colors.borderColor + ';margin-right:8px"></span>';
      const parts = item.lines[0].split(': ');
      const label = parts[0];
      const value = parts[1] || parts[0];
      html += '<div style="display:flex;justify-content:space-between;align-items:center;gap:16px;padding:2px 0">'
        + '<span>' + dot + label + '</span>'
        + '<span style="font-weight:700;font-variant-numeric:tabular-nums">' + (parts.length > 1 ? value : '') + '</span>'
        + '</div>';
    });
    el.innerHTML = html;
    el.style.opacity = '1';
    const pos = context.chart.canvas.getBoundingClientRect();
    el.style.left = pos.left + window.scrollX + tooltip.caretX + 'px';
    el.style.top = pos.top + window.scrollY + tooltip.caretY - 10 + 'px';
    // Keep tooltip within viewport
    const rect = el.getBoundingClientRect();
    if (rect.right > window.innerWidth - 10) {
      el.style.left = (pos.left + window.scrollX + tooltip.caretX - rect.width - 12) + 'px';
    }
  }
};

Chart.defaults.color = '#555';
Chart.defaults.font.family = 'Inter, system-ui, sans-serif';
Chart.defaults.font.size = 12;
Chart.defaults.elements.point.radius = 0;
Chart.defaults.elements.point.hoverRadius = 5;
Chart.defaults.elements.line.borderWidth = 2;

const gY = { grid: { color: 'rgba(255,255,255,0.04)', drawBorder: false }, beginAtZero: true };
const gX = { grid: { display: false } };

function grad(ctx, r,g,b, h) {
  const gr = ctx.createLinearGradient(0, 0, 0, h || 240);
  gr.addColorStop(0, 'rgba('+r+','+g+','+b+',0.18)');
  gr.addColorStop(1, 'rgba('+r+','+g+','+b+',0)');
  return gr;
}

const legendOpts = { position: 'bottom', align: 'center', labels: { usePointStyle: true, pointStyle: 'circle', boxWidth: 6, padding: 16, font: { size: 12 } } };
const lineOpts = (legend) => ({
  responsive: true,
  interaction: { intersect: false, mode: 'index' },
  plugins: { legend: legend ? legendOpts : { display: false }, tooltip: tooltipPlugin },
  scales: { y: gY, x: gX }
});

// ── Chart instances (stored for time range updates) ──
let viewsChart, clonesChart, starsChart;

function buildCharts(days) {
  function filterByDays(dates, ...arrays) {
    if (!days || days === 0) return { dates, arrays };
    if (!dates.length) return { dates: [], arrays: arrays.map(() => []) };
    // Anchor cutoff to last available data date (not today) so historical snapshots work.
    const anchor = new Date(dates[dates.length - 1] + 'T12:00:00');
    const t = new Date(anchor);
    t.setDate(t.getDate() - days);
    const cutoff = t.getFullYear() + '-' +
      String(t.getMonth() + 1).padStart(2, '0') + '-' +
      String(t.getDate()).padStart(2, '0');
    const filtered = { dates: [], arrays: arrays.map(() => []) };
    dates.forEach((d, i) => {
      if (d >= cutoff) {
        filtered.dates.push(d);
        arrays.forEach((arr, j) => filtered.arrays[j].push(arr[i]));
      }
    });
    return filtered;
  }

  // Destroy existing charts
  [viewsChart, clonesChart, starsChart].forEach(ch => { if (ch) ch.destroy(); });

  // Views
  const v = filterByDays(allData.views.dates, allData.views.total, allData.views.unique);
  const vc = document.getElementById('viewsChart').getContext('2d');
  viewsChart = new Chart(vc, {
    type: 'line',
    data: {
      labels: v.dates,
      datasets: [
        { label: 'Total', data: v.arrays[0], borderColor: '#3b82f6', backgroundColor: grad(vc,59,130,246), fill: true, tension: 0.4 },
        { label: 'Unique', data: v.arrays[1], borderColor: '#22c55e', backgroundColor: grad(vc,34,197,94), fill: true, tension: 0.4 }
      ]
    },
    options: lineOpts(true)
  });
  // Update summary stat
  const viewsSum = v.arrays[0].reduce((a,b) => a+b, 0);
  document.getElementById('viewsStat').textContent = viewsSum.toLocaleString();

  // Clones
  const cl = filterByDays(allData.clones.dates, allData.clones.total, allData.clones.unique);
  const cc = document.getElementById('clonesChart').getContext('2d');
  clonesChart = new Chart(cc, {
    type: 'line',
    data: {
      labels: cl.dates,
      datasets: [
        { label: 'Total', data: cl.arrays[0], borderColor: '#a855f7', backgroundColor: grad(cc,168,85,247), fill: true, tension: 0.4 },
        { label: 'Unique', data: cl.arrays[1], borderColor: '#f43f5e', backgroundColor: grad(cc,244,63,94), fill: true, tension: 0.4 }
      ]
    },
    options: lineOpts(true)
  });
  const clonesSum = cl.arrays[0].reduce((a,b) => a+b, 0);
  document.getElementById('clonesStat').textContent = clonesSum.toLocaleString();

  // Stars
  const st = filterByDays(allData.stars.dates, allData.stars.cumulative);
  const sc = document.getElementById('starsChart').getContext('2d');
  const filteredUsers = allData.stars.users.slice(allData.stars.dates.length - st.dates.length);
  starsChart = new Chart(sc, {
    type: 'line',
    data: {
      labels: st.dates,
      datasets: [{
        data: st.arrays[0],
        borderColor: '#f59e0b',
        backgroundColor: grad(sc,245,158,11),
        fill: true, tension: 0.4,
        pointRadius: 4, pointBackgroundColor: '#f59e0b', pointBorderColor: '#050507', pointBorderWidth: 2
      }]
    },
    options: {
      ...lineOpts(false),
      plugins: {
        legend: { display: false },
        tooltip: {
          ...tooltipPlugin,
          external: function(context) {
            let el = document.getElementById('chartjs-tooltip');
            if (!el) {
              el = document.createElement('div');
              el.id = 'chartjs-tooltip';
              el.style.cssText = 'position:absolute;pointer-events:none;background:#1a1a1e;border:1px solid rgba(255,255,255,0.12);border-radius:10px;padding:10px 14px;font-family:Inter,system-ui,sans-serif;font-size:12px;color:#ededed;z-index:200;box-shadow:0 8px 24px rgba(0,0,0,0.6);transition:opacity 0.15s ease';
              document.body.appendChild(el);
            }
            const tt = context.tooltip;
            if (tt.opacity === 0) { el.style.opacity = '0'; return; }
            const idx = tt.dataPoints?.[0]?.dataIndex;
            const user = filteredUsers[idx] || '';
            el.innerHTML = '<div style="font-weight:600;margin-bottom:4px;color:#aaa">' + tt.title[0] + '</div>'
              + '<div style="display:flex;justify-content:space-between;gap:16px"><span><span style="display:inline-block;width:8px;height:8px;border-radius:50%;background:#f59e0b;margin-right:8px"></span>Star #' + tt.dataPoints[0].raw + '</span><span style="font-weight:700">' + user + '</span></div>';
            el.style.opacity = '1';
            const pos = context.chart.canvas.getBoundingClientRect();
            el.style.left = pos.left + window.scrollX + tt.caretX + 'px';
            el.style.top = pos.top + window.scrollY + tt.caretY - 10 + 'px';
          }
        }
      }
    }
  });
  if (st.arrays[0].length > 0) {
    document.getElementById('starsStat').textContent = st.arrays[0][st.arrays[0].length - 1];
  }
}

// ── Update header metrics + insights for selected time range ──
function updateMetrics(days) {
  const rangeLabel = days === 0 ? 'All Time' : days + 'd';

  // Helper: filter data by days and return { dates, values, uniques }
  // Anchors to last data date so historical snapshots work correctly.
  function windowData(src, valKey, uniqKey, windowDays) {
    if (!windowDays || windowDays === 0) {
      return { dates: src.dates, values: src[valKey], uniques: src[uniqKey] };
    }
    if (!src.dates.length) return { dates: [], values: [], uniques: [] };
    const anchor = new Date(src.dates[src.dates.length - 1] + 'T12:00:00');
    const t = new Date(anchor); t.setDate(t.getDate() - windowDays);
    const cutoff = t.getFullYear() + '-' + String(t.getMonth()+1).padStart(2,'0') + '-' + String(t.getDate()).padStart(2,'0');
    const r = { dates: [], values: [], uniques: [] };
    src.dates.forEach((d, i) => {
      if (d >= cutoff) { r.dates.push(d); r.values.push(src[valKey][i]); r.uniques.push(src[uniqKey][i]); }
    });
    return r;
  }

  // Helper: compute rolling delta (current window vs prior window of same size)
  // Anchors to last data date; uses >= / < boundary to match windowData.
  function rollingDelta(src, valKey, windowDays) {
    if (!windowDays || windowDays === 0) return { current: 0, prior: 0, delta: 0, hasData: false };
    if (!src.dates.length) return { current: 0, prior: 0, delta: 0, hasData: false };
    const anchor = new Date(src.dates[src.dates.length - 1] + 'T12:00:00');
    const t = new Date(anchor); t.setDate(t.getDate() - windowDays);
    const cutoff = t.getFullYear() + '-' + String(t.getMonth()+1).padStart(2,'0') + '-' + String(t.getDate()).padStart(2,'0');
    const t2 = new Date(anchor); t2.setDate(t2.getDate() - windowDays * 2);
    const priorCutoff = t2.getFullYear() + '-' + String(t2.getMonth()+1).padStart(2,'0') + '-' + String(t2.getDate()).padStart(2,'0');
    let current = 0, prior = 0;
    src.dates.forEach((d, i) => {
      if (d >= cutoff) current += src[valKey][i];
      else if (d >= priorCutoff && d < cutoff) prior += src[valKey][i];
    });
    const delta = prior > 0 ? Math.round((current - prior) / prior * 100) : 0;
    return { current, prior, delta, hasData: prior > 0 };
  }

  // Current window data
  const vw = windowData(allData.views, 'total', 'unique', days);
  const cw = windowData(allData.clones, 'total', 'unique', days);

  const viewsTotal = vw.values.reduce((a,b) => a+b, 0);
  const viewsUnique = vw.uniques.reduce((a,b) => a+b, 0);
  const clonesTotal = cw.values.reduce((a,b) => a+b, 0);
  const clonesUnique = cw.uniques.reduce((a,b) => a+b, 0);

  const allTimeViews = allData.views.total.reduce((a,b) => a+b, 0);
  const allTimeClones = allData.clones.total.reduce((a,b) => a+b, 0);

  // Delta: compare selected window vs prior window of same size
  // For "All Time" use 7d WoW as the comparison
  const compareWindow = days === 0 ? 7 : days;
  const vDelta = rollingDelta(allData.views, 'total', compareWindow);
  const cDelta = rollingDelta(allData.clones, 'total', compareWindow);
  const compareLabel = days === 0 ? 'WoW' : 'vs prior';

  // Update header cards
  const vCls = vDelta.delta > 0 ? 'up' : vDelta.delta < 0 ? 'down' : 'flat';
  const vArrow = vDelta.delta > 0 ? '\u2191' : vDelta.delta < 0 ? '\u2193' : '\u2192';
  document.getElementById('hdr-views-label').textContent = 'Views (' + rangeLabel + ')';
  document.getElementById('hdr-views-value').textContent = viewsTotal.toLocaleString();
  document.getElementById('hdr-views-sub').innerHTML = viewsUnique.toLocaleString() + ' unique &middot; ' + allTimeViews.toLocaleString() + ' all-time';
  const vDeltaEl = document.getElementById('hdr-views-delta');
  vDeltaEl.className = 'm-delta ' + vCls;
  vDeltaEl.textContent = vArrow + ' ' + vDelta.delta + '% ' + compareLabel;

  const cCls = cDelta.delta > 0 ? 'up' : cDelta.delta < 0 ? 'down' : 'flat';
  const cArrow = cDelta.delta > 0 ? '\u2191' : cDelta.delta < 0 ? '\u2193' : '\u2192';
  document.getElementById('hdr-clones-label').textContent = 'Clones (' + rangeLabel + ')';
  document.getElementById('hdr-clones-value').textContent = clonesTotal.toLocaleString();
  document.getElementById('hdr-clones-sub').innerHTML = clonesUnique.toLocaleString() + ' unique &middot; ' + allTimeClones.toLocaleString() + ' all-time';
  const cDeltaEl = document.getElementById('hdr-clones-delta');
  cDeltaEl.className = 'm-delta ' + cCls;
  cDeltaEl.textContent = cArrow + ' ' + cDelta.delta + '% ' + compareLabel;

  // ── Insight cards ──
  // View → Clone rate
  const cloneRate = viewsTotal > 0 ? (clonesTotal / viewsTotal * 100).toFixed(1) : '0';
  document.getElementById('ins-clone-rate').textContent = cloneRate + '%';
  document.getElementById('ins-clone-rate-sub').textContent = clonesTotal.toLocaleString() + ' clones / ' + viewsTotal.toLocaleString() + ' views';

  // Avg daily views
  const numDays = vw.dates.length || 1;
  document.getElementById('ins-avg-views').textContent = Math.round(viewsTotal / numDays).toLocaleString();
  document.getElementById('ins-avg-views-sub').textContent = numDays + ' days in window';

  // Peak day
  let peakVal = 0, peakDate = '';
  vw.values.forEach((v, i) => { if (v > peakVal) { peakVal = v; peakDate = vw.dates[i]; } });
  document.getElementById('ins-peak-day').textContent = peakVal.toLocaleString();
  document.getElementById('ins-peak-sub').textContent = peakDate || '—';

  // Days since last star
  if (allData.stars.dates.length > 0) {
    const lastStar = allData.stars.dates[allData.stars.dates.length - 1];
    const lastStarLocal = new Date(lastStar + 'T12:00:00');
    const diff = Math.floor((new Date() - lastStarLocal) / 86400000);
    document.getElementById('ins-star-gap').textContent = diff;
    document.getElementById('ins-star-gap-sub').textContent = 'last: ' + allData.stars.users[allData.stars.users.length - 1] + ' on ' + lastStar;
  } else {
    document.getElementById('ins-star-gap').textContent = '—';
    document.getElementById('ins-star-gap-sub').textContent = 'no stars yet';
  }

  // ── Weekly trend table ──
  buildWeeklyTrend(vw, cw);
}

function buildWeeklyTrend(viewWindow, cloneWindow) {
  // Group data into ISO weeks (Mon–Sun)
  function toWeekKey(dateStr) {
    const d = new Date(dateStr + 'T12:00:00'); // noon to avoid timezone edge
    const day = d.getDay(); // 0=Sun
    const mon = new Date(d); mon.setDate(d.getDate() - ((day + 6) % 7)); // Monday
    return mon.getFullYear() + '-' + String(mon.getMonth()+1).padStart(2,'0') + '-' + String(mon.getDate()).padStart(2,'0');
  }

  // Merge view + clone dates into unified weekly buckets
  const weeks = {};
  viewWindow.dates.forEach((d, i) => {
    const wk = toWeekKey(d);
    if (!weeks[wk]) weeks[wk] = { views: 0, clones: 0 };
    weeks[wk].views += viewWindow.values[i];
  });
  cloneWindow.dates.forEach((d, i) => {
    const wk = toWeekKey(d);
    if (!weeks[wk]) weeks[wk] = { views: 0, clones: 0 };
    weeks[wk].clones += cloneWindow.values[i];
  });

  const sortedWeeks = Object.keys(weeks).sort();
  const tbody = document.getElementById('trend-table-body');
  let html = '';

  sortedWeeks.forEach((wk, idx) => {
    const w = weeks[wk];
    // End date (Sun) = Monday + 6
    const mon = new Date(wk + 'T12:00:00');
    const sun = new Date(mon); sun.setDate(mon.getDate() + 6);
    const wkLabel = (mon.getMonth()+1) + '/' + mon.getDate() + ' – ' + (sun.getMonth()+1) + '/' + sun.getDate();

    // WoW deltas
    let vDelta = '', cDelta = '';
    if (idx > 0) {
      const prev = weeks[sortedWeeks[idx - 1]];
      if (prev.views > 0) {
        const pct = Math.round((w.views - prev.views) / prev.views * 100);
        const cls = pct > 0 ? 'td-up' : pct < 0 ? 'td-down' : 'td-flat';
        vDelta = '<span class="' + cls + '">' + (pct > 0 ? '\u2191' : pct < 0 ? '\u2193' : '\u2192') + ' ' + pct + '%</span>';
      } else {
        vDelta = '<span class="td-flat">\u2014</span>';
      }
      if (prev.clones > 0) {
        const pct = Math.round((w.clones - prev.clones) / prev.clones * 100);
        const cls = pct > 0 ? 'td-up' : pct < 0 ? 'td-down' : 'td-flat';
        cDelta = '<span class="' + cls + '">' + (pct > 0 ? '\u2191' : pct < 0 ? '\u2193' : '\u2192') + ' ' + pct + '%</span>';
      } else {
        cDelta = '<span class="td-flat">\u2014</span>';
      }
    } else {
      vDelta = '<span class="td-flat">—</span>';
      cDelta = '<span class="td-flat">—</span>';
    }

    const rate = w.views > 0 ? (w.clones / w.views * 100).toFixed(1) + '%' : '—';
    html += '<tr><td>' + wkLabel + '</td><td class="td-value">' + w.views.toLocaleString() + '</td><td>' + vDelta + '</td><td class="td-value">' + w.clones.toLocaleString() + '</td><td>' + cDelta + '</td><td>' + rate + '</td></tr>';
  });

  tbody.innerHTML = html;
}

// Initial build
buildCharts(0);
updateMetrics(0);

// Referrers (not time-filtered — snapshot data)
new Chart(document.getElementById('referrersChart'), {
  type: 'bar',
  data: {
    labels: $refLabels,
    datasets: [
      { label: 'Views', data: $refViews, backgroundColor: 'rgba(59,130,246,0.5)', borderRadius: 4, borderSkipped: false },
      { label: 'Unique', data: $refUniques, backgroundColor: 'rgba(34,197,94,0.4)', borderRadius: 4, borderSkipped: false }
    ]
  },
  options: { responsive: true, indexAxis: 'y',
    plugins: { legend: legendOpts, tooltip: tooltipPlugin },
    scales: { x: { ...gY }, y: gX } }
});

// Paths (not time-filtered — snapshot data)
new Chart(document.getElementById('pathsChart'), {
  type: 'bar',
  data: {
    labels: $pathLabels,
    datasets: [{
      label: 'Views', data: $pathViews,
      backgroundColor: ['rgba(59,130,246,0.45)','rgba(168,85,247,0.45)','rgba(34,197,94,0.45)','rgba(244,63,94,0.45)','rgba(245,158,11,0.45)','rgba(6,182,212,0.45)','rgba(236,72,153,0.45)','rgba(132,204,22,0.45)','rgba(251,146,60,0.45)','rgba(99,102,241,0.45)'],
      borderRadius: 4, borderSkipped: false
    }]
  },
  options: { responsive: true, indexAxis: 'y',
    plugins: { legend: { display: false }, tooltip: tooltipPlugin },
    scales: { x: { ...gY }, y: gX } }
});

// ── Time range menu ──
function toggleMenu() {
  document.getElementById('rangeMenu').classList.toggle('open');
}
document.addEventListener('click', function(e) {
  if (!e.target.closest('.range-picker')) {
    document.getElementById('rangeMenu').classList.remove('open');
  }
});
function setRange(days, el) {
  document.querySelectorAll('.range-opt').forEach(o => o.classList.remove('active'));
  el.classList.add('active');
  document.getElementById('rangeLabel').textContent = el.textContent.replace('✓','').trim();
  document.getElementById('rangeMenu').classList.remove('open');
  buildCharts(days);
  updateMetrics(days);
}
</script>
</body>
</html>
"@
#endregion

#region Write and Open
$html | Out-File -FilePath $OutputFile -Encoding UTF8
Write-Host "`nDashboard generated: $OutputFile" -ForegroundColor Green
if ($env:CI -ne 'true' -and $PSVersionTable.Platform -ne 'Unix') {
  Write-Host "Opening in browser..." -ForegroundColor Gray
  Start-Process $OutputFile
} else {
  Write-Host "Skipping browser launch in CI/non-Windows environment." -ForegroundColor Gray
}
#endregion
