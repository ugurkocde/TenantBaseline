#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force
}

Describe 'Send-TBDriftNotification' {

    BeforeEach {
        Mock -ModuleName TenantBaseline Write-TBLog {}
        Mock -ModuleName TenantBaseline Start-Sleep {}

        $script:testMonitor = [PSCustomObject]@{
            Id          = 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
            DisplayName = 'MFA Required Monitor'
            Status      = 'active'
            Mode        = 'monitorOnly'
        }

        $script:testResult = [PSCustomObject]@{
            Id                    = '7a8b9c0d-1234-5678-9abc-def012345678'
            MonitorId             = 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
            TenantId              = '96bf81b4-2694-42bb-9204-70081135ca61'
            RunStatus             = 'successful'
            RunCompletionDateTime = '2025-01-20T02:05:31.4567890Z'
            DriftsCount           = 2
        }

        $script:testDrifts = @(
            [PSCustomObject]@{
                Id                          = 'a3c17d62-e4b8-4f09-b6a1-8d2e5f7c9012'
                MonitorId                   = 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
                TenantId                    = '96bf81b4-2694-42bb-9204-70081135ca61'
                ResourceType                = 'microsoft.entra.conditionalaccesspolicy'
                BaselineResourceDisplayName = 'Require MFA for All Users'
                FirstReportedDateTime       = '2025-01-15T14:22:31.6543210Z'
                Status                      = 'active'
                ResourceInstanceIdentifier  = [PSCustomObject]@{ Identity = 'CA-Policy-MFA-AllUsers' }
                DriftedProperties           = @(
                    [PSCustomObject]@{
                        propertyName = 'State'
                        desiredValue = 'enabled'
                        currentValue = 'disabled'
                    }
                )
            },
            [PSCustomObject]@{
                Id                          = 'c8f94b21-3a6e-4d70-9e85-1b4c7f0a2d63'
                MonitorId                   = 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
                TenantId                    = '96bf81b4-2694-42bb-9204-70081135ca61'
                ResourceType                = 'microsoft.exchange.transportrule'
                BaselineResourceDisplayName = 'Block External Auto-Forwarding'
                FirstReportedDateTime       = '2025-01-10T08:15:22.9876543Z'
                Status                      = 'fixed'
                ResourceInstanceIdentifier  = [PSCustomObject]@{ Identity = 'Block-External-AutoForward' }
                DriftedProperties           = @(
                    [PSCustomObject]@{
                        propertyName = 'State'
                        desiredValue = 'Enabled'
                        currentValue = 'Disabled'
                    }
                )
            }
        )

        Mock -ModuleName TenantBaseline Get-TBMonitor { return $script:testMonitor }
        Mock -ModuleName TenantBaseline Get-TBMonitorResult { return @($script:testResult) }
        Mock -ModuleName TenantBaseline Get-TBDrift { return $script:testDrifts }
        Mock -ModuleName TenantBaseline Invoke-RestMethod { return @{ ok = $true } }
    }

    Context 'When a new drift-bearing result exists' {

        It 'Sends a webhook and writes notification state' {
            $tempState = Join-Path ([System.IO.Path]::GetTempPath()) ('tbnotify-{0}.json' -f [guid]::NewGuid().ToString('N'))

            try {
                $result = Send-TBDriftNotification -WebhookUrl 'https://example.test/webhook' -StatePath $tempState -PayloadFormat Generic -Confirm:$false

                $result.NotificationSent | Should -BeTrue
                $result.ActiveDriftCount | Should -Be 1
                Test-Path -Path $tempState | Should -BeTrue

                Should -Invoke -CommandName Invoke-RestMethod -ModuleName TenantBaseline -Times 1 -Exactly -ParameterFilter {
                    $Uri -eq 'https://example.test/webhook'
                }

                $state = Get-Content -Path $tempState -Raw | ConvertFrom-Json
                $state.Items.'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'.LastNotifiedResultId | Should -Be '7a8b9c0d-1234-5678-9abc-def012345678'
                $state.Items.'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'.LastActiveDriftFingerprint | Should -Not -BeNullOrEmpty
            }
            finally {
                if (Test-Path -Path $tempState) {
                    Remove-Item -Path $tempState -Force
                }
            }
        }
    }

    Context 'When the latest result was already notified' {

        It 'Skips the webhook when a newer run reports the same active drift set' {
            $tempState = Join-Path ([System.IO.Path]::GetTempPath()) ('tbnotify-{0}.json' -f [guid]::NewGuid().ToString('N'))

            try {
                $null = Send-TBDriftNotification -WebhookUrl 'https://example.test/webhook' -StatePath $tempState -Confirm:$false

                Mock -ModuleName TenantBaseline Get-TBMonitorResult {
                    return @(
                        [PSCustomObject]@{
                            Id                    = '99999999-2222-3333-4444-555555555555'
                            MonitorId             = 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
                            TenantId              = '96bf81b4-2694-42bb-9204-70081135ca61'
                            RunStatus             = 'successful'
                            RunCompletionDateTime = '2025-01-21T02:05:31.4567890Z'
                            DriftsCount           = 2
                        }
                    )
                }

                $second = Send-TBDriftNotification -WebhookUrl 'https://example.test/webhook' -StatePath $tempState -Confirm:$false

                $second.NotificationSent | Should -BeFalse
                $second.Duplicate | Should -BeTrue
                $second.Reason | Should -Be 'AlreadyNotified'

                Should -Invoke -CommandName Invoke-RestMethod -ModuleName TenantBaseline -Times 1 -Exactly
            }
            finally {
                if (Test-Path -Path $tempState) {
                    Remove-Item -Path $tempState -Force
                }
            }
        }
    }

    Context 'When the latest result has no drift' {

        It 'Does not send a notification' {
            Mock -ModuleName TenantBaseline Get-TBMonitorResult {
                return @(
                    [PSCustomObject]@{
                        Id                    = '11111111-2222-3333-4444-555555555555'
                        MonitorId             = 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
                        TenantId              = '96bf81b4-2694-42bb-9204-70081135ca61'
                        RunStatus             = 'successful'
                        RunCompletionDateTime = '2025-01-21T02:05:31.4567890Z'
                        DriftsCount           = 0
                    }
                )
            }

            $result = Send-TBDriftNotification -WebhookUrl 'https://example.test/webhook' -Confirm:$false

            $result.NotificationSent | Should -BeFalse
            $result.Reason | Should -Be 'NoDrift'
            Should -Invoke -CommandName Invoke-RestMethod -ModuleName TenantBaseline -Times 0 -Exactly
        }
    }

    Context 'When drifts are no longer active' {

        It 'Skips the notification even if the latest result still has drift count' {
            Mock -ModuleName TenantBaseline Get-TBDrift {
                return @(
                    [PSCustomObject]@{
                        Id                          = 'c8f94b21-3a6e-4d70-9e85-1b4c7f0a2d63'
                        MonitorId                   = 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
                        TenantId                    = '96bf81b4-2694-42bb-9204-70081135ca61'
                        ResourceType                = 'microsoft.exchange.transportrule'
                        BaselineResourceDisplayName = 'Block External Auto-Forwarding'
                        FirstReportedDateTime       = '2025-01-10T08:15:22.9876543Z'
                        Status                      = 'fixed'
                        ResourceInstanceIdentifier  = [PSCustomObject]@{ Identity = 'Block-External-AutoForward' }
                        DriftedProperties           = @(
                            [PSCustomObject]@{
                                propertyName = 'State'
                                desiredValue = 'Enabled'
                                currentValue = 'Disabled'
                            }
                        )
                    }
                )
            }

            $result = Send-TBDriftNotification -WebhookUrl 'https://example.test/webhook' -Confirm:$false

            $result.NotificationSent | Should -BeFalse
            $result.Reason | Should -Be 'NoActiveDrift'
            Should -Invoke -CommandName Invoke-RestMethod -ModuleName TenantBaseline -Times 0 -Exactly
        }
    }

    Context 'When the latest run failed' {

        It 'Skips the notification and reports the reason' {
            Mock -ModuleName TenantBaseline Get-TBMonitorResult {
                return @(
                    [PSCustomObject]@{
                        Id                    = '11111111-2222-3333-4444-555555555555'
                        MonitorId             = 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
                        TenantId              = '96bf81b4-2694-42bb-9204-70081135ca61'
                        RunStatus             = 'failed'
                        RunCompletionDateTime = '2025-01-21T02:05:31.4567890Z'
                        DriftsCount           = 0
                    }
                )
            }

            $result = Send-TBDriftNotification -WebhookUrl 'https://example.test/webhook' -Confirm:$false

            $result.NotificationSent | Should -BeFalse
            $result.Reason | Should -Be 'LatestRunNotSuccessful'
            Should -Invoke -CommandName Invoke-RestMethod -ModuleName TenantBaseline -Times 0 -Exactly
        }
    }

    Context 'When the webhook endpoint has a transient failure' {

        It 'Retries before succeeding' {
            $tempState = Join-Path ([System.IO.Path]::GetTempPath()) ('tbnotify-{0}.json' -f [guid]::NewGuid().ToString('N'))
            $script:webhookAttempts = 0
            Mock -ModuleName TenantBaseline Invoke-RestMethod {
                $script:webhookAttempts++
                if ($script:webhookAttempts -lt 3) {
                    throw 'Temporary webhook failure'
                }

                return @{ ok = $true }
            }

            try {
                $result = Send-TBDriftNotification -WebhookUrl 'https://example.test/webhook' -StatePath $tempState -Confirm:$false

                $result.NotificationSent | Should -BeTrue
                Should -Invoke -CommandName Invoke-RestMethod -ModuleName TenantBaseline -Times 3 -Exactly
                Should -Invoke -CommandName Start-Sleep -ModuleName TenantBaseline -Times 2 -Exactly
            }
            finally {
                if (Test-Path -Path $tempState) {
                    Remove-Item -Path $tempState -Force
                }
            }
        }
    }
}
