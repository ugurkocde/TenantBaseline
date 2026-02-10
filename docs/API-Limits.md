# API Limits

The UTCM beta API has several service constraints to be aware of when planning your monitoring strategy.

## Monitor Limits

| Constraint | Value |
|-----------|-------|
| Maximum monitors per tenant | 30 |
| Maximum daily monitored resources | 800 |
| Monitoring cycle frequency | Every 6 hours |
| Snapshot expiration | 7 days |

## Planning Resource Budgets

Each monitor tracks one or more resources. The 800 daily resource limit is shared across all monitors. When designing your monitoring strategy:

- **Prioritize high-impact configurations** -- Conditional Access MFA and legacy auth blocking are typically most critical.
- **Plan multi-resource monitors wisely** -- Monitors with many resources are efficient but consume more of the daily budget.
- **Consolidate where possible** -- One monitor with 10 resources is more efficient than 10 monitors with 1 resource each.

## Snapshot Considerations

- Snapshots capture a point-in-time view of tenant configuration.
- They expire after 7 days and cannot be extended.
- Use `Export-TBSnapshot` to save snapshot data locally before expiration.
- Use `Wait-TBSnapshot` to poll until a snapshot job completes before exporting.

## Throttling

The module's internal API wrapper (`Invoke-TBGraphRequest`) automatically:

- Retries on HTTP 429 (Too Many Requests) with exponential backoff
- Retries on HTTP 503/504 (Service Unavailable) with exponential backoff
- Respects the `Retry-After` header when provided
- Defaults to 3 retry attempts

## Best Practices

1. Start with a few critical monitors and expand gradually.
2. Export snapshots promptly after completion.
3. Use `Get-TBDriftSummary` for a quick overview rather than fetching all individual drifts.
4. Schedule reports during off-peak hours if running against large tenants.
5. Monitor the `Get-TBMonitorResult` output for errors that may indicate permission issues.
