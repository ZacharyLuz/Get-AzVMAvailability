function Show-StartupBanner {
    <#
    .SYNOPSIS
    Displays the interactive startup banner with ASCII block art.
    Only called in interactive mode (not -NoPrompt, not -JsonOutput).
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '',
        Justification = 'Intentional interactive terminal output')]
    param(
        [Parameter(Mandatory)]
        [string]$Version,

        [switch]$UseAscii
    )

    if ($UseAscii) {
        # ASCII-safe fallback for terminals without Unicode block support
        Write-Host ''
        Write-Host '  +------------------------------------------+' -ForegroundColor Yellow
        Write-Host '  |  AzVMAvailability                        |' -ForegroundColor Yellow
        Write-Host '  |  Azure VM Availability Scanner           |' -ForegroundColor Yellow
        Write-Host '  +------------------------------------------+' -ForegroundColor Yellow
        Write-Host "  v$Version  |  Not an official Microsoft product" -ForegroundColor DarkGray
        Write-Host ''
        return
    }

    # Row 1: "Get-" (cyan) + "AzVM" (yellow) — combined one-line identity
    $G    = @(' ██████╗ ', '██╔════╝ ', '██║  ███╗', '██║   ██║', '╚██████╔╝', ' ╚═════╝ ')
    $E    = @('███████╗', '██╔════╝', '█████╗  ', '██╔══╝  ', '███████╗', '╚══════╝')
    $T    = @('████████╗', '╚══██╔══╝', '   ██║   ', '   ██║   ', '   ██║   ', '   ╚═╝   ')
    $dash = @('      ', '      ', ' ███╗ ', ' ╚══╝ ', '      ', '      ')
    $cyanPart = for ($i = 0; $i -lt 6; $i++) { $G[$i] + $E[$i] + $T[$i] + $dash[$i] }

    $yellowPart = @(
        ' █████╗ ███████╗██╗   ██╗███╗   ███╗'
        '██╔══██╗╚══███╔╝██║   ██║████╗ ████║'
        '███████║  ███╔╝ ╚██╗ ██╔╝██╔████╔██║'
        '██╔══██║ ███╔╝   ╚████╔╝ ██║╚██╔╝██║'
        '██║  ██║███████╗  ╚██╔╝  ██║ ╚═╝ ██║'
        '╚═╝  ╚═╝╚══════╝   ╚═╝   ╚═╝     ╚═╝'
    )

    # Row 2: "AVAILABILITY" (yellow)
    $availPart = @(
        ' █████╗ ██╗   ██╗ █████╗ ██╗██╗      █████╗ ██████╗ ██╗██╗     ██╗████████╗██╗   ██╗'
        '██╔══██╗██║   ██║██╔══██╗██║██║     ██╔══██╗██╔══██╗██║██║     ██║╚══██╔══╝╚██╗ ██╔╝'
        '███████║╚██╗ ██╔╝███████║██║██║     ███████║██████╔╝██║██║     ██║   ██║    ╚████╔╝ '
        '██╔══██║ ╚████╔╝ ██╔══██║██║██║     ██╔══██║██╔══██╗██║██║     ██║   ██║     ╚██╔╝  '
        '██║  ██║  ╚██╔╝  ██║  ██║██║███████╗██║  ██║██████╔╝██║███████╗██║   ██║      ██║   '
        '╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝╚══════╝╚═╝  ╚═╝╚═════╝ ╚═╝╚══════╝╚═╝   ╚═╝      ╚═╝  '
    )

    # Header width spans the wider of the two rows (AVAILABILITY = ~84 chars)
    $artWidth = ($availPart | ForEach-Object { $_.Length } | Measure-Object -Maximum).Maximum
    $indent = '  '

    $title       = 'Get-AzVMAvailability'
    $totalWidth  = $artWidth + $indent.Length
    $innerWidth  = $totalWidth - 6
    $dashCount   = [Math]::Max(2, $innerWidth - $title.Length - 2)
    $leftDashes  = [Math]::Floor($dashCount / 2)
    $rightDashes = $dashCount - $leftDashes
    $headerLine  = "⚡ $('─' * $leftDashes) $title $('─' * $rightDashes) ⚡"

    Write-Host ''
    Write-Host ($indent + $headerLine) -ForegroundColor Cyan
    for ($i = 0; $i -lt 6; $i++) {
        Write-Host -NoNewline ($indent + $cyanPart[$i]) -ForegroundColor Cyan
        Write-Host $yellowPart[$i] -ForegroundColor Yellow
    }
    foreach ($line in $availPart) {
        Write-Host ($indent + $line) -ForegroundColor Yellow
    }
    Write-Host ($indent + ('─' * ($artWidth + 2))) -ForegroundColor DarkGray
    Write-Host ($indent + 'Azure VM SKU Availability  ·  Capacity  ·  Pricing  ·  Lifecycle') -ForegroundColor Cyan
    Write-Host ($indent + "v$Version  ·  Personal project — not an official Microsoft product") -ForegroundColor DarkGray
    Write-Host ''
}
