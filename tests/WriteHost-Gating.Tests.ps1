# WriteHost-Gating.Tests.ps1
# Pester tests for the Write-Host override / $script:SuppressConsole gating
# Run with: Invoke-Pester .\tests\WriteHost-Gating.Tests.ps1 -Output Detailed

AfterAll {
    Remove-Item function:Write-Host -ErrorAction SilentlyContinue
}

Describe "Write-Host Gating ($script:SuppressConsole)" {

    BeforeAll {
        # Define the override exactly as the main script does
        $script:SuppressConsole = $false
        function Write-Host {
            param(
                [Parameter(Position = 0, ValueFromPipeline)]
                [object]$Object = '',
                [System.ConsoleColor]$ForegroundColor,
                [System.ConsoleColor]$BackgroundColor,
                [switch]$NoNewline
            )
            if ($script:SuppressConsole) { return }
            Microsoft.PowerShell.Utility\Write-Host @PSBoundParameters
        }
    }

    Context "Suppressed mode" {
        It "Produces no output when SuppressConsole is true" {
            $script:SuppressConsole = $true
            # If Write-Host were not suppressed, this would write to information stream
            $output = Write-Host "This should be suppressed" 6>&1
            $output | Should -BeNullOrEmpty
        }
    }

    Context "Normal mode" {
        It "Produces output when SuppressConsole is false" {
            $script:SuppressConsole = $false
            $output = Write-Host "This should appear" 6>&1
            $output | Should -Not -BeNullOrEmpty
        }

        It "Preserves ForegroundColor parameter" {
            $script:SuppressConsole = $false
            # This should not throw — confirms param forwarding works
            { Write-Host "Colored text" -ForegroundColor Green 6>&1 } | Should -Not -Throw
        }

        It "Preserves NoNewline parameter" {
            $script:SuppressConsole = $false
            { Write-Host "No newline" -NoNewline 6>&1 } | Should -Not -Throw
        }
    }

    Context "Runtime toggle" {
        It "Can be toggled at runtime" {
            $script:SuppressConsole = $true
            $suppressed = Write-Host "Suppressed" 6>&1
            $suppressed | Should -BeNullOrEmpty

            $script:SuppressConsole = $false
            $visible = Write-Host "Visible" 6>&1
            $visible | Should -Not -BeNullOrEmpty
        }
    }

    Context "Other streams not affected" {
        It "Write-Verbose still works when console is suppressed" {
            $script:SuppressConsole = $true
            $VerbosePreference = 'Continue'
            $output = Write-Verbose "Verbose message" 4>&1
            $output | Should -Not -BeNullOrEmpty
            $VerbosePreference = 'SilentlyContinue'
        }

        It "Write-Warning still works when console is suppressed" {
            $script:SuppressConsole = $true
            $output = Write-Warning "Warning message" 3>&1
            $output | Should -Not -BeNullOrEmpty
        }
    }
}
