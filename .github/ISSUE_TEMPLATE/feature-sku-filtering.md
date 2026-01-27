---
name: 'Feature: SKU Filtering'
about: Filter output to show only selected SKUs
title: '[FEATURE] Add -SkuFilter parameter to filter output'
labels: enhancement, v1.2.0
assignees: ''
---

## Feature Description

Add ability to filter output to show only specified SKUs throughout all reports (initial scan, matrix, summary, exports).

## Background

**Requested by:** Omar
**Use Case:** When users know exactly which SKUs they need to check, they don't want to see all SKUs in the output. This reduces clutter and makes results more actionable.

## Proposed Solution

### New Parameter
```powershell
-SkuFilter <string[]>
```

**Examples:**
```powershell
# Filter to specific SKUs
.\Azure-VM-Capacity-Checker.ps1 -SkuFilter "Standard_D2s_v3","Standard_E4s_v5" -Region "eastus","westus2"

# Combine with family filter
.\Azure-VM-Capacity-Checker.ps1 -FamilyFilter "D","E" -SkuFilter "Standard_D2s_v3","Standard_D4s_v3"
```

### Behavior
- When `-SkuFilter` is specified, **only** those SKUs appear in:
  - Per-region SKU tables
  - Multi-region matrix (families with matching SKUs only)
  - Drill-down results
  - Excel/CSV exports
- Counts should reflect filtered SKUs, not all SKUs
- Clear indication in output header: "Filtered to X SKU(s)"

### Implementation Notes
- Apply filter after `Get-AzComputeResourceSku` retrieval
- Filter should work with wildcard patterns (e.g., `Standard_D*_v5`)
- Case-insensitive matching
- Error if no SKUs match the filter

## Acceptance Criteria
- [ ] `-SkuFilter` parameter added and documented
- [ ] All output sections respect the filter
- [ ] Export files only contain filtered SKUs
- [ ] Clear user feedback when filter is applied
- [ ] Wildcard support (`*`) for pattern matching
- [ ] Works with `-FamilyFilter` in combination

## Related Issues
- #[TBD] - Add pricing information (v1.2.0)
