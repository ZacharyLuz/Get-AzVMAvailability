# Get-DiskCode.ps1
# Extracted from Get-AzVMAvailability.ps1 (line 901)
# Returns the disk type code (P/E/S) from a VM SKU name
# DO NOT execute this file directly — it is a documentation reference only.
function Get-DiskCode {
    param(
        [bool]$HasTempDisk,
        [bool]$HasNvme
    )
    if ($HasNvme -and $HasTempDisk) { return 'NV+T' }
    if ($HasNvme) { return 'NVMe' }
    if ($HasTempDisk) { return 'SC+T' }
    return 'SCSI'
}
