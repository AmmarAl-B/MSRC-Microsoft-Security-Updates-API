Function Get-MsrcDownloadDialog {
<#
    .SYNOPSIS
        Get all download files from a MSRC CVRF document

    .DESCRIPTION
       Calls the MSRC CVRF API to get a CVRF document by ID and identifies all needed updates.

    .PARAMETER monthOfInterest
        Get the CVRF document for the specified CVRF ID (e.g. 2016-Aug)

    .PARAMETER AsXml
        Get the output as Xml

    .EXAMPLE
       Get-MsrcDownload -monthOfInterest 2016-Aug

    .NOTES
        An API Key for the MSRC CVRF API is not required anymore
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true, ParameterSetName='UpdateID')]
    [String]$UpdateID
)

Begin {}
Process {
        $updateIDs = "[{""size"":0, ""languages"":"""", ""uidInfo"": ""$UpdateID"", ""updateID"": ""$UpdateID""}]"
        # Build the request hashtable for Invoke-WebRequest.
        $WebRequest = @{
            uri         = 'https://catalog.update.microsoft.com/DownloadDialog.aspx'
            Headers = @{
                "Accept" = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
                "Accept-Encoding" = "gzip, deflate, br, zstd"
                "Accept-Language" = "en-US,en;q=0.5"
                "Host" = "catalog.update.microsoft.com"
                "Origin" = "https://catalog.update.microsoft.com"
                "Referer" = "https://catalog.update.microsoft.com/DownloadDialog.aspx"
                "Sec-Fetch-Dest" = "document"
                "Sec-Fetch-Mode" = "navigate"
                "Sec-Fetch-Site" = "same-origin"
                "Sec-Fetch-User" = "?1"
                "Upgrade-Insecure-Requests" = "1"
                "User-Agent" = "Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:135.0) Gecko/20100101 Firefox/135.0"
            }
            Body = @{
                "updateIDs" = $UpdateIDs
                "updateIDsBlockedForImport" = ""
                "wsusApiPresent" = ""
                "contentImport" = ""
                "sku" = ""
                "serverName" = ""
                "ssl" = ""
                "portNumber" = ""
                "version" = ""
            }
            WebSession = $Session
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

        try {
            # [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls13

            $Response = Invoke-WebRequest @WebRequest -Method POST -UseBasicParsing

            $pattern = "downloadInformation\[0\]\.files\[0\]\.url\s*=\s*'([^']+)'"

            if ($Response.Content -match $pattern) {
                return $matches[1]
            }
        }
        catch {
            Write-Error "Error during Get-MsrcDownloadDialog: $($_.Exception.Message)"
            Write-Error -Message "HTTP Get failed for Dialog retrieval with status code $($_.Exception.Response.StatusCode): $($_.Exception.Response.StatusDescription)"
        }
    }
End {}
}