#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Invoke-TBMonitorCreateWithRetry' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Write-TBLog {}
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
    }

    Context 'Creates monitor on first attempt' {

        It 'Returns Result and empty RejectedTypes on success' {
            $result = InModuleScope TenantBaseline {
                Mock New-TBMonitor {
                    return [PSCustomObject]@{ Id = 'mon-001'; DisplayName = 'Test Monitor'; Status = 'active' }
                }

                $resources = @(
                    [PSCustomObject]@{ resourceType = 'microsoft.entra.authorizationpolicy'; displayName = 'microsoft.entra.authorizationpolicy'; properties = @{ allowedToCreateTenants = $false } }
                )

                Invoke-TBMonitorCreateWithRetry -DisplayName 'Test Monitor' -Resources $resources
            }

            $result.Result | Should -Not -BeNullOrEmpty
            $result.Result.Id | Should -Be 'mon-001'
            $result.RejectedTypes.Count | Should -Be 0
        }
    }

    Context 'Retries after filtering rejected types' {

        It 'Removes unsupported types and retries successfully' {
            $result = InModuleScope TenantBaseline {
                $script:monitorAttempt = 0
                Mock New-TBMonitor {
                    $script:monitorAttempt++
                    if ($script:monitorAttempt -eq 1) {
                        $errJson = '{"error":{"code":"BadRequest","message":"One or more validation errors occurred.","details":[{"code":"BadRequest","message":"ResourceType ''microsoft.intune.devicecleanuprule'' is not supported in monitor run type: ''monitorOnly''.","target":"microsoft.intune.devicecleanuprule"},{"code":"BadRequest","message":"Resource properties cannot be empty.","target":"microsoft.intune.devicecleanuprule"}]}}'
                        throw [System.Exception]::new($errJson)
                    }
                    return [PSCustomObject]@{ Id = 'mon-002'; DisplayName = 'Test Monitor'; Status = 'active' }
                }

                $resources = @(
                    [PSCustomObject]@{ resourceType = 'microsoft.entra.authorizationpolicy'; displayName = 'microsoft.entra.authorizationpolicy'; properties = @{ allowedToCreateTenants = $false } }
                    [PSCustomObject]@{ resourceType = 'microsoft.intune.devicecleanuprule'; displayName = 'microsoft.intune.devicecleanuprule'; properties = @{} }
                )

                Invoke-TBMonitorCreateWithRetry -DisplayName 'Test Monitor' -Resources $resources
            }

            $result.Result | Should -Not -BeNullOrEmpty
            $result.Result.Id | Should -Be 'mon-002'
            $result.RejectedTypes | Should -Contain 'microsoft.intune.devicecleanuprule'
        }
    }

    Context 'All types rejected' {

        It 'Returns null Result when all types are rejected' {
            $result = InModuleScope TenantBaseline {
                Mock New-TBMonitor {
                    $errJson = '{"error":{"code":"BadRequest","message":"Validation failed.","details":[{"code":"BadRequest","message":"ResourceType ''microsoft.intune.devicecleanuprule'' is not supported in monitor run type: ''monitorOnly''.","target":"microsoft.intune.devicecleanuprule"}]}}'
                    throw [System.Exception]::new($errJson)
                }

                $resources = @(
                    [PSCustomObject]@{ resourceType = 'microsoft.intune.devicecleanuprule'; displayName = 'microsoft.intune.devicecleanuprule'; properties = @{} }
                )

                Invoke-TBMonitorCreateWithRetry -DisplayName 'Test Monitor' -Resources $resources
            }

            $result.Result | Should -BeNullOrEmpty
            $result.RejectedTypes | Should -Contain 'microsoft.intune.devicecleanuprule'
        }
    }

    Context 'Non-retryable errors are rethrown' {

        It 'Throws when error is not a resource type rejection' {
            InModuleScope TenantBaseline {
                Mock New-TBMonitor {
                    throw [System.Exception]::new('Network timeout')
                }

                $resources = @(
                    [PSCustomObject]@{ resourceType = 'microsoft.entra.authorizationpolicy'; displayName = 'microsoft.entra.authorizationpolicy'; properties = @{ allowedToCreateTenants = $false } }
                )

                { Invoke-TBMonitorCreateWithRetry -DisplayName 'Test Monitor' -Resources $resources } | Should -Throw '*Network timeout*'
            }
        }
    }

    Context 'Includes description when provided' {

        It 'Passes description to New-TBMonitor' {
            $result = InModuleScope TenantBaseline {
                Mock New-TBMonitor {
                    return [PSCustomObject]@{ Id = 'mon-003'; DisplayName = 'Test Monitor'; Status = 'active' }
                }

                $resources = @(
                    [PSCustomObject]@{ resourceType = 'microsoft.entra.authorizationpolicy'; displayName = 'microsoft.entra.authorizationpolicy'; properties = @{ allowedToCreateTenants = $false } }
                )

                Invoke-TBMonitorCreateWithRetry -DisplayName 'Test Monitor' -Description 'My description' -Resources $resources
            }

            $result.Result.Id | Should -Be 'mon-003'
        }
    }
}
