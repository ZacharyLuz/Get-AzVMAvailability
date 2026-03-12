# HelperFunctions.Tests.ps1
# Pester tests for helper functions in Get-AzVMAvailability.ps1
# Run with: Invoke-Pester .\tests\HelperFunctions.Tests.ps1 -Output Detailed

BeforeAll {
    Import-Module "$PSScriptRoot\TestHarness.psm1" -Force
    $functionNames = @(
        'Get-CapValue',
        'Get-SkuFamily',
        'Get-RestrictionReason',
        'Get-RestrictionDetails',
        'Format-ZoneStatus',
        'Test-SkuMatchesFilter',
        'Get-SafeString',
        'Get-GeoGroup',
        'Get-QuotaAvailable',
        'Get-SkuCapabilities'
    )

    foreach ($functionName in $functionNames) {
        . ([scriptblock]::Create((Get-MainScriptFunctionDefinition -FunctionName $functionName)))
    }

    # Get-SkuCapabilities reads $MBPerGB from parent scope (known tech debt)
    $script:MBPerGB = 1024
}

Describe "Get-SafeString" {

    It "Returns empty string for null" {
        Get-SafeString -Value $null | Should -Be ''
    }

    It "Returns the string as-is for a plain string" {
        Get-SafeString -Value 'eastus' | Should -Be 'eastus'
    }

    It "Unwraps single-element array" {
        Get-SafeString -Value @('westus2') | Should -Be 'westus2'
    }

    It "Unwraps nested arrays" {
        Get-SafeString -Value @(@('centralus')) | Should -Be 'centralus'
    }

    It "Converts integer to string" {
        Get-SafeString -Value 42 | Should -Be '42'
    }
}

Describe "Get-CapValue" {

    BeforeAll {
        $mockSku = [PSCustomObject]@{
            Name         = 'Standard_D2s_v3'
            Capabilities = @(
                [PSCustomObject]@{ Name = 'vCPUs'; Value = '2' }
                [PSCustomObject]@{ Name = 'MemoryGB'; Value = '8' }
                [PSCustomObject]@{ Name = 'MaxDataDiskCount'; Value = '4' }
            )
        }
    }

    It "Returns vCPU value" {
        Get-CapValue -Sku $mockSku -Name 'vCPUs' | Should -Be '2'
    }

    It "Returns MemoryGB value" {
        Get-CapValue -Sku $mockSku -Name 'MemoryGB' | Should -Be '8'
    }

    It "Returns null for missing capability" {
        Get-CapValue -Sku $mockSku -Name 'GPUCount' | Should -BeNullOrEmpty
    }

    It "Returns null for SKU with no capabilities" {
        $emptySku = [PSCustomObject]@{ Name = 'Standard_B1s'; Capabilities = @() }
        Get-CapValue -Sku $emptySku -Name 'vCPUs' | Should -BeNullOrEmpty
    }
}

Describe "Get-SkuFamily" {

    It "Extracts D family from Standard_D2s_v3" {
        Get-SkuFamily -SkuName 'Standard_D2s_v3' | Should -Be 'D'
    }

    It "Extracts E family from Standard_E4as_v5" {
        Get-SkuFamily -SkuName 'Standard_E4as_v5' | Should -Be 'E'
    }

    It "Extracts NC family from Standard_NC6s_v3" {
        Get-SkuFamily -SkuName 'Standard_NC6s_v3' | Should -Be 'NC'
    }

    It "Extracts B family from Standard_B2ms" {
        Get-SkuFamily -SkuName 'Standard_B2ms' | Should -Be 'B'
    }

    It "Returns Unknown for non-standard name" {
        Get-SkuFamily -SkuName 'Custom_VM' | Should -Be 'Unknown'
    }
}

Describe "Get-RestrictionDetails" {

    Context "No restrictions" {
        It "Returns OK status with all zones available" {
            $mockSku = [PSCustomObject]@{
                Restrictions = @()
                LocationInfo = @(
                    [PSCustomObject]@{ Zones = @('1', '2', '3') }
                )
            }
            $result = Get-RestrictionDetails -Sku $mockSku
            $result.Status | Should -Be 'OK'
            $result.ZonesOK | Should -HaveCount 3
            $result.ZonesLimited | Should -HaveCount 0
            $result.ZonesRestricted | Should -HaveCount 0
        }

        It "Returns OK with empty zones for non-zonal SKU" {
            $mockSku = [PSCustomObject]@{
                Restrictions = @()
                LocationInfo = @(
                    [PSCustomObject]@{ Zones = @() }
                )
            }
            $result = Get-RestrictionDetails -Sku $mockSku
            $result.Status | Should -Be 'OK'
            $result.ZonesOK | Should -HaveCount 0
        }
    }

    Context "Zone-level restrictions" {
        It "Identifies limited zones from NotAvailableForSubscription" {
            $mockSku = [PSCustomObject]@{
                Restrictions = @(
                    [PSCustomObject]@{
                        Type            = 'Zone'
                        ReasonCode      = 'NotAvailableForSubscription'
                        RestrictionInfo = [PSCustomObject]@{ Zones = @('2') }
                    }
                )
                LocationInfo = @(
                    [PSCustomObject]@{ Zones = @('1', '2', '3') }
                )
            }
            $result = Get-RestrictionDetails -Sku $mockSku
            $result.ZonesLimited | Should -Contain '2'
            $result.ZonesOK | Should -Contain '1'
            $result.ZonesOK | Should -Contain '3'
        }

        It "Reports RESTRICTED when all zones are blocked" {
            $mockSku = [PSCustomObject]@{
                Restrictions = @(
                    [PSCustomObject]@{
                        Type            = 'Zone'
                        ReasonCode      = 'Quota'
                        RestrictionInfo = [PSCustomObject]@{ Zones = @('1', '2', '3') }
                    }
                )
                LocationInfo = @(
                    [PSCustomObject]@{ Zones = @('1', '2', '3') }
                )
            }
            $result = Get-RestrictionDetails -Sku $mockSku
            $result.Status | Should -Be 'RESTRICTED'
            $result.ZonesOK | Should -HaveCount 0
        }
    }

    Context "Null / empty input" {
        It "Returns OK for null SKU" {
            $result = Get-RestrictionDetails -Sku $null
            $result.Status | Should -Be 'OK'
        }
    }
}

Describe "Format-ZoneStatus" {

    It "Formats OK zones only" {
        $result = Format-ZoneStatus -OK @('1', '2') -Limited @() -Restricted @()
        $result | Should -Match '✓ Zones 1,2'
    }

    It "Formats limited zones only" {
        $result = Format-ZoneStatus -OK @() -Limited @('3') -Restricted @()
        $result | Should -Match '⚠ Zones 3'
    }

    It "Formats restricted zones only" {
        $result = Format-ZoneStatus -OK @() -Limited @() -Restricted @('1', '2')
        $result | Should -Match '✗ Zones 1,2'
    }

    It "Formats mixed zones with pipe separator" {
        $result = Format-ZoneStatus -OK @('1') -Limited @('2') -Restricted @('3')
        $result | Should -Match '✓ Zones 1'
        $result | Should -Match '⚠ Zones 2'
        $result | Should -Match '✗ Zones 3'
        $result | Should -Match '\|'
    }

    It "Returns Non-zonal when all arrays are empty" {
        $result = Format-ZoneStatus -OK @() -Limited @() -Restricted @()
        $result | Should -Be 'Non-zonal'
    }
}

Describe "Test-SkuMatchesFilter" {

    Context "No filter" {
        It "Returns true when no filter is provided" {
            Test-SkuMatchesFilter -SkuName 'Standard_D2s_v3' -FilterPatterns @() | Should -BeTrue
        }

        It "Returns true when filter is null" {
            Test-SkuMatchesFilter -SkuName 'Standard_D2s_v3' -FilterPatterns $null | Should -BeTrue
        }
    }

    Context "Exact match" {
        It "Matches exact SKU name" {
            Test-SkuMatchesFilter -SkuName 'Standard_D2s_v3' -FilterPatterns @('Standard_D2s_v3') | Should -BeTrue
        }

        It "Does not match different SKU name" {
            Test-SkuMatchesFilter -SkuName 'Standard_D2s_v3' -FilterPatterns @('Standard_E2s_v3') | Should -BeFalse
        }
    }

    Context "Wildcard patterns" {
        It "Matches with trailing wildcard" {
            Test-SkuMatchesFilter -SkuName 'Standard_D2s_v3' -FilterPatterns @('Standard_D*') | Should -BeTrue
        }

        It "Matches with middle wildcard" {
            Test-SkuMatchesFilter -SkuName 'Standard_D2s_v3' -FilterPatterns @('Standard_*_v3') | Should -BeTrue
        }

        It "Matches single-char wildcard" {
            Test-SkuMatchesFilter -SkuName 'Standard_D2s_v3' -FilterPatterns @('Standard_D?s_v3') | Should -BeTrue
        }

        It "Does not match when pattern doesn't fit" {
            Test-SkuMatchesFilter -SkuName 'Standard_D2s_v3' -FilterPatterns @('Standard_E*') | Should -BeFalse
        }
    }

    Context "Multiple patterns" {
        It "Matches if any pattern matches" {
            Test-SkuMatchesFilter -SkuName 'Standard_D2s_v3' -FilterPatterns @('Standard_E*', 'Standard_D*') | Should -BeTrue
        }

        It "Returns false when no pattern matches" {
            Test-SkuMatchesFilter -SkuName 'Standard_D2s_v3' -FilterPatterns @('Standard_E*', 'Standard_F*') | Should -BeFalse
        }
    }
}

Describe "Get-GeoGroup" {

    It "Maps eastus to Americas-US" {
        Get-GeoGroup -LocationCode 'eastus' | Should -Be 'Americas-US'
    }

    It "Maps westeurope to Europe" {
        Get-GeoGroup -LocationCode 'westeurope' | Should -Be 'Europe'
    }

    It "Maps southeastasia to Asia-Pacific" {
        Get-GeoGroup -LocationCode 'southeastasia' | Should -Be 'Asia-Pacific'
    }

    It "Maps australiaeast to Australia" {
        Get-GeoGroup -LocationCode 'australiaeast' | Should -Be 'Australia'
    }

    It "Maps brazilsouth to Americas-LatAm" {
        Get-GeoGroup -LocationCode 'brazilsouth' | Should -Be 'Americas-LatAm'
    }

    It "Maps centralindia to India" {
        Get-GeoGroup -LocationCode 'centralindia' | Should -Be 'India'
    }

    It "Maps uaenorth to Middle East" {
        Get-GeoGroup -LocationCode 'uaenorth' | Should -Be 'Middle East'
    }

    It "Maps southafricanorth to Africa" {
        Get-GeoGroup -LocationCode 'southafricanorth' | Should -Be 'Africa'
    }

    It "Maps unknown region to Other" {
        Get-GeoGroup -LocationCode 'xyzregion' | Should -Be 'Other'
    }

    It "Maps usgovvirginia to Americas-USGov" {
        Get-GeoGroup -LocationCode 'usgovvirginia' | Should -Be 'Americas-USGov'
    }

    It "Maps canadacentral to Americas-Canada" {
        Get-GeoGroup -LocationCode 'canadacentral' | Should -Be 'Americas-Canada'
    }
}

Describe "Get-RestrictionReason" {

    It "Returns null for SKU with no restrictions" {
        $sku = [PSCustomObject]@{ Restrictions = @() }
        Get-RestrictionReason -Sku $sku | Should -BeNullOrEmpty
    }

    It "Returns ReasonCode from a single restriction" {
        $sku = [PSCustomObject]@{
            Restrictions = @(
                [PSCustomObject]@{ ReasonCode = 'Quota' }
            )
        }
        Get-RestrictionReason -Sku $sku | Should -Be 'Quota'
    }

    It "Returns first ReasonCode when multiple restrictions exist" {
        $sku = [PSCustomObject]@{
            Restrictions = @(
                [PSCustomObject]@{ ReasonCode = 'NotAvailableForSubscription' }
                [PSCustomObject]@{ ReasonCode = 'Quota' }
            )
        }
        Get-RestrictionReason -Sku $sku | Should -Be 'NotAvailableForSubscription'
    }

    It "Returns null for null Sku" {
        Get-RestrictionReason -Sku $null | Should -BeNullOrEmpty
    }
}

Describe "Get-QuotaAvailable" {

    Context "Family not in quota lookup" {
        It "Returns all nulls when family is missing" {
            $result = Get-QuotaAvailable -QuotaLookup @{} -SkuFamily 'D'
            $result.Available | Should -BeNullOrEmpty
            $result.OK | Should -BeNullOrEmpty
            $result.Limit | Should -BeNullOrEmpty
            $result.Current | Should -BeNullOrEmpty
        }
    }

    Context "Family found in quota lookup" {

        BeforeAll {
            $script:TestQuota = @{ 'D' = @{ Limit = 100; CurrentValue = 60 } }
        }

        It "Returns correct Available count (Limit - CurrentValue)" {
            $result = Get-QuotaAvailable -QuotaLookup $script:TestQuota -SkuFamily 'D'
            $result.Available | Should -Be 40
            $result.Limit | Should -Be 100
            $result.Current | Should -Be 60
        }

        It "OK is true when no RequiredvCPUs and available > 0" {
            $result = Get-QuotaAvailable -QuotaLookup $script:TestQuota -SkuFamily 'D'
            $result.OK | Should -BeTrue
        }

        It "OK is true when available meets RequiredvCPUs" {
            $result = Get-QuotaAvailable -QuotaLookup $script:TestQuota -SkuFamily 'D' -RequiredvCPUs 32
            $result.OK | Should -BeTrue
        }

        It "OK is false when available is below RequiredvCPUs" {
            $result = Get-QuotaAvailable -QuotaLookup $script:TestQuota -SkuFamily 'D' -RequiredvCPUs 50
            $result.OK | Should -BeFalse
        }

        It "OK is false when quota is fully exhausted" {
            $fullQuota = @{ 'D' = @{ Limit = 100; CurrentValue = 100 } }
            $result = Get-QuotaAvailable -QuotaLookup $fullQuota -SkuFamily 'D'
            $result.OK | Should -BeFalse
        }
    }
}

Describe "Get-SkuCapabilities" {

    Context "Defaults when no capabilities present" {
        It "Returns HyperVGenerations V1 by default" {
            $sku = [PSCustomObject]@{ Capabilities = @() }
            (Get-SkuCapabilities -Sku $sku).HyperVGenerations | Should -Be 'V1'
        }

        It "Returns CpuArchitecture x64 by default" {
            $sku = [PSCustomObject]@{ Capabilities = @() }
            (Get-SkuCapabilities -Sku $sku).CpuArchitecture | Should -Be 'x64'
        }

        It "Returns TempDiskGB 0 by default" {
            $sku = [PSCustomObject]@{ Capabilities = @() }
            (Get-SkuCapabilities -Sku $sku).TempDiskGB | Should -Be 0
        }

        It "Returns NvmeSupport false by default" {
            $sku = [PSCustomObject]@{ Capabilities = @() }
            (Get-SkuCapabilities -Sku $sku).NvmeSupport | Should -BeFalse
        }

        It "Returns AcceleratedNetworkingEnabled false by default" {
            $sku = [PSCustomObject]@{ Capabilities = @() }
            (Get-SkuCapabilities -Sku $sku).AcceleratedNetworkingEnabled | Should -BeFalse
        }
    }

    Context "Capability parsing" {
        It "Parses HyperVGenerations V1,V2" {
            $sku = [PSCustomObject]@{
                Capabilities = @([PSCustomObject]@{ Name = 'HyperVGenerations'; Value = 'V1,V2' })
            }
            (Get-SkuCapabilities -Sku $sku).HyperVGenerations | Should -Be 'V1,V2'
        }

        It "Parses CpuArchitectureType = Arm64" {
            $sku = [PSCustomObject]@{
                Capabilities = @([PSCustomObject]@{ Name = 'CpuArchitectureType'; Value = 'Arm64' })
            }
            (Get-SkuCapabilities -Sku $sku).CpuArchitecture | Should -Be 'Arm64'
        }

        It "Converts MaxResourceVolumeMB to TempDiskGB (204800 MB = 200 GB)" {
            $sku = [PSCustomObject]@{
                Capabilities = @([PSCustomObject]@{ Name = 'MaxResourceVolumeMB'; Value = '204800' })
            }
            (Get-SkuCapabilities -Sku $sku).TempDiskGB | Should -Be 200
        }

        It "Sets AcceleratedNetworkingEnabled true from 'True' string" {
            $sku = [PSCustomObject]@{
                Capabilities = @([PSCustomObject]@{ Name = 'AcceleratedNetworkingEnabled'; Value = 'True' })
            }
            (Get-SkuCapabilities -Sku $sku).AcceleratedNetworkingEnabled | Should -BeTrue
        }

        It "Leaves AcceleratedNetworkingEnabled false from 'False' string" {
            $sku = [PSCustomObject]@{
                Capabilities = @([PSCustomObject]@{ Name = 'AcceleratedNetworkingEnabled'; Value = 'False' })
            }
            (Get-SkuCapabilities -Sku $sku).AcceleratedNetworkingEnabled | Should -BeFalse
        }

        It "Sets NvmeSupport true when NvmeDiskSizeInMiB is present" {
            $sku = [PSCustomObject]@{
                Capabilities = @([PSCustomObject]@{ Name = 'NvmeDiskSizeInMiB'; Value = '3686400' })
            }
            (Get-SkuCapabilities -Sku $sku).NvmeSupport | Should -BeTrue
        }
    }

    Context "Null capabilities property" {
        It "Returns defaults when Capabilities is null" {
            $sku = [PSCustomObject]@{ Capabilities = $null }
            $result = Get-SkuCapabilities -Sku $sku
            $result.HyperVGenerations | Should -Be 'V1'
            $result.CpuArchitecture | Should -Be 'x64'
        }
    }
}
