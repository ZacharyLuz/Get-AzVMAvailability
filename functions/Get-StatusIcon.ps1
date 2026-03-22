# Get-StatusIcon.ps1
# Extracted from Get-AzVMAvailability.ps1 (line 1370)
# Returns a Unicode or ASCII status icon character for a given status
# DO NOT execute this file directly — it is a documentation reference only.
function Get-StatusIcon {
    param(
        [string]$Status,
        [Parameter(Mandatory)]
        [hashtable]$Icons
    )
    switch ($Status) {
        'OK' { return $Icons.OK }
        'CAPACITY-CONSTRAINED' { return $Icons.CAPACITY }
        'LIMITED' { return $Icons.LIMITED }
        'PARTIAL' { return $Icons.PARTIAL }
        'RESTRICTED' { return $Icons.BLOCKED }
        default { return $Icons.UNKNOWN }
    }
}
