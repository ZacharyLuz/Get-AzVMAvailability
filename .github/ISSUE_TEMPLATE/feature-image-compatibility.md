---
name: 'Feature: Image Compatibility Check'
about: Verify VM image compatibility with selected SKUs
title: '[FEATURE] Check image compatibility when selecting VM SKUs'
labels: enhancement, v1.3.0
assignees: ''
---

## Feature Description

Check whether a specific VM image (marketplace image, custom image, or gallery image) is compatible with selected VM SKUs.

## Background

**Requested by:** Zach
**Use Case:** Not all VM images work with all SKUs. Users waste time deploying VMs only to discover the image isn't supported (e.g., Gen1 image on Gen2-only SKU, ARM64 images on x64 SKUs).

## Proposed Solution

### New Parameters
```powershell
-ImageURN <string>         # Image URN to check compatibility
-VMGeneration <string>     # Filter by VM generation: Gen1, Gen2, Both
-Architecture <string>     # Filter by architecture: x64, ARM64, Both
```

**Examples:**
```powershell
# Check if Ubuntu 22.04 works with D-series in eastus
.\Azure-VM-Capacity-Checker.ps1 `
    -Region "eastus" `
    -FamilyFilter "D" `
    -ImageURN "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest"

# Filter to Gen2-only SKUs
.\Azure-VM-Capacity-Checker.ps1 -VMGeneration Gen2 -Region "eastus","westus2"

# Check custom image compatibility
.\Azure-VM-Capacity-Checker.ps1 `
    -ImageURN "/subscriptions/.../resourceGroups/.../providers/Microsoft.Compute/images/myImage"
```

### Output Format

**Console output:**
```
======================================================================
IMAGE COMPATIBILITY CHECK
======================================================================
Image: Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest
Architecture: x64
VM Generation: Gen2
OS Type: Linux

Compatible SKUs in eastus:
  ✓ Standard_D2s_v5 (Gen2, x64)
  ✓ Standard_D4s_v5 (Gen2, x64)
  ✗ Standard_D2s_v3 (Gen1 only - INCOMPATIBLE)
  ✗ Standard_D2ps_v5 (ARM64 - INCOMPATIBLE)

Summary: 12 of 15 SKUs are compatible
```

**Excel export:**
- Add column: `ImageCompatible` (Yes/No/Unknown)
- Add column: `CompatibilityReason` (e.g., "Gen2 required", "ARM64 not supported")
- Conditional formatting: Red highlight for incompatible SKUs

### Technical Implementation

#### Get Image Information
```powershell
function Get-VMImageInfo {
    param([string]$ImageURN)

    # Parse URN: Publisher:Offer:SKU:Version
    if ($ImageURN -match '^([^:]+):([^:]+):([^:]+):([^:]+)$') {
        $pub, $offer, $sku, $ver = $matches[1..4]

        $image = Get-AzVMImage `
            -Location $Region `
            -PublisherName $pub `
            -Offer $offer `
            -Skus $sku `
            -Version $ver

        return @{
            HyperVGeneration = $image.HyperVGeneration  # V1, V2
            Architecture = $image.Architecture          # x64, Arm64
            OSType = $image.OSDiskImage.OperatingSystem
        }
    }
}
```

#### Check SKU Compatibility
```powershell
function Test-SKUImageCompatibility {
    param($SkuObj, $ImageInfo)

    # Check HyperVGeneration capability
    $skuGen = Get-CapValue $SkuObj 'HyperVGenerations'  # "V1,V2" or "V2"

    if ($ImageInfo.HyperVGeneration -eq 'V2' -and $skuGen -notmatch 'V2') {
        return @{ Compatible = $false; Reason = "SKU only supports Gen1, image requires Gen2" }
    }

    # Check Architecture
    $skuArch = Get-CapValue $SkuObj 'CpuArchitectureType'  # x64, Arm64
    if ($ImageInfo.Architecture -ne $skuArch) {
        return @{ Compatible = $false; Reason = "Architecture mismatch: SKU=$skuArch, Image=$($ImageInfo.Architecture)" }
    }

    return @{ Compatible = $true; Reason = "Compatible" }
}
```

### Display Enhancements
- Add "Gen" column to SKU tables (Gen1, Gen2, Both)
- Add "Arch" column (x64, ARM64)
- Filter incompatible SKUs out of results (or show with warning)

## Acceptance Criteria
- [ ] `-ImageURN` parameter implemented
- [ ] Support for marketplace images (URN format)
- [ ] Support for custom images (resource ID format)
- [ ] VM generation filtering (`-VMGeneration`)
- [ ] Architecture filtering (`-Architecture`)
- [ ] Compatibility check displayed in console output
- [ ] Compatibility columns in Excel export
- [ ] Graceful error handling for invalid image URNs
- [ ] Documentation with examples

## Edge Cases
- Image not found in specified region
- Custom image from different subscription
- Azure Compute Gallery images
- Community gallery images
- Images with special requirements (NVMe, TrustedLaunch, etc.)

## Optional Enhancements
- [ ] Check for special features (Accelerated Networking, Ephemeral OS disk, etc.)
- [ ] Show recommended SKUs based on image requirements
- [ ] Validate image size fits on SKU's OS disk
- [ ] Check for TrustedLaunch / ConfidentialVM support

## Related Issues
- #[TBD] - Add SKU filtering (v1.2.0)

## References
- [Get-AzVMImage](https://learn.microsoft.com/en-us/powershell/module/az.compute/get-azvmimage)
- [VM Generation 2 Support](https://learn.microsoft.com/en-us/azure/virtual-machines/generation-2)
- [ARM64 VMs](https://learn.microsoft.com/en-us/azure/virtual-machines/dpsv5-dpdsv5-series)
