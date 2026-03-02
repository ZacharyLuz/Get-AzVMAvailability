# ContextManagement.Tests.ps1
# Pester tests for Azure context switch/restore helper functions

BeforeAll {
    $scriptContent = Get-Content "$PSScriptRoot\..\Get-AzVMAvailability.ps1" -Raw

    $functionNames = @(
        'Use-SubscriptionContextSafely',
        'Restore-OriginalSubscriptionContext'
    )

    foreach ($funcName in $functionNames) {
        if ($scriptContent -match "(?s)(function $funcName \{.+?\n\})") {
            . ([scriptblock]::Create($matches[1]))
        }
        else {
            throw "Could not find function in script: $funcName"
        }
    }
}

Describe "Use-SubscriptionContextSafely" {
    It "Does not call Set-AzContext when already on target subscription" {
        Mock Get-AzContext {
            [PSCustomObject]@{
                Subscription = [PSCustomObject]@{ Id = 'sub-a' }
            }
        }
        Mock Set-AzContext { }

        $changed = Use-SubscriptionContextSafely -SubscriptionId 'sub-a'

        $changed | Should -BeFalse
        Should -Invoke Set-AzContext -Times 0
    }

    It "Calls Set-AzContext when current subscription differs" {
        Mock Get-AzContext {
            [PSCustomObject]@{
                Subscription = [PSCustomObject]@{ Id = 'sub-a' }
            }
        }
        Mock Set-AzContext { }

        $changed = Use-SubscriptionContextSafely -SubscriptionId 'sub-b'

        $changed | Should -BeTrue
        Should -Invoke Set-AzContext -Times 1 -ParameterFilter { $SubscriptionId -eq 'sub-b' }
    }

    It "Throws when context switch fails" {
        Mock Get-AzContext { $null }
        Mock Set-AzContext { throw 'switch failed' }

        { Use-SubscriptionContextSafely -SubscriptionId 'sub-c' } | Should -Throw
    }
}

Describe "Restore-OriginalSubscriptionContext" {
    It "Returns false when original subscription is not provided" {
        Mock Get-AzContext { $null }
        Mock Set-AzContext { }

        $restored = Restore-OriginalSubscriptionContext -OriginalSubscriptionId ''

        $restored | Should -BeFalse
        Should -Invoke Set-AzContext -Times 0
    }

    It "Returns false when current context already matches original" {
        Mock Get-AzContext {
            [PSCustomObject]@{
                Subscription = [PSCustomObject]@{ Id = 'sub-a' }
            }
        }
        Mock Set-AzContext { }

        $restored = Restore-OriginalSubscriptionContext -OriginalSubscriptionId 'sub-a'

        $restored | Should -BeFalse
        Should -Invoke Set-AzContext -Times 0
    }

    It "Restores context when current subscription differs" {
        Mock Get-AzContext {
            [PSCustomObject]@{
                Subscription = [PSCustomObject]@{ Id = 'sub-b' }
            }
        }
        Mock Set-AzContext { }

        $restored = Restore-OriginalSubscriptionContext -OriginalSubscriptionId 'sub-a'

        $restored | Should -BeTrue
        Should -Invoke Set-AzContext -Times 1 -ParameterFilter { $SubscriptionId -eq 'sub-a' }
    }

    It "Returns false and does not throw when restore fails" {
        Mock Get-AzContext {
            [PSCustomObject]@{
                Subscription = [PSCustomObject]@{ Id = 'sub-b' }
            }
        }
        Mock Set-AzContext { throw 'restore failed' }

        $restored = $null
        { $restored = Restore-OriginalSubscriptionContext -OriginalSubscriptionId 'sub-a' } | Should -Not -Throw
        $restored | Should -BeFalse
    }
}
