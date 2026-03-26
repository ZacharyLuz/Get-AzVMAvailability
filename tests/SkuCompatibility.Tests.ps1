# SkuCompatibility.Tests.ps1
# Pester tests for Test-SkuCompatibility and enhanced Get-SkuSimilarityScore
# Run with: Invoke-Pester .\tests\SkuCompatibility.Tests.ps1 -Output Detailed

BeforeAll {
    Import-Module "$PSScriptRoot\TestHarness.psm1" -Force
    . ([scriptblock]::Create((Get-MainScriptFunctionDefinition -FunctionName 'Test-SkuCompatibility')))
    . ([scriptblock]::Create((Get-MainScriptFunctionDefinition -FunctionName 'Get-SkuSimilarityScore')))
    . ([scriptblock]::Create((Get-MainScriptVariableAssignment -VariableName 'FamilyInfo' -ScopePrefix 'script')))
    $script:TestFamilyInfo = $script:FamilyInfo
}

Describe 'Test-SkuCompatibility' {
    Context 'Full compatibility' {
        It 'Returns compatible when candidate meets or exceeds all target dimensions' {
            $target = @{
                vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 8; MaxNetworkInterfaces = 2
                AccelNet = $true; PremiumIO = $true; DiskCode = 'SCSI'
                EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false
            }
            $candidate = @{
                vCPU = 8; MemoryGB = 32; MaxDataDiskCount = 16; MaxNetworkInterfaces = 4
                AccelNet = $true; PremiumIO = $true; DiskCode = 'SCSI'
                EphemeralOSDiskSupported = $true; UltraSSDAvailable = $false
            }
            $result = Test-SkuCompatibility -Target $target -Candidate $candidate
            $result.Compatible | Should -BeTrue
            $result.Failures.Count | Should -Be 0
        }

        It 'Returns compatible when candidate exactly matches target' {
            $target = @{
                vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 8; MaxNetworkInterfaces = 2
                AccelNet = $true; PremiumIO = $true; DiskCode = 'SC+T'
                EphemeralOSDiskSupported = $true; UltraSSDAvailable = $true
            }
            $result = Test-SkuCompatibility -Target $target -Candidate $target
            $result.Compatible | Should -BeTrue
        }
    }

    Context 'vCPU checks' {
        It 'Fails when candidate has fewer vCPUs' {
            $target = @{ vCPU = 8; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $candidate = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $result = Test-SkuCompatibility -Target $target -Candidate $candidate
            $result.Compatible | Should -BeFalse
            $result.Failures | Should -Contain 'vCPU: candidate 4 < target 8'
        }

        It 'Fails when candidate exceeds 2x target vCPU' {
            $target = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $candidate = @{ vCPU = 16; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $result = Test-SkuCompatibility -Target $target -Candidate $candidate
            $result.Compatible | Should -BeFalse
            $result.Failures[0] | Should -Match 'licensing risk'
        }

        It 'Passes when candidate is exactly 2x target vCPU' {
            $target = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $candidate = @{ vCPU = 8; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $result = Test-SkuCompatibility -Target $target -Candidate $candidate
            $result.Compatible | Should -BeTrue
        }
    }

    Context 'Memory checks' {
        It 'Fails when candidate has less memory' {
            $target = @{ vCPU = 4; MemoryGB = 32; MaxDataDiskCount = 0; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $candidate = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $result = Test-SkuCompatibility -Target $target -Candidate $candidate
            $result.Compatible | Should -BeFalse
            $result.Failures | Should -Contain 'MemoryGB: candidate 16 < target 32'
        }
    }

    Context 'Data disk checks' {
        It 'Passes when candidate supports fewer data disks (soft dimension, shown as Disk +/-)' {
            $target = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 32; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $candidate = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 8; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $result = Test-SkuCompatibility -Target $target -Candidate $candidate
            $result.Compatible | Should -BeTrue
        }

        It 'Passes when target has 0 data disks (unknown)' {
            $target = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $candidate = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 8; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $result = Test-SkuCompatibility -Target $target -Candidate $candidate
            $result.Compatible | Should -BeTrue
        }
    }

    Context 'NIC checks' {
        It 'Fails when candidate supports fewer NICs and target has multi-NIC' {
            $target = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 4; AccelNet = $false; PremiumIO = $false; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $candidate = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 2; AccelNet = $false; PremiumIO = $false; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $result = Test-SkuCompatibility -Target $target -Candidate $candidate
            $result.Compatible | Should -BeFalse
            $result.Failures | Should -Contain 'MaxNICs: candidate 2 < target 4'
        }

        It 'Passes NIC check when target uses single NIC' {
            $target = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $candidate = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $result = Test-SkuCompatibility -Target $target -Candidate $candidate
            $result.Compatible | Should -BeTrue
        }
    }

    Context 'Accelerated networking checks' {
        It 'Fails when target requires accel net but candidate lacks it' {
            $target = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 1; AccelNet = $true; PremiumIO = $false; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $candidate = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $result = Test-SkuCompatibility -Target $target -Candidate $candidate
            $result.Compatible | Should -BeFalse
            $result.Failures[0] | Should -Match 'AcceleratedNetworking'
        }
    }

    Context 'Premium IO checks' {
        It 'Fails when target requires premium IO but candidate lacks it' {
            $target = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $true; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $candidate = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $result = Test-SkuCompatibility -Target $target -Candidate $candidate
            $result.Compatible | Should -BeFalse
            $result.Failures[0] | Should -Match 'PremiumIO'
        }
    }

    Context 'Disk interface checks' {
        It 'Fails when target uses NVMe but candidate only has SCSI' {
            $target = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'NVMe'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $candidate = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $result = Test-SkuCompatibility -Target $target -Candidate $candidate
            $result.Compatible | Should -BeFalse
            $result.Failures[0] | Should -Match 'DiskInterface'
        }

        It 'Passes when target uses SCSI and candidate has NVMe' {
            $target = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $candidate = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'NVMe'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $result = Test-SkuCompatibility -Target $target -Candidate $candidate
            $result.Compatible | Should -BeTrue
        }

        It 'Fails when target uses NV+T but candidate only has SC+T' {
            $target = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'NV+T'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $candidate = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'SC+T'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $result = Test-SkuCompatibility -Target $target -Candidate $candidate
            $result.Compatible | Should -BeFalse
        }
    }

    Context 'Ephemeral OS disk checks' {
        It 'Fails when target requires ephemeral OS disk but candidate lacks it' {
            $target = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $true; UltraSSDAvailable = $false }
            $candidate = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $result = Test-SkuCompatibility -Target $target -Candidate $candidate
            $result.Compatible | Should -BeFalse
            $result.Failures[0] | Should -Match 'EphemeralOSDisk'
        }
    }

    Context 'Ultra SSD checks' {
        It 'Fails when target requires Ultra SSD but candidate lacks it' {
            $target = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $true }
            $candidate = @{ vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 0; MaxNetworkInterfaces = 1; AccelNet = $false; PremiumIO = $false; DiskCode = 'SCSI'; EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false }
            $result = Test-SkuCompatibility -Target $target -Candidate $candidate
            $result.Compatible | Should -BeFalse
            $result.Failures[0] | Should -Match 'UltraSSD'
        }
    }

    Context 'Multiple failures' {
        It 'Reports all failures when multiple dimensions are incompatible' {
            $target = @{
                vCPU = 8; MemoryGB = 32; MaxDataDiskCount = 32; MaxNetworkInterfaces = 4
                AccelNet = $true; PremiumIO = $true; DiskCode = 'NVMe'
                EphemeralOSDiskSupported = $true; UltraSSDAvailable = $true
            }
            $candidate = @{
                vCPU = 4; MemoryGB = 16; MaxDataDiskCount = 8; MaxNetworkInterfaces = 2
                AccelNet = $false; PremiumIO = $false; DiskCode = 'SCSI'
                EphemeralOSDiskSupported = $false; UltraSSDAvailable = $false
            }
            $result = Test-SkuCompatibility -Target $target -Candidate $candidate
            $result.Compatible | Should -BeFalse
            $result.Failures.Count | Should -BeGreaterOrEqual 7
        }
    }
}

Describe 'Get-SkuSimilarityScore - Enhanced Weights' {
    Context 'Identical profiles with new dimensions' {
        It 'Returns 93 for identical SKU profiles (version same = 5/12)' {
            $skuProfile = @{
                vCPU = 64; MemoryGB = 512; Family = 'E'; Generation = 'V1,V2'
                Architecture = 'x64'; PremiumIO = $true
                UncachedDiskIOPS = 80000; MaxDataDiskCount = 32
            }
            Get-SkuSimilarityScore -Target $skuProfile -Candidate $skuProfile | Should -Be 93
        }
    }

    Context 'IOPS scoring' {
        It 'Awards points for close IOPS values' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 80000; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 80000; MaxDataDiskCount = 0 }
            $scoreExact = Get-SkuSimilarityScore -Target $target -Candidate $candidate

            $candidateHalf = @{ vCPU = 0; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 40000; MaxDataDiskCount = 0 }
            $scoreHalf = Get-SkuSimilarityScore -Target $target -Candidate $candidateHalf

            $scoreExact | Should -BeGreaterThan $scoreHalf
        }

        It 'Awards full IOPS points when target has no IOPS data' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 0; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 50000; MaxDataDiskCount = 0 }
            $score = Get-SkuSimilarityScore -Target $target -Candidate $candidate
            # Should get: arch(10) + premium(5) + iops(8) + datadisk(7) = 30
            $score | Should -BeGreaterOrEqual 28
        }
    }

    Context 'Data disk count scoring' {
        It 'Awards points for matching disk count' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 32 }
            $exact = @{ vCPU = 0; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 32 }
            $fewer = @{ vCPU = 0; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 8 }

            $scoreExact = Get-SkuSimilarityScore -Target $target -Candidate $exact
            $scoreFewer = Get-SkuSimilarityScore -Target $target -Candidate $fewer
            $scoreExact | Should -BeGreaterThan $scoreFewer
        }
    }

    Context 'Weight rebalancing' {
        It 'vCPU dimension is worth 20 points max' {
            $target = @{ vCPU = 64; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $candidate = @{ vCPU = 64; MemoryGB = 0; Family = 'Z'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            # vCPU exact match (20) + no IOPS data (8) + no disk data (7) = 35
            Get-SkuSimilarityScore -Target $target -Candidate $candidate | Should -Be 35
        }

        It 'Architecture dimension is worth 10 points' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'X'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $matchArch = @{ vCPU = 0; MemoryGB = 0; Family = 'Z'; Generation = 'V2'; Architecture = 'x64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $wrongArch = @{ vCPU = 0; MemoryGB = 0; Family = 'Z'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }

            $scoreMatch = Get-SkuSimilarityScore -Target $target -Candidate $matchArch
            $scoreWrong = Get-SkuSimilarityScore -Target $target -Candidate $wrongArch
            ($scoreMatch - $scoreWrong) | Should -Be 10
        }

        It 'Family + version dimension is worth 23 points for same-family vs unknown' {
            $target = @{ vCPU = 0; MemoryGB = 0; Family = 'E'; Generation = 'V1'; Architecture = 'x64'; PremiumIO = $true; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $sameFamily = @{ vCPU = 0; MemoryGB = 0; Family = 'E'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }
            $diffFamily = @{ vCPU = 0; MemoryGB = 0; Family = 'Z'; Generation = 'V2'; Architecture = 'Arm64'; PremiumIO = $false; UncachedDiskIOPS = 0; MaxDataDiskCount = 0 }

            $scoreSame = Get-SkuSimilarityScore -Target $target -Candidate $sameFamily
            $scoreDiff = Get-SkuSimilarityScore -Target $target -Candidate $diffFamily
            ($scoreSame - $scoreDiff) | Should -Be 23
        }

        It 'Never exceeds 100' {
            $vmProfile = @{
                vCPU = 64; MemoryGB = 512; Family = 'E'; Generation = 'V2'
                Architecture = 'x64'; PremiumIO = $true
                UncachedDiskIOPS = 80000; MaxDataDiskCount = 32
            }
            Get-SkuSimilarityScore -Target $vmProfile -Candidate $vmProfile | Should -BeLessOrEqual 100
        }
    }
}
