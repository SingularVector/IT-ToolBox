@{
    RootModule = 'IT-ToolBox.psm1'
    ModuleVersion = '3.1.0'
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
        'Test-IsGuid'
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
            ReleaseNotes = '3.1.0: Add dependency-free Test-IsGuid syntax validation with pipeline support. Includes 3.0.1 logger fixes; exports 30 commands. See CHANGELOG.md.'
            Tags = @('Infrastructure', 'Automation', 'Logging')
            LicenseUri = 'https://github.com/SingularVector/IT-ToolBox/blob/master/LICENSE'
            ProjectUri = 'https://github.com/SingularVector/IT-ToolBox'
        }
    }
}
