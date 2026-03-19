# Get-ValidAzureRegions.Tests.ps1
# Pester tests for Get-ValidAzureRegions function
# Run with: Invoke-Pester .\tests\Get-ValidAzureRegions.Tests.ps1

BeforeAll {
    Import-Module "$PSScriptRoot\TestHarness.psm1" -Force
    $functionNames = @(
        'Get-ValidAzureRegions',
        'Invoke-WithRetry'
    )

    foreach ($functionName in $functionNames) {
        . ([scriptblock]::Create((Get-MainScriptFunctionDefinition -FunctionName $functionName)))
    }

    # Initialize test defaults
    $script:TestMaxRetries = 3
    $script:TestAzureEndpoints = $null
}

Describe "Get-ValidAzureRegions" {

    BeforeEach {
        $script:TestCaches = @{}
    }

    Context "Caching" {

        It "Returns cached regions on second call without re-fetching" {
            $script:TestCaches = @{ ValidRegions = @('eastus', 'westus2', 'centralus') }
            $result = Get-ValidAzureRegions -MaxRetries $script:TestMaxRetries -Caches $script:TestCaches
            $result | Should -HaveCount 3
            $result | Should -Contain 'eastus'
        }
    }

    Context "Region name validation (regex)" {

        It "Accepts regions with digits like eastus2, westus3" {
            # The regex '^[a-z0-9]+$' must accept digit-containing region names
            'eastus2' | Should -Match '^[a-z0-9]+$'
            'westus3' | Should -Match '^[a-z0-9]+$'
            'southcentralus' | Should -Match '^[a-z0-9]+$'
        }

        It "Rejects regions with hyphens or spaces (paired/logical display names)" {
            'East US' | Should -Not -Match '^[a-z0-9]+$'
            'east-us' | Should -Not -Match '^[a-z0-9]+$'
            'US East' | Should -Not -Match '^[a-z0-9]+$'
        }
    }

    Context "REST API success path" {

        It "Returns lowercase region names from REST API response" {
            $mockResponse = @{
                value = @(
                    @{ name = 'eastus'; metadata = @{ regionCategory = 'Recommended' } }
                    @{ name = 'eastus2'; metadata = @{ regionCategory = 'Recommended' } }
                    @{ name = 'westeurope'; metadata = @{ regionCategory = 'Recommended' } }
                    @{ name = 'global'; metadata = @{ regionCategory = 'Other' } }
                )
            }

            Mock Get-AzContext { [PSCustomObject]@{ Subscription = @{ Id = '00000000-0000-0000-0000-000000000000' } } }
            Mock Get-AzAccessToken { [PSCustomObject]@{ Token = 'mock-token' } }
            Mock Invoke-RestMethod { $mockResponse }

            $result = Get-ValidAzureRegions -MaxRetries $script:TestMaxRetries -Caches $script:TestCaches
            $result | Should -HaveCount 3
            $result | Should -Contain 'eastus'
            $result | Should -Contain 'eastus2'
            $result | Should -Not -Contain 'global'
        }

        It "Filters out 'Other' category regions" {
            $mockResponse = @{
                value = @(
                    @{ name = 'westus2'; metadata = @{ regionCategory = 'Recommended' } }
                    @{ name = 'staging'; metadata = @{ regionCategory = 'Other' } }
                )
            }

            Mock Get-AzContext { [PSCustomObject]@{ Subscription = @{ Id = '00000000-0000-0000-0000-000000000000' } } }
            Mock Get-AzAccessToken { [PSCustomObject]@{ Token = 'mock-token' } }
            Mock Invoke-RestMethod { $mockResponse }

            $result = Get-ValidAzureRegions -MaxRetries $script:TestMaxRetries -Caches $script:TestCaches
            $result | Should -Contain 'westus2'
            $result | Should -Not -Contain 'staging'
        }

        It "Caches result after successful fetch" {
            $mockResponse = @{
                value = @(
                    @{ name = 'eastus'; metadata = @{ regionCategory = 'Recommended' } }
                )
            }

            Mock Get-AzContext { [PSCustomObject]@{ Subscription = @{ Id = '00000000-0000-0000-0000-000000000000' } } }
            Mock Get-AzAccessToken { [PSCustomObject]@{ Token = 'mock-token' } }
            Mock Invoke-RestMethod { $mockResponse }

            Get-ValidAzureRegions -MaxRetries $script:TestMaxRetries -Caches $script:TestCaches | Out-Null
            $script:TestCaches.ValidRegions | Should -Not -BeNullOrEmpty
            $script:TestCaches.ValidRegions | Should -Contain 'eastus'
        }
    }

    Context "Fallback to Get-AzLocation" {

        It "Falls back when REST API fails and returns valid regions" {
            Mock Get-AzContext { throw "No context" }
            Mock Get-AzLocation {
                @(
                    [PSCustomObject]@{ Location = 'eastus'; Providers = @('Microsoft.Compute', 'Microsoft.Storage') }
                    [PSCustomObject]@{ Location = 'westus2'; Providers = @('Microsoft.Compute') }
                    [PSCustomObject]@{ Location = 'brazilsouth'; Providers = @('Microsoft.Storage') }
                )
            }

            $result = Get-ValidAzureRegions -MaxRetries $script:TestMaxRetries -Caches $script:TestCaches
            $result | Should -HaveCount 2
            $result | Should -Contain 'eastus'
            $result | Should -Contain 'westus2'
            $result | Should -Not -Contain 'brazilsouth'
        }
    }

    Context "Graceful failure" {

        It "Returns null when both REST and Get-AzLocation fail" {
            Mock Get-AzContext { throw "No context" }
            Mock Get-AzLocation { throw "No locations available" }

            $result = Get-ValidAzureRegions -MaxRetries $script:TestMaxRetries -Caches $script:TestCaches
            $result | Should -BeNullOrEmpty
        }

        It "Does not throw when all sources fail" {
            Mock Get-AzContext { throw "No context" }
            Mock Get-AzLocation { throw "Connection error" }

            { Get-ValidAzureRegions -MaxRetries $script:TestMaxRetries -Caches $script:TestCaches } | Should -Not -Throw
        }
    }

    Context "Sovereign cloud support" {

        It "Uses sovereign ARM URL when AzureEndpoints is set" {
            $sovereignEndpoints = @{ ResourceManagerUrl = 'https://management.chinacloudapi.cn/' }

            Mock Get-AzContext { [PSCustomObject]@{ Subscription = @{ Id = '00000000-0000-0000-0000-000000000000' } } }
            Mock Get-AzAccessToken { [PSCustomObject]@{ Token = 'mock-token' } }
            Mock Invoke-RestMethod {
                param($Uri)
                $Uri | Should -Match 'chinacloudapi'
                @{ value = @(@{ name = 'chinaeast'; metadata = @{ regionCategory = 'Recommended' } }) }
            }

            $result = Get-ValidAzureRegions -MaxRetries $script:TestMaxRetries -AzureEndpoints $sovereignEndpoints -Caches $script:TestCaches
            $result | Should -Contain 'chinaeast'
        }
    }
}
