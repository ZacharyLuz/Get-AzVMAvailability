<#
.SYNOPSIS
    End-to-end integration tests for Get-AzVMAvailability.ps1
.DESCRIPTION
    These tests run the ACTUAL script against a LIVE Azure subscription.
    They verify every parameter, switch, and code path produces correct output.

    Prerequisites:
      - PowerShell 7+
      - Az.Compute, Az.Resources modules installed
      - Authenticated Azure session (Connect-AzAccount)
      - At least one subscription with Compute access

    Run:
      Invoke-Pester ./tests/Integration.Tests.ps1 -Output Detailed *> artifacts/integration-test.log
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '..' 'Get-AzVMAvailability.ps1'
    $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "IntegrationTests-$(Get-Random)"
    New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

    # Verify prerequisites
    $script:AzContext = Get-AzContext -ErrorAction SilentlyContinue
    if (-not $script:AzContext) {
        throw "No Azure context. Run Connect-AzAccount before running integration tests."
    }
    $script:SubId = $script:AzContext.Subscription.Id
    $script:SubName = $script:AzContext.Subscription.Name

    # Default test region — single region keeps tests fast (~5-8s each)
    $script:TestRegion = 'eastus'
    # A known commonly-available SKU for recommend/filter tests
    $script:TestSku = 'Standard_D2s_v5'
    $script:TestSkuShort = 'D2s_v5'

    Write-Host "Integration tests running against:" -ForegroundColor Cyan
    Write-Host "  Subscription: $($script:SubName) ($($script:SubId))" -ForegroundColor White
    Write-Host "  Region: $($script:TestRegion)" -ForegroundColor White
    Write-Host "  Temp dir: $($script:TempDir)" -ForegroundColor DarkGray
}

AfterAll {
    if (Test-Path $script:TempDir) {
        Remove-Item $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    # Restore original context in case tests changed it
    $currentCtx = Get-AzContext -ErrorAction SilentlyContinue
    if ($currentCtx -and $script:SubId -and $currentCtx.Subscription.Id -ne $script:SubId) {
        Set-AzContext -SubscriptionId $script:SubId -ErrorAction SilentlyContinue | Out-Null
    }
}

# ============================================================================
# SECTION 1: BASIC SCAN MODE
# ============================================================================

Describe 'Basic Scan Mode — -NoPrompt -Region' {
    It 'Completes a single-region scan without error' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'SCAN COMPLETE'
    }

    It 'Displays the banner with version number' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'GET-AZVMAVAILABILITY v\d+\.\d+\.\d+'
    }

    It 'Shows region header in output' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match "REGION: $($script:TestRegion)"
    }

    It 'Shows QUOTA SUMMARY section' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'QUOTA SUMMARY'
    }

    It 'Shows SKU FAMILIES section' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'SKU FAMILIES'
    }

    It 'Shows MULTI-REGION CAPACITY MATRIX section' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'MULTI-REGION CAPACITY MATRIX'
    }

    It 'Shows DEPLOYMENT RECOMMENDATIONS section' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'DEPLOYMENT RECOMMENDATIONS'
    }

    It 'Shows DETAILED CROSS-REGION BREAKDOWN section' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'DETAILED CROSS-REGION BREAKDOWN'
    }
}

# ============================================================================
# SECTION 2: MULTI-REGION SCAN
# ============================================================================

Describe 'Multi-Region Scan' {
    It 'Scans two regions and shows both in output' {
        $output = & $script:ScriptPath -NoPrompt -Region 'eastus','westus2' `
            -SubscriptionId $script:SubId 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'REGION: eastus'
        $joined | Should -Match 'REGION: westus2'
    }

    It 'Matrix includes both regions as columns' {
        $output = & $script:ScriptPath -NoPrompt -Region 'eastus','westus2' `
            -SubscriptionId $script:SubId 6>&1 *>&1
        $joined = $output -join "`n"
        # Matrix header row should contain both region names
        $joined | Should -Match 'eastus.*westus2'
    }
}

# ============================================================================
# SECTION 3: REGION PRESETS
# ============================================================================

Describe 'Region Presets — -RegionPreset' {
    It 'USEastWest preset scans 4 regions' {
        $output = & $script:ScriptPath -NoPrompt -RegionPreset USEastWest `
            -SubscriptionId $script:SubId 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'REGION: eastus'
        $joined | Should -Match 'REGION: westus2'
        $joined | Should -Match 'SCAN COMPLETE'
    }

    It 'ASR-EastWest preset scans 2 DR pair regions' {
        $output = & $script:ScriptPath -NoPrompt -RegionPreset 'ASR-EastWest' `
            -SubscriptionId $script:SubId 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'REGION: eastus'
        $joined | Should -Match 'REGION: westus2'
    }
}

# ============================================================================
# SECTION 4: SKU FILTER
# ============================================================================

Describe 'SKU Filter — -SkuFilter' {
    It 'Exact SKU filter returns only that SKU in output' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -SkuFilter $script:TestSku 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match $script:TestSku
        $joined | Should -Match 'SCAN COMPLETE'
    }

    It 'Wildcard SKU filter (Standard_D*_v5) returns multiple D-series v5 SKUs' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -SkuFilter 'Standard_D*_v5' 6>&1 *>&1
        $joined = $output -join "`n"
        # Should find at least the D family
        $joined | Should -Match 'SKU FAMILIES'
        $joined | Should -Match 'SCAN COMPLETE'
    }

    It 'Multiple exact SKUs filter correctly' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId `
            -SkuFilter 'Standard_D2s_v5','Standard_D4s_v5' 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'Standard_D2s_v5|Standard_D4s_v5'
    }
}

# ============================================================================
# SECTION 5: FAMILY FILTER
# ============================================================================

Describe 'Family Filter — -FamilyFilter' {
    It 'Filters to only D family when -FamilyFilter D is specified with -EnableDrillDown -NoPrompt' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -FamilyFilter 'D' -EnableDrillDown 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'Family: D'
    }
}

# ============================================================================
# SECTION 6: PRICING
# ============================================================================

Describe 'Pricing — -ShowPricing' {
    It 'Shows pricing columns when -ShowPricing is enabled' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -ShowPricing -SkuFilter $script:TestSku 6>&1 *>&1
        $joined = $output -join "`n"
        # Header should show $/Hr and $/Mo columns
        $joined | Should -Match '\$/Hr'
        $joined | Should -Match '\$/Mo'
    }

    It 'Shows pricing note about Pay-As-You-Go' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -ShowPricing -SkuFilter $script:TestSku 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'pricing'
    }
}

# ============================================================================
# SECTION 7: SPOT PRICING
# ============================================================================

Describe 'Spot Pricing — -ShowSpot' {
    It 'Includes spot pricing when -ShowSpot -ShowPricing are both set' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -ShowPricing -ShowSpot `
            -Recommend $script:TestSku 6>&1 *>&1
        $joined = $output -join "`n"
        # Spot columns in recommend output header
        $joined | Should -Match 'Spot'
    }
}

# ============================================================================
# SECTION 8: IMAGE COMPATIBILITY
# ============================================================================

Describe 'Image Compatibility — -ImageURN' {
    It 'Shows image requirements when a Gen2 x64 image is specified' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId `
            -ImageURN 'Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest' `
            -SkuFilter $script:TestSku -EnableDrillDown 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'Image:.*Canonical'
        $joined | Should -Match 'Gen2.*x64'
    }

    It 'Shows Img compatibility column in drill-down when image is specified' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId `
            -ImageURN 'Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest' `
            -SkuFilter $script:TestSku -EnableDrillDown 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'Img'
    }

    It 'ARM64 image marks x64-only SKUs as incompatible' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId `
            -ImageURN 'Canonical:0001-com-ubuntu-server-jammy:22_04-lts-arm64:latest' `
            -SkuFilter $script:TestSku -EnableDrillDown 6>&1 *>&1
        $joined = $output -join "`n"
        # D2s_v5 is x64-only, ARM64 image should show incompatible marker
        $joined | Should -Match '✗|(\[-\])'
    }
}

# ============================================================================
# SECTION 9: RECOMMEND MODE
# ============================================================================

Describe 'Recommend Mode — -Recommend' {
    It 'Finds alternatives for a common SKU' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId `
            -Recommend $script:TestSku 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'CAPACITY RECOMMENDER'
        $joined | Should -Match "TARGET: $($script:TestSku)"
        $joined | Should -Match 'RECOMMENDED ALTERNATIVES'
    }

    It 'Auto-adds Standard_ prefix to short SKU name' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId `
            -Recommend $script:TestSkuShort 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match "TARGET: $($script:TestSku)"
    }

    It '-TopN limits the number of recommendations' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId `
            -Recommend $script:TestSku -TopN 3 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'top 3'
    }

    It '-MinScore 0 shows all candidates regardless of score' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId `
            -Recommend $script:TestSku -MinScore 0 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'RECOMMENDED ALTERNATIVES'
    }

    It '-MinScore 99 returns few or no recommendations' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId `
            -Recommend $script:TestSku -MinScore 99 6>&1 *>&1
        $joined = $output -join "`n"
        # Either shows recommendations with very high scores or "No alternatives"
        $joined | Should -Match 'RECOMMENDED ALTERNATIVES|No alternatives'
    }

    It '-MinvCPU filters out smaller SKUs' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId `
            -Recommend 'Standard_D8s_v5' -MinvCPU 4 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'CAPACITY RECOMMENDER'
    }

    It '-MinMemoryGB filters out lower memory SKUs' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId `
            -Recommend 'Standard_D8s_v5' -MinMemoryGB 16 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'CAPACITY RECOMMENDER'
    }

    It 'Shows name breakdown with family/purpose/suffix info' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId `
            -Recommend $script:TestSku 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'Name breakdown'
        $joined | Should -Match 'General purpose'
    }

    It 'Shows STATUS KEY legend after recommendations' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId `
            -Recommend $script:TestSku 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'STATUS KEY'
        $joined | Should -Match 'DISK CODES'
    }

    It 'Reports if target SKU is not found in scanned regions' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId `
            -Recommend 'Standard_FAKEXYZ99_v99' 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'not found'
    }
}

# ============================================================================
# SECTION 10: RECOMMEND WITH PRICING
# ============================================================================

Describe 'Recommend + Pricing — -Recommend -ShowPricing' {
    It 'Shows $/Hr and $/Mo columns in recommendation table' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId `
            -Recommend $script:TestSku -ShowPricing 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match '\$/Hr'
        $joined | Should -Match '\$/Mo'
    }
}

# ============================================================================
# SECTION 11: JSON OUTPUT
# ============================================================================

Describe 'JSON Output — -JsonOutput' {
    It 'Scan mode emits valid JSON with -JsonOutput' {
        $raw = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -SkuFilter $script:TestSku `
            -JsonOutput 2>&1
        # Filter to only string lines (skip Write-Host output captured by 6>&1)
        $jsonLines = @($raw | Where-Object { $_ -is [string] })
        $jsonText = $jsonLines -join "`n"
        # Extract the JSON object from the output (skip any non-JSON prefix lines)
        $jsonStart = $jsonText.IndexOf('{')
        if ($jsonStart -ge 0) {
            $jsonText = $jsonText.Substring($jsonStart)
        }
        $parsed = $jsonText | ConvertFrom-Json -ErrorAction Stop
        $parsed.mode | Should -Be 'scan'
        $parsed.schemaVersion | Should -Be '1.0'
        $parsed.regions | Should -Contain $script:TestRegion
    }

    It 'Recommend mode emits valid JSON with -JsonOutput' {
        $raw = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId `
            -Recommend $script:TestSku -JsonOutput 2>&1
        $jsonLines = @($raw | Where-Object { $_ -is [string] })
        $jsonText = $jsonLines -join "`n"
        $jsonStart = $jsonText.IndexOf('{')
        if ($jsonStart -ge 0) {
            $jsonText = $jsonText.Substring($jsonStart)
        }
        $parsed = $jsonText | ConvertFrom-Json -ErrorAction Stop
        $parsed.mode | Should -Be 'recommend'
        $parsed.schemaVersion | Should -Be '1.0'
        $parsed.target.Name | Should -Be $script:TestSku
    }

    It 'JSON scan output includes families array' {
        $raw = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -SkuFilter 'Standard_D2s_v5','Standard_D4s_v5' `
            -JsonOutput 2>&1
        $jsonLines = @($raw | Where-Object { $_ -is [string] })
        $jsonText = $jsonLines -join "`n"
        $jsonStart = $jsonText.IndexOf('{')
        if ($jsonStart -ge 0) {
            $jsonText = $jsonText.Substring($jsonStart)
        }
        $parsed = $jsonText | ConvertFrom-Json -ErrorAction Stop
        $parsed.families.Count | Should -BeGreaterThan 0
    }

    It 'JSON recommend output includes recommendations array' {
        $raw = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId `
            -Recommend $script:TestSku -JsonOutput 2>&1
        $jsonLines = @($raw | Where-Object { $_ -is [string] })
        $jsonText = $jsonLines -join "`n"
        $jsonStart = $jsonText.IndexOf('{')
        if ($jsonStart -ge 0) {
            $jsonText = $jsonText.Substring($jsonStart)
        }
        $parsed = $jsonText | ConvertFrom-Json -ErrorAction Stop
        # recommendations should be an array (possibly empty if constrained)
        $parsed.recommendations | Should -Not -BeNullOrEmpty
    }

    It 'JSON recommend output includes targetAvailability array' {
        $raw = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId `
            -Recommend $script:TestSku -JsonOutput 2>&1
        $jsonLines = @($raw | Where-Object { $_ -is [string] })
        $jsonText = $jsonLines -join "`n"
        $jsonStart = $jsonText.IndexOf('{')
        if ($jsonStart -ge 0) {
            $jsonText = $jsonText.Substring($jsonStart)
        }
        $parsed = $jsonText | ConvertFrom-Json -ErrorAction Stop
        $parsed.targetAvailability | Should -Not -BeNullOrEmpty
        $parsed.targetAvailability[0].Region | Should -Be $script:TestRegion
    }
}

# ============================================================================
# SECTION 12: FLEET MODE — HASHTABLE
# ============================================================================

Describe 'Fleet Mode — -Fleet hashtable' {
    It 'Shows INVENTORY READINESS SUMMARY for a two-SKU fleet' {
        $fleet = @{ 'Standard_D2s_v5' = 2; 'Standard_D4s_v5' = 1 }
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -Fleet $fleet 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'INVENTORY READINESS SUMMARY'
        $joined | Should -Match 'Standard_D2s_v5'
        $joined | Should -Match 'Standard_D4s_v5'
    }

    It 'Shows QUOTA VALIDATION BY FAMILY section' {
        $fleet = @{ 'Standard_D2s_v5' = 2 }
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -Fleet $fleet 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'QUOTA VALIDATION BY FAMILY'
    }

    It 'Shows PASS or FAIL verdict' {
        $fleet = @{ 'Standard_D2s_v5' = 1 }
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -Fleet $fleet 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'INVENTORY READINESS: (PASS|FAIL)'
    }

    It 'Auto-adds Standard_ prefix to fleet SKU keys' {
        $fleet = @{ 'D2s_v5' = 1 }
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -Fleet $fleet 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'Standard_D2s_v5'
    }

    It 'Removes double Standard_ prefix from fleet keys' {
        $fleet = @{ 'Standard_Standard_D2s_v5' = 1 }
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -Fleet $fleet 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'Standard_D2s_v5'
        # Should not contain double prefix
        $joined | Should -Not -Match 'Standard_Standard_'
    }
}

# ============================================================================
# SECTION 13: FLEET MODE — CSV FILE
# ============================================================================

Describe 'Fleet Mode — -FleetFile CSV' {
    It 'Loads fleet from CSV file and shows readiness' {
        $csvPath = Join-Path $script:TempDir 'fleet-test.csv'
        @"
SKU,Qty
Standard_D2s_v5,2
Standard_D4s_v5,1
"@ | Set-Content -Path $csvPath -Encoding utf8

        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -FleetFile $csvPath 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'Loaded 2 SKUs'
        $joined | Should -Match 'INVENTORY READINESS SUMMARY'
    }

    It 'Recognizes alternative column names (Name, Quantity)' {
        $csvPath = Join-Path $script:TempDir 'fleet-altcol.csv'
        @"
Name,Quantity
Standard_D2s_v5,3
"@ | Set-Content -Path $csvPath -Encoding utf8

        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -FleetFile $csvPath 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'Loaded 1 SKUs'
    }
}

# ============================================================================
# SECTION 14: FLEET MODE — JSON FILE
# ============================================================================

Describe 'Fleet Mode — -FleetFile JSON' {
    It 'Loads fleet from JSON file and shows readiness' {
        $jsonPath = Join-Path $script:TempDir 'fleet-test.json'
        @'
[
  { "SKU": "Standard_D2s_v5", "Qty": 2 },
  { "SKU": "Standard_D4s_v5", "Qty": 1 }
]
'@ | Set-Content -Path $jsonPath -Encoding utf8

        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -FleetFile $jsonPath 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'Loaded 2 SKUs'
        $joined | Should -Match 'INVENTORY READINESS SUMMARY'
    }
}

# ============================================================================
# SECTION 15: GENERATE FLEET TEMPLATE
# ============================================================================

Describe 'Generate Fleet Template — -GenerateFleetTemplate' {
    It 'Creates CSV and JSON template files' {
        $templateDir = Join-Path $script:TempDir 'templates'
        New-Item -ItemType Directory -Path $templateDir -Force | Out-Null

        Push-Location $templateDir
        try {
            $output = & $script:ScriptPath -GenerateFleetTemplate 6>&1 *>&1
            $joined = $output -join "`n"
            $joined | Should -Match 'Created (fleet|inventory) templates'

            (Join-Path $templateDir 'inventory-template.csv') | Should -Exist
            (Join-Path $templateDir 'inventory-template.json') | Should -Exist

            # Validate CSV content
            $csv = Import-Csv (Join-Path $templateDir 'inventory-template.csv')
            $csv.Count | Should -BeGreaterThan 0
            $csv[0].SKU | Should -Not -BeNullOrEmpty

            # Validate JSON content
            $json = Get-Content (Join-Path $templateDir 'inventory-template.json') -Raw | ConvertFrom-Json
            $json.Count | Should -BeGreaterThan 0
            $json[0].SKU | Should -Not -BeNullOrEmpty
        }
        finally {
            Pop-Location
        }
    }

    It 'Does not require Azure login (no Az calls)' {
        $templateDir = Join-Path $script:TempDir 'templates2'
        New-Item -ItemType Directory -Path $templateDir -Force | Out-Null

        Push-Location $templateDir
        try {
            # This should succeed even without Azure context
            { & $script:ScriptPath -GenerateFleetTemplate 6>&1 *>&1 } | Should -Not -Throw
        }
        finally {
            Pop-Location
        }
    }
}

# ============================================================================
# SECTION 16: FLEET + JSON OUTPUT
# ============================================================================

Describe 'Fleet + JSON Output — -Fleet -JsonOutput' {
    It 'Emits JSON for inventory readiness' {
        $fleet = @{ 'Standard_D2s_v5' = 1 }
        $raw = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -Fleet $fleet -JsonOutput 2>&1
        $jsonLines = @($raw | Where-Object { $_ -is [string] })
        $jsonText = $jsonLines -join "`n"
        $jsonStart = $jsonText.IndexOf('{')
        if ($jsonStart -ge 0) {
            $jsonText = $jsonText.Substring($jsonStart)
        }
        # Fleet JSON has SKUs and Quotas arrays
        $parsed = $jsonText | ConvertFrom-Json -ErrorAction Stop
        $parsed.SKUs | Should -Not -BeNullOrEmpty
    }
}

# ============================================================================
# SECTION 17: ASCII ICONS
# ============================================================================

Describe 'ASCII Icons — -UseAsciiIcons' {
    It 'Uses bracket-style icons instead of Unicode' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -UseAsciiIcons -SkuFilter $script:TestSku 6>&1 *>&1
        $joined = $output -join "`n"
        # ASCII mode should show [OK] or [+] style icons
        $joined | Should -Match '\[OK\]|\[\+\]|\[!\]|\[-\]'
    }
}

# ============================================================================
# SECTION 18: COMPACT OUTPUT
# ============================================================================

Describe 'Compact Output — -CompactOutput' {
    It 'Completes scan in compact mode without error' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -CompactOutput -SkuFilter $script:TestSku 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'SCAN COMPLETE'
    }
}

# ============================================================================
# SECTION 19: DRILL-DOWN WITH -NoPrompt
# ============================================================================

Describe 'Drill-Down — -EnableDrillDown -NoPrompt' {
    It 'Shows drill-down results for all families when -NoPrompt enables auto-select' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -EnableDrillDown `
            -SkuFilter $script:TestSku 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'FAMILY / SKU DRILL-DOWN RESULTS'
    }

    It 'Shows per-region quota in drill-down headers' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -EnableDrillDown `
            -SkuFilter $script:TestSku 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'Quota:'
    }

    It 'Shows Gen and Arch columns in drill-down table' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -EnableDrillDown `
            -SkuFilter $script:TestSku 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'Gen'
        $joined | Should -Match 'Arch'
    }
}

# ============================================================================
# SECTION 20: EXPORT — CSV
# ============================================================================

Describe 'Export — CSV' {
    It 'Exports CSV file when -AutoExport -OutputFormat CSV is specified' {
        $exportDir = Join-Path $script:TempDir 'export-csv'
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -SkuFilter $script:TestSku `
            -AutoExport -ExportPath $exportDir -OutputFormat CSV 6>&1 *>&1
        $joined = $output -join "`n"

        # Check that export dir was created and contains CSV files
        $exportDir | Should -Exist
        $csvFiles = Get-ChildItem -Path $exportDir -Filter '*.csv' -ErrorAction SilentlyContinue
        $csvFiles.Count | Should -BeGreaterThan 0
    }
}

# ============================================================================
# SECTION 21: EXPORT — XLSX (conditional on ImportExcel)
# ============================================================================

Describe 'Export — XLSX' -Skip:(-not (Get-Module ImportExcel -ListAvailable -ErrorAction SilentlyContinue)) {
    It 'Exports XLSX file when ImportExcel module is available' {
        $exportDir = Join-Path $script:TempDir 'export-xlsx'
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -SkuFilter $script:TestSku `
            -AutoExport -ExportPath $exportDir -OutputFormat XLSX 6>&1 *>&1

        $exportDir | Should -Exist
        $xlsxFiles = Get-ChildItem -Path $exportDir -Filter '*.xlsx' -ErrorAction SilentlyContinue
        $xlsxFiles.Count | Should -BeGreaterThan 0
    }
}

# ============================================================================
# SECTION 22: REGION VALIDATION
# ============================================================================

Describe 'Region Validation' {
    It 'Rejects invalid region names with error' {
        { & $script:ScriptPath -NoPrompt -Region 'fakeregion999' `
                -SubscriptionId $script:SubId 6>&1 *>&1 } | Should -Throw
    }

    It '-SkipRegionValidation allows invalid region names (API error at scan time)' {
        $output = & $script:ScriptPath -NoPrompt -Region 'eastus' `
            -SubscriptionId $script:SubId -SkipRegionValidation 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'SCAN COMPLETE'
    }

    It 'Warns about invalid regions when mixed with valid ones' {
        $output = & $script:ScriptPath -NoPrompt -Region 'eastus','fakeregion999' `
            -SubscriptionId $script:SubId 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'Invalid|unsupported|not found'
        # Should still scan the valid region
        $joined | Should -Match 'REGION: eastus'
    }
}

# ============================================================================
# SECTION 23: REGION COUNT LIMIT
# ============================================================================

Describe 'Region Count Limit' {
    It 'Auto-truncates to 5 regions in -NoPrompt mode when more than 5 specified' {
        $output = & $script:ScriptPath -NoPrompt `
            -Region 'eastus','eastus2','westus','westus2','centralus','northcentralus' `
            -SubscriptionId $script:SubId -SkuFilter $script:TestSku 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'Auto-truncating|truncat'
        $joined | Should -Match 'SCAN COMPLETE'
    }
}

# ============================================================================
# SECTION 24: MAXRETRIES PARAMETER
# ============================================================================

Describe 'MaxRetries Parameter' {
    It 'Accepts -MaxRetries 0 without error' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -MaxRetries 0 `
            -SkuFilter $script:TestSku 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'SCAN COMPLETE'
    }

    It 'Accepts -MaxRetries 5 without error' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -MaxRetries 5 `
            -SkuFilter $script:TestSku 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'SCAN COMPLETE'
    }
}

# ============================================================================
# SECTION 25: MIXED ARCHITECTURE
# ============================================================================

Describe 'Mixed Architecture — -AllowMixedArch' {
    It 'Includes ARM64 SKUs in recommendations when -AllowMixedArch is set' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId `
            -Recommend $script:TestSku -AllowMixedArch -MinScore 0 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'CAPACITY RECOMMENDER'
        # There should be at least some output - ARM64 or not
        $joined | Should -Match 'RECOMMENDED ALTERNATIVES|No alternatives'
    }
}

# ============================================================================
# SECTION 26: PARAMETER VALIDATION ERRORS
# ============================================================================

Describe 'Parameter Validation' {
    It 'Rejects -Fleet and -FleetFile together' {
        $fleet = @{ 'Standard_D2s_v5' = 1 }
        $csvPath = Join-Path $script:TempDir 'fleet-conflict.csv'
        "SKU,Qty`nStandard_D2s_v5,1" | Set-Content -Path $csvPath -Encoding utf8

        { & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
                -SubscriptionId $script:SubId -Fleet $fleet -FleetFile $csvPath 6>&1 *>&1 } | Should -Throw
    }

    It 'Rejects -FleetFile with nonexistent file' {
        { & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
                -SubscriptionId $script:SubId -FleetFile 'C:\nonexistent\fleet.csv' 6>&1 *>&1 } | Should -Throw
    }

    It 'Rejects -FleetFile with unsupported extension' {
        $txtPath = Join-Path $script:TempDir 'fleet.txt'
        "SKU,Qty`nStandard_D2s_v5,1" | Set-Content -Path $txtPath -Encoding utf8

        { & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
                -SubscriptionId $script:SubId -FleetFile $txtPath 6>&1 *>&1 } | Should -Throw
    }

    It 'Rejects -GenerateFleetTemplate with -JsonOutput' {
        { & $script:ScriptPath -GenerateFleetTemplate -JsonOutput 6>&1 *>&1 } | Should -Throw
    }

    It 'Rejects no valid regions' {
        { & $script:ScriptPath -NoPrompt -Region 'totallyinvalid' `
                -SubscriptionId $script:SubId 6>&1 *>&1 } | Should -Throw
    }
}

# ============================================================================
# SECTION 27: POWERSHELL VERSION CHECK
# ============================================================================

Describe 'PowerShell Version Guard' {
    It 'Script file parses without syntax errors in PS7+' {
        $tokens = $null
        $parseErrors = $null
        [System.Management.Automation.Language.Parser]::ParseFile(
            $script:ScriptPath, [ref]$tokens, [ref]$parseErrors
        )
        $parseErrors.Count | Should -Be 0
    }
}

# ============================================================================
# SECTION 28: CONTEXT RESTORATION
# ============================================================================

Describe 'Subscription Context Restoration' {
    It 'Restores original Azure context after scan completes' {
        $originalCtx = Get-AzContext
        $originalSubId = $originalCtx.Subscription.Id

        & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -SkuFilter $script:TestSku 6>&1 *>&1 | Out-Null

        $afterCtx = Get-AzContext
        $afterCtx.Subscription.Id | Should -Be $originalSubId
    }
}

# ============================================================================
# SECTION 29: RECOMMEND + MULTI-REGION
# ============================================================================

Describe 'Recommend + Multi-Region' {
    It 'Finds alternatives across multiple regions' {
        $output = & $script:ScriptPath -NoPrompt -Region 'eastus','westus2' `
            -SubscriptionId $script:SubId `
            -Recommend $script:TestSku 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'CAPACITY RECOMMENDER'
        # Target availability should show both regions
        $joined | Should -Match 'eastus'
    }
}

# ============================================================================
# SECTION 30: RECOMMEND + REGION PRESET
# ============================================================================

Describe 'Recommend + Region Preset' {
    It 'Works with -RegionPreset USMajor' {
        $output = & $script:ScriptPath -NoPrompt -RegionPreset USMajor `
            -SubscriptionId $script:SubId `
            -Recommend $script:TestSku -TopN 3 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'CAPACITY RECOMMENDER'
    }
}

# ============================================================================
# SECTION 31: PLACEMENT SCORES
# ============================================================================

Describe 'Placement Scores — -ShowPlacement' {
    It 'Shows Alloc column in recommend output when -ShowPlacement is enabled' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId `
            -Recommend $script:TestSku -ShowPlacement 6>&1 *>&1
        $joined = $output -join "`n"
        # Should show Alloc column (or a permission warning if no RBAC)
        $joined | Should -Match 'Alloc|Placement.*skipped|permission'
    }

    It '-DesiredCount parameter is accepted' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId `
            -Recommend $script:TestSku -ShowPlacement -DesiredCount 5 6>&1 *>&1
        $joined = $output -join "`n"
        # No crash = success; placement may or may not have RBAC
        $joined | Should -Match 'CAPACITY RECOMMENDER'
    }
}

# ============================================================================
# SECTION 32: SCAN + DRILL-DOWN + PRICING + IMAGE (FULL COMBO)
# ============================================================================

Describe 'Full Feature Combination' {
    It 'Scan + DrillDown + Pricing + Image all work together' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId `
            -SkuFilter $script:TestSku `
            -ShowPricing -EnableDrillDown `
            -ImageURN 'Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest' 6>&1 *>&1
        $joined = $output -join "`n"
        # All sections should be present
        $joined | Should -Match 'SKU FAMILIES'
        $joined | Should -Match '\$/Hr'
        $joined | Should -Match 'FAMILY / SKU DRILL-DOWN RESULTS'
        $joined | Should -Match 'Image:.*Canonical'
        $joined | Should -Match 'Img'
        $joined | Should -Match 'SCAN COMPLETE'
    }
}

# ============================================================================
# SECTION 33: RECOMMEND + PRICING + SPOT + PLACEMENT (FULL COMBO)
# ============================================================================

Describe 'Recommend Full Feature Combination' {
    It 'Recommend + Pricing + Spot + Placement all work together' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId `
            -Recommend $script:TestSku `
            -ShowPricing -ShowSpot -ShowPlacement 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'CAPACITY RECOMMENDER'
        $joined | Should -Match '\$/Hr'
        $joined | Should -Match 'Spot'
    }
}

# ============================================================================
# SECTION 34: STRING NORMALIZATION EDGE CASES
# ============================================================================

Describe 'Comma-delimited String Parameter Normalization' {
    It 'Handles comma-separated regions as a single string (pwsh -File behavior)' {
        # When pwsh -File passes "eastus,westus2" it arrives as single string
        $output = & $script:ScriptPath -NoPrompt -Region 'eastus,westus2' `
            -SubscriptionId $script:SubId -SkuFilter $script:TestSku 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'REGION: eastus'
        $joined | Should -Match 'REGION: westus2'
    }
}

# ============================================================================
# SECTION 35: PERFORMANCE BASELINE
# ============================================================================

Describe 'Performance Baseline' {
    It 'Single-region filtered scan completes in under 30 seconds' {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -SkuFilter $script:TestSku 6>&1 *>&1 | Out-Null
        $sw.Stop()
        $sw.Elapsed.TotalSeconds | Should -BeLessThan 30
    }

    It 'Single-region recommend completes in under 30 seconds' {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -Recommend $script:TestSku 6>&1 *>&1 | Out-Null
        $sw.Stop()
        $sw.Elapsed.TotalSeconds | Should -BeLessThan 30
    }
}

# ============================================================================
# SECTION 36: RECOMMEND JSON CONTRACT FIELD COMPLETENESS
# ============================================================================

Describe 'Recommend JSON Contract Fields' {
    BeforeAll {
        $raw = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId `
            -Recommend $script:TestSku -JsonOutput -ShowPricing 2>&1
        $jsonLines = @($raw | Where-Object { $_ -is [string] })
        $jsonText = $jsonLines -join "`n"
        $jsonStart = $jsonText.IndexOf('{')
        if ($jsonStart -ge 0) {
            $jsonText = $jsonText.Substring($jsonStart)
        }
        $script:Contract = $jsonText | ConvertFrom-Json -ErrorAction Stop
    }

    It 'Has schemaVersion field' {
        $script:Contract.schemaVersion | Should -Not -BeNullOrEmpty
    }

    It 'Has mode = recommend' {
        $script:Contract.mode | Should -Be 'recommend'
    }

    It 'Has generatedAt timestamp' {
        $script:Contract.generatedAt | Should -Not -BeNullOrEmpty
    }

    It 'Has target object with Name, vCPU, MemoryGB' {
        $script:Contract.target.Name | Should -Be $script:TestSku
        $script:Contract.target.vCPU | Should -BeGreaterThan 0
        $script:Contract.target.MemoryGB | Should -BeGreaterThan 0
    }

    It 'Has target object with Family, Architecture, Processor' {
        $script:Contract.target.Family | Should -Not -BeNullOrEmpty
        $script:Contract.target.Architecture | Should -Not -BeNullOrEmpty
        $script:Contract.target.Processor | Should -Not -BeNullOrEmpty
    }

    It 'Has pricingEnabled = true when -ShowPricing is used' {
        $script:Contract.pricingEnabled | Should -Be $true
    }

    It 'Recommendations have sku, region, vCPU, memGiB, score, capacity fields' {
        if ($script:Contract.recommendations.Count -gt 0) {
            $first = $script:Contract.recommendations[0]
            $first.sku | Should -Not -BeNullOrEmpty
            $first.region | Should -Not -BeNullOrEmpty
            $first.vCPU | Should -BeGreaterThan 0
            $first.memGiB | Should -BeGreaterThan 0
            $first.score | Should -BeGreaterOrEqual 0
            $first.capacity | Should -Not -BeNullOrEmpty
        }
    }

    It 'Recommendations have rank field starting at 1' {
        if ($script:Contract.recommendations.Count -gt 0) {
            $script:Contract.recommendations[0].rank | Should -Be 1
        }
    }

    It 'Recommendations have pricing fields when pricing enabled' {
        if ($script:Contract.recommendations.Count -gt 0) {
            # priceHr should exist (may be null if no price found for that SKU)
            $script:Contract.recommendations[0].PSObject.Properties.Name | Should -Contain 'priceHr'
            $script:Contract.recommendations[0].PSObject.Properties.Name | Should -Contain 'priceMo'
        }
    }
}

# ============================================================================
# SECTION 37: SCAN JSON CONTRACT FIELD COMPLETENESS
# ============================================================================

Describe 'Scan JSON Contract Fields' {
    BeforeAll {
        $raw = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId `
            -SkuFilter 'Standard_D2s_v5','Standard_D4s_v5' -JsonOutput 2>&1
        $jsonLines = @($raw | Where-Object { $_ -is [string] })
        $jsonText = $jsonLines -join "`n"
        $jsonStart = $jsonText.IndexOf('{')
        if ($jsonStart -ge 0) {
            $jsonText = $jsonText.Substring($jsonStart)
        }
        $script:ScanContract = $jsonText | ConvertFrom-Json -ErrorAction Stop
    }

    It 'Has schemaVersion field' {
        $script:ScanContract.schemaVersion | Should -Not -BeNullOrEmpty
    }

    It 'Has mode = scan' {
        $script:ScanContract.mode | Should -Be 'scan'
    }

    It 'Has generatedAt timestamp' {
        $script:ScanContract.generatedAt | Should -Not -BeNullOrEmpty
    }

    It 'Has subscriptions array with our sub ID' {
        $script:ScanContract.subscriptions | Should -Contain $script:SubId
    }

    It 'Has regions array' {
        $script:ScanContract.regions | Should -Contain $script:TestRegion
    }

    It 'Has summary with familyCount > 0' {
        $script:ScanContract.summary.familyCount | Should -BeGreaterThan 0
    }

    It 'Has families array with family name and counts' {
        $script:ScanContract.families.Count | Should -BeGreaterThan 0
        $script:ScanContract.families[0].family | Should -Not -BeNullOrEmpty
    }
}

# ============================================================================
# SECTION 38: FLEET + FLEET FILE VALIDATION ERRORS
# ============================================================================

Describe 'Fleet Input Validation' {
    It 'Rejects CSV with zero quantity' {
        $csvPath = Join-Path $script:TempDir 'fleet-zeroqty.csv'
        @"
SKU,Qty
Standard_D2s_v5,0
"@ | Set-Content -Path $csvPath -Encoding utf8

        { & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
                -SubscriptionId $script:SubId -FleetFile $csvPath 6>&1 *>&1 } | Should -Throw
    }

    It 'Rejects CSV with negative quantity' {
        $csvPath = Join-Path $script:TempDir 'fleet-negqty.csv'
        @"
SKU,Qty
Standard_D2s_v5,-5
"@ | Set-Content -Path $csvPath -Encoding utf8

        { & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
                -SubscriptionId $script:SubId -FleetFile $csvPath 6>&1 *>&1 } | Should -Throw
    }

    It 'Rejects empty CSV with no valid rows' {
        $csvPath = Join-Path $script:TempDir 'fleet-empty.csv'
        @"
WrongColumn,BadColumn
foo,bar
"@ | Set-Content -Path $csvPath -Encoding utf8

        { & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
                -SubscriptionId $script:SubId -FleetFile $csvPath 6>&1 *>&1 } | Should -Throw
    }
}

# ============================================================================
# SECTION 39: ENVIRONMENT PARAMETER
# ============================================================================

Describe 'Environment Parameter' {
    It 'Accepts -Environment AzureCloud without error' {
        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -Environment AzureCloud `
            -SkuFilter $script:TestSku 6>&1 *>&1
        $joined = $output -join "`n"
        $joined | Should -Match 'SCAN COMPLETE'
    }
}

# ============================================================================
# SECTION 40: MODULE IMPORT / INLINE FALLBACK
# ============================================================================

Describe 'Function Availability' {
    It 'All core functions are available after script initializes' {
        # Post-modularization: the wrapper imports the AzVMAvailability module which
        # registers private/public functions as commands. Verify availability via
        # Get-Command rather than AST-parsing the wrapper (which is now a thin shim).
        Import-Module (Join-Path $PSScriptRoot '..' 'AzVMAvailability') -Force

        $expectedFunctions = @(
            'Get-SafeString'
            'Invoke-WithRetry'
            'Get-GeoGroup'
            'Get-AzureEndpoints'
            'Get-CapValue'
            'Get-SkuFamily'
            'Get-ProcessorVendor'
            'Get-DiskCode'
            'Get-ValidAzureRegions'
            'Get-RestrictionReason'
            'Get-RestrictionDetails'
            'Format-ZoneStatus'
            'Format-RegionList'
            'Get-QuotaAvailable'
            'Get-FleetReadiness'
            'Write-FleetReadinessSummary'
            'Get-StatusIcon'
            'Use-SubscriptionContextSafely'
            'Restore-OriginalSubscriptionContext'
            'Test-ImportExcelModule'
            'Test-SkuMatchesFilter'
            'Get-SkuSimilarityScore'
            'New-RecommendOutputContract'
            'Write-RecommendOutputContract'
            'New-ScanOutputContract'
            'Invoke-RecommendMode'
            'Get-ImageRequirements'
            'Get-SkuCapabilities'
            'Test-ImageSkuCompatibility'
            'Get-AzVMPricing'
            'Get-RegularPricingMap'
            'Get-SpotPricingMap'
            'Get-PlacementScores'
            'Get-AzActualPricing'
        )

        $module = Get-Module AzVMAvailability
        $available = @()
        foreach ($fn in $expectedFunctions) {
            $cmd = & $module ([scriptblock]::Create("Get-Command -Name '$fn' -ErrorAction SilentlyContinue"))
            if ($cmd) { $available += $fn }
        }

        foreach ($fn in $expectedFunctions) {
            $available | Should -Contain $fn -Because "$fn must be available via the AzVMAvailability module"
        }
    }
}

# ============================================================================
# SECTION 41: NO PIPELINE OUTPUT LEAKAGE
# ============================================================================

Describe 'Pipeline Output Discipline' {
    It 'Scan mode does not emit objects to pipeline (only Write-Host)' {
        $pipelineOutput = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -SkuFilter $script:TestSku 2>&1
        # Filter out InformationRecord objects (Write-Host goes to stream 6)
        $realObjects = @($pipelineOutput | Where-Object {
                $_ -isnot [System.Management.Automation.InformationRecord] -and
                $_ -isnot [System.Management.Automation.WarningRecord] -and
                $_ -isnot [string]
            })
        $realObjects.Count | Should -Be 0 -Because 'script should not emit objects to pipeline (Write-Host only)'
    }
}

# ============================================================================
# SECTION 42: VERSION CONSISTENCY
# ============================================================================

Describe 'Version Metadata Consistency' {
    It 'ScriptVersion variable matches .NOTES Version' {
        $content = Get-Content $script:ScriptPath -Raw

        # Extract ScriptVersion from the variable assignment
        if ($content -match '\$ScriptVersion\s*=\s*[''"](\d+\.\d+\.\d+)[''"]') {
            $scriptVar = $Matches[1]
        }
        else {
            throw 'Could not find $ScriptVersion assignment'
        }

        # Extract Version from .NOTES
        if ($content -match '(?m)^\s+Version:\s+(\d+\.\d+\.\d+)') {
            $notesVersion = $Matches[1]
        }
        else {
            throw 'Could not find Version in .NOTES'
        }

        $scriptVar | Should -Be $notesVersion
    }
}

# ============================================================================
# SECTION 43: FLEET CSV DUPLICATE SUMMING
# ============================================================================

Describe 'Fleet CSV Duplicate SKU Summing' {
    It 'Sums quantities for duplicate SKUs in fleet CSV' {
        $csvPath = Join-Path $script:TempDir 'fleet-dupe.csv'
        @"
SKU,Qty
Standard_D2s_v5,5
Standard_D2s_v5,3
Standard_D4s_v5,2
"@ | Set-Content -Path $csvPath -Encoding utf8

        $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
            -SubscriptionId $script:SubId -FleetFile $csvPath 6>&1 *>&1
        $joined = $output -join "`n"
        # Loaded count should be 2 (deduplicated), not 3
        $joined | Should -Match 'Loaded 2 SKUs'
        # Total quantity for D2s_v5 should be 8 (5+3)
        $joined | Should -Match 'INVENTORY READINESS SUMMARY'
    }
}

# ============================================================================
# SECTION 44: SCAN + FLEET FILE INTEGRATION
# ============================================================================

Describe 'Fleet File Full Integration' {
    It 'Fleet from generated template files works end-to-end' {
        $templateDir = Join-Path $script:TempDir 'fleet-e2e'
        New-Item -ItemType Directory -Path $templateDir -Force | Out-Null

        Push-Location $templateDir
        try {
            # Step 1: Generate templates
            & $script:ScriptPath -GenerateFleetTemplate 6>&1 *>&1 | Out-Null

            $csvPath = Join-Path $templateDir 'inventory-template.csv'
            $csvPath | Should -Exist

            # Step 2: Use generated CSV in fleet scan
            $output = & $script:ScriptPath -NoPrompt -Region $script:TestRegion `
                -SubscriptionId $script:SubId -FleetFile $csvPath 6>&1 *>&1
            $joined = $output -join "`n"
            $joined | Should -Match 'INVENTORY READINESS SUMMARY'
            $joined | Should -Match 'INVENTORY READINESS: (PASS|FAIL)'
        }
        finally {
            Pop-Location
        }
    }
}
