function Open-ITToolBoxRegistryKey
{
    [CmdletBinding()]
    param ([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$Path)

    if (-not $IsWindows)
    {
        throw [PlatformNotSupportedException]::new('Registry functions require the Windows Registry provider.')
    }
    $provider = $null
    $drive = $null
    [void]$ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($Path, [ref]$provider, [ref]$drive)
    if ($provider.Name -ne 'Registry')
    {
        throw 'Path must use the Registry provider.'
    }
    try
    {
        return Get-Item -LiteralPath $Path -ErrorAction Stop
    }
    catch [System.Management.Automation.ItemNotFoundException]
    {
        return $null
    }
}
