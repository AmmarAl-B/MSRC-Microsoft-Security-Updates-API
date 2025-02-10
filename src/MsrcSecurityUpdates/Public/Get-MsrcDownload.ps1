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
    [ValidatePattern('^\d{4}-(Jan|Feb|Mer|Apr|Mai|Jun|Jul|Aug|Sep|Nov|Dez)$')]
    [String]$monthOfInterest
)

Begin {
    $CVRFDoc = Get-MsrcCvrfDocument -ID $monthOfInterest -Verbose
    $affectedSoftware = Get-MsrcCvrfAffectedSoftware -Vulnerability $CVRFDoc.Vulnerability -ProductTree $CVRFDoc.ProductTree

    $global:downloadLinks = @()
    $affectedSoftware | ForEach-Object {
        if ($_.KBArticle.URL -match "catalog.update.microsoft" -and $_.FullProductName -match "Windows 11") {
            $global:downloadLinks += $_.KBArticle.URL 
        }
    }
    $global:downloadLinks = $global:downloadLinks | Sort-Object -Unique
}

Process {
    # Build the request hashtable for Invoke-WebRequest.
    $WebRequest = @{
        Headers = @{
            'Accept' = {'application/xml'}
        }
        ErrorAction = 'Stop'
    }

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

    foreach ($currentLink in $global:downloadLinks) {

        try {
            # [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls13
            $Response = Invoke-WebRequest @WebRequest -Uri $currentLink -UseBasicParsing

            $InputFields = $Response.InputFields | Where-Object { $_.class -Match "flatBlueButtonDownload"}

            foreach($Field in $InputFields) {
                $Id = $Field.id

                $DownloadURL = Get-MsrcDownloadDialog -UpdateID $Id
                
                $FileName = $DownloadURL.Replace('/', '').Replace('\', '').Replace(':','').Replace('"','').Replace('?','').Replace('<','').Replace('>','').Replace('*','').Replace('|','')
                $FolderPath = "$env:USERPROFILE\Downloads\" + $($FileName)

                Invoke-WebRequest $DownloadURL -OutFile $FolderPath -UseBasicParsing -ErrorAction Stop
            }
        }
        catch {
            Write-Error "Error during Get-MsrcDownload: $($_.Exception.Message)"
            Write-Error -Message "HTTP Get failed for catalog retrieval with status code $($_.Exception.Response.StatusCode): $($_.Exception.Response.StatusDescription)"
        }
    }
}
End {}
}
