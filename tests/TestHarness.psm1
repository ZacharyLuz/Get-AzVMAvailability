function Get-MainScriptAst {
    param(
        [string]$ScriptPath = (Join-Path $PSScriptRoot '..\Get-AzVMAvailability.ps1')
    )

    if (-not (Test-Path $ScriptPath)) {
        throw "Main script not found: $ScriptPath"
    }

    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($ScriptPath, [ref]$tokens, [ref]$parseErrors)

    if ($parseErrors -and $parseErrors.Count -gt 0) {
        $messages = ($parseErrors | ForEach-Object { $_.Message }) -join '; '
        throw "Failed to parse main script '$ScriptPath': $messages"
    }

    return $ast
}

# Module-level cache for parsed function definitions (populated once, reused across lookups)
$script:ModuleFunctionCache = $null

function Find-FunctionInModule {
    <#
    .SYNOPSIS
        Searches the AzVMAvailability module Private/ directory for a function definition.
    .DESCRIPTION
        Parses all .ps1 files in AzVMAvailability/Private/ on first call, caches results,
        and returns cached definitions on subsequent calls. Throws on parse errors.
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'FunctionName', Justification = 'Used in cache lookup after cache-building block')]
    param(
        [Parameter(Mandatory)]
        [string]$FunctionName
    )

    # Build cache on first call
    if ($null -eq $script:ModuleFunctionCache) {
        $script:ModuleFunctionCache = @{}
        $moduleRoot = Join-Path $PSScriptRoot '..\AzVMAvailability\Private'
        if (-not (Test-Path $moduleRoot)) { return $null }

        foreach ($file in (Get-ChildItem -Path $moduleRoot -Filter '*.ps1' -Recurse -File)) {
            $tokens = $null
            $parseErrors = $null
            $fileAst = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)

            if ($parseErrors -and $parseErrors.Count -gt 0) {
                $messages = ($parseErrors | ForEach-Object { $_.Message }) -join '; '
                throw "Syntax error in module file '$($file.FullName)': $messages"
            }

            $functions = $fileAst.FindAll(
                {
                    param($node)
                    $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
                },
                $true
            )
            foreach ($funcAst in $functions) {
                $script:ModuleFunctionCache[$funcAst.Name] = $funcAst.Extent.Text
            }
        }
    }

    if ($script:ModuleFunctionCache.ContainsKey($FunctionName)) {
        return $script:ModuleFunctionCache[$FunctionName]
    }
    return $null
}

function Import-MainScriptFunctions {
    param(
        [Parameter(Mandatory)]
        [string[]]$FunctionNames,

        [string]$ScriptPath = (Join-Path $PSScriptRoot '..\Get-AzVMAvailability.ps1')
    )

    $ast = Get-MainScriptAst -ScriptPath $ScriptPath

    foreach ($functionName in $FunctionNames) {
        # Try module Private/ files first (v2.0.0+ layout)
        $moduleDefinition = Find-FunctionInModule -FunctionName $functionName
        if ($moduleDefinition) {
            $globalDefinition = $moduleDefinition -replace ("function\s+" + [regex]::Escape($functionName) + "\b"), ("function global:" + $functionName)
            . ([scriptblock]::Create($globalDefinition))
            continue
        }

        # Fallback: AST extraction from main script
        $functionAst = $ast.Find(
            {
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                $node.Name -eq $functionName
            },
            $true
        )

        if (-not $functionAst) {
            throw "Could not find function '$functionName' in module or main script"
        }

        $definition = $functionAst.Extent.Text
        $globalDefinition = $definition -replace ("function\s+" + [regex]::Escape($functionName) + "\b"), ("function global:" + $functionName)
        . ([scriptblock]::Create($globalDefinition))
    }
}

function Get-MainScriptFunctionDefinition {
    param(
        [Parameter(Mandatory)]
        [string]$FunctionName,

        [string]$ScriptPath = (Join-Path $PSScriptRoot '..\Get-AzVMAvailability.ps1')
    )

    # Try module Private/ files first (v2.0.0+ layout)
    $moduleDefinition = Find-FunctionInModule -FunctionName $FunctionName
    if ($moduleDefinition) {
        return $moduleDefinition
    }

    # Fallback: AST extraction from main script
    $ast = Get-MainScriptAst -ScriptPath $ScriptPath
    $functionAst = $ast.Find(
        {
            param($node)
            $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
            $node.Name -eq $FunctionName
        },
        $true
    )

    if (-not $functionAst) {
        throw "Could not find function '$FunctionName' in module or main script"
    }

    return $functionAst.Extent.Text
}

function Import-MainScriptVariables {
    param(
        [Parameter(Mandatory)]
        [string[]]$VariableNames,

        [string]$ScriptPath = (Join-Path $PSScriptRoot '..\Get-AzVMAvailability.ps1')
    )

    $ast = Get-MainScriptAst -ScriptPath $ScriptPath

    foreach ($variableName in $VariableNames) {
        $assignmentAst = $ast.Find(
            {
                param($node)
                $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                $node.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
                $node.Left.VariablePath.UserPath -eq $variableName
            },
            $true
        )

        if (-not $assignmentAst) {
            throw "Could not find variable assignment in main script: `$${variableName}"
        }

        $assignmentCode = $assignmentAst.Extent.Text -replace ('^\$' + [regex]::Escape($variableName)), ('$global:' + $variableName)
        . ([scriptblock]::Create($assignmentCode))
    }
}

function Get-MainScriptVariableAssignment {
    param(
        [Parameter(Mandatory)]
        [string]$VariableName,

        [ValidateSet('script', 'global')]
        [string]$ScopePrefix = 'script',

        [string]$ScriptPath = (Join-Path $PSScriptRoot '..\Get-AzVMAvailability.ps1')
    )

    $ast = Get-MainScriptAst -ScriptPath $ScriptPath
    $assignmentAst = $ast.Find(
        {
            param($node)
            $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
            $node.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
            $node.Left.VariablePath.UserPath -eq $VariableName
        },
        $true
    )

    if (-not $assignmentAst) {
        # Fallback: search the Public function file (v2.0.0 module layout)
        $publicPath = Join-Path $PSScriptRoot '..' 'AzVMAvailability' 'Public' 'Get-AzVMAvailability.ps1'
        if (Test-Path $publicPath) {
            $publicAst = [System.Management.Automation.Language.Parser]::ParseFile($publicPath, [ref]$null, [ref]$null)
            $assignmentAst = $publicAst.Find(
                {
                    param($node)
                    $node -is [System.Management.Automation.Language.AssignmentStatementAst] -and
                    $node.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and
                    $node.Left.VariablePath.UserPath -eq $VariableName
                },
                $true
            )
        }
    }
    if (-not $assignmentAst) {
        throw "Could not find variable assignment in main script or AzVMAvailability/Public/Get-AzVMAvailability.ps1: `$${VariableName}"
    }

    return ($assignmentAst.Extent.Text -replace ('^\$' + [regex]::Escape($VariableName)), ('$' + $ScopePrefix + ':' + $VariableName))
}

Export-ModuleMember -Function Import-MainScriptFunctions, Import-MainScriptVariables, Get-MainScriptFunctionDefinition, Get-MainScriptVariableAssignment, Find-FunctionInModule
