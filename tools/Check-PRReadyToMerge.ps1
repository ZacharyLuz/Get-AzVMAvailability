<#
.SYNOPSIS
    Pre-merge gate: verify all Copilot/bot comment threads are replied to before merging.

.DESCRIPTION
    Fetches all inline PR comments, identifies top-level bot threads with no owner reply,
    and blocks merge if any are found. Run this after every push, before merging.

    Branch protection already enforces "required_review_thread_resolution" — this script
    is the local companion that shows you exactly what needs to be addressed so you never
    hit a blocked merge unexpectedly.

.PARAMETER PRNumber
    PR number to check. Defaults to the current branch's open PR.

.PARAMETER Owner
    GitHub repo owner. Defaults to ZacharyLuz.

.PARAMETER Repo
    GitHub repo name. Defaults to Get-AzVMAvailability.

.EXAMPLE
    .\tools\Check-PRReadyToMerge.ps1
    .\tools\Check-PRReadyToMerge.ps1 -PRNumber 104
#>
param(
    [int]$PRNumber = 0,
    [string]$Owner = 'ZacharyLuz',
    [string]$Repo = 'Get-AzVMAvailability'
)

Set-StrictMode -Version Latest

#region Resolve PR number
if ($PRNumber -eq 0) {
    $branch = git branch --show-current 2>$null
    if (-not $branch) {
        Write-Error "Could not determine current branch. Pass -PRNumber explicitly."
        exit 1
    }
    $prJson = gh api "repos/$Owner/$Repo/pulls?head=$Owner`:$branch&state=open" 2>$null | ConvertFrom-Json
    if (-not $prJson -or $prJson.Count -eq 0) {
        Write-Host "No open PR found for branch '$branch'." -ForegroundColor Yellow
        Write-Host "If the PR is not open yet, push your branch and create a PR first."
        exit 0
    }
    $PRNumber = $prJson[0].number
    Write-Host "Checking PR #$PRNumber ($($prJson[0].title))..." -ForegroundColor Cyan
}
#endregion

#region Fetch comments
$all = gh api "repos/$Owner/$Repo/pulls/$PRNumber/comments" 2>$null | ConvertFrom-Json
if (-not $all -or $all.Count -eq 0) {
    Write-Host ""
    Write-Host "PR #$PRNumber — no inline comments. Ready to merge." -ForegroundColor Green
    exit 0
}
#endregion

#region Find unreplied threads
$repliedIds = @{}
foreach ($c in $all) {
    if ($null -ne $c.in_reply_to_id -and $c.user.login -eq $Owner) {
        $repliedIds[$c.in_reply_to_id] = $true
    }
}

$open = $all | Where-Object {
    $null -eq $_.in_reply_to_id -and
    $_.user.login -ne $Owner -and
    -not $repliedIds.ContainsKey($_.id)
}
#endregion

#region Report
$total = @($all | Where-Object { $null -eq $_.in_reply_to_id }).Count
$openCount = @($open).Count
$replied = $total - $openCount

Write-Host ""
Write-Host "── PR #$PRNumber Comment Thread Status ──────────────────────────────" -ForegroundColor Cyan
Write-Host "  Total top-level threads : $total"
Write-Host "  Replied (owner)         : $replied" -ForegroundColor Green
Write-Host "  UNREPLIED               : $openCount" -ForegroundColor $(if ($openCount -gt 0) { 'Red' } else { 'Green' })
Write-Host ""

if ($openCount -gt 0) {
    Write-Host "The following threads need a reply before you can merge:" -ForegroundColor Red
    Write-Host ""
    $i = 1
    foreach ($t in $open) {
        $line = if ($t.line) { $t.line } else { $t.original_line }
        $preview = $t.body -replace '\r?\n', ' '
        if ($preview.Length -gt 100) { $preview = $preview.Substring(0, 100) + '...' }
        Write-Host "  [$i] ID $($t.id) | $($t.user.login) | $($t.path):$line"
        Write-Host "      $preview" -ForegroundColor DarkGray
        Write-Host ""
        $i++
    }
    Write-Host "Reply to each thread:" -ForegroundColor Yellow
    Write-Host '  gh api repos/$Owner/$Repo/pulls/$PRNumber/comments/{id}/replies --method POST -f body="Agree — fixed in this PR."'
    Write-Host ""
    Write-Host "Then resolve each conversation on GitHub before merging." -ForegroundColor Yellow
    Write-Host ""
    exit 1
}
else {
    Write-Host "All threads replied to. Verify conversations are RESOLVED on GitHub, then merge." -ForegroundColor Green
    Write-Host ""
    exit 0
}
#endregion
