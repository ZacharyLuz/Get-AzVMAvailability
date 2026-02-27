<#
.SYNOPSIS
    Demo command script for Get-AzVMAvailability live demonstrations.
.DESCRIPTION
    Copy-paste-ready commands organized by demo scenario.
    Run each section sequentially during the demo.
    Requires: PowerShell 7+, Az.Compute, Az.Resources, active Azure login.
.NOTES
    Duration: ~30 minutes (7 scenarios + closing)
    See demo/DEMO-GUIDE.md for talking points and transitions.
#>

#region Pre-Flight
# Verify Azure login and active subscription
Get-AzContext | Select-Object Account, Subscription, Tenant

# Confirm module availability
Get-Module Az.Compute -ListAvailable | Select-Object Name, Version -First 1
#endregion Pre-Flight

# ============================================================
# ACT 1: "Where Can I Deploy?"
# ============================================================

#region Scenario 1 — Interactive Prompt Mode (~4 min)
# No parameters — walk through prompts live.
# The tool prompts for subscription, region, and drill-down options.
.\Get-AzVMAvailability.ps1
#endregion Scenario 1

#region Scenario 2 — Targeted Multi-Region Scan (~3 min)
# D-series across 3 regions, no prompts. ~5 seconds.
.\Get-AzVMAvailability.ps1 `
    -Region "eastus", "westus2", "centralus" `
    -FamilyFilter "D" `
    -NoPrompt
#endregion Scenario 2

#region Scenario 3 — Region Presets (~2 min)
# USMajor preset = eastus, eastus2, centralus, westus, westus2
# D and E families for a broader view.
.\Get-AzVMAvailability.ps1 `
    -RegionPreset USMajor `
    -FamilyFilter "D", "E" `
    -NoPrompt
#endregion Scenario 3

# ============================================================
# ACT 2: "What Should I Deploy?"
# ============================================================

#region Scenario 4 — Live Pricing (~3 min)
# ShowPricing auto-detects EA/MCA negotiated rates.
# Falls back to Retail Pricing API if negotiated rates unavailable.
.\Get-AzVMAvailability.ps1 `
    -Region "eastus" `
    -FamilyFilter "D" `
    -ShowPricing `
    -NoPrompt
#endregion Scenario 4

#region Scenario 5 — Image Compatibility (~3 min)
# Ubuntu ARM64 image — only Ampere-based SKUs (Dps, Eps) are compatible.
# EnableDrillDown lets you explore compatible vs. incompatible SKUs.
.\Get-AzVMAvailability.ps1 `
    -Region "eastus" `
    -ImageURN "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-arm64:latest" `
    -EnableDrillDown `
    -NoPrompt

# Alternative: Windows Server 2022 Gen2 (x64) for simpler demo
# .\Get-AzVMAvailability.ps1 `
#     -Region "eastus" `
#     -ImageURN "MicrosoftWindowsServer:WindowsServer:2022-datacenter-g2:latest" `
#     -EnableDrillDown `
#     -NoPrompt
#endregion Scenario 5

#region Scenario 6 — Recommend Mode (~4 min)
# Customer's D4s_v3 is constrained — find scored alternatives.
# Scoring: vCPU (25pts) + Memory (25) + Family (20) + Gen (13) + Arch (12) + PremiumIO (5) = 100 max.
.\Get-AzVMAvailability.ps1 `
    -Recommend "Standard_D4s_v3" `
    -Region "eastus", "westus2" `
    -ShowPricing `
    -TopN 10 `
    -NoPrompt
#endregion Scenario 6

# ============================================================
# ACT 3: "Automation & Export"
# ============================================================

#region Scenario 7A — JSON Output for Pipelines
# Structured JSON to stdout — pipe to file or parse in CI.
.\Get-AzVMAvailability.ps1 `
    -Recommend "D4s_v5" `
    -Region "eastus" `
    -JsonOutput `
    -NoPrompt
#endregion Scenario 7A

#region Scenario 7B — Excel Export for Stakeholders
# 3 worksheets: Summary (color-coded matrix), Details (per-SKU), Legend.
# Requires ImportExcel module; falls back to CSV if not installed.
.\Get-AzVMAvailability.ps1 `
    -Region "eastus" `
    -FamilyFilter "D" `
    -ShowPricing `
    -AutoExport `
    -OutputFormat XLSX `
    -NoPrompt
#endregion Scenario 7B
