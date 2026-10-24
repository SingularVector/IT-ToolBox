BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../IT-ToolBox.psd1') -Force -ErrorAction Stop
}
Describe 'Registry key and value contracts with offline handles' {
    BeforeEach {
        $script:key = [pscustomobject]@{ Disposed = $false }
        $script:key | Add-Member ScriptMethod Dispose { $this.Disposed = $true }
        $script:key | Add-Member ScriptMethod GetValueNames { @('', 'Zero', 'Empty', 'A*B') }
        Mock Open-ITToolBoxRegistryKey -ModuleName IT-ToolBox { $script:key }
    }
    It 'returns true for an existing key and disposes its handle' {
        Test-IsRegistryKey -KeyPath 'HKCU:\Example' | Should -BeTrue
        $script:key.Disposed | Should -BeTrue
    }
    It 'returns true for an empty key while value checks return false' {
        $script:key | Add-Member ScriptMethod GetValueNames { @() } -Force
        Test-IsRegistryKey 'HKCU:\Empty' | Should -BeTrue
        Test-RegistryValue 'HKCU:\Empty' 'Missing' | Should -BeFalse
    }
    It 'returns false for a missing key in both commands' {
        Mock Open-ITToolBoxRegistryKey -ModuleName IT-ToolBox { $null }
        Test-IsRegistryKey 'HKCU:\Missing' | Should -BeFalse
        Test-RegistryValue 'HKCU:\Missing' 'Name' | Should -BeFalse
    }
    It 'passes metacharacters literally to the shared opener' {
        Test-IsRegistryKey 'HKCU:\Literal[1]*' | Should -BeTrue
        Should -Invoke Open-ITToolBoxRegistryKey -ModuleName IT-ToolBox -Times 1 -Exactly -ParameterFilter { $Path -ceq 'HKCU:\Literal[1]*' }
    }
    It 'propagates access failures from both commands' {
        Mock Open-ITToolBoxRegistryKey -ModuleName IT-ToolBox { throw [UnauthorizedAccessException]::new('Access denied') }
        { Test-IsRegistryKey 'HKCU:\Denied' } | Should -Throw '*Access denied*'
        { Test-RegistryValue 'HKCU:\Denied' 'Name' } | Should -Throw '*Access denied*'
    }
    It 'preserves default, case-insensitive and literal value-name checks' {
        Test-RegistryValue 'HKCU:\Example' '' | Should -BeTrue
        Test-RegistryValue 'HKCU:\Example' 'zero' | Should -BeTrue
        Test-RegistryValue 'HKCU:\Example' 'A*B' | Should -BeTrue
        Test-RegistryValue 'HKCU:\Example' 'A*' | Should -BeFalse
        $script:key.Disposed | Should -BeTrue
    }
    It 'disposes value handles even if reading fails' {
        $script:key | Add-Member ScriptMethod GetValueNames { throw 'Read failed' } -Force
        { Test-RegistryValue 'HKCU:\Example' 'Name' } | Should -Throw '*Read failed*'
        $script:key.Disposed | Should -BeTrue
    }
    It 'rejects null and empty key arguments during binding' {
        { Test-IsRegistryKey -KeyPath $null } | Should -Throw
        { Test-IsRegistryKey -KeyPath '' } | Should -Throw
        Should -Invoke Open-ITToolBoxRegistryKey -ModuleName IT-ToolBox -Times 0 -Exactly
    }
}
Describe 'Registry key platform boundary' {
    It 'rejects invocation on non-Windows without affecting module import' -Skip:$IsWindows {
        { Test-IsRegistryKey 'HKCU:\Software' } | Should -Throw '*Windows Registry provider*'
    }
    It 'checks actual literal empty HKCU keys on Windows' -Skip:(-not $IsWindows) {
        $parent = 'HKCU:\Software\ITToolBoxKeyTests-' + [guid]::NewGuid().ToString('N')
        try {
            $null = New-Item -Path $parent -ErrorAction Stop
            $key = Get-Item -LiteralPath $parent -ErrorAction Stop
            try { $child = $key.CreateSubKey('Literal[1]') }
            finally { $key.Dispose() }
            $child.Dispose()
            Test-IsRegistryKey ($parent + '\Literal[1]') | Should -BeTrue
            Test-IsRegistryKey ($parent + '\Literal*') | Should -BeFalse
            Test-IsRegistryKey ($parent + '\Missing') | Should -BeFalse
            Test-RegistryValue ($parent + '\Literal[1]') 'Missing' | Should -BeFalse
            { Test-IsRegistryKey $TestDrive } | Should -Throw '*Registry provider*'
        }
        finally {
            if (Test-Path -LiteralPath $parent) { Remove-Item -LiteralPath $parent -Recurse -Force }
        }
    }
}
