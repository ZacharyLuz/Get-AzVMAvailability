# Get-AzureEndpoints.Tests.ps1
# Pester tests for sovereign cloud endpoint resolution
# Run with: Invoke-Pester .\tests\Get-AzureEndpoints.Tests.ps1 -Output Detailed

BeforeAll {
    # Import only the functions from the script without executing main logic
    # We extract and invoke just the function definitions
    $scriptContent = Get-Content "$PSScriptRoot\..\Get-AzVMAvailability.ps1" -Raw

    # Extract Get-AzureEndpoints function using regex
    if ($scriptContent -match '(?s)(function Get-AzureEndpoints \{.+?\n\})') {
        Invoke-Expression $matches[1]
    }
    else {
        throw "Could not find Get-AzureEndpoints function in script"
    }
}

Describe "Get-AzureEndpoints" {

    Context "Commercial Cloud (AzureCloud)" {
        It "Returns correct endpoints for Azure Commercial" {
            # Mock a Commercial cloud environment
            $mockEnv = [PSCustomObject]@{
                Name                = 'AzureCloud'
                ResourceManagerUrl  = 'https://management.azure.com/'
                ManagementPortalUrl = 'https://portal.azure.com'
            }

            $endpoints = Get-AzureEndpoints -AzEnvironment $mockEnv

            $endpoints.EnvironmentName | Should -Be 'AzureCloud'
            $endpoints.ResourceManagerUrl | Should -Be 'https://management.azure.com'
            $endpoints.PricingApiUrl | Should -Be 'https://prices.azure.com/api/retail/prices'
        }
    }

    Context "US Government Cloud (AzureUSGovernment)" {
        It "Returns correct endpoints for Azure Government" {
            $mockEnv = [PSCustomObject]@{
                Name                = 'AzureUSGovernment'
                ResourceManagerUrl  = 'https://management.usgovcloudapi.net/'
                ManagementPortalUrl = 'https://portal.azure.us'
            }

            $endpoints = Get-AzureEndpoints -AzEnvironment $mockEnv

            $endpoints.EnvironmentName | Should -Be 'AzureUSGovernment'
            $endpoints.ResourceManagerUrl | Should -Be 'https://management.usgovcloudapi.net'
            $endpoints.PricingApiUrl | Should -Be 'https://prices.azure.us/api/retail/prices'
        }

        It "Handles portal.azure.us -> prices.azure.us transformation" {
            $mockEnv = [PSCustomObject]@{
                Name                = 'AzureUSGovernment'
                ResourceManagerUrl  = 'https://management.usgovcloudapi.net'
                ManagementPortalUrl = 'https://portal.azure.us/'  # With trailing slash
            }

            $endpoints = Get-AzureEndpoints -AzEnvironment $mockEnv

            $endpoints.PricingApiUrl | Should -Match 'prices\.azure\.us'
        }
    }

    Context "China Cloud (AzureChinaCloud)" {
        It "Returns correct endpoints for Azure China" {
            $mockEnv = [PSCustomObject]@{
                Name                = 'AzureChinaCloud'
                ResourceManagerUrl  = 'https://management.chinacloudapi.cn/'
                ManagementPortalUrl = 'https://portal.azure.cn'
            }

            $endpoints = Get-AzureEndpoints -AzEnvironment $mockEnv

            $endpoints.EnvironmentName | Should -Be 'AzureChinaCloud'
            $endpoints.ResourceManagerUrl | Should -Be 'https://management.chinacloudapi.cn'
            $endpoints.PricingApiUrl | Should -Be 'https://prices.azure.cn/api/retail/prices'
        }
    }

    Context "German Cloud (AzureGermanCloud)" {
        It "Returns correct endpoints for Azure Germany (legacy)" {
            $mockEnv = [PSCustomObject]@{
                Name                = 'AzureGermanCloud'
                ResourceManagerUrl  = 'https://management.microsoftazure.de/'
                ManagementPortalUrl = 'https://portal.microsoftazure.de'
            }

            $endpoints = Get-AzureEndpoints -AzEnvironment $mockEnv

            $endpoints.EnvironmentName | Should -Be 'AzureGermanCloud'
            $endpoints.ResourceManagerUrl | Should -Be 'https://management.microsoftazure.de'
            $endpoints.PricingApiUrl | Should -Be 'https://prices.microsoftazure.de/api/retail/prices'
        }
    }

    Context "Fallback behavior" {
        It "Returns Commercial endpoints when no environment provided" {
            $endpoints = Get-AzureEndpoints -AzEnvironment $null

            $endpoints.EnvironmentName | Should -Be 'AzureCloud'
            $endpoints.ResourceManagerUrl | Should -Be 'https://management.azure.com'
            $endpoints.PricingApiUrl | Should -Be 'https://prices.azure.com/api/retail/prices'
        }

        It "Uses fallback when ManagementPortalUrl is missing" {
            $mockEnv = [PSCustomObject]@{
                Name                = 'AzureUSGovernment'
                ResourceManagerUrl  = 'https://management.usgovcloudapi.net'
                ManagementPortalUrl = $null  # Missing portal URL
            }

            $endpoints = Get-AzureEndpoints -AzEnvironment $mockEnv

            # Should use fallback based on environment name
            $endpoints.PricingApiUrl | Should -Be 'https://prices.azure.us/api/retail/prices'
        }
    }

    Context "URL normalization" {
        It "Removes trailing slashes from ResourceManagerUrl" {
            $mockEnv = [PSCustomObject]@{
                Name                = 'AzureCloud'
                ResourceManagerUrl  = 'https://management.azure.com/'  # With trailing slash
                ManagementPortalUrl = 'https://portal.azure.com'
            }

            $endpoints = Get-AzureEndpoints -AzEnvironment $mockEnv

            $endpoints.ResourceManagerUrl | Should -Not -Match '/$'
        }

        It "Removes trailing slashes from PricingApiUrl base" {
            $mockEnv = [PSCustomObject]@{
                Name                = 'AzureCloud'
                ResourceManagerUrl  = 'https://management.azure.com'
                ManagementPortalUrl = 'https://portal.azure.com/'  # With trailing slash
            }

            $endpoints = Get-AzureEndpoints -AzEnvironment $mockEnv

            # Should not have double slashes after the protocol
            $endpoints.PricingApiUrl | Should -Not -Match 'https?://.*//'
            $endpoints.PricingApiUrl | Should -Match '/api/retail/prices$'
        }
    }
}

Describe "Endpoint Integration" {

    Context "URL construction" {
        It "Constructs valid pricing API filter URL" {
            $mockEnv = [PSCustomObject]@{
                Name                = 'AzureUSGovernment'
                ResourceManagerUrl  = 'https://management.usgovcloudapi.net'
                ManagementPortalUrl = 'https://portal.azure.us'
            }

            $endpoints = Get-AzureEndpoints -AzEnvironment $mockEnv

            $region = 'usgovvirginia'
            $filter = "armRegionName eq '$region' and priceType eq 'Consumption'"
            $fullUrl = "$($endpoints.PricingApiUrl)?`$filter=$([uri]::EscapeDataString($filter))"

            $fullUrl | Should -Match 'prices\.azure\.us/api/retail/prices\?'
            $fullUrl | Should -Match 'usgovvirginia'
        }

        It "Constructs valid ARM API URL for Cost Management" {
            $mockEnv = [PSCustomObject]@{
                Name                = 'AzureUSGovernment'
                ResourceManagerUrl  = 'https://management.usgovcloudapi.net'
                ManagementPortalUrl = 'https://portal.azure.us'
            }

            $endpoints = Get-AzureEndpoints -AzEnvironment $mockEnv

            $subscriptionId = '00000000-0000-0000-0000-000000000000'
            $armApiUrl = "$($endpoints.ResourceManagerUrl)/subscriptions/$subscriptionId/providers/Microsoft.Consumption/pricesheets/default"

            $armApiUrl | Should -Match 'management\.usgovcloudapi\.net/subscriptions/'
            $armApiUrl | Should -Not -Match 'https?://.*//'  # No double slashes after protocol
        }
    }
}
