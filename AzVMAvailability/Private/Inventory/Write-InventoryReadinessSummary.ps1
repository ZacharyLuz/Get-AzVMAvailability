function Write-InventoryReadinessSummary {
    [Alias('Write-FleetReadinessSummary')]
    <#
    .SYNOPSIS
        Renders the inventory readiness summary to console with color-coded pass/fail.
    #>
    param(
        [Parameter(Mandatory)]
        [Alias('FleetResult')]
        [hashtable]$InventoryResult,

        [Parameter(Mandatory)]
        [Alias('Fleet')]
        [hashtable]$Inventory
    )

    $totalVMs = ($Inventory.Values | Measure-Object -Sum).Sum
    $totalvCPU = ($InventoryResult.SKUs | Measure-Object -Property TotalvCPU -Sum).Sum

    Write-Host ""
    Write-Host ("=" * 100) -ForegroundColor Gray
    Write-Host "INVENTORY READINESS SUMMARY" -ForegroundColor Cyan
    Write-Host ("=" * 100) -ForegroundColor Gray
    Write-Host "Inventory: $($Inventory.Count) SKUs | $totalVMs VMs | $totalvCPU vCPUs total" -ForegroundColor White
    Write-Host "The RestrictionStatus column shows ARM SKU restriction status, not live allocatable capacity." -ForegroundColor DarkYellow
    Write-Host "OK = no restriction returned. Deployment can still fail due to quota, placement, or policy." -ForegroundColor DarkYellow
    Write-Host ""

    # Per-SKU table
    $headerFmt = "{0,-28} {1,4} {2,5} {3,5} {4,10} {5,22} {6,-12}"
    Write-Host ($headerFmt -f 'SKU', 'Qty', 'vCPU', 'Mem', 'Need', 'RestrictionStatus', 'Region') -ForegroundColor White
    Write-Host ("-" * 100) -ForegroundColor Gray

    foreach ($row in $InventoryResult.SKUs) {
        $capacityColor = switch ($row.RestrictionStatus) {
            'OK'                    { 'Green' }
            'LIMITED'               { 'Yellow' }
            'ZONE-LIMITED'          { 'DarkYellow' }
            'NOT FOUND'             { 'Red' }
            default                 { 'Gray' }
        }
        $needStr = "$($row.TotalvCPU) vCPU"
        $line = $headerFmt -f $row.SKU, $row.Qty, $row.vCPUEach, $row.MemGiBEach, $needStr, $row.RestrictionStatus, $row.BestRegion
        Write-Host $line -ForegroundColor $capacityColor
    }

    Write-Host ""
    Write-Host "QUOTA VALIDATION BY FAMILY:" -ForegroundColor White
    Write-Host ("-" * 100) -ForegroundColor Gray

    $quotaFmt = "{0,-40} {1,8} {2,8} {3,10} {4,8} {5,6}"
    Write-Host ($quotaFmt -f 'Quota Family', 'Need', 'Used', 'Available', 'Limit', 'Pass') -ForegroundColor White
    Write-Host ("-" * 100) -ForegroundColor Gray

    $allPass = $true
    foreach ($q in $InventoryResult.Quotas) {
        $passStr = if ($null -eq $q.Pass) { '?' } elseif ($q.Pass) { 'YES' } else { 'NO' }
        $passColor = if ($null -eq $q.Pass) { 'Yellow' } elseif ($q.Pass) { 'Green' } else { 'Red' }
        if ($q.Pass -eq $false) { $allPass = $false }
        if ($null -eq $q.Pass) { $allPass = $false }

        $line = $quotaFmt -f $q.QuotaFamily, $q.TotalDemand, $q.Used, $q.Available, $q.Limit, $passStr
        Write-Host $line -ForegroundColor $passColor
    }

    Write-Host ""
    if ($allPass) {
        Write-Host "INVENTORY READINESS: PASS" -ForegroundColor Green -BackgroundColor Black
        Write-Host "All SKUs returned no blocking ARM SKU restrictions and quota covers the inventory demand." -ForegroundColor Green
    }
    else {
        Write-Host "INVENTORY READINESS: FAIL" -ForegroundColor Red -BackgroundColor Black
        Write-Host "One or more SKUs returned blocking ARM SKU restrictions or insufficient quota." -ForegroundColor Red
        Write-Host "Request quota increase: https://aka.ms/ProdportalCRP/?#create/Microsoft.Support/Parameters/" -ForegroundColor Yellow
    }

    Write-Host ("=" * 100) -ForegroundColor Gray
}
