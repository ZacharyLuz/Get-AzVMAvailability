<#
.SYNOPSIS
    Discovery probe for Consumption Price Sheet API — finds ALL pricing tiers
    (PAYG, Reservation 1Yr/3Yr, Savings Plan 1Yr/3Yr, Spot) in one pass.

.DESCRIPTION
    Hits the Price Sheet API directly and dumps the schema of items grouped by
    priceType / meterCategory / term to determine how each pricing tier is
    represented for the current tenant.

    Goal: confirm exactly what fields the Price Sheet exposes for each tier so
    we can extend Get-AzActualPricing to populate Reservation1Yr/3Yr,
    SavingsPlan1Yr/3Yr, and Spot maps with negotiated rates (currently it only
    captures PAYG Regular).

    Works for both commercial (AzureCloud) and sovereign (AzureUSGovernment,
    AzureChinaCloud) tenants — uses the current Az context to derive the
    correct ARM endpoint.

.PARAMETER SubscriptionId
    Subscription to query the price sheet against (must be EA/MCA/CSP).

.PARAMETER Region
    ARM region code to spot-check (e.g. usgovvirginia, eastus). Used only for
    filtering the report; the price sheet itself is tenant-scoped.

.PARAMETER MaxPages
    Maximum number of pages to scan. Default 600 — full price sheets are
    typically ~480 pages for commercial, fewer for sovereign.

.EXAMPLE
    .\Probe-PriceSheetRI.ps1 -SubscriptionId <subId> -Region usgovvirginia
    .\Probe-PriceSheetRI.ps1 -SubscriptionId <subId> -Region eastus
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$SubscriptionId,

    [string]$Region = 'usgovvirginia',

    [int]$MaxPages = 600
)

$ErrorActionPreference = 'Stop'
$ctx = Get-AzContext
if (-not $ctx) { throw "No Az context. Run Connect-AzAccount first." }

$envName = $ctx.Environment.Name
$armUrl  = $ctx.Environment.ResourceManagerUrl.TrimEnd('/')
Write-Host "Tenant   : $($ctx.Tenant.Id)"
Write-Host "Env      : $envName"
Write-Host "ARM URL  : $armUrl"
Write-Host "SubId    : $SubscriptionId"
Write-Host "Region   : $Region (used to filter samples)"
Write-Host ""

$token   = (Get-AzAccessToken -ResourceUrl $ctx.Environment.ResourceManagerUrl).Token
$headers = @{ Authorization = "Bearer $token" }

$psUrl = "$armUrl/subscriptions/$SubscriptionId/providers/Microsoft.Consumption/pricesheets/default?api-version=2023-05-01&`$expand=properties/meterDetails&`$top=1000"

# ── Diagnostic buckets ───────────────────────────────────────────────────────
$priceTypeCounts  = @{}
$categoryCounts   = @{}
$subCategoryCounts = @{}        # only for VM-related categories
$unitOfMeasureCounts = @{}      # only for VM-related categories
$termCounts       = @{}         # any non-empty term/reservationTerm value

# Bucketed samples per pricing tier (limit per bucket so we keep memory bounded)
$samples = @{
    'Reservation-1Yr' = New-Object System.Collections.Generic.List[object]
    'Reservation-3Yr' = New-Object System.Collections.Generic.List[object]
    'SavingsPlan-1Yr' = New-Object System.Collections.Generic.List[object]
    'SavingsPlan-3Yr' = New-Object System.Collections.Generic.List[object]
    'Spot'            = New-Object System.Collections.Generic.List[object]
    'Other-NonPAYG'   = New-Object System.Collections.Generic.List[object]
}
$sampleCap = 12  # per bucket

$pageCount  = 0
$totalItems = 0

$normalizedFilter = ($Region -replace '[\s-]', '').ToLower()
$regionAliases = @{
    'usgovarizona'  = 'usgovaz'
    'usgovtexas'    = 'usgovtx'
    'usgovvirginia' = 'usgov'
    'usdodcentral'  = 'usdod'
    'usdodeast'     = 'usdod'
}
$altFilter = $regionAliases[$normalizedFilter]

function Test-RegionMatch {
    param($MeterDetails)
    if (-not $MeterDetails -or -not $MeterDetails.meterLocation) { return $false }
    $loc = ($MeterDetails.meterLocation -replace '[\s-]', '').ToLower()
    return ($loc -eq $normalizedFilter) -or ($altFilter -and $loc -eq $altFilter)
}

function Add-Sample {
    param($Bucket, $Item, $Md, $PriceType)
    if ($samples[$Bucket].Count -ge $sampleCap) { return }
    $samples[$Bucket].Add([pscustomobject]@{
        PriceType        = $PriceType
        Category         = if ($Md) { [string]$Md.meterCategory } else { '' }
        SubCategory      = if ($Md) { [string]$Md.meterSubCategory } else { '' }
        MeterName        = if ($Md) { [string]$Md.meterName } else { '' }
        Location         = if ($Md) { [string]$Md.meterLocation } else { '' }
        UnitOfMeasure    = [string]$Item.unitOfMeasure
        UnitPrice        = $Item.unitPrice
        PretaxStandard   = if ($Md -and $Md.pretaxStandardRate) { $Md.pretaxStandardRate } else { $null }
        Term             = if ($Item.PSObject.Properties['term'])            { [string]$Item.term }            else { '' }
        ReservationTerm  = if ($Item.PSObject.Properties['reservationTerm']) { [string]$Item.reservationTerm } else { '' }
        Currency         = [string]$Item.currencyCode
    })
}

do {
    $pageCount++
    Write-Progress -Activity "Probing price sheet" `
        -Status ("Page {0}, {1} items, RI1={2} RI3={3} SP1={4} SP3={5} Spot={6}" -f `
            $pageCount, $totalItems,
            $samples['Reservation-1Yr'].Count, $samples['Reservation-3Yr'].Count,
            $samples['SavingsPlan-1Yr'].Count, $samples['SavingsPlan-3Yr'].Count,
            $samples['Spot'].Count) `
        -PercentComplete ([math]::Min(99, ($pageCount / $MaxPages) * 100))

    $resp = Invoke-RestMethod -Uri $psUrl -Headers $headers -Method Get -TimeoutSec 120
    foreach ($item in $resp.properties.pricesheets) {
        $totalItems++
        $md = $item.meterDetails

        # ── Track all priceType/type values across the whole sheet ──────────
        $pt = if ($item.PSObject.Properties['priceType'] -and $item.priceType) { [string]$item.priceType }
              elseif ($item.PSObject.Properties['type'] -and $item.type)       { [string]$item.type }
              else { '<none>' }
        if ($priceTypeCounts.ContainsKey($pt)) { $priceTypeCounts[$pt]++ } else { $priceTypeCounts[$pt] = 1 }

        $cat = if ($md -and $md.meterCategory) { [string]$md.meterCategory } else { '<no md>' }
        if ($categoryCounts.ContainsKey($cat)) { $categoryCounts[$cat]++ } else { $categoryCounts[$cat] = 1 }

        # ── Only deeply analyse VM-related rows ─────────────────────────────
        $isVmCategory = ($cat -match 'Virtual Machines') -or ($cat -match 'Reservation' -and $md.meterSubCategory -match 'VM|Virtual')
        if (-not $isVmCategory) { continue }

        $subCat = if ($md -and $md.meterSubCategory) { [string]$md.meterSubCategory } else { '' }
        if ($subCategoryCounts.ContainsKey($subCat)) { $subCategoryCounts[$subCat]++ } else { $subCategoryCounts[$subCat] = 1 }

        $uom = [string]$item.unitOfMeasure
        if ($unitOfMeasureCounts.ContainsKey($uom)) { $unitOfMeasureCounts[$uom]++ } else { $unitOfMeasureCounts[$uom] = 1 }

        $termVal = if ($item.PSObject.Properties['term'] -and $item.term) { [string]$item.term }
                   elseif ($item.PSObject.Properties['reservationTerm'] -and $item.reservationTerm) { [string]$item.reservationTerm }
                   else { '' }
        if ($termVal) {
            if ($termCounts.ContainsKey($termVal)) { $termCounts[$termVal]++ } else { $termCounts[$termVal] = 1 }
        }

        # ── Bucket samples for the requested region ─────────────────────────
        if (-not (Test-RegionMatch $md)) { continue }

        $isReservation = ($pt -match 'Reservation') -or ($termVal -match '^(P\d+Y|\d+\s+Year|\d+\s+Years)$')
        $isSavingsPlan = ($pt -match 'Savings\s*Plan|SavingsPlan') -or ($subCat -match 'Savings\s*Plan')
        $isSpot        = ($pt -match 'Spot') -or ($md.meterName -match 'Spot')

        if ($isReservation) {
            if ($termVal -match '1\s*Year|^P1Y') { Add-Sample 'Reservation-1Yr' $item $md $pt }
            elseif ($termVal -match '3\s*Year|^P3Y') { Add-Sample 'Reservation-3Yr' $item $md $pt }
            else { Add-Sample 'Other-NonPAYG' $item $md $pt }
        }
        elseif ($isSavingsPlan) {
            if ($termVal -match '1\s*Year|^P1Y') { Add-Sample 'SavingsPlan-1Yr' $item $md $pt }
            elseif ($termVal -match '3\s*Year|^P3Y') { Add-Sample 'SavingsPlan-3Yr' $item $md $pt }
            else { Add-Sample 'Other-NonPAYG' $item $md $pt }
        }
        elseif ($isSpot) {
            Add-Sample 'Spot' $item $md $pt
        }
        elseif ($pt -ne 'Consumption' -and $pt -ne '<none>') {
            Add-Sample 'Other-NonPAYG' $item $md $pt
        }
    }
    $psUrl = $resp.properties.nextLink
} while ($psUrl -and $pageCount -lt $MaxPages)

Write-Progress -Activity "Probing price sheet" -Completed

Write-Host "`n=== Summary ===" -ForegroundColor Cyan
Write-Host "Pages scanned : $pageCount"
Write-Host "Total items   : $totalItems"
Write-Host ""

Write-Host "All priceType / type values:" -ForegroundColor Yellow
$priceTypeCounts.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
    "  {0,-30} {1,10}" -f $_.Key, $_.Value
}

Write-Host "`nTop 20 meterCategory values:" -ForegroundColor Yellow
$categoryCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 20 | ForEach-Object {
    "  {0,-45} {1,10}" -f $_.Key, $_.Value
}

Write-Host "`nVM-only meterSubCategory values:" -ForegroundColor Yellow
$subCategoryCounts.GetEnumerator() | Sort-Object Value -Descending | Select-Object -First 25 | ForEach-Object {
    "  {0,-50} {1,10}" -f $_.Key, $_.Value
}

Write-Host "`nVM-only unitOfMeasure values:" -ForegroundColor Yellow
$unitOfMeasureCounts.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
    "  {0,-30} {1,10}" -f $_.Key, $_.Value
}

Write-Host "`nVM-only term / reservationTerm values:" -ForegroundColor Yellow
if ($termCounts.Count -eq 0) {
    Write-Host "  (none — no term fields populated on VM rows)" -ForegroundColor DarkGray
}
else {
    $termCounts.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        "  {0,-30} {1,10}" -f $_.Key, $_.Value
    }
}

foreach ($bucket in 'Reservation-1Yr','Reservation-3Yr','SavingsPlan-1Yr','SavingsPlan-3Yr','Spot','Other-NonPAYG') {
    Write-Host "`n--- $bucket samples for region '$Region' (cap $sampleCap) ---" -ForegroundColor Magenta
    if ($samples[$bucket].Count -eq 0) {
        Write-Host "  (none)" -ForegroundColor DarkGray
    }
    else {
        $samples[$bucket] | Format-Table PriceType, SubCategory, MeterName, UnitOfMeasure, UnitPrice, Term, ReservationTerm, Currency -AutoSize
    }
}
