#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Invoke-TBGraphRequest' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
    }

    Context 'Successful GET request' {

        It 'Returns the response from Invoke-MgGraphRequest' {
            $expected = [PSCustomObject]@{ id = 'abc'; displayName = 'Test' }
            Mock -ModuleName TenantBaseline Invoke-MgGraphRequest { return $expected }

            $result = InModuleScope TenantBaseline {
                Invoke-TBGraphRequest -Uri 'https://graph.microsoft.com/v1.0/test' -Method 'GET'
            }

            $result.id | Should -Be 'abc'
            $result.displayName | Should -Be 'Test'
        }

        It 'Calls Test-TBGraphConnection before making the request' {
            Mock -ModuleName TenantBaseline Invoke-MgGraphRequest { return @{} }

            InModuleScope TenantBaseline {
                Invoke-TBGraphRequest -Uri 'https://graph.microsoft.com/v1.0/test' -Method 'GET'
            }

            Should -Invoke -CommandName Test-TBGraphConnection -ModuleName TenantBaseline -Times 1 -Exactly
        }
    }

    Context 'Successful POST request with body' {

        It 'Passes body and ContentType to Invoke-MgGraphRequest' {
            Mock -ModuleName TenantBaseline Invoke-MgGraphRequest {
                return [PSCustomObject]@{ id = 'new-id' }
            }

            $result = InModuleScope TenantBaseline {
                $body = @{ displayName = 'New Monitor' }
                Invoke-TBGraphRequest -Uri 'https://graph.microsoft.com/v1.0/test' -Method 'POST' -Body $body
            }

            $result.id | Should -Be 'new-id'
            Should -Invoke -CommandName Invoke-MgGraphRequest -ModuleName TenantBaseline -Times 1 -Exactly
        }
    }

    Context 'Retry on 429 status code' {

        It 'Retries when receiving a 429 response' {
            Mock -ModuleName TenantBaseline Start-Sleep {}

            $script:callCount = 0
            Mock -ModuleName TenantBaseline Invoke-MgGraphRequest {
                $script:callCount++
                if ($script:callCount -lt 2) {
                    $ex = New-Object System.Exception 'Throttled'
                    $ex | Add-Member -NotePropertyName 'StatusCode' -NotePropertyValue 429 -Force
                    throw $ex
                }
                return [PSCustomObject]@{ id = 'ok' }
            }

            Mock -ModuleName TenantBaseline Resolve-TBErrorResponse {
                return [PSCustomObject]@{
                    StatusCode = 429
                    ErrorCode  = 'TooManyRequests'
                    Message    = 'Throttled'
                    RequestId  = $null
                    RawError   = 'Throttled'
                }
            }

            $result = InModuleScope TenantBaseline {
                Invoke-TBGraphRequest -Uri 'https://graph.microsoft.com/v1.0/test' -Method 'GET' -MaxRetries 3
            }

            $result.id | Should -Be 'ok'
            Should -Invoke -CommandName Start-Sleep -ModuleName TenantBaseline -Times 1 -Exactly
        }
    }

    Context 'Retry on 503 status code' {

        It 'Retries when receiving a 503 response' {
            Mock -ModuleName TenantBaseline Start-Sleep {}

            $script:callCount503 = 0
            Mock -ModuleName TenantBaseline Invoke-MgGraphRequest {
                $script:callCount503++
                if ($script:callCount503 -lt 2) {
                    $ex = New-Object System.Exception 'Service Unavailable'
                    $ex | Add-Member -NotePropertyName 'StatusCode' -NotePropertyValue 503 -Force
                    throw $ex
                }
                return [PSCustomObject]@{ id = 'recovered' }
            }

            Mock -ModuleName TenantBaseline Resolve-TBErrorResponse {
                return [PSCustomObject]@{
                    StatusCode = 503
                    ErrorCode  = 'ServiceUnavailable'
                    Message    = 'Service Unavailable'
                    RequestId  = $null
                    RawError   = 'Service Unavailable'
                }
            }

            $result = InModuleScope TenantBaseline {
                Invoke-TBGraphRequest -Uri 'https://graph.microsoft.com/v1.0/test' -Method 'GET' -MaxRetries 3
            }

            $result.id | Should -Be 'recovered'
        }
    }

    Context 'Max retries exceeded' {

        It 'Throws after all retries are exhausted' {
            Mock -ModuleName TenantBaseline Start-Sleep {}

            Mock -ModuleName TenantBaseline Invoke-MgGraphRequest {
                $ex = New-Object System.Exception 'Throttled'
                $ex | Add-Member -NotePropertyName 'StatusCode' -NotePropertyValue 429 -Force
                throw $ex
            }

            Mock -ModuleName TenantBaseline Resolve-TBErrorResponse {
                return [PSCustomObject]@{
                    StatusCode = 429
                    ErrorCode  = 'TooManyRequests'
                    Message    = 'Throttled'
                    RequestId  = $null
                    RawError   = 'Throttled'
                }
            }

            {
                InModuleScope TenantBaseline {
                    Invoke-TBGraphRequest -Uri 'https://graph.microsoft.com/v1.0/test' -Method 'GET' -MaxRetries 2
                }
            } | Should -Throw
        }
    }

    Context 'Non-retryable error' {

        It 'Throws immediately on 403' {
            Mock -ModuleName TenantBaseline Invoke-MgGraphRequest {
                $ex = New-Object System.Exception 'Forbidden'
                $ex | Add-Member -NotePropertyName 'StatusCode' -NotePropertyValue 403 -Force
                throw $ex
            }

            Mock -ModuleName TenantBaseline Resolve-TBErrorResponse {
                return [PSCustomObject]@{
                    StatusCode = 403
                    ErrorCode  = 'Authorization_RequestDenied'
                    Message    = 'Forbidden'
                    RequestId  = $null
                    RawError   = 'Forbidden'
                }
            }

            {
                InModuleScope TenantBaseline {
                    Invoke-TBGraphRequest -Uri 'https://graph.microsoft.com/v1.0/test' -Method 'GET'
                }
            } | Should -Throw

            Should -Invoke -CommandName Invoke-MgGraphRequest -ModuleName TenantBaseline -Times 1 -Exactly
        }

        It 'Throws immediately on 404' {
            Mock -ModuleName TenantBaseline Invoke-MgGraphRequest {
                $ex = New-Object System.Exception 'Not Found'
                $ex | Add-Member -NotePropertyName 'StatusCode' -NotePropertyValue 404 -Force
                throw $ex
            }

            Mock -ModuleName TenantBaseline Resolve-TBErrorResponse {
                return [PSCustomObject]@{
                    StatusCode = 404
                    ErrorCode  = 'Request_ResourceNotFound'
                    Message    = 'Not Found'
                    RequestId  = $null
                    RawError   = 'Not Found'
                }
            }

            {
                InModuleScope TenantBaseline {
                    Invoke-TBGraphRequest -Uri 'https://graph.microsoft.com/v1.0/test' -Method 'GET'
                }
            } | Should -Throw

            Should -Invoke -CommandName Invoke-MgGraphRequest -ModuleName TenantBaseline -Times 1 -Exactly
        }
    }
}
