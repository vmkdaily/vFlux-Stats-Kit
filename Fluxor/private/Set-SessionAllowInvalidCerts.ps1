Function Set-SessionAllowInvalidCerts {
    
    <#
        .DESCRIPTION
            Creates a TrustAllCertsPolicy for this session.
            Supports only Windows Desktop builds of PowerShell
            such as version 3.0, 4.0, 5.0 and 5.1. Does not support PowerShell Core.
            If Core CLR is detected, we skip.
        
        .NOTES
            Script:       Set-SessionAllowInvalidCerts
            Author:       Mike Nisk
            Prior Art:    Uses code from: http://www.virtuallyghetto.com/2017/02/automating-vsphere-global-permissions-with-powercli.html

        .EXAMPLE
        Set-SessionAllowInvalidCerts

        This example illustrates running the command; It has no parameters.
    
    #>
    
    [CmdletBinding()]
    param()

    Process {

        ## Skip if CoreCLR
        If($IsCoreCLR -eq $null -or $IsCoreCLR -eq $false){
        
            ## Add .NET class to this PowerShell session if needed
            If('TrustAllCertsPolicy' -as [type]){
                Write-Verbose -Message 'Skipping TrustAllCertsPolicy setup (System already has it)!'
            }
            else{
              
              ## Announce action
              Write-Verbose -Message 'Creating a TrustAllCertsPolicy for this runtime'
              
              ## Some lines Padded Left by design; Do not move.
              Add-Type -ErrorAction SilentlyContinue -TypeDefinition  @"
using System.Net;
using System.Security.Cryptography.X509Certificates;
public class TrustAllCertsPolicy : ICertificatePolicy {
public bool CheckValidationResult(
ServicePoint srvPoint, X509Certificate certificate,
WebRequest request, int certificateProblem) {
return true;
}
}
"@
#End of padding
                ## New object
                try{
                    [System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy -ErrorAction Stop
                }
                catch{
                    Write-Error -Message $Error[0].exception.Message
                }
            } #End Else
        } #End If
        Else{
            Write-Verbose -Message 'Skipping TrustAllCertsPolicy setup since we are CoreCLR!' 
        }
    } #End Process
} #End Function