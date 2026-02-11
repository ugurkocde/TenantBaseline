#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'New-TBSnapshotDiscovery' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Write-TBLog {}
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
    }

    Context 'Returns properties on successful snapshot' {

        It 'Returns Success=$true and populated Properties' {
            $result = InModuleScope TenantBaseline {
                Mock New-TBSnapshot {
                    return [PSCustomObject]@{ Id = 'snap-001' }
                }
                Mock Wait-TBSnapshotInteractive {
                    return [PSCustomObject]@{
                        Id               = 'snap-001'
                        Status           = 'succeeded'
                        ResourceLocation = 'https://example.com/content'
                    }
                }
                Mock Get-TBSnapshotResourceProperties {
                    return @{
                        'microsoft.entra.authorizationpolicy' = @{ allowedToCreateTenants = $false }
                        'microsoft.entra.authenticationmethodpolicyfido2' = @{ state = 'enabled' }
                    }
                }

                New-TBSnapshotDiscovery -ResourceTypes @(
                    'microsoft.entra.authorizationpolicy',
                    'microsoft.entra.authenticationmethodpolicyfido2'
                )
            }

            $result.Success | Should -BeTrue
            $result.SnapshotId | Should -Be 'snap-001'
            $result.Properties.Count | Should -Be 2
            $result.UnsupportedTypes.Count | Should -Be 0
        }
    }

    Context 'Retries and filters unsupported types' {

        It 'Returns UnsupportedTypes and retries without them' {
            $result = InModuleScope TenantBaseline {
                $script:snapAttempt = 0
                Mock New-TBSnapshot {
                    $script:snapAttempt++
                    if ($script:snapAttempt -eq 1) {
                        $errJson = '{"error":{"code":"BadRequest","message":"Invalid","details":[{"message":"ResourceType ''microsoft.intune.devicecleanuprule'' is not supported."}]}}'
                        $ex = [System.Exception]::new($errJson)
                        $errRecord = [System.Management.Automation.ErrorRecord]::new(
                            $ex, 'BadRequest', [System.Management.Automation.ErrorCategory]::InvalidArgument, $null)
                        $errRecord | Add-Member -NotePropertyName ErrorDetails -NotePropertyValue ([PSCustomObject]@{
                            Message = $errJson
                        }) -Force
                        throw $errRecord
                    }
                    return [PSCustomObject]@{ Id = 'snap-002' }
                }
                Mock Wait-TBSnapshotInteractive {
                    return [PSCustomObject]@{
                        Id               = 'snap-002'
                        Status           = 'succeeded'
                        ResourceLocation = 'https://example.com/content'
                    }
                }
                Mock Get-TBSnapshotResourceProperties {
                    return @{
                        'microsoft.entra.authorizationpolicy' = @{ allowedToCreateTenants = $false }
                    }
                }

                New-TBSnapshotDiscovery -ResourceTypes @(
                    'microsoft.entra.authorizationpolicy',
                    'microsoft.intune.devicecleanuprule'
                )
            }

            $result.Success | Should -BeTrue
            $result.SnapshotId | Should -Be 'snap-002'
            $result.Properties.Count | Should -Be 1
            $result.UnsupportedTypes | Should -Contain 'microsoft.intune.devicecleanuprule'
        }
    }

    Context 'Returns Success=$false when snapshot fails' {

        It 'Returns Success=$false when snapshot status is failed' {
            $result = InModuleScope TenantBaseline {
                Mock New-TBSnapshot {
                    return [PSCustomObject]@{ Id = 'snap-003' }
                }
                Mock Wait-TBSnapshotInteractive {
                    return [PSCustomObject]@{
                        Id               = 'snap-003'
                        Status           = 'failed'
                        ResourceLocation = $null
                    }
                }
                Mock Get-TBSnapshotResourceProperties {}

                New-TBSnapshotDiscovery -ResourceTypes @('microsoft.entra.authorizationpolicy')
            }

            $result.Success | Should -BeFalse
            $result.SnapshotId | Should -Be 'snap-003'
            $result.Properties.Count | Should -Be 0
        }
    }

    Context 'Handles all types unsupported by snapshot' {

        It 'Returns Success=$true with empty properties when all types are unsupported' {
            $result = InModuleScope TenantBaseline {
                Mock New-TBSnapshot {
                    $errJson = '{"error":{"code":"BadRequest","message":"Invalid","details":[{"message":"ResourceType ''microsoft.intune.devicecleanuprule'' is not supported."}]}}'
                    $ex = [System.Exception]::new($errJson)
                    $errRecord = [System.Management.Automation.ErrorRecord]::new(
                        $ex, 'BadRequest', [System.Management.Automation.ErrorCategory]::InvalidArgument, $null)
                    $errRecord | Add-Member -NotePropertyName ErrorDetails -NotePropertyValue ([PSCustomObject]@{
                        Message = $errJson
                    }) -Force
                    throw $errRecord
                }
                Mock Wait-TBSnapshotInteractive {}
                Mock Get-TBSnapshotResourceProperties {}

                New-TBSnapshotDiscovery -ResourceTypes @('microsoft.intune.devicecleanuprule')
            }

            $result.Success | Should -BeTrue
            $result.SnapshotId | Should -BeNullOrEmpty
            $result.Properties.Count | Should -Be 0
            $result.UnsupportedTypes | Should -Contain 'microsoft.intune.devicecleanuprule'
        }
    }

    Context 'Handles partiallySuccessful status' {

        It 'Returns Success=$true for partiallySuccessful snapshots' {
            $result = InModuleScope TenantBaseline {
                Mock New-TBSnapshot {
                    return [PSCustomObject]@{ Id = 'snap-004' }
                }
                Mock Wait-TBSnapshotInteractive {
                    return [PSCustomObject]@{
                        Id               = 'snap-004'
                        Status           = 'partiallySuccessful'
                        ResourceLocation = 'https://example.com/content'
                    }
                }
                Mock Get-TBSnapshotResourceProperties {
                    return @{
                        'microsoft.entra.authorizationpolicy' = @{ allowedToCreateTenants = $false }
                    }
                }

                New-TBSnapshotDiscovery -ResourceTypes @(
                    'microsoft.entra.authorizationpolicy',
                    'microsoft.entra.authenticationmethodpolicyfido2'
                )
            }

            $result.Success | Should -BeTrue
            $result.Properties.Count | Should -Be 1
        }
    }
}
