# UPN availability and generation

## Requirements and loading

Import IT-ToolBox.psd1 on PowerShell 7.4+; no ActiveDirectory module is required at
import. The module loader supplies the functions and private helpers. These UPN
commands are exported in 3.3.0; keep private helpers internal.

Actual lookup uses Get-ADUser from the ActiveDirectory module (for example, an appropriately configured Windows management host with RSAT). Forest discovery also needs Get-ADDomainController; Domain scope needs Get-ADRootDSE. Dependencies are checked at invocation, so scripts load and offline tests run without the AD module. This replaces the historical System.DirectoryServices query and is a deliberate new dependency. Live operation from macOS/Linux is not asserted by the offline tests.

## Generation

```powershell
Import-Module ./IT-ToolBox.psd1
Get-UniqueUPN -FirstName John -LastName Doe -UPNSuffix example.com -ADServer gc.example.com
# john.doe@example.com, if no matching user is found

Get-UniqueUPN -FirstName John -LastName Doe -UPNSuffix example.com -FirstNameFormat FirstLetter -LastNameFormat FullName -ADServer gc.example.com
# j.doe@example.com, if available
```

FullName is the corrected default. Each formatting option applies independently. IncludeMiddleName inserts the supplied/extracted middle name when nonblank. Outer name whitespace is trimmed. Embedded whitespace, controls and @ are rejected in name components; normalize compound names to your organization's policy before calling. Separators may be empty but cannot contain whitespace, controls or @. The suffix must pass IT-ToolBox's DNS/IDN syntax policy; syntax validation does not check registered AD UPN suffixes.

ADObject accepts ADUser, DirectoryEntry and SearchResult inputs as before. Ensure required name attributes are loaded; missing first/last names terminate before querying. The tests use representative typed objects, not a live directory. Casing uses ToLowerInvariant; initials use the first .NET text element.

Collisions try localpart@suffix, localpart1@suffix, localpart2@suffix, and so on. MaxAttempts defaults to 1000 and includes the initial unsuffixed candidate. Exhaustion throws. The generator calls the public lookup for each candidate, forwarding server and scope. Supply a specific controller to keep candidate checks on a chosen server and avoid repeated discovery. Name normalization and AD provisioning policy remain caller responsibilities.

## Lookup scope

Forest is the default. An explicit hostname selects that host on Global Catalog port 3268, or an explicit 3268/3269 port is retained. The host must actually provide the requested GC service; failure is not treated as absence. An empty SearchBase searches all GC partitions. Without a server, discover a Global Catalog in the current forest.

```powershell
Test-UPNExist -UPN 'john@example.com' -AdServer gc.example.com -SearchScope Forest
Test-UPNExist -UPN 'john@example.com' -Server gc.example.com:3269
Test-UPNExist -UPN 'john@example.com' -AdServer dc.example.com -SearchScope Domain
```

Server is a compatibility alias for AdServer on both functions. Domain scope uses the selected controller's DefaultNamingContext, with a subtree search. When no server is supplied, pin the user query to the RootDSE controller used to discover that naming context. Domain coverage must not be described as forest-wide. Hostname/optional-port strings are supported; LDAP URLs, arbitrary search roots and IPv6 literals are not accepted by this parameter contract.

The internal Get-ADUser query uses an escaped LDAP userPrincipalName equality filter, restricts results to person/user objects, limits results to one, and returns one Boolean. AD command/discovery failures terminate. LDAP escaping reuses IT-ToolBox's ConvertTo-ITToolBoxLdapFilterValue implementation unchanged. It is filter-value escaping, not DN escaping.

Microsoft documents the empty SearchBase / Global Catalog behavior here:
https://learn.microsoft.com/en-us/powershell/module/activedirectory/get-aduser

## Limits and production validation

An unused UPN is a point-in-time observation, not a reservation. Replication delays, concurrent provisioning and scoped directory permissions affect what can be observed. Handle collision errors in account creation and retry according to your provisioning workflow. Domain scope only checks that domain; alternate credentials and custom search roots are not added by this patch.

Tests mock AD commands and validate request assembly, naming, errors and output contracts. Before production, check with a test forest: known-present/absent users, collisions, two domains, explicit GC and domain controllers, discovery, port 3269 if used, permissions and connectivity failures. Perform provisioning validation only with approved test accounts; the functions themselves do not create or modify users.

## Consistent naming policy

Every generated candidate must satisfy Test-IsValidUpn, using the same implementation
as IT-ToolBox: ASCII letters/digits at the username edges; dots, underscores,
hyphens and apostrophes internally; no consecutive dots; and a DNS/IDN suffix.
The initial candidate is validated before any directory call. Numeric collision
suffixes preserve that syntax policy.

This deliberately changes older generation behavior. For example, José/García
and separators such as / or .. now cause a policy error. Normalize names according
to your organization's rules before calling, for example explicitly supplying
Jose and Garcia. No silent accent stripping or custom-map conversion is performed.
Unicode AD identities are not intrinsically invalid; this is the toolkit's
chosen generation policy. Test-UPNExist still searches literal existing identities,
including Unicode names, without imposing the generation policy on the lookup.

An absent optional ADUser MiddleName property is treated as empty, including under
StrictMode. Explicit server ports must be within 1–65535; forest scope additionally
requires port 3268 or 3269. Existing aliases, bounded retries and scope defaults remain.

Test-IsValidUpn is available for local cross-platform validation after importing the module:

```powershell
Import-Module ./IT-ToolBox.psd1
Test-IsValidUpn 'first.last@example.com'
```

The validator
does not need AD, perform discovery, check configured suffixes or establish uniqueness.
The Get-UniqueUPN command still performs a directory lookup: it does not claim an
unchecked generated string is unique when AD is unavailable.
