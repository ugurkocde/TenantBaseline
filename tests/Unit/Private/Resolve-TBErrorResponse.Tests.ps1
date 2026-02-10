#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Resolve-TBErrorResponse' {

    Context 'Parses Graph error JSON from exception message' {

        It 'Extracts error code and message from embedded JSON' {
            $jsonMsg = '{"error":{"code":"Authorization_RequestDenied","message":"Insufficient privileges","innerError":{"request-id":"abc-123"}}}'
            $exception = New-Object System.Exception $jsonMsg
            $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                $exception,
                'GraphError',
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $null
            )

            $result = InModuleScope TenantBaseline -Parameters @{ ErrorRecord = $errorRecord } {
                param($ErrorRecord)
                Resolve-TBErrorResponse -ErrorRecord $ErrorRecord
            }

            $result.ErrorCode | Should -Be 'Authorization_RequestDenied'
            $result.Message | Should -Be 'Insufficient privileges'
            $result.RequestId | Should -Be 'abc-123'
        }
    }

    Context 'Parses Graph error JSON from ErrorDetails.Message' {

        It 'Extracts error code and message from plain JSON in ErrorDetails' {
            $exception = New-Object System.Exception 'Response status code does not indicate success: BadRequest (Bad Request).'
            $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                $exception,
                'GraphError',
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $null
            )
            $errorDetailsJson = '{"error":{"code":"BadRequest","message":"The number of resources exceeds the maximum allowed (50).","innerError":{"request-id":"def-456"}}}'
            $errorDetails = New-Object System.Management.Automation.ErrorDetails $errorDetailsJson
            $errorRecord.GetType().GetProperty('ErrorDetails').SetValue($errorRecord, $errorDetails)

            $result = InModuleScope TenantBaseline -Parameters @{ ErrorRecord = $errorRecord } {
                param($ErrorRecord)
                Resolve-TBErrorResponse -ErrorRecord $ErrorRecord
            }

            $result.ErrorCode | Should -Be 'BadRequest'
            $result.Message | Should -Be 'The number of resources exceeds the maximum allowed (50).'
            $result.RequestId | Should -Be 'def-456'
        }

        It 'Extracts error from full HTTP response dump in ErrorDetails' {
            $exception = New-Object System.Exception 'Response status code does not indicate success: BadRequest (Bad Request).'
            $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                $exception,
                'GraphError',
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $null
            )
            # Simulate the full HTTP response format that the Graph SDK puts in ErrorDetails.Message
            $fullHttpResponse = @(
                'POST https://graph.microsoft.com/beta/admin/configurationManagement/configurationSnapshots/createSnapshot'
                'HTTP/2.0 400 Bad Request'
                'Vary: Accept-Encoding'
                'x-ms-ags-diagnostic: {"ServerInfo":{"DataCenter":"Germany West Central","Slice":"E","Ring":"4"}}'
                'Content-Type: application/json'
                ''
                '{"error":{"code":"BadRequest","message":"One or more validation errors occurred.","innerError":{"request-id":"abc-def-123"}}}'
            ) -join "`n"
            $errorDetails = New-Object System.Management.Automation.ErrorDetails $fullHttpResponse
            $errorRecord.GetType().GetProperty('ErrorDetails').SetValue($errorRecord, $errorDetails)

            $result = InModuleScope TenantBaseline -Parameters @{ ErrorRecord = $errorRecord } {
                param($ErrorRecord)
                Resolve-TBErrorResponse -ErrorRecord $ErrorRecord
            }

            $result.ErrorCode | Should -Be 'BadRequest'
            $result.Message | Should -Be 'One or more validation errors occurred.'
            $result.RequestId | Should -Be 'abc-def-123'
        }
    }

    Context 'Returns message when JSON parsing fails' {

        It 'Falls back to the exception message text' {
            $exception = New-Object System.Exception 'Some plain error text'
            $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                $exception,
                'PlainError',
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $null
            )

            $result = InModuleScope TenantBaseline -Parameters @{ ErrorRecord = $errorRecord } {
                param($ErrorRecord)
                Resolve-TBErrorResponse -ErrorRecord $ErrorRecord
            }

            $result.Message | Should -Be 'Some plain error text'
            $result.ErrorCode | Should -BeNullOrEmpty
        }
    }

    Context 'Parses error from ResponseBody parameter' {

        It 'Extracts error from ResponseBody when ErrorDetails and exception have no JSON' {
            $exception = New-Object System.Exception 'Response status code does not indicate success: BadRequest (Bad Request).'
            $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                $exception,
                'GraphError',
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $null
            )
            $body = '{"error":{"code":"InvalidRequest","message":"Too many resources specified.","innerError":{"request-id":"ghi-789"}}}'

            $result = InModuleScope TenantBaseline -Parameters @{ ErrorRecord = $errorRecord; Body = $body } {
                param($ErrorRecord, $Body)
                Resolve-TBErrorResponse -ErrorRecord $ErrorRecord -ResponseBody $Body
            }

            $result.ErrorCode | Should -Be 'InvalidRequest'
            $result.Message | Should -Be 'Too many resources specified.'
            $result.RequestId | Should -Be 'ghi-789'
        }

        It 'Handles flat error JSON format without error wrapper' {
            $exception = New-Object System.Exception 'Bad Request'
            $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                $exception,
                'GraphError',
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $null
            )
            $body = '{"code":"BadRequest","message":"The request payload is invalid."}'

            $result = InModuleScope TenantBaseline -Parameters @{ ErrorRecord = $errorRecord; Body = $body } {
                param($ErrorRecord, $Body)
                Resolve-TBErrorResponse -ErrorRecord $ErrorRecord -ResponseBody $Body
            }

            $result.ErrorCode | Should -Be 'BadRequest'
            $result.Message | Should -Be 'The request payload is invalid.'
        }
    }

    Context 'Handles non-ErrorRecord input' {

        It 'Converts a plain string to a result object' {
            $result = InModuleScope TenantBaseline {
                Resolve-TBErrorResponse -ErrorRecord 'Simple error string'
            }

            $result.Message | Should -Be 'Simple error string'
            $result.RawError | Should -Be 'Simple error string'
        }
    }

    Context 'Returns all expected properties' {

        It 'Result has StatusCode, ErrorCode, Message, RequestId, and RawError' {
            $result = InModuleScope TenantBaseline {
                Resolve-TBErrorResponse -ErrorRecord 'test'
            }

            $result.PSObject.Properties['StatusCode'] | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties['ErrorCode'] | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties['Message'] | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties['RequestId'] | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties['RawError'] | Should -Not -BeNullOrEmpty
        }
    }
}
