#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Remove-TBMonitor' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
        Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {}
    }

    Context 'Deletes a monitor by ID' {

        It 'Sends a DELETE request for the specified monitor' {
            Remove-TBMonitor -MonitorId 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02' -Confirm:$false

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'DELETE' -and $Uri -match 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
            }
        }
    }

    Context 'Supports -WhatIf' {

        It 'Does not invoke the API when -WhatIf is used' {
            Remove-TBMonitor -MonitorId 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02' -WhatIf

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 0 -Exactly
        }
    }

    Context 'Accepts pipeline input via Id alias' {

        It 'Accepts MonitorId from pipeline by property name' {
            $monitor = [PSCustomObject]@{ Id = 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02' }
            $monitor | Remove-TBMonitor -Confirm:$false

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'DELETE'
            }
        }
    }
}
