Function Get-MsrcDownload {
<#
    .SYNOPSIS
        Get all download files from a MSRC CVRF document

    .DESCRIPTION
       Calls the MSRC CVRF API to get a CVRF document by ID and identifies all needed updates.

    .PARAMETER monthOfInterest
        Get the CVRF document for the specified CVRF ID (e.g. 2016-Aug)

    .EXAMPLE
       Get-MsrcDownload -monthOfInterest 2016-Aug

    .NOTES
        An API Key for the MSRC CVRF API is not required anymore
#>
[CmdletBinding()]
Param (
    [Parameter(ParameterSetName='monthOfInterest')]
    [ValidatePattern('^\d{4}-(Jan|Feb|Mer|Apr|Mai|Jun|Jul|Aug|Sep|Nob|Dez)$')]
    [String]$monthOfInterest
)

Begin {
    $CVRFDoc = Get-MsrcCvrfDocument -ID $monthOfInterest -Verbose
    $affectedSoftware = Get-MsrcCvrfAffectedSoftware -Vulnerability $CVRFDoc.Vulnerability -ProductTree $CVRFDoc.ProductTree

    $global:downloadLinks = @()
    $affectedSoftware.FullProductName | Sort-Object -Unique | ForEach-Object {
        $PN = $_
        $affectedSoftware | Where-Object { $_.FullProductName -eq $PN } | ForEach-Object {
            if ($_.KBArticle.URL -ne "" -and -not($_.KBArticle.URL -Match "/download/dotnet/")) {
                $global:downloadLinks += $_.KBArticle.URL 
            }
        }
    }
}

Process {
    foreach ($currentLink in $global:downloadLinks) {

        # Build the request hashtable for Invoke-WebRequest.
        $WebRequest = @{
            Uri         = $currentLink
            Headers = @{
                'Accept' = {'application/xml'}
            }
            ErrorAction = 'Stop'
        }

        $Session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

        # Add proxy settings if required.
        if ($global:msrcProxy) {
            $WebRequest['Proxy'] = $global:msrcProxy
        }
        if ($global:msrcProxyCredential) {
            $WebRequest['ProxyCredential'] = $global:msrcProxyCredential
        }
        if ($global:MSRCAdalAccessToken) {
            $WebRequest.Headers['Authorization'] = $global:MSRCAdalAccessToken.CreateAuthorizationHeader()
        }

        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

            $Response = Invoke-WebRequest @WebRequest -WebSession $Session

            $InputFields = $Response.InputFields | Where-Object { $_.class -Match "flatBlueButtonDownload"}

            foreach($Field in $InputFields) {
                $Id = $Field.id

                $DownloadURL = Get-MsrcDownloadDialog -UpdateID $Id

                Invoke-WebRequest $downloadURL -OutFile $env:USERPROFILE\Downloads\download.msu
            }
        }
        catch {
            Write-Error "Error during Get-MsrcDownloadDialog: $($_.Exception.Message)"
            Write-Error -Message "HTTP Get failed for catalog retrieval with status code $($_.Exception.Response.StatusCode): $($_.Exception.Response.StatusDescription)"
        }
    }
}
End {}
}