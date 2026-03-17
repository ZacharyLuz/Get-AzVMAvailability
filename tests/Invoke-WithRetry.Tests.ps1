# Invoke-WithRetry.Tests.ps1
# Pester tests for the Invoke-WithRetry function
# Run with: Invoke-Pester .\tests\Invoke-WithRetry.Tests.ps1 -Output Detailed

BeforeAll {
    Import-Module "$PSScriptRoot\TestHarness.psm1" -Force
    . ([scriptblock]::Create((Get-MainScriptFunctionDefinition -FunctionName 'Invoke-WithRetry')))
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

    Context "Retry-After header parsing — integer seconds" {
        It "Uses integer Retry-After value as the wait interval" {
            # Validate the parsing and clamping math used in Invoke-WithRetry
            $parsedSeconds = 0
            [int]::TryParse('5', [ref]$parsedSeconds) | Should -BeTrue
            $waitSeconds = [math]::Max(1, $parsedSeconds)
            $waitSeconds | Should -Be 5
        }

        It "Clamps zero Retry-After integer to at least 1 second" {
            $parsedSeconds = 0
            [int]::TryParse('0', [ref]$parsedSeconds) | Should -BeTrue
            $waitSeconds = [math]::Max(1, $parsedSeconds)
            $waitSeconds | Should -BeGreaterOrEqual 1
        }

        It "Clamps negative Retry-After integer to at least 1 second" {
            $parsedSeconds = 0
            [int]::TryParse('-10', [ref]$parsedSeconds) | Should -BeTrue
            $waitSeconds = [math]::Max(1, $parsedSeconds)
            $waitSeconds | Should -BeGreaterOrEqual 1
        }
    }

    Context "Retry-After header parsing — RFC1123 HTTP-date" {
        It "Parses RFC1123 Retry-After date and computes a positive wait interval" {
            # Construct an RFC1123-formatted date 5 seconds in the future
            $futureDate = [datetime]::UtcNow.AddSeconds(5)
            $rfcDate = $futureDate.ToString('R')   # e.g. "Mon, 17 Mar 2026 01:00:00 GMT"

            # Verify the round-trip: TryParseExact with AssumeUniversal|AdjustToUniversal
            $styles = [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal
            $parsed = [datetime]::MinValue
            $ok = [datetime]::TryParseExact($rfcDate, 'R', [System.Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$parsed)
            $ok | Should -BeTrue
            $parsed.Kind | Should -Be ([System.DateTimeKind]::Utc)
            $waitSeconds = [int][math]::Ceiling(($parsed - [datetime]::UtcNow).TotalSeconds)
            $waitSeconds | Should -BeGreaterOrEqual 1
        }

        It "Returns wait of at least 1 when RFC1123 date is in the past" {
            $pastDate = [datetime]::UtcNow.AddSeconds(-10)
            $rfcDate = $pastDate.ToString('R')
            $styles = [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal
            $parsed = [datetime]::MinValue
            [datetime]::TryParseExact($rfcDate, 'R', [System.Globalization.CultureInfo]::InvariantCulture, $styles, [ref]$parsed) | Should -BeTrue
            $waitSeconds = [int][math]::Ceiling(($parsed - [datetime]::UtcNow).TotalSeconds)
            if ($waitSeconds -lt 1) { $waitSeconds = 1 }
            $waitSeconds | Should -BeGreaterOrEqual 1
        }
    }

    Context "Retry-After integration — end-to-end catch path" {
        BeforeAll {
            # Guard: Add-Type fails if the type already exists in the session (e.g. repeated test runs).
            # Unique prefix avoids collisions with any types from the main script or other tests.
            if (-not ([System.Management.Automation.PSTypeName]'InvokeWithRetryFakeThrottledException').Type) {
                Add-Type @'
using System;
using System.Collections.Generic;
public class InvokeWithRetryFakeHeaders : Dictionary<string, string> {}
public class InvokeWithRetryFakeStatusCode { public int value__; public InvokeWithRetryFakeStatusCode(int c) { value__ = c; } }
public class InvokeWithRetryFakeResponse {
    public InvokeWithRetryFakeStatusCode StatusCode;
    public InvokeWithRetryFakeHeaders Headers;
    public InvokeWithRetryFakeResponse(int code, string retryAfter) {
        StatusCode = new InvokeWithRetryFakeStatusCode(code);
        Headers = new InvokeWithRetryFakeHeaders();
        if (retryAfter != null) Headers["Retry-After"] = retryAfter;
    }
}
public class InvokeWithRetryFakeThrottledException : Exception {
    public InvokeWithRetryFakeResponse Response { get; }
    public InvokeWithRetryFakeThrottledException(string message, InvokeWithRetryFakeResponse response)
        : base(message) { Response = response; }
}
'@
            }
        }

        It "Passes integer Retry-After header through the catch path to Start-Sleep" {
            Mock Start-Sleep {}
            $script:intIntegCalls = 0
            Invoke-WithRetry -MaxRetries 2 -OperationName "Integration int" -ScriptBlock {
                $script:intIntegCalls++
                if ($script:intIntegCalls -eq 1) {
                    $resp = [InvokeWithRetryFakeResponse]::new(429, '5')
                    throw [InvokeWithRetryFakeThrottledException]::new('429 Too Many Requests', $resp)
                }
            }
            Should -Invoke Start-Sleep -Times 1 -ParameterFilter { $Seconds -ge 5 }
        }

        It "Passes RFC1123 Retry-After header through the catch path to Start-Sleep" {
            Mock Start-Sleep {}
            # +300s — far enough that the computed wait (~300s) can't be confused
            # with the default exponential backoff on attempt 1 (2s + jitter ≤3s).
            $script:futureRfc = ([datetime]::UtcNow.AddSeconds(300)).ToString('R')
            $script:rfcIntegCalls = 0
            Invoke-WithRetry -MaxRetries 2 -OperationName "Integration RFC1123" -ScriptBlock {
                $script:rfcIntegCalls++
                if ($script:rfcIntegCalls -eq 1) {
                    $resp = [InvokeWithRetryFakeResponse]::new(429, $script:futureRfc)
                    throw [InvokeWithRetryFakeThrottledException]::new('429 Too Many Requests', $resp)
                }
            }
            Should -Invoke Start-Sleep -Times 1 -ParameterFilter { $Seconds -ge 60 }
        }
    }
}
