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
$releasesPath = Join-Path $InputDir 'releases.csv'
$psGalleryPath = Join-Path $InputDir 'psgallery-downloads.csv'

$views     = @(if (Test-Path $viewsPath)     { Import-Csv $viewsPath     | Sort-Object Date })
$clones    = @(if (Test-Path $clonesPath)    { Import-Csv $clonesPath    | Sort-Object Date })
$stars     = @(if (Test-Path $starsPath)     { Import-Csv $starsPath     | Sort-Object Date })
$repoStats = @(if (Test-Path $repoStatsPath) { Import-Csv $repoStatsPath | Sort-Object Date })
$releaseDownloads = @(if (Test-Path $releaseDownloadsPath) { Import-Csv $releaseDownloadsPath | Sort-Object Date })

# Individual release tags with publish dates (for chart annotations)
$releases = @(if (Test-Path $releasesPath) { Import-Csv $releasesPath | Sort-Object PublishedDate })

# PSGallery: one row per date (prefer IsLatestVersion=true)
$psGalleryRaw = @(if (Test-Path $psGalleryPath) { Import-Csv $psGalleryPath | Sort-Object Date })
$psGallery = @()
if ($psGalleryRaw.Count -gt 0) {
    $grouped = $psGalleryRaw | Group-Object Date
    foreach ($g in ($grouped | Sort-Object Name)) {
        $latest = $g.Group | Where-Object { $_.IsLatestVersion -eq 'true' } | Select-Object -First 1
        if (-not $latest) { $latest = $g.Group | Select-Object -First 1 }
        $psGallery += $latest
    }
}

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

Write-Host "Loaded: $($views.Count) view days, $($clones.Count) clone days, $($stars.Count) stars, $($referrers.Count) referrers, $($paths.Count) paths, $(@($releaseDownloads).Count) release download snapshots, $($releases.Count) releases, $($psGallery.Count) PSGallery snapshots" -ForegroundColor Cyan
#endregion

#region Build JSON — use @() to guarantee arrays for ConvertTo-Json
$viewDates    = @($views  | ForEach-Object { $_.Date })            | ConvertTo-Json -Compress -AsArray
$viewTotals   = @($views  | ForEach-Object { [int]$_.TotalViews }) | ConvertTo-Json -Compress -AsArray
$viewUniques  = @($views  | ForEach-Object { [int]$_.UniqueViews })| ConvertTo-Json -Compress -AsArray

$cloneDates   = @($clones | ForEach-Object { $_.Date })             | ConvertTo-Json -Compress -AsArray
$cloneTotals  = @($clones | ForEach-Object { [int]$_.TotalClones }) | ConvertTo-Json -Compress -AsArray
$cloneUniques = @($clones | ForEach-Object { [int]$_.UniqueClones })| ConvertTo-Json -Compress -AsArray

$starDates      = @($stars | ForEach-Object { $_.Date })               | ConvertTo-Json -Compress -AsArray
$starCumulative = @($stars | ForEach-Object { [int]$_.CumulativeStars })| ConvertTo-Json -Compress -AsArray
$starUsers      = @($stars | ForEach-Object { $_.User })               | ConvertTo-Json -Compress -AsArray

$psGalleryDates   = @($psGallery | ForEach-Object { $_.Date })                | ConvertTo-Json -Compress -AsArray
$psGalleryTotalDl = @($psGallery | ForEach-Object { [long]$_.TotalDownloads })| ConvertTo-Json -Compress -AsArray

# Build release annotations from actual GitHub release publish dates
$releaseAnnotations = @($releases | ForEach-Object {
    [PSCustomObject]@{
        date    = $_.PublishedDate
        version = $_.TagName
    }
})
$releasesJson = $releaseAnnotations | ConvertTo-Json -Compress -AsArray

$refLabels  = @($referrers | ForEach-Object { $_.Referrer })           | ConvertTo-Json -Compress -AsArray
$refViews   = @($referrers | ForEach-Object { [int]$_.TotalViews })    | ConvertTo-Json -Compress -AsArray
$refUniques = @($referrers | ForEach-Object { [int]$_.UniqueVisitors }) | ConvertTo-Json -Compress -AsArray

$pathLabels = @($paths | ForEach-Object { $_.Path -replace '^/ZacharyLuz/Get-AzVMAvailability', '' -replace '^$', '/' }) | ConvertTo-Json -Compress -AsArray
$pathViews  = @($paths | ForEach-Object { [int]$_.TotalViews }) | ConvertTo-Json -Compress -AsArray

# All-time totals (default to 0 when arrays are empty)
$totalViewsAllTime  = if ($views.Count -gt 0) { ($views  | ForEach-Object { [int]$_.TotalViews }  | Measure-Object -Sum).Sum } else { 0 }
$uniqueViewsAllTime = if ($views.Count -gt 0) { ($views  | ForEach-Object { [int]$_.UniqueViews } | Measure-Object -Sum).Sum } else { 0 }
$totalClonesAllTime = if ($clones.Count -gt 0) { ($clones | ForEach-Object { [int]$_.TotalClones } | Measure-Object -Sum).Sum } else { 0 }
$uniqueClonesAllTime= if ($clones.Count -gt 0) { ($clones | ForEach-Object { [int]$_.UniqueClones }| Measure-Object -Sum).Sum } else { 0 }
$totalStars     = if ($stars.Count -gt 0) { ($stars[-1]).CumulativeStars } else { 0 }
$latestStats    = if ($repoStats.Count -gt 0) { $repoStats[-1] } else { $null }
$latestReleaseDownloads = if (@($releaseDownloads).Count -gt 0) { @($releaseDownloads)[-1] } else { $null }
$latestPsGallery = if ($psGallery.Count -gt 0) { $psGallery[-1] } else { $null }
$psGalleryTotal = if ($latestPsGallery) { $latestPsGallery.TotalDownloads } else { '0' }
$psGalleryVersion = if ($latestPsGallery) { "v$($latestPsGallery.Version)" } else { [char]0x2014 }
$psGalleryVersionDlCount = if ($latestPsGallery) { $latestPsGallery.VersionDownloads } else { '0' }
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

    $current = ($sorted | Where-Object { [datetime]$_.Date -ge $cutoff } |
        ForEach-Object { [int]$_.$ValueProperty } | Measure-Object -Sum).Sum
    $prior = ($sorted | Where-Object { [datetime]$_.Date -ge $priorCutoff -and [datetime]$_.Date -lt $cutoff } |
        ForEach-Object { [int]$_.$ValueProperty } | Measure-Object -Sum).Sum

    $delta = if ($prior -gt 0) { [math]::Round(($current - $prior) / $prior * 100) } else { 0 }
    return @{ Current = $current; Prior = $prior; Delta = $delta; HasData = ($prior -gt 0) }
}

# Week-over-week (7d vs prior 7d)
$viewsWoW  = Get-RollingDelta -Data $views  -ValueProperty 'TotalViews'  -WindowDays 7
$clonesWoW = Get-RollingDelta -Data $clones -ValueProperty 'TotalClones' -WindowDays 7

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
$viewDeltaHtml = if ($viewsWoW.HasData) {
    $cls = if ($viewDelta -gt 0) { 'up' } elseif ($viewDelta -lt 0) { 'down' } else { 'flat' }
    $arrow = if ($viewDelta -gt 0) { '&#8593;' } elseif ($viewDelta -lt 0) { '&#8595;' } else { '&#8594;' }
    "<div class=`"m-delta $cls`" id=`"hdr-views-delta`">$arrow ${viewDelta}% WoW</div>"
} else {
    '<div class="m-delta flat" id="hdr-views-delta">&mdash;</div>'
}
$cloneDeltaHtml = if ($clonesWoW.HasData) {
    $cls = if ($cloneDelta -gt 0) { 'up' } elseif ($cloneDelta -lt 0) { 'down' } else { 'flat' }
    $arrow = if ($cloneDelta -gt 0) { '&#8593;' } elseif ($cloneDelta -lt 0) { '&#8595;' } else { '&#8594;' }
    "<div class=`"m-delta $cls`" id=`"hdr-clones-delta`">$arrow ${cloneDelta}% WoW</div>"
} else {
    '<div class="m-delta flat" id="hdr-clones-delta">&mdash;</div>'
}

$html += @"
  <div class="metrics reveal d1">
    <div class="metric">
      <div class="m-label" id="hdr-views-label">Views (All Time)</div>
      <div class="m-value" id="hdr-views-value">$totalViewsAllTime</div>
      <div class="m-sub" id="hdr-views-sub">$uniqueViewsAllTime unique</div>
      $viewDeltaHtml
    </div>
    <div class="metric">
      <div class="m-label" id="hdr-clones-label">Clones (All Time)</div>
      <div class="m-value" id="hdr-clones-value">$totalClonesAllTime</div>
      <div class="m-sub" id="hdr-clones-sub">$uniqueClonesAllTime unique</div>
      $cloneDeltaHtml
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
      <div class="m-label">PSGallery</div>
      <div class="m-value">$psGalleryTotal</div>
      <div class="m-sub">$psGalleryVersion &middot; $psGalleryVersionDlCount ver. installs</div>
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
      <div class="ch-left"><h3>PSGallery Downloads</h3><div class="ch-sub">Cumulative install count from PowerShell Gallery</div></div>
      <div class="ch-right"><div class="ch-stat-label">Total Installs</div><div class="ch-stat-value" id="psGalleryStat">$psGalleryTotal</div></div>
    </div>
    <canvas id="psGalleryChart"></canvas>
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

# Chart.js + external dashboard script
$html += @"
<script src="dashboard.js"></script>
<script>
var allData = {
  views:  { dates: $viewDates, total: $viewTotals, unique: $viewUniques },
  clones: { dates: $cloneDates, total: $cloneTotals, unique: $cloneUniques },
  stars:  { dates: $starDates, cumulative: $starCumulative, users: $starUsers },
  psGallery: { dates: $psGalleryDates, totalDl: $psGalleryTotalDl },
  releases: $releasesJson
};
var refData = { labels: $refLabels, views: $refViews, uniques: $refUniques };
var pathData = { labels: $pathLabels, views: $pathViews };
initDashboard(allData, refData, pathData);
</script>
</body>
</html>
"@
#endregion

#region Write and Open
$html | Out-File -FilePath $OutputFile -Encoding UTF8

# Copy dashboard.js alongside the HTML output
$jsSource = Join-Path $PSScriptRoot 'dashboard.js'
$jsTarget = Join-Path (Split-Path $OutputFile) 'dashboard.js'
if (Test-Path $jsSource) {
    Copy-Item $jsSource $jsTarget -Force
    Write-Host "Copied dashboard.js to $(Split-Path $jsTarget)" -ForegroundColor Gray
}

Write-Host "`nDashboard generated: $OutputFile" -ForegroundColor Green
if ($env:CI -ne 'true' -and $PSVersionTable.Platform -ne 'Unix') {
  Write-Host "Opening in browser..." -ForegroundColor Gray
  Start-Process $OutputFile
} else {
  Write-Host "Skipping browser launch in CI/non-Windows environment." -ForegroundColor Gray
}
#endregion
