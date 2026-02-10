function Resolve-TBErrorResponse {
    <#
    .SYNOPSIS
        Parses a Microsoft Graph error response into a structured object.
    .DESCRIPTION
        Takes a Graph API error (typically from a catch block) and extracts
        the error code, message, and request ID for consistent error reporting.
        Checks multiple sources for the API error body: ErrorDetails.Message,
        the HttpResponseMessage content stream, and the exception message itself.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$ErrorRecord,

        [Parameter()]
        [string]$ResponseBody
    )

    $result = [PSCustomObject]@{
        StatusCode = $null
        ErrorCode  = $null
        Message    = $null
        RequestId  = $null
        RawError   = $null
    }

    try {
        if ($ErrorRecord -is [System.Management.Automation.ErrorRecord]) {
            $exception = $ErrorRecord.Exception
            $result.RawError = $ErrorRecord.ToString()

            # Collect all potential JSON sources in priority order
            $jsonSources = @()

            # Source 1: Explicit ResponseBody parameter (pre-captured by caller)
            if ($ResponseBody) {
                $jsonSources += $ResponseBody
            }

            # Source 2: ErrorDetails.Message (PowerShell error details, sometimes has API body)
            if ($ErrorRecord.ErrorDetails -and $ErrorRecord.ErrorDetails.Message) {
                $edm = $ErrorRecord.ErrorDetails.Message
                # The Graph SDK may return the full HTTP response (headers + body) in
                # ErrorDetails.Message. Extract the body after the blank line separator
                # so we try clean JSON first, before falling back to the raw text.
                if ($edm -match '(\r?\n){2}') {
                    $parts = $edm -split '(?:\r?\n){2}', 2
                    if ($parts.Count -eq 2) {
                        $httpBody = $parts[1].Trim()
                        if ($httpBody) {
                            $jsonSources += $httpBody
                        }
                    }
                }
                $jsonSources += $edm
            }

            # Source 3: Exception message (Graph errors sometimes embed JSON)
            $messageText = $exception.Message
            if ($messageText) {
                $jsonSources += $messageText
            }

            # Try each source: first attempt direct JSON parse, then regex extraction
            foreach ($source in $jsonSources) {
                if ($result.ErrorCode) { break }

                # Attempt 1: Direct ConvertFrom-Json (handles clean JSON strings)
                try {
                    $parsed = $source | ConvertFrom-Json
                    if ($parsed.error -and $parsed.error.code) {
                        $result.ErrorCode = $parsed.error.code
                        $result.Message = $parsed.error.message
                        if ($parsed.error.innerError -and $parsed.error.innerError.'request-id') {
                            $result.RequestId = $parsed.error.innerError.'request-id'
                        }
                        break
                    }
                    elseif ($parsed.code) {
                        # Flat error format (no "error" wrapper)
                        $result.ErrorCode = $parsed.code
                        $result.Message = $parsed.message
                        break
                    }
                }
                catch {
                    # Not valid JSON on its own, try regex extraction
                }

                # Attempt 2: Regex extraction for JSON embedded in other text
                if ($source -match '\{.*"error".*\}') {
                    $jsonMatch = $source | Select-String -Pattern '\{.*\}' | ForEach-Object { $_.Matches[0].Value }
                    if ($jsonMatch) {
                        try {
                            $parsed = $jsonMatch | ConvertFrom-Json
                            if ($parsed.error) {
                                $result.ErrorCode = $parsed.error.code
                                $result.Message = $parsed.error.message
                                if ($parsed.error.innerError -and $parsed.error.innerError.'request-id') {
                                    $result.RequestId = $parsed.error.innerError.'request-id'
                                }
                                break
                            }
                        }
                        catch {
                            # Regex matched but JSON parse failed
                        }
                    }
                }
            }

            if (-not $result.Message) {
                $result.Message = $messageText
            }

            # Try to extract status code
            if ($exception.PSObject.Properties['StatusCode']) {
                $result.StatusCode = [int]$exception.StatusCode
            }
            elseif ($exception.PSObject.Properties['Response'] -and $exception.Response.PSObject.Properties['StatusCode']) {
                $result.StatusCode = [int]$exception.Response.StatusCode
            }
        }
        else {
            $result.Message = $ErrorRecord.ToString()
            $result.RawError = $ErrorRecord.ToString()
        }
    }
    catch {
        $result.Message = $ErrorRecord.ToString()
        $result.RawError = $ErrorRecord.ToString()
    }

    return $result
}
