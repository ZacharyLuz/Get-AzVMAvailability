function Get-RestrictionDetails {
    <#
    .SYNOPSIS
        Analyzes SKU restrictions and returns detailed zone-level availability status.
    .DESCRIPTION
        Examines Azure SKU restrictions to determine:
        - Which zones are fully available (OK)
        - Which zones have capacity constraints (LIMITED)
        - Which zones are completely restricted (RESTRICTED)
        Returns a hashtable with status and zone breakdowns.
    #>
    param([object]$Sku)

    # If no restrictions, SKU is fully available in all zones
    if (-not $Sku -or -not $Sku.Restrictions -or $Sku.Restrictions.Count -eq 0) {
        $zones = if ($Sku -and $Sku.LocationInfo -and $Sku.LocationInfo[0].Zones) {
            $Sku.LocationInfo[0].Zones
        }
        else { @() }
        return @{
            Status             = 'OK'
            ZonesOK            = @($zones)
            ZonesLimited       = @()
            ZonesRestricted    = @()
            RestrictionReasons = @()
        }
    }

    # Categorize zones based on restriction type
    $zonesOK = [System.Collections.Generic.List[string]]::new()
    $zonesLimited = [System.Collections.Generic.List[string]]::new()
    $zonesRestricted = [System.Collections.Generic.List[string]]::new()
    $reasonCodes = @()

    foreach ($r in $Sku.Restrictions) {
        $reasonCodes += $r.ReasonCode
        if ($r.Type -eq 'Zone' -and $r.RestrictionInfo -and $r.RestrictionInfo.Zones) {
            foreach ($zone in $r.RestrictionInfo.Zones) {
                if ($r.ReasonCode -eq 'NotAvailableForSubscription') {
                    if (-not $zonesLimited.Contains($zone)) { $zonesLimited.Add($zone) }
                }
                else {
                    if (-not $zonesRestricted.Contains($zone)) { $zonesRestricted.Add($zone) }
                }
            }
        }
    }

    if ($Sku.LocationInfo -and $Sku.LocationInfo[0].Zones) {
        foreach ($zone in $Sku.LocationInfo[0].Zones) {
            if (-not $zonesLimited.Contains($zone) -and -not $zonesRestricted.Contains($zone)) {
                if (-not $zonesOK.Contains($zone)) { $zonesOK.Add($zone) }
            }
        }
    }

    $status = if ($zonesRestricted.Count -gt 0) {
        if ($zonesOK.Count -eq 0) { 'RESTRICTED' } else { 'PARTIAL' }
    }
    elseif ($zonesLimited.Count -gt 0) {
        if ($zonesOK.Count -eq 0) { 'LIMITED' } else { 'CAPACITY-CONSTRAINED' }
    }
    else { 'OK' }

    return @{
        Status             = $status
        ZonesOK            = @($zonesOK | Sort-Object)
        ZonesLimited       = @($zonesLimited | Sort-Object)
        ZonesRestricted    = @($zonesRestricted | Sort-Object)
        RestrictionReasons = @($reasonCodes | Select-Object -Unique)
    }
}
