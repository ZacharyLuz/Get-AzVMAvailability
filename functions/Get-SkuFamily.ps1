# Get-SkuFamily.ps1
# Extracted from Get-AzVMAvailability.ps1 (line 882)
# Parses the VM family prefix letter(s) from a Standard_Xnn_vN SKU name
# DO NOT execute this file directly — it is a documentation reference only.
function Get-SkuFamily {
    param([string]$SkuName)
    if ($SkuName -match 'Standard_([A-Z]+)\d') {
        return $matches[1]
    }
    return 'Unknown'
}
