BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../IT-ToolBox.psd1') -Force -ErrorAction Stop
}
Describe 'Stopwatch lifecycle' {
    It 'starts, reports status, stops and preserves elapsed time' {
        $timer=New-Timer
        $timer | Should -BeOfType ([System.Diagnostics.Stopwatch])
        Get-TimerStatus $timer | Should -BeTrue
        [System.Threading.SpinWait]::SpinUntil([Func[bool]]{$timer.ElapsedTicks -gt 0},1000) | Should -BeTrue
        Stop-Timer $timer | Should -BeTrue
        Get-TimerStatus $timer | Should -BeFalse
        $ticks=$timer.ElapsedTicks
        $ticks | Should -BeGreaterThan 0
        Stop-Timer $timer | Should -BeTrue
        $timer.ElapsedTicks | Should -Be $ticks
        (Get-ElapsedTime -ElapsedTime $timer).Ticks | Should -Be $timer.Elapsed.Ticks
    }
    It 'does not start a stopwatch that was never started' {
        $timer=[System.Diagnostics.Stopwatch]::new()
        Stop-Timer $timer | Should -BeTrue
        Get-TimerStatus $timer | Should -BeFalse
        $timer.ElapsedTicks | Should -Be 0
    }
    It 'rejects null and incompatible inputs' {
        {Stop-Timer -Timer $null} | Should -Throw
        {Get-TimerStatus -Timer $null} | Should -Throw
        {Stop-Timer -Timer 'invalid'} | Should -Throw
        {Get-TimerStatus -Timer 'invalid'} | Should -Throw
    }
    It 'preserves caller and module preferences starting with <Preference>' -ForEach @(
        @{ Preference = 'Continue' }
        @{ Preference = 'Stop' }
    ) {
        $module = Get-Module IT-ToolBox
        $originalModulePreference = & $module { $script:ErrorActionPreference }
        $originalCallerPreference = $ErrorActionPreference
        try {
            $ErrorActionPreference = $Preference
            & $module { param($value) $script:ErrorActionPreference = $value } $Preference
            $timer = New-Timer
            Stop-Timer $timer | Should -BeTrue
            $ErrorActionPreference | Should -Be $Preference
            (& $module { $script:ErrorActionPreference }) | Should -Be $Preference
            { Stop-Timer -Timer $null } | Should -Throw
            $ErrorActionPreference | Should -Be $Preference
            (& $module { $script:ErrorActionPreference }) | Should -Be $Preference
        }
        finally {
            & $module { param($value) $script:ErrorActionPreference = $value } $originalModulePreference
            $ErrorActionPreference = $originalCallerPreference
        }
    }
    It 'accepts verbose diagnostics and returns a boolean' {
        $timer=New-Timer
        $result=Stop-Timer $timer -Verbose
        $result | Should -BeOfType ([bool])
        Get-TimerStatus $timer -Verbose | Should -BeFalse
    }
}
