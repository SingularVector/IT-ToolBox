function Test-UPNExist
{
    <#
    .SYNOPSIS
        Tests whether a user principal name exists in a forest or domain.
    .DESCRIPTION
        Requires the ActiveDirectory module commands at invocation, not script load.
        Forest searches use a Global Catalog and an empty search base to search all
        partitions. Domain searches use the server's default naming context.
        Query and discovery errors terminate; they are not treated as an unused UPN.
    .PARAMETER AdServer
        Server hostname, optionally with a port. Server is retained as an alias.
        Forest scope accepts GC ports 3268 or 3269 and defaults to 3268.
        The supplied host must actually provide a Global Catalog service.
    .PARAMETER SearchScope
        Forest (default) or Domain. This selects the directory coverage, not an LDAP
        Base/OneLevel/Subtree option; the LDAP search itself uses Subtree.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$UPN,

        [Alias('Server')]
        [ValidatePattern('^[A-Za-z0-9][A-Za-z0-9._-]*(?::[0-9]{1,5})?$')]
        [ValidateScript({
            if ($_ -match ':([0-9]+)$') { [int]$Matches[1] -ge 1 -and [int]$Matches[1] -le 65535 }
            else { $true }
        })]
        [string]$AdServer,

        [ValidateSet('Forest', 'Domain')]
        [string]$SearchScope = 'Forest'
    )

    $ErrorActionPreference = 'Stop'
    if ([string]::IsNullOrWhiteSpace($UPN))
    {
        throw [ArgumentException]::new('UPN must not be blank.')
    }

    if (-not (Get-Command Get-ADUser -ErrorAction SilentlyContinue))
    {
        throw [InvalidOperationException]::new('Test-UPNExist requires Get-ADUser from the ActiveDirectory module and a reachable directory.')
    }

    $query = @{
        LDAPFilter    = '(&(objectCategory=person)(objectClass=user)(userPrincipalName={0}))' -f (ConvertTo-ITToolBoxLdapFilterValue -Value $UPN)
        SearchScope   = 'Subtree'
        ResultSetSize = 1
        ErrorAction   = 'Stop'
    }

    if ($SearchScope -eq 'Forest')
    {
        $server = $AdServer
        if (-not $PSBoundParameters.ContainsKey('AdServer'))
        {
            if (-not (Get-Command Get-ADDomainController -ErrorAction SilentlyContinue))
            {
                throw 'Forest discovery requires Get-ADDomainController from the ActiveDirectory module.'
            }
            $controller = Get-ADDomainController -Discover -Service GlobalCatalog -ErrorAction Stop
            $server = [string]$controller.HostName
            if ([string]::IsNullOrWhiteSpace($server))
            {
                throw 'Global Catalog discovery returned no hostname.'
            }
        }

        if ($server -match ':([0-9]+)$')
        {
            if ($Matches[1] -notin @('3268', '3269'))
            {
                throw 'Forest scope requires a Global Catalog port (3268 or 3269).'
            }
        }
        else
        {
            $server += ':3268'
        }

        $query.Server = $server
        $query.SearchBase = ''
    }
    else
    {
        if (-not (Get-Command Get-ADRootDSE -ErrorAction SilentlyContinue))
        {
            throw 'Domain scope requires Get-ADRootDSE from the ActiveDirectory module.'
        }
        $rootQuery = @{ ErrorAction = 'Stop' }
        if ($PSBoundParameters.ContainsKey('AdServer'))
        {
            $rootQuery.Server = $AdServer
            $query.Server = $AdServer
        }
        $root = Get-ADRootDSE @rootQuery
        $base = [string]$root.DefaultNamingContext
        if ([string]::IsNullOrWhiteSpace($base))
        {
            throw 'Directory discovery returned no default naming context.'
        }
        # Pin the user search to the same controller used to discover the domain.
        if (-not $query.ContainsKey('Server'))
        {
            if ([string]::IsNullOrWhiteSpace([string]$root.DnsHostName))
            {
                throw 'Directory discovery returned no controller hostname.'
            }
            $query.Server = [string]$root.DnsHostName
        }
        $query.SearchBase = $base
    }

    $found = @(Get-ADUser @query)
    return ($found.Count -gt 0)
}
