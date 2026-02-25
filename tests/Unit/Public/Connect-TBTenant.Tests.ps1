#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Connect-TBTenant' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Write-TBLog {}
        Mock -ModuleName TenantBaseline Connect-MgGraph {}
        InModuleScope TenantBaseline { $script:TBConnection = $null }
        Mock -ModuleName TenantBaseline Get-TBDirectoryMetadata {
            return [PSCustomObject]@{
                TenantDisplayName = 'Contoso'
                PrimaryDomain     = 'contoso.onmicrosoft.com'
            }
        }
        Mock -ModuleName TenantBaseline Get-TBGraphBaseUri { return 'https://graph.microsoft.com' }
        Mock -ModuleName TenantBaseline Get-MgContext {
            return [PSCustomObject]@{
                TenantId    = '96bf81b4-2694-42bb-9204-70081135ca61'
                Account     = 'admin@contoso.onmicrosoft.com'
                Scopes      = @('ConfigurationMonitoring.ReadWrite.All')
                Environment = 'Global'
            }
        }
    }

    Context 'Calls Connect-MgGraph with correct default scopes' {

        It 'Passes ConfigurationMonitoring.ReadWrite.All by default' {
            Connect-TBTenant

            Should -Invoke -CommandName Connect-MgGraph -ModuleName TenantBaseline -Times 1 -Exactly -ParameterFilter {
                $Scopes -contains 'ConfigurationMonitoring.ReadWrite.All' -and
                -not ($Scopes -contains 'Application.ReadWrite.All') -and
                -not ($Scopes -contains 'Organization.Read.All') -and
                -not ($Scopes -contains 'Domain.Read.All')
            }
        }
    }

    Context 'Sets script:TBConnection on success' {

        It 'Sets the module-scoped connection variable' {
            Connect-TBTenant

            $status = InModuleScope TenantBaseline { $script:TBConnection }
            $status | Should -Not -BeNullOrEmpty
            $status.TenantId | Should -Be '96bf81b4-2694-42bb-9204-70081135ca61'
            $status.Account | Should -Be 'admin@contoso.onmicrosoft.com'
            $status.DirectoryMetadataEnabled | Should -BeFalse
        }
    }

    Context 'Passes TenantId when specified' {

        It 'Includes TenantId in Connect-MgGraph parameters' {
            Connect-TBTenant -TenantId 'contoso.onmicrosoft.com'

            Should -Invoke -CommandName Connect-MgGraph -ModuleName TenantBaseline -Times 1 -Exactly -ParameterFilter {
                $TenantId -eq 'contoso.onmicrosoft.com'
            }
        }
    }

    Context 'Merges additional scopes' {

        It 'Combines default scopes with user-specified scopes' {
            Connect-TBTenant -Scopes @('User.Read.All')

            Should -Invoke -CommandName Connect-MgGraph -ModuleName TenantBaseline -Times 1 -Exactly -ParameterFilter {
                $scopeText = @($Scopes) -join ','
                $scopeText -match 'ConfigurationMonitoring\.ReadWrite\.All' -and
                $scopeText -match 'User\.Read\.All'
            }
        }
    }

    Context 'Scenario-based scopes' {

        It 'Uses setup scope profile when -Scenario Setup is used' {
            Connect-TBTenant -Scenario Setup

            Should -Invoke -CommandName Connect-MgGraph -ModuleName TenantBaseline -Times 1 -Exactly -ParameterFilter {
                $Scopes -contains 'ConfigurationMonitoring.ReadWrite.All' -and
                $Scopes -contains 'Application.ReadWrite.All' -and
                $Scopes -contains 'AppRoleAssignment.ReadWrite.All'
            }
        }

        It 'Uses read-only scope profile when -Scenario ReadOnly is used' {
            Connect-TBTenant -Scenario ReadOnly

            Should -Invoke -CommandName Connect-MgGraph -ModuleName TenantBaseline -Times 1 -Exactly -ParameterFilter {
                $Scopes -contains 'ConfigurationMonitoring.Read.All' -and
                -not ($Scopes -contains 'ConfigurationMonitoring.ReadWrite.All')
            }
        }
    }

    Context 'Optional directory metadata scopes' {

        It 'Adds Organization.Read.All and Domain.Read.All only when requested' {
            Connect-TBTenant -IncludeDirectoryMetadata

            Should -Invoke -CommandName Connect-MgGraph -ModuleName TenantBaseline -Times 1 -Exactly -ParameterFilter {
                $Scopes -contains 'ConfigurationMonitoring.ReadWrite.All' -and
                $Scopes -contains 'Organization.Read.All' -and
                $Scopes -contains 'Domain.Read.All'
            }
        }
    }

    Context 'Directory metadata cache population' {

        It 'Caches tenant display name and primary domain when metadata is requested' {
            Connect-TBTenant -IncludeDirectoryMetadata

            $status = InModuleScope TenantBaseline { $script:TBConnection }
            $status.DirectoryMetadataEnabled | Should -BeTrue
            $status.TenantDisplayName | Should -Be 'Contoso'
            $status.PrimaryDomain | Should -Be 'contoso.onmicrosoft.com'
            Should -Invoke -CommandName Get-TBDirectoryMetadata -ModuleName TenantBaseline -Times 1
        }
    }

    Context 'Directory metadata lookup failure' {

        It 'Continues connection when metadata lookup fails' {
            Mock -ModuleName TenantBaseline Get-TBDirectoryMetadata { throw 'Insufficient privileges' }

            { Connect-TBTenant -IncludeDirectoryMetadata } | Should -Not -Throw

            $status = InModuleScope TenantBaseline { $script:TBConnection }
            $status.DirectoryMetadataEnabled | Should -BeTrue
            $status.TenantDisplayName | Should -BeNullOrEmpty
            $status.PrimaryDomain | Should -BeNullOrEmpty
        }
    }

    Context 'Connection failure' {

        It 'Throws when Connect-MgGraph fails' {
            Mock -ModuleName TenantBaseline Connect-MgGraph { throw 'Auth failed' }

            { Connect-TBTenant } | Should -Throw
        }
    }

    Context 'Environment parameter' {

        It 'Passes Environment to Connect-MgGraph' {
            Connect-TBTenant -Environment USGov

            Should -Invoke -CommandName Connect-MgGraph -ModuleName TenantBaseline -Times 1 -Exactly -ParameterFilter {
                $Environment -eq 'USGov'
            }
        }

        It 'Defaults to Global environment' {
            Connect-TBTenant

            Should -Invoke -CommandName Connect-MgGraph -ModuleName TenantBaseline -Times 1 -Exactly -ParameterFilter {
                $Environment -eq 'Global'
            }
        }

        It 'Stores Environment in TBConnection' {
            Connect-TBTenant -Environment USGov

            $conn = InModuleScope TenantBaseline { $script:TBConnection }
            $conn.Environment | Should -Be 'USGov'
        }

        It 'Updates TBApiBaseUri after connection' {
            Mock -ModuleName TenantBaseline Get-TBGraphBaseUri { return 'https://graph.microsoft.us' }

            Connect-TBTenant -Environment USGov

            $uri = InModuleScope TenantBaseline { $script:TBApiBaseUri }
            $uri | Should -Be 'https://graph.microsoft.us/beta/admin/configurationManagement'
        }

        It 'Emits a warning when Environment is not Global' {
            Connect-TBTenant -Environment USGov

            Should -Invoke -CommandName Write-TBLog -ModuleName TenantBaseline -ParameterFilter {
                $Message -like '*UTCM APIs are only available in the Global cloud*' -and $Level -eq 'Warning'
            } -Times 1
        }

        It 'Does not emit a national cloud warning for Global environment' {
            Connect-TBTenant -Environment Global

            Should -Invoke -CommandName Write-TBLog -ModuleName TenantBaseline -ParameterFilter {
                $Message -like '*UTCM APIs are only available in the Global cloud*' -and $Level -eq 'Warning'
            } -Times 0 -Exactly
        }
    }
}
