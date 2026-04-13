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
        try {
            $CloudEnvironment = (Get-AzContext).Environment.Name
        }
        catch {
            Write-Verbose "Get-SmartDefaultRegions: Get-AzContext failed, falling back to AzureCloud. Error: $($_.Exception.Message)"
            $CloudEnvironment = 'AzureCloud'
        }
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
    # BaseUtcOffset is intentional — it excludes DST so region selection stays stable year-round
    $utcOffset = [System.TimeZoneInfo]::Local.BaseUtcOffset.TotalHours

    if ($utcOffset -ge -10 -and $utcOffset -lt -2) {
        $regions = @('eastus', 'eastus2', 'centralus')
        $geo = 'Americas'
    }
    elseif ($utcOffset -ge -2 -and $utcOffset -lt 3.5) {
        $regions = @('westeurope', 'northeurope', 'uksouth')
        $geo = 'Europe'
    }
    elseif ($utcOffset -ge 3.5 -and $utcOffset -lt 7) {
        $regions = @('centralindia', 'uaenorth', 'westindia')
        $geo = 'India/MiddleEast'
    }
    elseif ($utcOffset -ge 7 -and $utcOffset -lt 10) {
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

    # Format offset as UTC+05:30 / UTC-04:00
    $offsetSign = if ($utcOffset -ge 0) { '+' } else { '-' }
    $absOffset = [Math]::Abs($utcOffset)
    $offsetHours = [Math]::Floor($absOffset)
    $offsetMinutes = ($absOffset - $offsetHours) * 60
    $formattedOffset = '{0}{1:D2}:{2:D2}' -f $offsetSign, [int]$offsetHours, [int]$offsetMinutes

    return @{
        Regions = $regions
        Source  = "Timezone: $([System.TimeZoneInfo]::Local.Id) (UTC$formattedOffset) -> $geo"
    }
}
