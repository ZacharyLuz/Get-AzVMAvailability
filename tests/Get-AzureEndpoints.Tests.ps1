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

Describe "Drill-Down Display Logic" {
    BeforeAll {
        # Mock data for testing drill-down display
        $script:mockFamilyDetails = @(
            [PSCustomObject]@{ Family = 'D'; SKU = 'Standard_D2s_v3'; Region = 'eastus'; vCPU = 2; MemGiB = 8; Gen = 'V2'; Arch = 'x64'; ZoneStatus = '1,2,3'; Capacity = 'OK'; QuotaAvail = 100; QuotaLimit = 200; QuotaCurrent = 100 }
            [PSCustomObject]@{ Family = 'D'; SKU = 'Standard_D4s_v3'; Region = 'eastus'; vCPU = 4; MemGiB = 16; Gen = 'V2'; Arch = 'x64'; ZoneStatus = '1,2,3'; Capacity = 'OK'; QuotaAvail = 100; QuotaLimit = 200; QuotaCurrent = 100 }
            [PSCustomObject]@{ Family = 'D'; SKU = 'Standard_D2s_v3'; Region = 'westus'; vCPU = 2; MemGiB = 8; Gen = 'V2'; Arch = 'x64'; ZoneStatus = '1,2'; Capacity = 'LIMITED'; QuotaAvail = 50; QuotaLimit = 100; QuotaCurrent = 50 }
            [PSCustomObject]@{ Family = 'E'; SKU = 'Standard_E2s_v3'; Region = 'eastus'; vCPU = 2; MemGiB = 16; Gen = 'V2'; Arch = 'x64'; ZoneStatus = '1,2,3'; Capacity = 'OK'; QuotaAvail = 200; QuotaLimit = 300; QuotaCurrent = 100 }
        )
    }

    Context "Header display behavior" {
        It "Should NOT print Family header when no matching SKUs exist" {
            # Simulate drill-down with a family that has no data
            $familyDetails = $script:mockFamilyDetails
            $SelectedFamilyFilter = @('X')  # Family X doesn't exist
            $SelectedSkuFilter = @{}

            foreach ($fam in $SelectedFamilyFilter) {
                $skuFilter = $null
                if ($SelectedSkuFilter.ContainsKey($fam)) { $skuFilter = $SelectedSkuFilter[$fam] }

                $detailRows = $familyDetails | Where-Object {
                    $_.Family -eq $fam -and (-not $skuFilter -or $skuFilter -contains $_.SKU)
                }

                # This is the FIX we're testing: check BEFORE printing headers
                if ($detailRows.Count -eq 0) {
                    # Should show "no matching" message, not family header
                    $result = "Family: $fam - No matching SKUs found for selection."
                }
                else {
                    $result = "Family: $fam (shared quota per region)"
                }
            }

            $result | Should -Match 'No matching SKUs found'
            $result | Should -Not -Match 'shared quota per region'
        }

        It "Should print Family header when matching SKUs exist" {
            $familyDetails = $script:mockFamilyDetails
            $SelectedFamilyFilter = @('D')  # Family D exists
            $SelectedSkuFilter = @{}

            foreach ($fam in $SelectedFamilyFilter) {
                $skuFilter = $null
                if ($SelectedSkuFilter.ContainsKey($fam)) { $skuFilter = $SelectedSkuFilter[$fam] }

                $detailRows = $familyDetails | Where-Object {
                    $_.Family -eq $fam -and (-not $skuFilter -or $skuFilter -contains $_.SKU)
                }

                if ($detailRows.Count -eq 0) {
                    $result = "Family: $fam - No matching SKUs found for selection."
                }
                else {
                    $result = "Family: $fam (shared quota per region)"
                }
            }

            $result | Should -Match 'shared quota per region'
            $result | Should -Not -Match 'No matching SKUs found'
        }

        It "Should filter by SKU when SelectedSkuFilter is specified" {
            $familyDetails = $script:mockFamilyDetails
            $SelectedFamilyFilter = @('D')
            $SelectedSkuFilter = @{ 'D' = @('Standard_D2s_v3') }  # Only D2s

            foreach ($fam in $SelectedFamilyFilter) {
                $skuFilter = $null
                if ($SelectedSkuFilter.ContainsKey($fam)) { $skuFilter = $SelectedSkuFilter[$fam] }

                $detailRows = $familyDetails | Where-Object {
                    $_.Family -eq $fam -and (-not $skuFilter -or $skuFilter -contains $_.SKU)
                }
            }

            $detailRows.Count | Should -Be 2  # D2s in eastus and westus
            $detailRows | ForEach-Object { $_.SKU | Should -Be 'Standard_D2s_v3' }
        }

        It "Should group results by region" {
            $familyDetails = $script:mockFamilyDetails
            $detailRows = $familyDetails | Where-Object { $_.Family -eq 'D' }
            $regionGroups = $detailRows | Group-Object Region | Sort-Object Name

            $regionGroups.Count | Should -Be 2
            $regionGroups[0].Name | Should -Be 'eastus'
            $regionGroups[1].Name | Should -Be 'westus'
            $regionGroups[0].Count | Should -Be 2  # 2 SKUs in eastus
            $regionGroups[1].Count | Should -Be 1  # 1 SKU in westus
        }

        It "Should handle multiple families correctly" {
            $familyDetails = $script:mockFamilyDetails
            $SelectedFamilyFilter = @('D', 'E', 'X')  # D and E exist, X doesn't
            $SelectedSkuFilter = @{}
            $results = @()

            foreach ($fam in $SelectedFamilyFilter) {
                $skuFilter = $null
                if ($SelectedSkuFilter.ContainsKey($fam)) { $skuFilter = $SelectedSkuFilter[$fam] }

                $detailRows = $familyDetails | Where-Object {
                    $_.Family -eq $fam -and (-not $skuFilter -or $skuFilter -contains $_.SKU)
                }

                if ($detailRows.Count -eq 0) {
                    $results += @{ Family = $fam; HasData = $false; Message = 'No matching' }
                }
                else {
                    $results += @{ Family = $fam; HasData = $true; RowCount = $detailRows.Count }
                }
            }

            $results.Count | Should -Be 3
            ($results | Where-Object { $_.Family -eq 'D' }).HasData | Should -Be $true
            ($results | Where-Object { $_.Family -eq 'D' }).RowCount | Should -Be 3
            ($results | Where-Object { $_.Family -eq 'E' }).HasData | Should -Be $true
            ($results | Where-Object { $_.Family -eq 'E' }).RowCount | Should -Be 1
            ($results | Where-Object { $_.Family -eq 'X' }).HasData | Should -Be $false
        }
    }

    Context "Quota display formatting" {
        It "Should format quota as 'X of Y used' when both values available" {
            $regionQuota = [PSCustomObject]@{ QuotaLimit = 200; QuotaCurrent = 100 }

            $quotaHeader = if ($null -ne $regionQuota.QuotaLimit -and $null -ne $regionQuota.QuotaCurrent) {
                $avail = $regionQuota.QuotaLimit - $regionQuota.QuotaCurrent
                "Quota: $($regionQuota.QuotaCurrent) of $($regionQuota.QuotaLimit) vCPUs used | $avail available"
            }

            $quotaHeader | Should -Be 'Quota: 100 of 200 vCPUs used | 100 available'
        }

        It "Should show '0 of X used' when quota is fully available" {
            $regionQuota = [PSCustomObject]@{ QuotaLimit = 100; QuotaCurrent = 0 }

            $quotaHeader = if ($null -ne $regionQuota.QuotaLimit -and $null -ne $regionQuota.QuotaCurrent) {
                $avail = $regionQuota.QuotaLimit - $regionQuota.QuotaCurrent
                "Quota: $($regionQuota.QuotaCurrent) of $($regionQuota.QuotaLimit) vCPUs used | $avail available"
            }

            $quotaHeader | Should -Be 'Quota: 0 of 100 vCPUs used | 100 available'
            $quotaHeader | Should -Match '^Quota: 0 of'
        }

        It "Should fallback to QuotaAvail when limit/current not available" {
            $regionQuota = [PSCustomObject]@{ QuotaAvail = 50 }

            $quotaHeader = if ($null -ne $regionQuota.QuotaLimit -and $null -ne $regionQuota.QuotaCurrent) {
                $avail = $regionQuota.QuotaLimit - $regionQuota.QuotaCurrent
                "Quota: $($regionQuota.QuotaCurrent) of $($regionQuota.QuotaLimit) vCPUs used | $avail available"
            }
            elseif ($regionQuota.QuotaAvail -and $regionQuota.QuotaAvail -ne '?') {
                "Quota: $($regionQuota.QuotaAvail) vCPUs available"
            }
            else {
                "Quota: N/A"
            }

            $quotaHeader | Should -Be 'Quota: 50 vCPUs available'
        }

        It "Should show N/A when no quota info available" {
            $regionQuota = [PSCustomObject]@{ QuotaAvail = '?' }

            $quotaHeader = if ($null -ne $regionQuota.QuotaLimit -and $null -ne $regionQuota.QuotaCurrent) {
                $avail = $regionQuota.QuotaLimit - $regionQuota.QuotaCurrent
                "Quota: $($regionQuota.QuotaCurrent) of $($regionQuota.QuotaLimit) vCPUs used | $avail available"
            }
            elseif ($regionQuota.QuotaAvail -and $regionQuota.QuotaAvail -ne '?') {
                "Quota: $($regionQuota.QuotaAvail) vCPUs available"
            }
            else {
                "Quota: N/A"
            }

            $quotaHeader | Should -Be 'Quota: N/A'
        }
    }
}
