# ConvertFrom-Rest.Tests.ps1
# Pester tests for ConvertFrom-RestSku and ConvertFrom-RestQuota normalization helpers
# Run with: Invoke-Pester .\tests\ConvertFrom-Rest.Tests.ps1 -Output Detailed

BeforeAll {
    Import-Module "$PSScriptRoot\TestHarness.psm1" -Force
    . ([scriptblock]::Create((Get-MainScriptFunctionDefinition -FunctionName 'ConvertFrom-RestSku')))
    . ([scriptblock]::Create((Get-MainScriptFunctionDefinition -FunctionName 'ConvertFrom-RestQuota')))
}

Describe "ConvertFrom-RestSku" {

    Context "Standard VM SKU normalization" {
        BeforeAll {
            $restSku = [PSCustomObject]@{
                name         = 'Standard_D4s_v5'
                resourceType = 'virtualMachines'
                family       = 'standardDSv5Family'
                locationInfo = @(
                    [PSCustomObject]@{ location = 'eastus'; zones = @('1', '2', '3') }
                )
                restrictions = @()
                capabilities = @(
                    [PSCustomObject]@{ name = 'vCPUs'; value = '4' }
                    [PSCustomObject]@{ name = 'MemoryGB'; value = '16' }
                    [PSCustomObject]@{ name = 'MaxDataDiskCount'; value = '8' }
                )
            }
            $result = ConvertFrom-RestSku -RestSku $restSku
        }

        It "Sets Name from REST name field" {
            $result.Name | Should -Be 'Standard_D4s_v5'
        }

        It "Sets ResourceType" {
            $result.ResourceType | Should -Be 'virtualMachines'
        }

        It "Sets Family" {
            $result.Family | Should -Be 'standardDSv5Family'
        }

        It "Normalizes LocationInfo with Zones array" {
            $result.LocationInfo | Should -HaveCount 1
            $result.LocationInfo[0].Location | Should -Be 'eastus'
            $result.LocationInfo[0].Zones | Should -HaveCount 3
        }

        It "Normalizes Capabilities to PSCustomObject array" {
            $result.Capabilities | Should -HaveCount 3
            $result.Capabilities[0].Name | Should -Be 'vCPUs'
            $result.Capabilities[0].Value | Should -Be '4'
        }

        It "Builds _CapIndex hashtable for O(1) lookup" {
            $result._CapIndex | Should -Not -BeNullOrEmpty
            $result._CapIndex['vCPUs'] | Should -Be '4'
            $result._CapIndex['MemoryGB'] | Should -Be '16'
            $result._CapIndex['MaxDataDiskCount'] | Should -Be '8'
        }
    }

    Context "SKU with restrictions" {
        BeforeAll {
            $restSku = [PSCustomObject]@{
                name         = 'Standard_NC6s_v3'
                resourceType = 'virtualMachines'
                family       = 'standardNCSv3Family'
                locationInfo = @(
                    [PSCustomObject]@{ location = 'eastus'; zones = @() }
                )
                restrictions = @(
                    [PSCustomObject]@{
                        type            = 'Zone'
                        reasonCode      = 'NotAvailableForSubscription'
                        restrictionInfo = [PSCustomObject]@{ zones = @('1', '2'); locations = @('eastus') }
                    }
                )
                capabilities = @()
            }
            $result = ConvertFrom-RestSku -RestSku $restSku
        }

        It "Normalizes restriction with type and reason" {
            $result.Restrictions | Should -HaveCount 1
            $result.Restrictions[0].Type | Should -Be 'Zone'
            $result.Restrictions[0].ReasonCode | Should -Be 'NotAvailableForSubscription'
        }

        It "Normalizes restriction info with zones" {
            $result.Restrictions[0].RestrictionInfo.Zones | Should -Contain '1'
            $result.Restrictions[0].RestrictionInfo.Zones | Should -Contain '2'
        }
    }

    Context "Edge cases" {
        It "Handles SKU with empty capabilities" {
            $restSku = [PSCustomObject]@{
                name = 'Standard_B1s'; resourceType = 'virtualMachines'; family = 'standardBSFamily'
                locationInfo = @(); restrictions = @(); capabilities = @()
            }
            $result = ConvertFrom-RestSku -RestSku $restSku
            $result.Capabilities | Should -HaveCount 0
            $result._CapIndex.Count | Should -Be 0
        }

        It "Handles SKU with null locationInfo" {
            $restSku = [PSCustomObject]@{
                name = 'Standard_B1s'; resourceType = 'virtualMachines'; family = 'standardBSFamily'
                locationInfo = $null; restrictions = $null; capabilities = $null
            }
            $result = ConvertFrom-RestSku -RestSku $restSku
            $result.LocationInfo | Should -HaveCount 0
            $result.Restrictions | Should -HaveCount 0
        }
    }
}

Describe "ConvertFrom-RestQuota" {

    Context "Standard quota normalization" {
        BeforeAll {
            $restQuota = [PSCustomObject]@{
                name = [PSCustomObject]@{
                    value          = 'standardDSv3Family'
                    localizedValue = 'Standard DSv3 Family vCPUs'
                }
                currentValue = 12
                limit        = 100
            }
            $result = ConvertFrom-RestQuota -RestQuota $restQuota
        }

        It "Sets Name.Value from REST name.value" {
            $result.Name.Value | Should -Be 'standardDSv3Family'
        }

        It "Sets Name.LocalizedValue" {
            $result.Name.LocalizedValue | Should -Be 'Standard DSv3 Family vCPUs'
        }

        It "Sets CurrentValue" {
            $result.CurrentValue | Should -Be 12
        }

        It "Sets Limit" {
            $result.Limit | Should -Be 100
        }
    }

    Context "Zero usage quota" {
        It "Handles zero currentValue and limit" {
            $restQuota = [PSCustomObject]@{
                name = [PSCustomObject]@{ value = 'standardNCSv3Family'; localizedValue = 'Standard NCSv3 Family vCPUs' }
                currentValue = 0
                limit        = 0
            }
            $result = ConvertFrom-RestQuota -RestQuota $restQuota
            $result.CurrentValue | Should -Be 0
            $result.Limit | Should -Be 0
        }
    }
}
