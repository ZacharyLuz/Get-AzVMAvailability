<#
.SYNOPSIS
    Dump the COMPLETE raw Consumption Price Sheet API response to JSON files
    for offline analysis. No source-side filtering — every row from every
    page is captured exactly as the API returned it. All bucketing /
    parsing decisions are made later from the dump.

.DESCRIPTION
    The runtime cache file (AzVMLifecycle-PriceSheet-v2-<tenant>.json) is
    heavily filtered (PAYG Regular VM meters only). When we need to design
    a new parser (e.g. negotiated RI / SP rate harvesting) we must work
    from the unfiltered source of truth, not from a cache that already
    threw most rows away.

    This script:
      1. Pages through the Price Sheet API using the current Az context.
      2. Writes EVERY row from every page verbatim to <OutputDir>\page-NNNN.json.
      3. Logs running bucket counts (Regular / Reservation / SavingsPlan /
         Spot / Other) for visibility during the run — counting only,
         no filtering.
      4. Zips the directory to <OutputDir>.zip for easy copy-back.

    Works for both commercial (AzureCloud) and sovereign tenants — uses the
    current context's ARM endpoint.

.PARAMETER SubscriptionId
    Subscription in the EA/MCA enrollment to query. Defaults to the current
    Az context's subscription.

.PARAMETER OutputDir
    Directory to write per-page JSON files into. Defaults to
    "$env:USERPROFILE\Desktop\pricesheet-raw-<env>-<yyyyMMdd-HHmmss>".

.PARAMETER MaxPages
    Safety cap on pages to fetch. Default 600.

.PARAMETER NoZip
    Skip the final Compress-Archive step (useful if 7zip etc. preferred).

.EXAMPLE
    .\Dump-PriceSheetRaw.ps1
    # Uses current context, writes to Desktop, zips when done.

.EXAMPLE
    .\Dump-PriceSheetRaw.ps1 -SubscriptionId <subId> -OutputDir C:\temp\ps-dump
#>
[CmdletBinding()]
param(
    [string]$SubscriptionId,
    [string]$OutputDir,
    [int]$MaxPages = 600,
    [switch]$NoZip
)

$ErrorActionPreference = 'Stop'

$ctx = Get-AzContext
if (-not $ctx) { throw "No Az context. Run Connect-AzAccount first." }

if (-not $SubscriptionId) {
    $SubscriptionId = $ctx.Subscription.Id
    if (-not $SubscriptionId) { throw "No subscription on current context. Pass -SubscriptionId or Set-AzContext first." }
}

if (-not $OutputDir) {
    $stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
    $OutputDir = Join-Path $env:USERPROFILE "Desktop\pricesheet-raw-$($ctx.Environment.Name)-$stamp"
}

New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

$armUrl = $ctx.Environment.ResourceManagerUrl.TrimEnd('/')
$tok    = (Get-AzAccessToken -ResourceUrl $ctx.Environment.ResourceManagerUrl).Token
$hdr    = @{ Authorization = "Bearer $tok" }

Write-Host "Tenant   : $($ctx.Tenant.Id)"
Write-Host "Env      : $($ctx.Environment.Name)"
Write-Host "ARM URL  : $armUrl"
Write-Host "SubId    : $SubscriptionId"
Write-Host "Output   : $OutputDir"
Write-Host ""

$url = "$armUrl/subscriptions/$SubscriptionId/providers/Microsoft.Consumption/pricesheets/default?api-version=2023-05-01&`$expand=properties/meterDetails&`$top=1000"

$page         = 0
$totalRaw     = 0
$bucketCounts = @{ Regular = 0; Reservation = 0; SavingsPlan = 0; Spot = 0; Other = 0 }
$sw           = [System.Diagnostics.Stopwatch]::StartNew()

while ($url -and $page -lt $MaxPages) {
    $page++
    Write-Progress -Activity "Dumping price sheet" `
        -Status ("Page {0} | rows={1} | RI={2} SP={3} Spot={4}" -f `
            $page, $totalRaw,
            $bucketCounts.Reservation, $bucketCounts.SavingsPlan, $bucketCounts.Spot) `
        -PercentComplete ([math]::Min(99, ($page / $MaxPages) * 100))

    try {
        $resp = Invoke-RestMethod -Uri $url -Headers $hdr -Method Get -TimeoutSec 120
    }
    catch {
        Write-Warning "Page $page failed: $($_.Exception.Message)"
        break
    }

    $rows = @($resp.properties.pricesheets)
    $totalRaw += $rows.Count

    # NO FILTERING — capture every row exactly as returned. Bucket counters
    # below are visibility only; they do not affect what gets written.

    foreach ($r in $rows) {
        $pt = if ($r.PSObject.Properties['priceType'] -and $r.priceType) { [string]$r.priceType }
              elseif ($r.PSObject.Properties['type'] -and $r.type)       { [string]$r.type }
              else { 'Other' }
        if ($pt -match 'Reservation') { $bucketCounts.Reservation++ }
        elseif ($pt -match 'Savings\s*Plan|SavingsPlan') { $bucketCounts.SavingsPlan++ }
        elseif ($pt -match 'Spot') { $bucketCounts.Spot++ }
        elseif ($pt -match 'Consumption|Regular') { $bucketCounts.Regular++ }
        else { $bucketCounts.Other++ }
    }

    if ($rows.Count -gt 0) {
        $outFile = Join-Path $OutputDir ("page-{0:D4}.json" -f $page)
        $rows | ConvertTo-Json -Depth 6 -Compress | Set-Content $outFile -Encoding UTF8
    }

    $url = $resp.properties.nextLink
}

Write-Progress -Activity "Dumping price sheet" -Completed
$sw.Stop()

Write-Host ""
Write-Host "=== Done ===" -ForegroundColor Cyan
Write-Host ("Pages    : {0}" -f $page)
Write-Host ("Rows     : {0} (all rows captured, no filtering)" -f $totalRaw)
Write-Host ("Buckets  : Regular={0}  Reservation={1}  SavingsPlan={2}  Spot={3}  Other={4}" -f `
    $bucketCounts.Regular, $bucketCounts.Reservation, $bucketCounts.SavingsPlan, $bucketCounts.Spot, $bucketCounts.Other)
Write-Host ("Elapsed  : {0:mm\:ss}" -f $sw.Elapsed)
Write-Host ""

if (-not $NoZip) {
    $zipPath = "$OutputDir.zip"
    if (Test-Path $zipPath) { Remove-Item $zipPath -Force }
    Compress-Archive -Path "$OutputDir\*" -DestinationPath $zipPath -CompressionLevel Optimal
    $zipMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
    Write-Host "Zip ready: $zipPath ($zipMB MB)" -ForegroundColor Green
    Write-Host "Copy this file back to the analysis machine." -ForegroundColor Yellow
}
else {
    Write-Host "Output dir: $OutputDir" -ForegroundColor Green
}
