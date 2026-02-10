#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Write-TBLog' {

    Context 'Verbose messages' {

        It 'Writes a verbose message with default level' {
            $output = InModuleScope TenantBaseline {
                Write-TBLog -Message 'Test verbose message' -Verbose 4>&1
            }

            $output | Should -Not -BeNullOrEmpty
            $verboseText = $output | Out-String
            $verboseText | Should -Match 'Test verbose message'
        }
    }

    Context 'Warning messages' {

        It 'Writes a warning message when Level is Warning' {
            $output = InModuleScope TenantBaseline {
                Write-TBLog -Message 'Test warning' -Level 'Warning' 3>&1
            }

            $output | Should -Not -BeNullOrEmpty
            $warningText = $output | Out-String
            $warningText | Should -Match 'Test warning'
        }
    }

    Context 'Formatted message includes timestamp and level' {

        It 'Includes a timestamp in the output' {
            $output = InModuleScope TenantBaseline {
                Write-TBLog -Message 'Timestamp check' -Verbose 4>&1
            }

            $text = $output | Out-String
            $text | Should -Match '\[\d{4}-\d{2}-\d{2}'
        }

        It 'Includes the level label in the output' {
            $output = InModuleScope TenantBaseline {
                Write-TBLog -Message 'Level check' -Level 'Warning' 3>&1
            }

            $text = $output | Out-String
            $text | Should -Match 'Warning'
        }
    }

    Context 'File logging' {

        It 'Writes to file when TBLogPath environment variable is set' {
            $tempFile = Join-Path ([System.IO.Path]::GetTempPath()) ('tblog-test-{0}.log' -f [guid]::NewGuid().ToString('N'))

            try {
                $env:TBLogPath = $tempFile

                InModuleScope TenantBaseline {
                    Write-TBLog -Message 'File log test'
                }

                Test-Path -Path $tempFile | Should -BeTrue
                $content = Get-Content -Path $tempFile -Raw
                $content | Should -Match 'File log test'
            }
            finally {
                $env:TBLogPath = $null
                if (Test-Path -Path $tempFile) {
                    Remove-Item -Path $tempFile -Force
                }
            }
        }

        It 'Does not write to file when TBLogPath is not set' {
            $env:TBLogPath = $null

            {
                InModuleScope TenantBaseline {
                    Write-TBLog -Message 'No file test'
                }
            } | Should -Not -Throw
        }
    }
}
