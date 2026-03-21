function Get-QuotaAvailable {
    param([hashtable]$QuotaLookup, [string]$SkuFamily, [int]$RequiredvCPUs = 0)
    $quota = $QuotaLookup[$SkuFamily]
    if (-not $quota) { return @{ Available = $null; OK = $null; Limit = $null; Current = $null } }
    $available = $quota.Limit - $quota.CurrentValue
    return @{
        Available = $available
        OK        = if ($RequiredvCPUs -gt 0) { $available -ge $RequiredvCPUs } else { $available -gt 0 }
        Limit     = $quota.Limit
        Current   = $quota.CurrentValue
    }
}
