# Mock functions declare parameters to match real cmdlet signatures but don't reference them
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', '', Justification = 'Mock function parameters match real cmdlet signatures for Pester overrides')]
param()

BeforeAll {
    Import-Module "$PSScriptRoot\TestHarness.psm1" -Force

    . ([scriptblock]::Create((Get-MainScriptFunctionDefinition -FunctionName 'Get-AzVMPricing')))
    . ([scriptblock]::Create((Get-MainScriptFunctionDefinition -FunctionName 'Get-RegularPricingMap')))
    . ([scriptblock]::Create((Get-MainScriptFunctionDefinition -FunctionName 'Get-SpotPricingMap')))
}

Describe 'Get-AzVMPricing spot/regular data model' {

    BeforeEach {
        $script:TestEndpoints = @{
            PricingApiUrl = 'https://example.test/api/prices'
        }
        $script:TestCaches = [ordered]@{
            Pricing = @{}
        }

        function Invoke-WithRetry {
            param([scriptblock]$ScriptBlock, [int]$MaxRetries, [string]$OperationName)
            & $ScriptBlock
        }
    }

    It 'Returns separate Regular and Spot pricing maps' {
        Mock Invoke-RestMethod {
            [pscustomobject]@{
                Items = @(
                    [pscustomobject]@{
                        productName   = 'Virtual Machines Dv5 Series'
                        skuName       = 'D4s v5'
                        meterName     = 'D4s v5'
                        armSkuName    = 'Standard_D4s_v5'
                        retailPrice   = 0.2
                        currencyCode  = 'USD'
                    },
                    [pscustomobject]@{
                        productName   = 'Virtual Machines Dv5 Series'
                        skuName       = 'D4s v5 Spot'
                        meterName     = 'D4s v5 Spot'
                        armSkuName    = 'Standard_D4s_v5'
                        retailPrice   = 0.06
                        currencyCode  = 'USD'
                    }
                )
                NextPageLink = $null
            }
        }

        $result = Get-AzVMPricing -Region 'eastus' -MaxRetries 0 -HoursPerMonth 730 -AzureEndpoints $script:TestEndpoints -Caches $script:TestCaches

        @($result.Keys) | Should -Contain 'Regular'
        @($result.Keys) | Should -Contain 'Spot'
        $result.Regular['Standard_D4s_v5'].Hourly | Should -Be 0.2
        $result.Spot['Standard_D4s_v5'].Hourly | Should -Be 0.06
    }

    It 'Returns empty Regular and Spot maps on failure' {
        Mock Invoke-RestMethod { throw 'network failed' }

        $result = Get-AzVMPricing -Region 'eastus' -MaxRetries 0 -HoursPerMonth 730 -AzureEndpoints $script:TestEndpoints -Caches $script:TestCaches

        $result.Regular.Count | Should -Be 0
        $result.Spot.Count | Should -Be 0
    }
}

Describe 'Get-RegularPricingMap' {

    It 'Returns Regular map when pricing container has Regular and Spot keys' {
        $container = @{
            Regular = @{ 'Standard_D4s_v5' = @{ Hourly = 0.2 } }
            Spot    = @{ 'Standard_D4s_v5' = @{ Hourly = 0.06 } }
        }

        $map = Get-RegularPricingMap -PricingContainer $container
        $map['Standard_D4s_v5'].Hourly | Should -Be 0.2
    }

    It 'Returns input map unchanged for legacy pricing containers' {
        $legacy = @{ 'Standard_D4s_v5' = @{ Hourly = 0.2 } }

        $map = Get-RegularPricingMap -PricingContainer $legacy
        $map['Standard_D4s_v5'].Hourly | Should -Be 0.2
    }
}

Describe 'Get-SpotPricingMap' {

    It 'Returns Spot map when pricing container has Regular and Spot keys' {
        $container = @{
            Regular = @{ 'Standard_D4s_v5' = @{ Hourly = 0.2 } }
            Spot    = @{ 'Standard_D4s_v5' = @{ Hourly = 0.06 } }
        }

        $map = Get-SpotPricingMap -PricingContainer $container
        $map['Standard_D4s_v5'].Hourly | Should -Be 0.06
    }

    It 'Returns empty map for legacy pricing containers' {
        $legacy = @{ 'Standard_D4s_v5' = @{ Hourly = 0.2 } }

        $map = Get-SpotPricingMap -PricingContainer $legacy
        $map.Count | Should -Be 0
    }
}
