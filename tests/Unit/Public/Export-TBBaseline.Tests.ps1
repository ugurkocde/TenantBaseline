#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force

    $fixturesPath = Join-Path $projectRoot 'tests' 'Fixtures' 'MockResponses'
}

Describe 'Export-TBBaseline' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
    }

    Context 'Exports a baseline to a JSON file' {

        It 'Creates a JSON file with baseline data' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'BaselineResponse.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ('tbexport-baseline-{0}.json' -f [guid]::NewGuid().ToString('N'))

            try {
                $result = Export-TBBaseline -MonitorId 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02' -OutputPath $tempFile

                $result | Should -Not -BeNullOrEmpty
                $result.MonitorId | Should -Be 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
                Test-Path -Path $tempFile | Should -BeTrue

                $exported = Get-Content -Path $tempFile -Raw | ConvertFrom-Json
                $exported.MonitorId | Should -Be 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
                $exported.ExportedAt | Should -Not -BeNullOrEmpty
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
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'BaselineResponse.json') -Raw | ConvertFrom-Json
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest { return $fixtureData }

            $result = Export-TBBaseline -MonitorId 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'

            try {
                $result | Should -Not -BeNullOrEmpty
                $result.OutputPath | Should -Match 'TBBaseline-bf77ee1e'
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
