function Test-RegistryValue
{
    <#
    .SYNOPSIS
        Tests whether a named registry value exists on Windows.

    .DESCRIPTION
        Uses a literal Registry-provider path and checks value names, not their data.
        Empty strings, zero and unexpanded environment-variable data still count as
        existing values. Missing keys/values return false; permissions and other
        operational errors terminate. Non-Windows hosts throw PlatformNotSupportedException.

    .PARAMETER Value
        Value name; an empty string selects the unnamed/default registry value.

    .EXAMPLE
        Test-RegistryValue -Path 'HKCU:\Software\Example' -Value 'Enabled'
    #>

    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory = $true, Position = 1)]
        [AllowEmptyString()]
        [ValidateNotNull()]
        [string]$Value
    )

    $key = Open-ITToolBoxRegistryKey -Path $Path
    if ($null -eq $key)
    {
        return $false
    }

    try
    {
        # Check the registry key's value names; the data itself is intentionally ignored.
        return ($key.GetValueNames() -contains $Value)
    }
    finally
    {
        $key.Dispose()
    }
}
