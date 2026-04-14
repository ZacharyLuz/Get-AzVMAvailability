<#
.SYNOPSIS
    Collects GitHub traffic analytics and appends to historical CSV files.

.DESCRIPTION
    GitHub only retains traffic data for 14 days. This script captures views,
    clones, referrers, and popular paths via the GitHub API, collects PSGallery
    download stats, and appends new records to CSV files in the artifacts/traffic/
    directory. Designed to be run daily (manually, scheduled task, or GitHub Actions).

    Requires: GitHub CLI (gh) authenticated with repo scope.

.PARAMETER Owner
    Repository owner. Defaults to 'ZacharyLuz'.

.PARAMETER Repo
    Repository name. Defaults to 'Get-AzVMAvailability'.

.PARAMETER OutputDir
    Directory for CSV output files. Defaults to artifacts/traffic/ in the repo root.

.EXAMPLE
    .\tools\Collect-TrafficData.ps1
    # Collects all traffic metrics using defaults

.EXAMPLE
    .\tools\Collect-TrafficData.ps1 -Owner "ZacharyLuz" -Repo "Get-AzVMAvailability"
    # Explicit owner/repo
#>

[CmdletBinding()]
param(
    [string]$Owner = 'ZacharyLuz',
    [string]$Repo  = 'Get-AzVMAvailability',
    [string]$OutputDir
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Constants
$ViewsFile     = 'views.csv'
$ClonesFile    = 'clones.csv'
$ReferrersFile = 'referrers.csv'
$PathsFile     = 'paths.csv'
$StarsFile     = 'stars.csv'
$RepoStatsFile = 'repo-stats.csv'
$ReleaseDownloadsFile = 'release-downloads.csv'
$PSGalleryFile = 'psgallery-downloads.csv'
$StargazersPerPage = 100
$PSGalleryModuleName = 'AzVMAvailability'
#endregion

#region Setup
if (-not $OutputDir) {
    $repoRoot = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
    if (-not $repoRoot) { $repoRoot = Split-Path -Parent $PSScriptRoot }
    $OutputDir = Join-Path $PSScriptRoot '..' 'artifacts' 'traffic'
    $OutputDir = [System.IO.Path]::GetFullPath($OutputDir)
}

if (-not (Test-Path $OutputDir)) {
    New-Item -Path $OutputDir -ItemType Directory -Force | Out-Null
    Write-Host "Created output directory: $OutputDir" -ForegroundColor Cyan
}

# Verify gh CLI is available and authenticated
try {
    $null = & gh auth status 2>&1
    if ($LASTEXITCODE -ne 0) { throw "gh CLI not authenticated. Run 'gh auth login' first." }
}
catch {
    Write-Error "GitHub CLI (gh) is required. Install from https://cli.github.com/ and run 'gh auth login'."
    return
}
#endregion

#region Helper: Load existing CSV or return empty array
function Get-ExistingData {
    param([string]$FilePath)
    if (Test-Path $FilePath) {
        return @(Import-Csv -Path $FilePath)
    }
    return @()
}
#endregion

#region Helper: Merge new daily records, deduplicate by date
function Merge-DailyRecords {
    param(
        [array]$Existing,
        [array]$New,
        [string]$DateProperty = 'Date'
    )

    $existingDates = @{}
    foreach ($row in $Existing) {
        $existingDates[$row.$DateProperty] = $true
    }

    $added = 0
    foreach ($row in $New) {
        if (-not $existingDates.ContainsKey($row.$DateProperty)) {
            $Existing += $row
            $existingDates[$row.$DateProperty] = $true
            $added++
        }
    }

    Write-Verbose "Merged: $added new records, $($Existing.Count) total"
    return @{ Records = $Existing; Added = $added }
}
#endregion

#region Helper: Merge snapshot records (referrers/paths captured at a point in time)
function Merge-SnapshotRecords {
    param(
        [array]$Existing,
        [array]$New,
        [string]$KeyProperty,
        [string]$CollectedDate
    )

    $existingKeys = @{}
    foreach ($row in $Existing) {
        $compositeKey = "$($row.CollectedDate)|$($row.$KeyProperty)"
        $existingKeys[$compositeKey] = $true
    }

    $added = 0
    foreach ($row in $New) {
        $compositeKey = "$CollectedDate|$($row.$KeyProperty)"
        if (-not $existingKeys.ContainsKey($compositeKey)) {
            $Existing += $row
            $existingKeys[$compositeKey] = $true
            $added++
        }
    }

    return @{ Records = $Existing; Added = $added }
}
#endregion

$collectedDate = (Get-Date).ToString('yyyy-MM-dd')
$totalNew = 0

#region Collect Views
Write-Host "`nCollecting page views..." -ForegroundColor Cyan
try {
    $viewsJson = & gh api "repos/$Owner/$Repo/traffic/views" 2>&1
    if ($LASTEXITCODE -ne 0) { throw "API call failed: $viewsJson" }

    $viewsData = $viewsJson | ConvertFrom-Json
    $newViews = foreach ($v in $viewsData.views) {
        [PSCustomObject]@{
            Date         = ([DateTimeOffset]$v.timestamp).ToString('yyyy-MM-dd')
            TotalViews   = $v.count
            UniqueViews  = $v.uniques
        }
    }

    $viewsPath = Join-Path $OutputDir $ViewsFile
    $existing = Get-ExistingData -FilePath $viewsPath
    $result = Merge-DailyRecords -Existing $existing -New $newViews -DateProperty 'Date'
    $result.Records | Sort-Object Date | Export-Csv -Path $viewsPath -NoTypeInformation
    $totalNew += $result.Added
    Write-Host "  Views: $($result.Added) new days added ($($result.Records.Count) total records)" -ForegroundColor Green
    Write-Host "  Summary: $($viewsData.count) total views, $($viewsData.uniques) unique (last 14 days)" -ForegroundColor Gray
}
catch {
    Write-Warning "Failed to collect views: $_"
}
#endregion

#region Collect Clones
Write-Host "`nCollecting clones..." -ForegroundColor Cyan
try {
    $clonesJson = & gh api "repos/$Owner/$Repo/traffic/clones" 2>&1
    if ($LASTEXITCODE -ne 0) { throw "API call failed: $clonesJson" }

    $clonesData = $clonesJson | ConvertFrom-Json
    $newClones = foreach ($c in $clonesData.clones) {
        [PSCustomObject]@{
            Date          = ([DateTimeOffset]$c.timestamp).ToString('yyyy-MM-dd')
            TotalClones   = $c.count
            UniqueClones  = $c.uniques
        }
    }

    $clonesPath = Join-Path $OutputDir $ClonesFile
    $existing = Get-ExistingData -FilePath $clonesPath
    $result = Merge-DailyRecords -Existing $existing -New $newClones -DateProperty 'Date'
    $result.Records | Sort-Object Date | Export-Csv -Path $clonesPath -NoTypeInformation
    $totalNew += $result.Added
    Write-Host "  Clones: $($result.Added) new days added ($($result.Records.Count) total records)" -ForegroundColor Green
    Write-Host "  Summary: $($clonesData.count) total clones, $($clonesData.uniques) unique (last 14 days)" -ForegroundColor Gray
}
catch {
    Write-Warning "Failed to collect clones: $_"
}
#endregion

#region Collect Referrers
Write-Host "`nCollecting top referrers..." -ForegroundColor Cyan
try {
    $referrersJson = & gh api "repos/$Owner/$Repo/traffic/popular/referrers" 2>&1
    if ($LASTEXITCODE -ne 0) { throw "API call failed: $referrersJson" }

    $referrersData = $referrersJson | ConvertFrom-Json
    $newReferrers = foreach ($r in $referrersData) {
        [PSCustomObject]@{
            CollectedDate  = $collectedDate
            Referrer       = $r.referrer
            TotalViews     = $r.count
            UniqueVisitors = $r.uniques
        }
    }

    $referrersPath = Join-Path $OutputDir $ReferrersFile
    $existing = Get-ExistingData -FilePath $referrersPath
    $result = Merge-SnapshotRecords -Existing $existing -New $newReferrers -KeyProperty 'Referrer' -CollectedDate $collectedDate
    $result.Records | Sort-Object CollectedDate, Referrer | Export-Csv -Path $referrersPath -NoTypeInformation
    $totalNew += $result.Added
    Write-Host "  Referrers: $($result.Added) new records ($($result.Records.Count) total)" -ForegroundColor Green
}
catch {
    Write-Warning "Failed to collect referrers: $_"
}
#endregion

#region Collect Popular Paths
Write-Host "`nCollecting popular paths..." -ForegroundColor Cyan
try {
    $pathsJson = & gh api "repos/$Owner/$Repo/traffic/popular/paths" 2>&1
    if ($LASTEXITCODE -ne 0) { throw "API call failed: $pathsJson" }

    $pathsData = $pathsJson | ConvertFrom-Json
    $newPaths = foreach ($p in $pathsData) {
        [PSCustomObject]@{
            CollectedDate  = $collectedDate
            Path           = $p.path
            Title          = $p.title
            TotalViews     = $p.count
            UniqueVisitors = $p.uniques
        }
    }

    $pathsPath = Join-Path $OutputDir $PathsFile
    $existing = Get-ExistingData -FilePath $pathsPath
    $result = Merge-SnapshotRecords -Existing $existing -New $newPaths -KeyProperty 'Path' -CollectedDate $collectedDate
    $result.Records | Sort-Object CollectedDate, Path | Export-Csv -Path $pathsPath -NoTypeInformation
    $totalNew += $result.Added
    Write-Host "  Paths: $($result.Added) new records ($($result.Records.Count) total)" -ForegroundColor Green
}
catch {
    Write-Warning "Failed to collect popular paths: $_"
}
#endregion

#region Collect Star History
Write-Host "`nCollecting star history..." -ForegroundColor Cyan
try {
    $starsPath = Join-Path $OutputDir $StarsFile
    $existingStars = Get-ExistingData -FilePath $starsPath

    $existingStarDates = @{}
    foreach ($row in $existingStars) {
        $existingStarDates[$row.Date] = $true
    }

    $page = 1
    $newStarRecords = @()
    $seenAllExisting = $false

    while (-not $seenAllExisting) {
        $starJson = & gh api "repos/$Owner/$Repo/stargazers?per_page=$StargazersPerPage&page=$page" -H 'Accept: application/vnd.github.v3.star+json' 2>&1
        if ($LASTEXITCODE -ne 0) { throw "API call failed: $starJson" }

        $starPage = $starJson | ConvertFrom-Json
        if ($starPage.Count -eq 0) { break }

        foreach ($s in $starPage) {
            $starDate = ([DateTimeOffset]$s.starred_at).ToString('yyyy-MM-dd')
            if (-not $existingStarDates.ContainsKey($starDate)) {
                $newStarRecords += [PSCustomObject]@{
                    Date = $starDate
                    User = $s.user.login
                }
                $existingStarDates[$starDate] = $true
            }
        }

        if ($starPage.Count -lt $StargazersPerPage) { break }
        $page++
    }

    if ($newStarRecords.Count -gt 0) {
        $allStars = @($existingStars) + @($newStarRecords)
    } else {
        $allStars = $existingStars
    }

    # Build cumulative star count
    $sorted = $allStars | Sort-Object Date
    $cumulative = 0
    $finalRecords = foreach ($star in $sorted) {
        $cumulative++
        [PSCustomObject]@{
            Date           = $star.Date
            User           = $star.User
            CumulativeStars = $cumulative
        }
    }

    $finalRecords | Export-Csv -Path $starsPath -NoTypeInformation
    $totalNew += $newStarRecords.Count
    Write-Host "  Stars: $($newStarRecords.Count) new stars found ($cumulative total)" -ForegroundColor Green
}
catch {
    Write-Warning "Failed to collect star history: $_"
}
#endregion

#region Collect Repo Stats (forks, watchers, open issues)
Write-Host "`nCollecting repo stats..." -ForegroundColor Cyan
try {
    $repoJson = & gh api "repos/$Owner/$Repo" 2>&1
    if ($LASTEXITCODE -ne 0) { throw "API call failed: $repoJson" }

    $repoData = $repoJson | ConvertFrom-Json
    $statsRecord = [PSCustomObject]@{
        Date            = $collectedDate
        Stars           = $repoData.stargazers_count
        Forks           = $repoData.forks_count
        Watchers        = $repoData.subscribers_count
        OpenIssues      = $repoData.open_issues_count
        Size_KB         = $repoData.size
    }

    $statsPath = Join-Path $OutputDir $RepoStatsFile
    $existingStats = Get-ExistingData -FilePath $statsPath

    $alreadyHasToday = $false
    foreach ($row in $existingStats) {
        if ($row.Date -eq $collectedDate) { $alreadyHasToday = $true; break }
    }

    if (-not $alreadyHasToday) {
        $allStats = @($existingStats) + @($statsRecord)
        $allStats | Sort-Object Date | Export-Csv -Path $statsPath -NoTypeInformation
        $totalNew++
        Write-Host "  Repo stats: captured (Stars: $($repoData.stargazers_count), Forks: $($repoData.forks_count), Watchers: $($repoData.subscribers_count))" -ForegroundColor Green
    } else {
        Write-Host "  Repo stats: already captured today" -ForegroundColor Yellow
    }
}
catch {
    Write-Warning "Failed to collect repo stats: $_"
}
#endregion

#region Collect Release Download Stats (asset download snapshots)
Write-Host "`nCollecting release download stats..." -ForegroundColor Cyan
try {
    $releasesJson = & gh api "repos/$Owner/$Repo/releases" --paginate 2>&1
    if ($LASTEXITCODE -ne 0) { throw "API call failed: $releasesJson" }

    $releasesData = $releasesJson | ConvertFrom-Json
    $releaseCount = @($releasesData).Count
    $assetCount = 0
    $totalReleaseDownloads = 0

    foreach ($release in @($releasesData)) {
        foreach ($asset in @($release.assets)) {
            $assetCount++
            $totalReleaseDownloads += [int]$asset.download_count
        }
    }

    $releaseDownloadsPath = Join-Path $OutputDir $ReleaseDownloadsFile
    $existingReleaseDownloads = Get-ExistingData -FilePath $releaseDownloadsPath
    $newSnapshot = @(
        [PSCustomObject]@{
            Date                  = $collectedDate
            TotalReleaseDownloads = $totalReleaseDownloads
            ReleaseCount          = $releaseCount
            AssetCount            = $assetCount
        }
    )

    $result = Merge-DailyRecords -Existing $existingReleaseDownloads -New $newSnapshot -DateProperty 'Date'
    $result.Records | Sort-Object Date | Export-Csv -Path $releaseDownloadsPath -NoTypeInformation
    $totalNew += $result.Added
    Write-Host "  Release downloads: $($result.Added) new snapshots ($($result.Records.Count) total)" -ForegroundColor Green
    Write-Host "  Summary: $totalReleaseDownloads total downloads across $assetCount assets in $releaseCount releases" -ForegroundColor Gray
}
catch {
    Write-Warning "Failed to collect release download stats: $_"
}
#endregion

#region Collect PSGallery Downloads
Write-Host "`nCollecting PSGallery download stats..." -ForegroundColor Cyan
try {
    $galleryUrl = "https://www.powershellgallery.com/api/v2/FindPackagesById()?id='$PSGalleryModuleName'"
    $packages = Invoke-RestMethod -Uri $galleryUrl -ErrorAction Stop
    $galleryRecords = @()
    $totalGalleryDownloads = 0

    foreach ($pkg in $packages) {
        $props = $pkg.properties
        $version = $props.Version
        $versionDownloads = [long]$props.VersionDownloadCount.'#text'
        $totalDownloads = [long]$props.DownloadCount.'#text'
        $isLatest = $props.IsLatestVersion.'#text' -eq 'true'
        $totalGalleryDownloads = $totalDownloads

        $galleryRecords += [PSCustomObject]@{
            Date             = $collectedDate
            Version          = $version
            VersionDownloads = $versionDownloads
            TotalDownloads   = $totalDownloads
            IsLatestVersion  = $isLatest
        }
    }

    $psGalleryPath = Join-Path $OutputDir $PSGalleryFile
    $existingGallery = Get-ExistingData -FilePath $psGalleryPath

    # Snapshot merge: skip if today already collected (all versions are a batch)
    $alreadyCollected = $existingGallery | Where-Object { $_.Date -eq $collectedDate }
    if ($alreadyCollected) {
        $totalNew += 0
        Write-Host "  PSGallery: 0 new records (today already collected, $($existingGallery.Count) total)" -ForegroundColor Green
    }
    else {
        $merged = @($existingGallery) + @($galleryRecords)
        $merged | Sort-Object Date, Version | Export-Csv -Path $psGalleryPath -NoTypeInformation
        $totalNew += $galleryRecords.Count
        Write-Host "  PSGallery: $($galleryRecords.Count) new records ($($merged.Count) total)" -ForegroundColor Green
    }
    Write-Host "  Summary: $totalGalleryDownloads total downloads across $($galleryRecords.Count) version(s)" -ForegroundColor Gray
}
catch {
    Write-Warning "Failed to collect PSGallery download stats: $_"
}
#endregion

#region Summary
Write-Host "`n--- Collection Complete ---" -ForegroundColor Cyan
Write-Host "Output directory: $OutputDir" -ForegroundColor Gray
Write-Host "Total new records added: $totalNew" -ForegroundColor $(if ($totalNew -gt 0) { 'Green' } else { 'Yellow' })
Write-Host "Run this script daily to build historical data (GitHub only retains 14 days)." -ForegroundColor Gray
#endregion
