#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Show-TBMainMenu' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Write-Host {}
        Mock -ModuleName TenantBaseline Write-TBMenuHeader {}
        Mock -ModuleName TenantBaseline Clear-Host {}
        Mock -ModuleName TenantBaseline Get-TBConnectionStatus {
            return [PSCustomObject]@{
                Connected                = $true
                TenantId                 = 'test-tenant-guid'
                Account                  = 'admin@test.com'
                Scopes                   = @('ConfigurationMonitoring.ReadWrite.All', 'Application.ReadWrite.All')
                ConnectedAt              = $null
                TenantDisplayName        = $null
                PrimaryDomain            = $null
                IdentityLabel            = 'test.com'
                DirectoryMetadataEnabled = $false
            }
        }
    }

    Context 'Classic path - Exits on Quit' {

        It 'Returns when user selects Quit' {
            Mock -ModuleName TenantBaseline Test-TBArrowKeySupport { return $false }
            Mock -ModuleName TenantBaseline Show-TBMenu { return 'Quit' }

            InModuleScope TenantBaseline {
                Show-TBMainMenu
            }

            Should -Invoke -CommandName Show-TBMenu -ModuleName TenantBaseline -Times 1
            Should -Invoke -CommandName Write-TBMenuHeader -ModuleName TenantBaseline -Times 1 -ParameterFilter { $Mode -eq 'Rich' }
        }
    }

    Context 'Classic path - Routes to submenus' {

        BeforeEach {
            Mock -ModuleName TenantBaseline Test-TBArrowKeySupport { return $false }
        }

        It 'Shows connection status when option 0 is selected' {
            $script:menuCalls = 0
            Mock -ModuleName TenantBaseline Show-TBMenu {
                $script:menuCalls++
                if ($script:menuCalls -eq 1) { return 0 }
                return 'Quit'
            }
            Mock -ModuleName TenantBaseline Get-TBConnectionStatus {
                return [PSCustomObject]@{
                    Connected   = $true
                    TenantId    = 'test-tenant'
                    Account     = 'admin@test.com'
                    Scopes      = @()
                    ConnectedAt = $null
                }
            }
            Mock -ModuleName TenantBaseline Read-Host { return '' }

            InModuleScope TenantBaseline {
                Show-TBMainMenu
            }

            Should -Invoke -CommandName Get-TBConnectionStatus -ModuleName TenantBaseline
        }

        It 'Shows friendly tenant identity label in connection status' {
            $script:menuCalls = 0
            Mock -ModuleName TenantBaseline Show-TBMenu {
                $script:menuCalls++
                if ($script:menuCalls -eq 1) { return 0 }
                return 'Quit'
            }
            Mock -ModuleName TenantBaseline Get-TBConnectionStatus {
                return [PSCustomObject]@{
                    Connected                = $true
                    TenantId                 = 'test-tenant-guid'
                    Account                  = 'admin@test.com'
                    Scopes                   = @('ConfigurationMonitoring.ReadWrite.All')
                    ConnectedAt              = $null
                    TenantDisplayName        = 'Contoso'
                    PrimaryDomain            = 'contoso.com'
                    IdentityLabel            = 'contoso.com'
                    DirectoryMetadataEnabled = $true
                }
            }
            Mock -ModuleName TenantBaseline Read-Host { return '' }

            InModuleScope TenantBaseline {
                Show-TBMainMenu
            }

            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter {
                $Object -match 'Organization:\s+contoso\.com'
            }
        }

        It 'Triggers optional metadata consent when user selects D' {
            $script:menuCalls = 0
            Mock -ModuleName TenantBaseline Show-TBMenu {
                $script:menuCalls++
                if ($script:menuCalls -eq 1) { return 0 }
                return 'Quit'
            }
            Mock -ModuleName TenantBaseline Get-TBConnectionStatus {
                return [PSCustomObject]@{
                    Connected                = $true
                    TenantId                 = 'test-tenant-guid'
                    Account                  = 'admin@test.com'
                    Scopes                   = @('ConfigurationMonitoring.ReadWrite.All')
                    ConnectedAt              = $null
                    TenantDisplayName        = $null
                    PrimaryDomain            = $null
                    IdentityLabel            = 'test.com'
                    DirectoryMetadataEnabled = $false
                }
            }
            $script:readHostCalls = 0
            Mock -ModuleName TenantBaseline Read-Host {
                $script:readHostCalls++
                if ($script:readHostCalls -eq 1) { return 'D' }
                return ''
            }
            Mock -ModuleName TenantBaseline Connect-TBTenant {}

            InModuleScope TenantBaseline {
                Show-TBMainMenu
            }

            Should -Invoke -CommandName Connect-TBTenant -ModuleName TenantBaseline -Times 1 -ParameterFilter {
                $IncludeDirectoryMetadata -and $Scenario -eq 'Manage' -and $TenantId -eq 'test-tenant-guid'
            }
        }

        It 'Hides technical details by default in connection status view' {
            $script:menuCalls = 0
            Mock -ModuleName TenantBaseline Show-TBMenu {
                $script:menuCalls++
                if ($script:menuCalls -eq 1) { return 0 }
                return 'Quit'
            }
            Mock -ModuleName TenantBaseline Get-TBConnectionStatus {
                return [PSCustomObject]@{
                    Connected                = $true
                    TenantId                 = 'test-tenant-guid'
                    Account                  = 'admin@test.com'
                    Scopes                   = @('ConfigurationMonitoring.ReadWrite.All')
                    ConnectedAt              = $null
                    TenantDisplayName        = $null
                    PrimaryDomain            = $null
                    IdentityLabel            = 'test.com'
                    DirectoryMetadataEnabled = $true
                }
            }
            Mock -ModuleName TenantBaseline Read-Host { return '' }

            InModuleScope TenantBaseline {
                Show-TBMainMenu
            }

            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter {
                $Object -match 'Technical details are hidden'
            }
            Should -Not -Invoke -CommandName Write-Host -ModuleName TenantBaseline -ParameterFilter {
                $Object -match 'Scopes:'
            }
        }

        It 'Shows technical details when user toggles with T' {
            $script:menuCalls = 0
            Mock -ModuleName TenantBaseline Show-TBMenu {
                $script:menuCalls++
                if ($script:menuCalls -eq 1) { return 0 }
                return 'Quit'
            }
            Mock -ModuleName TenantBaseline Get-TBConnectionStatus {
                return [PSCustomObject]@{
                    Connected                = $true
                    TenantId                 = 'test-tenant-guid'
                    Account                  = 'admin@test.com'
                    Scopes                   = @('ConfigurationMonitoring.ReadWrite.All')
                    ConnectedAt              = $null
                    TenantDisplayName        = $null
                    PrimaryDomain            = $null
                    IdentityLabel            = 'test.com'
                    DirectoryMetadataEnabled = $true
                }
            }
            $script:readHostCalls = 0
            Mock -ModuleName TenantBaseline Read-Host {
                $script:readHostCalls++
                if ($script:readHostCalls -eq 1) { return 'T' }
                return ''
            }

            InModuleScope TenantBaseline {
                Show-TBMainMenu
            }

            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter {
                $Object -match 'Scopes:'
            }
        }

        It 'Calls Show-TBSetupMenu when option 1 is selected' {
            $script:menuCalls = 0
            Mock -ModuleName TenantBaseline Show-TBMenu {
                $script:menuCalls++
                if ($script:menuCalls -eq 1) { return 1 }
                return 'Quit'
            }
            Mock -ModuleName TenantBaseline Show-TBSetupMenu {}

            InModuleScope TenantBaseline {
                Show-TBMainMenu
            }

            Should -Invoke -CommandName Show-TBSetupMenu -ModuleName TenantBaseline -Times 1
        }

        It 'Calls Show-TBMonitorMenu when option 2 is selected' {
            $script:menuCalls = 0
            Mock -ModuleName TenantBaseline Show-TBMenu {
                $script:menuCalls++
                if ($script:menuCalls -eq 1) { return 2 }
                return 'Quit'
            }
            Mock -ModuleName TenantBaseline Show-TBMonitorMenu {}

            InModuleScope TenantBaseline {
                Show-TBMainMenu
            }

            Should -Invoke -CommandName Show-TBMonitorMenu -ModuleName TenantBaseline -Times 1
        }

        It 'Calls Show-TBBaselineMenu when option 3 is selected' {
            $script:menuCalls = 0
            Mock -ModuleName TenantBaseline Show-TBMenu {
                $script:menuCalls++
                if ($script:menuCalls -eq 1) { return 3 }
                return 'Quit'
            }
            Mock -ModuleName TenantBaseline Show-TBBaselineMenu {}

            InModuleScope TenantBaseline {
                Show-TBMainMenu
            }

            Should -Invoke -CommandName Show-TBBaselineMenu -ModuleName TenantBaseline -Times 1
        }

        It 'Calls Show-TBSnapshotMenu when option 4 is selected' {
            $script:menuCalls = 0
            Mock -ModuleName TenantBaseline Show-TBMenu {
                $script:menuCalls++
                if ($script:menuCalls -eq 1) { return 4 }
                return 'Quit'
            }
            Mock -ModuleName TenantBaseline Show-TBSnapshotMenu {}

            InModuleScope TenantBaseline {
                Show-TBMainMenu
            }

            Should -Invoke -CommandName Show-TBSnapshotMenu -ModuleName TenantBaseline -Times 1
        }

        It 'Calls Show-TBDriftMenu when option 5 is selected' {
            $script:menuCalls = 0
            Mock -ModuleName TenantBaseline Show-TBMenu {
                $script:menuCalls++
                if ($script:menuCalls -eq 1) { return 5 }
                return 'Quit'
            }
            Mock -ModuleName TenantBaseline Show-TBDriftMenu {}

            InModuleScope TenantBaseline {
                Show-TBMainMenu
            }

            Should -Invoke -CommandName Show-TBDriftMenu -ModuleName TenantBaseline -Times 1
        }

        It 'Calls Show-TBReportMenu when option 6 is selected' {
            $script:menuCalls = 0
            Mock -ModuleName TenantBaseline Show-TBMenu {
                $script:menuCalls++
                if ($script:menuCalls -eq 1) { return 6 }
                return 'Quit'
            }
            Mock -ModuleName TenantBaseline Show-TBReportMenu {}

            InModuleScope TenantBaseline {
                Show-TBMainMenu
            }

            Should -Invoke -CommandName Show-TBReportMenu -ModuleName TenantBaseline -Times 1
        }

        It 'Shows capability summary line in main menu' {
            Mock -ModuleName TenantBaseline Show-TBMenu { return 'Quit' }

            InModuleScope TenantBaseline {
                Show-TBMainMenu
            }

            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter {
                $Object -match 'What you can do now:'
            }
        }

        It 'Blocks setup submenu when setup scope is missing' {
            $script:menuCalls = 0
            Mock -ModuleName TenantBaseline Show-TBMenu {
                $script:menuCalls++
                if ($script:menuCalls -eq 1) { return 1 }
                return 'Quit'
            }
            Mock -ModuleName TenantBaseline Get-TBConnectionStatus {
                return [PSCustomObject]@{
                    Connected                = $true
                    TenantId                 = 'test-tenant-guid'
                    Account                  = 'admin@test.com'
                    Scopes                   = @('ConfigurationMonitoring.ReadWrite.All')
                    ConnectedAt              = $null
                    TenantDisplayName        = $null
                    PrimaryDomain            = $null
                    IdentityLabel            = 'test.com'
                    DirectoryMetadataEnabled = $false
                }
            }
            Mock -ModuleName TenantBaseline Show-TBSetupMenu {}
            Mock -ModuleName TenantBaseline Read-Host { return '' }

            InModuleScope TenantBaseline {
                Show-TBMainMenu
            }

            Should -Not -Invoke -CommandName Show-TBSetupMenu -ModuleName TenantBaseline
            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter {
                $Object -match 'Setup and Permissions is currently locked'
            }
        }
    }

    Context 'Accordion path - Routes child selections to submenus' {

        BeforeEach {
            Mock -ModuleName TenantBaseline Test-TBArrowKeySupport { return $true }
        }

        It 'Routes connection status direct action' {
            $script:accordionCalls = 0
            Mock -ModuleName TenantBaseline Show-TBMenuArrowAccordion {
                $script:accordionCalls++
                if ($script:accordionCalls -eq 1) { return @{ Section = 0; Item = -1 } }
                return 'Quit'
            }
            Mock -ModuleName TenantBaseline Get-TBConnectionStatus {
                return [PSCustomObject]@{
                    Connected   = $true
                    TenantId    = 'test-tenant'
                    Account     = 'admin@test.com'
                    Scopes      = @()
                    ConnectedAt = $null
                }
            }
            Mock -ModuleName TenantBaseline Read-Host { return '' }

            InModuleScope TenantBaseline {
                Show-TBMainMenu
            }

            Should -Invoke -CommandName Get-TBConnectionStatus -ModuleName TenantBaseline
        }

        It 'Routes setup child selection to Show-TBSetupMenu -DirectAction' {
            $script:accordionCalls = 0
            Mock -ModuleName TenantBaseline Show-TBMenuArrowAccordion {
                $script:accordionCalls++
                if ($script:accordionCalls -eq 1) { return @{ Section = 1; Item = 2 } }
                return 'Quit'
            }
            Mock -ModuleName TenantBaseline Show-TBSetupMenu {}

            InModuleScope TenantBaseline {
                Show-TBMainMenu
            }

            Should -Invoke -CommandName Show-TBSetupMenu -ModuleName TenantBaseline -Times 1 -ParameterFilter { $DirectAction -eq 2 }
        }

        It 'Routes monitor child selection to Show-TBMonitorMenu -DirectAction' {
            $script:accordionCalls = 0
            Mock -ModuleName TenantBaseline Show-TBMenuArrowAccordion {
                $script:accordionCalls++
                if ($script:accordionCalls -eq 1) { return @{ Section = 2; Item = 1 } }
                return 'Quit'
            }
            Mock -ModuleName TenantBaseline Show-TBMonitorMenu {}

            InModuleScope TenantBaseline {
                Show-TBMainMenu
            }

            Should -Invoke -CommandName Show-TBMonitorMenu -ModuleName TenantBaseline -Times 1 -ParameterFilter { $DirectAction -eq 1 }
        }

        It 'Routes snapshot child selection to Show-TBSnapshotMenu -DirectAction' {
            $script:accordionCalls = 0
            Mock -ModuleName TenantBaseline Show-TBMenuArrowAccordion {
                $script:accordionCalls++
                if ($script:accordionCalls -eq 1) { return @{ Section = 4; Item = 3 } }
                return 'Quit'
            }
            Mock -ModuleName TenantBaseline Show-TBSnapshotMenu {}

            InModuleScope TenantBaseline {
                Show-TBMainMenu
            }

            Should -Invoke -CommandName Show-TBSnapshotMenu -ModuleName TenantBaseline -Times 1 -ParameterFilter { $DirectAction -eq 3 }
        }

        It 'Routes drift child selection to Show-TBDriftMenu -DirectAction' {
            $script:accordionCalls = 0
            Mock -ModuleName TenantBaseline Show-TBMenuArrowAccordion {
                $script:accordionCalls++
                if ($script:accordionCalls -eq 1) { return @{ Section = 5; Item = 0 } }
                return 'Quit'
            }
            Mock -ModuleName TenantBaseline Show-TBDriftMenu {}

            InModuleScope TenantBaseline {
                Show-TBMainMenu
            }

            Should -Invoke -CommandName Show-TBDriftMenu -ModuleName TenantBaseline -Times 1 -ParameterFilter { $DirectAction -eq 0 }
        }

        It 'Exits on Quit from accordion' {
            Mock -ModuleName TenantBaseline Show-TBMenuArrowAccordion { return 'Quit' }

            InModuleScope TenantBaseline {
                Show-TBMainMenu
            }

            Should -Invoke -CommandName Show-TBMenuArrowAccordion -ModuleName TenantBaseline -Times 1
            Should -Invoke -CommandName Write-TBMenuHeader -ModuleName TenantBaseline -Times 1 -ParameterFilter { $Mode -eq 'Rich' }
        }

        It 'Renders rich header on each main-menu loop iteration' {
            $script:accordionCalls = 0
            Mock -ModuleName TenantBaseline Show-TBMenuArrowAccordion {
                $script:accordionCalls++
                if ($script:accordionCalls -eq 1) { return @{ Section = 1; Item = 0 } }
                return 'Quit'
            }
            Mock -ModuleName TenantBaseline Show-TBSetupMenu {}

            InModuleScope TenantBaseline {
                Show-TBMainMenu
            }

            Should -Invoke -CommandName Write-TBMenuHeader -ModuleName TenantBaseline -Times 2 -ParameterFilter { $Mode -eq 'Rich' }
            Should -Invoke -CommandName Show-TBSetupMenu -ModuleName TenantBaseline -Times 1 -ParameterFilter { $DirectAction -eq 0 }
        }
    }
}
