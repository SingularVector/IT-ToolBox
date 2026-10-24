BeforeAll {
    $manifestPath = Join-Path $PSScriptRoot '../IT-ToolBox.psd1'
    $module = Import-Module $manifestPath -Force -PassThru -ErrorAction Stop
}

Describe 'IT-ToolBox module boundary' {
    It 'has a valid manifest' {
        $manifest = Test-ModuleManifest $manifestPath -ErrorAction Stop
        $manifest.Version | Should -Be ([version]'3.2.0')
    }

    It 'exports exactly the supported commands' {
        $expected = @('New-LogEntry', 'New-Timer', 'Get-TimerStatus', 'Stop-Timer', 'Get-ElapsedTime', 'Get-ScriptDirectory', 'Get-ScriptName', 'Test-FileName', 'Test-IsValidPath', 'Test-IsIP', 'Test-IsGuid', 'Test-IsDate', 'Test-IsEmail', 'Test-IsUrl', 'Convert-LogonTimestamp', 'Get-OsUpTime', 'Remove-SpecialCharacters', 'Test-IsRegistryKey', 'Test-RegistryValue', 'Test-IsValidDn', 'Test-IsValidUpn', 'Get-ReportChain', 'New-StringEncryption', 'New-StringDecryption', 'New-RandomString', 'New-RandomPassword', 'New-PhoneticPassword', 'New-ApiRequest', 'New-StringConversion', 'Get-StringCheckSum', 'Get-StringHashCode') | Sort-Object
        $actual = @($module.ExportedFunctions.Keys | Sort-Object)
        ($actual -join ',') | Should -Be ($expected -join ',')
        $module.ExportedVariables.Count | Should -Be 0
        $module.ExportedAliases.Count | Should -Be 0
        $module.ExportedCmdlets.Count | Should -Be 0
    }

    It 'keeps logging helpers private' {
        Get-Command Open-ITToolBoxRegistryKey -Module IT-ToolBox -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command Get-NewLogEntryMutexName -Module IT-ToolBox -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command Test-ITToolBoxDnsName -Module IT-ToolBox -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
        Get-Command Initialize-NewLogEntryState -Module IT-ToolBox -ErrorAction SilentlyContinue | Should -BeNullOrEmpty
    }

    It 'has no mandatory external dependencies' {
        $data = Import-PowerShellDataFile $manifestPath
        @($data.RequiredAssemblies).Where({ $null -ne $_ }).Count | Should -Be 0
        @($data.RequiredModules).Where({ $null -ne $_ }).Count | Should -Be 0
    }
}

Describe 'Timers' {
    It 'starts, measures and stops a timer' {
        $timer = New-Timer
        $timer | Should -BeOfType ([System.Diagnostics.Stopwatch])
        Get-TimerStatus -Timer $timer | Should -BeTrue
        Get-ElapsedTime -ElapsedTime $timer | Should -BeOfType ([timespan])
        Get-ElapsedTime -ElapsedTime $timer -Seconds | Should -BeOfType ([int])
        Get-ElapsedTime -ElapsedTime $timer -TotalMilliseconds | Should -BeGreaterOrEqual 0
        Stop-Timer -Timer $timer | Should -BeTrue
        Get-TimerStatus -Timer $timer | Should -BeFalse
    }
}


Describe 'Elapsed-time input validation' {
    It 'requires a non-null stopwatch in every parameter set' {
        $command = Get-Command Get-ElapsedTime -Module IT-ToolBox
        foreach ($set in $command.ParameterSets) {
            ($set.Parameters | Where-Object Name -eq ElapsedTime).IsMandatory | Should -BeTrue
        }
        { Get-ElapsedTime -ElapsedTime $null -Seconds } | Should -Throw
    }

    It 'returns the requested elapsed-time component: <Component>' -ForEach @(
        @{ Component = 'Days' }; @{ Component = 'Hours' }; @{ Component = 'Minutes' }
        @{ Component = 'Seconds' }; @{ Component = 'TotalDays' }; @{ Component = 'TotalHours' }
        @{ Component = 'TotalMinutes' }; @{ Component = 'TotalSeconds' }; @{ Component = 'TotalMilliseconds' }
    ) {
        $timer = [System.Diagnostics.Stopwatch]::new()
        $selector = @{ $Component = $true }
        Get-ElapsedTime -ElapsedTime $timer @selector | Should -Be $timer.Elapsed.$Component
    }
}

Describe 'Documented module surface' {
    BeforeAll {
        $root = Split-Path $manifestPath -Parent
        $exports = @( (Import-PowerShellDataFile $manifestPath).FunctionsToExport | Sort-Object )
    }
    It 'documents exactly the manifest exports in the command inventory' {
        $readme = Get-Content -LiteralPath (Join-Path $root 'README.md') -Raw
        $inventory = [regex]::Match($readme, '(?s)<!-- command-inventory:start -->(.*?)<!-- command-inventory:end -->')
        $inventory.Success | Should -BeTrue
        $documented = @([regex]::Matches($inventory.Groups[1].Value, '(?m)^\| `([^`]+)` \|') | ForEach-Object { $_.Groups[1].Value } | Sort-Object)
        $documented.Count | Should -Be $exports.Count
        ($documented -join ',') | Should -Be ($exports -join ',')
    }
    It 'exports all top-level public functions without exposing additional commands' {
        $publicFunctions = @(foreach ($file in Get-ChildItem (Join-Path $root 'Public') -Filter '*.ps1') {
            $tokens = $null
            $parseErrors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors)
            $parseErrors.Count | Should -Be 0
            $ast.EndBlock.Statements | Where-Object { $_ -is [System.Management.Automation.Language.FunctionDefinitionAst] } | ForEach-Object Name
        }) | Sort-Object
        ($publicFunctions -join ',') | Should -Be ($exports -join ',')
        (@($module.ExportedFunctions.Keys | Sort-Object) -join ',') | Should -Be ($exports -join ',')
    }
}
