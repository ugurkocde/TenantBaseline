#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Get-TBSnapshotResourceProperties' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Write-TBLog {}
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
    }

    Context 'Parses flat array content' {

        It 'Returns properties keyed by lowercase resource type' {
            $result = InModuleScope TenantBaseline {
                Mock Invoke-TBGraphRequest {
                    return @(
                        @{
                            resourceType = 'microsoft.entra.AuthenticationMethodPolicyFido2'
                            properties   = @{ IsAttestationEnforced = $true }
                        }
                        @{
                            resourceType = 'microsoft.exchange.AcceptedDomain'
                            properties   = @{ DomainType = 'Authoritative' }
                        }
                    )
                }

                $snapshot = [PSCustomObject]@{
                    Status           = 'succeeded'
                    ResourceLocation = 'https://graph.microsoft.com/beta/admin/configurationManagement/configurationSnapshots/test/content'
                }

                Get-TBSnapshotResourceProperties -Snapshot $snapshot
            }

            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 2
            $result.ContainsKey('microsoft.entra.authenticationmethodpolicyfido2') | Should -BeTrue
            $result.ContainsKey('microsoft.exchange.accepteddomain') | Should -BeTrue
            $result['microsoft.entra.authenticationmethodpolicyfido2'].IsAttestationEnforced | Should -BeTrue
        }
    }

    Context 'Parses value-wrapped content' {

        It 'Extracts items from a value array' {
            $result = InModuleScope TenantBaseline {
                Mock Invoke-TBGraphRequest {
                    return @{
                        value = @(
                            @{
                                resourceType = 'microsoft.teams.TeamsClientConfiguration'
                                properties   = @{ AllowBox = $false }
                            }
                        )
                    }
                }

                $snapshot = [PSCustomObject]@{
                    Status           = 'succeeded'
                    ResourceLocation = 'https://example.com/content'
                }

                Get-TBSnapshotResourceProperties -Snapshot $snapshot
            }

            $result.Count | Should -Be 1
            $result.ContainsKey('microsoft.teams.teamsclientconfiguration') | Should -BeTrue
        }
    }

    Context 'Parses resources-wrapped content' {

        It 'Extracts items from a resources array' {
            $result = InModuleScope TenantBaseline {
                Mock Invoke-TBGraphRequest {
                    return @{
                        resources = @(
                            @{
                                resourceType = 'microsoft.intune.DeviceCompliancePolicy'
                                properties   = @{ PasswordRequired = $true }
                            }
                        )
                    }
                }

                $snapshot = [PSCustomObject]@{
                    Status           = 'succeeded'
                    ResourceLocation = 'https://example.com/content'
                }

                Get-TBSnapshotResourceProperties -Snapshot $snapshot
            }

            $result.Count | Should -Be 1
            $result.ContainsKey('microsoft.intune.devicecompliancepolicy') | Should -BeTrue
        }
    }

    Context 'Handles PSCustomObject content' {

        It 'Extracts items from PSCustomObject with value property' {
            $result = InModuleScope TenantBaseline {
                Mock Invoke-TBGraphRequest {
                    return [PSCustomObject]@{
                        value = @(
                            [PSCustomObject]@{
                                resourceType = 'microsoft.entra.ConditionalAccessPolicy'
                                properties   = [PSCustomObject]@{ State = 'enabled' }
                            }
                        )
                    }
                }

                $snapshot = [PSCustomObject]@{
                    Status           = 'succeeded'
                    ResourceLocation = 'https://example.com/content'
                }

                Get-TBSnapshotResourceProperties -Snapshot $snapshot
            }

            $result.Count | Should -Be 1
            $result.ContainsKey('microsoft.entra.conditionalaccesspolicy') | Should -BeTrue
        }
    }

    Context 'Returns lowercase resource type keys' {

        It 'Lowercases mixed-case resource type names' {
            $result = InModuleScope TenantBaseline {
                Mock Invoke-TBGraphRequest {
                    return @(
                        @{
                            resourceType = 'Microsoft.Entra.FIDO2Policy'
                            properties   = @{ Enabled = $true }
                        }
                    )
                }

                $snapshot = [PSCustomObject]@{
                    Status           = 'succeeded'
                    ResourceLocation = 'https://example.com/content'
                }

                Get-TBSnapshotResourceProperties -Snapshot $snapshot
            }

            $result.ContainsKey('microsoft.entra.fido2policy') | Should -BeTrue
        }
    }

    Context 'Throws on failed snapshot status' {

        It 'Throws when snapshot status is failed' {
            InModuleScope TenantBaseline {
                $snapshot = [PSCustomObject]@{
                    Status           = 'failed'
                    ResourceLocation = 'https://example.com/content'
                }

                { Get-TBSnapshotResourceProperties -Snapshot $snapshot } | Should -Throw '*status is "failed"*'
            }
        }

        It 'Throws when snapshot status is notStarted' {
            InModuleScope TenantBaseline {
                $snapshot = [PSCustomObject]@{
                    Status           = 'notStarted'
                    ResourceLocation = 'https://example.com/content'
                }

                { Get-TBSnapshotResourceProperties -Snapshot $snapshot } | Should -Throw '*status is "notStarted"*'
            }
        }
    }

    Context 'Throws on missing ResourceLocation' {

        It 'Throws when ResourceLocation is null' {
            InModuleScope TenantBaseline {
                $snapshot = [PSCustomObject]@{
                    Status           = 'succeeded'
                    ResourceLocation = $null
                }

                { Get-TBSnapshotResourceProperties -Snapshot $snapshot } | Should -Throw '*no ResourceLocation*'
            }
        }
    }

    Context 'Returns empty hashtable on null or empty content' {

        It 'Returns empty hashtable when API returns null' {
            $result = InModuleScope TenantBaseline {
                Mock Invoke-TBGraphRequest { return $null }

                $snapshot = [PSCustomObject]@{
                    Status           = 'succeeded'
                    ResourceLocation = 'https://example.com/content'
                }

                Get-TBSnapshotResourceProperties -Snapshot $snapshot
            }

            $result | Should -BeOfType [hashtable]
            $result.Count | Should -Be 0
        }
    }

    Context 'Skips items missing resourceType or properties' {

        It 'Skips items without resourceType' {
            $result = InModuleScope TenantBaseline {
                Mock Invoke-TBGraphRequest {
                    return @(
                        @{ properties = @{ Foo = 'bar' } }
                        @{ resourceType = 'microsoft.entra.policy'; properties = @{ State = 'on' } }
                    )
                }

                $snapshot = [PSCustomObject]@{
                    Status           = 'succeeded'
                    ResourceLocation = 'https://example.com/content'
                }

                Get-TBSnapshotResourceProperties -Snapshot $snapshot
            }

            $result.Count | Should -Be 1
            $result.ContainsKey('microsoft.entra.policy') | Should -BeTrue
        }

        It 'Skips items without properties' {
            $result = InModuleScope TenantBaseline {
                Mock Invoke-TBGraphRequest {
                    return @(
                        @{ resourceType = 'microsoft.entra.noprops' }
                        @{ resourceType = 'microsoft.entra.withprops'; properties = @{ Key = 'val' } }
                    )
                }

                $snapshot = [PSCustomObject]@{
                    Status           = 'succeeded'
                    ResourceLocation = 'https://example.com/content'
                }

                Get-TBSnapshotResourceProperties -Snapshot $snapshot
            }

            $result.Count | Should -Be 1
            $result.ContainsKey('microsoft.entra.withprops') | Should -BeTrue
        }

        It 'Skips items with empty properties hashtable' {
            $result = InModuleScope TenantBaseline {
                Mock Invoke-TBGraphRequest {
                    return @(
                        @{ resourceType = 'microsoft.entra.empty'; properties = @{} }
                        @{ resourceType = 'microsoft.entra.filled'; properties = @{ A = 1 } }
                    )
                }

                $snapshot = [PSCustomObject]@{
                    Status           = 'succeeded'
                    ResourceLocation = 'https://example.com/content'
                }

                Get-TBSnapshotResourceProperties -Snapshot $snapshot
            }

            $result.Count | Should -Be 1
            $result.ContainsKey('microsoft.entra.filled') | Should -BeTrue
        }
    }

    Context 'Works with partiallySuccessful status' {

        It 'Accepts partiallySuccessful snapshots' {
            $result = InModuleScope TenantBaseline {
                Mock Invoke-TBGraphRequest {
                    return @(
                        @{ resourceType = 'microsoft.entra.policy'; properties = @{ State = 'on' } }
                    )
                }

                $snapshot = [PSCustomObject]@{
                    Status           = 'partiallySuccessful'
                    ResourceLocation = 'https://example.com/content'
                }

                Get-TBSnapshotResourceProperties -Snapshot $snapshot
            }

            $result.Count | Should -Be 1
        }
    }
}
