function Get-SkuCapabilities {
    <#
    .SYNOPSIS
        Extracts VM capabilities from a SKU object for compatibility and inventory analysis.
    .DESCRIPTION
        Parses the SKU's Capabilities array to find HyperVGenerations, CpuArchitectureType,
        temp disk size, accelerated networking, NVMe support, max data disks, max NICs,
        ephemeral OS disk support, Ultra SSD availability, uncached disk IOPS/throughput,
        encryption at host, and trusted launch status.
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
        MaxDataDiskCount             = 0
        MaxNetworkInterfaces         = 1
        EphemeralOSDiskSupported     = $false
        UltraSSDAvailable            = $false
        UncachedDiskIOPS             = 0
        UncachedDiskBytesPerSecond   = 0
        EncryptionAtHostSupported    = $false
        TrustedLaunchDisabled        = $false
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
                'MaxDataDiskCount' {
                    $val = 0
                    if ([int]::TryParse($cap.Value, [ref]$val)) { $capabilities.MaxDataDiskCount = $val }
                }
                'MaxNetworkInterfaces' {
                    $val = 0
                    if ([int]::TryParse($cap.Value, [ref]$val)) { $capabilities.MaxNetworkInterfaces = $val }
                }
                'EphemeralOSDiskSupported' {
                    $capabilities.EphemeralOSDiskSupported = $cap.Value -eq 'True'
                }
                'UltraSSDAvailable' {
                    $capabilities.UltraSSDAvailable = $cap.Value -eq 'True'
                }
                'UncachedDiskIOPS' {
                    $val = 0
                    if ([int]::TryParse($cap.Value, [ref]$val)) { $capabilities.UncachedDiskIOPS = $val }
                }
                'UncachedDiskBytesPerSecond' {
                    $val = 0
                    if ([long]::TryParse($cap.Value, [ref]$val)) { $capabilities.UncachedDiskBytesPerSecond = $val }
                }
                'EncryptionAtHostSupported' {
                    $capabilities.EncryptionAtHostSupported = $cap.Value -eq 'True'
                }
                'TrustedLaunchDisabled' {
                    $capabilities.TrustedLaunchDisabled = $cap.Value -eq 'True'
                }
            }
        }
    }

    return $capabilities
}
