# ExportHandler.ps1
# Reference copy extracted from Get-AzVMAvailability.ps1 (lines 4047-4592)
# Contains: XLSX and CSV export logic, Excel formatting, export path selection,
#           and final export summary output.
# DO NOT execute this file directly — it is a documentation reference only.
# The authoritative source is Get-AzVMAvailability.ps1.
        if ($families.Count -gt 0) {
            Write-Host "  $r`:" -ForegroundColor Green -NoNewline
            Write-Host " $($families -join ', ')" -ForegroundColor White
        }
    }
}
else {
    Write-Host "No regions have full capacity for the scanned families." -ForegroundColor Yellow
    Write-Host "Best available options (with constraints):" -ForegroundColor Yellow
    foreach ($family in ($allFamilyStats.Keys | Sort-Object | Select-Object -First 5)) {
        $stats = $allFamilyStats[$family]
        $bestRegion = $stats.Regions.Keys | Sort-Object { $stats.Regions[$_].Available } -Descending | Select-Object -First 1
        if ($bestRegion) {
            $regionStat = $stats.Regions[$bestRegion]
            Write-Host "  $family in $bestRegion" -ForegroundColor Yellow -NoNewline
            Write-Host " ($($regionStat.Capacity))" -ForegroundColor DarkYellow
        }
    }
}

#endregion Deployment Recommendations
#region Detailed Breakdown

Write-Host "`n" -NoNewline
Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
Write-Host "DETAILED CROSS-REGION BREAKDOWN" -ForegroundColor Green
Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
Write-Host ""
Write-Host "SUMMARY: Shows which regions have capacity for each VM family." -ForegroundColor DarkGray
Write-Host "  'Available'   = At least one SKU in this family can be deployed here" -ForegroundColor DarkGray
Write-Host "  'Constrained' = Family has issues in this region (see reason in parentheses)" -ForegroundColor DarkGray
Write-Host "  '(none)'      = No regions in that category for this family" -ForegroundColor DarkGray
Write-Host ""
Write-Host "IMPORTANT: This is a family-level summary. Individual SKUs within a family" -ForegroundColor DarkYellow
Write-Host "           may have different availability. Check the detailed table above." -ForegroundColor DarkYellow
Write-Host ""

# Calculate column widths based on ACTUAL terminal width for better Cloud Shell support
# Try to detect actual console width, fall back to a safe default
$actualWidth = try {
    $hostWidth = $Host.UI.RawUI.WindowSize.Width
    if ($hostWidth -gt 0) { $hostWidth } else { $DefaultTerminalWidth }
}
catch { $DefaultTerminalWidth }

# Use the smaller of OutputWidth or actual terminal width for this table
$tableWidth = [Math]::Min($script:OutputWidth, $actualWidth - 2)
$tableWidth = [Math]::Max($tableWidth, $MinTableWidth)

# Fixed column widths for consistent alignment
# Family: 8 chars, Available: 20 chars, Constrained: rest
$colFamily = 8
$colAvailable = 20
$colConstrained = [Math]::Max(30, $tableWidth - $colFamily - $colAvailable - 4)

$headerFamily = "Family".PadRight($colFamily)
$headerAvail = "Available".PadRight($colAvailable)
$headerConst = "Constrained"
Write-Host "$headerFamily  $headerAvail  $headerConst" -ForegroundColor Cyan
Write-Host ("-" * $tableWidth) -ForegroundColor Gray

$summaryRowsForExport = @()
foreach ($family in ($allFamilyStats.Keys | Sort-Object)) {
    $stats = $allFamilyStats[$family]
    $regionsOK = [System.Collections.Generic.List[string]]::new()
    $regionsConstrained = [System.Collections.Generic.List[string]]::new()

    foreach ($regionKey in ($stats.Regions.Keys | Sort-Object)) {
        $regionKeyStr = Get-SafeString $regionKey
        $regionStat = $stats.Regions[$regionKey]  # Use original key for lookup
        if ($regionStat) {
            if ($regionStat.Capacity -eq 'OK') {
                $regionsOK.Add($regionKeyStr)
            }
            elseif ($regionStat.Capacity -match 'LIMITED|CAPACITY-CONSTRAINED|PARTIAL|RESTRICTED|BLOCKED') {
                # Shorten status labels for narrow terminals
                $shortStatus = switch -Regex ($regionStat.Capacity) {
                    'CAPACITY-CONSTRAINED' { 'CONSTRAINED' }
                    default { $regionStat.Capacity }
                }
                $regionsConstrained.Add("$regionKeyStr ($shortStatus)")
            }
        }
    }

    # Format multi-line output
    $okLines = @(Format-RegionList -Regions $regionsOK.ToArray() -MaxWidth $colAvailable)
    $constrainedLines = @(Format-RegionList -Regions $regionsConstrained.ToArray() -MaxWidth $colConstrained)

    # Flatten if nested (PowerShell array quirk)
    if ($okLines.Count -eq 1 -and $okLines[0] -is [array]) { $okLines = $okLines[0] }
    if ($constrainedLines.Count -eq 1 -and $constrainedLines[0] -is [array]) { $constrainedLines = $constrainedLines[0] }

    # Determine how many lines we need (max of both columns)
    $maxLines = [Math]::Max(@($okLines).Count, @($constrainedLines).Count)

    # Determine color for the family name based on availability
    # Green  = Perfect (All regions OK)
    # White  = Mixed (Some OK, some constrained - check details)
    # Yellow = Constrained (No regions strictly OK, all have limitations)
    # Gray   = Unavailable
    $familyColor = if ($regionsOK.Count -gt 0 -and $regionsConstrained.Count -eq 0) { 'Green' }
    elseif ($regionsOK.Count -gt 0 -and $regionsConstrained.Count -gt 0) { 'White' }
    elseif ($regionsConstrained.Count -gt 0) { 'Yellow' }
    else { 'Gray' }

    # Iterate through lines to print
    for ($i = 0; $i -lt $maxLines; $i++) {
        $familyStr = if ($i -eq 0) { $family } else { '' }
        $okStr = if ($i -lt @($okLines).Count) { @($okLines)[$i] } else { '' }
        $constrainedStr = if ($i -lt @($constrainedLines).Count) { @($constrainedLines)[$i] } else { '' }

        # Write each column with appropriate color (use 2 spaces between columns for clarity)
        Write-Host ("{0,-$colFamily}  " -f $familyStr) -ForegroundColor $familyColor -NoNewline
        Write-Host ("{0,-$colAvailable}  " -f $okStr) -ForegroundColor Green -NoNewline
        Write-Host $constrainedStr -ForegroundColor Yellow
    }

    # Export data
    $exportRow = [ordered]@{
        Family     = $family
        Total_SKUs = ($stats.Regions.Values | Measure-Object -Property Count -Sum).Sum
        SKUs_OK    = (($stats.Regions.Values | Where-Object { $_.Capacity -eq 'OK' } | Measure-Object -Property Available -Sum).Sum)
    }
    foreach ($r in $allRegions) {
        $regionStat = $stats.Regions[$r]
        if ($regionStat) {
            $exportRow["$r`_Status"] = "$($regionStat.Capacity) ($($regionStat.Available)/$($regionStat.Count))"
        }
        else {
            $exportRow["$r`_Status"] = 'N/A'
        }
    }
    $summaryRowsForExport += [pscustomobject]$exportRow
}

Write-Progress -Activity "Processing Region Data" -Completed

#endregion Detailed Breakdown
#region Completion

$totalElapsed = (Get-Date) - $scanStartTime

Write-Host "`n" -NoNewline
Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray
Write-Host "SCAN COMPLETE" -ForegroundColor Green
Write-Host "Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss') | Total time: $([math]::Round($totalElapsed.TotalSeconds, 1)) seconds" -ForegroundColor DarkGray
Write-Host ("=" * $script:OutputWidth) -ForegroundColor Gray

#endregion Completion
#region Export

if ($ExportPath) {
    $timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'

    # Determine format
    $useXLSX = ($OutputFormat -eq 'XLSX') -or ($OutputFormat -eq 'Auto' -and (Test-ImportExcelModule))

    Write-Host "`nEXPORTING..." -ForegroundColor Cyan

    if ($useXLSX -and (Test-ImportExcelModule)) {
        $xlsxFile = Join-Path $ExportPath "AzVMAvailability-$timestamp.xlsx"
        try {
            # Define colors for conditional formatting
            $greenFill = [System.Drawing.Color]::FromArgb(198, 239, 206)
            $greenText = [System.Drawing.Color]::FromArgb(0, 97, 0)
            $yellowFill = [System.Drawing.Color]::FromArgb(255, 235, 156)
            $yellowText = [System.Drawing.Color]::FromArgb(156, 101, 0)
            $redFill = [System.Drawing.Color]::FromArgb(255, 199, 206)
            $redText = [System.Drawing.Color]::FromArgb(156, 0, 6)
            $headerBlue = [System.Drawing.Color]::FromArgb(0, 120, 212)  # Azure blue
            $lightGray = [System.Drawing.Color]::FromArgb(242, 242, 242)

            #region Summary Sheet
            $excel = $summaryRowsForExport | Export-Excel -Path $xlsxFile -WorksheetName "Summary" -AutoSize -FreezeTopRow -PassThru

            $ws = $excel.Workbook.Worksheets["Summary"]
            $lastRow = $ws.Dimension.End.Row
            $lastCol = $ws.Dimension.End.Column

            $headerRange = $ws.Cells["A1:$([char](64 + $lastCol))1"]
            $headerRange.Style.Font.Bold = $true
            $headerRange.Style.Font.Color.SetColor([System.Drawing.Color]::White)
            $headerRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
            $headerRange.Style.Fill.BackgroundColor.SetColor($headerBlue)
            $headerRange.Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center

            for ($row = 2; $row -le $lastRow; $row++) {
                if ($row % 2 -eq 0) {
                    $rowRange = $ws.Cells["A$row`:$([char](64 + $lastCol))$row"]
                    $rowRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                    $rowRange.Style.Fill.BackgroundColor.SetColor($lightGray)
                }
            }

            for ($col = 4; $col -le $lastCol; $col++) {
                $colLetter = [char](64 + $col)
                $statusRange = "$colLetter`2:$colLetter$lastRow"

                # OK status - Green
                Add-ConditionalFormatting -Worksheet $ws -Range $statusRange -RuleType ContainsText -ConditionValue "OK (" -BackgroundColor $greenFill -ForegroundColor $greenText

                # LIMITED status - Yellow/Orange
                Add-ConditionalFormatting -Worksheet $ws -Range $statusRange -RuleType ContainsText -ConditionValue "LIMITED" -BackgroundColor $yellowFill -ForegroundColor $yellowText

                # CAPACITY-CONSTRAINED - Light orange
                Add-ConditionalFormatting -Worksheet $ws -Range $statusRange -RuleType ContainsText -ConditionValue "CAPACITY" -BackgroundColor $yellowFill -ForegroundColor $yellowText

                # N/A - Gray
                Add-ConditionalFormatting -Worksheet $ws -Range $statusRange -RuleType Equal -ConditionValue "N/A" -BackgroundColor $lightGray -ForegroundColor ([System.Drawing.Color]::Gray)
            }

            $dataRange = $ws.Cells["A1:$([char](64 + $lastCol))$lastRow"]
            $dataRange.Style.Border.Top.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Bottom.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Left.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Right.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin

            $ws.Cells["B2:C$lastRow"].Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center

            #region Add Compact Legend to Summary Sheet
            $legendStartRow = $lastRow + 3  # Leave 2 blank rows

            # Legend title - Capacity Status
            $ws.Cells["A$legendStartRow"].Value = "CAPACITY STATUS"
            $ws.Cells["A$legendStartRow`:C$legendStartRow"].Merge = $true
            $ws.Cells["A$legendStartRow"].Style.Font.Bold = $true
            $ws.Cells["A$legendStartRow"].Style.Font.Size = 11
            $ws.Cells["A$legendStartRow"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
            $ws.Cells["A$legendStartRow"].Style.Fill.BackgroundColor.SetColor($headerBlue)
            $ws.Cells["A$legendStartRow"].Style.Font.Color.SetColor([System.Drawing.Color]::White)

            # Status codes table
            $statusItems = @(
                @{ Status = "OK"; Desc = "Ready to deploy. No restrictions." }
                @{ Status = "LIMITED"; Desc = "Your subscription can't use this. Request access via support ticket." }
                @{ Status = "CAPACITY-CONSTRAINED"; Desc = "Azure is low on hardware. Try a different zone or wait." }
                @{ Status = "PARTIAL"; Desc = "Some zones work, others are blocked. No zone redundancy." }
                @{ Status = "RESTRICTED"; Desc = "Cannot deploy. Pick a different region or SKU." }
            )

            $currentRow = $legendStartRow + 1
            foreach ($item in $statusItems) {
                $ws.Cells["A$currentRow"].Value = $item.Status
                $ws.Cells["B$currentRow`:C$currentRow"].Merge = $true
                $ws.Cells["B$currentRow"].Value = $item.Desc
                $ws.Cells["A$currentRow"].Style.Font.Bold = $true
                $ws.Cells["A$currentRow"].Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center

                # Apply matching colors to status cell
                $ws.Cells["A$currentRow"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                switch ($item.Status) {
                    "OK" {
                        $ws.Cells["A$currentRow"].Style.Fill.BackgroundColor.SetColor($greenFill)
                        $ws.Cells["A$currentRow"].Style.Font.Color.SetColor($greenText)
                    }
                    { $_ -in "LIMITED", "CAPACITY-CONSTRAINED", "PARTIAL" } {
                        $ws.Cells["A$currentRow"].Style.Fill.BackgroundColor.SetColor($yellowFill)
                        $ws.Cells["A$currentRow"].Style.Font.Color.SetColor($yellowText)
                    }
                    "RESTRICTED" {
                        $ws.Cells["A$currentRow"].Style.Fill.BackgroundColor.SetColor($redFill)
                        $ws.Cells["A$currentRow"].Style.Font.Color.SetColor($redText)
                    }
                }

                $ws.Cells["A$currentRow`:C$currentRow"].Style.Border.Top.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
                $ws.Cells["A$currentRow`:C$currentRow"].Style.Border.Bottom.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
                $ws.Cells["A$currentRow`:C$currentRow"].Style.Border.Left.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
                $ws.Cells["A$currentRow`:C$currentRow"].Style.Border.Right.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin

                $currentRow++
            }

            # Image Compatibility section (if image checking was used)
            $currentRow += 2  # Skip a row
            $ws.Cells["A$currentRow"].Value = "IMAGE COMPATIBILITY (Img Column)"
            $ws.Cells["A$currentRow`:C$currentRow"].Merge = $true
            $ws.Cells["A$currentRow"].Style.Font.Bold = $true
            $ws.Cells["A$currentRow"].Style.Font.Size = 11
            $ws.Cells["A$currentRow"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
            $ws.Cells["A$currentRow"].Style.Fill.BackgroundColor.SetColor($headerBlue)
            $ws.Cells["A$currentRow"].Style.Font.Color.SetColor([System.Drawing.Color]::White)

            $imgItems = @(
                @{ Symbol = "✓"; Desc = "SKU is compatible with selected image (Gen & Arch match)" }
                @{ Symbol = "✗"; Desc = "SKU is NOT compatible (wrong generation or architecture)" }
                @{ Symbol = "[-]"; Desc = "Unable to determine compatibility" }
            )

            $currentRow++
            foreach ($item in $imgItems) {
                $ws.Cells["A$currentRow"].Value = $item.Symbol
                $ws.Cells["B$currentRow`:C$currentRow"].Merge = $true
                $ws.Cells["B$currentRow"].Value = $item.Desc
                $ws.Cells["A$currentRow"].Style.Font.Bold = $true
                $ws.Cells["A$currentRow"].Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center
                $ws.Cells["A$currentRow"].Style.Font.Size = 12

                $ws.Cells["A$currentRow"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                switch ($item.Symbol) {
                    "✓" {
                        $ws.Cells["A$currentRow"].Style.Fill.BackgroundColor.SetColor($greenFill)
                        $ws.Cells["A$currentRow"].Style.Font.Color.SetColor($greenText)
                    }
                    "✗" {
                        $ws.Cells["A$currentRow"].Style.Fill.BackgroundColor.SetColor($redFill)
                        $ws.Cells["A$currentRow"].Style.Font.Color.SetColor($redText)
                    }
                    "[-]" {
                        $ws.Cells["A$currentRow"].Style.Fill.BackgroundColor.SetColor($lightGray)
                        $ws.Cells["A$currentRow"].Style.Font.Color.SetColor([System.Drawing.Color]::Gray)
                    }
                }

                $ws.Cells["A$currentRow`:C$currentRow"].Style.Border.Top.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
                $ws.Cells["A$currentRow`:C$currentRow"].Style.Border.Bottom.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
                $ws.Cells["A$currentRow`:C$currentRow"].Style.Border.Left.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
                $ws.Cells["A$currentRow`:C$currentRow"].Style.Border.Right.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin

                $currentRow++
            }

            $currentRow += 2
            $ws.Cells["A$currentRow"].Value = "FORMAT:"
            $ws.Cells["A$currentRow"].Style.Font.Bold = $true
            $ws.Cells["B$currentRow"].Value = "STATUS (X/Y) = X SKUs available out of Y total"
            $currentRow++
            $ws.Cells["A$currentRow`:C$currentRow"].Merge = $true
            $ws.Cells["A$currentRow"].Value = "See 'Legend' tab for detailed column descriptions"
            $ws.Cells["A$currentRow"].Style.Font.Italic = $true
            $ws.Cells["A$currentRow"].Style.Font.Color.SetColor([System.Drawing.Color]::Gray)

            $ws.Column(1).Width = 22
            $ws.Column(2).Width = 35
            $ws.Column(3).Width = 25

            Close-ExcelPackage $excel

            #region Details Sheet
            $excel = $familyDetails | Export-Excel -Path $xlsxFile -WorksheetName "Details" -AutoSize -FreezeTopRow -Append -PassThru

            $ws = $excel.Workbook.Worksheets["Details"]
            $lastRow = $ws.Dimension.End.Row
            $lastCol = $ws.Dimension.End.Column

            $headerRange = $ws.Cells["A1:$([char](64 + $lastCol))1"]
            $headerRange.Style.Font.Bold = $true
            $headerRange.Style.Font.Color.SetColor([System.Drawing.Color]::White)
            $headerRange.Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
            $headerRange.Style.Fill.BackgroundColor.SetColor($headerBlue)
            $headerRange.Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center

            $capacityCol = $null
            for ($c = 1; $c -le $lastCol; $c++) {
                if ($ws.Cells[1, $c].Value -eq "Capacity") {
                    $capacityCol = $c
                    break
                }
            }

            if ($capacityCol) {
                $colLetter = [char](64 + $capacityCol)
                $capacityRange = "$colLetter`2:$colLetter$lastRow"

                # OK - Green
                Add-ConditionalFormatting -Worksheet $ws -Range $capacityRange -RuleType Equal -ConditionValue "OK" -BackgroundColor $greenFill -ForegroundColor $greenText

                # LIMITED - Yellow
                Add-ConditionalFormatting -Worksheet $ws -Range $capacityRange -RuleType Equal -ConditionValue "LIMITED" -BackgroundColor $yellowFill -ForegroundColor $yellowText

                # CAPACITY-CONSTRAINED - Light orange
                Add-ConditionalFormatting -Worksheet $ws -Range $capacityRange -RuleType ContainsText -ConditionValue "CAPACITY" -BackgroundColor $yellowFill -ForegroundColor $yellowText

                # PARTIAL - Yellow (mixed zone availability)
                Add-ConditionalFormatting -Worksheet $ws -Range $capacityRange -RuleType Equal -ConditionValue "PARTIAL" -BackgroundColor $yellowFill -ForegroundColor $yellowText

                # RESTRICTED - Red
                Add-ConditionalFormatting -Worksheet $ws -Range $capacityRange -RuleType Equal -ConditionValue "RESTRICTED" -BackgroundColor $redFill -ForegroundColor $redText
            }

            $dataRange = $ws.Cells["A1:$([char](64 + $lastCol))$lastRow"]
            $dataRange.Style.Border.Top.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Bottom.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Left.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $dataRange.Style.Border.Right.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin

            $ws.Cells["E2:F$lastRow"].Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center
            $ws.Cells["J2:J$lastRow"].Style.HorizontalAlignment = [OfficeOpenXml.Style.ExcelHorizontalAlignment]::Center

            $ws.Cells["A1:$([char](64 + $lastCol))1"].AutoFilter = $true

            Close-ExcelPackage $excel

            #region Legend Sheet
            $legendData = @(
                [PSCustomObject]@{ Category = "STATUS FORMAT"; Item = "STATUS (X/Y)"; Description = "X = SKUs with full availability, Y = Total SKUs in family for that region" }
                [PSCustomObject]@{ Category = "STATUS FORMAT"; Item = "Example: OK (5/8)"; Description = "5 out of 8 SKUs are fully available with OK status" }
                [PSCustomObject]@{ Category = ""; Item = ""; Description = "" }
                [PSCustomObject]@{ Category = "CAPACITY STATUS"; Item = "OK"; Description = "Ready to deploy. No restrictions." }
                [PSCustomObject]@{ Category = "CAPACITY STATUS"; Item = "LIMITED"; Description = "Your subscription can't use this. Request access via support ticket." }
                [PSCustomObject]@{ Category = "CAPACITY STATUS"; Item = "CAPACITY-CONSTRAINED"; Description = "Azure is low on hardware. Try a different zone or wait." }
                [PSCustomObject]@{ Category = "CAPACITY STATUS"; Item = "PARTIAL"; Description = "Some zones work, others are blocked. No zone redundancy." }
                [PSCustomObject]@{ Category = "CAPACITY STATUS"; Item = "RESTRICTED"; Description = "Cannot deploy. Pick a different region or SKU." }
                [PSCustomObject]@{ Category = "CAPACITY STATUS"; Item = "N/A"; Description = "SKU family not available in this region." }
                [PSCustomObject]@{ Category = ""; Item = ""; Description = "" }
                [PSCustomObject]@{ Category = "SUMMARY COLUMNS"; Item = "Family"; Description = "VM family identifier (e.g., Dv5, Ev5, Mv2)" }
                [PSCustomObject]@{ Category = "SUMMARY COLUMNS"; Item = "Total_SKUs"; Description = "Total number of SKUs scanned across all regions" }
                [PSCustomObject]@{ Category = "SUMMARY COLUMNS"; Item = "SKUs_OK"; Description = "Number of SKUs with full availability (OK status)" }
                [PSCustomObject]@{ Category = "SUMMARY COLUMNS"; Item = "<Region>_Status"; Description = "Capacity status for that region with (Available/Total) count" }
                [PSCustomObject]@{ Category = ""; Item = ""; Description = "" }
                [PSCustomObject]@{ Category = "DETAILS COLUMNS"; Item = "Family"; Description = "VM family identifier" }
                [PSCustomObject]@{ Category = "DETAILS COLUMNS"; Item = "SKU"; Description = "Full SKU name (e.g., Standard_D2s_v5)" }
                [PSCustomObject]@{ Category = "DETAILS COLUMNS"; Item = "Region"; Description = "Azure region code" }
                [PSCustomObject]@{ Category = "DETAILS COLUMNS"; Item = "vCPU"; Description = "Number of virtual CPUs" }
                [PSCustomObject]@{ Category = "DETAILS COLUMNS"; Item = "MemGiB"; Description = "Memory in GiB" }
                [PSCustomObject]@{ Category = "DETAILS COLUMNS"; Item = "Zones"; Description = "Availability zones where SKU is available" }
                [PSCustomObject]@{ Category = "DETAILS COLUMNS"; Item = "Capacity"; Description = "Current capacity status" }
                [PSCustomObject]@{ Category = "DETAILS COLUMNS"; Item = "Restrictions"; Description = "Any restrictions or capacity messages" }
                [PSCustomObject]@{ Category = "DETAILS COLUMNS"; Item = "QuotaAvail"; Description = "Available vCPU quota for this family (Limit - Current Usage)" }
                [PSCustomObject]@{ Category = ""; Item = ""; Description = "" }
                [PSCustomObject]@{ Category = "COLOR CODING"; Item = "Green"; Description = "Ready to deploy. No restrictions." }
                [PSCustomObject]@{ Category = "COLOR CODING"; Item = "Yellow/Orange"; Description = "Constrained. Check status for what to do next." }
                [PSCustomObject]@{ Category = "COLOR CODING"; Item = "Red"; Description = "Cannot deploy. Pick a different region or SKU." }
                [PSCustomObject]@{ Category = "COLOR CODING"; Item = "Gray"; Description = "Not available in this region." }
            )

            $excel = $legendData | Export-Excel -Path $xlsxFile -WorksheetName "Legend" -AutoSize -Append -PassThru

            $ws = $excel.Workbook.Worksheets["Legend"]
            $legendLastRow = $ws.Dimension.End.Row

            $ws.Cells["A1:C1"].Style.Font.Bold = $true
            $ws.Cells["A1:C1"].Style.Font.Color.SetColor([System.Drawing.Color]::White)
            $ws.Cells["A1:C1"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
            $ws.Cells["A1:C1"].Style.Fill.BackgroundColor.SetColor($headerBlue)

            $ws.Cells["A2:A$legendLastRow"].Style.Font.Bold = $true

            $ws.Cells["A1:C$legendLastRow"].Style.Border.Top.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $ws.Cells["A1:C$legendLastRow"].Style.Border.Bottom.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $ws.Cells["A1:C$legendLastRow"].Style.Border.Left.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin
            $ws.Cells["A1:C$legendLastRow"].Style.Border.Right.Style = [OfficeOpenXml.Style.ExcelBorderStyle]::Thin

            # Apply colors to color coding rows
            for ($row = 2; $row -le $legendLastRow; $row++) {
                $itemValue = $ws.Cells["B$row"].Value
                if ($itemValue -eq "Green") {
                    $ws.Cells["B$row"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                    $ws.Cells["B$row"].Style.Fill.BackgroundColor.SetColor($greenFill)
                    $ws.Cells["B$row"].Style.Font.Color.SetColor($greenText)
                }
                elseif ($itemValue -eq "Yellow/Orange") {
                    $ws.Cells["B$row"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                    $ws.Cells["B$row"].Style.Fill.BackgroundColor.SetColor($yellowFill)
                    $ws.Cells["B$row"].Style.Font.Color.SetColor($yellowText)
                }
                elseif ($itemValue -eq "Red") {
                    $ws.Cells["B$row"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                    $ws.Cells["B$row"].Style.Fill.BackgroundColor.SetColor($redFill)
                    $ws.Cells["B$row"].Style.Font.Color.SetColor($redText)
                }
                elseif ($itemValue -eq "Gray") {
                    $ws.Cells["B$row"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                    $ws.Cells["B$row"].Style.Fill.BackgroundColor.SetColor($lightGray)
                    $ws.Cells["B$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Gray)
                }
                # Style status values in Legend
                elseif ($itemValue -eq "OK") {
                    $ws.Cells["B$row"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                    $ws.Cells["B$row"].Style.Fill.BackgroundColor.SetColor($greenFill)
                    $ws.Cells["B$row"].Style.Font.Color.SetColor($greenText)
                }
                elseif ($itemValue -eq "LIMITED" -or $itemValue -eq "CAPACITY-CONSTRAINED" -or $itemValue -eq "PARTIAL") {
                    $ws.Cells["B$row"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                    $ws.Cells["B$row"].Style.Fill.BackgroundColor.SetColor($yellowFill)
                    $ws.Cells["B$row"].Style.Font.Color.SetColor($yellowText)
                }
                elseif ($itemValue -eq "RESTRICTED") {
                    $ws.Cells["B$row"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                    $ws.Cells["B$row"].Style.Fill.BackgroundColor.SetColor($redFill)
                    $ws.Cells["B$row"].Style.Font.Color.SetColor($redText)
                }
                elseif ($itemValue -eq "N/A") {
                    $ws.Cells["B$row"].Style.Fill.PatternType = [OfficeOpenXml.Style.ExcelFillStyle]::Solid
                    $ws.Cells["B$row"].Style.Fill.BackgroundColor.SetColor($lightGray)
                    $ws.Cells["B$row"].Style.Font.Color.SetColor([System.Drawing.Color]::Gray)
                }
            }

            $ws.Column(1).Width = 20
            $ws.Column(2).Width = 25
            $ws.Column(3).Width = $ExcelDescriptionColumnWidth

            Close-ExcelPackage $excel

            Write-Host "  $($Icons.Check) XLSX: $xlsxFile" -ForegroundColor Green
            Write-Host "    - Summary sheet with color-coded status" -ForegroundColor DarkGray
            Write-Host "    - Details sheet with filters and conditional formatting" -ForegroundColor DarkGray
            Write-Host "    - Legend sheet explaining status codes and format" -ForegroundColor DarkGray
        }
        catch {
            Write-Host "  $($Icons.Warning) XLSX formatting failed: $($_.Exception.Message)" -ForegroundColor Yellow
            Write-Host "  $($Icons.Warning) Falling back to basic XLSX..." -ForegroundColor Yellow
            try {
                $summaryRowsForExport | Export-Excel -Path $xlsxFile -WorksheetName "Summary" -AutoSize -FreezeTopRow
                $familyDetails | Export-Excel -Path $xlsxFile -WorksheetName "Details" -AutoSize -FreezeTopRow -Append
                Write-Host "  $($Icons.Check) XLSX (basic): $xlsxFile" -ForegroundColor Green
            }
            catch {
                Write-Host "  $($Icons.Warning) XLSX failed, falling back to CSV" -ForegroundColor Yellow
                $useXLSX = $false
            }
        }
    }

    if (-not $useXLSX) {
        $summaryFile = Join-Path $ExportPath "AzVMAvailability-Summary-$timestamp.csv"
        $detailFile = Join-Path $ExportPath "AzVMAvailability-Details-$timestamp.csv"

        $summaryRowsForExport | Export-Csv -Path $summaryFile -NoTypeInformation -Encoding UTF8
        $familyDetails | Export-Csv -Path $detailFile -NoTypeInformation -Encoding UTF8

        Write-Host "  $($Icons.Check) Summary: $summaryFile" -ForegroundColor Green
        Write-Host "  $($Icons.Check) Details: $detailFile" -ForegroundColor Green
    }

    Write-Host "`nExport complete!" -ForegroundColor Green

    # Prompt to open Excel file
    if ($useXLSX -and (Test-Path $xlsxFile)) {
        if (-not $NoPrompt) {
            Write-Host ""
            $openExcel = Read-Host "Open Excel file now? (Y/n)"
            if ($openExcel -eq '' -or $openExcel -match '^[Yy]') {
                Write-Host "Opening $xlsxFile..." -ForegroundColor Cyan
                Start-Process $xlsxFile
            }
        }
    }
}
#endregion Export
}
finally {
    [void](Restore-OriginalSubscriptionContext -OriginalSubscriptionId $initialSubscriptionId)
}
