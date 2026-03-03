BeforeAll {
    Import-Module "$PSScriptRoot\TestHarness.psm1" -Force

    . ([scriptblock]::Create((Get-MainScriptFunctionDefinition -FunctionName 'Invoke-WithRetry')))
    . ([scriptblock]::Create((Get-MainScriptFunctionDefinition -FunctionName 'Get-PlacementScores')))
}

Describe 'Get-PlacementScores' {

    BeforeEach {
        $script:MaxRetries = 0
        $script:RunContext = [pscustomobject]@{
            Caches = [ordered]@{
                PlacementWarned403 = $false
            }
        }

        if (Test-Path function:Invoke-AzSpotPlacementScore) {
            Remove-Item function:Invoke-AzSpotPlacementScore -Force
        }
    }

    It 'Returns empty hashtable when placement cmdlet is unavailable' {
        $result = Get-PlacementScores -SkuNames @('Standard_D4s_v5') -Regions @('eastus')

        $result | Should -BeOfType 'hashtable'
        $result.Count | Should -Be 0
    }

    It 'Parses placement results into sku|region keys' {
        function global:Invoke-AzSpotPlacementScore {
            param([string[]]$Location, [string[]]$Sku, [int]$DesiredCount, [bool]$IsZonePlacement)
            return @(
                [pscustomobject]@{
                    Sku            = 'Standard_D4s_v5'
                    Region         = 'eastus'
                    PlacementScore = 'High'
                    IsAvailable    = $true
                    IsRestricted   = $false
                }
            )
        }

        $result = Get-PlacementScores -SkuNames @('Standard_D4s_v5') -Regions @('eastus') -DesiredCount 2

        $result.ContainsKey('Standard_D4s_v5|eastus') | Should -BeTrue
        $result['Standard_D4s_v5|eastus'].Score | Should -Be 'High'
        $result['Standard_D4s_v5|eastus'].IsAvailable | Should -BeTrue
        $result['Standard_D4s_v5|eastus'].IsRestricted | Should -BeFalse
    }

    It 'Enforces API input limits and passes zone placement flag' {
        $script:CapturedPlacementArgs = $null

        function global:Invoke-AzSpotPlacementScore {
            param([string[]]$Location, [string[]]$Sku, [int]$DesiredCount, [bool]$IsZonePlacement)
            $script:CapturedPlacementArgs = @{
                Location        = $Location
                Sku             = $Sku
                DesiredCount    = $DesiredCount
                IsZonePlacement = $IsZonePlacement
            }
            return @()
        }

        $skuNames = @('s1','s2','s3','s4','s5','s6')
        $regions = @('eastus','westus','centralus','eastus2','westus2','northcentralus','southcentralus','northeurope','westeurope')

        $null = Get-PlacementScores -SkuNames $skuNames -Regions $regions -DesiredCount 7 -IncludeAvailabilityZone

        $script:CapturedPlacementArgs.Sku.Count | Should -Be 5
        $script:CapturedPlacementArgs.Location.Count | Should -Be 8
        $script:CapturedPlacementArgs.DesiredCount | Should -Be 7
        $script:CapturedPlacementArgs.IsZonePlacement | Should -BeTrue
    }

    It 'Warns once and returns empty results on 403 permission failures' {
        Mock Write-Warning {}

        function global:Invoke-AzSpotPlacementScore {
            param([string[]]$Location, [string[]]$Sku, [int]$DesiredCount, [bool]$IsZonePlacement)
            throw '403 Forbidden'
        }

        $first = Get-PlacementScores -SkuNames @('Standard_D4s_v5') -Regions @('eastus')
        $second = Get-PlacementScores -SkuNames @('Standard_D4s_v5') -Regions @('eastus')

        $first.Count | Should -Be 0
        $second.Count | Should -Be 0
        Assert-MockCalled Write-Warning -Times 1 -Exactly
    }
}
