function Get-CapValue {
    param([object]$Sku, [string]$Name)
    if ($Sku.PSObject.Properties['_CapIndex'] -and $null -ne $Sku._CapIndex) {
        return $Sku._CapIndex[$Name]
    }
    $cap = $Sku.Capabilities | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if ($cap) { return $cap.Value }
    return $null
}
