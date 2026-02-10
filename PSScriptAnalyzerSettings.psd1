# PSScriptAnalyzer configuration for Get-AzVMAvailability
# https://github.com/PowerShell/PSScriptAnalyzer
#
# This file is used by both local VS Code linting (on-save) and CI (GitHub Actions).
# Keep them in sync — if you exclude a rule here, exclude it in CI too.

@{
    Severity     = @('Error', 'Warning')

    ExcludeRules = @(
        # This is a console tool — Write-Host is intentional for color-coded output
        'PSAvoidUsingWriteHost'

        # Function names like Get-AzureEndpoints, Get-RestrictionDetails return
        # collections — plural nouns are intentional and match Azure cmdlet conventions
        'PSUseSingularNouns'

        # CompactOutput and SkuNames parameters are declared for future features
        # and internal function signatures — suppressing until implemented
        'PSReviewUnusedParameter'
    )

    Rules        = @{
        PSUseCompatibleSyntax = @{
            Enable         = $true
            TargetVersions = @('7.0')
        }
    }
}
