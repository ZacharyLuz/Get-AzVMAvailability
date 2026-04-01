# Audit merged PRs for unreplied top-level non-owner comment threads.
# Fetches the current merged PR list dynamically from GitHub, then checks each one.
param(
    [string]$Owner = 'ZacharyLuz',
    [string]$Repo = 'Get-AzVMAvailability',
    [int]$Limit = 100
)

Write-Host "Fetching merged PR list..."
$prsRaw = gh api --paginate "repos/$Owner/$Repo/pulls?state=closed&per_page=$Limit" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Error "Failed to fetch PR list: $prsRaw"
    exit 1
}
$prObjects = $prsRaw | ConvertFrom-Json | Where-Object { $null -ne $_.merged_at }
$prs = $prObjects | Select-Object -ExpandProperty number | Sort-Object
Write-Host "Found $($prs.Count) merged PRs.`n"

$report = @()

foreach ($pr in $prs) {
    Write-Host "Checking PR #$pr..." -NoNewline
    $allRaw = gh api --paginate "repos/$Owner/$Repo/pulls/$pr/comments" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host " (error: $allRaw)" -ForegroundColor Red
        continue
    }
    $all = $allRaw | ConvertFrom-Json
    if (-not $all -or $all.Count -eq 0) {
        Write-Host " (no comments)"
        continue
    }

    # Build a lookup of which top-level comment IDs have an owner reply
    $repliedIds = @{}
    foreach ($c in $all) {
        if ($c.in_reply_to_id -and $c.user.login -eq $Owner) {
            $repliedIds[$c.in_reply_to_id] = $true
        }
    }

    # Find top-level non-owner comments that have no owner reply
    $openThreads = $all | Where-Object {
        $null -eq $_.in_reply_to_id -and
        $_.user.login -ne $Owner -and
        -not $repliedIds.ContainsKey($_.id)
    }

    $openCount = @($openThreads).Count
    Write-Host " $openCount open thread(s)"

    if ($openCount -gt 0) {
        $locations = $openThreads | ForEach-Object {
            $line = if ($_.line) { $_.line } else { $_.original_line }
            "$($_.path):$line"
        }
        $report += [PSCustomObject]@{
            PR        = $pr
            OpenCount = $openCount
            Locations = $locations -join ' | '
        }
    }
}

Write-Host ""
Write-Host "=== AUDIT SUMMARY ==="
if ($report.Count -eq 0) {
    Write-Host "All PRs fully replied to."
} else {
    $report | ForEach-Object {
        Write-Host "PR #$($_.PR) — $($_.OpenCount) open thread(s):"
        Write-Host "  $($_.Locations)"
        Write-Host ""
    }
}
