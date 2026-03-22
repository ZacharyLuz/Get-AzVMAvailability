# Get-QuotaAvailable.ps1
# Extracted from Get-AzVMAvailability.ps1 (line 1141)
# Returns available quota for a VM family in a given region
# DO NOT execute this file directly — it is a documentation reference only.
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
