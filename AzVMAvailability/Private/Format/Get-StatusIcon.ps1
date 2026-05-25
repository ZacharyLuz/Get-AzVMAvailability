function Get-StatusIcon {
    param(
        [string]$Status,
        [Parameter(Mandatory)]
        [hashtable]$Icons
    )
    switch ($Status) {
        'OK' { return $Icons.OK }
        'ZONE-LIMITED' { return $Icons.ZONE_LIMITED }
        'LIMITED' { return $Icons.LIMITED }
        'PARTIAL' { return $Icons.PARTIAL }
        'RESTRICTED' { return $Icons.BLOCKED }
        default { return $Icons.UNKNOWN }
    }
}
