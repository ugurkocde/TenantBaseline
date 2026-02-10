#Requires -Modules Pester

BeforeAll {
    $projectRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..\..')).Path
    $modulePath  = Join-Path $projectRoot 'src' 'TenantBaseline' 'TenantBaseline.psd1'
    Import-Module $modulePath -Force

    $fixturesPath = Join-Path $projectRoot 'tests' 'Fixtures' 'MockResponses'
}

Describe 'ConvertFrom-TBMonitorResponse' {

    Context 'Converts hashtable response to typed object' {

        It 'Maps all properties from a hashtable' {
            $result = InModuleScope TenantBaseline {
                $response = @{
                    id                        = 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
                    displayName               = 'MFA Required Monitor'
                    description               = 'Monitors MFA enforcement across all users'
                    status                    = 'active'
                    mode                      = 'monitorOnly'
                    monitorRunFrequencyInHours = 6
                    tenantId                  = '96bf81b4-2694-42bb-9204-70081135ca61'
                    createdDateTime           = '2024-12-12T09:52:18.7982733Z'
                    lastModifiedDateTime      = '2024-12-12T09:52:18.8274415Z'
                    createdBy                 = @{ user = @{ id = '823da47e-fc25-48d8-8b5a-6186c760f0df'; displayName = 'Admin User' } }
                    parameters                = @(@{ name = 'testParam'; value = 'testValue' })
                }
                ConvertFrom-TBMonitorResponse -Response $response
            }

            $result.PSObject.TypeNames[0] | Should -Be 'TenantBaseline.Monitor'
            $result.Id | Should -Be 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
            $result.DisplayName | Should -Be 'MFA Required Monitor'
            $result.Description | Should -Be 'Monitors MFA enforcement across all users'
            $result.Status | Should -Be 'active'
            $result.Mode | Should -Be 'monitorOnly'
            $result.MonitorRunFrequencyInHours | Should -Be 6
            $result.TenantId | Should -Be '96bf81b4-2694-42bb-9204-70081135ca61'
            $result.CreatedDateTime | Should -Be '2024-12-12T09:52:18.7982733Z'
            $result.LastModifiedDateTime | Should -Be '2024-12-12T09:52:18.8274415Z'
            $result.Parameters | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Converts PSCustomObject response' {

        It 'Maps all properties from a PSCustomObject' {
            $result = InModuleScope TenantBaseline {
                $response = [PSCustomObject]@{
                    id              = 'b166c9cb-db29-438b-95fb-247da1dc72c3'
                    displayName     = 'Exchange Accepted Domain Monitor'
                    description     = 'Monitors Exchange accepted domain configuration for drift'
                    status          = 'active'
                    mode            = 'monitorOnly'
                    monitorRunFrequencyInHours = 6
                    tenantId        = '96bf81b4-2694-42bb-9204-70081135ca61'
                }
                ConvertFrom-TBMonitorResponse -Response $response
            }

            $result.Id | Should -Be 'b166c9cb-db29-438b-95fb-247da1dc72c3'
            $result.DisplayName | Should -Be 'Exchange Accepted Domain Monitor'
            $result.Status | Should -Be 'active'
            $result.Mode | Should -Be 'monitorOnly'
            $result.MonitorRunFrequencyInHours | Should -Be 6
        }
    }

    Context 'Sets null for missing properties' {

        It 'Returns null for properties not present in response' {
            $result = InModuleScope TenantBaseline {
                $response = @{
                    id          = 'mon-minimal'
                    displayName = 'Minimal'
                }
                ConvertFrom-TBMonitorResponse -Response $response
            }

            $result.Id | Should -Be 'mon-minimal'
            $result.DisplayName | Should -Be 'Minimal'
            $result.Description | Should -BeNullOrEmpty
            $result.Status | Should -BeNullOrEmpty
            $result.Mode | Should -BeNullOrEmpty
            $result.MonitorRunFrequencyInHours | Should -BeNullOrEmpty
            $result.InactivationReason | Should -BeNullOrEmpty
            $result.TenantId | Should -BeNullOrEmpty
            $result.CreatedBy | Should -BeNullOrEmpty
            $result.CreatedDateTime | Should -BeNullOrEmpty
            $result.LastModifiedBy | Should -BeNullOrEmpty
            $result.LastModifiedDateTime | Should -BeNullOrEmpty
            $result.Parameters | Should -BeNullOrEmpty
        }
    }

    Context 'Preserves RawResponse' {

        It 'Stores the original response in RawResponse' {
            $result = InModuleScope TenantBaseline {
                $response = @{
                    id          = 'mon-raw'
                    displayName = 'Raw Test'
                    status      = 'active'
                }
                ConvertFrom-TBMonitorResponse -Response $response
            }

            $result.RawResponse | Should -Not -BeNullOrEmpty
            $result.RawResponse['id'] | Should -Be 'mon-raw'
        }
    }

    Context 'Works with fixture data' {

        It 'Correctly converts the MonitorSingle fixture' {
            $fixtureData = Get-Content -Path (Join-Path $fixturesPath 'MonitorSingle.json') -Raw | ConvertFrom-Json

            $result = InModuleScope TenantBaseline -Parameters @{ resp = $fixtureData } {
                param($resp)
                ConvertFrom-TBMonitorResponse -Response $resp
            }

            $result.Id | Should -Be 'bf77ee1e-7750-40cb-8bcd-524dc4cdab02'
            $result.DisplayName | Should -Be 'MFA Required Monitor'
            $result.Status | Should -Be 'active'
            $result.Mode | Should -Be 'monitorOnly'
            $result.MonitorRunFrequencyInHours | Should -Be 6
            $result.TenantId | Should -Be '96bf81b4-2694-42bb-9204-70081135ca61'
        }
    }
}
