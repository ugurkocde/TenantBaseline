#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Disconnect-TBTenant' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Write-TBLog {}
        Mock -ModuleName TenantBaseline Disconnect-MgGraph {}
    }

    Context 'Calls Disconnect-MgGraph' {

        It 'Invokes Disconnect-MgGraph' {
            Disconnect-TBTenant

            Should -Invoke -CommandName Disconnect-MgGraph -ModuleName TenantBaseline -Times 1 -Exactly
        }
    }

    Context 'Clears script:TBConnection' {

        It 'Sets the module-scoped connection to null' {
            InModuleScope TenantBaseline {
                $script:TBConnection = [PSCustomObject]@{
                    TenantId = '96bf81b4-2694-42bb-9204-70081135ca61'
                    Account  = 'admin@contoso.onmicrosoft.com'
                }
            }

            Disconnect-TBTenant

            $conn = InModuleScope TenantBaseline { $script:TBConnection }
            $conn | Should -BeNullOrEmpty
        }
    }

    Context 'Handles Disconnect-MgGraph errors gracefully' {

        It 'Does not throw when Disconnect-MgGraph errors' {
            Mock -ModuleName TenantBaseline Disconnect-MgGraph { throw 'Not connected' }

            { Disconnect-TBTenant } | Should -Not -Throw
        }
    }
}
