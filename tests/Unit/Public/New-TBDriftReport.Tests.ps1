#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force

    $fixturesPath = Join-Path $projectRoot 'tests' 'Fixtures' 'MockResponses'
}

Describe 'New-TBDriftReport' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
    }

    Context 'Generates a JSON report' {

        It 'Creates a JSON file with drift data' {
            $driftData = Get-Content -Path (Join-Path $fixturesPath 'DriftList.json') -Raw | ConvertFrom-Json
            $monitorData = Get-Content -Path (Join-Path $fixturesPath 'MonitorList.json') -Raw | ConvertFrom-Json

            $script:graphCallCount = 0
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                $script:graphCallCount++
                if ($Uri -match 'configurationDrifts') {
                    return $driftData
                }
                return $monitorData
            }

            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ('tbreport-{0}.json' -f [guid]::NewGuid().ToString('N'))

            try {
                $result = New-TBDriftReport -OutputPath $tempFile -Confirm:$false

                $result | Should -Not -BeNullOrEmpty
                $result.Format | Should -Be 'JSON'
                $result.DriftCount | Should -Be 3
                Test-Path -Path $tempFile | Should -BeTrue

                $reportContent = Get-Content -Path $tempFile -Raw | ConvertFrom-Json
                $reportContent.TotalDrifts | Should -Be 3
                $reportContent.TotalMonitors | Should -Be 2
            }
            finally {
                if (Test-Path -Path $tempFile) {
                    Remove-Item -Path $tempFile -Force
                }
            }
        }
    }

    Context 'Generates an HTML report' {

        It 'Creates an HTML file with drift data' {
            $driftData = Get-Content -Path (Join-Path $fixturesPath 'DriftList.json') -Raw | ConvertFrom-Json
            $monitorData = Get-Content -Path (Join-Path $fixturesPath 'MonitorList.json') -Raw | ConvertFrom-Json

            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                if ($Uri -match 'configurationDrifts') {
                    return $driftData
                }
                return $monitorData
            }

            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ('tbreport-{0}.html' -f [guid]::NewGuid().ToString('N'))

            try {
                $result = New-TBDriftReport -OutputPath $tempFile -Confirm:$false

                $result | Should -Not -BeNullOrEmpty
                $result.Format | Should -Be 'HTML'
                Test-Path -Path $tempFile | Should -BeTrue

                $htmlContent = Get-Content -Path $tempFile -Raw
                $htmlContent | Should -Match 'TenantBaseline Drift Report'
                $htmlContent | Should -Match 'microsoft.exchange.accepteddomain'
            }
            finally {
                if (Test-Path -Path $tempFile) {
                    Remove-Item -Path $tempFile -Force
                }
            }
        }
    }

    Context 'Supports -WhatIf' {

        It 'Does not create a file when -WhatIf is used' {
            $driftData = Get-Content -Path (Join-Path $fixturesPath 'DriftList.json') -Raw | ConvertFrom-Json
            $monitorData = Get-Content -Path (Join-Path $fixturesPath 'MonitorList.json') -Raw | ConvertFrom-Json

            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                if ($Uri -match 'configurationDrifts') {
                    return $driftData
                }
                return $monitorData
            }

            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ('tbreport-whatif-{0}.json' -f [guid]::NewGuid().ToString('N'))

            New-TBDriftReport -OutputPath $tempFile -WhatIf

            Test-Path -Path $tempFile | Should -BeFalse
        }
    }
}
