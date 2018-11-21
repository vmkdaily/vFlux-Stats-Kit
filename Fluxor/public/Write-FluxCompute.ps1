#requires -Version 3.0
Function Write-FluxCompute {

  <#

      .DESCRIPTION
        Writes one or more compute stat objects containing Influx line protocol to an InfluxDB Server using PowerShell web cmdlets. To feed stats to this cmdlet, use Get-FluxCompute.

      .NOTES
        Script:        Write-FluxCompute.ps1
        Module:        This function is part of the Fluxor module
        Author:        Mike Nisk
        Website:       Check out our contributors, issues, and docs for the vFlux-Stats-Kit at https://github.com/vmkdaily/vFlux-Stats-Kit/
        Supports:      Core Editions of PowerShell 6.x and later, and PowerShell 3.0 to 5.1
        Supports:      Windows, Linux, macOS
        Known Issues:  InfluxDB needs a PowerShell culture of en-US for InfluxDB writes that are float (i.e. 97.5)
        
      .PARAMETER Server
      String. The IP Address or DNS name of exactly one InfluxDB Server machine (or localhost). If not populated, we use the value indicated in the "InfluxDB Prefs" section of the script.

      .PARAMETER Credential
      PSCredential. Optionally, provide a PSCredential containing the login for InfluxDB Server. If not populated, we use the value indicated in the "InfluxDB Prefs" section of the script.
    
      .PARAMETER CredentialPath
      String. Optionally, provide the path to a PSCredential on disk such as "$HOME/CredsInfluxDB.enc.xml". This parameter is not supported on Core Editions of PowerShell.

      .PARAMETER Port
      Integer. The InfluxDB Port to connect to.

      .PARAMETER Database
      String. The name of the InfluxDB database to write to.

      .PARAMETER InputObject
      Object. One or more PowerShell objects to write to InfluxDB. This should be an array of line protocol. The InputObject parameter requires InluxDB line protocol syntax such as that returned by Get-FluxCompute.
      
      .PARAMETER Throttle
      Switch. Optionally, activate the Throttle switch to limit total InfluxDB connections to 2 for this runtime. By default we close the connection after each write, so this is not needed. Using the Throttle switch is slightly more elegant than the default, and is recommended for power users. The benefit would be that instead of closing all connections from client to InfluxDB, we simply limit the maximum to 2.
      
      .PARAMETER ShowRestActivity
      Switch. Optionally, return additional REST connection detail by setting to $true. Only works when the Verbose switch is also used.
      
      .PARAMETER ShowModuleEfficiency
      Switch. Optionally, show the start and end of the function as it is called.
    
      .PARAMETER Logging
      Boolean. Optionally, activate this switch to enable PowerShell transcript logging.

      .PARAMETER LogFolder
        String. The path to the folder to save PowerShell transcript logs. The default is $HOME.

      .PARAMETER PassThru
      Switch. Optionally, return output (if any) from the web cmdlet write operation. There should be no output on successful writes.

      .PARAMETER Strict
      Boolean. Prevents fall-back to hard-coded script values for InfluxDB login, if any.

      .EXAMPLE
      Write-FluxCompute -InputObject $stats

      This example shows the basic syntax. You would need to first populate the $stats variable using $stats = Get-FluxCompute -Server 'myvcenter'. Notice there is no Server provided, because we expect you to be on localhost, though you could populate the Server parameter to write to a remote InfluxDB server. We use REST API either way (local or remote).

  #>

    [CmdletBinding()]
    param(
    
      #String. The IP Address or DNS name of exactly one InfluxDB Server machine (or localhost).
      [String]$Server,

      #PSCredential. Optionally, provide a PSCredential containing the login for InfluxDB Server.
      [PSCredential]$Credential,
      
      #String. Optionally, provide the string path to a PSCredential on disk (i.e. "$HOME/CredsInfluxDB.enc.xml'). This parameter is not supported on Core Editions of PowerShell.
      [string]$CredentialPath,

      #String. Optionally, enter a user for connecting to InfluxDB Server. This is exclusive of the PSCredential options.
      [string]$User,

      #String. Optionally, enter a password for connecting to InfluxDB Server. This is exclusive of the PSCredential options.
      [string]$Password,

      #Integer. The InfluxDB Port to connect to.
      [int]$Port,

      #String. The name of the InfluxDB database to write to.
      [string]$Database,

      #Object. One or more PowerShell objects to write to InfluxDB. This should be an array of line protocol.
      [Parameter(Mandatory,ValueFromPipeline=$true)]
      [Alias('Stat')]
      [PSObject[]]$InputObject,

      #Switch. Optionally, activate the throttle switch to throttle total InfluxDB connections to 2 for this runtime. Only activate if having issues (i.e. first write works, and second one fails).
      [switch]$Throttle,
      
      #Switch. Optionally, return additional REST connection detail by setting to $true. Only works when the Verbose switch is also used.
      [switch]$ShowRestActivity,
      
      #Switch. Optionally, show the start and end of the function as it is called. This is only to highlight differences between piping and using variable and is only observable in Verbose mode. Hint piping is less efficient for us.
      [Switch]$ShowModuleEfficiency,
      
      #Boolean. Optionally, activate this switch to enable PowerShell transcript logging.
      [switch]$Logging,

      #String. The path to the folder to save PowerShell transcript logs. The default is $HOME.
      [Parameter(ParameterSetName='Default')]
      [ValidateScript({Test-Path $_ -PathType Container})]
      [string]$LogFolder = $HOME,

      #Switch. Optionally, return output (if any) from the web cmdlet write operation. There should be no output on successful writes.
      [switch]$PassThru,
      
      #Boolean. By default this is $true. The Strict parameter prevents fall-back to hard-coded script values for login to the InfluxDB Server. Set Strict to $false at runtime to consume the plain text values in the script.
      [bool]$Strict = $true
      
    )
    
    Begin{
      ## Announce cmdlet start. This is skipped if we take pipeline input.
      If($ShowModuleEfficiency){
        Write-Verbose -Message ('Starting {0} at {1}' -f ($MyInvocation.Mycommand), (Get-Date -Format o))
      }
    }
    
    Process {

      ## InfluxDB Prefs.
      $InfluxStruct = New-Object -TypeName PSObject -Property @{
          InfluxDbServer        = 'localhost'                                   #IP Address, DNS Name, or 'localhost'. Alternatively, populate the Server parameter at runtime.
          InfluxDbPort          = 8086                                          #The default for InfluxDB is 8086. Alternatively, populate the Port parameter at runtime.
          InfluxDbName          = 'compute'                                     #To follow the examples, set to 'compute' here and run "CREATE DATABASE compute" from Influx CLI if you have not already. To access the cli, SSH to your server and type influx.
          InfluxDbUser          = 'esx'                                         #This value is ignored in Strict mode. To follow the examples, set to 'esx' here and run "CREATE USER esx WITH PASSWORD esx WITH ALL PRIVILEGES" from Influx CLI. Not needed if PSCredential is provided.
          InfluxDbPassword      = 'esx'                                         #This value is ignored in Strict mode. To follow the examples, set to 'esx' here [see above example to create InfluxDB user and set password at the same time]. Not needed if PSCredential is provided.
          InfluxCredentialPath  = "$HOME\CredsInfluxDB.enc.xml"                 #Optionally, enter a path like "$HOME/CredsInfluxDB.enc.xml". Not supported on Core editions of PowerShell. This value is ignored if the Credential or CredentialPath parameters are populated. Optionally, enter the Path to encrypted xml Credential file on disk. To create a PSCredential on disk see "help New-FluxCredential".
      }

      ## Logging (only used if Logging switch is activated)
      [string]$LogDir           = $LogFolder
      [string]$LogName          = 'fluxcompute-ps-transcript'                   #PowerShell transcript name, if any. This is the leaf of the name only; We add extension and date later.
      [string]$dt               = (Get-Date -Format 'ddMMMyyyy') | Out-String   #Creates one log file per day.
    
      #######################################
      ## No need to edit beyond this point
      #######################################

      ## Handle Server parameter
      If($Server){
          $InfluxStruct.InfluxDbServer = $Server
      }

      ## Handle credential from disk
      If(!$Credential -and !$User){
        If($IsCoreCLR){
          Write-Verbose -Message 'Running on Core Edition of PowerShell'
        }
        Else{
          If($CredentialPath){
            $Credential = Get-FluxCredential -Path $CredentialPath
          }
          Elseif($null -ne $InfluxStruct.InfluxCredentialPath -and ($InfluxStruct.InfluxCredentialPath).length -gt 0){
            $Credential = Get-FluxCredential -Path $InfluxStruct.InfluxCredentialPath
          }
          Else{
            throw 'Script cannot proceed without InfluxDB login!'
          }
        }
      }

      ## Handle Credential parameter
      If($Credential){
        $InfluxStruct.InfluxDbUser = $Credential.GetNetworkCredential().UserName
        $InfluxStruct.InfluxDbPassword = $Credential.GetNetworkCredential().Password
      }
      ## Handle User and Password parameter
      Elseif($user -and $Password){
        $InfluxStruct.InfluxDbUser = $User
        $InfluxStruct.InfluxDbPassword = $Password
      }
      Elseif($Strict){
        Throw 'InfluxDB login required!'
      }
      Else{
        Write-Verbose -Message ('Connecting to influxdb as {0}' -f $InfluxStruct.InfluxDbUser)
      }
        
      ## Handle Port
      If($Port){
          $InfluxStruct.InfluxDbPort = $Port
      }
        
      ## Handle InfluxDB database name
      If($Database){
          $InfluxStruct.InfluxDbName = $Database
      }

      ## Create the Rest header
      $authheader = 'Basic ' + ([Convert]::ToBase64String([Text.encoding]::ASCII.GetBytes(('{0}:{1}' -f $InfluxStruct.InfluxDbUser, $InfluxStruct.InfluxDbPassword))))
        
      ## URI for InfluxDB /write HTTP endpoint
      $uri = ('http://{0}:{1}/write?db={2}' -f $InfluxStruct.InfluxDbServer, $InfluxStruct.InfluxDbPort, $InfluxStruct.InfluxDbName)

      ## Handler for InfluxDB connection limit
      $ServicePoint = [System.Net.ServicePointManager]::FindServicePoint($uri)
      If($Throttle){
          $null = $ServicePoint.ConnectionLimit = 2
      }
        
      ## Logging
      If($Logging){
          Start-Transcript -Append -Path ('{0}/{1}-{2}.log' -f $LogDir, $LogName, $dt)
      }

      ## Rest headers
      $headers = @{
          'Authorization' = $authheader
      }
      
      foreach($obj in $InputObject){
        ## Handle Rest parameters
        $sParamRest = @{
            'Headers'     = $headers
            'Uri'         = $uri
            'Method'      = 'POST'
            'Body'        = $obj
            'Verbose'     = $ShowRestActivity
            'ErrorAction' = 'Stop'
        }

        ## Write it
        Try {
            $result = (Invoke-RestMethod @sParamRest)
        }
        Catch {
            Write-Warning -Message 'Problem writing object to InfluxDB!'
            Write-Warning -Message ('{0}' -f $_.Exception.Message)
            throw
        }

        ## Close it
        $null = $ServicePoint.CloseConnectionGroup('')
      }
  }
  
  End {
        
      ## Session cleanup, InfluxDB
      $null = $ServicePoint.CloseConnectionGroup('')
    
      ## Stop transcript logging, if any
      If ($Logging) {
        Write-Verbose -Message 'Stopping transcript logging for this session'
          Stop-Transcript
      }
        
      ## Announce completion
      If($ShowModuleEfficiency){
        Write-Verbose -Message ('Ending {0} at {1}' -f ($MyInvocation.Mycommand), (Get-Date -Format o))
      }

      ## Output
      If($Passthru){
        return $result
      }
  } #End End
}