# Getting Started with TenantBaseline

## Prerequisites

1. **PowerShell 7.2+**
2. **Microsoft.Graph.Authentication module** (v2.0.0+)
3. **Entra ID tenant** with Global Administrator or appropriate admin roles

## Installation

```powershell
# From PowerShell Gallery
Install-Module -Name TenantBaseline -Scope CurrentUser

# Or clone and import directly
git clone https://github.com/ugurkocde/TenantBaseline.git
Import-Module ./tenantbaseline/src/TenantBaseline/TenantBaseline.psd1
```

## First-Time Setup

### 1. Connect to your tenant

```powershell
Connect-TBTenant -Scenario Setup
```

This opens a browser-based interactive login for setup operations. After setup, reconnect with the lower-privilege manage profile:

```powershell
Connect-TBTenant -Scenario Manage
```

### 2. Provision the UTCM service principal

This is a one-time step per tenant. The UTCM service principal is a Microsoft first-party application that executes the configuration monitors.

```powershell
Install-TBServicePrincipal
```

### 3. Grant workload permissions

Grant the service principal permission to monitor specific workloads:

```powershell
# Grant permissions for Conditional Access monitoring
Grant-TBServicePrincipalPermission -Workload ConditionalAccess

# Preview the full plan (auto + manual steps)
Get-TBPermissionPlan -Workload MultiWorkload

# Or grant permissions for all workloads at once
Grant-TBServicePrincipalPermission -Workload MultiWorkload
```

## Creating Your First Monitor

### Creating a monitor

```powershell
# Create a monitor with resources to track
New-TBMonitor -DisplayName 'MFA Required Monitor' -Resources @(
    @{ resourceType = 'microsoft.entra.conditionalaccesspolicy'; displayName = 'MFA Policy' }
)
```

### Checking for drift

Monitors run on a 6-hour cycle. After the first run completes:

```powershell
# List all detected drifts
Get-TBDrift

# Get an aggregated summary
Get-TBDriftSummary

# Generate an HTML report
New-TBDriftReport -OutputPath './drift-report.html'
```

### Taking a snapshot

```powershell
# Create a snapshot and wait for it to complete
$snapshot = New-TBSnapshot -DisplayName 'Daily Snapshot' -Resources @(
    'microsoft.entra.conditionalaccesspolicy',
    'microsoft.exchange.antiphishpolicy'
) | Wait-TBSnapshot

# Export the snapshot before it expires (7-day TTL)
Export-TBSnapshot -SnapshotId $snapshot.Id -OutputPath './snapshot.json'
```

## Next Steps

- Read about [Authentication](Authentication.md) options
- Check [API Limits](API-Limits.md) for service constraints
