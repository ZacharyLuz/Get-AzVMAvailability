# Invoke-WithRetry.Tests.ps1
# Pester tests for the Invoke-WithRetry function
# Run with: Invoke-Pester .\tests\Invoke-WithRetry.Tests.ps1 -Output Detailed

BeforeAll {
    $scriptContent = Get-Content "$PSScriptRoot\..\Get-AzVMAvailability.ps1" -Raw

    if ($scriptContent -match '(?s)(function Invoke-WithRetry \{.+?\n\})') {
        Invoke-Expression $matches[1]
    }
    else {
        throw "Could not find Invoke-WithRetry function in script"
    }
}

Describe "Invoke-WithRetry" {

    Context "Successful execution" {
        It "Returns result on first successful call" {
            $result = Invoke-WithRetry -ScriptBlock { 42 } -MaxRetries 3 -OperationName "Test"
            $result | Should -Be 42
        }

        It "Returns string result correctly" {
            $result = Invoke-WithRetry -ScriptBlock { "hello" } -MaxRetries 3 -OperationName "Test"
            $result | Should -Be "hello"
        }

        It "Returns array result correctly" {
            $result = Invoke-WithRetry -ScriptBlock { @(1, 2, 3) } -MaxRetries 3 -OperationName "Test"
            $result | Should -HaveCount 3
        }

        It "Returns hashtable result correctly" {
            $result = Invoke-WithRetry -ScriptBlock { @{ Key = 'Value' } } -MaxRetries 3 -OperationName "Test"
            $result.Key | Should -Be 'Value'
        }
    }

    Context "Non-retryable errors" {
        It "Throws immediately for non-retryable errors" {
            { Invoke-WithRetry -ScriptBlock { throw "Something unexpected" } -MaxRetries 3 -OperationName "Test" } |
            Should -Throw "Something unexpected"
        }

        It "Does not retry on ArgumentException" {
            $callCount = 0
            $action = {
                $callCount++
                throw [System.ArgumentException]::new("Bad argument")
            }.GetNewClosure()

            # Use a variable in the outer scope for tracking
            $script:retryCallCount = 0
            {
                Invoke-WithRetry -ScriptBlock {
                    $script:retryCallCount++
                    throw [System.ArgumentException]::new("Bad argument")
                } -MaxRetries 3 -OperationName "Test"
            } | Should -Throw "*Bad argument*"

            $script:retryCallCount | Should -Be 1
        }
    }

    Context "Retryable errors (429)" {
        It "Retries on HTTP 429 message and eventually succeeds" {
            $script:attempt429 = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attempt429++
                if ($script:attempt429 -lt 3) {
                    throw "HTTP 429 Too Many Requests"
                }
                "success"
            } -MaxRetries 3 -OperationName "Throttle test"

            $result | Should -Be "success"
            $script:attempt429 | Should -Be 3
        }
    }

    Context "Retryable errors (503)" {
        It "Retries on HTTP 503 message and eventually succeeds" {
            $script:attempt503 = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attempt503++
                if ($script:attempt503 -lt 2) {
                    throw "503 Service Unavailable"
                }
                "recovered"
            } -MaxRetries 3 -OperationName "503 test"

            $result | Should -Be "recovered"
            $script:attempt503 | Should -Be 2
        }
    }

    Context "Retryable errors (timeout)" {
        It "Retries on timeout messages" {
            $script:attemptTimeout = 0
            $result = Invoke-WithRetry -ScriptBlock {
                $script:attemptTimeout++
                if ($script:attemptTimeout -lt 2) {
                    throw "The operation has timed out"
                }
                "ok"
            } -MaxRetries 3 -OperationName "Timeout test"

            $result | Should -Be "ok"
            $script:attemptTimeout | Should -Be 2
        }
    }

    Context "Max retries exhausted" {
        It "Throws after exhausting all retries" {
            $script:attemptExhausted = 0
            {
                Invoke-WithRetry -ScriptBlock {
                    $script:attemptExhausted++
                    throw "429 Too Many Requests"
                } -MaxRetries 2 -OperationName "Exhaustion test"
            } | Should -Throw "*429*"

            # 1 initial + 2 retries = 3 total attempts (attempt reaches MaxRetries)
            $script:attemptExhausted | Should -BeLessOrEqual 3
        }
    }

    Context "Zero retries" {
        It "Does not retry when MaxRetries is 0" {
            $script:attemptZero = 0
            {
                Invoke-WithRetry -ScriptBlock {
                    $script:attemptZero++
                    throw "429 Too Many Requests"
                } -MaxRetries 0 -OperationName "Zero retry test"
            } | Should -Throw "*429*"

            $script:attemptZero | Should -Be 1
        }
    }
}
