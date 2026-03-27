<#
.SYNOPSIS
    Demo command script for Get-AzVMAvailability live demonstrations.
.DESCRIPTION
    Copy-paste-ready commands organized by demo scenario.
    Run each section sequentially during the demo.
    Requires: PowerShell 7+, Az.Compute, Az.Resources, active Azure login.
.NOTES
    Duration: ~40 minutes (10 scenarios + closing)
    See demo/DEMO-GUIDE.md for talking points and transitions.
#>

#region Pre-Flight
# Verify Azure login and active subscription
Get-AzContext | Select-Object Account, Subscription, Tenant

# Confirm module availability
Get-Module Az.Compute -ListAvailable | Select-Object Name, Version -First 1
#endregion Pre-Flight

# ============================================================
# CRAWL: "Where Can I Deploy?"
# ============================================================

#region Scenario 1 — Interactive Prompt Mode (~5 min)
# No parameters — walk through prompts live.
# The tool prompts for subscription, region, and drill-down options.
.\Get-AzVMAvailability.ps1

# Step 2 — Introduce the drill-down: interactive family/SKU exploration.
# Run again with -EnableDrillDown to show per-SKU details: Gen, Arch, CPU, Disk, zones, quota.
.\Get-AzVMAvailability.ps1 `
    -Region "eastus" `
    -FamilyFilter "D" `
    -EnableDrillDown
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

#region Scenario 4 — Placement Scores (~3 min)
# Allocation likelihood from the Azure Placement Scores API: High / Medium / Low.
# Answers "not just *is* the SKU available, but *how likely* is Azure to fulfill the request?"
# Note: Requires "Compute Recommendations" RBAC role; degrades gracefully if absent.
.\Get-AzVMAvailability.ps1 `
    -Region "eastus", "westus2", "uksouth" `
    -SkuFilter "Standard_D4s_v5", "Standard_D8s_v5", "Standard_D16s_v5" `
    -ShowPlacement `
    -DesiredCount 5 `
    -NoPrompt
#endregion Scenario 4

# ============================================================
# WALK: "What Should I Deploy?"
# ============================================================

#region Scenario 5 — Live Pricing + Spot (~4 min)
# ShowPricing auto-detects EA/MCA negotiated rates.
# Falls back to Retail Pricing API if negotiated rates unavailable.
.\Get-AzVMAvailability.ps1 `
    -Region "eastus" `
    -FamilyFilter "D" `
    -ShowPricing `
    -NoPrompt

# Part B — Spot vs. On-Demand cost delta.
# ShowSpot adds a Spot $/hr column in recommend mode alongside regular on-demand pricing.
# Typical spot discounts: 40-80% off on-demand. Useful for batch/interruptible workloads.
# Note: -ShowSpot is available in recommend mode when -ShowPricing is also enabled.
.\.Get-AzVMAvailability.ps1 `
    -Recommend "Standard_D4s_v5" `
    -Region "eastus" `
    -ShowPricing `
    -ShowSpot `
    -NoPrompt
#endregion Scenario 5

#region Scenario 6 — Image Compatibility (~3 min)
# Ubuntu ARM64 image — only Ampere-based SKUs (Dps, Eps) are compatible.
# The drill-down (introduced in Scenario 1) now surfaces image compatibility details per SKU.
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
#endregion Scenario 6

#region Scenario 7 — Recommend Mode (~4 min)
# Customer's D4s_v3 is constrained — find scored alternatives.
# Scoring: vCPU (25pts) + Memory (25) + Family (20) + Gen (13) + Arch (12) + PremiumIO (5) = 100 max.
# v1.10+: CPU (Intel/AMD/ARM) and Disk columns added. Compatibility warnings fire on mixed-arch results.
.\Get-AzVMAvailability.ps1 `
    -Recommend "Standard_D4s_v3" `
    -Region "eastus", "westus2" `
    -ShowPricing `
    -TopN 10 `
    -NoPrompt

# AllowMixedArch — include ARM64 candidates alongside x64 for broader coverage.
# Compatibility warnings fire automatically when mixed x64/ARM64 SKUs appear in results.
.\Get-AzVMAvailability.ps1 `
    -Recommend "Standard_D4s_v3" `
    -Region "eastus" `
    -AllowMixedArch `
    -ShowPricing `
    -TopN 10 `
    -NoPrompt
#endregion Scenario 7

#region Scenario 7B — Inventory Readiness (BOM Validation) (~3 min)
# Validate an entire VM inventory BOM against a region's capacity and quota.
# This is a PASS/FAIL check: can all VMs in my deployment plan be provisioned?

# Option A: Load from CSV file (easiest for non-PowerShell users)
.\Get-AzVMAvailability.ps1 `
    -InventoryFile .\examples\fleet-bom.csv `
    -Region "eastus" `
    -NoPrompt

# Option B: Inline hashtable (for scripting)
# .\Get-AzVMAvailability.ps1 `
#     -Inventory @{'Standard_D2s_v5'=17; 'Standard_D4s_v5'=4; 'Standard_D8s_v5'=5; 'Standard_D16ds_v5'=1; 'Standard_D16ls_v6'=1} `
#     -Region "eastus" `
#     -NoPrompt
#endregion Scenario 7B

#region Scenario 7C — Generate Inventory Template
# Generate starter CSV + JSON inventory template files — no Azure login needed.
# Users edit the template with their actual SKUs, then run -InventoryFile.
.\Get-AzVMAvailability.ps1 -GenerateInventoryTemplate
#endregion Scenario 7C

# ============================================================
# RUN: "Automation & Export"
# ============================================================

#region Scenario 8A — JSON Output for Pipelines
# Structured JSON to stdout — pipe to file or parse in CI.
.\Get-AzVMAvailability.ps1 `
    -Recommend "D4s_v5" `
    -Region "eastus" `
    -JsonOutput `
    -NoPrompt
#endregion Scenario 8A

#region Scenario 8B — Excel Export for Stakeholders
# 3 worksheets: Summary (color-coded matrix), Details (per-SKU), Legend.
# Requires ImportExcel module; falls back to CSV if not installed.
.\Get-AzVMAvailability.ps1 `
    -Region "eastus" `
    -FamilyFilter "D" `
    -ShowPricing `
    -AutoExport `
    -OutputFormat XLSX `
    -NoPrompt
#endregion Scenario 8B
