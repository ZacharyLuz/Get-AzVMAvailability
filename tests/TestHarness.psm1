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

function Import-MainScriptFunctions {
    param(
        [Parameter(Mandatory)]
        [string[]]$FunctionNames,

        [string]$ScriptPath = (Join-Path $PSScriptRoot '..\Get-AzVMAvailability.ps1')
    )

    $ast = Get-MainScriptAst -ScriptPath $ScriptPath

    foreach ($functionName in $FunctionNames) {
        $functionAst = $ast.Find(
            {
                param($node)
                $node -is [System.Management.Automation.Language.FunctionDefinitionAst] -and
                $node.Name -eq $functionName
            },
            $true
        )

        if (-not $functionAst) {
            throw "Could not find function in main script: $functionName"
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
        throw "Could not find function in main script: $FunctionName"
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
        throw "Could not find variable assignment in main script: `$${VariableName}"
    }

    return ($assignmentAst.Extent.Text -replace ('^\$' + [regex]::Escape($VariableName)), ('$' + $ScopePrefix + ':' + $VariableName))
}

Export-ModuleMember -Function Import-MainScriptFunctions, Import-MainScriptVariables, Get-MainScriptFunctionDefinition, Get-MainScriptVariableAssignment
