BeforeAll {
    Import-Module "$PSScriptRoot\TestHarness.psm1" -Force
    . ([scriptblock]::Create((Get-MainScriptFunctionDefinition -FunctionName 'Get-SkuSimilarityScore')))
    . ([scriptblock]::Create((Get-MainScriptVariableAssignment -VariableName 'FamilyInfo' -ScopePrefix 'script')))
}

Describe 'Get-SkuSimilarityScore' {
    Context 'Identical profiles' {
        It 'Returns 100 for identical SKU profiles' {
            $skuProfile = @{
                vCPU         = 64
                MemoryGB     = 512
                Family       = 'E'
                Generation   = 'V1,V2'
                Architecture = 'x64'
                PremiumIO    = $true
            }
            Get-SkuSimilarityScore -Target $skuProfile -Candidate $skuProfile | Should -Be 100
        }
    }

    Context 'vCPU scoring' {
        It 'Gives 25 points for exact vCPU match' {
            $target = @{ vCPU = 64; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true }
            $candidate = @{ vCPU = 64; MemoryGB = 0; Family = 'Z'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 25
        }

        It 'Gives partial points for close vCPU count' {
            $target = @{ vCPU = 64; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true }
            $candidate = @{ vCPU = 48; MemoryGB = 0; Family = 'Z'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false }
            $score = Get-SkuSimilarityScore -Target $target -Candidate $candidate
            $score | Should -BeGreaterThan 0
            $score | Should -BeLessThan 25
        }

        It 'Gives 0 vCPU points when candidate has 0 vCPU' {
            $target = @{ vCPU = 64; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'Z'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 0
        }
    }

    Context 'Memory scoring' {
        It 'Gives 25 points for exact memory match' {
            $target = @{ vCPU = 0; MemoryGB = 512; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true }
            $candidate = @{ vCPU = 0; MemoryGB = 512; Family = 'Z'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 25
        }

        It 'Gives partial points for close memory' {
            $target = @{ vCPU = 0; MemoryGB = 512; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true }
            $candidate = @{ vCPU = 0; MemoryGB = 384; Family = 'Z'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false }
            $score = Get-SkuSimilarityScore -Target $target -Candidate $candidate
            $score | Should -BeGreaterThan 0
            $score | Should -BeLessThan 25
        }
    }

    Context 'Family scoring' {
        It 'Gives 20 points for same family' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'E'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'E'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 20
        }

        It 'Gives 15 points for same category (Memory: E vs M)' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'E'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'M'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 15
        }

        It 'Gives 15 points for EC vs E (same Memory category)' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'EC'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'E'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 15
        }

        It 'Gives 0 points for different family and category' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'E'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'F'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 0
        }
    }

    Context 'Generation scoring' {
        It 'Gives 13 points when generations overlap' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'X'; Generation = 'V1,V2'; Architecture = 'x64'; PremiumIO = $true }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'Z'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 13
        }

        It 'Gives 0 points when generations do not overlap' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'X'; Generation = 'V2'; Architecture = 'x64'; PremiumIO = $true }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'Z'; Generation = 'V1'; Architecture = 'Arm64'; PremiumIO = $false }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 0
        }
    }

    Context 'Architecture scoring' {
        It 'Gives 12 points for matching architecture' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'Z'; Generation = 'V2'; Architecture = 'x64'; PremiumIO = $false }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 12
        }

        It 'Gives 0 points for mismatched architecture' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'Z'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 0
        }
    }

    Context 'Premium IO scoring' {
        It 'Gives 5 points when both support premium IO' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'Z'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $true }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 5
        }

        It 'Gives 0 points when target needs premium but candidate lacks it' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'Z'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 0
        }

        It 'Gives 5 points when target does not need premium' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $false }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'Z'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false }
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 5
        }
    }

    Context 'Combined scoring' {
        It 'Same category with exact specs beats same family with fewer cores' {
            $target = @{ vCPU = 64; MemoryGB = 512; Family = 'E'; Generation = 'V2'; Architecture = 'x64'; PremiumIO = $true }

            $sameFamily = @{ vCPU = 48; MemoryGB = 384; Family = 'E'; Generation = 'V2'; Architecture = 'x64'; PremiumIO = $true }
            $diffFamily = @{ vCPU = 64; MemoryGB = 512; Family = 'M'; Generation = 'V2'; Architecture = 'x64'; PremiumIO = $true }

            $scoreSameFamily = Get-SkuSimilarityScore -Target $target -Candidate $sameFamily
            $scoreDiffFamily = Get-SkuSimilarityScore -Target $target -Candidate $diffFamily

            $scoreDiffFamily | Should -BeGreaterThan $scoreSameFamily
        }

        It 'Architecture mismatch reduces score by 12 points' {
            $target = @{ vCPU = 64; MemoryGB = 512; Family = 'E'; Generation = 'V2'; Architecture = 'x64'; PremiumIO = $true }

            $matchArch = @{ vCPU = 64; MemoryGB = 512; Family = 'E'; Generation = 'V2'; Architecture = 'x64'; PremiumIO = $true }
            $wrongArch = @{ vCPU = 64; MemoryGB = 512; Family = 'E'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $true }

            $scoreMatch = Get-SkuSimilarityScore -Target $target -Candidate $matchArch
            $scoreWrong = Get-SkuSimilarityScore -Target $target -Candidate $wrongArch

            ($scoreMatch - $scoreWrong) | Should -Be 12
        }

        It 'Never exceeds 100' {
            $vmProfile = @{ vCPU = 64; MemoryGB = 512; Family = 'E'; Generation = 'V2'; Architecture = 'x64'; PremiumIO = $true }
            Get-SkuSimilarityScore -Target $vmProfile -Candidate $vmProfile | Should -BeLessOrEqual 100
        }
    }
}
