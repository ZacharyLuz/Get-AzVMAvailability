# AI Agent Integration (Copilot Skill)

[← Back to README](../README.md)

This repo includes a **Copilot skill** that teaches AI coding agents (VS Code Copilot, Claude, Copilot CLI) how to invoke Get-AzVMAvailability for live capacity scanning. The skill provides routing logic, parameter mapping, and JSON output schema documentation so agents can translate natural language requests into the correct CLI invocations.

**Skill file:** [.github/skills/azure-vm-availability/SKILL.md](../.github/skills/azure-vm-availability/SKILL.md)

## What the skill enables

| User says | Agent runs |
|-----------|-----------|
| "Where can I deploy NC-series GPUs?" | `.\Get-AzVMAvailability.ps1 -NoPrompt -FamilyFilter "NC","ND","NV" -RegionPreset USMajor -JsonOutput` |
| "E64pds_v6 is constrained, find alternatives" | `.\Get-AzVMAvailability.ps1 -NoPrompt -Recommend "Standard_E64pds_v6" -Region "eastus","westus2" -JsonOutput` |
| "Check placement scores for D4s_v5" | `.\Get-AzVMAvailability.ps1 -NoPrompt -Recommend "Standard_D4s_v5" -Region "eastus" -ShowPlacement -JsonOutput` |

## Installing the skill for VS Code Copilot

This skill is already referenced in `.github/copilot-instructions.md` and loads automatically when you open this repo in VS Code with GitHub Copilot enabled.

To use it in **other repositories**, copy the skill to your local skills directory and reference it in that repo's Copilot instructions:

```powershell
# Windows
Copy-Item -Recurse ".github\skills\azure-vm-availability" "$env:USERPROFILE\.agents\skills\azure-vm-availability"

# macOS/Linux
cp -r .github/skills/azure-vm-availability ~/.agents/skills/azure-vm-availability
```
