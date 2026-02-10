#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Start-TBInteractive' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Write-Host {}
        Mock -ModuleName TenantBaseline Show-TBMainMenu {}
        Mock -ModuleName TenantBaseline Invoke-TBQuickStart {}
    }

    Context 'Function exists and is exported' {

        It 'Is available as a module command' {
            $cmd = Get-Command -Name Start-TBInteractive -Module TenantBaseline -ErrorAction SilentlyContinue
            $cmd | Should -Not -BeNullOrEmpty
        }

        It 'Has CmdletBinding attribute' {
            $cmd = Get-Command -Name Start-TBInteractive -Module TenantBaseline
            $cmd.CmdletBinding | Should -BeTrue
        }
    }

    Context 'Already connected' {

        It 'Skips connection prompt and goes straight to menu' {
            Mock -ModuleName TenantBaseline Get-TBConnectionStatus {
                return [PSCustomObject]@{
                    Connected   = $true
                    TenantId    = 'test-tenant'
                    Account     = 'admin@test.com'
                    Scopes      = @()
                    ConnectedAt = $null
                }
            }

            InModuleScope TenantBaseline {
                Start-TBInteractive
            }

            Should -Invoke -CommandName Show-TBMainMenu -ModuleName TenantBaseline -Times 1
            Should -Invoke -CommandName Get-TBConnectionStatus -ModuleName TenantBaseline -Times 1
        }
    }

    Context 'Not connected - connect then success' {

        It 'Connects and opens menu only after status becomes connected' {
            $script:statusCalls = 0
            Mock -ModuleName TenantBaseline Get-TBConnectionStatus {
                $script:statusCalls++
                if ($script:statusCalls -eq 1) {
                    return [PSCustomObject]@{
                        Connected                = $false
                        TenantId                 = $null
                        Account                  = $null
                        Scopes                   = @()
                        ConnectedAt              = $null
                        TenantDisplayName        = $null
                        PrimaryDomain            = $null
                        IdentityLabel            = $null
                        DirectoryMetadataEnabled = $false
                    }
                }

                return [PSCustomObject]@{
                    Connected                = $true
                    TenantId                 = 'test-tenant'
                    Account                  = 'admin@test.com'
                    Scopes                   = @()
                    ConnectedAt              = $null
                    TenantDisplayName        = $null
                    PrimaryDomain            = $null
                    IdentityLabel            = 'test.com'
                    DirectoryMetadataEnabled = $false
                }
            }
            Mock -ModuleName TenantBaseline Read-Host { return '1' }
            Mock -ModuleName TenantBaseline Connect-TBTenant {}

            InModuleScope TenantBaseline {
                Start-TBInteractive
            }

            Should -Invoke -CommandName Connect-TBTenant -ModuleName TenantBaseline -Times 1
            Should -Invoke -CommandName Show-TBMainMenu -ModuleName TenantBaseline -Times 1
        }
    }

    Context 'Not connected - failure then retry then success' {

        It 'Keeps looping on failure and opens menu after a later success' {
            $script:statusCalls = 0
            Mock -ModuleName TenantBaseline Get-TBConnectionStatus {
                $script:statusCalls++
                if ($script:statusCalls -ge 4) {
                    return [PSCustomObject]@{
                        Connected                = $true
                        TenantId                 = 'test-tenant'
                        Account                  = 'admin@test.com'
                        Scopes                   = @()
                        ConnectedAt              = $null
                        TenantDisplayName        = $null
                        PrimaryDomain            = $null
                        IdentityLabel            = 'test.com'
                        DirectoryMetadataEnabled = $false
                    }
                }

                return [PSCustomObject]@{
                    Connected                = $false
                    TenantId                 = $null
                    Account                  = $null
                    Scopes                   = @()
                    ConnectedAt              = $null
                    TenantDisplayName        = $null
                    PrimaryDomain            = $null
                    IdentityLabel            = $null
                    DirectoryMetadataEnabled = $false
                }
            }

            $script:connectCalls = 0
            Mock -ModuleName TenantBaseline Connect-TBTenant {
                $script:connectCalls++
                if ($script:connectCalls -eq 1) {
                    throw 'Auth failed'
                }
            }

            $script:inputCalls = 0
            Mock -ModuleName TenantBaseline Read-Host {
                $script:inputCalls++
                switch ($script:inputCalls) {
                    1 { return '1' }
                    default { return '1' }
                }
            }

            InModuleScope TenantBaseline {
                Start-TBInteractive
            }

            Should -Invoke -CommandName Connect-TBTenant -ModuleName TenantBaseline -Times 2
            Should -Invoke -CommandName Show-TBMainMenu -ModuleName TenantBaseline -Times 1
        }
    }

    Context 'Not connected - first successful sign-in quick start' {

        It 'Runs quick start when user confirms' {
            $script:statusCalls = 0
            Mock -ModuleName TenantBaseline Get-TBConnectionStatus {
                $script:statusCalls++
                if ($script:statusCalls -eq 1) {
                    return [PSCustomObject]@{
                        Connected                = $false
                        TenantId                 = $null
                        Account                  = $null
                        Scopes                   = @()
                        ConnectedAt              = $null
                        TenantDisplayName        = $null
                        PrimaryDomain            = $null
                        IdentityLabel            = $null
                        DirectoryMetadataEnabled = $false
                    }
                }

                return [PSCustomObject]@{
                    Connected                = $true
                    TenantId                 = 'test-tenant'
                    Account                  = 'admin@test.com'
                    Scopes                   = @()
                    ConnectedAt              = $null
                    TenantDisplayName        = $null
                    PrimaryDomain            = $null
                    IdentityLabel            = 'test.com'
                    DirectoryMetadataEnabled = $false
                }
            }

            $script:inputCalls = 0
            Mock -ModuleName TenantBaseline Read-Host {
                $script:inputCalls++
                switch ($script:inputCalls) {
                    1 { return '1' }
                    2 { return 'Y' }
                    default { return '' }
                }
            }
            Mock -ModuleName TenantBaseline Connect-TBTenant {}

            InModuleScope TenantBaseline {
                Start-TBInteractive
            }

            Should -Invoke -CommandName Invoke-TBQuickStart -ModuleName TenantBaseline -Times 1
            Should -Invoke -CommandName Show-TBMainMenu -ModuleName TenantBaseline -Times 1
        }
    }

    Context 'Not connected - user exits' {

        It 'Exits interactive mode without showing the menu' {
            Mock -ModuleName TenantBaseline Get-TBConnectionStatus {
                return [PSCustomObject]@{
                    Connected                = $false
                    TenantId                 = $null
                    Account                  = $null
                    Scopes                   = @()
                    ConnectedAt              = $null
                    TenantDisplayName        = $null
                    PrimaryDomain            = $null
                    IdentityLabel            = $null
                    DirectoryMetadataEnabled = $false
                }
            }
            Mock -ModuleName TenantBaseline Read-Host { return '2' }
            Mock -ModuleName TenantBaseline Connect-TBTenant {}

            InModuleScope TenantBaseline {
                Start-TBInteractive
            }

            Should -Not -Invoke -CommandName Connect-TBTenant -ModuleName TenantBaseline
            Should -Not -Invoke -CommandName Show-TBMainMenu -ModuleName TenantBaseline
        }
    }
}
