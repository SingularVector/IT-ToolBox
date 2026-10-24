BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../IT-ToolBox.psd1') -Force -ErrorAction Stop
    & (Get-Module IT-ToolBox) {
    # Offline seams: accidental unmocked directory calls fail, never contact AD.
    function script:Get-ADUser { [CmdletBinding()] param($LDAPFilter,$SearchScope,$SearchBase,$Server,$ResultSetSize) throw 'Unexpected directory call' }
    function script:Get-ADRootDSE { [CmdletBinding()] param($Server) throw 'Unexpected root lookup' }
    function script:Get-ADDomainController { [CmdletBinding()] param([switch]$Discover,$Service) throw 'Unexpected discovery' }
    }
}

Describe 'UPN generation' {
    BeforeEach { Mock Test-UPNExist -ModuleName IT-ToolBox { $false } }
    It 'uses full names by default' {
        Get-UniqueUPN -FirstName John -LastName Doe -UPNSuffix example.com | Should -BeExactly 'john.doe@example.com'
    }
    It 'formats first and last names independently: <First>/<Last>' -ForEach @(
        @{ First='FullName';Last='FirstLetter';Expected='john.d@example.com' }
        @{ First='FirstLetter';Last='FullName';Expected='j.doe@example.com' }
        @{ First='FirstLetter';Last='FirstLetter';Expected='j.d@example.com' }
    ) {
        Get-UniqueUPN -FirstName John -LastName Doe -UPNSuffix example.com -FirstNameFormat $First -LastNameFormat $Last | Should -BeExactly $Expected
    }
    It 'includes an available middle name and permits an empty separator' {
        Get-UniqueUPN -FirstName John -LastName Doe -MiddleName A -IncludeMiddleName -UPNSuffix example.com | Should -BeExactly 'john.a.doe@example.com'
        Get-UniqueUPN -FirstName John -LastName Doe -Separator '' -UPNSuffix example.com | Should -BeExactly 'johndoe@example.com'
        Get-UniqueUPN -FirstName John -LastName Doe -IncludeMiddleName -UPNSuffix example.com | Should -BeExactly 'john.doe@example.com'
    }
    It 'forwards server and scope using the real dependency parameter name' {
        Get-UniqueUPN -FirstName John -LastName Doe -UPNSuffix example.com -Server dc.example.com -SearchScope Domain | Out-Null
        Should -Invoke Test-UPNExist -ModuleName IT-ToolBox -Times 1 -Exactly -ParameterFilter { $AdServer -eq 'dc.example.com' -and $SearchScope -eq 'Domain' }
    }
    It 'appends counters until an unused candidate is found' {
        Mock Test-UPNExist -ModuleName IT-ToolBox { $UPN -ne 'john.doe2@example.com' }
        Get-UniqueUPN -FirstName John -LastName Doe -UPNSuffix example.com | Should -BeExactly 'john.doe2@example.com'
        Should -Invoke Test-UPNExist -ModuleName IT-ToolBox -Times 3 -Exactly
    }
    It 'bounds retries and includes the unsuffixed candidate in MaxAttempts' {
        Mock Test-UPNExist -ModuleName IT-ToolBox { $true }
        { Get-UniqueUPN -FirstName John -LastName Doe -UPNSuffix example.com -MaxAttempts 2 } | Should -Throw '*after 2 candidates*'
        Should -Invoke Test-UPNExist -ModuleName IT-ToolBox -Times 2 -Exactly
    }
    It 'propagates directory failures instead of returning availability' {
        Mock Test-UPNExist -ModuleName IT-ToolBox { throw 'Directory offline' }
        { Get-UniqueUPN -FirstName John -LastName Doe -UPNSuffix example.com } | Should -Throw '*Directory offline*'
    }
    It 'extracts an ADUser-shaped object' {
        $user=[pscustomobject]@{GivenName='Jane';Surname='Doe';MiddleName='A'}
        $user.PSObject.TypeNames.Insert(0,'Microsoft.ActiveDirectory.Management.ADUser')
        Get-UniqueUPN -ADObject $user -UPNSuffix example.com -IncludeMiddleName | Should -BeExactly 'jane.a.doe@example.com'
    }
    It 'extracts directory property collections: <Type>' -ForEach @(
        @{Type='System.DirectoryServices.DirectoryEntry'}
        @{Type='System.DirectoryServices.SearchResult'}
    ) {
        $user=[pscustomobject]@{Properties=@{givenName=@('Jane');sn=@('Doe');middleName=@('A')}}
        $user.PSObject.TypeNames.Insert(0,$Type)
        Get-UniqueUPN -ADObject $user -UPNSuffix example.com -IncludeMiddleName | Should -BeExactly 'jane.a.doe@example.com'
    }
    It 'rejects incomplete or unsupported objects before any lookup' {
        {Get-UniqueUPN -ADObject ([pscustomobject]@{}) -UPNSuffix example.com} | Should -Throw '*Unsupported*'
        $user=[pscustomobject]@{GivenName='Jane';Surname=$null}
        $user.PSObject.TypeNames.Insert(0,'Microsoft.ActiveDirectory.Management.ADUser')
        {Get-UniqueUPN -ADObject $user -UPNSuffix example.com} | Should -Throw '*nonblank*'
        Should -Invoke Test-UPNExist -ModuleName IT-ToolBox -Times 0 -Exactly
    }
    It 'rejects invalid input before any lookup' {
        {Get-UniqueUPN -FirstName ' ' -LastName Doe -UPNSuffix example.com} | Should -Throw
        {Get-UniqueUPN -FirstName 'John Paul' -LastName Doe -UPNSuffix example.com} | Should -Throw
        {Get-UniqueUPN -FirstName John -LastName Doe -UPNSuffix 'bad suffix'} | Should -Throw
        {Get-UniqueUPN -FirstName John -LastName Doe -UPNSuffix example.com -Separator '@'} | Should -Throw
        {Get-UniqueUPN -FirstName John -LastName Doe -UPNSuffix example.com -MaxAttempts 0} | Should -Throw
        Should -Invoke Test-UPNExist -ModuleName IT-ToolBox -Times 0 -Exactly
    }
    It 'lowercases invariantly under Turkish culture' {
        $old=[System.Globalization.CultureInfo]::CurrentCulture
        try {
            [System.Globalization.CultureInfo]::CurrentCulture=[System.Globalization.CultureInfo]::new('tr-TR')
            Get-UniqueUPN -FirstName IVAN -LastName DOE -UPNSuffix EXAMPLE.COM | Should -BeExactly 'ivan.doe@example.com'
        } finally { [System.Globalization.CultureInfo]::CurrentCulture=$old }
    }
}

Describe 'Directory query construction' {
    BeforeEach {
        Mock Get-ADUser -ModuleName IT-ToolBox { }
        Mock Get-ADDomainController -ModuleName IT-ToolBox { [pscustomobject]@{HostName='gc.example.com'} }
        Mock Get-ADRootDSE -ModuleName IT-ToolBox { [pscustomobject]@{DefaultNamingContext='DC=example,DC=com';DnsHostName='dc.example.com'} }
    }
    It 'runs the real generator and lookup together with mocked AD commands' {
        Get-UniqueUPN -FirstName John -LastName Doe -UPNSuffix example.com -AdServer gc.example.com | Should -BeExactly 'john.doe@example.com'
        Should -Invoke Get-ADUser -ModuleName IT-ToolBox -Times 1 -Exactly -ParameterFilter { $Server -eq 'gc.example.com:3268' -and $LDAPFilter -like '*john.doe@example.com*' }
    }
    It 'searches every GC partition by default' {
        Test-UPNExist -UPN 'john@example.com' | Should -BeFalse
        Should -Invoke Get-ADUser -ModuleName IT-ToolBox -Times 1 -Exactly -ParameterFilter {
            $Server -eq 'gc.example.com:3268' -and $SearchBase -ceq '' -and $SearchScope -eq 'Subtree' -and $ResultSetSize -eq 1 -and
            $LDAPFilter -eq '(&(objectCategory=person)(objectClass=user)(userPrincipalName=john@example.com))'
        }
    }
    It 'accepts the Server alias without discovery and uses GC coverage' {
        Test-UPNExist -UPN 'john@example.com' -Server gc.other.example | Should -BeFalse
        Should -Invoke Get-ADDomainController -ModuleName IT-ToolBox -Times 0 -Exactly
        Should -Invoke Get-ADUser -ModuleName IT-ToolBox -Times 1 -Exactly -ParameterFilter { $Server -eq 'gc.other.example:3268' -and $SearchBase -ceq '' }
    }
    It 'preserves an explicit secure Global Catalog port' {
        Test-UPNExist -UPN 'john@example.com' -AdServer gc.example.com:3269 | Out-Null
        Should -Invoke Get-ADUser -ModuleName IT-ToolBox -Times 1 -Exactly -ParameterFilter { $Server -eq 'gc.example.com:3269' }
    }
    It 'rejects a non-GC port in forest scope' {
        {Test-UPNExist -UPN 'john@example.com' -AdServer dc.example.com:389} | Should -Throw '*Global Catalog port*'
        Should -Invoke Get-ADUser -ModuleName IT-ToolBox -Times 0 -Exactly
    }
    It 'uses only the selected domain naming context' {
        Test-UPNExist -UPN 'john@example.com' -SearchScope Domain -AdServer dc.other.example | Out-Null
        Should -Invoke Get-ADRootDSE -ModuleName IT-ToolBox -Times 1 -Exactly -ParameterFilter {$Server -eq 'dc.other.example'}
        Should -Invoke Get-ADUser -ModuleName IT-ToolBox -Times 1 -Exactly -ParameterFilter {$Server -eq 'dc.other.example' -and $SearchBase -eq 'DC=example,DC=com'}
    }
    It 'pins default domain lookup to the RootDSE controller' {
        Test-UPNExist -UPN 'john@example.com' -SearchScope Domain | Out-Null
        Should -Invoke Get-ADUser -ModuleName IT-ToolBox -Times 1 -Exactly -ParameterFilter {$Server -eq 'dc.example.com' -and $SearchBase -eq 'DC=example,DC=com'}
    }
    It 'returns exactly one Boolean when a user matches' {
        Mock Get-ADUser -ModuleName IT-ToolBox {[pscustomobject]@{UserPrincipalName='john@example.com'}}
        $result=@(Test-UPNExist -UPN 'john@example.com')
        $result.Count | Should -Be 1
        $result[0] | Should -BeOfType ([bool])
        $result[0] | Should -BeTrue
    }
    It 'escapes literal wildcard, brackets, backslash, NUL and UTF-8 bytes' {
        $inputUpn="a*(b)\$([char]0)é@example.com"
        Test-UPNExist -UPN $inputUpn -AdServer gc.example.com | Out-Null
        Should -Invoke Get-ADUser -ModuleName IT-ToolBox -Times 1 -Exactly -ParameterFilter {
            $LDAPFilter -eq '(&(objectCategory=person)(objectClass=user)(userPrincipalName=a\2a\28b\29\5c\00\c3\a9@example.com))'
        }
    }
    It 'propagates directory errors' {
        Mock Get-ADUser -ModuleName IT-ToolBox {throw 'Access denied'}
        {Test-UPNExist -UPN 'john@example.com'} | Should -Throw '*Access denied*'
    }
    It 'rejects blank discovery and domain results' {
        Mock Get-ADDomainController -ModuleName IT-ToolBox {[pscustomobject]@{HostName=''}}
        {Test-UPNExist -UPN 'john@example.com'} | Should -Throw '*no hostname*'
        Mock Get-ADRootDSE -ModuleName IT-ToolBox {[pscustomobject]@{DefaultNamingContext=''}}
        {Test-UPNExist -UPN 'john@example.com' -SearchScope Domain} | Should -Throw '*no default naming context*'
    }
    It 'rejects missing ActiveDirectory commands clearly' {
        Mock Get-Command -ModuleName IT-ToolBox { $null } -ParameterFilter {$Name -eq 'Get-ADUser'}
        {Test-UPNExist -UPN 'john@example.com'} | Should -Throw '*requires Get-ADUser*'
    }
}

Describe 'UPN generation policy alignment' {
    BeforeEach { Mock Test-UPNExist -ModuleName IT-ToolBox { $false } }
    It 'rejects unsupported generated names before directory lookup: <First>' -ForEach @(
        @{First='José';Last='García';Separator='.'}
        @{First='.John';Last='Doe';Separator='.'}
        @{First='John.';Last='Doe';Separator='.'}
        @{First='John';Last='Doe';Separator='/'}
        @{First='John';Last='Doe';Separator='..'}
    ) {
        { Get-UniqueUPN -FirstName $First -LastName $Last -Separator $Separator -UPNSuffix example.com } | Should -Throw '*supported syntax policy*'
        Should -Invoke Test-UPNExist -ModuleName IT-ToolBox -Times 0 -Exactly
    }
    It 'preserves supported punctuation and IDN suffixes without transliteration' {
        $candidate=Get-UniqueUPN -FirstName Anne-Marie -LastName "O'Brien" -UPNSuffix 'bücher.example'
        $candidate | Should -BeExactly "anne-marie.o'brien@bücher.example"
        Test-IsValidUpn $candidate | Should -BeTrue
    }
    It 'accepts explicitly normalized names and returns a policy-valid collision candidate' {
        Mock Test-UPNExist -ModuleName IT-ToolBox { $UPN -ne 'jose.garcia2@example.com' }
        $candidate=Get-UniqueUPN -FirstName Jose -LastName Garcia -UPNSuffix example.com
        $candidate | Should -BeExactly 'jose.garcia2@example.com'
        Test-IsValidUpn $candidate | Should -BeTrue
    }
    It 'does not require an optional ADUser middle-name property under StrictMode' {
        $user=[pscustomobject]@{GivenName='Jane';Surname='Doe'}
        $user.PSObject.TypeNames.Insert(0,'Microsoft.ActiveDirectory.Management.ADUser')
        & {
            Set-StrictMode -Version Latest
            Get-UniqueUPN -ADObject $user -IncludeMiddleName -UPNSuffix example.com
        } | Should -BeExactly 'jane.doe@example.com'
    }
}
Describe 'UPN explicit server port validation' {
    It 'rejects an invalid numeric port without a directory call: <Port>' -ForEach @(
        @{Port='0'}; @{Port='65536'}; @{Port='99999'}
    ) {
        Mock Get-ADUser -ModuleName IT-ToolBox { throw 'Unexpected directory call' }
        { Test-UPNExist -UPN 'john@example.com' -SearchScope Domain -AdServer "dc.example.com:$Port" } | Should -Throw
        { Get-UniqueUPN -FirstName John -LastName Doe -UPNSuffix example.com -AdServer "dc.example.com:$Port" } | Should -Throw
        Should -Invoke Get-ADUser -ModuleName IT-ToolBox -Times 0 -Exactly
    }
}

AfterAll { Remove-Module IT-ToolBox -ErrorAction SilentlyContinue }
