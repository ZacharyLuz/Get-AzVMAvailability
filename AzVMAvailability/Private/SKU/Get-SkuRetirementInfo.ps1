function Get-SkuRetirementInfo {
    param([string]$SkuName)

    # Azure VM series retirement data from official Microsoft announcements
    # https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/retirement
    $retirementLookup = @(
        # Already retired
        @{ Pattern = '^(Basic_A\d+|Standard_A\d+)$';  Series = 'Av1';  RetireDate = '2024-08-31'; Status = 'Retired' }
        @{ Pattern = '^Standard_DS?\d+$';              Series = 'Dv1';  RetireDate = '2024-08-31'; Status = 'Retired' }
        @{ Pattern = '^Standard_GS?\d+$';              Series = 'G/GS'; RetireDate = '2025-03-31'; Status = 'Retired' }
        @{ Pattern = '^Standard_H\d+[a-z]*$';          Series = 'H';    RetireDate = '2024-09-28'; Status = 'Retired' }
        @{ Pattern = '^Standard_HB60rs$';              Series = 'HBv1'; RetireDate = '2024-09-28'; Status = 'Retired' }
        @{ Pattern = '^Standard_HC44rs$';              Series = 'HC';   RetireDate = '2024-09-28'; Status = 'Retired' }
        @{ Pattern = '^Standard_NC\d+r?$';             Series = 'NCv1'; RetireDate = '2023-09-06'; Status = 'Retired' }
        @{ Pattern = '^Standard_NC\d+r?s_v2$';         Series = 'NCv2'; RetireDate = '2023-09-06'; Status = 'Retired' }
        @{ Pattern = '^Standard_ND\d+r?s$';            Series = 'NDv1'; RetireDate = '2023-09-06'; Status = 'Retired' }
        @{ Pattern = '^Standard_NV\d+$';               Series = 'NVv1'; RetireDate = '2023-09-06'; Status = 'Retired' }
        @{ Pattern = '^Standard_L\d+s$';               Series = 'Lsv1'; RetireDate = '2024-08-31'; Status = 'Retired' }
        # Scheduled for retirement
        @{ Pattern = '^Standard_DS?\d+_v2(_Promo)?$';  Series = 'Dv2';  RetireDate = '2027-03-31'; Status = 'Retiring' }
        @{ Pattern = '^Standard_D\d+s?_v3$';           Series = 'Dv3';  RetireDate = '2027-09-30'; Status = 'Retiring' }
        @{ Pattern = '^Standard_E\d+i?s?_v3$';         Series = 'Ev3';  RetireDate = '2027-09-30'; Status = 'Retiring' }
        @{ Pattern = '^Standard_F\d+s$';               Series = 'Fsv1'; RetireDate = '2027-09-30'; Status = 'Retiring' }
        @{ Pattern = '^Standard_NC\d+r?s_v3$';         Series = 'NCv3'; RetireDate = '2025-09-30'; Status = 'Retiring' }
        @{ Pattern = '^Standard_ND\d+r?s_v2$';         Series = 'NDv2'; RetireDate = '2025-09-30'; Status = 'Retiring' }
        @{ Pattern = '^Standard_NV\d+s_v3$';           Series = 'NVv3'; RetireDate = '2025-09-30'; Status = 'Retiring' }
        @{ Pattern = '^Standard_M\d+(-\d+)?[a-z]*$';   Series = 'Mv1';  RetireDate = '2027-08-31'; Status = 'Retiring' }
    )

    foreach ($entry in $retirementLookup) {
        if ($SkuName -match $entry.Pattern) {
            return $entry
        }
    }
    return $null
}
