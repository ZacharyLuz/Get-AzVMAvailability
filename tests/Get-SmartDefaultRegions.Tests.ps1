# Get-SmartDefaultRegions.Tests.ps1
# Pester tests for smart default region selection
# Run with: Invoke-Pester .\tests\Get-SmartDefaultRegions.Tests.ps1 -Output Detailed

BeforeAll {
    Import-Module "$PSScriptRoot\TestHarness.psm1" -Force
    . ([scriptblock]::Create((Get-MainScriptFunctionDefinition -FunctionName 'Get-SmartDefaultRegions')))
}

Describe "Get-SmartDefaultRegions" {

    Context "Sovereign cloud environments" {

        It "Returns Gov regions for AzureUSGovernment" {
            $result = Get-SmartDefaultRegions -CloudEnvironment 'AzureUSGovernment'
            $result.Regions | Should -Contain 'usgovvirginia'
            $result.Regions | Should -HaveCount 3
            $result.Source | Should -BeLike 'Cloud: AzureUSGovernment'
        }

        It "Returns China regions for AzureChinaCloud" {
            $result = Get-SmartDefaultRegions -CloudEnvironment 'AzureChinaCloud'
            $result.Regions | Should -Contain 'chinaeast'
            $result.Regions | Should -HaveCount 3
            $result.Source | Should -BeLike 'Cloud: AzureChinaCloud'
        }
    }

    Context "Commercial cloud (AzureCloud)" {

        It "Returns a hashtable with Regions and Source keys" {
            $result = Get-SmartDefaultRegions -CloudEnvironment 'AzureCloud'
            $result.Keys | Should -Contain 'Regions'
            $result.Keys | Should -Contain 'Source'
        }

        It "Returns 3 regions" {
            $result = Get-SmartDefaultRegions -CloudEnvironment 'AzureCloud'
            $result.Regions | Should -HaveCount 3
        }

        It "Source string contains formatted UTC offset" {
            $result = Get-SmartDefaultRegions -CloudEnvironment 'AzureCloud'
            $result.Source | Should -Match 'UTC[+-]\d{2}:\d{2}'
        }
    }

    Context "Output contract" {

        It "Regions is always a string array" {
            $result = Get-SmartDefaultRegions -CloudEnvironment 'AzureCloud'
            $result.Regions | Should -BeOfType [string]
            $result.Regions.Count | Should -BeGreaterThan 0
            , $result.Regions | Should -BeOfType [array]
        }

        It "Source is always a non-empty string" {
            $result = Get-SmartDefaultRegions -CloudEnvironment 'AzureCloud'
            $result.Source | Should -Not -BeNullOrEmpty
        }
    }
}
