#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Write-TBMenuHeader' {

    Context 'Metadata model' {
        It 'Resolves version and author from module metadata' {
            $model = InModuleScope TenantBaseline {
                Get-TBHeaderModel
            }

            $model | Should -Not -BeNullOrEmpty
            $model.VersionText | Should -Match '^Version: v'
            $model.AuthorText | Should -Be 'Author: Ugur'
            $model.WebsiteText | Should -Be 'Website: tenantbaseline.com'
            $model.LinkedInText | Should -Be 'LinkedIn: linkedin.com/in/ugurkocde'
            $model.RepositoryText | Should -Be 'Repository: github.com/ugurkocde/tenantbaseline'
            $model.UTCMText | Should -Match '^UTCM:'
            $model.LinksLine | Should -Be 'TenantBaseline.com |  GitHub.com/ugurkocde/tenantbaseline'
            $model.UTCMShort | Should -Be 'UTCM: Unified Tenant Configuration Management (Microsoft Graph)'
            $model.CapabilitiesLine | Should -Be 'Monitoring, Drift Detection, Snapshots, Baselines, Reports'
        }
    }

    Context 'Hero art' {
        It 'Does not include small enant/aseline text under T/B in classic mode' {
            $hero = InModuleScope TenantBaseline {
                Get-TBHeroLines -HeaderModel (Get-TBHeaderModel)
            }

            ($hero.ArtLines -join "`n") | Should -Not -Match 'enant'
            ($hero.ArtLines -join "`n") | Should -Not -Match 'aseline'
        }

        It 'Does not include small enant/aseline text under T/B in premium mode' {
            $hero = InModuleScope TenantBaseline {
                Get-TBHeroLines -HeaderModel (Get-TBHeaderModel) -Premium
            }

            ($hero.ArtLines -join "`n") | Should -Not -Match 'enant'
            ($hero.ArtLines -join "`n") | Should -Not -Match 'aseline'
        }
    }

    Context 'Compact mode' {
        It 'Runs without throwing and omits rich details by default' {
            Mock -ModuleName TenantBaseline Write-Host {}
            Mock -ModuleName TenantBaseline Test-TBArrowKeySupport { return $false }
            Mock -ModuleName TenantBaseline Get-TBConsoleInnerWidth { return 80 }
            Mock -ModuleName TenantBaseline Get-TBConnectionStatus { return [PSCustomObject]@{ Connected = $false; TenantId = $null } }

            {
                InModuleScope TenantBaseline {
                    Write-TBMenuHeader
                }
            } | Should -Not -Throw

            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter { $Object -match 'tenantbaseline\.com' }
            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter { $Object -match 'github\.com/ugurkocde/tenantbaseline' }
            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 0 -ParameterFilter { $Object -match 'UTCM:' }
        }
    }

    Context 'Rich mode - classic renderer' {
        It 'Renders version, author, link, use-cases, and features' {
            Mock -ModuleName TenantBaseline Write-Host {}
            Mock -ModuleName TenantBaseline Test-TBArrowKeySupport { return $false }
            Mock -ModuleName TenantBaseline Get-TBConsoleInnerWidth { return 80 }
            Mock -ModuleName TenantBaseline Get-TBConnectionStatus { return [PSCustomObject]@{ Connected = $false; TenantId = $null } }

            InModuleScope TenantBaseline {
                Write-TBMenuHeader -Mode Rich
            }

            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter { $Object -match 'Version: v' }
            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter { $Object -match 'Author: Ugur' }
            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter { $Object -match 'tenantbaseline\.com' }
            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter { $Object -match 'github\.com/ugurkocde/tenantbaseline' }
            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter { $Object -match 'UTCM:' }
            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter { $Object -match 'Monitoring' }
            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter { $Object -match 'Baselines' }
            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter { $Object -match 'Action: Select Sign in to continue' }
        }

        It 'Shows connected status and friendly tenant label' {
            Mock -ModuleName TenantBaseline Write-Host {}
            Mock -ModuleName TenantBaseline Test-TBArrowKeySupport { return $false }
            Mock -ModuleName TenantBaseline Get-TBConsoleInnerWidth { return 80 }
            Mock -ModuleName TenantBaseline Get-TBConnectionStatus {
                return [PSCustomObject]@{
                    Connected                = $true
                    TenantId                 = '96bf81b4-2694-42bb-9204-70081135ca61'
                    Account                  = 'admin@contoso.onmicrosoft.com'
                    IdentityLabel            = 'contoso.onmicrosoft.com'
                    DirectoryMetadataEnabled = $false
                }
            }

            InModuleScope TenantBaseline {
                Write-TBMenuHeader -Mode Rich
            }

            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter { $Object -match 'Status: Connected' }
            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter { $Object -match 'Organization: contoso\.onmicrosoft\.com' }
        }
    }

    Context 'Rich mode - premium renderer' {
        It 'Runs without throwing and includes rich detail lines' {
            Mock -ModuleName TenantBaseline Write-Host {}
            Mock -ModuleName TenantBaseline Test-TBArrowKeySupport { return $true }
            Mock -ModuleName TenantBaseline Get-TBConsoleInnerWidth { return 80 }
            Mock -ModuleName TenantBaseline Get-TBColorPalette {
                return @{
                    Text = ''; Subtext = ''; Dim = ''; Blue = ''; Green = ''; Red = ''
                    Yellow = ''; Mauve = ''; Teal = ''; Peach = ''; Surface = ''
                    BgSelect = ''; Bold = ''; Italic = ''; DimStyle = ''; Reset = ''
                }
            }
            Mock -ModuleName TenantBaseline Get-TBGradientLine { return ('-' * $Length) }
            Mock -ModuleName TenantBaseline Get-TBGradientString { return $Text }
            Mock -ModuleName TenantBaseline Get-TBConnectionStatus { return [PSCustomObject]@{ Connected = $false; TenantId = $null } }

            {
                InModuleScope TenantBaseline {
                    Write-TBMenuHeader -Mode Rich
                }
            } | Should -Not -Throw

            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter { $Object -match 'Version: v' }
            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter { $Object -match 'Author: Ugur' }
            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter { $Object -match 'tenantbaseline\.com' }
            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter { $Object -match 'github\.com/ugurkocde/tenantbaseline' }
            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter { $Object -match 'UTCM:' }
            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter { $Object -match 'Monitoring' }
            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter { $Object -match 'Baselines' }
            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter { $Object -match 'Action: Select Sign in to continue' }
        }

        It 'Uses friendly identity label in premium status line' {
            Mock -ModuleName TenantBaseline Write-Host {}
            Mock -ModuleName TenantBaseline Test-TBArrowKeySupport { return $true }
            Mock -ModuleName TenantBaseline Get-TBConsoleInnerWidth { return 80 }
            Mock -ModuleName TenantBaseline Get-TBColorPalette {
                return @{
                    Text = ''; Subtext = ''; Dim = ''; Blue = ''; Green = ''; Red = ''
                    Yellow = ''; Mauve = ''; Teal = ''; Peach = ''; Surface = ''
                    BgSelect = ''; Bold = ''; Italic = ''; DimStyle = ''; Reset = ''
                }
            }
            Mock -ModuleName TenantBaseline Get-TBGradientLine { return ('-' * $Length) }
            Mock -ModuleName TenantBaseline Get-TBGradientString { return $Text }
            Mock -ModuleName TenantBaseline Get-TBConnectionStatus {
                return [PSCustomObject]@{
                    Connected                = $true
                    TenantId                 = '96bf81b4-2694-42bb-9204-70081135ca61'
                    Account                  = 'admin@contoso.onmicrosoft.com'
                    IdentityLabel            = 'contoso.onmicrosoft.com'
                    DirectoryMetadataEnabled = $false
                }
            }

            InModuleScope TenantBaseline {
                Write-TBMenuHeader -Mode Rich
            }

            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter { $Object -match 'Status: Connected' }
            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -Times 1 -ParameterFilter { $Object -match 'Organization: contoso\.onmicrosoft\.com' }
        }
    }
}
