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
# Before the first command runs, the audience needs to see you're in the right place.
# Two seconds of verification earns the trust that carries you through 40 minutes —
# they know you're live, not replaying a recording.
Get-AzContext | Select-Object Account, Subscription, Tenant

# Confirm Az.Compute is present. The tool fails fast and clearly if it isn't, but
# showing this upfront signals that the prerequisites are already handled.
Get-Module Az.Compute -ListAvailable | Select-Object Name, Version -First 1
#endregion Pre-Flight

# ============================================================
# CRAWL: "Where Can I Deploy?"
# ============================================================

#region Scenario 1 — Interactive Prompt Mode (~5 min)
# Start here with a new audience. No parameters — the tool speaks first.
# Watch their faces: the prompts walk through the exact decisions they fumble through
# in the portal today. Every question the tool asks is one they've been answering
# slowly, one click at a time.
.\Get-AzVMAvailability.ps1

# Drill-down unlocks per-SKU detail: generation, architecture, CPU vendor, disk type,
# zone availability, and quota — all in one table.
# This is where "it shows me what I need" becomes "it shows me things I didn't know to ask."
.\Get-AzVMAvailability.ps1 `
    -Region "eastus" `
    -FamilyFilter "D" `
    -EnableDrillDown
#endregion Scenario 1

#region Scenario 2 — Targeted Multi-Region Scan (~3 min)
# The near miss: you know your SKU family and have 3 candidate regions.
# Without this you open three portal browser tabs, navigate to Quotas in each,
# and still don't have a side-by-side answer.
# This does all three in 5 seconds — one command, one table, one decision.
.\Get-AzVMAvailability.ps1 `
    -Region "eastus", "westus2", "centralus" `
    -FamilyFilter "D" `
    -NoPrompt
#endregion Scenario 2

#region Scenario 3 — Region Presets (~2 min)
# Typing individual region names is the wrong way.
# USMajor = eastus, eastus2, centralus, westus, westus2 — five regions, one word.
# This is how "let me check each region" becomes "I scanned all major US regions"
# in the time it would take to mistype a region name in the portal.
.\Get-AzVMAvailability.ps1 `
    -RegionPreset USMajor `
    -FamilyFilter "D", "E" `
    -NoPrompt
#endregion Scenario 3

#region Scenario 4 — Placement Scores (~3 min)
# Availability status tells you the SKU exists in the catalog.
# Placement Score answers the harder question: will Azure actually hand you 5 of them right now?
# High = deploy with confidence. Medium = have a backup plan. Low = find another region.
# This is the column that stops a failed deployment at planning time — not at 2am.
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
# Run this when you're in the room with a FinOps stakeholder.
# EA/MCA negotiated rates auto-detect — no manual rate card lookup.
# The moment your actual contract price appears next to availability status
# is the moment the conversation shifts from "interesting tool" to "I need this."
.\Get-AzVMAvailability.ps1 `
    -Region "eastus" `
    -FamilyFilter "D" `
    -ShowPricing `
    -NoPrompt

# Part B — Spot vs. On-Demand cost delta.
# Typical spot discount on D-series: 60-80% off on-demand.
# A D8s_v5 at $0.11/hr instead of $0.38/hr — show that number, then explain the eviction trade-off.
# That contrast is what makes the spot decision land permanently.
# Note: -ShowSpot is available in recommend mode when -ShowPricing is also enabled.
.\Get-AzVMAvailability.ps1 `
    -Recommend "Standard_D4s_v5" `
    -Region "eastus" `
    -ShowPricing `
    -ShowSpot `
    -NoPrompt
#endregion Scenario 5

#region Scenario 6 — Image Compatibility (~3 min)
# The near miss: someone picks an ARM64 Ubuntu image, spins up a D4s_v5 (x64),
# and spends 3 hours debugging why the VM won't boot. No error message says "wrong architecture."
# This run filters the SKU list to only hardware the image can actually boot on —
# Ampere-based Dps/Eps for ARM64, Gen2 SKUs for Hyper-V Gen2 images.
# No more architecture mismatch at 2am.
.\Get-AzVMAvailability.ps1 `
    -Region "eastus" `
    -ImageURN "Canonical:0001-com-ubuntu-server-jammy:22_04-lts-arm64:latest" `
    -EnableDrillDown `
    -NoPrompt

# Alternative: Windows Server 2022 Gen2 (x64) for simpler demo
.\Get-AzVMAvailability.ps1 `
    -Region "eastus" `
   -ImageURN "MicrosoftWindowsServer:WindowsServer:2022-datacenter-g2:latest" `
    -EnableDrillDown `
    -NoPrompt
#endregion Scenario 6

#region Scenario 7 — Recommend Mode (~4 min)
# The most common customer call: "My v3 SKU is constrained. What do I move to?"
# Without this: open the portal, guess v4, guess v5, guess v5 in another region, file a ticket.
# Every guess almost right — none of them confirmed.
# With this: a ranked list in 30 seconds, scored on CPU, memory, family, generation,
# architecture, and IO. The score column ends the debate before it starts.
# Scoring: vCPU (25) + Memory (25) + Family (20) + Gen (13) + Arch (12) + PremiumIO (5) = 100 max.
.\Get-AzVMAvailability.ps1 `
    -Recommend "Standard_D4s_v3" `
    -Region "eastus", "westus2" `
    -ShowPricing `
    -TopN 10 `
    -NoPrompt

# AllowMixedArch broadens the search to include ARM64 Ampere candidates alongside x64.
# Fleet safety warnings fire automatically when architectures mix in the top results —
# so you can't accidentally recommend an upgrade that breaks binary compatibility.
.\Get-AzVMAvailability.ps1 `
    -Recommend "Standard_D4s_v3" `
    -Region "eastus" `
    -AllowMixedArch `
    -ShowPricing `
    -TopN 10 `
    -NoPrompt
#endregion Scenario 7

#region Scenario 7B — Fleet Readiness (BOM Validation) (~3 min)
# Scale the problem up: not one VM, but a deployment BOM of 28 VMs across 5 SKUs.
# PASS means every SKU in the plan has capacity and quota to deploy today.
# FAIL surfaces exactly which SKU is blocking you — before the ARM template runs,
# before the deployment window opens, before the on-call engineer gets paged at 2am.

# Option A: Load from CSV — the right choice when the BOM lives in a spreadsheet.
# Hand the fleet-bom.csv template to whoever owns the BOM; they fill in SKUs and quantities.
.\Get-AzVMAvailability.ps1 `
    -FleetFile .\examples\fleet-bom.csv `
    -Region "eastus" `
    -NoPrompt

# Option B: Inline hashtable — the right choice for scripting and CI gates. See Scenario 14.
# .\Get-AzVMAvailability.ps1 `
#     -Fleet @{'Standard_D2s_v5'=17; 'Standard_D4s_v5'=4; 'Standard_D8s_v5'=5; 'Standard_D16ds_v5'=1; 'Standard_D16ls_v6'=1} `
#     -Region "eastus" `
#     -NoPrompt
#endregion Scenario 7B

#region Scenario 7C — Generate Fleet Template
# Hand this to the person who owns the deployment BOM — no PowerShell knowledge required.
# Two output files: a CSV they open in Excel, and a JSON for automation consumers.
# Fill in SKU names and quantities, feed it back with -FleetFile. No Azure login needed.
.\Get-AzVMAvailability.ps1 -GenerateFleetTemplate
#endregion Scenario 7C

# ============================================================
# RUN: "Automation & Export"
# ============================================================

#region Scenario 8A — JSON Output for Pipelines
# Same scan, machine-readable output.
# Pipe this into a CI gate, an ADO pipeline task, a Logic App, or a monitoring script.
# The decision that just ran interactively becomes a structured API response
# that can block a deployment or trigger an alert automatically.
.\Get-AzVMAvailability.ps1 `
    -Recommend "D4s_v5" `
    -Region "eastus" `
    -JsonOutput `
    -NoPrompt
#endregion Scenario 8A

#region Scenario 8B — Excel Export for Stakeholders (~2 min)
# This is the output your stakeholder's manager actually reads.
# Three worksheets: a color-coded availability matrix, per-SKU detail, and a legend.
# Send this file instead of a screenshot — it re-runs in seconds whenever the data changes.
# Requires ImportExcel module; falls back gracefully to CSV if not installed.
.\Get-AzVMAvailability.ps1 `
    -Region "eastus" `
    -FamilyFilter "D" `
    -ShowPricing `
    -AutoExport `
    -NoPrompt
#endregion Scenario 8B

#region Scenario 8C — CSV Export (~1 min)
# No ImportExcel module? No problem.
# CSV opens in Excel, imports into any tool, and is Git-diffable.
# Use this when the consumer is a script, a dashboard, or a team without ImportExcel.
.\Get-AzVMAvailability.ps1 `
    -Region "eastus" `
    -FamilyFilter "D" `
    -OutputFormat CSV `
    -NoPrompt
#endregion Scenario 8C

# ============================================================
# ADVANCED: "Enterprise & Edge Scenarios"
# ============================================================

#region Scenario 9 — Recommend Tuning: Widen the Net (~2 min)
# Capacity is tight and the default score threshold is hiding candidates.
# -MinScore 0 opens the full list — every match, even low-confidence ones.
# -MinvCPU and -MinMemoryGB enforce a hard floor so no recommendation
# silently downgrades your workload's compute or memory profile.
.\Get-AzVMAvailability.ps1 `
    -Recommend "Standard_D4s_v3" `
    -Region "eastus" `
    -MinScore 0 `
    -MinvCPU 4 `
    -MinMemoryGB 16 `
    -ShowPricing `
    -TopN 15 `
    -NoPrompt
#endregion Scenario 9

#region Scenario 10 — GPU / ML Families + Wildcard Generation Scan (~3 min)
# NC, ND, NV families are capacity-constrained in almost every region.
# Run this before you promise a team their GPU training job starts Monday.
# It tells you which region actually has headroom right now — not six weeks ago.
.\Get-AzVMAvailability.ps1 `
    -Region "eastus", "westus2", "southcentralus" `
    -FamilyFilter "NC", "ND", "NV" `
    -NoPrompt

# Wildcard generation scan: every D-series v5 SKU matching Standard_D*s_v5.
# Use this when you know the generation but not the size — the full family ladder
# in one table so you pick the right vCPU count instead of guessing.
.\Get-AzVMAvailability.ps1 `
    -Region "eastus" `
    -SkuFilter "Standard_D*s_v5" `
    -NoPrompt
#endregion Scenario 10

#region Scenario 11 — DR Pair Planning (~3 min)
# Every DR plan has to answer one question: if my primary region fails,
# does the failover region have capacity for the fleet right now?
# Run this before the DR drill — not during it.
# ASR-EastWest = eastus + westus2. ASR-CentralUS = eastus + centralus.
.\Get-AzVMAvailability.ps1 `
    -RegionPreset ASR-EastWest `
    -FamilyFilter "D", "E" `
    -NoPrompt

.\Get-AzVMAvailability.ps1 `
    -RegionPreset ASR-CentralUS `
    -FamilyFilter "D", "E" `
    -NoPrompt
#endregion Scenario 11

#region Scenario 12 — Sovereign Cloud (Azure Government) (~2 min)
# One preset flag switches the entire Azure environment — no manual -Environment flag needed.
# FedRAMP/IL5 customers have the same question as everyone else:
# "Which SKUs are actually available in usgovvirginia right now?"
# They've just never had a tool that could answer it this fast.
# Note: Requires an active login to Azure Government (Connect-AzAccount -Environment AzureUSGovernment).
.\Get-AzVMAvailability.ps1 `
    -RegionPreset USGov `
    -FamilyFilter "D", "E" `
    -NoPrompt
#endregion Scenario 12

#region Scenario 13 — Multi-Subscription Scan (~3 min)
# Enterprise accounts spread capacity across subscriptions by design.
# Without this, every subscription is a separate scan, manually aggregated in a spreadsheet.
# Pass both IDs and the tool builds one combined picture — one run, full enterprise view.
# Replace the placeholder GUIDs with your actual subscription IDs before running.
$sub1 = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
$sub2 = "yyyyyyyy-yyyy-yyyy-yyyy-yyyyyyyyyyyy"

.\Get-AzVMAvailability.ps1 `
    -SubscriptionId $sub1, $sub2 `
    -Region "eastus" `
    -FamilyFilter "D" `
    -NoPrompt
#endregion Scenario 13

#region Scenario 14 — Fleet Inline Hashtable (~1 min)
# Same PASS/FAIL fleet validation as Scenario 7B — no CSV file required.
# This is the form that lives inside a deployment script or a CI pipeline gate.
# Validate capacity before `terraform apply`. Block the pipeline if the result is FAIL.
# The difference between a failed deployment at 3am and a blocked pipeline at 10am.
.\Get-AzVMAvailability.ps1 `
    -Fleet @{
        'Standard_D2s_v5'  = 17
        'Standard_D4s_v5'  = 4
        'Standard_D8s_v5'  = 5
        'Standard_D16ds_v5' = 1
        'Standard_D16ls_v6' = 1
    } `
    -Region "eastus" `
    -NoPrompt
#endregion Scenario 14

#region Scenario 15 — Cloud Shell / Narrow Terminal Mode (~1 min)
# Run this when you're on a 13" laptop, presenting on a narrow screen,
# or when the audience is in Azure Cloud Shell — which defaults to 80 columns.
# -UseAsciiIcons replaces Unicode ✓ ⚠ ✗ with [OK] [!!] [X] — no Nerd Font needed,
# works in every terminal, looks right in every recording or screenshot.
# -CompactOutput fits the entire table without horizontal scrolling.
.\Get-AzVMAvailability.ps1 `
    -Region "eastus" `
    -FamilyFilter "D" `
    -UseAsciiIcons `
    -CompactOutput `
    -NoPrompt
#endregion Scenario 15
