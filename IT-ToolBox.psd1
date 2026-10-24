@{
    RootModule = 'IT-ToolBox.psm1'
    ModuleVersion = '3.0.0'
    GUID = '02c0c748-00ba-4e8f-b8ce-6aa7e4cefe08'
    Author = 'Daniele Catanesi - SingularVector'
    CompanyName = 'Community'
    Copyright = '(c) Daniele Catanesi. MIT License.'
    Description = 'PowerShell 7.4+ utilities for infrastructure automation: logging, validation, timing, string handling, password generation and API requests.'
    PowerShellVersion = '7.4'
    CompatiblePSEditions = @('Core')
    FunctionsToExport = @(
        'New-LogEntry'
        'New-Timer'
        'Get-TimerStatus'
        'Stop-Timer'
        'Get-ElapsedTime'
        'Get-ScriptDirectory'
        'Get-ScriptName'
        'Test-FileName'
        'Test-IsValidPath'
        'Test-IsIP'
        'Test-IsDate'
        'Test-IsEmail'
        'Test-IsUrl'
        'Convert-LogonTimestamp'
        'Get-OsUpTime'
        'Remove-SpecialCharacters'
        'Test-RegistryValue'
        'Test-IsValidDn'
        'Test-IsValidUpn'
        'Get-ReportChain'
        'New-StringEncryption'
        'New-StringDecryption'
        'New-RandomString'
        'New-RandomPassword'
        'New-PhoneticPassword'
        'New-ApiRequest'
        'New-StringConversion'
        'Get-StringCheckSum'
        'Get-StringHashCode'
    )
    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            ReleaseNotes = '3.0.0: Stable 29-command PowerShell 7.4+ API; aligned timer validation and diagnostics; updated SingularVector metadata and command documentation. See CHANGELOG.md for migration and validation boundaries.'
            Tags = @('Infrastructure', 'Automation', 'Logging')
            LicenseUri = 'https://github.com/SingularVector/IT-ToolBox/blob/master/LICENSE'
            ProjectUri = 'https://github.com/SingularVector/IT-ToolBox'
        }
    }
}
