## Summary
Adds a new `-ArchFilter` parameter to filter VM SKUs by CPU architecture (x64, ARM64).

## Motivation
Users frequently need to exclude ARM64 SKUs when planning x64-only workloads. Current workaround requires manual filtering of drill-down output or maintaining long explicit SKU lists.

## Changes
- Added `-ArchFilter` parameter with ValidateSet constraint
- Applied architecture filtering in serial and parallel scan blocks
- Updated header display to show active architecture filter
- Added Pester test coverage (Integration + ParameterParity)
- Updated docs: parameters.md, copilot-instructions.md, CHANGELOG.md

## Testing
- [x] Validated with `.\tools\Validate-Script.ps1`
- [x] Manual testing: x64-only, ARM64-only, combined filters
- [x] Parameter parity tests pass (102/102)
- [x] Integration tests pass (4/4)
