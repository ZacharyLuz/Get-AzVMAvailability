BeforeAll {
    Import-Module "$PSScriptRoot\TestHarness.psm1" -Force

    . ([scriptblock]::Create((Get-MainScriptFunctionDefinition -FunctionName 'Get-AzVMPricing')))
    . ([scriptblock]::Create((Get-MainScriptFunctionDefinition -FunctionName 'Get-RegularPricingMap')))
}

Describe 'Get-AzVMPricing spot/regular data model' {

    BeforeEach {
        $script:MaxRetries = 0
        $script:HoursPerMonth = 730
        $script:TargetEnvironment = 'AzureCloud'
        $script:AzureEndpoints = [pscustomobject]@{
            PricingApiUrl = 'https://example.test/api/prices'
        }
        $script:RunContext = [pscustomobject]@{
            Caches = [ordered]@{
                Pricing = @{}
            }
        }

        function global:Invoke-WithRetry {
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

        $result = Get-AzVMPricing -Region 'eastus'

        @($result.Keys) | Should -Contain 'Regular'
        @($result.Keys) | Should -Contain 'Spot'
        $result.Regular['Standard_D4s_v5'].Hourly | Should -Be 0.2
        $result.Spot['Standard_D4s_v5'].Hourly | Should -Be 0.06
    }

    It 'Returns empty Regular and Spot maps on failure' {
        Mock Invoke-RestMethod { throw 'network failed' }

        $result = Get-AzVMPricing -Region 'eastus'

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
