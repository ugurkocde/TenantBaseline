#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force

    $fixturesPath = Join-Path $projectRoot 'tests' 'Fixtures' 'MockResponses'
}

Describe 'New-TBSnapshot' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
        # Mock Get-TBSnapshot for the pre-flight quota check
        Mock -ModuleName TenantBaseline Get-TBSnapshot { return @() }
    }

    Context 'Creates a snapshot with required parameters' {

        It 'Sends a POST request with DisplayName and Resources' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'SnapshotSingle.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $result = New-TBSnapshot -DisplayName 'Weekly Baseline Snapshot' `
                -Resources @('microsoft.exchange.accepteddomain', 'microsoft.entra.conditionalaccesspolicy') `
                -Confirm:$false

            $result | Should -Not -BeNullOrEmpty
            $result.Id | Should -Be 'e7a2c4d6-8f10-4b3e-9d5a-1c7f2e8b0a34'
            $result.DisplayName | Should -Be 'Weekly Baseline Snapshot'
            $result.Status | Should -Be 'succeeded'

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -match 'createSnapshot'
            }
        }
    }

    Context 'Creates a snapshot with description' {

        It 'Includes description in the POST body' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'SnapshotSingle.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $result = New-TBSnapshot -DisplayName 'Test Snapshot' `
                -Description 'Test description' `
                -Resources @('microsoft.exchange.accepteddomain') `
                -Confirm:$false

            $result | Should -Not -BeNullOrEmpty
            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 1 -Exactly
        }
    }

    Context 'Supports -WhatIf' {

        It 'Does not invoke the API when -WhatIf is used' {
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return @{} }

            New-TBSnapshot -DisplayName 'WhatIf Test' `
                -Resources @('microsoft.exchange.accepteddomain') `
                -WhatIf

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 0 -Exactly
        }
    }
}
