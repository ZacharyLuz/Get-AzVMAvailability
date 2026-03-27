BeforeAll {
    Import-Module "$PSScriptRoot\TestHarness.psm1" -Force
    . ([scriptblock]::Create((Get-MainScriptFunctionDefinition -FunctionName 'Get-SkuSimilarityScore')))
    . ([scriptblock]::Create((Get-MainScriptVariableAssignment -VariableName 'FamilyInfo' -ScopePrefix 'script')))
    $script:TestFamilyInfo = $script:FamilyInfo
}

Describe 'Get-SkuSimilarityScore' {
    Context 'Identical profiles' {
        It 'Returns 93 for identical SKU profiles (version same = 5/12)' {
            $skuProfile = @{
                vCPU             = 64
                MemoryGB         = 512
                Family           = 'E'
                FamilyVersion    = 5
                Generation       = 'V1,V2'
                Architecture     = 'x64'
                PremiumIO        = $true
                UncachedDiskIOPS = 80000
                MaxDataDiskCount = 32
            }
            Get-SkuSimilarityScore -Target $skuProfile -Candidate $skuProfile | Should -Be 93
        }

        It 'Returns 98 when candidate is same-family newer version with identical specs' {
            $target = @{
                vCPU             = 64
                MemoryGB         = 512
                Family           = 'E'
                FamilyVersion    = 3
                Generation       = 'V1,V2'
                Architecture     = 'x64'
                PremiumIO        = $true
                UncachedDiskIOPS = 80000
                MaxDataDiskCount = 32
            }
            $candidate = @{
                vCPU             = 64
                MemoryGB         = 512
                Family           = 'E'
                FamilyVersion    = 5
                Generation       = 'V1,V2'
                Architecture     = 'x64'
                PremiumIO        = $true
                UncachedDiskIOPS = 80000
                MaxDataDiskCount = 32
            }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 98
        }
    }

    Context 'vCPU scoring' {
        It 'Gives 20 points for exact vCPU match (plus 15 for no IOPS/disk data)' {
            $target = @{ vCPU = 64; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 64; MemoryGB = 0; Family = 'Z'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 35
        }

        It 'Gives partial points for close vCPU count' {
            $target = @{ vCPU = 64; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 48; MemoryGB = 0; Family = 'Z'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $score = Get-SkuSimilarityScore -Target $target -Candidate $candidate
            $score | Should -BeGreaterThan 15
            $score | Should -BeLessThan 35
        }

        It 'Gives 0 vCPU points when candidate has 0 vCPU (only IOPS/disk bonus)' {
            $target = @{ vCPU = 64; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'Z'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 15
        }
    }

    Context 'Memory scoring' {
        It 'Gives 20 points for exact memory match (plus 15 for no IOPS/disk data)' {
            $target = @{ vCPU = 0; MemoryGB = 512; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 0; MemoryGB = 512; Family = 'Z'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 35
        }

        It 'Gives partial points for close memory' {
            $target = @{ vCPU = 0; MemoryGB = 512; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 0; MemoryGB = 384; Family = 'Z'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $score = Get-SkuSimilarityScore -Target $target -Candidate $candidate
            $score | Should -BeGreaterThan 15
            $score | Should -BeLessThan 35
        }
    }

    Context 'Family scoring' {
        It 'Gives 18 points for same family plus 5 version same-gen bonus (plus 15 for no IOPS/disk data)' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'E'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'E'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 38
        }

        It 'Gives 13 points for same category (Memory: E vs M) plus 15 bonus' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'E'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'M'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate -FamilyInfo $script:TestFamilyInfo | Should -Be 28
        }

        It 'Gives 13 points for EC vs E (same Memory category) plus 15 bonus' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'EC'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'E'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate -FamilyInfo $script:TestFamilyInfo | Should -Be 28
        }

        It 'Gives 0 family points for different family and category (only 15 bonus)' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'E'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'F'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 15
        }
    }

    Context 'Version newness replaces HyperV generation scoring' {
        It 'Cross-family v1 candidates get 0 version points (only 15 bonus)' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'X'; Generation = 'V1,V2'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'Z'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 15
        }

        It 'Cross-family v6 gets 9 version points (plus 15 bonus)' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'X'; FamilyVersion = 2; Generation = 'V2'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'Z'; FamilyVersion = 6; Generation = 'V1'; Architecture = 'Arm64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 24
        }

        It 'Cross-family v7 gets 10 version points (plus 15 bonus)' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'X'; FamilyVersion = 2; Generation = 'V2'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'Z'; FamilyVersion = 7; Generation = 'V1'; Architecture = 'Arm64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 25
        }
    }

    Context 'Architecture scoring' {
        It 'Gives 10 points for matching architecture (plus 15 bonus)' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'Z'; Generation = 'V2'; Architecture = 'x64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 25
        }

        It 'Gives 0 arch points for mismatched architecture (only 15 bonus)' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'Z'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 15
        }
    }

    Context 'Premium IO scoring' {
        It 'Gives 5 points when both support premium IO (plus 15 bonus)' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'Z'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 20
        }

        It 'Gives 0 points when target needs premium but candidate lacks it (only 15 bonus)' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'Z'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 15
        }

        It 'Gives 5 points when target does not need premium (plus 15 bonus)' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'Z'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 20
        }
    }

    Context 'Combined scoring' {
        It 'Same category with exact specs beats same family with fewer cores' {
            $target = @{ vCPU = 64; MemoryGB = 512; Family = 'E'; FamilyVersion = 2; Generation = 'V2'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 80000; MaxDataDiskCount = 32 }

            $sameFamily = @{ vCPU = 48; MemoryGB = 384; Family = 'E'; FamilyVersion = 2; Generation = 'V2'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 60000; MaxDataDiskCount = 32 }
            $diffFamily = @{ vCPU = 64; MemoryGB = 512; Family = 'M'; FamilyVersion = 2; Generation = 'V2'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 80000; MaxDataDiskCount = 32 }

            $scoreSameFamily = Get-SkuSimilarityScore -Target $target -Candidate $sameFamily -FamilyInfo $script:TestFamilyInfo
            $scoreDiffFamily = Get-SkuSimilarityScore -Target $target -Candidate $diffFamily -FamilyInfo $script:TestFamilyInfo

            $scoreDiffFamily | Should -BeGreaterThan $scoreSameFamily
        }

        It 'Architecture mismatch reduces score by 10 points' {
            $target = @{ vCPU = 64; MemoryGB = 512; Family = 'E'; Generation = 'V2'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 80000; MaxDataDiskCount = 32 }

            $matchArch = @{ vCPU = 64; MemoryGB = 512; Family = 'E'; Generation = 'V2'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 80000; MaxDataDiskCount = 32 }
            $wrongArch = @{ vCPU = 64; MemoryGB = 512; Family = 'E'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $true; UncachedDiskIOPS = 80000; MaxDataDiskCount = 32 }

            $scoreMatch = Get-SkuSimilarityScore -Target $target -Candidate $matchArch
            $scoreWrong = Get-SkuSimilarityScore -Target $target -Candidate $wrongArch

            ($scoreMatch - $scoreWrong) | Should -Be 10
        }

        It 'Never exceeds 100' {
            $vmProfile = @{ vCPU = 64; MemoryGB = 512; Family = 'E'; FamilyVersion = 5; Generation = 'V2'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 80000; MaxDataDiskCount = 32 }
            Get-SkuSimilarityScore -Target $vmProfile -Candidate $vmProfile | Should -BeLessOrEqual 100
        }
    }

    Context 'Family version scoring' {
        It 'Gives 10 points for same-family v5 upgrade (8+2 bonus, plus 18 family and 15 IOPS/disk)' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'D'; FamilyVersion = 2; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'D'; FamilyVersion = 5; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 43
        }

        It 'Gives 12 points for same-family v7 upgrade (8+4 bonus, plus 18 family and 15 IOPS/disk)' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'D'; FamilyVersion = 2; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'D'; FamilyVersion = 7; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 45
        }

        It 'Gives 5 points for same-family same version (plus 18 family and 15 IOPS/disk)' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'D'; FamilyVersion = 3; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'D'; FamilyVersion = 3; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 38
        }

        It 'Gives 1 point for same-family version downgrade (plus 18 family and 15 IOPS/disk)' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'D'; FamilyVersion = 5; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'D'; FamilyVersion = 2; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 34
        }

        It 'Cross-family v5 candidate gets 7 version points (plus 15 bonus)' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'E'; FamilyVersion = 3; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'D'; FamilyVersion = 5; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 22
        }

        It 'Cross-family v1 candidate gets 0 version points (only 15 bonus)' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'E'; FamilyVersion = 3; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'D'; FamilyVersion = 1; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 15
        }

        It 'Same-family v5 upgrade beats same-family v2 lateral move' {
            $target = @{ vCPU = 4; MemoryGB = 16; Family = 'D'; FamilyVersion = 2; Generation = 'V1,V2'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 6400; MaxDataDiskCount = 8 }
            $v5upgrade = @{ vCPU = 4; MemoryGB = 16; Family = 'D'; FamilyVersion = 5; Generation = 'V1,V2'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 6400; MaxDataDiskCount = 8 }
            $v2lateral = @{ vCPU = 4; MemoryGB = 16; Family = 'D'; FamilyVersion = 2; Generation = 'V1,V2'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 6400; MaxDataDiskCount = 8 }

            $scoreV5 = Get-SkuSimilarityScore -Target $target -Candidate $v5upgrade
            $scoreV2 = Get-SkuSimilarityScore -Target $target -Candidate $v2lateral

            $scoreV5 | Should -BeGreaterThan $scoreV2
            ($scoreV5 - $scoreV2) | Should -Be 5
        }

        It 'Same-family v7 upgrade scores higher than v5 upgrade' {
            $target = @{ vCPU = 4; MemoryGB = 16; Family = 'D'; FamilyVersion = 2; Generation = 'V1,V2'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 6400; MaxDataDiskCount = 8 }
            $v7upgrade = @{ vCPU = 4; MemoryGB = 16; Family = 'D'; FamilyVersion = 7; Generation = 'V1,V2'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 6400; MaxDataDiskCount = 8 }
            $v5upgrade = @{ vCPU = 4; MemoryGB = 16; Family = 'D'; FamilyVersion = 5; Generation = 'V1,V2'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 6400; MaxDataDiskCount = 8 }

            $scoreV7 = Get-SkuSimilarityScore -Target $target -Candidate $v7upgrade
            $scoreV5 = Get-SkuSimilarityScore -Target $target -Candidate $v5upgrade

            $scoreV7 | Should -BeGreaterThan $scoreV5
            ($scoreV7 - $scoreV5) | Should -Be 2
        }
    }
}
