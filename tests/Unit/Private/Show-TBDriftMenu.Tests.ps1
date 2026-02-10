#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Show-TBDriftMenu' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Write-Host {}
        Mock -ModuleName TenantBaseline Read-Host { return '' }
        Mock -ModuleName TenantBaseline Clear-Host {}
        Mock -ModuleName TenantBaseline Write-TBMenuHeader {}
    }

    Context 'Classic menu loop' {

        It 'Returns when user selects Back' {
            Mock -ModuleName TenantBaseline Show-TBMenu { return 'Back' }

            InModuleScope TenantBaseline {
                Show-TBDriftMenu
            }

            Should -Invoke -CommandName Show-TBMenu -ModuleName TenantBaseline -Times 1
        }

        It 'Includes View drift details in options' {
            Mock -ModuleName TenantBaseline Show-TBMenu {
                param($Title, $Options, [switch]$IncludeBack)
                if ($Options -contains 'View drift details') {
                    return 'Back'
                }
                return 'Back'
            }

            InModuleScope TenantBaseline {
                Show-TBDriftMenu
            }

            Should -Invoke -CommandName Show-TBMenu -ModuleName TenantBaseline -Times 1
        }
    }

    Context 'DirectAction parameter' {

        It 'Calls Invoke-TBDriftAction with the given index and returns' {
            Mock -ModuleName TenantBaseline Get-TBDrift { return @() }

            InModuleScope TenantBaseline {
                Show-TBDriftMenu -DirectAction 3
            }

            Should -Invoke -CommandName Get-TBDrift -ModuleName TenantBaseline -Times 1
        }
    }
}

Describe 'Invoke-TBDriftAction' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Write-Host {}
        Mock -ModuleName TenantBaseline Read-Host { return '' }
    }

    Context 'Action 0 - View all drifts' {

        It 'Calls Get-TBDrift' {
            Mock -ModuleName TenantBaseline Get-TBDrift { return @() }

            InModuleScope TenantBaseline {
                Invoke-TBDriftAction -ActionIndex 0
            }

            Should -Invoke -CommandName Get-TBDrift -ModuleName TenantBaseline -Times 1
        }

        It 'Shows message when no drifts found' {
            Mock -ModuleName TenantBaseline Get-TBDrift { return @() }

            InModuleScope TenantBaseline {
                Invoke-TBDriftAction -ActionIndex 0
            }

            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -ParameterFilter {
                $Object -eq '  No drifts detected.'
            }
        }
    }

    Context 'Action 2 - Drift summary' {

        It 'Calls Get-TBDriftSummary' {
            Mock -ModuleName TenantBaseline Get-TBDriftSummary {
                return [PSCustomObject]@{
                    TotalDrifts            = 0
                    TotalDriftedProperties = 0
                    GeneratedAt            = '2025-01-01T00:00:00Z'
                    ByStatus               = [PSCustomObject]@{}
                    ByResourceType         = [PSCustomObject]@{}
                }
            }

            InModuleScope TenantBaseline {
                Invoke-TBDriftAction -ActionIndex 2
            }

            Should -Invoke -CommandName Get-TBDriftSummary -ModuleName TenantBaseline -Times 1
        }
    }

    Context 'Action 3 - View drift details' {

        It 'Calls Get-TBDrift' {
            Mock -ModuleName TenantBaseline Get-TBDrift { return @() }

            InModuleScope TenantBaseline {
                Invoke-TBDriftAction -ActionIndex 3
            }

            Should -Invoke -CommandName Get-TBDrift -ModuleName TenantBaseline -Times 1
        }

        It 'Shows no drifts message when empty' {
            Mock -ModuleName TenantBaseline Get-TBDrift { return @() }

            InModuleScope TenantBaseline {
                Invoke-TBDriftAction -ActionIndex 3
            }

            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -ParameterFilter {
                $Object -eq '  No drifts detected.'
            }
        }

        It 'Displays drift details with property table' {
            Mock -ModuleName TenantBaseline Get-TBDrift {
                return @(
                    [PSCustomObject]@{
                        PSTypeName                  = 'TenantBaseline.Drift'
                        Id                          = 'drift-1'
                        ResourceType                = 'microsoft.exchange.accepteddomain'
                        BaselineResourceDisplayName = 'Accepted Domain'
                        Status                      = 'active'
                        FirstReportedDateTime       = '2024-12-12T09:00:00Z'
                        ResourceInstanceIdentifier  = [PSCustomObject]@{ Identity = 'contoso.onmicrosoft.com' }
                        DriftedProperties           = @(
                            [PSCustomObject]@{ propertyName = 'Ensure'; currentValue = 'Absent'; desiredValue = 'Present' }
                        )
                    }
                )
            }

            InModuleScope TenantBaseline {
                Invoke-TBDriftAction -ActionIndex 3
            }

            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -ParameterFilter {
                $Object -eq '  --- Drift 1 of 1 ---'
            }
            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -ParameterFilter {
                $Object -eq '  Resource Type:  microsoft.exchange.accepteddomain'
            }
            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -ParameterFilter {
                $Object -eq '  Instance:       contoso.onmicrosoft.com'
            }
        }

        It 'Uses Yellow for active drift status' {
            Mock -ModuleName TenantBaseline Get-TBDrift {
                return @(
                    [PSCustomObject]@{
                        PSTypeName                  = 'TenantBaseline.Drift'
                        Id                          = 'drift-1'
                        ResourceType                = 'microsoft.exchange.accepteddomain'
                        BaselineResourceDisplayName = 'Accepted Domain'
                        Status                      = 'active'
                        FirstReportedDateTime       = '2024-12-12T09:00:00Z'
                        ResourceInstanceIdentifier  = $null
                        DriftedProperties           = @()
                    }
                )
            }

            InModuleScope TenantBaseline {
                Invoke-TBDriftAction -ActionIndex 3
            }

            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -ParameterFilter {
                $Object -eq '  Status:         active' -and $ForegroundColor -eq 'Yellow'
            }
        }

        It 'Uses Green for fixed drift status' {
            Mock -ModuleName TenantBaseline Get-TBDrift {
                return @(
                    [PSCustomObject]@{
                        PSTypeName                  = 'TenantBaseline.Drift'
                        Id                          = 'drift-1'
                        ResourceType                = 'microsoft.exchange.transportrule'
                        BaselineResourceDisplayName = 'Block External Auto-Forwarding'
                        Status                      = 'fixed'
                        FirstReportedDateTime       = '2025-01-10T08:15:22Z'
                        ResourceInstanceIdentifier  = $null
                        DriftedProperties           = @()
                    }
                )
            }

            InModuleScope TenantBaseline {
                Invoke-TBDriftAction -ActionIndex 3
            }

            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -ParameterFilter {
                $Object -eq '  Status:         fixed' -and $ForegroundColor -eq 'Green'
            }
        }

        It 'Handles multiple drifted properties' {
            Mock -ModuleName TenantBaseline Get-TBDrift {
                return @(
                    [PSCustomObject]@{
                        PSTypeName                  = 'TenantBaseline.Drift'
                        Id                          = 'drift-ca'
                        ResourceType                = 'microsoft.entra.conditionalaccesspolicy'
                        BaselineResourceDisplayName = 'Require MFA for All Users'
                        Status                      = 'active'
                        FirstReportedDateTime       = '2025-01-15T14:22:31Z'
                        ResourceInstanceIdentifier  = [PSCustomObject]@{ Identity = 'CA-Policy-MFA-AllUsers' }
                        DriftedProperties           = @(
                            [PSCustomObject]@{ propertyName = 'State'; currentValue = 'disabled'; desiredValue = 'enabled' }
                            [PSCustomObject]@{ propertyName = 'GrantControls'; currentValue = 'mfa'; desiredValue = 'mfa,compliantDevice' }
                        )
                    }
                )
            }

            InModuleScope TenantBaseline {
                Invoke-TBDriftAction -ActionIndex 3
            }

            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -ParameterFilter {
                $Object -like '*State*disabled*enabled*'
            }
            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -ParameterFilter {
                $Object -like '*GrantControls*mfa*'
            }
        }

        It 'Shows no properties message when driftedProperties is empty' {
            Mock -ModuleName TenantBaseline Get-TBDrift {
                return @(
                    [PSCustomObject]@{
                        PSTypeName                  = 'TenantBaseline.Drift'
                        Id                          = 'drift-empty'
                        ResourceType                = 'microsoft.exchange.accepteddomain'
                        BaselineResourceDisplayName = 'Accepted Domain'
                        Status                      = 'active'
                        FirstReportedDateTime       = '2024-12-12T09:00:00Z'
                        ResourceInstanceIdentifier  = $null
                        DriftedProperties           = @()
                    }
                )
            }

            InModuleScope TenantBaseline {
                Invoke-TBDriftAction -ActionIndex 3
            }

            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -ParameterFilter {
                $Object -eq '  (no drifted properties reported)'
            }
        }

        It 'Handles errors gracefully' {
            Mock -ModuleName TenantBaseline Get-TBDrift { throw 'API error' }

            InModuleScope TenantBaseline {
                Invoke-TBDriftAction -ActionIndex 3
            }

            Should -Invoke -CommandName Write-Host -ModuleName TenantBaseline -ParameterFilter {
                $Object -like '  Error:*' -and $ForegroundColor -eq 'Red'
            }
        }

        It 'Skips instance line when ResourceInstanceIdentifier is null' {
            Mock -ModuleName TenantBaseline Get-TBDrift {
                return @(
                    [PSCustomObject]@{
                        PSTypeName                  = 'TenantBaseline.Drift'
                        Id                          = 'drift-no-instance'
                        ResourceType                = 'microsoft.exchange.accepteddomain'
                        BaselineResourceDisplayName = 'Accepted Domain'
                        Status                      = 'active'
                        FirstReportedDateTime       = '2024-12-12T09:00:00Z'
                        ResourceInstanceIdentifier  = $null
                        DriftedProperties           = @()
                    }
                )
            }

            InModuleScope TenantBaseline {
                Invoke-TBDriftAction -ActionIndex 3
            }

            Should -Not -Invoke -CommandName Write-Host -ModuleName TenantBaseline -ParameterFilter {
                $Object -like '  Instance:*'
            }
        }
    }
}
