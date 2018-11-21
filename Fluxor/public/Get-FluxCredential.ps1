#Requires -Version 3
Function Get-FluxCredential {

  <#
      .DESCRIPTION
        Get a PSCredential from file for use with the Fluxor module by populating the Path parameter. This function does not support Core Editions of PowerShell.
        
        With no parameters, the script returns a list of *.enc.xml files from the $HOME directory.
        
      .NOTES
        Script:     Get-FluxCredential.ps1
        Module:     This function is part of the Fluxor module
        Author:     Mike Nisk
        Website:    Check out our contributors, issues, and docs for the vFlux-Stats-Kit at https://github.com/vmkdaily/vFlux-Stats-Kit/
        Prior Art:	This function is based on Import PSCredential by Hal Rottenberg.
        Supports:   Not supported on Core Editions of PowerShell.

      .PARAMETER Path
        String. The path to a PSCredential on disk.
    
      .PARAMETER ListAvailable
        #Switch. Return a list of all "*.enc.xml" files in your ListLocation ($HOME directory by default).
    
      .PARAMETER ListLocation
        String. The path to folder where your credential files on disk, if any, are located.
    
      .PARAMETER Expected
        Switch. Optionally, activate the Expected switch to only show the offical cred file names we expect (i.e. created by New-FluxCredential).
    
      .EXAMPLE
      Get-FluxCredential

      This example runs the function with no parameters. This will perform a ListAvailable to show any credential files in the $HOME directory.

      .EXAMPLE
      $credsVC = Get-FluxCredential -Path "$Home/CredsVcLab.enc.xml"
    
      This example imported a credential from disk and saved it to a variable for runtime use.

      .EXAMPLE
      $credsInflux = Get-FluxCredential -Path "$Home/CredsInfluxDB.enc.xml"
    
      This example imported a credential from disk and saved it to a variable for runtime use.

      .INPUTS
      encrypted xml credential file

      .OUTPUTS
      PSCredential Object

  #>

  [CmdletBinding(DefaultParameterSetName='ByPathSet')]
  param (
  
    #String. The path to a PSCredential on disk such as "$Home/CredsVcProd.enc.xml"
    [Parameter()]
    [string]$Path
  )
  
  Process {
    
    If($null -ne $path){
      function Import-PSCredential {
        [CmdletBinding()]
        param (
          [string]$Path
        )
    
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

          return $Credential
      }
        
      try{
        $result = Import-PSCredential -Path $Path -ErrorAction Stop
      }
      catch{
        throw $_
      }
      return $result
    }
  }
}