param(
    [Parameter()]
    [string]$WebhookVariableName = 'TB_WEBHOOK_URL',

    [Parameter()]
    [string]$StatePathVariableName = 'TB_NOTIFICATION_STATE_PATH',

    [Parameter()]
    [string]$ManagedIdentityClientIdVariableName = 'TB_MANAGED_IDENTITY_CLIENT_ID'
)

Import-Module TenantBaseline -ErrorAction Stop

$webhookUrl = Get-AutomationVariable -Name $WebhookVariableName
if (-not $webhookUrl) {
    throw "Automation variable '$WebhookVariableName' is not set."
}

$statePath = $null
try {
    $statePath = Get-AutomationVariable -Name $StatePathVariableName
}
catch {
    Write-Verbose "Automation variable '$StatePathVariableName' is not defined. Continuing without an explicit state path."
}

$managedIdentityClientId = $null
try {
    $managedIdentityClientId = Get-AutomationVariable -Name $ManagedIdentityClientIdVariableName
}
catch {
    Write-Verbose "Automation variable '$ManagedIdentityClientIdVariableName' is not defined. Using the system-assigned managed identity."
}

if ($managedIdentityClientId) {
    Connect-TBTenant -Identity -ClientId $managedIdentityClientId
}
else {
    Connect-TBTenant -Identity
}

$notifyParams = @{
    WebhookUrl = $webhookUrl
}

if ($statePath) {
    $notifyParams['StatePath'] = $statePath
}

Send-TBDriftNotification @notifyParams -Verbose
