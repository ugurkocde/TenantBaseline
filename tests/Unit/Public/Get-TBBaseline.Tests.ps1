#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force

    $fixturesPath = Join-Path $projectRoot 'tests' 'Fixtures' 'MockResponses'
}

Describe 'Get-TBBaseline' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
    }

    Context 'Gets baseline for a monitor' {

        It 'Returns a baseline object with all expected properties' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'BaselineResponse.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $result = Get-TBBaseline -MonitorId 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'

            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.TypeNames[0] | Should -Be 'TenantBaseline.Baseline'
            $result.Id | Should -Be 'd2e3f4a5-6789-0bcd-ef12-345678901abc'
            $result.MonitorId | Should -Be 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
            $result.DisplayName | Should -Be 'Contoso Tenant Baseline'
            $result.Description | Should -Be 'Standard security baseline for Contoso tenant'
            $result.Parameters | Should -HaveCount 0
            $result.Resources | Should -HaveCount 2
            $result.Resources[0].resourceType | Should -Be 'microsoft.entra.conditionalaccesspolicy'
            $result.Resources[1].resourceType | Should -Be 'microsoft.exchange.accepteddomain'
            $result.RawResponse | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Calls the correct API endpoint' {

        It 'Requests the baseline endpoint for the specified monitor' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'BaselineResponse.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $null = Get-TBBaseline -MonitorId 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 1 -Exactly -ParameterFilter {
                $Uri -match 'configurationMonitors/bf77ee1e-7750-40cb-8bcd-524dc4cdab02/baseline'
            }
        }
    }

    Context 'Handles missing optional properties' {

        It 'Returns null or empty for missing properties' {
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                return [PSCustomObject]@{ id = 'baseline-minimal' }
            }

            $result = Get-TBBaseline -MonitorId 'some-monitor-id'

            $result.Id | Should -Be 'baseline-minimal'
            $result.MonitorId | Should -Be 'some-monitor-id'
            $result.DisplayName | Should -BeNullOrEmpty
            $result.Description | Should -BeNullOrEmpty
            $result.Parameters | Should -HaveCount 0
            $result.Resources | Should -HaveCount 0
        }
    }

    Context 'Accepts pipeline input' {

        It 'Accepts MonitorId from pipeline by property name' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'BaselineResponse.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $monitor = [PSCustomObject]@{ Id = 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02' }
            $result = $monitor | Get-TBBaseline

            $result | Should -Not -BeNullOrEmpty
            $result.MonitorId | Should -Be 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
        }
    }
}
