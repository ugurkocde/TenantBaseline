#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force

    $fixturesPath = Join-Path $projectRoot 'tests' 'Fixtures' 'MockResponses'
}

Describe 'Export-TBSnapshot' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
    }

    Context 'Exports a snapshot to a JSON file' {

        It 'Creates a JSON file with snapshot data' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'SnapshotSingle.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ('tbexport-snap-{0}.json' -f [guid]::NewGuid().ToString('N'))

            try {
                $result = Export-TBSnapshot -SnapshotId 'e7a2c4d6-8f10-4b3e-9d5a-1c7f2e8b0a34' -OutputPath $tempFile

                $result | Should -Not -BeNullOrEmpty
                $result.SnapshotId | Should -Be 'e7a2c4d6-8f10-4b3e-9d5a-1c7f2e8b0a34'
                Test-Path -Path $tempFile | Should -BeTrue

                $exported = Get-Content -Path $tempFile -Raw | ConvertFrom-Json
                $exported.SnapshotId | Should -Be 'e7a2c4d6-8f10-4b3e-9d5a-1c7f2e8b0a34'
                $exported.DisplayName | Should -Be 'Weekly Baseline Snapshot'
                $exported.Status | Should -Be 'succeeded'
                $exported.Resources | Should -HaveCount 3
            }
            finally {
                if (Test-Path -Path $tempFile) {
                    Remove-Item -Path $tempFile -Force
                }
            }
        }
    }

    Context 'Generates default file name when OutputPath is not specified' {

        It 'Creates a file with auto-generated name' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'SnapshotSingle.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $result = Export-TBSnapshot -SnapshotId 'e7a2c4d6-8f10-4b3e-9d5a-1c7f2e8b0a34'

            try {
                $result | Should -Not -BeNullOrEmpty
                $result.OutputPath | Should -Match 'TBSnapshot-e7a2c4d6'
                Test-Path -Path $result.OutputPath | Should -BeTrue
            }
            finally {
                if ($result.OutputPath -and (Test-Path -Path $result.OutputPath)) {
                    Remove-Item -Path $result.OutputPath -Force
                }
            }
        }
    }
}
