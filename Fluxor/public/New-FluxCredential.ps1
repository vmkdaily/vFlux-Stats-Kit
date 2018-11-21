#requires -version 3

  Function New-FluxCredential {
  
    <#
        .DESCRIPTION
          This is an optional function that we provide for Windows users to save a PSCredential to disk.
          Presents an interactive menu for users to create a credential file on disk. Supports creating
          local credential files for use with InfluxDB Server and vCenter Server connections.

          This function does not support Core Editions of PowerShell.

        .Notes
          Script:     New-FluxCredential.ps1
          Module:     This function is part of the Fluxor module
          Author:     Mike Nisk
          Website:    Check out our contributors, issues, and docs for the vFlux-Stats-Kit at https://github.com/vmkdaily/vFlux-Stats-Kit/
          Prior Art:	This function is based on Import PSCredential by Hal Rottenberg.
          Supports:   Not supported on Core Editions of PowerShell.
          
        .PARAMETER PATH
          String. The path to save outputted encrypted Credential files.  The Default Path is $HOME.
          The files are named automatically by the script.
      
        .EXAMPLE
        New-FluxCredential
    
        Welcome to New-FluxCredential!
        Credentials will be saved to C:\Users\mike

        Save Credential for:
        1. InfluxDB
        2. vCenter Lab
        3. vCenter Dev
        4. vCenter Prod
        5. vCenter Prod2

        X. Exit

        Select 1-5:

        This example launches the interactive menu to allow user to enter name and password, and
        save the resulting PSCredential file to disk. The resulting encrypted xml file will be
        saved to the default directory of $HOME, since Path was not specified.
      
        Please note the following default filenames created in your $HOME directory (depending on how many you configure):
      
        CredsInfluxDB.enc.xml
        CredsVcLab.enc.xml
        CredsVcDev.enc.xml
        CredsVcProd.enc.xml
        CredsVcProd2.enc.xml
 
        Note: Feel free to rename the credential files if desired. By default the Fluxor scripts will look for these in $HOME by one or more of the filenames above. You can also use the -CredentialPath parameter at runtime of Fluxor cmdlets to point to the desired Credential file, if any.
      
        .EXAMPLE
        New-FluxCredential -Path "$HOME/MyCreds"
    
        Consume the interactive menu and save the resulting Credential file to the desired path.
        Best practice is to keep these in your personal directory to avoid confusion with other
        users of the system. We use $HOME for the examples, which is the same as $env:USERPROFILE.

        .OUTPUTS
        Encrypted credentials saved to xml
    
    #>

    [CmdletBinding()]
    param (
      #String. The path to save outputted encrypted Credential files.  The Default Path is $HOME. The files are named automatically.
      [Alias('CredPath','ListLocation')]
      $Path = $HOME
    )

    Process {
      ## Windows classic PowerShell only (i.e. 3,4,5.x)
      If($IsCoreCLR){
      
        Write-Warning -Message 'This script does not support PowerShell Core!'
        return
      }
    
      ## PSCredential Functions by Hal Rottenberg
      function Export-PSCredential {
        param ( $Credential = (Get-Credential), $Path = "credentials.enc.xml" )

        # Handle $Credential parameter
        switch ( $Credential.GetType().Name ) {
          # It is a credential, so continue
          PSCredential{ continue }
          # It is a string, so use that as the username and prompt for the password
          String{ $Credential = Get-Credential -Credential $Credential }
          # In all other caess, throw an error and exit
          default{ Throw "You must specify a credential object to export to disk." }
        }
	
        # Create temporary object to be serialized to disk
        $export = "" | Select-Object Username, EncryptedPassword
	
        # Give object a type name which can be identified later
        $export.PSObject.TypeNames.Insert(0,'ExportedPSCredential')
	
        $export.Username = $Credential.Username

        # Encrypt SecureString password using Data Protection API. Only the current user account can decrypt this cipher
        $export.EncryptedPassword = $Credential.Password | ConvertFrom-SecureString

        # Export using the Export-Clixml cmdlet
        $export | Export-Clixml $Path
        Write-Host -ForegroundColor Green "Credentials saved to: " -noNewLine

        # Return FileInfo object referring to saved credentials
        Get-Item $Path
      }

      ## clear screen
      Clear-Host

      ## Welcome
      Write-Host ""
      Write-Host "Welcome to New-FluxCredential!" -ForegroundColor Yellow
      Write-Host ('Credentials will be saved to {0}' -f $Path) -ForegroundColor Yellow
      Write-Host ""

      $fileList = @(
        'CredsInfluxDB.enc.xml',
        'CredsVcLab.enc.xml',
        'CredsVcDev.enc.xml',
        'CredsVcProd.enc.xml',
        'CredsVcProd2.enc.xml'
      )
      
      Write-Host "Expected Credential files:"
      Write-Host ''
      $FileList | ForEach-Object {
        If(Test-Path "$Path\$_" -ea 0){
          $result = Get-ChildItem "$Path\$_" | Select-Object -ExpandProperty FullName
    
          ## Output, found
          Write-Host ('    {0}' -f $result) -ForegroundColor Green -BackgroundColor DarkGreen
        }
        Else{
          ## Output, not found
          Write-Host ('{0}' -f $_) -ForegroundColor Red -BackgroundColor DarkRed
        }
      }
      
      ## Select function MENU
      Write-Host ''
      Write-Host "Save Credential for:" -ForegroundColor Green
      Write-Host "1. InfluxDB"
      Write-Host "2. vCenter Lab"
      Write-Host "3. vCenter Dev"
      Write-Host "4. vCenter Prod"
      Write-Host "5. vCenter Prod2"
      Write-Host " "
      Write-Host "X. Exit"
      Write-Host ""

      ## Main
      Try {
        $prompt = Read-Host "Select 1-5"

        switch ($prompt) {
          1{
                ## InfluxDB Creds
                Write-Host "Enter your InfluxDB login" -ForegroundColor Yellow
                $CredsInfluxDB = Get-Credential
                Export-PSCredential -Credential $CredsInfluxDB -Path (Join-Path -Path $Path -ChildPath 'CredsInfluxDB.enc.xml')
          }
          2 {
                ## vCenter Lab Creds
                Write-Host "Enter your vCenter Login" -ForegroundColor Yellow
                $CredsVcLab = Get-Credential
                Export-PSCredential -Credential $CredsVcLab -Path (Join-Path -Path $Path -ChildPath 'CredsVcLab.enc.xml')
          }
          3 {
                ## vCenter Development Creds
                Write-Host "Enter your vCenter Login" -ForegroundColor Yellow
                $CredsVcDev = Get-Credential
                Export-PSCredential -Credential $CredsVcDev -Path (Join-Path -Path $Path -ChildPath 'CredsVcDev.enc.xml')
          }
          4 {
                ## vCenter Production Creds
                Write-Host "Enter your vCenter Login" -ForegroundColor Yellow
                $CredsVcProd = Get-Credential
                Export-PSCredential -Credential $CredsVcProd -Path (Join-Path -Path $Path -ChildPath 'CredsVcProd.enc.xml')
          }
          5 {
                ## vCenter Production Creds 2
                Write-Host "Enter your vCenter Login" -ForegroundColor Yellow
                $CredsVcProd2 = Get-Credential
                Export-PSCredential -Credential $CredsVcProd2 -Path (Join-Path -Path $Path -ChildPath 'CredsVcProd2.enc.xml')
          }
          x {
                break;
          } 
          default {
                Write-Host "** The selection could not be determined **" -ForegroundColor Red
          }
        }
      }

      Finally {
    
        Write-Verbose -Message "Script Complete."
      }
    }
  }