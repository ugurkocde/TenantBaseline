# Changelog

All notable changes to the TenantBaseline module will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0] - 2026-02-10

### Added
- Canonical UTCM resource catalog artifact (`UTCMResourceCatalog.json`) with 268 resource types
- `Get-TBPermissionPlan` for hybrid auto/granular permission planning
- OData pagination helper for complete list retrieval (`Invoke-TBGraphPagedRequest`)
- Shared Fluent HTML style tokens used by dashboard, report, and documentation outputs
- Contract tests for UTCM catalog parity

### Changed
- Runtime baseline is now PowerShell 7.2+
- `Connect-TBTenant` now uses scenario-based least-privilege scope profiles (`ReadOnly`, `Manage`, `Setup`)
- `Grant-TBServicePrincipalPermission` supports `-ResourceType` and `-PlanOnly`
- Interactive resource registry now sources from tracked canonical UTCM catalog instead of hardcoded lists
- Interactive resource selection supports optional search filtering per workload
- List commands now retrieve all pages through `@odata.nextLink`

### Fixed
- Documentation and help scope names aligned with implementation (`ConfigurationMonitoring.ReadWrite.All`)
- `Install-TBServicePrincipal` now reports permission grant issues explicitly instead of always indicating full success
- Alias deprecation warnings are now tracked per monitor operation invocation instead of module lifetime
