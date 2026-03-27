function ConvertTo-ExcelColumnLetter {
    param([int]$ColumnNumber)
    $letter = ''
    while ($ColumnNumber -gt 0) {
        $mod = ($ColumnNumber - 1) % 26
        $letter = [char](65 + $mod) + $letter
        $ColumnNumber = [math]::Floor(($ColumnNumber - 1) / 26)
    }
    return $letter
}
