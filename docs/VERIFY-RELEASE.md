# Release Verification Checklist

Use this checklist before running, sharing, or troubleshooting `Get-AzVMAvailability.ps1`.

## Goals

- Confirm you are using the intended repository copy.
- Confirm the script version and required runtime.
- Detect stale local copies versus upstream `main`.
- Validate startup guards that prevent known runtime failures.

## 1) Confirm Repo Context

```powershell
Get-Location
git remote -v
```

## 2) Confirm Script Version

```powershell
Select-String -Path .\Get-AzVMAvailability.ps1 -Pattern '^\$ScriptVersion\s*=\s*"'
```

Expected: version line reads `$ScriptVersion = "X.Y.Z"` where `X.Y.Z` matches the latest release in `CHANGELOG.md`.

## 3) Confirm PowerShell Runtime (Required: 7+)

```powershell
$PSVersionTable.PSVersion
$PSVersionTable.PSEdition
```

Expected: `PSVersion.Major` is `7` or higher.

## 4) Confirm AzureEndpoints Startup Guard Exists

```powershell
Select-String -Path .\Get-AzVMAvailability.ps1 -Pattern 'AzureEndpoints\s*=\s*\$null|Add-Member.+AzureEndpoints|RunContext\.AzureEndpoints'
```

Expected: at least one hit for the run-context property initialization and assignment guard.

## 5) Detect Stale Local Copy (Hash Compare with Upstream main)

```powershell
$u       = "https://raw.githubusercontent.com/ZacharyLuz/Get-AzVMAvailability/main/Get-AzVMAvailability.ps1"
$tempDir = [System.IO.Path]::GetTempPath()
$outFile = Join-Path -Path $tempDir -ChildPath "Get-AzVMAvailability.main.ps1"
Invoke-WebRequest -Uri $u -OutFile $outFile
(Get-FileHash .\Get-AzVMAvailability.ps1).Hash
(Get-FileHash $outFile).Hash
```

Expected: hashes are identical.

## 6) Unblock Downloaded Script (If Needed)

```powershell
Unblock-File .\Get-AzVMAvailability.ps1
```

Use this when Windows marks the script as downloaded from the internet.

## 7) Quick Smoke Run (Non-Interactive)

Prerequisite: signed in to Azure (`Connect-AzAccount`) and required modules installed.

```powershell
pwsh -File .\Get-AzVMAvailability.ps1 -NoPrompt -Region eastus -FamilyFilter D -TopN 3
```

Expected:

- Script starts without `AzureEndpoints` startup property errors.
- No PowerShell 5.1 `ForEach-Object -Parallel` incompatibility path, because the host is PowerShell 7+.
- Basic scan output is produced.

## Troubleshooting Signals

- Version mismatch: update local script from repository `main`.
- Hash mismatch: local file is stale or modified.
- Host mismatch: launch with `pwsh -File .\Get-AzVMAvailability.ps1`.
- Execution policy warning: run `Unblock-File` once on the local script.
