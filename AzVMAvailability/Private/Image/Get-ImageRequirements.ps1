function Get-ImageRequirements {
    <#
    .SYNOPSIS
        Parses an image URN and determines its Generation and Architecture requirements.
    .DESCRIPTION
        Analyzes the image URN (Publisher:Offer:Sku:Version) to determine if the image
        requires Gen1 or Gen2 VMs, and whether it needs x64 or ARM64 architecture.
        Uses pattern matching on SKU names for common Azure Marketplace images.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ImageURN
    )

    $parts = $ImageURN -split ':'
    if ($parts.Count -lt 3) {
        return @{ Gen = 'Unknown'; Arch = 'Unknown'; Valid = $false; Error = "Invalid URN format" }
    }

    $publisher = $parts[0]
    $offer = $parts[1]
    $sku = $parts[2]

    # Determine Generation from SKU name patterns
    $gen = 'Gen1'  # Default to Gen1 for compatibility
    if ($sku -match '-gen2|-g2|gen2|_gen2|arm64|aarch64') {
        $gen = 'Gen2'
    }
    elseif ($sku -match '-gen1|-g1|gen1|_gen1') {
        $gen = 'Gen1'
    }
    # Some publishers use different patterns
    elseif ($offer -match 'gen2' -or $publisher -match 'gen2') {
        $gen = 'Gen2'
    }

    # Determine Architecture from SKU name patterns
    $arch = 'x64'  # Default to x64
    if ($sku -match 'arm64|aarch64') {
        $arch = 'ARM64'
    }

    return @{
        Gen       = $gen
        Arch      = $arch
        Publisher = $publisher
        Offer     = $offer
        Sku       = $sku
        Valid     = $true
    }
}
