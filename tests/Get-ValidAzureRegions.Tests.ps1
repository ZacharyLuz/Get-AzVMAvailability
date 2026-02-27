# Get-ValidAzureRegions.Tests.ps1
# Pester tests for Get-ValidAzureRegions function
# Run with: Invoke-Pester .\tests\Get-ValidAzureRegions.Tests.ps1

BeforeAll {
    $scriptContent = Get-Content "$PSScriptRoot\..\Get-AzVMAvailability.ps1" -Raw

    # Extract Get-ValidAzureRegions and its dependencies
    $functionNames = @(
        'Get-ValidAzureRegions',
        'Invoke-WithRetry'
    )

    foreach ($funcName in $functionNames) {
        if ($scriptContent -match "(?s)(function $funcName \{.+?\n\})") {
            Invoke-Expression $matches[1]
        }
        else {
            Write-Warning "Could not find $funcName function in script"
        }
    }

    # Initialize script-scope variables the function depends on
    $script:CachedValidRegions = $null
    $script:AzureEndpoints = $null
    $MaxRetries = 3
}

Describe "Get-ValidAzureRegions" {

    BeforeEach {
        $script:CachedValidRegions = $null
    }

    Context "Caching" {

        It "Returns cached regions on second call without re-fetching" {
            $script:CachedValidRegions = @('eastus', 'westus2', 'centralus')
            $result = Get-ValidAzureRegions
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

            $result = Get-ValidAzureRegions
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

            $result = Get-ValidAzureRegions
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

            Get-ValidAzureRegions | Out-Null
            $script:CachedValidRegions | Should -Not -BeNullOrEmpty
            $script:CachedValidRegions | Should -Contain 'eastus'
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

            $result = Get-ValidAzureRegions
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

            $result = Get-ValidAzureRegions
            $result | Should -BeNullOrEmpty
        }

        It "Does not throw when all sources fail" {
            Mock Get-AzContext { throw "No context" }
            Mock Get-AzLocation { throw "Connection error" }

            { Get-ValidAzureRegions } | Should -Not -Throw
        }
    }

    Context "Sovereign cloud support" {

        It "Uses sovereign ARM URL when AzureEndpoints is set" {
            $script:AzureEndpoints = @{ ResourceManagerUrl = 'https://management.chinacloudapi.cn/' }

            Mock Get-AzContext { [PSCustomObject]@{ Subscription = @{ Id = '00000000-0000-0000-0000-000000000000' } } }
            Mock Get-AzAccessToken { [PSCustomObject]@{ Token = 'mock-token' } }
            Mock Invoke-RestMethod {
                param($Uri) 
                $Uri | Should -Match 'chinacloudapi'
                @{ value = @(@{ name = 'chinaeast'; metadata = @{ regionCategory = 'Recommended' } }) }
            }

            $result = Get-ValidAzureRegions
            $result | Should -Contain 'chinaeast'

            $script:AzureEndpoints = $null
        }
    }
}
