Describe 'AzVMAvailability Module' {

    BeforeAll {
        # Remove any stale copy, import fresh from repo root
        Remove-Module AzVMAvailability -ErrorAction SilentlyContinue
        $modulePath = Join-Path $PSScriptRoot '..' 'AzVMAvailability'
        Import-Module $modulePath -Force -DisableNameChecking -ErrorAction Stop
    }

    AfterAll {
        Remove-Module AzVMAvailability -ErrorAction SilentlyContinue
    }

    Context 'Module loads correctly' {

        It 'Module is loaded' {
            $mod = Get-Module AzVMAvailability
            $mod | Should -Not -BeNullOrEmpty
        }

        It 'Module version matches manifest' {
            $mod = Get-Module AzVMAvailability
            $manifestPath = Join-Path $PSScriptRoot '..' 'AzVMAvailability' 'AzVMAvailability.psd1'
            $expected = (Import-PowerShellDataFile $manifestPath).ModuleVersion
            $mod.Version.ToString() | Should -Be $expected
        }

        It 'Exports exactly Get-AzVMAvailability' {
            $mod = Get-Module AzVMAvailability
            $exported = $mod.ExportedFunctions.Keys
            $exported | Should -HaveCount 1
            $exported | Should -Contain 'Get-AzVMAvailability'
        }

        It 'Does not export private functions' {
            $mod = Get-Module AzVMAvailability
            $exported = $mod.ExportedFunctions.Keys
            $exported | Should -Not -Contain 'Get-SafeString'
            $exported | Should -Not -Contain 'Invoke-WithRetry'
            $exported | Should -Not -Contain 'Get-AzureEndpoints'
            $exported | Should -Not -Contain 'Get-CapValue'
            $exported | Should -Not -Contain 'Get-SkuFamily'
            $exported | Should -Not -Contain 'Format-ZoneStatus'
            $exported | Should -Not -Contain 'New-ScanOutputContract'
        }

        It 'Does not export cmdlets, variables, or aliases' {
            $mod = Get-Module AzVMAvailability
            $mod.ExportedCmdlets.Count | Should -Be 0
            $mod.ExportedVariables.Count | Should -Be 0
            $mod.ExportedAliases.Count | Should -Be 0
        }

        It 'Get-AzVMAvailability command is available' {
            $cmd = Get-Command Get-AzVMAvailability -Module AzVMAvailability -ErrorAction SilentlyContinue
            $cmd | Should -Not -BeNullOrEmpty
            $cmd.CommandType | Should -Be 'Function'
        }

        It 'Requires PowerShell 7+' {
            $mod = Get-Module AzVMAvailability
            $mod.PowerShellVersion | Should -Be '7.0'
        }
    }
}
