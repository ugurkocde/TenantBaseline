#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Remove-TBSnapshot' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
        Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {}
    }

    Context 'Deletes a snapshot by ID' {

        It 'Sends a DELETE request for the specified snapshot' {
            Remove-TBSnapshot -SnapshotId 'e7a2c4d6-8f10-4b3e-9d5a-1c7f2e8b0a34' -Confirm:$false

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'DELETE' -and $Uri -match 'e7a2c4d6-8f10-4b3e-9d5a-1c7f2e8b0a34'
            }
        }
    }

    Context 'Supports -WhatIf' {

        It 'Does not invoke the API when -WhatIf is used' {
            Remove-TBSnapshot -SnapshotId 'e7a2c4d6-8f10-4b3e-9d5a-1c7f2e8b0a34' -WhatIf

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 0 -Exactly
        }
    }

    Context 'Accepts pipeline input via Id alias' {

        It 'Accepts SnapshotId from pipeline by property name' {
            $snapshot = [PSCustomObject]@{ Id = 'e7a2c4d6-8f10-4b3e-9d5a-1c7f2e8b0a34' }
            $snapshot | Remove-TBSnapshot -Confirm:$false

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'DELETE'
            }
        }
    }
}
