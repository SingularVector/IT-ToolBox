function Test-IsRegistryKey
{
    <#
    .SYNOPSIS
        Tests whether a literal Windows Registry key exists.
    .DESCRIPTION
        Missing keys return false. Provider, permission and operational errors
        terminate. Non-Windows systems are unsupported. This tests keys, not values.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param ([Parameter(Mandatory)][ValidateNotNullOrEmpty()][string]$KeyPath)

    $key = Open-ITToolBoxRegistryKey -Path $KeyPath
    if ($null -eq $key) { return $false }
    try { return $true }
    finally { $key.Dispose() }
}
