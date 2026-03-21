function Invoke-WithRetry {
    <#
    .SYNOPSIS
        Executes a script block with retry logic for transient Azure API errors.
    .DESCRIPTION
        Wraps any API call with automatic retry on:
        - HTTP 429 (Too Many Requests) — reads Retry-After header
        - HTTP 503 (Service Unavailable) — transient Azure outages
        - Network timeouts and WebExceptions
        Uses exponential backoff with jitter between retries.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [scriptblock]$ScriptBlock,

        [Parameter(Mandatory = $false)]
        [int]$MaxRetries = 3,

        [Parameter(Mandatory = $false)]
        [string]$OperationName = 'API call'
    )

    $attempt = 0
    while ($true) {
        try {
            return & $ScriptBlock
        }
        catch {
            $attempt++
            $ex = $_.Exception
            $isRetryable = $false
            $waitSeconds = [math]::Pow(2, $attempt)  # Exponential: 2, 4, 8...

            # HTTP 429 — Too Many Requests (throttled)
            $statusCode = if ($ex.Response) { $ex.Response.StatusCode.value__ } else { $null }
            if ($statusCode -eq 429 -or $ex.Message -match '429|Too Many Requests') {
                $isRetryable = $true
                if ($ex.Response -and $ex.Response.Headers) {
                    $retryAfter = $ex.Response.Headers['Retry-After']
                    if ($retryAfter) {
                        $parsedSeconds = 0
                        $retryDate = [datetime]::MinValue
                        if ([int]::TryParse($retryAfter, [ref]$parsedSeconds)) {
                            # Clamp to ≥1 so Start-Sleep never receives 0 or negative seconds
                            $waitSeconds = [math]::Max(1, $parsedSeconds)
                        }
                        elseif ([datetime]::TryParseExact($retryAfter, 'R', [System.Globalization.CultureInfo]::InvariantCulture, [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal, [ref]$retryDate)) {
                            # Azure can return an absolute HTTP-date (RFC 1123 'R' format) instead of integer seconds.
                            # AssumeUniversal|AdjustToUniversal ensures Kind=Utc so the subtraction is correct regardless of local timezone.
                            $waitSeconds = [int][math]::Ceiling(($retryDate - [datetime]::UtcNow).TotalSeconds)
                            if ($waitSeconds -lt 1) { $waitSeconds = 1 }
                        }
                    }
                }
            }
            # HTTP 503 — Service Unavailable
            elseif ($statusCode -eq 503 -or $ex.Message -match '503|Service Unavailable') {
                $isRetryable = $true
            }
            # Network errors — timeouts, connection failures
            elseif ($ex -is [System.Net.WebException] -or
                $ex -is [System.Net.Http.HttpRequestException] -or
                $ex.InnerException -is [System.Net.WebException] -or
                $ex.InnerException -is [System.Net.Http.HttpRequestException] -or
                $ex.Message -match 'timed?\s*out|connection.*reset|connection.*refused') {
                $isRetryable = $true
            }

            if (-not $isRetryable -or $attempt -ge $MaxRetries) {
                throw
            }

            # Add jitter (0-25%) to prevent thundering herd
            $jitter = Get-Random -Minimum 0 -Maximum ([math]::Max(1, [int]($waitSeconds * 0.25)))
            $waitSeconds += $jitter

            Write-Verbose "$OperationName failed (attempt $attempt/$MaxRetries): $($ex.Message). Retrying in ${waitSeconds}s..."
            Start-Sleep -Seconds $waitSeconds
        }
    }
}
