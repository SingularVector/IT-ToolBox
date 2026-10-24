BeforeAll { Import-Module (Join-Path $PSScriptRoot '../IT-ToolBox.psd1') -Force -ErrorAction Stop }
Describe 'GUID syntax contract' {
    It 'accepts <Value>' -ForEach @(
        @{Value='7761bf39-9a9f-42c8-869f-7c6e2689811a'}
        @{Value='7761BF39-9A9F-42C8-869F-7C6E2689811A'}
        @{Value='7761bf399a9f42c8869f7c6e2689811a'}
        @{Value='{7761bf39-9a9f-42c8-869f-7c6e2689811a}'}
        @{Value='(7761bf39-9a9f-42c8-869f-7c6e2689811a)'}
        @{Value='00000000-0000-0000-0000-000000000000'}
    ) { Test-IsGuid $Value | Should -BeTrue }
    It 'rejects malformed or unsupported input: <Value>' -ForEach @(
        @{Value=$null};@{Value=''};@{Value=' '};@{Value='not-a-guid'}
        @{Value='7761bf39-9a9f-42c8-869f-7c6e2689811a}'}
        @{Value='{7761bf39-9a9f-42c8-869f-7c6e2689811a)'}
        @{Value='{7761bf399a9f42c8869f7c6e2689811a}'}
        @{Value='7761bf39-9a9f42c8-869f-7c6e2689811a'}
        @{Value="junk`n7761bf39-9a9f-42c8-869f-7c6e2689811a`njunk"}
        @{Value="7761bf39-9a9f-42c8-869f-7c6e2689811a`n"}
        @{Value=' 7761bf39-9a9f-42c8-869f-7c6e2689811a'}
        @{Value='{0x7761bf39,0x9a9f,0x42c8,{0x86,0x9f,0x7c,0x6e,0x26,0x89,0x81,0x1a}}'}
    ) { Test-IsGuid -ObjectGuid $Value | Should -BeFalse }
    It 'returns one Boolean per pipeline record' {
        $r=@('bad','','00000000-0000-0000-0000-000000000000') | Test-IsGuid
        $r.Count | Should -Be 3
        ($r -join ',') | Should -BeExactly 'False,False,True'
        foreach($v in $r){$v | Should -BeOfType ([bool])}
    }
}
