# Get-SkuCapabilities.ps1
# Extracted from Get-AzVMAvailability.ps1 (line 2199)
# Extracts and returns a structured capabilities object for a VM SKU
# DO NOT execute this file directly — it is a documentation reference only.
function Get-SkuCapabilities {
    <#
    .SYNOPSIS
        Extracts VM capabilities from a SKU object for compatibility and fleet safety analysis.
    .DESCRIPTION
        Parses the SKU's Capabilities array to find HyperVGenerations, CpuArchitectureType,
        temp disk size, accelerated networking, and NVMe support.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [object]$Sku
    )

    $capabilities = @{
        HyperVGenerations            = 'V1'
        CpuArchitecture              = 'x64'
        TempDiskGB                   = 0
        AcceleratedNetworkingEnabled = $false
        NvmeSupport                  = $false
    }

    if ($Sku.Capabilities) {
        foreach ($cap in $Sku.Capabilities) {
            switch ($cap.Name) {
                'HyperVGenerations' { $capabilities.HyperVGenerations = $cap.Value }
                'CpuArchitectureType' { $capabilities.CpuArchitecture = $cap.Value }
                'MaxResourceVolumeMB' {
                    $MiBPerGiB = 1024
                    $mb = 0
                    if ([int]::TryParse($cap.Value, [ref]$mb) -and $mb -gt 0) {
                        $capabilities.TempDiskGB = [math]::Round($mb / $MiBPerGiB, 0)
                    }
                }
                'AcceleratedNetworkingEnabled' {
                    $capabilities.AcceleratedNetworkingEnabled = $cap.Value -eq 'True'
                }
                'NvmeDiskSizeInMiB' { $capabilities.NvmeSupport = $true }
            }
        }
    }

    return $capabilities
}
