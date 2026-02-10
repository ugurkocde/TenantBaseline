function Invoke-TBGraphRequest {
    <#
    .SYNOPSIS
        Central wrapper for Microsoft Graph API calls with retry and error handling.
    .DESCRIPTION
        Wraps Invoke-MgGraphRequest with automatic retry on 429 (throttling) and
        503 (service unavailable), verbose logging, and structured error parsing.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Uri,

        [Parameter()]
        [ValidateSet('GET', 'POST', 'PATCH', 'DELETE')]
        [string]$Method = 'GET',

        [Parameter()]
        [object]$Body,

        [Parameter()]
        [int]$MaxRetries = 3,

        [Parameter()]
        [hashtable]$Headers
    )

    $null = Test-TBGraphConnection

    $attempt = 0
    $baseDelay = 2

    while ($true) {
        $attempt++
        Write-TBLog -Message ('{0} {1} (attempt {2})' -f $Method, $Uri, $attempt)

        try {
            $params = @{
                Uri    = $Uri
                Method = $Method
            }

            if ($Body) {
                $params['Body'] = $Body | ConvertTo-Json -Depth 20 -Compress
                if (-not $params.ContainsKey('ContentType')) {
                    $params['ContentType'] = 'application/json'
                }
                Write-TBLog -Message ('Request body: {0}' -f $params['Body']) -Level 'Verbose'
            }

            if ($Headers) {
                $params['Headers'] = $Headers
            }

            $response = Invoke-MgGraphRequest @params
            Write-TBLog -Message ('{0} {1} succeeded' -f $Method, $Uri)
            return $response
        }
        catch {
            # Try to capture the API response body from all available sources
            $responseBody = $null

            # Source 1: ErrorDetails.Message
            if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                $responseBody = $_.ErrorDetails.Message
                Write-TBLog -Message ('ErrorDetails.Message: {0}' -f $responseBody) -Level 'Verbose'
            }

            # Source 2: Read from HttpResponseMessage content stream
            if (-not $responseBody) {
                try {
                    if ($_.Exception.PSObject.Properties['Response'] -and $_.Exception.Response -and
                        $_.Exception.Response.PSObject.Properties['Content'] -and $_.Exception.Response.Content) {
                        $responseBody = $_.Exception.Response.Content.ReadAsStringAsync().GetAwaiter().GetResult()
                        if ($responseBody) {
                            Write-TBLog -Message ('Response body from stream: {0}' -f $responseBody) -Level 'Verbose'
                        }
                    }
                }
                catch {
                    # Content stream may already be disposed
                }
            }

            # Source 3: Check TargetObject (some SDK versions store response here)
            if (-not $responseBody -and $_.TargetObject -is [string] -and $_.TargetObject -match '\{') {
                $responseBody = $_.TargetObject
                Write-TBLog -Message ('TargetObject: {0}' -f $responseBody) -Level 'Verbose'
            }

            Write-TBLog -Message ('Exception type: {0}' -f $_.Exception.GetType().FullName) -Level 'Verbose'

            $resolveParams = @{ ErrorRecord = $_ }
            if ($responseBody) {
                $resolveParams['ResponseBody'] = $responseBody
            }
            $parsedError = Resolve-TBErrorResponse @resolveParams
            $statusCode = $parsedError.StatusCode

            $isRetryable = ($statusCode -eq 429) -or ($statusCode -eq 503) -or ($statusCode -eq 504)

            if ($isRetryable -and ($attempt -lt $MaxRetries)) {
                # Calculate delay: use Retry-After header if available, otherwise exponential backoff
                $retryAfter = $null
                if ($_.Exception.PSObject.Properties['Response'] -and
                    $_.Exception.Response.Headers -and
                    $_.Exception.Response.Headers['Retry-After']) {
                    $retryAfter = [int]$_.Exception.Response.Headers['Retry-After'][0]
                }

                if (-not $retryAfter) {
                    $retryAfter = [math]::Pow($baseDelay, $attempt)
                }

                Write-TBLog -Message ('Request throttled or service unavailable (HTTP {0}). Retrying in {1}s...' -f $statusCode, $retryAfter) -Level 'Warning'
                Start-Sleep -Seconds $retryAfter
            }
            else {
                $errorMsg = 'Graph API request failed: [{0}] {1}' -f $parsedError.ErrorCode, $parsedError.Message
                if ($parsedError.RequestId) {
                    $errorMsg += ' (Request ID: {0})' -f $parsedError.RequestId
                }
                Write-TBLog -Message $errorMsg -Level 'Error'
                throw $_
            }
        }
    }
}
