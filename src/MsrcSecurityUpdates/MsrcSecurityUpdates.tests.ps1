
# Import module would only work if the module is found in standard locations
# Import-Module -Name MsrcSecurityUpdates -Force
$Error.Clear()
Get-Module -Name MsrcSecurityUpdates | Remove-Module -Force -Verbose:$false
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'MsrcSecurityUpdates.psd1') -Verbose:$false -Force

Describe 'API version after module loading' {
    It '$msrcApiUrl = https://api.msrc.microsoft.com/cvrf/v3.0' {
        $msrcApiUrl -eq 'https://api.msrc.microsoft.com/cvrf/v3.0' | Should Be $true
    }
    It '$msrcApiVersion = api-version=2023-11-01' {
        $msrcApiVersion -eq 'api-version=2023-11-01' | Should Be $true
    }
    Set-MSRCApiKey -APIVersion 2.0
    It '$msrcApiUrl = https://api.msrc.microsoft.com/cvrf/v2.0' {
        $msrcApiUrl -eq 'https://api.msrc.microsoft.com/cvrf/v2.0' | Should Be $true
    }
    It '$msrcApiVersion = api-version=2016-08-01' {
        $msrcApiVersion -eq 'api-version=2016-08-01' | Should Be $true
    }
}

'2.0','3.0' |
Foreach-Object {
    $v = $_
    Set-MSRCApiKey -APIVersion $_
    Describe ('Function: Get-MsrcDownload calls the the download function' -f $v) {
        It 'Get-MsrcDownload - all' {
            Get-MsrcDownload -monthOfInterest "2024-Jan" |
            Should Not Throw
        }
    }
}
#When a pester test fails, it writes out to stdout, and sets an error in $Error. When invoking powershell from C# it is a lot easier to read the stderr stream.
if($Error)
{
    Write-Error -Message 'A pester test has failed during the validation process'
}