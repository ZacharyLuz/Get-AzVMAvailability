function Get-SkuRetirementInfo {
    param([string]$SkuName)

    # Azure VM series retirement data from official Microsoft announcements
    # https://learn.microsoft.com/en-us/azure/virtual-machines/sizes/retirement/retired-sizes-list
    # Last verified: 2026-03-27
    $retirementLookup = @(
        # Already retired
        @{ Pattern = '^Standard_H\d+[a-z]*$';          Series = 'H';    RetireDate = '2024-09-28'; Status = 'Retired' }
        @{ Pattern = '^Standard_HB60rs$';              Series = 'HBv1'; RetireDate = '2024-09-28'; Status = 'Retired' }
        @{ Pattern = '^Standard_HC44rs$';              Series = 'HC';   RetireDate = '2024-09-28'; Status = 'Retired' }
        @{ Pattern = '^Standard_NC\d+r?$';             Series = 'NCv1'; RetireDate = '2023-09-06'; Status = 'Retired' }
        @{ Pattern = '^Standard_NC\d+r?s_v2$';         Series = 'NCv2'; RetireDate = '2023-09-06'; Status = 'Retired' }
        @{ Pattern = '^Standard_NC\d+r?s_v3$';         Series = 'NCv3'; RetireDate = '2025-09-30'; Status = 'Retired' }
        @{ Pattern = '^Standard_ND\d+r?s$';            Series = 'NDv1'; RetireDate = '2023-09-06'; Status = 'Retired' }
        @{ Pattern = '^Standard_NV\d+$';               Series = 'NVv1'; RetireDate = '2023-09-06'; Status = 'Retired' }
        # Scheduled for retirement (announced, planned retirement date)
        @{ Pattern = '^Standard_DS?\d+$';              Series = 'Dv1';  RetireDate = '2028-05-01'; Status = 'Retiring' }
        @{ Pattern = '^Standard_DS?\d+_v2(_Promo)?$';  Series = 'Dv2';  RetireDate = '2028-05-01'; Status = 'Retiring' }
        @{ Pattern = '^(Basic_A\d+|Standard_A\d+)$';  Series = 'Av1';  RetireDate = '2028-11-15'; Status = 'Retiring' }
        @{ Pattern = '^Standard_B\d+[a-z]*$';          Series = 'Bv1';  RetireDate = '2028-11-15'; Status = 'Retiring' }
        @{ Pattern = '^Standard_GS?\d+$';              Series = 'G/GS'; RetireDate = '2028-11-15'; Status = 'Retiring' }
        @{ Pattern = '^Standard_F\d+s?$';              Series = 'Fsv1'; RetireDate = '2028-11-15'; Status = 'Retiring' }
        @{ Pattern = '^Standard_L\d+s$';               Series = 'Lsv1'; RetireDate = '2028-05-01'; Status = 'Retiring' }
        @{ Pattern = '^Standard_L\d+s_v2$';            Series = 'Lsv2'; RetireDate = '2028-11-15'; Status = 'Retiring' }
        @{ Pattern = '^Standard_ND\d+r?s_v2$';         Series = 'NDv2'; RetireDate = '2025-09-30'; Status = 'Retiring' }
        @{ Pattern = '^Standard_NV\d+s_v3$';           Series = 'NVv3'; RetireDate = '2026-09-30'; Status = 'Retiring' }
        @{ Pattern = '^Standard_M\d+(-\d+)?[a-z]*$';   Series = 'Mv1';  RetireDate = '2027-08-31'; Status = 'Retiring' }
    )

    foreach ($entry in $retirementLookup) {
        if ($SkuName -match $entry.Pattern) {
            return $entry
        }
    }
    return $null
}
