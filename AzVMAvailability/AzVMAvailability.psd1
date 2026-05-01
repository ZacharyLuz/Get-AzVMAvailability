@{
    RootModule        = 'AzVMAvailability.psm1'
    ModuleVersion     = '2.2.1'
    GUID              = '7f42e8d6-e85d-4e31-a541-d9af648a5269'
    Author            = 'Zachary Luz'
    CompanyName       = 'Community'
    Copyright         = '(c) Zachary Luz. All rights reserved. MIT License.'
    Description       = 'Scans Azure regions for VM SKU availability, capacity, quota, pricing, and image compatibility.'
    PowerShellVersion = '7.0'
    RequiredModules   = @(
        @{ ModuleName = 'Az.Accounts'; ModuleVersion = '2.0.0' }
        @{ ModuleName = 'Az.Compute'; ModuleVersion = '4.0.0' }
        @{ ModuleName = 'Az.Resources'; ModuleVersion = '4.0.0' }
    )
    FunctionsToExport = @(
        'Get-AzVMAvailability'
    )
    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('Azure', 'VM', 'SKU', 'Capacity', 'Availability', 'Quota', 'Pricing')
            LicenseUri   = 'https://github.com/zacharyluz/Get-AzVMAvailability/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/zacharyluz/Get-AzVMAvailability'
            ReleaseNotes = 'v2.2.1: Pricing correctness follow-up to v2.2.0 — Tier 2 Cost Management query now scoped by ResourceLocation (was attributing other regions'' usage rates to the queried region) and excludes Spot/Low-Priority rows from the negotiated PAYG map; negotiated Savings Plan maps are aliased from meterLocation to ARM region keys (commercial regions previously fell back to retail SP rates); Update-RetirementData.ps1 no longer stamps "Last verified" when new series are pending manual addition. See CHANGELOG.md.'
        }
    }
}
