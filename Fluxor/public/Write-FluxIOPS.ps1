#requires -Version 3.0
Function Write-FluxIOPS {

  <#

      .DESCRIPTION
        Writes one or more IOPS stat objects containing Influx line protocol to an InfluxDB Server using PowerShell web cmdlets.
        
        To feed stats to this cmdlet, use Get-FluxIOPS.

      .NOTES
        Script:        Write-FluxIOPS.ps1
        Version:       1.0.0.1
        Prior Art:     Based on vFlux Stats Kit
        Author:        Mike Nisk
        Supports:      Core Editions of PowerShell 6.0 and later (including 6.1), and PowerShell 3.0 to 5.1
        Supports:      Windows, Linux, macOS as clients for collecting and writing stats
        Supports:      Windows only (and non-core edition of PowerShell) for Credential on disk feature (optional)
        Known Issues:  InfluxDB needs a PowerShell culture of en-US for InfluxDB writes that are float (i.e. 97.5).
        
      .PARAMETER Server
        String. The IP Address or DNS name of exactly one InfluxDB Server machine (or localhost).
        If not populated, we use the value indicated in the "InfluxDB Prefs" section of the script.

      .PARAMETER Credential
        PSCredential. Optionally, provide a PSCredential containing the login for InfluxDB Server.
        If not populated, we use the value indicated in the "InfluxDB Prefs" section of the script.

      .PARAMETER CredentialPath
        String. Optionally, provide the path to a PSCredential on disk such as "$HOME/CredsVcLab.enc.xml".
        This is a Windows only feature.

      .PARAMETER Port
        Integer. The InfluxDB Port to connect to.

      .PARAMETER Database
        String. The name of the InfluxDB database to write to.

      .PARAMETER InputObject
        Object. A PowerShell object to write to InfluxDB. The InputObject parameter requires strict InluxDB line protocol syntax such as that returned by Get-FluxIOPS.
      
      .PARAMETER Throttle
        Switch. Optionally, activate the Throttle switch to limit total InfluxDB connections to 2 for this runtime.
        By default we close the connection after each write, so this is not needed. Using the Throttle switch is
        slightly more elegant than the default, and is recommended for power users. The benefit would be that
        instead of closing all connections from client to InfluxDB, we simply limit the maximum to 2.

      .PARAMETER ShowRestActivity
        Switch. Optionally, return additional REST connection detail by setting to $true. Only works when the Verbose switch is also used.
      
      .PARAMETER ShowModuleEfficiency
        Switch. Optionally, show the start and end of the function as it is called. This is only to highlight differences between piping and using variable and is only observable in Verbose mode. Hint piping is less efficient for us.
      
      .PARAMETER PassThru
        Switch. Optionally, return output (if any) from the web cmdlet write operation. There should be no output on successful writes.
      
      .PARAMETER Strict
        Switch. Optionally, prevent fall-back to hard-coded script values for login

      .EXAMPLE
      Write-FluxIOPS -InputObject $iops

      This example shows the basic syntax. You would need to first populate the $iops variable using $iops = Get-FluxIOPS -Server 'myvcenter'.
      Notice there is no Server provided, because we expect you to be on localhost, though you could populate the Server parameter to write
      to a remote InfluxDB server. We use REST API either way (local or remote).

    #>

    [CmdletBinding()]
    param (
    
      #String. The IP Address or DNS name of exactly one InfluxDB Server machine (or localhost).
      [String]$Server,

      #PSCredential. Optionally, provide a PSCredential containing the login for InfluxDB Server.
      [PSCredential]$Credential,
      
      #String. Optionally, provide the string path to a PSCredential on disk (i.e. "$HOME/CredsVcLab.enc.xml').
      [string]$CredentialPath,

      #String. Optionally, enter a user for connecting to InfluxDB Server. This is exclusive of the PSCredential options.
      [string]$User,

      #String. Optionally, enter a password for connecting to InfluxDB Server. This is exclusive of the PSCredential options.
      [string]$Password,

      #Integer. The InfluxDB Port to connect to.
      [int]$Port,

      #String. The name of the InfluxDB database to write to.
      [string]$Database,

      #Object. A PowerShell object to write to InfluxDB. The InputObject parameter requires strict InluxDB line protocol syntax such as that returned by Get-FluxIOPS.
      [Parameter(Mandatory,ValueFromPipeline=$true)]
      [Alias('Stat')]
      [PSObject]$InputObject,

      #Switch. Optionally, activate the throttle switch to throttle total InfluxDB connections to 2 for this runtime. Only activate if having issues (i.e. first write works, and second one fails).
      [switch]$Throttle,
      
      #Switch. Optionally, return additional REST connection detail by setting to $true. Only works when the Verbose switch is also used.
      [switch]$ShowRestActivity,
      
      #Switch. Optionally, show the start and end of the function as it is called.
      [Switch]$ShowModuleEfficiency,

      #Switch. Optionally, return output (if any) from the web cmdlet write operation. There should be no output on successful writes.
      [switch]$PassThru,
      
      #Switch. Optionally, prevent fall-back to hard-coded script values.
      [switch]$Strict
      
    )
    
    Begin{
      ## Announce cmdlet start. This is skipped if we take pipeline input.
      If($ShowModuleEfficiency){
        Write-Verbose -Message ('Starting {0} at {1}' -f ($MyInvocation.Mycommand), (Get-Date -Format o))
      }
    }
    
    Process {

        ## InfluxDB Prefs
        $InfluxStruct = New-Object -TypeName PSObject -Property @{
            InfluxDbServer             = 'localhost'                                 #IP Address, DNS Name, or 'localhost'. Alternatively, populate the Server parameter at runtime.
            InfluxDbPort               = 8086                                        #The default for InfluxDB is 8086. Alternatively, populate the Port parameter at runtime.
            InfluxDbName               = 'iops'                                      #To follow my examples, set to 'iops' here and run "CREATE DATABASE iops" from Influx CLI if you have not already. To access the cli, SSH to your server and type influx.
            InfluxDbUser               = 'esx'                                       #This value is ignored in Strict mode. To follow the examples, set to 'esx' here and run "CREATE USER esx WITH PASSWORD esx WITH ALL PRIVILEGES" from Influx CLI. Not needed if PSCredential is provided.
            InfluxDbPassword           = 'esx'                                       #This value is ignored in Strict mode. To follow the examples, set to 'esx' here [see above example to create InfluxDB user and set password at the same time]. Not needed if PSCredential is provided.
            InfluxCredentialPath       = "$HOME/CredsInfluxDB.enc.xml"               #Credential files are not supported on Core editions of PowerShell. Path to encrypted xml Credential file on disk. We ignore plain text entries if this or Credential is populated. To create a PSCredential on disk see "help New-FluxCredential".
        }

        ## User Prefs
        [string]$Logging             = 'Off'                                         #PowerShell transcript logging 'On' or 'Off'
        [string]$LogDir              = $HOME                                         #PowerShell transcript logging location.  Optionally, set to something like "$HOME/logs" or similar.
        [string]$LogName             = 'fluxiops-ps-transcript'                      #PowerShell transcript name, if any. This is the leaf of the name only; We add extension and date later.
        [string]$dt                  = (Get-Date -Format 'ddMMMyyyy') | Out-String   #Creates one log file per day.
    
        #######################################
        ## No need to edit beyond this point
        #######################################

        ## Handle Server parameter
        If($Server){
            $InfluxStruct.InfluxDbServer = $Server
        }
        Else{
          $Server = $InfluxStruct.InfluxDbServer
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
            Elseif(Test-Path -Path $InfluxStruct.InfluxCredentialPath -ea 0){
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

        ## Create Rest header
        $authheader = 'Basic ' + ([Convert]::ToBase64String([Text.encoding]::ASCII.GetBytes(('{0}:{1}' -f $InfluxStruct.InfluxDbUser, $InfluxStruct.InfluxDbPassword))))
        
        ## URI for InfluxDB /write HTTP endpoint
        $uri = ('http://{0}:{1}/write?db={2}' -f $InfluxStruct.InfluxDbServer, $InfluxStruct.InfluxDbPort, $InfluxStruct.InfluxDbName)

        ## Handler for InfluxDB connection limit
        $ServicePoint = [System.Net.ServicePointManager]::FindServicePoint($uri)
        If($Throttle){
            $null = $ServicePoint.ConnectionLimit = 2
        }
        
        ## Logging
        If($Logging -eq 'On'){
            Start-Transcript -Append -Path ('{0}\{1}-{2}.log' -f $LogDir, $LogName, $dt)
        }

        ## Rest headers
        $headers = @{
            'Authorization' = $authheader
        }

        ## Report array for PassThru
        $resultInfo = @()
        
        ## Handle one or more InputObjects 
        Foreach($obj in $InputObject){
          
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
          $resultInfo += $result
        }

        ## Close it
        $null = $ServicePoint.CloseConnectionGroup('')
    }
    
    End {
        
        ## Session cleanup, InfluxDB
        $null = $ServicePoint.CloseConnectionGroup('')
    
        ## Stop transcript logging, if any
        If ($Logging -eq 'On') {
          Write-Verbose -Message 'Stopping transcript logging for this session'
            Stop-Transcript
        }
        
        ## Announce completion
        If($ShowModuleEfficiency){
          Write-Verbose -Message ('Ending {0} at {1}' -f ($MyInvocation.Mycommand), (Get-Date -Format o))
        }

        ## Output
        If($Passthru){
          return $resultInfo
        }
      } #End End
}