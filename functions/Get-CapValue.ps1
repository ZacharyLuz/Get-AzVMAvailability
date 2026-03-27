# Get-CapValue.ps1
# Extracted from Get-AzVMAvailability.ps1 (line 875)
# Extracts a named capability value from a VM SKU capabilities array
# DO NOT execute this file directly — it is a documentation reference only.
function Get-CapValue {
    param([object]$Sku, [string]$Name)
    $cap = $Sku.Capabilities | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if ($cap) { return $cap.Value }
    return $null
}
