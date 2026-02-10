#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force

    $fixturesPath = Join-Path $projectRoot 'tests' 'Fixtures' 'MockResponses'
}

Describe 'Get-TBSnapshot' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
    }

    Context 'Lists all snapshots' {

        It 'Returns all snapshots from the fixture' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'SnapshotList.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $result = @(Get-TBSnapshot)

            $result.Count | Should -Be 2
            $result[0].Id | Should -Be 'e7a2c4d6-8f10-4b3e-9d5a-1c7f2e8b0a34'
            $result[0].DisplayName | Should -Be 'Weekly Baseline Snapshot'
            $result[0].Status | Should -Be 'succeeded'
            $result[0].Resources | Should -HaveCount 3

            $result[1].Id | Should -Be 'f9b3d5e7-0a21-4c4f-ae6b-2d8f3f9c1b45'
            $result[1].DisplayName | Should -Be 'On-Demand Snapshot'
            $result[1].Status | Should -Be 'running'
            $result[1].Resources | Should -HaveCount 2
        }
    }

    Context 'Gets a single snapshot by ID' {

        It 'Returns a single snapshot when SnapshotId is specified' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'SnapshotSingle.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $result = Get-TBSnapshot -SnapshotId 'e7a2c4d6-8f10-4b3e-9d5a-1c7f2e8b0a34'

            $result | Should -Not -BeNullOrEmpty
            $result.Id | Should -Be 'e7a2c4d6-8f10-4b3e-9d5a-1c7f2e8b0a34'
            $result.DisplayName | Should -Be 'Weekly Baseline Snapshot'
            $result.Description | Should -Be 'Scheduled weekly snapshot of tenant configuration'
            $result.Status | Should -Be 'succeeded'
            $result.TenantId | Should -Be '96bf81b4-2694-42bb-9204-70081135ca61'
            $result.CreatedDateTime | Should -Not -BeNullOrEmpty
            $result.CompletedDateTime | Should -Not -BeNullOrEmpty
            $result.Resources | Should -HaveCount 3
            $result.Resources | Should -Contain 'microsoft.exchange.accepteddomain'
            $result.ResourceLocation | Should -Match 'configurationSnapshots'
        }
    }

    Context 'Returns typed snapshot objects' {

        It 'Returns objects with TenantBaseline.Snapshot type name' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'SnapshotSingle.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $result = Get-TBSnapshot -SnapshotId 'e7a2c4d6-8f10-4b3e-9d5a-1c7f2e8b0a34'

            $result.PSObject.TypeNames[0] | Should -Be 'TenantBaseline.Snapshot'
        }
    }

    Context 'Handles empty response' {

        It 'Returns nothing when API returns empty value array' {
            $emptyData = Get-Content -Path (Join-Path $fixturesPath 'EmptyResponse.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $emptyData }

            $result = @(Get-TBSnapshot)

            $result.Count | Should -Be 0
        }
    }
}
