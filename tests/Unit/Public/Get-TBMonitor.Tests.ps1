#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force

    $fixturesPath = Join-Path $projectRoot 'tests' 'Fixtures' 'MockResponses'
}

Describe 'Get-TBMonitor' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
    }

    Context 'Lists all monitors from API' {

        It 'Returns all monitors when no MonitorId is specified' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'MonitorList.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $result = @(Get-TBMonitor)

            $result.Count | Should -Be 2
            $result[0].Id | Should -Be 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
            $result[0].DisplayName | Should -Be 'MFA Required Monitor'
            $result[1].Id | Should -Be 'b166c9cb-db29-438b-95fb-247da1dc72c3'
            $result[1].DisplayName | Should -Be 'Exchange Accepted Domain Monitor'
        }
    }

    Context 'Gets single monitor by ID' {

        It 'Returns a single monitor when MonitorId is specified' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'MonitorSingle.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $result = Get-TBMonitor -MonitorId 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'

            $result | Should -Not -BeNullOrEmpty
            $result.Id | Should -Be 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
            $result.DisplayName | Should -Be 'MFA Required Monitor'
            $result.Description | Should -Be 'Monitors MFA enforcement across all users'
        }
    }

    Context 'Returns typed monitor objects with correct properties' {

        It 'Returns objects with TenantBaseline.Monitor type name' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'MonitorSingle.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $result = Get-TBMonitor -MonitorId 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'

            $result.PSObject.TypeNames[0] | Should -Be 'TenantBaseline.Monitor'
            $result.PSObject.Properties['Id'] | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties['DisplayName'] | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties['Status'] | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties['Mode'] | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties['MonitorRunFrequencyInHours'] | Should -Not -BeNullOrEmpty
            $result.PSObject.Properties['RawResponse'] | Should -Not -BeNullOrEmpty
        }

        It 'Maps status and mode correctly' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'MonitorSingle.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $result = Get-TBMonitor -MonitorId 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'

            $result.Status | Should -Be 'active'
            $result.Mode | Should -Be 'monitorOnly'
            $result.MonitorRunFrequencyInHours | Should -Be 6
            $result.TenantId | Should -Be '96bf81b4-2694-42bb-9204-70081135ca61'
        }
    }

    Context 'Handles empty response' {

        It 'Returns nothing when API returns empty value array' {
            $emptyData = Get-Content -Path (Join-Path $fixturesPath 'EmptyResponse.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $emptyData }

            $result = @(Get-TBMonitor)

            $result.Count | Should -Be 0
        }
    }
}
