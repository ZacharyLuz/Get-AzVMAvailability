# Mock functions declare parameters to match real cmdlet signatures but don't reference them
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Mock function parameters match real cmdlet signatures for Pester overrides')]
param()

BeforeAll {
    Import-Module "$PSScriptRoot\TestHarness.psm1" -Force
    . ([scriptblock]::Create((Get-MainScriptFunctionDefinition -FunctionName 'New-RecommendOutputContract')))
    . ([scriptblock]::Create((Get-MainScriptFunctionDefinition -FunctionName 'Get-RegularPricingMap')))
    . ([scriptblock]::Create((Get-MainScriptFunctionDefinition -FunctionName 'Get-SpotPricingMap')))
    . ([scriptblock]::Create((Get-MainScriptFunctionDefinition -FunctionName 'Invoke-RecommendMode')))

    function Get-SafeString { param($Value) [string]$Value }

    function Get-RestrictionDetails {
        param($Sku)
        $status = if ($Sku.Name -eq 'Standard_D4s_v5') { 'CAPACITY-CONSTRAINED' } else { 'OK' }
        @{ Status = $status; ZonesOK = @(1, 2); Reason = $null }
    }

    function Get-SkuCapabilities {
        param($Sku)
        $skuName = [string]$Sku.Name
        $arch = if ($skuName -match 'p') { 'Arm64' } else { 'x64' }
        [pscustomobject]@{
            HyperVGenerations            = 'V2'
            CpuArchitecture              = $arch
            TempDiskGB                   = if ($skuName -match 'd') { 75 } else { 0 }
            NvmeSupport                  = ($skuName -match 'n')
            AcceleratedNetworkingEnabled = ($skuName -notmatch 'legacy')
            MaxDataDiskCount             = 16
            MaxNetworkInterfaces         = 4
            EphemeralOSDiskSupported     = $false
            UltraSSDAvailable            = $false
            UncachedDiskIOPS             = 12800
            UncachedDiskBytesPerSecond   = 134217728
            EncryptionAtHostSupported    = $false
            TrustedLaunchDisabled        = $false
        }
    }

    function Test-SkuCompatibility {
        param([hashtable]$Target, [hashtable]$Candidate)
        @{ Compatible = $true; Failures = @() }
    }

    function Get-ProcessorVendor {
        param([string]$SkuName)
        if ($SkuName -match 'p') { return 'ARM' }
        if ($SkuName -match 'a') { return 'AMD' }
        return 'Intel'
    }

    function Get-DiskCode {
        param([bool]$HasTempDisk, [bool]$HasNvme)
        if ($HasNvme -and $HasTempDisk) { return 'NV+T' }
        if ($HasNvme) { return 'NVMe' }
        if ($HasTempDisk) { return 'SC+T' }
        return 'SCSI'
    }

    function Get-CapValue {
        param($Sku, [string]$Name)
        $map = @{
            'Standard_D4s_v5'  = @{ vCPUs = '4'; MemoryGB = '16'; PremiumIO = 'True' }
            'Standard_D8s_v5'  = @{ vCPUs = '8'; MemoryGB = '32'; PremiumIO = 'True' }
            'Standard_D8ps_v6' = @{ vCPUs = '8'; MemoryGB = '32'; PremiumIO = 'True' }
            'Standard_E8s_v5'  = @{ vCPUs = '8'; MemoryGB = '64'; PremiumIO = 'True' }
        }
        return $map[$Sku.Name][$Name]
    }

    function Get-SkuFamily {
        param([string]$SkuName)
        if ($SkuName -match '^Standard_([A-Za-z]+)') {
            return $matches[1].Substring(0, 1).ToUpper()
        }
        return 'Unknown'
    }

    function Get-SkuSimilarityScore {
        param([hashtable]$Target, [hashtable]$Candidate, [hashtable]$FamilyInfo)
        $score = 100
        if ($Target.Architecture -ne $Candidate.Architecture) { $score -= 12 }
        if ($Target.vCPU -ne $Candidate.vCPU) { $score -= 8 }
        if ($Target.MemoryGB -ne $Candidate.MemoryGB) { $score -= 8 }
        return [Math]::Max(0, $score)
    }

    function Get-PlacementScores {
        param([string[]]$SkuNames, [string[]]$Regions, [int]$DesiredCount, [int]$MaxRetries, [System.Collections.IDictionary]$Caches)
        $scores = @{}
        foreach ($sku in $SkuNames) {
            foreach ($region in $Regions) {
                $scores["$sku|$($region.ToLower())"] = [pscustomobject]@{ Score = 'High' }
            }
        }
        return $scores
    }

    $script:FamilyInfo = @{
        D = @{ Purpose = 'General purpose'; Category = 'General' }
        E = @{ Purpose = 'Memory optimized'; Category = 'Memory' }
    }

    $script:Icons = @{
        Check   = '[+]'
        Error   = '[-]'
        Warning = '[!]'
    }

    $script:OutputWidth = 122
}

Describe 'Invoke-RecommendMode JSON contract' {
    BeforeEach {
        $script:TestRunContext = [pscustomobject]@{
            RegionPricing   = @{}
            RecommendOutput = $null
            Caches          = [ordered]@{ PlacementWarned403 = $false }
        }

        $script:RecommendParams = @{
            FamilyInfo    = $script:FamilyInfo
            Icons         = $script:Icons
            FetchPricing  = $false
            ShowSpot      = $false
            ShowPlacement = $false
            AllowMixedArch = $false
            MinvCPU       = 0
            MinMemoryGB   = 0
            MinScore      = 0
            TopN          = 5
            DesiredCount  = 1
            JsonOutput    = $true
            MaxRetries    = 0
            RunContext    = $script:TestRunContext
            OutputWidth   = 122
        }
    }

    It 'Emits JSON with required top-level and recommendation fields' {
        $subscriptionData = @(
            [pscustomobject]@{
                SubscriptionId = 'sub-1'
                RegionData     = @(
                    [pscustomobject]@{
                        Region = 'eastus'
                        Error  = $null
                        Skus   = @(
                            [pscustomobject]@{ Name = 'Standard_D4s_v5' }
                            [pscustomobject]@{ Name = 'Standard_D8s_v5' }
                            [pscustomobject]@{ Name = 'Standard_E8s_v5' }
                        )
                    }
                )
            }
        )

        $result = (Invoke-RecommendMode -TargetSkuName 'Standard_D4s_v5' -SubscriptionData $subscriptionData @script:RecommendParams) | ConvertFrom-Json

        $result.target | Should -Not -BeNullOrEmpty
        $result.placementEnabled | Should -BeFalse
        $result.spotPricingEnabled | Should -BeFalse
        $result.targetAvailability | Should -Not -BeNullOrEmpty
        $result.recommendations.Count | Should -BeGreaterThan 0
        $result.PSObject.Properties.Name | Should -Contain 'warnings'

        $first = $result.recommendations[0]
        $first.rank | Should -Be 1
        $first.sku | Should -Not -BeNullOrEmpty
        $first.cpu | Should -Not -BeNullOrEmpty
        $first.disk | Should -Not -BeNullOrEmpty
        $first.tempDiskGB | Should -Not -BeNull
        $first.accelNet | Should -Not -BeNull
        $first.score | Should -Not -BeNull
        $first.PSObject.Properties.Name | Should -Contain 'spotPriceHr'
        $first.PSObject.Properties.Name | Should -Contain 'spotPriceMo'
    }

    It 'Returns empty recommendations contract when no candidates meet MinScore' {
        $script:RecommendParams.MinScore = 101

        $subscriptionData = @(
            [pscustomobject]@{
                SubscriptionId = 'sub-1'
                RegionData     = @(
                    [pscustomobject]@{
                        Region = 'eastus'
                        Error  = $null
                        Skus   = @(
                            [pscustomobject]@{ Name = 'Standard_D4s_v5' }
                            [pscustomobject]@{ Name = 'Standard_D8s_v5' }
                        )
                    }
                )
            }
        )

        $result = (Invoke-RecommendMode -TargetSkuName 'Standard_D4s_v5' -SubscriptionData $subscriptionData @script:RecommendParams) | ConvertFrom-Json

        $result.minScore | Should -Be 101
        $result.recommendations.Count | Should -Be 0
        $result.warnings.Count | Should -Be 0
    }

    It 'Filters mixed architectures by default when AllowMixedArch is false' {
        $subscriptionData = @(
            [pscustomobject]@{
                SubscriptionId = 'sub-1'
                RegionData     = @(
                    [pscustomobject]@{
                        Region = 'eastus'
                        Error  = $null
                        Skus   = @(
                            [pscustomobject]@{ Name = 'Standard_D4s_v5' }
                            [pscustomobject]@{ Name = 'Standard_D8s_v5' }
                            [pscustomobject]@{ Name = 'Standard_D8ps_v6' }
                        )
                    }
                )
            }
        )

        $result = (Invoke-RecommendMode -TargetSkuName 'Standard_D4s_v5' -SubscriptionData $subscriptionData @script:RecommendParams) | ConvertFrom-Json

        @($result.recommendations.sku) | Should -Contain 'Standard_D8s_v5'
        @($result.recommendations.sku) | Should -Not -Contain 'Standard_D8ps_v6'
    }

    It 'Includes mixed-architecture warning when AllowMixedArch is true' {
        $script:RecommendParams.AllowMixedArch = $true

        $subscriptionData = @(
            [pscustomobject]@{
                SubscriptionId = 'sub-1'
                RegionData     = @(
                    [pscustomobject]@{
                        Region = 'eastus'
                        Error  = $null
                        Skus   = @(
                            [pscustomobject]@{ Name = 'Standard_D4s_v5' }
                            [pscustomobject]@{ Name = 'Standard_D8s_v5' }
                            [pscustomobject]@{ Name = 'Standard_D8ps_v6' }
                        )
                    }
                )
            }
        )

        $result = (Invoke-RecommendMode -TargetSkuName 'Standard_D4s_v5' -SubscriptionData $subscriptionData @script:RecommendParams) | ConvertFrom-Json

        @($result.recommendations.sku) | Should -Contain 'Standard_D8s_v5'
        @($result.recommendations.sku) | Should -Contain 'Standard_D8ps_v6'
        @($result.warnings) -join ' ' | Should -Match 'Mixed architectures'
    }

    It 'Adds allocation score when ShowPlacement is enabled' {
        $script:RecommendParams.ShowPlacement = $true

        $subscriptionData = @(
            [pscustomobject]@{
                SubscriptionId = 'sub-1'
                RegionData     = @(
                    [pscustomobject]@{
                        Region = 'eastus'
                        Error  = $null
                        Skus   = @(
                            [pscustomobject]@{ Name = 'Standard_D4s_v5' }
                            [pscustomobject]@{ Name = 'Standard_D8s_v5' }
                        )
                    }
                )
            }
        )

        $result = (Invoke-RecommendMode -TargetSkuName 'Standard_D4s_v5' -SubscriptionData $subscriptionData @script:RecommendParams) | ConvertFrom-Json

        $result.placementEnabled | Should -BeTrue
        $result.recommendations.Count | Should -BeGreaterThan 0
        $result.recommendations[0].PSObject.Properties.Name | Should -Contain 'allocScore'
        $result.recommendations[0].allocScore | Should -Be 'High'
    }

    It 'Sets spot pricing fields when ShowSpot and FetchPricing are enabled' {
        $script:RecommendParams.ShowSpot = $true
        $script:RecommendParams.FetchPricing = $true
        $script:TestRunContext.RegionPricing = @{
            eastus = @{
                Regular = @{
                    'Standard_D4s_v5' = @{ Hourly = 0.2; Monthly = 146 }
                    'Standard_D8s_v5' = @{ Hourly = 0.4; Monthly = 292 }
                }
                Spot = @{
                    'Standard_D8s_v5' = @{ Hourly = 0.1; Monthly = 73 }
                }
            }
        }

        $subscriptionData = @(
            [pscustomobject]@{
                SubscriptionId = 'sub-1'
                RegionData     = @(
                    [pscustomobject]@{
                        Region = 'eastus'
                        Error  = $null
                        Skus   = @(
                            [pscustomobject]@{ Name = 'Standard_D4s_v5' }
                            [pscustomobject]@{ Name = 'Standard_D8s_v5' }
                        )
                    }
                )
            }
        )

        $result = (Invoke-RecommendMode -TargetSkuName 'Standard_D4s_v5' -SubscriptionData $subscriptionData @script:RecommendParams) | ConvertFrom-Json
        $recommendation = @($result.recommendations | Where-Object { $_.sku -eq 'Standard_D8s_v5' })[0]

        $result.spotPricingEnabled | Should -BeTrue
        $recommendation.spotPriceHr | Should -Be 0.1
        $recommendation.spotPriceMo | Should -Be 73
    }
}
