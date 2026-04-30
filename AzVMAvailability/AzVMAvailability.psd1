@{
    RootModule        = 'AzVMAvailability.psm1'
    ModuleVersion     = '2.2.0'
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
            ReleaseNotes = 'v2.2.0: Sovereign pricing correctness (Spot meter exclusion, paired meter split, Gov meterLocation aliases, Expired suffix strip, retail-fallback marker), Reservation/SP savings as retail-vs-retail percent, advisory upgrade-path recs, AZ zone columns auto-enabled in lifecycle, Lifecycle Summary legend block, dedupe candidate pool (~100x), parallel cross-sub scan, mid-scan token refresh, live progress/ETA. See CHANGELOG.md.'
        }
    }
}
