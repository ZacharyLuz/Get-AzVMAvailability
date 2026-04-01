<#
.SYNOPSIS
    Bulk-reply to all unreplied top-level non-owner comment threads across specified PRs.

.DESCRIPTION
    For each PR, finds top-level comments from non-owner users that have no owner reply,
    posts a canned reply, and reports what was done. Does NOT resolve threads on GitHub
    (resolving requires the web UI or GraphQL) — it only posts replies so threads show
    as acknowledged.

.PARAMETER PRNumbers
    Array of PR numbers to process.

.PARAMETER Reply
    The reply text to post on each unreplied thread.

.PARAMETER Owner / Repo
    GitHub owner and repo name.

.PARAMETER WhatIf
    Show what would be replied to without actually posting.
#>
param(
    [int[]]$PRNumbers,
    [string]$Reply = "Stale finding — the code this refers to has been significantly refactored in subsequent PRs. Closing thread.",
    [string]$Owner = 'ZacharyLuz',
    [string]$Repo = 'Get-AzVMAvailability',
    [switch]$WhatIf
)

Set-StrictMode -Version Latest

$total = 0
$posted = 0

foreach ($pr in $PRNumbers) {
    Write-Host "PR #$pr..." -NoNewline

    $allRaw = gh api --paginate "repos/$Owner/$Repo/pulls/$pr/comments" 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host " (error fetching: $allRaw)" -ForegroundColor Red
        continue
    }
    $all = $allRaw | ConvertFrom-Json
    if (-not $all -or $all.Count -eq 0) {
        Write-Host " (no comments)"
        continue
    }

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

    $openCount = @($open).Count
    if ($openCount -eq 0) {
        Write-Host " (all replied)"
        continue
    }

    Write-Host " $openCount to reply"
    $total += $openCount

    foreach ($t in $open) {
        $line = if ($t.line) { $t.line } else { $t.original_line }
        Write-Host "  → ID $($t.id) | $($t.path):$line | $($t.user.login)"

        if (-not $WhatIf) {
            $result = gh api "repos/$Owner/$Repo/pulls/$pr/comments/$($t.id)/replies" `
                --method POST -f "body=$Reply" 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-Host "    ✓ Reply posted" -ForegroundColor Green
                $posted++
            }
            else {
                Write-Host "    ✗ Failed: $result" -ForegroundColor Red
            }
        }
        else {
            Write-Host "    [WhatIf] Would post: $Reply" -ForegroundColor DarkYellow
        }
    }
}

$label = if ($WhatIf) { 'would reply to' } else { 'replied to' }
Write-Host ""
Write-Host "Done. $posted / $total thread(s) $label." -ForegroundColor Cyan
Write-Host "Next: open each PR on GitHub and click 'Resolve conversation' on each thread,"
Write-Host "or use the GraphQL resolveReviewThread mutation to batch-resolve."
