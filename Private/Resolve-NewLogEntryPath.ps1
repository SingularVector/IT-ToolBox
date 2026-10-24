function Resolve-NewLogEntryPath
{
    param
    (
        [string]$Path,
        [string]$CallerScriptPath
    )

    if (-not [string]::IsNullOrWhiteSpace($Path))
    {
        $provider = $null
        $drive = $null
        $resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
            $Path, [ref]$provider, [ref]$drive
        )
        if ($provider.Name -ne 'FileSystem')
        {
            throw [ArgumentException]::new('LogFilePath must use the FileSystem provider.')
        }
        return $resolved
    }

    $basePath = if (-not [string]::IsNullOrWhiteSpace($CallerScriptPath))
    {
        $CallerScriptPath
    }
    else
    {
        $location = Get-Location
        if ($location.Provider.Name -ne 'FileSystem')
        {
            throw [ArgumentException]::new('A filesystem LogFilePath is required when the current location uses another provider.')
        }
        Join-Path -Path $location.ProviderPath -ChildPath 'PowerShell'
    }

    $directory = Split-Path -Path $basePath -Parent
    $fileName = Split-Path -Path $basePath -Leaf

    if ([string]::IsNullOrWhiteSpace($directory))
    {
        $directory = (Get-Location).ProviderPath
    }

    if ([string]::IsNullOrWhiteSpace($fileName))
    {
        $fileName = 'PowerShell'
    }

    $safeTimestamp = [DateTime]::Now.ToString('yyyyMMdd-HHmmss')

    return Join-Path -Path $directory -ChildPath ('{0}-LogFile-{1}.log' -f $fileName, $safeTimestamp)
}
