# Roadmap

## Version 1.0.0 (Current Release)
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

## Version 1.2.0 (In Planning)
**Theme: SKU Filtering & Pricing**

### New Features
- [ ] **SKU Filtering** - Filter output to show only selected SKUs throughout all reports
- [ ] **Pricing Information** - Display hourly/monthly costs next to each SKU
- [ ] **Cost Comparison** - Compare pricing across regions for selected SKUs

### New Parameters
- `-SkuFilter` - Specify SKUs upfront (e.g., 'Standard_D2s_v3', 'Standard_E4s_v5')
- `-ShowPricing` - Include pricing information in output
- `-PricingType` - Choose 'Linux' (default), 'Windows', or 'Both'

### Technical Implementation
```powershell
# Azure Retail Prices API
$apiUrl = "https://prices.azure.com/api/retail/prices"
$filter = "serviceName eq 'Virtual Machines' and armRegionName eq 'eastus' and armSkuName eq 'Standard_D2s_v3'"
Invoke-RestMethod -Uri "$apiUrl?`$filter=$filter" -Method Get
```

---

## Version 1.3.0 (In Planning)
**Theme: Image Compatibility & Advanced Filtering**

### New Features
- [ ] **Image Compatibility Check** - Verify if VM images work with selected SKUs
- [ ] **Generation Support** - Show Gen1/Gen2 VM support per SKU
- [ ] **OS Compatibility** - Filter by OS type (Windows/Linux)

### New Parameters
- `-ImageURN` - Check compatibility with specific image (e.g., 'Canonical:UbuntuServer:22.04-LTS:latest')
- `-VMGeneration` - Filter by VM generation (Gen1, Gen2, or Both)

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
