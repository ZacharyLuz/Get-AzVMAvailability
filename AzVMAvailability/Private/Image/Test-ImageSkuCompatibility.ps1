function Test-ImageSkuCompatibility {
    <#
    .SYNOPSIS
        Tests if a VM SKU is compatible with the specified image requirements.
    .DESCRIPTION
        Compares the image's Generation and Architecture requirements against
        the SKU's capabilities to determine compatibility.
    .OUTPUTS
        Hashtable with Compatible (bool), Reason (string), Gen (string), Arch (string)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ImageReqs,

        [Parameter(Mandatory = $true)]
        [hashtable]$SkuCapabilities
    )

    $compatible = $true
    $reasons = @()

    # Check Generation compatibility
    $skuGens = $SkuCapabilities.HyperVGenerations -split ','
    $requiredGen = $ImageReqs.Gen
    if ($requiredGen -eq 'Gen2' -and $skuGens -notcontains 'V2') {
        $compatible = $false
        $reasons += "Gen2 required"
    }
    elseif ($requiredGen -eq 'Gen1' -and $skuGens -notcontains 'V1') {
        $compatible = $false
        $reasons += "Gen1 required"
    }

    # Check Architecture compatibility
    $skuArch = $SkuCapabilities.CpuArchitecture
    $requiredArch = $ImageReqs.Arch
    if ($requiredArch -eq 'ARM64' -and $skuArch -ne 'Arm64') {
        $compatible = $false
        $reasons += "ARM64 required"
    }
    elseif ($requiredArch -eq 'x64' -and $skuArch -eq 'Arm64') {
        $compatible = $false
        $reasons += "x64 required"
    }

    # Format the SKU's supported generations for display
    $genDisplay = ($skuGens | ForEach-Object { $_ -replace 'V', '' }) -join ','

    return @{
        Compatible = $compatible
        Reason     = if ($reasons.Count -gt 0) { $reasons -join '; ' } else { 'OK' }
        Gen        = $genDisplay
        Arch       = $skuArch
    }
}
