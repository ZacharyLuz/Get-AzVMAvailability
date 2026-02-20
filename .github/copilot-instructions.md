# GitHub Copilot Instructions

## Tech Stack & Architecture

- **Primary Language:** PowerShell 7+
- **Cloud Platform:** Microsoft Azure (requires Az PowerShell modules)
- **Purpose:** Scans Azure regions for VM SKU availability, capacity, quota, pricing, and image compatibility.
- **Key Scripts:** All main logic is implemented in PowerShell scripts; no Node.js, Python, or other language dependencies.

## Key Files & Directories

- `Get-AzVMAvailability.ps1`: Main script for multi-region, multi-SKU Azure VM capacity and quota scanning.
- `dev/`: Experimental and advanced scripts, including:
  - `Azure-VM-Capacity-Planner.ps1`
  - `Azure-SKU-Scanner-Fast.ps1`
  - `Azure-SKU-Scanner-All-Families.ps1`
  - `Azure-SKU-Scanner-All-Families-v2.ps1`
- `tests/`: Pester tests for endpoint and logic validation.
- `examples/`: Usage examples and ARG queries.
- `.github/ISSUE_TEMPLATE/`: Issue templates for bug reports and feature requests.

## Build, Test, and Run

- **Run Main Script:**
  ```powershell
  .\Get-AzVMAvailability.ps1
  ```
- **Run Tests:**
  ```powershell
  Invoke-Pester .\tests\Get-AzureEndpoints.Tests.ps1 -Output Detailed
  ```
- **Requirements:**
  - PowerShell 7+
  - Az.Compute, Az.Resources modules
  - Azure login (`Connect-AzAccount`)

## Project Conventions

- **Parameterization:** Scripts prompt for SubscriptionId and Region if not provided.
- **Exports:** Results can be exported to CSV/XLSX (default export paths: `C:\Temp\...` or `/home/system` in Cloud Shell).
- **Parallelism:** Uses `ForEach-Object -Parallel` for fast region scanning.
- **Color-coded Output:** Capacity and quota status are visually highlighted.
- **No Azure CLI dependency:** Only Az PowerShell modules required.

## Branch Protection

- Main/master branches are protected from deletion and require PRs for changes.

## Contribution & Security

- See `CONTRIBUTING.md` for guidelines.
- See `SECURITY.md` for vulnerability reporting.
- **Always update `CHANGELOG.md`** when making functional changes (new features, bug fixes, breaking changes).

## Additional Notes

- All scripts are MIT licensed.
- For advanced usage, see scripts in `dev/` and documentation in `README.md` and `examples/`.

## Safe File Editing Practices

When making code changes to PowerShell scripts, follow these guidelines to avoid file corruption:

### Small, Targeted Edits
- **Make small, focused edits** rather than large structural changes in a single operation.
- When fixing indentation or brace structure, edit one block at a time.
- Avoid combining multiple unrelated changes into one replacement.

### Verify After Every Edit
- **Always verify syntax immediately** after each edit using:
  ```powershell
  [scriptblock]::Create((Get-Content 'script.ps1' -Raw)) | Out-Null
  # Returns True if valid, throws error if invalid
  ```
- Run `git diff` to inspect changes before testing the script.

### Git as Safety Net
- **Commit frequently** before making structural changes.
- Use `git checkout HEAD -- <file>` to restore from last commit if edits corrupt the file.
- The `replace_string_in_file` tool can fail silently or make unexpected changes if the `oldString` doesn't match exactly (whitespace, newlines matter!).

### Common Pitfalls
- Large replacement blocks can misalign if whitespace doesn't match character-for-character.
- Removing `else` blocks or changing loop structures requires careful brace counting.
- When code ends up in the wrong location after an edit, restore from git and retry with smaller edits.

### Testing Requirements
- Run Pester tests after changes: `Invoke-Pester .\tests\*.Tests.ps1 -Output Detailed`
- Requires Pester v5+ (install with: `Install-Module Pester -Force -SkipPublisherCheck`)

## Code Quality Guardrails

### Before Every Commit
Run the validation script to catch issues before they reach GitHub:
```powershell
.\tools\Validate-Script.ps1
```
This runs five checks: syntax validation, PSScriptAnalyzer linting, Pester tests, AI-comment pattern scan, and version consistency.

### Linting
- PSScriptAnalyzer settings are in `PSScriptAnalyzerSettings.psd1` at the repo root.
- The same settings file is used by VS Code (on-save) and CI (GitHub Actions).
- To run manually: `Invoke-ScriptAnalyzer -Path . -Recurse -Settings PSScriptAnalyzerSettings.psd1`

### Comment Standards
- **Keep** comments that explain *why* something non-obvious is done.
- **Remove** comments that restate what the next line of code does.
- **Never** leave instructional comments like "Must be after", "This ensures", "Handle potential" — these are AI artifacts.
- Use `#region`/`#endregion` for section organization, not `# ===` ASCII banners.

### Constants and Magic Numbers
- All numeric literals with non-obvious meaning must be named constants in the `#region Constants` block.
- Example: `$HoursPerMonth = 730` instead of bare `730`.

### Error Handling
- Every `catch` block must have at least `Write-Verbose` — no silent `catch { }`.
- API calls should use `Invoke-WithRetry` for transient error resilience (429, 503, timeouts).

## Tool Usage Guide for AI Assistants

This section is for GitHub Copilot CLI, the AzVMAvailability-Agent, or any AI system
that invokes this tool on behalf of a user making Azure VM deployment decisions.

### What This Tool Does

This is a **decision support tool** for Azure VM capacity planning. It answers:
- "What VM SKUs are available in my target regions?"
- "Is this specific SKU available, and if not, what's the closest alternative?"
- "How does availability, quota, pricing, and image compatibility compare across regions?"

The output drives real business decisions: production deployments, disaster recovery planning,
cost optimization, and capacity reservations. Accuracy matters.

### Modes of Operation

| Mode | When to use | Key parameters |
|------|-------------|----------------|
| **Scan** (default) | User wants to see what's available | `-Region`, `-FamilyFilter`, `-SkuFilter` |
| **Recommend** | User has a specific SKU that may be unavailable | `-Recommend`, `-TopN`, `-ShowPricing` |
| **JSON Output** | Agent/automation needs structured data | `-JsonOutput -NoPrompt` |

### Capacity Recommender — How Scoring Works

When `-Recommend` is used, the tool scores every available SKU against the target using:

| Factor | Points | Logic |
|--------|--------|-------|
| vCPU closeness | 25 | Ratio: `1 - abs(diff) / max`. |
| Memory closeness | 25 | Same ratio formula. |
| Family/category match | 20 | Exact family = 20. Same category (e.g., E and M are both Memory) = 15. Same first letter = 10. |
| VM generation | 13 | Any generation overlap = 13. No overlap = 0. |
| CPU architecture | 12 | Exact match (x64/Arm64) = 12. Mismatch = 0. |
| Premium IO | 5 | Both support premium = 5. Target doesn't need premium = 5. Target needs but candidate lacks = 0. |

**Max score: 100.** Candidates with RESTRICTED capacity are excluded entirely.

**Price is NOT a scoring factor.** Price is displayed so the user can make their own cost tradeoff.
The tool respects the user's original intent (family, size, features) rather than optimizing for cost.

### SKU Naming Convention

Azure VM SKU names encode the VM's purpose. Help users understand what they're asking for:

```
Standard_E64pds_v6
  E   = Family (Memory optimized)
  64  = vCPU count
  p   = ARM processor (Ampere)
  d   = Local temp disk (NVMe)
  s   = Premium storage capable
  v6  = Generation 6
```

Common suffixes: `a` = AMD, `d` = temp disk, `i` = isolated, `l` = low memory,
`m` = high memory, `p` = ARM, `s` = premium storage, `t` = constrained vCPU.

Family categories: **General** (B, D, DC), **Memory** (E, EC, G, M), **Compute** (F, FX),
**GPU** (NC, ND, NG, NP, NV), **HPC** (H, HB, HC, HX), **Storage** (L), **Basic** (A).

### Natural Language → Parameter Mapping

When a user describes their need in natural language, map to parameters:

| User says | Parameter |
|-----------|-----------|
| "alternative to E64pds_v6" | `-Recommend "Standard_E64pds_v6"` |
| "at least 64 cores" | `-MinvCPU 64` |
| "at least 256 GB memory" | `-MinMemoryGB 256` |
| "in US regions" | `-RegionPreset USMajor` |
| "any region" | scan multiple presets or list all regions |
| "show cost" / "with pricing" | `-ShowPricing` |
| "top 10 options" | `-TopN 10` |
| "for automation" / "as JSON" | `-JsonOutput -NoPrompt` |
| "check eastus and westus2" | `-Region "eastus","westus2"` |
| "GPU workload" | `-FamilyFilter "NC","ND","NV"` |
| "memory optimized" | `-FamilyFilter "E","M"` |

### Important Business Context

- **Capacity status is real-time** — OK now doesn't mean OK tomorrow. Advise users to act on results promptly.
- **LIMITED ≠ unavailable** — it means some zones or configurations are constrained. The SKU may still be deployable.
- **Quota is per-subscription** — a SKU can have OK capacity but the user may not have enough quota to deploy it.
- **Pricing varies by agreement** — the tool auto-detects EA/MCA/CSP negotiated rates and falls back to retail. Always note which pricing source is shown.
- **Never recommend based on stale data** — always run a fresh scan rather than relying on cached results.

### Related Tools

- [Get-AzAIModelAvailability](https://github.com/ZacharyLuz/Get-AzAIModelAvailability) — Companion tool for Azure AI model availability scanning
- [AzVMAvailability-Agent](https://github.com/ZacharyLuz/AzVMAvailability-Agent) — AI-powered conversational wrapper that uses this tool via `-JsonOutput`