function Test-IsGuid
{
    <#
    .SYNOPSIS
        Tests a complete GUID string using defined .NET formats.
    .DESCRIPTION
        Accepts N (32 digits), D (dashed), B (matched braces) and P (matched
        parentheses). Rejects surrounding whitespace, extra lines, mixed optional
        delimiters and the X initializer format. Null and empty input return false.
        The all-zero GUID is syntactically valid; this does not test object existence.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$ObjectGuid
    )

    process
    {
        if ([string]::IsNullOrWhiteSpace($ObjectGuid) -or $ObjectGuid -match '\s')
        {
            return $false
        }
        $parsed = [guid]::Empty
        foreach ($format in @('N', 'D', 'B', 'P'))
        {
            if ([guid]::TryParseExact($ObjectGuid, $format, [ref]$parsed))
            {
                return $true
            }
        }
        return $false
    }
}
