#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Get-TBConnectionStatus' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Write-TBLog {}
        InModuleScope TenantBaseline { $script:TBConnection = $null }
    }

    Context 'Returns Connected=$true when context exists' {

        It 'Reports connected status with enriched tenant identity details' {
            Mock -ModuleName TenantBaseline Get-MgContext {
                return [PSCustomObject]@{
                    TenantId = '96bf81b4-2694-42bb-9204-70081135ca61'
                    Account  = 'admin@contoso.onmicrosoft.com'
                    Scopes   = @('ConfigurationMonitoring.ReadWrite.All', 'Organization.Read.All', 'Domain.Read.All')
                }
            }
            InModuleScope TenantBaseline {
                $script:TBConnection = [PSCustomObject]@{
                    ConnectedAt              = [datetime]::new(2025, 1, 20, 10, 0, 0)
                    TenantDisplayName        = 'Contoso'
                    PrimaryDomain            = 'contoso.onmicrosoft.com'
                    DirectoryMetadataEnabled = $true
                    Environment              = 'Global'
                }
            }

            $result = Get-TBConnectionStatus

            $result.Connected | Should -BeTrue
            $result.TenantId | Should -Be '96bf81b4-2694-42bb-9204-70081135ca61'
            $result.Account | Should -Be 'admin@contoso.onmicrosoft.com'
            $result.Scopes | Should -Contain 'ConfigurationMonitoring.ReadWrite.All'
            $result.TenantDisplayName | Should -Be 'Contoso'
            $result.PrimaryDomain | Should -Be 'contoso.onmicrosoft.com'
            $result.IdentityLabel | Should -Be 'contoso.onmicrosoft.com'
            $result.DirectoryMetadataEnabled | Should -BeTrue
            $result.Environment | Should -Be 'Global'
        }
    }

    Context 'Returns Connected=$false when no context' {

        It 'Reports disconnected status when Get-MgContext returns null' {
            Mock -ModuleName TenantBaseline Get-MgContext { return $null }

            $result = Get-TBConnectionStatus

            $result.Connected | Should -BeFalse
            $result.TenantId | Should -BeNullOrEmpty
            $result.Account | Should -BeNullOrEmpty
            $result.TenantDisplayName | Should -BeNullOrEmpty
            $result.PrimaryDomain | Should -BeNullOrEmpty
            $result.IdentityLabel | Should -BeNullOrEmpty
            $result.DirectoryMetadataEnabled | Should -BeFalse
            $result.Environment | Should -BeNullOrEmpty
        }

        It 'Reports disconnected status when Get-MgContext throws' {
            Mock -ModuleName TenantBaseline Get-MgContext { throw 'Not connected' }

            $result = Get-TBConnectionStatus

            $result.Connected | Should -BeFalse
        }
    }

    Context 'Includes ConnectedAt from module state' {

        It 'Returns ConnectedAt when TBConnection is set' {
            Mock -ModuleName TenantBaseline Get-MgContext {
                return [PSCustomObject]@{
                    TenantId = '96bf81b4-2694-42bb-9204-70081135ca61'
                    Account  = 'admin@contoso.onmicrosoft.com'
                    Scopes   = @('ConfigurationMonitoring.ReadWrite.All')
                }
            }

            InModuleScope TenantBaseline {
                $script:TBConnection = [PSCustomObject]@{
                    TenantId    = '96bf81b4-2694-42bb-9204-70081135ca61'
                    Account     = 'admin@contoso.onmicrosoft.com'
                    Scopes      = @('ConfigurationMonitoring.ReadWrite.All')
                    ConnectedAt = [datetime]::new(2025, 1, 20, 10, 0, 0)
                }
            }

            $result = Get-TBConnectionStatus
            $result.ConnectedAt | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Identity fallback chain' {

        It 'Uses tenant display name when primary domain is not available' {
            Mock -ModuleName TenantBaseline Get-MgContext {
                return [PSCustomObject]@{
                    TenantId = '96bf81b4-2694-42bb-9204-70081135ca61'
                    Account  = 'admin@contoso.onmicrosoft.com'
                    Scopes   = @('ConfigurationMonitoring.ReadWrite.All')
                }
            }
            InModuleScope TenantBaseline {
                $script:TBConnection = [PSCustomObject]@{
                    ConnectedAt              = [datetime]::new(2025, 1, 20, 10, 0, 0)
                    TenantDisplayName        = 'Contoso'
                    PrimaryDomain            = $null
                    DirectoryMetadataEnabled = $false
                }
            }

            $result = Get-TBConnectionStatus
            $result.IdentityLabel | Should -Be 'Contoso'
        }

        It 'Uses account UPN domain when directory metadata is missing' {
            Mock -ModuleName TenantBaseline Get-MgContext {
                return [PSCustomObject]@{
                    TenantId = '96bf81b4-2694-42bb-9204-70081135ca61'
                    Account  = 'admin@contoso.onmicrosoft.com'
                    Scopes   = @('ConfigurationMonitoring.ReadWrite.All')
                }
            }
            InModuleScope TenantBaseline { $script:TBConnection = $null }

            $result = Get-TBConnectionStatus
            $result.IdentityLabel | Should -Be 'contoso.onmicrosoft.com'
        }

        It 'Falls back to tenant ID when account domain is unavailable' {
            Mock -ModuleName TenantBaseline Get-MgContext {
                return [PSCustomObject]@{
                    TenantId = '96bf81b4-2694-42bb-9204-70081135ca61'
                    Account  = 'admin'
                    Scopes   = @('ConfigurationMonitoring.ReadWrite.All')
                }
            }
            InModuleScope TenantBaseline { $script:TBConnection = $null }

            $result = Get-TBConnectionStatus
            $result.IdentityLabel | Should -Be '96bf81b4-2694-42bb-9204-70081135ca61'
        }
    }

    Context 'Environment field' {

        It 'Returns Environment from TBConnection when connected' {
            Mock -ModuleName TenantBaseline Get-MgContext {
                return [PSCustomObject]@{
                    TenantId = '96bf81b4-2694-42bb-9204-70081135ca61'
                    Account  = 'admin@contoso.onmicrosoft.com'
                    Scopes   = @('ConfigurationMonitoring.ReadWrite.All')
                }
            }
            InModuleScope TenantBaseline {
                $script:TBConnection = [PSCustomObject]@{
                    ConnectedAt              = [datetime]::new(2025, 1, 20, 10, 0, 0)
                    TenantDisplayName        = $null
                    PrimaryDomain            = $null
                    DirectoryMetadataEnabled = $false
                    Environment              = 'USGov'
                }
            }

            $result = Get-TBConnectionStatus
            $result.Environment | Should -Be 'USGov'
        }

        It 'Returns null Environment when TBConnection has no Environment' {
            Mock -ModuleName TenantBaseline Get-MgContext {
                return [PSCustomObject]@{
                    TenantId = '96bf81b4-2694-42bb-9204-70081135ca61'
                    Account  = 'admin@contoso.onmicrosoft.com'
                    Scopes   = @('ConfigurationMonitoring.ReadWrite.All')
                }
            }
            InModuleScope TenantBaseline { $script:TBConnection = $null }

            $result = Get-TBConnectionStatus
            $result.Environment | Should -BeNullOrEmpty
        }
    }
}
