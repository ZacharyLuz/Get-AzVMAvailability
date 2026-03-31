# Audit all merged PRs for unreplied top-level bot/Copilot comment threads
param([string]$Owner = 'ZacharyLuz', [string]$Repo = 'Get-AzVMAvailability')

$prs = @(20,21,22,23,24,26,27,29,30,33,35,36,37,38,39,40,42,43,44,45,47,48,49,58,59,60,77,78,79,80,81,82,83,84,85,86,88,89,90,91,93,94,96,97,100,101,104,105,106,107)

$report = @()

foreach ($pr in $prs) {
    Write-Host "Checking PR #$pr..." -NoNewline
    $all = gh api "repos/$Owner/$Repo/pulls/$pr/comments" 2>$null | ConvertFrom-Json
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
