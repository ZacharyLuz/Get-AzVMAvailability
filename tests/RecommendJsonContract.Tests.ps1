BeforeAll {
    Import-Module "$PSScriptRoot\TestHarness.psm1" -Force
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
        }
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
        param([hashtable]$Target, [hashtable]$Candidate)
        $score = 100
        if ($Target.Architecture -ne $Candidate.Architecture) { $score -= 12 }
        if ($Target.vCPU -ne $Candidate.vCPU) { $score -= 8 }
        if ($Target.MemoryGB -ne $Candidate.MemoryGB) { $score -= 8 }
        return [Math]::Max(0, $score)
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
        $script:AllowMixedArch = $false
        $script:FetchPricing = $false
        $script:MinvCPU = $null
        $script:MinMemoryGB = $null
        $script:MinScore = 0
        $script:TopN = 5
        $script:JsonOutput = $true
        $script:regionPricing = @{}
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

        $result = (Invoke-RecommendMode -TargetSkuName 'Standard_D4s_v5' -SubscriptionData $subscriptionData) | ConvertFrom-Json

        $result.target | Should -Not -BeNullOrEmpty
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
    }

    It 'Returns empty recommendations contract when no candidates meet MinScore' {
        $script:MinScore = 101

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

        $result = (Invoke-RecommendMode -TargetSkuName 'Standard_D4s_v5' -SubscriptionData $subscriptionData) | ConvertFrom-Json

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

        $result = (Invoke-RecommendMode -TargetSkuName 'Standard_D4s_v5' -SubscriptionData $subscriptionData) | ConvertFrom-Json

        @($result.recommendations.sku) | Should -Contain 'Standard_D8s_v5'
        @($result.recommendations.sku) | Should -Not -Contain 'Standard_D8ps_v6'
    }

    It 'Includes mixed-architecture warning when AllowMixedArch is true' {
        $script:AllowMixedArch = $true

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

        $result = (Invoke-RecommendMode -TargetSkuName 'Standard_D4s_v5' -SubscriptionData $subscriptionData) | ConvertFrom-Json

        @($result.recommendations.sku) | Should -Contain 'Standard_D8s_v5'
        @($result.recommendations.sku) | Should -Contain 'Standard_D8ps_v6'
        @($result.warnings) -join ' ' | Should -Match 'Mixed architectures'
    }
}
