function Format-RegionList {
    param(
        [Parameter(Mandatory = $false)]
        [object]$Regions,
        [int]$MaxWidth = 75
    )

    if ($null -eq $Regions) {
        return , @('(none)')
    }

    $regionArray = @($Regions)

    if ($regionArray.Count -eq 0) {
        return , @('(none)')
    }

    $lines = [System.Collections.Generic.List[string]]::new()
    $currentLine = ""

    foreach ($region in $regionArray) {
        $regionStr = [string]$region
        $separator = if ($currentLine) { ', ' } else { '' }
        $testLine = $currentLine + $separator + $regionStr

        if ($testLine.Length -gt $MaxWidth -and $currentLine) {
            $lines.Add($currentLine)
            $currentLine = $regionStr
        }
        else {
            $currentLine = $testLine
        }
    }

    if ($currentLine) {
        $lines.Add($currentLine)
    }

    return , @($lines.ToArray())
}
