function Restore-OriginalSubscriptionContext {
    param([string]$OriginalSubscriptionId)

    if (-not $OriginalSubscriptionId) {
        return $false
    }

    $ctx = Get-AzContext -ErrorAction SilentlyContinue
    if ($ctx -and $ctx.Subscription -and $ctx.Subscription.Id -eq $OriginalSubscriptionId) {
        return $false
    }

    try {
        Set-AzContext -SubscriptionId $OriginalSubscriptionId -ErrorAction Stop | Out-Null
        Write-Verbose "Restored Azure context to original subscription: $OriginalSubscriptionId"
        return $true
    }
    catch {
        Write-Warning "Failed to restore Azure context to original subscription '$OriginalSubscriptionId': $($_.Exception.Message)"
        return $false
    }
}
