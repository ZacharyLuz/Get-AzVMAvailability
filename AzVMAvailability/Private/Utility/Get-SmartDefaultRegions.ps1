function Get-SmartDefaultRegions {
    <#
    .SYNOPSIS
        Returns context-aware default regions based on cloud environment and user timezone.
    .DESCRIPTION
        Cloud environment takes priority: Gov/China tenants get their sovereign regions.
        For commercial cloud, the local timezone is used to pick the nearest geo.
    .OUTPUTS
        Hashtable with keys: Regions (string[]), Source (string)
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$CloudEnvironment
    )

    # Signal 1: Cloud environment (sovereign clouds always override timezone)
    if (-not $CloudEnvironment) {
        $CloudEnvironment = try { (Get-AzContext).Environment.Name } catch { 'AzureCloud' }
    }

    switch ($CloudEnvironment) {
        'AzureUSGovernment' {
            return @{
                Regions = @('usgovvirginia', 'usgovtexas', 'usgovarizona')
                Source  = 'Cloud: AzureUSGovernment'
            }
        }
        'AzureChinaCloud' {
            return @{
                Regions = @('chinaeast', 'chinaeast2', 'chinanorth')
                Source  = 'Cloud: AzureChinaCloud'
            }
        }
    }

    # Signal 2: Local timezone -> geo hint (commercial cloud only)
    $utcOffset = [System.TimeZoneInfo]::Local.BaseUtcOffset.TotalHours

    if ($utcOffset -ge -10 -and $utcOffset -le -3) {
        $regions = @('eastus', 'eastus2', 'centralus')
        $geo = 'Americas'
    }
    elseif ($utcOffset -ge -2 -and $utcOffset -le 3) {
        $regions = @('westeurope', 'northeurope', 'uksouth')
        $geo = 'Europe'
    }
    elseif ($utcOffset -ge 3.5 -and $utcOffset -le 6) {
        $regions = @('centralindia', 'uaenorth', 'westindia')
        $geo = 'India/MiddleEast'
    }
    elseif ($utcOffset -ge 7 -and $utcOffset -le 9.5) {
        $regions = @('eastasia', 'southeastasia', 'japaneast')
        $geo = 'AsiaPacific'
    }
    elseif ($utcOffset -ge 10 -and $utcOffset -le 13) {
        $regions = @('australiaeast', 'australiasoutheast', 'eastasia')
        $geo = 'Australia'
    }
    else {
        $regions = @('eastus', 'eastus2', 'centralus')
        $geo = 'Fallback'
    }

    return @{
        Regions = $regions
        Source  = "Timezone: $([System.TimeZoneInfo]::Local.Id) (UTC$($utcOffset)) -> $geo"
    }
}
