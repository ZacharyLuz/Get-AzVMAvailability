@{
    RootModule        = 'AzVMAvailability.psm1'
    ModuleVersion     = '3.0.0'
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
            ReleaseNotes = 'v3.0.0: Breaking: Capacity field renamed to RestrictionStatus, CAPACITY-CONSTRAINED status renamed to ZONE-LIMITED, schemaVersion bumped to 2.0. All user-facing text clarified to reference ARM restriction metadata instead of capacity.'
        }
    }
}
