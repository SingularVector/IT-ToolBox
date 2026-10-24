function Get-NewLogEntryMutexName
{
    param
    (
        [string]$Path
    )

    # Conservatively share locks for case aliases on macOS, including its
    # common case-insensitive volumes. Case-sensitive macOS volumes may serialize
    # distinct case-only filenames; that is safer than missing a shared file.
    $normalizedPath = if ($IsWindows -or $IsMacOS)
    {
        $Path.ToUpperInvariant()
    }
    else
    {
        $Path
    }

    $bytes = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($normalizedPath))
    $hash = [Convert]::ToHexString($bytes).Substring(0, 32)

    if ($IsWindows)
    {
        return 'Global\NewLogEntry-{0}' -f $hash
    }

    return 'NewLogEntry-{0}' -f $hash
}
