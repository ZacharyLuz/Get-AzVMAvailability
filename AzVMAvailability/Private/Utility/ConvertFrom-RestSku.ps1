function ConvertFrom-RestSku {
    <#
    .SYNOPSIS
        Normalizes a REST API SKU response object to match the Get-AzComputeResourceSku cmdlet output shape.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param([Parameter(Mandatory)][object]$RestSku)

    $locInfo = if ($RestSku.locationInfo) {
        foreach ($li in $RestSku.locationInfo) {
            [pscustomobject]@{ Location = $li.location; Zones = @($li.zones) }
        }
    } else { @() }

    $restrictions = if ($RestSku.restrictions) {
        foreach ($r in $RestSku.restrictions) {
            [pscustomobject]@{
                Type            = $r.type
                ReasonCode      = $r.reasonCode
                RestrictionInfo = if ($r.restrictionInfo) {
                    [pscustomobject]@{ Zones = @($r.restrictionInfo.zones); Locations = @($r.restrictionInfo.locations) }
                } else { $null }
            }
        }
    } else { @() }

    $caps = if ($RestSku.capabilities) {
        foreach ($c in $RestSku.capabilities) {
            [pscustomobject]@{ Name = $c.name; Value = $c.value }
        }
    } else { @() }

    $capIndex = @{}
    foreach ($c in $caps) { $capIndex[$c.Name] = $c.Value }

    return [pscustomobject]@{
        Name         = $RestSku.name
        ResourceType = $RestSku.resourceType
        Family       = $RestSku.family
        LocationInfo = @($locInfo)
        Restrictions = @($restrictions)
        Capabilities = @($caps)
        _CapIndex    = $capIndex
    }
}
