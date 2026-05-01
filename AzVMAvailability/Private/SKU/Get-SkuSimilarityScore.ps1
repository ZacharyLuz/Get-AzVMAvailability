function Get-SkuSimilarityScore {
    <#
    .SYNOPSIS
        Scores how similar a candidate SKU is to a target SKU profile.
    .DESCRIPTION
        Weighted scoring across 8 dimensions: vCPU (20), memory (20), family (15),
        family version newness (15), architecture (10), premium IO (5), disk IOPS (8),
        data disk count (7). Max 100.
        Family version newness uses continuous formulas so future generations (v8, v9, v10+)
        score correctly without code changes.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Target,
        [Parameter(Mandatory)][hashtable]$Candidate,
        [hashtable]$FamilyInfo
    )

    $score = 0

    # vCPU closeness (20 points)
    if ($Target.vCPU -gt 0 -and $Candidate.vCPU -gt 0) {
        $maxCpu = [math]::Max($Target.vCPU, $Candidate.vCPU)
        $cpuScore = 1 - ([math]::Abs($Target.vCPU - $Candidate.vCPU) / $maxCpu)
        $score += [math]::Round($cpuScore * 20)
    }

    # Memory closeness (20 points)
    if ($Target.MemoryGB -gt 0 -and $Candidate.MemoryGB -gt 0) {
        $maxMem = [math]::Max($Target.MemoryGB, $Candidate.MemoryGB)
        $memScore = 1 - ([math]::Abs($Target.MemoryGB - $Candidate.MemoryGB) / $maxMem)
        $score += [math]::Round($memScore * 20)
    }

    # Family match (15 points) — exact = 15, same category = 11, same first letter = 7
    if ($Target.Family -eq $Candidate.Family) {
        $score += 15
    }
    else {
        $targetInfo = if ($FamilyInfo) { $FamilyInfo[$Target.Family] } else { $null }
        $candidateInfo = if ($FamilyInfo) { $FamilyInfo[$Candidate.Family] } else { $null }
        $targetCat = if ($targetInfo) { $targetInfo.Category } else { 'Unknown' }
        $candidateCat = if ($candidateInfo) { $candidateInfo.Category } else { 'Unknown' }
        if ($targetCat -ne 'Unknown' -and $targetCat -eq $candidateCat) {
            $score += 11
        }
        elseif ($Target.Family.Length -gt 0 -and $Candidate.Family.Length -gt 0 -and
            $Target.Family[0] -eq $Candidate.Family[0]) {
            $score += 7
        }
    }

    # Family version newness (15 points) — continuous formulas, no version cap
    $targetVer = if ($Target.FamilyVersion) { [int]$Target.FamilyVersion } else { 1 }
    $candidateVer = if ($Candidate.FamilyVersion) { [int]$Candidate.FamilyVersion } else { 1 }

    if ($Target.Family -eq $Candidate.Family) {
        if ($candidateVer -gt $targetVer) {
            # Upgrade: base 8 + (candidateVer - 1), capped at 15
            $score += [math]::Min(8 + $candidateVer - 1, 15)
        }
        elseif ($candidateVer -eq $targetVer) {
            $score += 6
        }
        else {
            $score += 1
        }
    }
    else {
        # Cross-family: 2 points per version above v1, capped at 13
        $score += [math]::Min(2 * ($candidateVer - 1), 13)
    }

    # Architecture match (10 points)
    if ($Target.Architecture -eq $Candidate.Architecture) {
        $score += 10
    }

    # Premium IO match (5 points) — if target needs premium, candidate must have it
    if ($Target.PremiumIO -eq $true -and $Candidate.PremiumIO -eq $true) {
        $score += 5
    }
    elseif ($Target.PremiumIO -ne $true) {
        $score += 5
    }

    # Disk IOPS closeness (8 points) — uncached disk IO throughput
    if ($Target.UncachedDiskIOPS -gt 0 -and $Candidate.UncachedDiskIOPS -gt 0) {
        $maxIOPS = [math]::Max($Target.UncachedDiskIOPS, $Candidate.UncachedDiskIOPS)
        $iopsScore = 1 - ([math]::Abs($Target.UncachedDiskIOPS - $Candidate.UncachedDiskIOPS) / $maxIOPS)
        $score += [math]::Round($iopsScore * 8)
    }
    elseif ($Target.UncachedDiskIOPS -le 0) {
        $score += 8
    }

    # Data disk count closeness (7 points)
    if ($Target.MaxDataDiskCount -gt 0 -and $Candidate.MaxDataDiskCount -gt 0) {
        $maxDisks = [math]::Max($Target.MaxDataDiskCount, $Candidate.MaxDataDiskCount)
        $diskScore = 1 - ([math]::Abs($Target.MaxDataDiskCount - $Candidate.MaxDataDiskCount) / $maxDisks)
        $score += [math]::Round($diskScore * 7)
    }
    elseif ($Target.MaxDataDiskCount -le 0) {
        $score += 7
    }

    return [math]::Min($score, 100)
}
