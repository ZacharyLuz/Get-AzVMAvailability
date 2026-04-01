function ConvertFrom-RestQuota {
    <#
    .SYNOPSIS
        Normalizes a REST API quota response object to match the Get-AzVMUsage cmdlet output shape.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    param([Parameter(Mandatory)][object]$RestQuota)
    return [pscustomobject]@{
        Name = [pscustomobject]@{
            Value          = $RestQuota.name.value
            LocalizedValue = $RestQuota.name.localizedValue
        }
        CurrentValue = $RestQuota.currentValue
        Limit        = $RestQuota.limit
    }
}
