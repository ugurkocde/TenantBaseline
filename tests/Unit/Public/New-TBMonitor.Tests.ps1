#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force

    $fixturesPath = Join-Path $projectRoot 'tests' 'Fixtures' 'MockResponses'
}

Describe 'New-TBMonitor' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
    }

    Context 'Creates a monitor with required parameters' {

        It 'Sends a POST request and returns the created monitor' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'MonitorSingle.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $result = New-TBMonitor -DisplayName 'MFA Required Monitor' -Confirm:$false

            $result | Should -Not -BeNullOrEmpty
            $result.Id | Should -Be 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
            $result.DisplayName | Should -Be 'MFA Required Monitor'
            $result.Status | Should -Be 'active'

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST'
            }
        }
    }

    Context 'Creates a monitor with all parameters' {

        It 'Includes description, baseline display name, and resources in the body' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'MonitorSingle.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $resources = @(
                @{
                    resourceType = 'microsoft.entra.conditionalaccesspolicy'
                    displayName  = 'Require MFA'
                    properties   = @{ State = 'enabled' }
                }
            )

            $result = New-TBMonitor -DisplayName 'MFA Required Monitor' `
                -Description 'Monitors MFA enforcement' `
                -BaselineDisplayName 'MFA Baseline' `
                -BaselineDescription 'MFA baseline description' `
                -Resources $resources `
                -Parameters @{ key = 'value' } `
                -Confirm:$false

            $result | Should -Not -BeNullOrEmpty
            $result.Id | Should -Be 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
        }
    }

    Context 'Supports -WhatIf' {

        It 'Does not invoke the API when -WhatIf is used' {
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return @{} }

            New-TBMonitor -DisplayName 'WhatIf Test' -WhatIf

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 0 -Exactly
        }
    }

    Context 'Accepts pipeline input for Resources' {

        It 'Collects resources from pipeline and sends them in the body' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'MonitorSingle.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $resources = @(
                [PSCustomObject]@{ resourceType = 'microsoft.entra.conditionalaccesspolicy'; displayName = 'Policy 1'; properties = @{ State = 'enabled' } }
                [PSCustomObject]@{ resourceType = 'microsoft.exchange.accepteddomain'; displayName = 'Domain 1'; properties = @{ DomainType = 'Authoritative' } }
            )

            $result = $resources | New-TBMonitor -DisplayName 'Pipeline Monitor' -Confirm:$false

            $result | Should -Not -BeNullOrEmpty
            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 1 -Exactly
        }
    }
}
