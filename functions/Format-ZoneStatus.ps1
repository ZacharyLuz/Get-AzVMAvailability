# Format-ZoneStatus.ps1
# Extracted from Get-AzVMAvailability.ps1 (line 1090)
# Formats zone availability status into a compact display string
# DO NOT execute this file directly — it is a documentation reference only.
function Format-ZoneStatus {
    param([array]$OK, [array]$Limited, [array]$Restricted)
    $parts = @()
    if ($OK.Count -gt 0) { $parts += "✓ Zones $($OK -join ',')" }
    if ($Limited.Count -gt 0) { $parts += "⚠ Zones $($Limited -join ',')" }
    if ($Restricted.Count -gt 0) { $parts += "✗ Zones $($Restricted -join ',')" }
    if ($parts.Count -eq 0) { return 'Non-zonal' }  # No zone info = regional deployment
    return $parts -join ' | '
}
