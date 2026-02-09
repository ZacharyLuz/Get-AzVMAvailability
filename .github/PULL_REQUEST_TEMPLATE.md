## Description

<!-- Brief summary of what this PR does and why -->

## Type of Change

- [ ] Bug fix (non-breaking change that fixes an issue)
- [ ] New feature (non-breaking change that adds functionality)
- [ ] Code quality (refactoring, comments, tests — no behavior change)
- [ ] Breaking change (fix or feature that would cause existing functionality to change)
- [ ] Documentation update

## Quality Checklist

- [ ] **No AI instructional comments** — no "Must be after", "This ensures", "Handle potential" comments
- [ ] **No empty catch blocks** — every catch has at least `Write-Verbose`
- [ ] **No magic numbers** — numeric literals are named constants
- [ ] **Version strings in sync** — `.NOTES`, `$ScriptVersion`, and ROADMAP all match
- [ ] **PSScriptAnalyzer clean** — `Invoke-ScriptAnalyzer -Path . -Recurse -Settings PSScriptAnalyzerSettings.psd1` returns no warnings/errors
- [ ] **Pester tests pass** — `Invoke-Pester ./tests -Output Detailed`
- [ ] **Syntax valid** — `[scriptblock]::Create((Get-Content 'Get-AzVMAvailability.ps1' -Raw)) | Out-Null` succeeds
- [ ] **CHANGELOG.md updated** (if functional change)

## Validation

- [ ] Ran `tools/Validate-Script.ps1` with all checks passing
- [ ] Tested with at least one Azure region (if applicable)
