BeforeAll {
    Import-Module "$PSScriptRoot\TestHarness.psm1" -Force
    $functionNames = @(
        'Get-ProcessorVendor',
        'Get-DiskCode'
    )

    foreach ($functionName in $functionNames) {
        . ([scriptblock]::Create((Get-MainScriptFunctionDefinition -FunctionName $functionName)))
    }
}

Describe 'Get-ProcessorVendor' {
    Context 'Intel SKUs (no a/p suffix)' {
        It 'Returns Intel for Standard_D4s_v5' {
            Get-ProcessorVendor -SkuName 'Standard_D4s_v5' | Should -Be 'Intel'
        }
        It 'Returns Intel for Standard_E64ds_v6' {
            Get-ProcessorVendor -SkuName 'Standard_E64ds_v6' | Should -Be 'Intel'
        }
        It 'Returns Intel for Standard_M128s_v2' {
            Get-ProcessorVendor -SkuName 'Standard_M128s_v2' | Should -Be 'Intel'
        }
    }

    Context 'AMD SKUs (a suffix)' {
        It 'Returns AMD for Standard_D4as_v5' {
            Get-ProcessorVendor -SkuName 'Standard_D4as_v5' | Should -Be 'AMD'
        }
        It 'Returns AMD for Standard_E64as_v5' {
            Get-ProcessorVendor -SkuName 'Standard_E64as_v5' | Should -Be 'AMD'
        }
    }

    Context 'ARM/Ampere SKUs (p suffix)' {
        It 'Returns ARM for Standard_D4ps_v6' {
            Get-ProcessorVendor -SkuName 'Standard_D4ps_v6' | Should -Be 'ARM'
        }
        It 'Returns ARM for Standard_E64pds_v6' {
            Get-ProcessorVendor -SkuName 'Standard_E64pds_v6' | Should -Be 'ARM'
        }
    }

    Context 'A-family exclusion' {
        It 'Returns Intel for A-family SKU Standard_A4_v2 (a is family, not AMD)' {
            Get-ProcessorVendor -SkuName 'Standard_A4_v2' | Should -Be 'Intel'
        }
    }

    Context 'p before a precedence' {
        It 'Returns ARM when SKU has both p and a in body (p takes priority)' {
            Get-ProcessorVendor -SkuName 'Standard_E4pads_v6' | Should -Be 'ARM'
        }
    }
}

Describe 'Get-DiskCode' {
    It 'Returns NV+T for NVMe with temp disk' {
        Get-DiskCode -HasTempDisk $true -HasNvme $true | Should -Be 'NV+T'
    }
    It 'Returns NVMe for NVMe without temp disk' {
        Get-DiskCode -HasTempDisk $false -HasNvme $true | Should -Be 'NVMe'
    }
    It 'Returns SC+T for SCSI with temp disk' {
        Get-DiskCode -HasTempDisk $true -HasNvme $false | Should -Be 'SC+T'
    }
    It 'Returns SCSI for SCSI without temp disk' {
        Get-DiskCode -HasTempDisk $false -HasNvme $false | Should -Be 'SCSI'
    }
}
