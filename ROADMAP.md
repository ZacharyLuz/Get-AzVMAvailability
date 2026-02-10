# Roadmap

## Current Release: v1.7.0

See [CHANGELOG.md](CHANGELOG.md) for full version history.

---

## Version 1.0.0 (Initial Release)
- ✅ Multi-region parallel scanning
- ✅ SKU availability and capacity status
- ✅ Zone-level restriction details
- ✅ Quota tracking per family
- ✅ Multi-region comparison matrix
- ✅ Interactive drill-down
- ✅ CSV/XLSX export with conditional formatting
- ✅ Unicode/ASCII icon auto-detection

---

## Version 1.1.0 (Released)
**Theme: Enhanced Interactive Menus**

### Completed Features
- ✅ **Enhanced Region Selection** - Full interactive menu with geo-grouping
- ✅ **Fast Path for Regions** - Type region codes directly to skip menu
- ✅ **Enhanced Family Drill-Down** - SKU selection within each family
- ✅ **SKU Selection Modes** - Choose 'all', 'none', or specific SKUs per family

---

## Version 1.2.0 (Released)
**Theme: SKU Filtering & UX Improvements**

### Completed Features
- ✅ **SKU Filtering** - `-SkuFilter` parameter with wildcard support (e.g., `Standard_D*_v5`)
- ✅ **UX Improvements** - Clearer column names, better zone status display
- ✅ **Improved Messaging** - Consistent terminology throughout

---

## Version 1.3.0 (Released)
**Theme: Pricing Information & Fixed-Width Tables**

### Completed Features
- ✅ **Pricing Information** - Display estimated hourly costs from Azure Retail Prices API
- ✅ **Optional Pricing** - `-ShowPricing` parameter or interactive prompt
- ✅ **Fixed-Width Tables** - Consistent column alignment across all tables
- ✅ **Performance Awareness** - Pricing adds ~5-10 seconds, user is prompted

### New Parameters
- `-ShowPricing` - Include pricing information in output (Linux pay-as-you-go)

---

## Version 1.4.0 (Released)
**Theme: Image Compatibility**

### Completed Features
- [x] **Image Compatibility Check** - Verify if VM images work with selected SKUs
- [x] **Generation Support** - Show Gen1/Gen2 VM support per SKU
- [x] **Architecture Support** - Show x64/ARM64 support per SKU
- [x] **Interactive Image Picker** - 16 common images organized by category
- [x] **Marketplace Search** - Search by publisher or offer name
- [x] **Data Science VMs** - DSVM Ubuntu, DSVM Windows, Azure ML Workstation
- [x] **HPC Images** - Ubuntu HPC, AlmaLinux HPC

### New Parameters
- `-ImageURN` - Check compatibility with specific image (e.g., 'Canonical:0001-com-ubuntu-server-jammy:22_04-lts-gen2:latest')
- `-CompactOutput` - Use compact output for narrow terminals

---

## Version 1.5.0 / 1.5.1 (Released)
**Theme: Pricing Enhancements**

### Completed Features
- ✅ **Negotiated Pricing** - Auto-detect EA/MCA/CSP rates via Cost Management API
- ✅ **Pricing Fallback** - Graceful fallback from negotiated to retail pricing
- ✅ **Sovereign Cloud Pricing** - Correct pricing endpoints for Government/China/Germany clouds

### New Parameters
- `-ShowPricing` enhanced with negotiated rate detection

---

## Version 1.6.0 (Released)
**Theme: Cloud Shell Compatibility & UX**

### Completed Features
- ✅ **Cloud Shell Support** - Fixed-width tables, terminal width detection
- ✅ **Table Explanations** - Added how-to-read guides for all output sections
- ✅ **Excel Legend Sheet** - Dedicated legend sheet in XLSX exports
- ✅ **Improved Multi-Region Matrix** - Dynamic column widths, status explanations

---

## Version 1.7.0 (Released)
**Theme: Code Quality & Resilience**

### Developer Guardrails
- [x] **PSScriptAnalyzer Config** - Shared linter settings for local + CI consistency
- [x] **EditorConfig** - Enforce consistent formatting across editors
- [x] **VS Code Settings** - Lint-on-save for anyone cloning the repo
- [x] **Validation Script** - `tools/Validate-Script.ps1` for pre-commit checks (syntax + lint + tests + AI comment scan)
- [x] **PR Template** - Quality checklist for every pull request
- [x] **Copilot Instructions** - Guardrail workflow for AI-assisted development

### Resilience
- [x] **Retry Logic** - `Invoke-WithRetry` helper with exponential backoff for 429/503/transient errors
- [x] **`-MaxRetries` Parameter** - Configurable retry count (default 3)
- [x] **Parallel Retry** - Inline retry loop for region scanning in `-Parallel` block

### Code Cleanup
- [x] **`#region` Blocks** - Replace `# ===` banners with collapsible PowerShell regions
- [x] **Comment Cleanup** - Remove ~30 "what" comments, keep "why" comments
- [x] **Dead Code Removal** - Remove unused functions (`Format-FixedWidthTable`, `Get-SkuSizeAvailability`)
- [x] **Function Organization** - Move `Format-RegionList` to helper functions section
- [x] **Named Constants** - Replace magic numbers with descriptive variables

### Testing
- [x] **Retry Tests** - Pester tests for `Invoke-WithRetry` behavior
- [x] **Helper Function Tests** - Tests for `Get-SkuFamily`, `Get-RestrictionDetails`, `Format-ZoneStatus`, `Test-SkuMatchesFilter`, `Get-CapValue`

### Housekeeping
- [x] **Version Sync** - Align `$ScriptVersion`, CHANGELOG, and ROADMAP
- [x] **Fix Empty Catch** - Add `Write-Verbose` to silent catch block in image search
- [x] **Fix Lint Warnings** - `$matches` variable shadowing, null comparison order

---

## Future Enhancements (Backlog)

### Azure Resource Graph Integration
- [ ] **Current VM Inventory** - Show existing VMs deployed per region/SKU family
- [ ] **Cross-Subscription Discovery** - Use ARG to discover all accessible subscriptions faster
- [ ] **Deployment Density** - Visualize how many VMs are already in each region
- [ ] **Compare Available vs Deployed** - Side-by-side view of capacity vs current usage

### Enhanced Reporting
- [ ] **HTML Report Export** - Self-contained HTML report with charts
- [ ] **Trend Tracking** - Compare against previous scan results
- [ ] **Email/Chat Notifications** - Send results via email, Slack, or Teams webhooks

### Pricing Enhancements
- [ ] **Windows Pricing** - Add `-PricingType` parameter for Windows/Linux/Both
- [ ] **Spot Pricing** - Include spot instance pricing comparison
- [ ] **Monthly Estimates** - Show projected monthly costs

### Advanced Monitoring
- [ ] **Watch Mode** - Continuous monitoring with alerts
- [ ] **Capacity Alerts** - Notify when capacity status changes
- [ ] **Azure Function Deployment** - Run as scheduled serverless function

---

## Version 2.0.0 (Future)
**Theme: Proactive Monitoring**

- [ ] **Watch Mode** - Continuous monitoring with alerts
- [ ] **Capacity Alerts** - Notify when capacity status changes
- [ ] **Azure Monitor Integration** - Log results to Log Analytics
- [ ] **Azure Function Deployment** - Run as scheduled serverless function
- [ ] **REST API Wrapper** - Expose as lightweight API

---

## Contributing

Have ideas for new features? Open an issue or submit a PR!

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.
