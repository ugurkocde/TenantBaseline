#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force

    $fixturesPath = Join-Path $projectRoot 'tests' 'Fixtures' 'MockResponses'
}

Describe 'New-TBDocumentation' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Test-TBGraphConnection { return $true }
        Mock -ModuleName TenantBaseline Write-TBLog {}
    }

    Context 'Generates HTML documentation' {

        It 'Creates an HTML file with monitor and baseline data' {
            $monitorData = Get-Content -Path (Join-Path $fixturesPath 'MonitorList.json') -Raw | ConvertFrom-Json
            $baselineData = Get-Content -Path (Join-Path $fixturesPath 'BaselineResponse.json') -Raw | ConvertFrom-Json
            $snapshotData = Get-Content -Path (Join-Path $fixturesPath 'SnapshotList.json') -Raw | ConvertFrom-Json

            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                if ($Uri -match 'configurationMonitors/.+/baseline') {
                    return $baselineData
                }
                if ($Uri -match 'configurationMonitors') {
                    return $monitorData
                }
                if ($Uri -match 'configurationSnapshotJobs') {
                    return $snapshotData
                }
                return $null
            }

            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ('tbdoc-{0}.html' -f [guid]::NewGuid().ToString('N'))

            try {
                $result = New-TBDocumentation -OutputPath $tempFile -Confirm:$false

                $result | Should -Not -BeNullOrEmpty
                $result.Format | Should -Be 'HTML'
                $result.MonitorCount | Should -Be 2
                Test-Path -Path $tempFile | Should -BeTrue

                $htmlContent = Get-Content -Path $tempFile -Raw
                $htmlContent | Should -Match 'Tenant Configuration Monitoring Documentation'
                $htmlContent | Should -Match 'Monitor Inventory'
                $htmlContent | Should -Match 'Baseline Details'
                $htmlContent | Should -Match 'Snapshot Inventory'
            }
            finally {
                if (Test-Path -Path $tempFile) {
                    Remove-Item -Path $tempFile -Force
                }
            }
        }

        It 'Includes drift history when -IncludeDriftHistory is specified' {
            $monitorData = Get-Content -Path (Join-Path $fixturesPath 'MonitorList.json') -Raw | ConvertFrom-Json
            $baselineData = Get-Content -Path (Join-Path $fixturesPath 'BaselineResponse.json') -Raw | ConvertFrom-Json
            $snapshotData = Get-Content -Path (Join-Path $fixturesPath 'SnapshotList.json') -Raw | ConvertFrom-Json
            $driftData = Get-Content -Path (Join-Path $fixturesPath 'DriftList.json') -Raw | ConvertFrom-Json

            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                if ($Uri -match 'configurationDrifts') {
                    return $driftData
                }
                if ($Uri -match 'configurationMonitors/.+/baseline') {
                    return $baselineData
                }
                if ($Uri -match 'configurationMonitors') {
                    return $monitorData
                }
                if ($Uri -match 'configurationSnapshotJobs') {
                    return $snapshotData
                }
                return $null
            }

            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ('tbdoc-drift-{0}.html' -f [guid]::NewGuid().ToString('N'))

            try {
                $result = New-TBDocumentation -OutputPath $tempFile -IncludeDriftHistory -Confirm:$false

                $result | Should -Not -BeNullOrEmpty
                Test-Path -Path $tempFile | Should -BeTrue

                $htmlContent = Get-Content -Path $tempFile -Raw
                $htmlContent | Should -Match 'Drift History'
            }
            finally {
                if (Test-Path -Path $tempFile) {
                    Remove-Item -Path $tempFile -Force
                }
            }
        }
    }

    Context 'Generates Markdown documentation' {

        It 'Creates a Markdown file with documentation sections' {
            $monitorData = Get-Content -Path (Join-Path $fixturesPath 'MonitorList.json') -Raw | ConvertFrom-Json
            $baselineData = Get-Content -Path (Join-Path $fixturesPath 'BaselineResponse.json') -Raw | ConvertFrom-Json
            $snapshotData = Get-Content -Path (Join-Path $fixturesPath 'SnapshotList.json') -Raw | ConvertFrom-Json

            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                if ($Uri -match 'configurationMonitors/.+/baseline') {
                    return $baselineData
                }
                if ($Uri -match 'configurationMonitors') {
                    return $monitorData
                }
                if ($Uri -match 'configurationSnapshotJobs') {
                    return $snapshotData
                }
                return $null
            }

            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ('tbdoc-{0}.md' -f [guid]::NewGuid().ToString('N'))

            try {
                $result = New-TBDocumentation -OutputPath $tempFile -Confirm:$false

                $result | Should -Not -BeNullOrEmpty
                $result.Format | Should -Be 'Markdown'
                $result.MonitorCount | Should -Be 2
                Test-Path -Path $tempFile | Should -BeTrue

                $mdContent = Get-Content -Path $tempFile -Raw
                $mdContent | Should -Match '# Tenant Configuration Monitoring Documentation'
                $mdContent | Should -Match '## Monitor Inventory'
                $mdContent | Should -Match '## Baseline Details'
                $mdContent | Should -Match '## Snapshot Inventory'
            }
            finally {
                if (Test-Path -Path $tempFile) {
                    Remove-Item -Path $tempFile -Force
                }
            }
        }

        It 'Detects Markdown format from .md extension' {
            $monitorData = Get-Content -Path (Join-Path $fixturesPath 'MonitorList.json') -Raw | ConvertFrom-Json
            $baselineData = Get-Content -Path (Join-Path $fixturesPath 'BaselineResponse.json') -Raw | ConvertFrom-Json
            $snapshotData = Get-Content -Path (Join-Path $fixturesPath 'SnapshotList.json') -Raw | ConvertFrom-Json

            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                if ($Uri -match 'configurationMonitors/.+/baseline') {
                    return $baselineData
                }
                if ($Uri -match 'configurationMonitors') {
                    return $monitorData
                }
                if ($Uri -match 'configurationSnapshotJobs') {
                    return $snapshotData
                }
                return $null
            }

            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ('tbdoc-ext-{0}.md' -f [guid]::NewGuid().ToString('N'))

            try {
                $result = New-TBDocumentation -OutputPath $tempFile -Format HTML -Confirm:$false

                $result.Format | Should -Be 'Markdown'
            }
            finally {
                if (Test-Path -Path $tempFile) {
                    Remove-Item -Path $tempFile -Force
                }
            }
        }
    }

    Context 'Handles empty data' {

        It 'Generates documentation with no monitors' {
            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                return [PSCustomObject]@{ value = @() }
            }

            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ('tbdoc-empty-{0}.html' -f [guid]::NewGuid().ToString('N'))

            try {
                $result = New-TBDocumentation -OutputPath $tempFile -Confirm:$false

                $result | Should -Not -BeNullOrEmpty
                $result.MonitorCount | Should -Be 0
                Test-Path -Path $tempFile | Should -BeTrue
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
            $monitorData = Get-Content -Path (Join-Path $fixturesPath 'MonitorList.json') -Raw | ConvertFrom-Json
            $baselineData = Get-Content -Path (Join-Path $fixturesPath 'BaselineResponse.json') -Raw | ConvertFrom-Json
            $snapshotData = Get-Content -Path (Join-Path $fixturesPath 'SnapshotList.json') -Raw | ConvertFrom-Json

            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                if ($Uri -match 'configurationMonitors/.+/baseline') {
                    return $baselineData
                }
                if ($Uri -match 'configurationMonitors') {
                    return $monitorData
                }
                if ($Uri -match 'configurationSnapshotJobs') {
                    return $snapshotData
                }
                return $null
            }

            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ('tbdoc-whatif-{0}.html' -f [guid]::NewGuid().ToString('N'))

            New-TBDocumentation -OutputPath $tempFile -WhatIf

            Test-Path -Path $tempFile | Should -BeFalse
        }
    }

    Context 'Default output path' {

        It 'Generates a default filename when no OutputPath is given' {
            $monitorData = Get-Content -Path (Join-Path $fixturesPath 'MonitorList.json') -Raw | ConvertFrom-Json
            $baselineData = Get-Content -Path (Join-Path $fixturesPath 'BaselineResponse.json') -Raw | ConvertFrom-Json
            $snapshotData = Get-Content -Path (Join-Path $fixturesPath 'SnapshotList.json') -Raw | ConvertFrom-Json

            Mock -ModuleName TenantBaseline Invoke-TBGraphRequest {
                if ($Uri -match 'configurationMonitors/.+/baseline') {
                    return $baselineData
                }
                if ($Uri -match 'configurationMonitors') {
                    return $monitorData
                }
                if ($Uri -match 'configurationSnapshotJobs') {
                    return $snapshotData
                }
                return $null
            }

            try {
                $result = New-TBDocumentation -Confirm:$false

                $result | Should -Not -BeNullOrEmpty
                $result.OutputPath | Should -Match 'TBDocumentation-'
                $result.OutputPath | Should -Match '\.html$'
            }
            finally {
                if ($result -and $result.OutputPath -and (Test-Path -Path $result.OutputPath)) {
                    Remove-Item -Path $result.OutputPath -Force
                }
            }
        }
    }
}
