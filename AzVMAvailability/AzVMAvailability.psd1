@{
    RootModule        = 'AzVMAvailability.psm1'
    ModuleVersion     = '1.12.3'
    GUID              = 'a7f3b2c1-4d5e-6f78-9a0b-1c2d3e4f5a6b'
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
        # Azure API
        'Get-AzureEndpoints'
        'Get-AzVMPricing'
        'Get-AzActualPricing'
        'Get-PlacementScores'
        'Get-ValidAzureRegions'
        'Invoke-WithRetry'
        # SKU analysis
        'Get-CapValue'
        'Get-SkuFamily'
        'Get-ProcessorVendor'
        'Get-DiskCode'
        'Get-SkuCapabilities'
        'Get-SkuSimilarityScore'
        'Get-RestrictionReason'
        'Get-RestrictionDetails'
        'Test-SkuMatchesFilter'
        # Image
        'Get-ImageRequirements'
        'Test-ImageSkuCompatibility'
        # Fleet
        'Get-FleetReadiness'
        'Write-FleetReadinessSummary'
        # Format / Output
        'Get-StatusIcon'
        'Format-ZoneStatus'
        'Format-RegionList'
        'New-RecommendOutputContract'
        'Write-RecommendOutputContract'
        'New-ScanOutputContract'
        'Invoke-RecommendMode'
        # Utility
        'Get-SafeString'
        'Get-GeoGroup'
        'Get-QuotaAvailable'
        'Use-SubscriptionContextSafely'
        'Restore-OriginalSubscriptionContext'
        'Test-ImportExcelModule'
        'Get-RegularPricingMap'
        'Get-SpotPricingMap'
    )
    CmdletsToExport   = @()
    VariablesToExport  = @()
    AliasesToExport    = @()
    PrivateData       = @{
        PSData = @{
            Tags         = @('Azure', 'VM', 'SKU', 'Capacity', 'Availability', 'Quota', 'Pricing')
            LicenseUri   = 'https://github.com/zacharyluz/Get-AzVMAvailability/blob/main/LICENSE'
            ProjectUri   = 'https://github.com/zacharyluz/Get-AzVMAvailability'
            ReleaseNotes = 'Module scaffold — extracted 34 functions into Private/ layout. Not yet published to PSGallery.'
        }
    }
}
