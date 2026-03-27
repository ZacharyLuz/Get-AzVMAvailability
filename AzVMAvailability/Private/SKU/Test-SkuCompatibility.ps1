function Test-SkuCompatibility {
    <#
    .SYNOPSIS
        Tests whether a candidate SKU can fully replace a target SKU.
    .DESCRIPTION
        Performs hard compatibility checks across critical VM dimensions: vCPU, memory,
        NICs, accelerated networking, premium IO, disk interface (NVMe/SCSI),
        ephemeral OS disk, and Ultra SSD. Returns pass/fail with a list of failures.
        This is a pre-filter before similarity scoring — only candidates that pass all
        checks should be scored and recommended.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Target,
        [Parameter(Mandatory)][hashtable]$Candidate
    )

    $failures = [System.Collections.Generic.List[string]]::new()

    # Category gate: burstable (B-series) candidates cannot replace non-burstable targets
    $targetFamily = if ($Target.Family) { $Target.Family } elseif ($Target.Name) { if ($Target.Name -match 'Standard_([A-Z]+)\d') { $matches[1] } else { '' } } else { '' }
    $candidateFamily = if ($Candidate.Family) { $Candidate.Family } elseif ($Candidate.Name) { if ($Candidate.Name -match 'Standard_([A-Z]+)\d') { $matches[1] } else { '' } } else { '' }
    if ($candidateFamily -eq 'B' -and $targetFamily -ne 'B') {
        $failures.Add("Category: burstable (B-series) cannot replace non-burstable ($targetFamily-series)")
    }

    # vCPU: candidate must meet or exceed target
    if ($Candidate.vCPU -gt 0 -and $Target.vCPU -gt 0 -and $Candidate.vCPU -lt $Target.vCPU) {
        $failures.Add("vCPU: candidate $($Candidate.vCPU) < target $($Target.vCPU)")
    }

    # vCPU ceiling: candidate must not exceed 2x target (prevents licensing-impacting core count jumps)
    if ($Candidate.vCPU -gt 0 -and $Target.vCPU -gt 0 -and $Candidate.vCPU -gt ($Target.vCPU * 2)) {
        $failures.Add("vCPU: candidate $($Candidate.vCPU) exceeds 2x target $($Target.vCPU) (licensing risk)")
    }

    # Memory: candidate must meet or exceed target
    if ($Candidate.MemoryGB -gt 0 -and $Target.MemoryGB -gt 0 -and $Candidate.MemoryGB -lt $Target.MemoryGB) {
        $failures.Add("MemoryGB: candidate $($Candidate.MemoryGB) < target $($Target.MemoryGB)")
    }

    # Max NICs: candidate must support at least as many
    if ($Target.MaxNetworkInterfaces -gt 1 -and $Candidate.MaxNetworkInterfaces -lt $Target.MaxNetworkInterfaces) {
        $failures.Add("MaxNICs: candidate $($Candidate.MaxNetworkInterfaces) < target $($Target.MaxNetworkInterfaces)")
    }

    # Accelerated networking: if target has it, candidate must too
    if ($Target.AccelNet -eq $true -and $Candidate.AccelNet -ne $true) {
        $failures.Add("AcceleratedNetworking: target requires it, candidate lacks it")
    }

    # Premium IO: if target requires premium, candidate must support it
    if ($Target.PremiumIO -eq $true -and $Candidate.PremiumIO -ne $true) {
        $failures.Add("PremiumIO: target requires it, candidate lacks it")
    }

    # Disk interface: NVMe target requires NVMe candidate
    if ($Target.DiskCode -match 'NV' -and $Candidate.DiskCode -notmatch 'NV') {
        $failures.Add("DiskInterface: target uses NVMe, candidate only has SCSI")
    }

    # Ephemeral OS disk: if target uses it, candidate must support it
    if ($Target.EphemeralOSDiskSupported -eq $true -and $Candidate.EphemeralOSDiskSupported -ne $true) {
        $failures.Add("EphemeralOSDisk: target requires it, candidate lacks it")
    }

    # Ultra SSD: if target uses it, candidate must support it
    if ($Target.UltraSSDAvailable -eq $true -and $Candidate.UltraSSDAvailable -ne $true) {
        $failures.Add("UltraSSD: target requires it, candidate lacks it")
    }

    return @{
        Compatible = ($failures.Count -eq 0)
        Failures   = @($failures)
    }
}
