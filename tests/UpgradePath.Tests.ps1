BeforeAll {
    Import-Module "$PSScriptRoot\TestHarness.psm1" -Force
    . ([scriptblock]::Create((Get-MainScriptFunctionDefinition -FunctionName 'Get-SkuRetirementInfo')))
}

Describe 'UpgradePath.json Validation' {
    BeforeAll {
        $jsonPath = Join-Path $PSScriptRoot '..' 'data' 'UpgradePath.json'
        $jsonContent = Get-Content -LiteralPath $jsonPath -Raw
        $data = $jsonContent | ConvertFrom-Json
    }

    It 'Is valid JSON' {
        { $jsonContent | ConvertFrom-Json } | Should -Not -Throw
    }

    It 'Has _metadata with required fields' {
        $data._metadata | Should -Not -BeNullOrEmpty
        $data._metadata.version | Should -Not -BeNullOrEmpty
        $data._metadata.lastUpdated | Should -Not -BeNullOrEmpty
        $data._metadata.source | Should -Not -BeNullOrEmpty
    }

    It 'Has _metadata.lastUpdated that is not in the future' {
        $lastUpdated = [datetime]$data._metadata.lastUpdated
        $lastUpdated | Should -BeLessOrEqual ([datetime]::UtcNow.Date.AddDays(1))
    }

    It 'Has _metadata.source URL that is not a known dead link' {
        $data._metadata.source | Should -Not -Match 'sizes/migration-guides'
    }

    It 'Has upgradePaths object' {
        $data.upgradePaths | Should -Not -BeNullOrEmpty
    }

    Context 'Each upgrade path entry has required fields' {
        $entries = $data.upgradePaths.PSObject.Properties
        foreach ($entry in $entries) {
            It "Entry '$($entry.Name)' has family, version, status" {
                $entry.Value.family | Should -Not -BeNullOrEmpty
                $entry.Value.version | Should -Not -BeNullOrEmpty
                $entry.Value.status | Should -BeIn @('Retired', 'Retiring', 'OldGen')
            }

            It "Entry '$($entry.Name)' has retireDate when Retired/Retiring" {
                if ($entry.Value.status -in @('Retired', 'Retiring')) {
                    $entry.Value.retireDate | Should -Not -BeNullOrEmpty
                    { [datetime]$entry.Value.retireDate } | Should -Not -Throw
                }
            }

            It "Entry '$($entry.Name)' has at least one upgrade path (dropIn)" {
                $entry.Value.dropIn | Should -Not -BeNullOrEmpty
                $entry.Value.dropIn.series | Should -Not -BeNullOrEmpty
                $entry.Value.dropIn.sizeMap | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Describe 'UpgradePath.json ↔ Get-SkuRetirementInfo Parity' {
    BeforeAll {
        $jsonPath = Join-Path $PSScriptRoot '..' 'data' 'UpgradePath.json'
        $data = Get-Content -LiteralPath $jsonPath -Raw | ConvertFrom-Json

        # Build a mapping from JSON family key to a representative SKU name for testing
        $familyToTestSku = @{
            'Av1'  = 'Standard_A4'
            'Dv1'  = 'Standard_D4'
            'Dv2'  = 'Standard_D4_v2'
            'Dv3'  = 'Standard_D4s_v3'
            'Ev3'  = 'Standard_E4s_v3'
            'Fv1'  = 'Standard_F4s'
            'Gv1'  = 'Standard_G4'
            'Hv1'  = 'Standard_H8'
            'HBv1' = 'Standard_HB60rs'
            'HCv1' = 'Standard_HC44rs'
            'Lv1'  = 'Standard_L8s'
            'Mv1'  = 'Standard_M64s'
            'NCv1' = 'Standard_NC6'
            'NCv2' = 'Standard_NC6s_v2'
            'NCv3' = 'Standard_NC6s_v3'
            'NDv1' = 'Standard_ND6s'
            'NDv2' = 'Standard_ND40rs_v2'
            'NVv1' = 'Standard_NV6'
            'NVv3' = 'Standard_NV12s_v3'
        }

        # Pre-compute parity results for all families
        $parityResults = @{}
        foreach ($familyKey in $familyToTestSku.Keys) {
            $jsonEntry = $data.upgradePaths.$familyKey
            $testSku = $familyToTestSku[$familyKey]
            $patternResult = Get-SkuRetirementInfo -SkuName $testSku
            $parityResults[$familyKey] = @{
                JsonEntry     = $jsonEntry
                PatternResult = $patternResult
                TestSku       = $testSku
            }
        }
    }

    It 'Av1 retireDate matches' { $parityResults['Av1'].JsonEntry.retireDate | Should -Be $parityResults['Av1'].PatternResult.RetireDate }
    It 'Av1 status matches' { $parityResults['Av1'].JsonEntry.status | Should -Be $parityResults['Av1'].PatternResult.Status }
    It 'Dv1 retireDate matches' { $parityResults['Dv1'].JsonEntry.retireDate | Should -Be $parityResults['Dv1'].PatternResult.RetireDate }
    It 'Dv1 status matches' { $parityResults['Dv1'].JsonEntry.status | Should -Be $parityResults['Dv1'].PatternResult.Status }
    It 'Dv2 retireDate matches' { $parityResults['Dv2'].JsonEntry.retireDate | Should -Be $parityResults['Dv2'].PatternResult.RetireDate }
    It 'Dv2 status matches' { $parityResults['Dv2'].JsonEntry.status | Should -Be $parityResults['Dv2'].PatternResult.Status }
    It 'Fv1 retireDate matches' { $parityResults['Fv1'].JsonEntry.retireDate | Should -Be $parityResults['Fv1'].PatternResult.RetireDate }
    It 'Fv1 status matches' { $parityResults['Fv1'].JsonEntry.status | Should -Be $parityResults['Fv1'].PatternResult.Status }
    It 'Gv1 retireDate matches' { $parityResults['Gv1'].JsonEntry.retireDate | Should -Be $parityResults['Gv1'].PatternResult.RetireDate }
    It 'Gv1 status matches' { $parityResults['Gv1'].JsonEntry.status | Should -Be $parityResults['Gv1'].PatternResult.Status }
    It 'Hv1 retireDate matches' { $parityResults['Hv1'].JsonEntry.retireDate | Should -Be $parityResults['Hv1'].PatternResult.RetireDate }
    It 'Hv1 status matches' { $parityResults['Hv1'].JsonEntry.status | Should -Be $parityResults['Hv1'].PatternResult.Status }
    It 'HBv1 retireDate matches' { $parityResults['HBv1'].JsonEntry.retireDate | Should -Be $parityResults['HBv1'].PatternResult.RetireDate }
    It 'HBv1 status matches' { $parityResults['HBv1'].JsonEntry.status | Should -Be $parityResults['HBv1'].PatternResult.Status }
    It 'HCv1 retireDate matches' { $parityResults['HCv1'].JsonEntry.retireDate | Should -Be $parityResults['HCv1'].PatternResult.RetireDate }
    It 'HCv1 status matches' { $parityResults['HCv1'].JsonEntry.status | Should -Be $parityResults['HCv1'].PatternResult.Status }
    It 'Lv1 retireDate matches' { $parityResults['Lv1'].JsonEntry.retireDate | Should -Be $parityResults['Lv1'].PatternResult.RetireDate }
    It 'Lv1 status matches' { $parityResults['Lv1'].JsonEntry.status | Should -Be $parityResults['Lv1'].PatternResult.Status }
    It 'NCv1 retireDate matches' { $parityResults['NCv1'].JsonEntry.retireDate | Should -Be $parityResults['NCv1'].PatternResult.RetireDate }
    It 'NCv1 status matches' { $parityResults['NCv1'].JsonEntry.status | Should -Be $parityResults['NCv1'].PatternResult.Status }
    It 'NCv2 retireDate matches' { $parityResults['NCv2'].JsonEntry.retireDate | Should -Be $parityResults['NCv2'].PatternResult.RetireDate }
    It 'NCv2 status matches' { $parityResults['NCv2'].JsonEntry.status | Should -Be $parityResults['NCv2'].PatternResult.Status }
    It 'NCv3 retireDate matches' { $parityResults['NCv3'].JsonEntry.retireDate | Should -Be $parityResults['NCv3'].PatternResult.RetireDate }
    It 'NCv3 status matches' { $parityResults['NCv3'].JsonEntry.status | Should -Be $parityResults['NCv3'].PatternResult.Status }
    It 'NDv1 retireDate matches' { $parityResults['NDv1'].JsonEntry.retireDate | Should -Be $parityResults['NDv1'].PatternResult.RetireDate }
    It 'NDv1 status matches' { $parityResults['NDv1'].JsonEntry.status | Should -Be $parityResults['NDv1'].PatternResult.Status }
    It 'NDv2 retireDate matches' { $parityResults['NDv2'].JsonEntry.retireDate | Should -Be $parityResults['NDv2'].PatternResult.RetireDate }
    It 'NDv2 status matches' { $parityResults['NDv2'].JsonEntry.status | Should -Be $parityResults['NDv2'].PatternResult.Status }
    It 'NVv1 retireDate matches' { $parityResults['NVv1'].JsonEntry.retireDate | Should -Be $parityResults['NVv1'].PatternResult.RetireDate }
    It 'NVv1 status matches' { $parityResults['NVv1'].JsonEntry.status | Should -Be $parityResults['NVv1'].PatternResult.Status }
    It 'NVv3 retireDate matches' { $parityResults['NVv3'].JsonEntry.retireDate | Should -Be $parityResults['NVv3'].PatternResult.RetireDate }
    It 'NVv3 status matches' { $parityResults['NVv3'].JsonEntry.status | Should -Be $parityResults['NVv3'].PatternResult.Status }
}
