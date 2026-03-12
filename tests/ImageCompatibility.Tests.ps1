# ImageCompatibility.Tests.ps1
# Pester tests for Get-ImageRequirements and Test-ImageSkuCompatibility
# Run with: Invoke-Pester .\tests\ImageCompatibility.Tests.ps1 -Output Detailed

BeforeAll {
    Import-Module "$PSScriptRoot\TestHarness.psm1" -Force
    $functionNames = @(
        'Get-ImageRequirements',
        'Test-ImageSkuCompatibility'
    )

    foreach ($functionName in $functionNames) {
        . ([scriptblock]::Create((Get-MainScriptFunctionDefinition -FunctionName $functionName)))
    }
}

Describe "Get-ImageRequirements" {

    Context "Valid URN parsing" {
        It "Returns Valid=true with Gen1 and x64 for a standard URN" {
            $result = Get-ImageRequirements -ImageURN 'Canonical:UbuntuServer:18.04-LTS:latest'
            $result.Valid | Should -BeTrue
            $result.Gen | Should -Be 'Gen1'
            $result.Arch | Should -Be 'x64'
        }

        It "Parses publisher, offer, and sku from URN" {
            $result = Get-ImageRequirements -ImageURN 'Canonical:UbuntuServer:18.04-LTS:latest'
            $result.Publisher | Should -Be 'Canonical'
            $result.Offer | Should -Be 'UbuntuServer'
            $result.Sku | Should -Be '18.04-LTS'
        }

        It "Detects Gen2 from 'gen2' in SKU name" {
            $result = Get-ImageRequirements -ImageURN 'Canonical:offer:20_04_lts-gen2:latest'
            $result.Gen | Should -Be 'Gen2'
        }

        It "Detects Gen2 from '-g2' in SKU name" {
            $result = Get-ImageRequirements -ImageURN 'Publisher:Offer:sku-g2:latest'
            $result.Gen | Should -Be 'Gen2'
        }

        It "Detects Gen1 explicitly from 'gen1' in SKU name" {
            $result = Get-ImageRequirements -ImageURN 'Publisher:Offer:sku-gen1:latest'
            $result.Gen | Should -Be 'Gen1'
        }

        It "Detects ARM64 architecture and Gen2 from 'arm64' in SKU name" {
            $result = Get-ImageRequirements -ImageURN 'Canonical:jammy:22_04-lts-arm64:latest'
            $result.Arch | Should -Be 'ARM64'
            $result.Gen | Should -Be 'Gen2'
        }

        It "Detects ARM64 architecture from 'aarch64' in SKU name" {
            $result = Get-ImageRequirements -ImageURN 'Publisher:Offer:sku-aarch64:latest'
            $result.Arch | Should -Be 'ARM64'
        }
    }

    Context "Invalid URN format" {
        It "Returns Valid=false for URN with fewer than 3 colon-separated parts (two-part)" {
            $result = Get-ImageRequirements -ImageURN 'Canonical:UbuntuServer'
            $result.Valid | Should -BeFalse
            $result.Error | Should -Not -BeNullOrEmpty
        }

        It "Returns Valid=false for URN with no colons (single segment)" {
            $result = Get-ImageRequirements -ImageURN 'JustAPublisher'
            $result.Valid | Should -BeFalse
        }
    }
}

Describe "Test-ImageSkuCompatibility" {

    Context "Fully compatible" {
        It "Compatible when Gen1 image matches SKU that supports V1" {
            $imageReqs = @{ Gen = 'Gen1'; Arch = 'x64' }
            $caps = @{ HyperVGenerations = 'V1,V2'; CpuArchitecture = 'x64' }
            $result = Test-ImageSkuCompatibility -ImageReqs $imageReqs -SkuCapabilities $caps
            $result.Compatible | Should -BeTrue
            $result.Reason | Should -Be 'OK'
        }

        It "Compatible when Gen2 image matches SKU that supports V2" {
            $imageReqs = @{ Gen = 'Gen2'; Arch = 'x64' }
            $caps = @{ HyperVGenerations = 'V1,V2'; CpuArchitecture = 'x64' }
            $result = Test-ImageSkuCompatibility -ImageReqs $imageReqs -SkuCapabilities $caps
            $result.Compatible | Should -BeTrue
        }

        It "Compatible when ARM64 image matches Arm64 SKU" {
            $imageReqs = @{ Gen = 'Gen2'; Arch = 'ARM64' }
            $caps = @{ HyperVGenerations = 'V2'; CpuArchitecture = 'Arm64' }
            $result = Test-ImageSkuCompatibility -ImageReqs $imageReqs -SkuCapabilities $caps
            $result.Compatible | Should -BeTrue
        }
    }

    Context "Generation incompatible" {
        It "Incompatible when Gen2 required but SKU only supports V1" {
            $imageReqs = @{ Gen = 'Gen2'; Arch = 'x64' }
            $caps = @{ HyperVGenerations = 'V1'; CpuArchitecture = 'x64' }
            $result = Test-ImageSkuCompatibility -ImageReqs $imageReqs -SkuCapabilities $caps
            $result.Compatible | Should -BeFalse
            $result.Reason | Should -Match 'Gen2'
        }

        It "Incompatible when Gen1 required but SKU only supports V2" {
            $imageReqs = @{ Gen = 'Gen1'; Arch = 'x64' }
            $caps = @{ HyperVGenerations = 'V2'; CpuArchitecture = 'x64' }
            $result = Test-ImageSkuCompatibility -ImageReqs $imageReqs -SkuCapabilities $caps
            $result.Compatible | Should -BeFalse
            $result.Reason | Should -Match 'Gen1'
        }
    }

    Context "Architecture incompatible" {
        It "Incompatible when ARM64 required but SKU is x64" {
            $imageReqs = @{ Gen = 'Gen2'; Arch = 'ARM64' }
            $caps = @{ HyperVGenerations = 'V1,V2'; CpuArchitecture = 'x64' }
            $result = Test-ImageSkuCompatibility -ImageReqs $imageReqs -SkuCapabilities $caps
            $result.Compatible | Should -BeFalse
            $result.Reason | Should -Match 'ARM64'
        }

        It "Incompatible when x64 required but SKU is Arm64" {
            $imageReqs = @{ Gen = 'Gen1'; Arch = 'x64' }
            $caps = @{ HyperVGenerations = 'V2'; CpuArchitecture = 'Arm64' }
            $result = Test-ImageSkuCompatibility -ImageReqs $imageReqs -SkuCapabilities $caps
            $result.Compatible | Should -BeFalse
            $result.Reason | Should -Match 'x64'
        }
    }

    Context "Output fields" {
        It "Gen field shows numeric generations without V prefix (V1,V2 → 1,2)" {
            $imageReqs = @{ Gen = 'Gen1'; Arch = 'x64' }
            $caps = @{ HyperVGenerations = 'V1,V2'; CpuArchitecture = 'x64' }
            (Test-ImageSkuCompatibility -ImageReqs $imageReqs -SkuCapabilities $caps).Gen | Should -Be '1,2'
        }

        It "Arch field returns the SKU's CpuArchitecture value" {
            $imageReqs = @{ Gen = 'Gen2'; Arch = 'ARM64' }
            $caps = @{ HyperVGenerations = 'V2'; CpuArchitecture = 'Arm64' }
            (Test-ImageSkuCompatibility -ImageReqs $imageReqs -SkuCapabilities $caps).Arch | Should -Be 'Arm64'
        }
    }
}
