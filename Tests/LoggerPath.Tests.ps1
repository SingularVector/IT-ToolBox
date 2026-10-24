BeforeAll {
    $loggerLoader = (Resolve-Path (Join-Path $PSScriptRoot '../IT-ToolBox.psd1')).Path
    $loggerModule = Import-Module $loggerLoader -Force -PassThru -ErrorAction Stop
    $loggerIsModule = $true
}
Describe 'Logger destination boundaries' {
    BeforeEach { New-LogEntry -ClearBuffer }
    It 'rejects non-filesystem destinations before creating a file: <Provider>' -ForEach @(
        @{Provider='Env'}; @{Provider='Variable'}; @{Provider='Function'}
    ) {
        $name = 'LoggerProbe' + [guid]::NewGuid().ToString('N')
        $destination = '{0}:{1}' -f $Provider,$name
        $originalDirectory = [Environment]::CurrentDirectory
        try {
            [Environment]::CurrentDirectory = $TestDrive
            { New-LogEntry -LogMessage 'must not be written' -LogFilePath $destination -NoConsole } | Should -Throw '*FileSystem*'
            @(Get-ChildItem -LiteralPath $TestDrive -Filter $name -Force).Count | Should -Be 0
            New-LogEntry -LogMessage 'keep buffered' -BufferOnly
            { New-LogEntry -FlushBuffer -LogFilePath $destination -NoConsole } | Should -Throw '*FileSystem*'
            @(New-LogEntry -GetBuffer).Count | Should -Be 1
            (New-LogEntry -GetBuffer) | Should -Match 'keep buffered$'
        }
        finally { [Environment]::CurrentDirectory = $originalDirectory }
    }
    It 'rejects an interactive default path from a non-filesystem location' {
        Push-Location Env:
        try {
            { & $loggerModule { Resolve-NewLogEntryPath } } | Should -Throw '*filesystem LogFilePath*'
        }
        finally { Pop-Location }
    }
    It 'still resolves an explicit filesystem destination from another provider' {
        $path = Join-Path $TestDrive 'explicit.log'
        Push-Location Env:
        try { New-LogEntry -LogMessage 'explicit destination' -LogFilePath $path -NoConsole }
        finally { Pop-Location }
        Get-Content -LiteralPath $path | Should -Match 'explicit destination$'
    }
}

Describe 'Logger case-alias locking' {
    It 'blocks a different process using the same file or an available case alias' {
        $path = Join-Path $TestDrive 'case-probe.log'
        $aliasPath = Join-Path $TestDrive 'CASE-PROBE.log'
        Set-Content -LiteralPath $path -Value 'seed'
        if (-not (Test-Path -LiteralPath $aliasPath)) {
            $aliasPath = $path

        }
        $name = & $loggerModule { param($p) Get-NewLogEntryMutexName -Path $p } $path
        $aliasName = & $loggerModule { param($p) Get-NewLogEntryMutexName -Path $p } $aliasPath
        $aliasName | Should -BeExactly $name
        $mutex = [Threading.Mutex]::new($false,$name)
        $locked = $false
        $process = $null
        try {
            $locked = $mutex.WaitOne(1000)
            $locked | Should -BeTrue
            $escapedLoader = $loggerLoader.Replace("'","''")
            $escapedPath = $aliasPath.Replace("'","''")
            $load = if ($loggerIsModule) { "Import-Module '$escapedLoader' -Force" } else { ". '$escapedLoader'" }
            $code = @"
`$ErrorActionPreference='Stop'
$load
try {
    New-LogEntry -LogMessage 'must time out' -LogFilePath '$escapedPath' -LockTimeoutSeconds 1 -NoConsole
    Write-Output 'UNEXPECTED_WRITE'
    exit 2
} catch {
    if (`$_.Exception.Message -like '*Timed out waiting*') { Write-Output 'EXPECTED_TIMEOUT'; exit 0 }
    Write-Output `$_.Exception.Message
    exit 3
}
"@
            $start = [Diagnostics.ProcessStartInfo]::new((Get-Process -Id $PID).Path)
            $start.UseShellExecute = $false
            $start.RedirectStandardOutput = $true
            $start.RedirectStandardError = $true
            foreach ($argument in @('-NoProfile','-EncodedCommand',[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code)))) {
                $start.ArgumentList.Add($argument)
            }
            $process = [Diagnostics.Process]::Start($start)
            if (-not $process.WaitForExit(15000)) { $process.Kill($true); throw 'Logger child process exceeded test timeout.' }
            $output = $process.StandardOutput.ReadToEnd()
            $errorOutput = $process.StandardError.ReadToEnd()
            $process.ExitCode | Should -Be 0 -Because ($output + $errorOutput)
            $output | Should -Match 'EXPECTED_TIMEOUT'
            Get-Content -LiteralPath $path | Should -Be 'seed'
        }
        finally {
            if ($null -ne $process) { $process.Dispose() }
            if ($locked) { $mutex.ReleaseMutex() }
            $mutex.Dispose()
        }
    }
}
