# Automation

TenantBaseline does not need to run on an admin workstation to send drift notifications. UTCM performs the monitor evaluation in Microsoft 365; your scheduled runner only needs to query the latest results and post notifications.

## Recommended Flow

1. Create and configure the UTCM monitor once.
2. Run TenantBaseline from a scheduler such as Azure Automation, GitHub Actions, or a container job.
3. Authenticate non-interactively with `Connect-TBTenant`.
4. Call `Send-TBDriftNotification` with a webhook endpoint.

## Azure Automation

Azure Automation is the best fit if you want a hosted PowerShell runner with a native schedule.

### 1. Create or choose an Automation account

- Create an Azure Automation account in the subscription where you want to host the runbook.
- Decide whether you will run in the Azure sandbox or on a Hybrid Runbook Worker.
- If you need durable local filesystem state for `TB_NOTIFICATION_STATE_PATH`, prefer a Hybrid Runbook Worker or another execution target with persistent storage.

### 2. Enable managed identity

TenantBaseline supports managed identity authentication through `Connect-TBTenant -Identity`.

- Enable a system-assigned managed identity on the Automation account if you want the simplest setup.
- If you need a user-assigned managed identity, attach it to the Automation account and record its client ID.
- Grant the managed identity service principal the Microsoft Graph application permissions required for your UTCM scenario, and complete admin consent in Entra ID.
- Validate the unattended Graph permissions in your tenant before you rely on the schedule in production.

If you later use a user-assigned managed identity, the runbook can pass the client ID to `Connect-TBTenant -Identity -ClientId ...`.

### 3. Create a PowerShell Runtime Environment

Azure Automation Runtime Environments let you define the runtime and package set that linked runbooks use.

- In the Azure portal, open your Automation account.
- Under `Process Automation`, select `Runtime Environments`.
- Create a PowerShell runtime environment that matches the PowerShell version you want to support for the runbook.
- Add packages from PowerShell Gallery to that runtime environment.

Recommended packages for this runbook:
- `Microsoft.Graph.Authentication`
- `TenantBaseline`

Notes:
- Keep the dependency modules in the same runtime environment as the runbook.
- If Azure Automation reports missing dependencies during import, import those dependencies first and wait until their state is `Available`.
- After you update packages in the runtime environment, linked runbooks use the updated package set automatically.

### 4. Create Automation variables

Store the runbook inputs as Automation variables instead of hardcoding them in the script.

Recommended variables:
- `TB_WEBHOOK_URL`
  Use an encrypted Automation variable. This is effectively a secret.
- `TB_NOTIFICATION_STATE_PATH`
  Use a standard string variable that points to a durable path only if your runner actually has persistent storage.
- `TB_MANAGED_IDENTITY_CLIENT_ID`
  Optional. Set this only when you are using a user-assigned managed identity.

Important:
- In the Azure Automation cloud sandbox, a file path alone does not create durable state across jobs.
- If you run in the cloud sandbox, duplicate suppression state can be lost between executions unless you restore and persist that file externally.
- For durable file-backed state, use a Hybrid Runbook Worker or another host with persistent storage.

### 5. Create the runbook

- Under `Process Automation`, select `Runbooks`.
- Create a new PowerShell runbook and link it to the runtime environment you created above.
- Upload or paste the sample runbook from [Send-TBDriftNotification.Runbook.ps1](/Users/ugurkoc/Desktop/GitHub/tenantbaseline/docs/examples/AzureAutomation/Send-TBDriftNotification.Runbook.ps1).
- If you want to inline it manually, use a script like this:

```powershell
Import-Module TenantBaseline

$webhookUrl = Get-AutomationVariable -Name 'TB_WEBHOOK_URL'
$statePath = Get-AutomationVariable -Name 'TB_NOTIFICATION_STATE_PATH'
$managedIdentityClientId = Get-AutomationVariable -Name 'TB_MANAGED_IDENTITY_CLIENT_ID'

if (-not $webhookUrl) {
    throw 'Automation variable TB_WEBHOOK_URL is not set.'
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

Send-TBDriftNotification @notifyParams
```

### 6. Publish and test the runbook

- Save the draft.
- Publish the runbook. Azure Automation only schedules the published version.
- Start it manually once and verify:
  - the managed identity can connect to Microsoft Graph
  - `Get-TBMonitor` and `Get-TBMonitorResult` succeed
  - the webhook receives the expected payload

### 7. Link a schedule

- Open the published runbook.
- Select `Schedules`.
- Link an existing schedule or create a new one.
- Choose a recurrence that fits your operating model.

Practical guidance:
- UTCM monitor evaluations are not real-time. This scheduler is polling for new results.
- Hourly schedules are a reasonable starting point.
- If your monitors run on a six-hour cadence, running every hour usually gives you fast enough notification without excessive overhead.

## App Certificate Example

```powershell
Import-Module TenantBaseline

$webhookUrl = Get-AutomationVariable -Name 'TB_WEBHOOK_URL'
$statePath = Get-AutomationVariable -Name 'TB_NOTIFICATION_STATE_PATH'

Connect-TBTenant `
    -ClientId (Get-AutomationVariable -Name 'TB_CLIENT_ID') `
    -TenantId (Get-AutomationVariable -Name 'TB_TENANT_ID') `
    -CertificateThumbprint (Get-AutomationVariable -Name 'TB_CERT_THUMBPRINT')

$notifyParams = @{
    WebhookUrl = $webhookUrl
}

if ($statePath) {
    $notifyParams['StatePath'] = $statePath
}

Send-TBDriftNotification @notifyParams
```

## State and Duplicate Suppression

`Send-TBDriftNotification` uses a JSON state file to remember the last monitor result it notified. This prevents the same drift-bearing result from being sent repeatedly on each scheduled run.

Important for Azure Automation cloud jobs:
- The cloud sandbox does not provide durable local storage between job executions.
- If you point `TB_NOTIFICATION_STATE_PATH` at a local sandbox path, duplicate suppression state can be lost when the worker changes.
- For durable file-backed state, use a Hybrid Runbook Worker or another host with persistent storage.

- Use a persistent `-StatePath` whenever possible.
- Prefer an explicit environment variable such as `TB_NOTIFICATION_STATE_PATH` so the scheduler configuration owns the storage location.
- If your runner uses ephemeral disk, repeated notifications can occur after the worker is recycled.
- For hosted runners, prefer a mounted share, persistent workspace, or an external process that restores and saves the state file between runs.

## Payload Formats

- `TeamsAdaptiveCard` is the default payload format and works well for Teams-oriented webhook endpoints and workflow bridges.
- `Generic` sends plain JSON for Logic Apps, Azure Functions, custom APIs, or other automation endpoints.

## Example Notification

Example summary a Teams/webhook receiver will show:

```text
TenantBaseline Drift Alert

1 active drift detected for monitor "MFA Required Monitor"
Monitor: MFA Required Monitor
Latest Run: 2025-01-20T02:05:31.4567890Z
Active Drifts: 1
Total Drifted Properties: 2

microsoft.entra.conditionalaccesspolicy | CA-Policy-MFA-AllUsers | active
State: desired=enabled, current=disabled
GrantControls.BuiltInControls: desired=["mfa","compliantDevice"], current=["mfa"]
```

If you need a plain JSON payload for Logic Apps, Azure Functions, or another automation endpoint, use `-PayloadFormat Generic`.

## References

- Sample runbook in this repo: [Send-TBDriftNotification.Runbook.ps1](/Users/ugurkoc/Desktop/GitHub/tenantbaseline/docs/examples/AzureAutomation/Send-TBDriftNotification.Runbook.ps1)
- Runtime Environments in Azure Automation: https://learn.microsoft.com/en-us/azure/automation/runtime-environment-overview
- Manage Runtime Environments and linked runbooks: https://learn.microsoft.com/en-us/azure/automation/manage-runtime-environment
- Manage modules in Azure Automation: https://learn.microsoft.com/en-us/azure/automation/shared-resources/modules
- Manage variables in Azure Automation: https://learn.microsoft.com/en-us/azure/automation/shared-resources/variables
- Enable managed identities for Automation accounts: https://learn.microsoft.com/en-us/azure/automation/quickstarts/enable-managed-identity
- PowerShell runbook tutorial with managed identity: https://learn.microsoft.com/en-us/azure/automation/learn/powershell-runbook-managed-identity
- Manage schedules in Azure Automation: https://learn.microsoft.com/en-us/azure/automation/shared-resources/schedules
- Manage runbooks in Azure Automation: https://learn.microsoft.com/en-us/azure/automation/manage-runbooks
