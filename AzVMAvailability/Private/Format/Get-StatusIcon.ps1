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
