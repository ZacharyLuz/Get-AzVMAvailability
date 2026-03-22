# Use-SubscriptionContextSafely.ps1
# Extracted from Get-AzVMAvailability.ps1 (line 1386)
# Switches to a target subscription and saves the original context
# DO NOT execute this file directly — it is a documentation reference only.
function Use-SubscriptionContextSafely {
    param([Parameter(Mandatory)][string]$SubscriptionId)

    $ctx = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $ctx -or -not $ctx.Subscription -or $ctx.Subscription.Id -ne $SubscriptionId) {
        Set-AzContext -SubscriptionId $SubscriptionId -ErrorAction Stop | Out-Null
        return $true
    }

    return $false
}
