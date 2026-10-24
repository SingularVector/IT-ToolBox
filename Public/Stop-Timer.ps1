function Stop-Timer
{
    <#
    .SYNOPSIS
        Stops a stopwatch without resetting its elapsed time.
    .DESCRIPTION
        Returns $true after stopping the supplied stopwatch. Stopping an already
        stopped stopwatch also succeeds. Invalid input is rejected during binding.
        If Stop() throws, reports a warning and returns $false.
    .PARAMETER Timer
        The stopwatch instance to stop.
    .EXAMPLE
        Stop-Timer -Timer $Timer
    .OUTPUTS
        System.Boolean
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Diagnostics.Stopwatch]$Timer
    )

    try
    {
        $Timer.Stop()
        return $true
    }
    catch
    {
        Write-Warning -Message 'Exception reported while stopping stopwatch; use -Verbose for details.'
        Write-Verbose -Message $_.Exception.Message
        return $false
    }
}
