#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force

    $fixturesPath = Join-Path $projectRoot 'tests' 'Fixtures' 'MockResponses'
}

Describe 'Wait-TBSnapshot' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
    }

    Context 'Returns completed snapshot' {

        It 'Returns a snapshot object when the job reaches a terminal state' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'SnapshotSingle.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $result = Wait-TBSnapshot -SnapshotId 'e7a2c4d6-8f10-4b3e-9d5a-1c7f2e8b0a34'

            $result | Should -Not -BeNullOrEmpty
            $result.Id | Should -Be 'e7a2c4d6-8f10-4b3e-9d5a-1c7f2e8b0a34'
            $result.Status | Should -Be 'succeeded'
            $result.DisplayName | Should -Be 'Weekly Baseline Snapshot'
        }
    }

    Context 'Accepts pipeline input' {

        It 'Accepts SnapshotId from pipeline by property name' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'SnapshotSingle.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $snapshot = [PSCustomObject]@{ Id = 'e7a2c4d6-8f10-4b3e-9d5a-1c7f2e8b0a34' }
            $result = $snapshot | Wait-TBSnapshot

            $result | Should -Not -BeNullOrEmpty
            $result.Id | Should -Be 'e7a2c4d6-8f10-4b3e-9d5a-1c7f2e8b0a34'
        }
    }
}
