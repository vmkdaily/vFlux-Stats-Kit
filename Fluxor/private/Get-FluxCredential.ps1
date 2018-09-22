#Requires -Version 3
Function Get-FluxCredential {

  <#
      .DESCRIPTION
        Get a PSCredential from file for use with the Fluxor module.
        
        This function does not support Core Editions of PowerShell (i.e. not supported on Linux or macOS).
        
      .NOTES
        Script:     Get-FluxCredential.ps1
        Author:     Mike Nisk
        Prior Art:	Based on Import PSCredential by Hal Rottenberg
        Supports:   Windows PowerShell 3.0, 4.0, 5.0 and 5.1 only!

      .EXAMPLE
      $credsVC = Get-FluxCredential -Credential "$Home/CredsVcLab.enc.xml"
    
      This example imported a credential from disk and saved it to a variable for runtime use.

      .EXAMPLE
      $credsInflux = Get-FluxCredential -Credential "$Home/CredsInfluxDB.enc.xml"
    
      This example imported a credential from disk and saved it to a variable for runtime use.
    
      .OUTPUTS
      Encrypted credential saved to xml

  #>

  [CmdletBinding()]
  param (
  
    #PSCredential. A PSCredential object or string path to a PSCredential on disk.
    [Alias('Path')]
    [PSCredential]$Credential
  )
  
  Process {
    function Import-PSCredential {
      [CmdletBinding()]
      param ( $Path = "credentials.enc.xml" )

      # Import credential file
      $import = Import-Clixml $Path 
	
      # Test for valid import
      if ( !$import.UserName -or !$import.EncryptedPassword ) {
        Throw "Input is not a valid ExportedPSCredential object, exiting."
      }
      $Username = $import.Username
	
      # Decrypt the password and store as a SecureString object for safekeeping
      $SecurePass = $import.EncryptedPassword | ConvertTo-SecureString
	
      # Build the new credential object
      $Credential = New-Object System.Management.Automation.PSCredential $Username, $SecurePass
    }
    
    try{
      $result = Import-PSCredential -Path $Credential -ErrorAction Stop
    }
    catch{
      throw
    }
    return $result
  }
}