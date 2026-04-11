Describe 'Get-AzVMAvailability Parameter Parity' {

    BeforeAll {
        Remove-Module AzVMAvailability -ErrorAction SilentlyContinue
        $modulePath = Join-Path $PSScriptRoot '..' 'AzVMAvailability'
        Import-Module $modulePath -Force -DisableNameChecking -ErrorAction Stop
        # Get-Command returns FunctionInfo; copy Parameters to a regular hashtable
        # so Pester v5 scope serialization does not lose them.
        $cmdObj = Get-Command Get-AzVMAvailability -CommandType Function -Module AzVMAvailability -ErrorAction Stop
        $script:params = @{}
        foreach ($kvp in $cmdObj.Parameters.GetEnumerator()) {
            $script:params[$kvp.Key] = $kvp.Value
        }
    }

    AfterAll {
        Remove-Module AzVMAvailability -ErrorAction SilentlyContinue
    }

    Context 'All expected parameters exist' {

        $testCases = @(
            'SubscriptionId', 'Region', 'RegionPreset', 'ExportPath', 'AutoExport',
            'EnableDrillDown', 'FamilyFilter', 'SkuFilter', 'ShowPricing', 'ShowSpot',
            'ShowPlacement', 'DesiredCount', 'ImageURN', 'CompactOutput', 'NoPrompt',
            'NoQuota', 'OutputFormat', 'UseAsciiIcons', 'Environment', 'MaxRetries',
            'Recommend', 'TopN', 'MinScore', 'MinvCPU', 'MinMemoryGB', 'JsonOutput',
            'AllowMixedArch', 'SkipRegionValidation', 'Inventory', 'InventoryFile',
            'GenerateInventoryTemplate', 'RateOptimization', 'LifecycleRecommendations',
            'LifecycleScan', 'ManagementGroup', 'ResourceGroup', 'Tag', 'SubMap', 'RGMap'
        ) | ForEach-Object { @{ Name = $_ } }

        It 'Has parameter: <Name>' -TestCases $testCases {
            param($Name)
            $script:params[$Name] | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Parameter types are correct' {

        $typeCases = @(
            @{ Name = 'SubscriptionId';           ExpectedType = 'System.String[]' }
            @{ Name = 'Region';                   ExpectedType = 'System.String[]' }
            @{ Name = 'RegionPreset';              ExpectedType = 'System.String' }
            @{ Name = 'ExportPath';                ExpectedType = 'System.String' }
            @{ Name = 'AutoExport';                ExpectedType = 'System.Management.Automation.SwitchParameter' }
            @{ Name = 'EnableDrillDown';           ExpectedType = 'System.Management.Automation.SwitchParameter' }
            @{ Name = 'FamilyFilter';              ExpectedType = 'System.String[]' }
            @{ Name = 'SkuFilter';                 ExpectedType = 'System.String[]' }
            @{ Name = 'ShowPricing';               ExpectedType = 'System.Management.Automation.SwitchParameter' }
            @{ Name = 'ShowSpot';                  ExpectedType = 'System.Management.Automation.SwitchParameter' }
            @{ Name = 'ShowPlacement';             ExpectedType = 'System.Management.Automation.SwitchParameter' }
            @{ Name = 'DesiredCount';              ExpectedType = 'System.Int32' }
            @{ Name = 'ImageURN';                  ExpectedType = 'System.String' }
            @{ Name = 'CompactOutput';             ExpectedType = 'System.Management.Automation.SwitchParameter' }
            @{ Name = 'NoPrompt';                  ExpectedType = 'System.Management.Automation.SwitchParameter' }
            @{ Name = 'NoQuota';                   ExpectedType = 'System.Management.Automation.SwitchParameter' }
            @{ Name = 'OutputFormat';              ExpectedType = 'System.String' }
            @{ Name = 'UseAsciiIcons';             ExpectedType = 'System.Management.Automation.SwitchParameter' }
            @{ Name = 'Environment';               ExpectedType = 'System.String' }
            @{ Name = 'MaxRetries';                ExpectedType = 'System.Int32' }
            @{ Name = 'Recommend';                 ExpectedType = 'System.String' }
            @{ Name = 'TopN';                      ExpectedType = 'System.Int32' }
            @{ Name = 'MinScore';                  ExpectedType = 'System.Int32' }
            @{ Name = 'MinvCPU';                   ExpectedType = 'System.Int32' }
            @{ Name = 'MinMemoryGB';               ExpectedType = 'System.Int32' }
            @{ Name = 'JsonOutput';                ExpectedType = 'System.Management.Automation.SwitchParameter' }
            @{ Name = 'AllowMixedArch';            ExpectedType = 'System.Management.Automation.SwitchParameter' }
            @{ Name = 'SkipRegionValidation';      ExpectedType = 'System.Management.Automation.SwitchParameter' }
            @{ Name = 'Inventory';                 ExpectedType = 'System.Collections.Hashtable' }
            @{ Name = 'InventoryFile';             ExpectedType = 'System.String' }
            @{ Name = 'GenerateInventoryTemplate'; ExpectedType = 'System.Management.Automation.SwitchParameter' }
            @{ Name = 'RateOptimization';          ExpectedType = 'System.Management.Automation.SwitchParameter' }
            @{ Name = 'LifecycleRecommendations';  ExpectedType = 'System.String' }
            @{ Name = 'LifecycleScan';             ExpectedType = 'System.Management.Automation.SwitchParameter' }
            @{ Name = 'ManagementGroup';           ExpectedType = 'System.String[]' }
            @{ Name = 'ResourceGroup';             ExpectedType = 'System.String[]' }
            @{ Name = 'Tag';                       ExpectedType = 'System.Collections.Hashtable' }
            @{ Name = 'SubMap';                    ExpectedType = 'System.Management.Automation.SwitchParameter' }
            @{ Name = 'RGMap';                     ExpectedType = 'System.Management.Automation.SwitchParameter' }
        )

        It 'Parameter <Name> has type <ExpectedType>' -TestCases $typeCases {
            param($Name, $ExpectedType)
            $script:params[$Name].ParameterType.FullName | Should -Be $ExpectedType
        }
    }

    Context 'Parameter aliases are preserved' {

        It 'SubscriptionId has aliases SubId and Subscription' {
            $aliases = $script:params['SubscriptionId'].Aliases
            $aliases | Should -Contain 'SubId'
            $aliases | Should -Contain 'Subscription'
        }

        It 'Region has alias Location' {
            $script:params['Region'].Aliases | Should -Contain 'Location'
        }

        It 'Inventory has alias Fleet' {
            $script:params['Inventory'].Aliases | Should -Contain 'Fleet'
        }

        It 'InventoryFile has alias FleetFile' {
            $script:params['InventoryFile'].Aliases | Should -Contain 'FleetFile'
        }

        It 'GenerateInventoryTemplate has alias GenerateFleetTemplate' {
            $script:params['GenerateInventoryTemplate'].Aliases | Should -Contain 'GenerateFleetTemplate'
        }

        It 'Tag has alias Tags' {
            $script:params['Tag'].Aliases | Should -Contain 'Tags'
        }
    }

    Context 'Default values are preserved (via AST)' {
        # ParameterMetadata.DefaultValue is only populated for compiled cmdlets.
        # For script functions, parse defaults from the AST instead.
        BeforeAll {
            $funcPath = Join-Path $PSScriptRoot '..' 'AzVMAvailability' 'Public' 'Get-AzVMAvailability.ps1'
            $funcAst = [System.Management.Automation.Language.Parser]::ParseFile($funcPath, [ref]$null, [ref]$null)
            $paramBlock = $funcAst.FindAll({ $args[0] -is [System.Management.Automation.Language.ParamBlockAst] }, $true) | Select-Object -First 1
            $script:paramAsts = @{}
            foreach ($p in $paramBlock.Parameters) {
                $name = $p.Name.VariablePath.UserPath
                $script:paramAsts[$name] = $p
            }
        }

        It 'TopN defaults to 5' {
            $script:paramAsts['TopN'].DefaultValue.Value | Should -Be 5
        }

        It 'MaxRetries defaults to 3' {
            $script:paramAsts['MaxRetries'].DefaultValue.Value | Should -Be 3
        }

        It 'DesiredCount defaults to 1' {
            $script:paramAsts['DesiredCount'].DefaultValue.Value | Should -Be 1
        }

        It 'OutputFormat defaults to Auto' {
            $script:paramAsts['OutputFormat'].DefaultValue.Value | Should -Be 'Auto'
        }
    }

    Context 'ValidateSet values are correct' {

        It 'RegionPreset has expected choices' {
            $attr = $script:params['RegionPreset'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $attr | Should -Not -BeNullOrEmpty
            $expected = @('USEastWest', 'USCentral', 'USMajor', 'Europe', 'AsiaPacific', 'Global', 'USGov', 'China', 'ASR-EastWest', 'ASR-CentralUS')
            foreach ($val in $expected) {
                $attr.ValidValues | Should -Contain $val
            }
        }

        It 'OutputFormat has Auto, CSV, XLSX' {
            $attr = $script:params['OutputFormat'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $attr.ValidValues | Should -Contain 'Auto'
            $attr.ValidValues | Should -Contain 'CSV'
            $attr.ValidValues | Should -Contain 'XLSX'
        }

        It 'Environment has expected cloud environments' {
            $attr = $script:params['Environment'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $attr.ValidValues | Should -Contain 'AzureCloud'
            $attr.ValidValues | Should -Contain 'AzureUSGovernment'
            $attr.ValidValues | Should -Contain 'AzureChinaCloud'
            $attr.ValidValues | Should -Contain 'AzureGermanCloud'
        }
    }

    Context 'ValidateRange values are correct' {

        It 'MaxRetries range is 0-10' {
            $attr = $script:params['MaxRetries'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $attr | Should -Not -BeNullOrEmpty
            $attr.MinRange | Should -Be 0
            $attr.MaxRange | Should -Be 10
        }

        It 'TopN range is 1-25' {
            $attr = $script:params['TopN'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $attr.MinRange | Should -Be 1
            $attr.MaxRange | Should -Be 25
        }

        It 'MinScore range is 0-100' {
            $attr = $script:params['MinScore'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $attr.MinRange | Should -Be 0
            $attr.MaxRange | Should -Be 100
        }

        It 'DesiredCount range is 1-1000' {
            $attr = $script:params['DesiredCount'].Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateRangeAttribute] }
            $attr.MinRange | Should -Be 1
            $attr.MaxRange | Should -Be 1000
        }
    }
}
