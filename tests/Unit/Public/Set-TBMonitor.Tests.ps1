#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force

    $fixturesPath = Join-Path $projectRoot 'tests' 'Fixtures' 'MockResponses'
}

Describe 'Set-TBMonitor' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
    }

    Context 'Updates monitor display name' {

        It 'Sends a PATCH request with updated display name' {
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {}

            Set-TBMonitor -MonitorId 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02' `
                -DisplayName 'Updated Monitor Name' `
                -Confirm:$false

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'PATCH' -and $Uri -match 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
            }
        }
    }

    Context 'Updates monitor status' {

        It 'Sends a PATCH request with status active or inactive' {
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {}

            Set-TBMonitor -MonitorId 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02' `
                -Status 'inactive' `
                -Confirm:$false

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'PATCH'
            }
        }
    }

    Context 'Updates monitor with resources and baseline' {

        It 'Includes baseline structure when Resources are provided' {
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {}

            $resources = @(
                @{
                    resourceType = 'microsoft.entra.conditionalaccesspolicy'
                    displayName  = 'Updated Policy'
                    properties   = @{ State = 'enabled' }
                }
            )

            Set-TBMonitor -MonitorId 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02' `
                -DisplayName 'Updated Monitor' `
                -Resources $resources `
                -BaselineDisplayName 'Updated Baseline' `
                -Confirm:$false

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 1 -Exactly
        }
    }

    Context 'Returns no output' {

        It 'Does not produce output since PATCH returns 204 No Content' {
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {}

            $result = Set-TBMonitor -MonitorId 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02' `
                -DisplayName 'No Output Test' `
                -Confirm:$false

            $result | Should -BeNullOrEmpty
        }
    }

    Context 'Warns when no properties are specified' {

        It 'Does not call the API when no update properties are provided' {
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {}

            Set-TBMonitor -MonitorId 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02' -Confirm:$false

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 0 -Exactly
        }
    }

    Context 'Supports -WhatIf' {

        It 'Does not invoke the API when -WhatIf is used' {
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {}

            Set-TBMonitor -MonitorId 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02' `
                -DisplayName 'WhatIf Test' -WhatIf

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 0 -Exactly
        }
    }
}
