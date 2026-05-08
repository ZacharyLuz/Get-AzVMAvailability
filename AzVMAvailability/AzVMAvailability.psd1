@{
    RootModule        = 'AzVMAvailability.psm1'
    ModuleVersion     = '2.2.2'
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
            ReleaseNotes = 'v2.2.2: PSGallery package parity — release publishing now stages the runtime UpgradePath data, README, LICENSE, CHANGELOG, examples, and curated docs into the module package before publishing, so PSGallery installs ship the same assets as repo-based usage. A package-layout Pester test guards those assets. Also: version-bump workflow now updates all eight version stamps; release-publish gate logs non-blocking PSScriptAnalyzer diagnostics but only blocks on errors; release-publish.yml supports manual workflow_dispatch retry against an existing tag. See CHANGELOG.md.'
        }
    }
}
