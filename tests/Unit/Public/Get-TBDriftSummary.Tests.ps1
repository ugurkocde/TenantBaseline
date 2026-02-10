#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force

    $fixturesPath = Join-Path $projectRoot 'tests' 'Fixtures' 'MockResponses'
}

Describe 'Get-TBDriftSummary' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
    }

    Context 'Summarizes drifts from fixture data' {

        It 'Returns correct totals and groupings' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'DriftList.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $result = Get-TBDriftSummary

            $result | Should -Not -BeNullOrEmpty
            $result.PSObject.TypeNames[0] | Should -Be 'TenantBaseline.DriftSummary'
            $result.TotalDrifts | Should -Be 3
            $result.TotalDriftedProperties | Should -Be 4
            $result.GeneratedAt | Should -Not -BeNullOrEmpty
        }

        It 'Groups by ResourceType correctly' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'DriftList.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $result = Get-TBDriftSummary

            $result.ByResourceType.'microsoft.exchange.accepteddomain' | Should -Be 1
            $result.ByResourceType.'microsoft.entra.conditionalaccesspolicy' | Should -Be 1
            $result.ByResourceType.'microsoft.exchange.transportrule' | Should -Be 1
        }

        It 'Groups by Monitor correctly' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'DriftList.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $result = Get-TBDriftSummary

            $result.ByMonitor.'b166c9cb-db29-438b-95fb-247da1dc72c3' | Should -Be 2
            $result.ByMonitor.'bf77ee1e-7750-40cb-8bcd-524dc4cdab02' | Should -Be 1
        }

        It 'Groups by Status correctly' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'DriftList.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $result = Get-TBDriftSummary

            $result.ByStatus.'active' | Should -Be 2
            $result.ByStatus.'fixed' | Should -Be 1
        }
    }

    Context 'Handles no drifts' {

        It 'Returns zero totals when no drifts exist' {
            $emptyData = Get-Content -Path (Join-Path $fixturesPath 'EmptyResponse.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $emptyData }

            $result = Get-TBDriftSummary

            $result.TotalDrifts | Should -Be 0
            $result.TotalDriftedProperties | Should -Be 0
        }
    }

    Context 'Filters by MonitorId' {

        It 'Passes MonitorId to Get-TBDrift' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'DriftList.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $null = Get-TBDriftSummary -MonitorId 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'

            Should -Invoke -CommandName Invoke-TBGraphRequest -ModuleName TenantBaseline -Times 1 -Exactly
        }
    }
}
