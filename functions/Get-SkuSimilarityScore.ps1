# Get-SkuSimilarityScore.ps1
# Extracted from Get-AzVMAvailability.ps1 (line 1461)
# Computes a 0-100 similarity score between two VM SKUs for recommendations
# DO NOT execute this file directly — it is a documentation reference only.
function Get-SkuSimilarityScore {
    <#
    .SYNOPSIS
        Scores how similar a candidate SKU is to a target SKU profile.
    .DESCRIPTION
        Weighted scoring across 6 dimensions: vCPU (25), memory (25), family (20),
        generation (13), architecture (12), premium IO (5). Max 100.
    #>
    param(
        [Parameter(Mandatory)][hashtable]$Target,
        [Parameter(Mandatory)][hashtable]$Candidate,
        [hashtable]$FamilyInfo
    )

    $score = 0

    # vCPU closeness (25 points)
    if ($Target.vCPU -gt 0 -and $Candidate.vCPU -gt 0) {
        $maxCpu = [math]::Max($Target.vCPU, $Candidate.vCPU)
        $cpuScore = 1 - ([math]::Abs($Target.vCPU - $Candidate.vCPU) / $maxCpu)
        $score += [math]::Round($cpuScore * 25)
    }

    # Memory closeness (25 points)
    if ($Target.MemoryGB -gt 0 -and $Candidate.MemoryGB -gt 0) {
        $maxMem = [math]::Max($Target.MemoryGB, $Candidate.MemoryGB)
        $memScore = 1 - ([math]::Abs($Target.MemoryGB - $Candidate.MemoryGB) / $maxMem)
        $score += [math]::Round($memScore * 25)
    }

    # Family match (20 points) — exact = 20, same category = 15, same first letter = 10
    if ($Target.Family -eq $Candidate.Family) {
        $score += 20
    }
    else {
        $targetInfo = if ($FamilyInfo) { $FamilyInfo[$Target.Family] } else { $null }
        $candidateInfo = if ($FamilyInfo) { $FamilyInfo[$Candidate.Family] } else { $null }
        $targetCat = if ($targetInfo) { $targetInfo.Category } else { 'Unknown' }
        $candidateCat = if ($candidateInfo) { $candidateInfo.Category } else { 'Unknown' }
        if ($targetCat -ne 'Unknown' -and $targetCat -eq $candidateCat) {
            $score += 15
        }
        elseif ($Target.Family.Length -gt 0 -and $Candidate.Family.Length -gt 0 -and
            $Target.Family[0] -eq $Candidate.Family[0]) {
            $score += 10
        }
    }

    # Generation match (13 points)
    if ($Target.Generation -and $Candidate.Generation) {
        $targetGens = @($Target.Generation -split ',')
        $candidateGens = @($Candidate.Generation -split ',')
        $overlap = $targetGens | Where-Object { $_ -in $candidateGens }
        if ($overlap) { $score += 13 }
    }

    # Architecture match (12 points)
    if ($Target.Architecture -eq $Candidate.Architecture) {
        $score += 12
    }

    # Premium IO match (5 points) — if target needs premium, candidate must have it
    if ($Target.PremiumIO -eq $true -and $Candidate.PremiumIO -eq $true) {
        $score += 5
    }
    elseif ($Target.PremiumIO -ne $true) {
        $score += 5
    }

    return [math]::Min($score, 100)
}
