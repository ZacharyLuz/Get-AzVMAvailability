---
name: release-verification-checklist
description: Verify local script release readiness against upstream main (version, runtime, guards, stale-copy hash check, smoke run). Use for pre-run troubleshooting or release sanity checks.
---

# Release Verification Checklist

## When to use
- User asks to verify script version and runtime before execution.
- User reports startup/runtime errors and wants to confirm stale-copy vs current `main`.
- User asks for a quick release sanity check before sharing scripts.

## Must follow
- Check host runtime first (`PowerShell 7+` required).
- Verify local script version line.
- Verify startup guard for `RunContext.AzureEndpoints` exists.
- Compare local file hash with upstream `main` raw script.
- Run a short non-interactive smoke command.

## Checklist
1) Confirm repo context (`Get-Location`, `git remote -v`)
2) Confirm script version line (`$ScriptVersion`)
3) Confirm host runtime (`$PSVersionTable.PSVersion` major >= 7)
4) Confirm guard patterns for `AzureEndpoints` run-context property
5) Hash-compare local file to upstream `main` raw script
6) Unblock file when downloaded from internet (`Unblock-File`)
7) Execute a minimal non-interactive smoke run

## Useful commands
- Version line: `Select-String -Path .\Get-AzVMAvailability.ps1 -Pattern '^\$ScriptVersion\s*=\s*"'`
- Runtime check: `$PSVersionTable.PSVersion; $PSVersionTable.PSEdition`
- Guard check: `Select-String -Path .\Get-AzVMAvailability.ps1 -Pattern 'AzureEndpoints\s*=\s*\$null|Add-Member.+AzureEndpoints|RunContext\.AzureEndpoints'`
- Upstream hash compare:
  - `$u = "https://raw.githubusercontent.com/ZacharyLuz/Get-AzVMAvailability/main/Get-AzVMAvailability.ps1"`
  - `Invoke-WebRequest -Uri $u -OutFile "$env:TEMP\Get-AzVMAvailability.main.ps1"`
  - `(Get-FileHash .\Get-AzVMAvailability.ps1).Hash`
  - `(Get-FileHash "$env:TEMP\Get-AzVMAvailability.main.ps1").Hash`
- Smoke run: `pwsh -File .\Get-AzVMAvailability.ps1 -NoPrompt -Region eastus -FamilyFilter D -TopN 3`

## Notes
- Keep this skill aligned with `docs/VERIFY-RELEASE.md`.
- If commands or required version change, update both files together.
