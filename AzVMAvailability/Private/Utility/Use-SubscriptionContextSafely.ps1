function Use-SubscriptionContextSafely {
    param([Parameter(Mandatory)][string]$SubscriptionId)

    $ctx = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $ctx -or -not $ctx.Subscription -or $ctx.Subscription.Id -ne $SubscriptionId) {
        Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null
        return $true
    }

    return $false
}
