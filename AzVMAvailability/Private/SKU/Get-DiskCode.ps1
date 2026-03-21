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
