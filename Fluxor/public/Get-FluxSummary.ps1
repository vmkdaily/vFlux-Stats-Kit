#requires -Module VMware.Vimautomation.Core
Function Get-FluxSummary {

  <#

      .DESCRIPTION
        Gathers basic VMware vSphere summary information such as amount of cpu and memory for virtual machines or ESXi hosts.

      .NOTES
        Script:     Get-FluxSummary.ps1
        Author:     Mike Nisk
        Prior Art:  Based on vFlux Stats Kit
        Supports:   PSEdition Core 6.x, and PowerShell 3.0 to 5.1
        Supports:   PowerCLI 6.5.4 or later (10.x preferred)
        Supports:   Windows, Linux, macOS

      .PARAMETER Server
        String. The IP Address or DNS name of exactly one vCenter Server machine. For IPv6, enclose address in square brackets, for example [fe80::250:56ff:feb0:74bd%4].
    
      .PARAMETER Credential
        PSCredential. Optionally, provide a PSCredential containing the login for vCenter Server.

      .PARAMETER CredentialPath
        String. Optionally, provide the path to a PSCredential on disk such as "$HOME/CredsVcLab.enc.xml". This parameter is not supported on Core Editions of PowerShell.

      .PARAMETER User
        String. Optionally, enter a user for connecting to vCenter Server.

      .PARAMETER Password
        String. Optionally, enter a password for connecting to vCenter Server.
      
      .PARAMETER ReportType
        String. The entity type to get summary details from ('VM' or 'VMHost'). The default is VM which returns stats for all virtual machines. To return host stats instead of virtual machines, tab complete or enter 'VMHost' as the value for the ReportType parameter.

      .PARAMETER OutputPath
        String. Only needed if saving to file. To use this parameter, enter the path to a folder such as $HOME or "$HOME/MyStats". This should be of type container (i.e. a folder). We will automatically create the filename for each stat result and save save the results in line protocol.

      .PARAMETER PassThru
        Switch. Optionally, return native vSphere stat objects instead of line protocol.
      
      .PARAMETER IgnoreCertificateErrors
        Switch. Alias Ice. This parameter should not be needed in most cases. Activate to ignore invalid certificate errors when connecting to vCenter Server. This switch adds handling for the current PowerCLI Session Scope to allow invalid certificates (all client operating systems) and for Windows PowerShell versions 3.0 through 5.1. We also add a temporary runtime dotnet type to help the current session ignore invalid certificates. If you find that you are still having issues, consider downloading the certificate from your vCenter Server instead.

      .PARAMETER Logging
        Boolean. Optionally, activate this switch to enable PowerShell transcript logging.

      .PARAMETER MaxJitter 
        Integer. The maximum time in seconds to offset the start of stat collection. Set to 0 for no jitter or keep the default which jitters for a random time up to MaxJitter. Use this to prevent spikes on localhost when running many jobs.

      .PARAMETER Supress
        Switch. Optionally, activate the Supress switch to prevent Fluxor jobs from running up to the maximium of MaxSupressionWindow.
      
      .PARAMETER Resume
        Switch. Optionally, resume collection if it has been paused with the Supress parameter. Alternatively, wait for MaxSupressionWindow to automatically resume the collection.
      
      .PARAMETER MaxSupressionWindow
        Integer. The maximum allowed time in minutes to miss collections due to being supressed with the Supress switch. The default is 20.

      .PARAMETER Strict
        Boolean. Prevents fall-back to hard-coded script values for login credential if any.

      .EXAMPLE
      $vc = 'vcvsa01.lab.local'
      Get-FluxSummary -Server $vc | Write-FluxSummary

      This example collected summary information for virtual machines and wrote the data points to InfluxDB by piping the object returned from Get-FluxSummary into Write-FluxSummary.

      .EXAMPLE
      $summaryVM = Get-FluxSummary -Server $vc
      Write-FluxSummary -InputObject $summaryVM

      Get the summary data points for virtual machines and write them to InfluxDB using a variable (more performant than the pipeline).

      .EXAMPLE
      $summaryVMHost = Get-FluxSummary -Server $vc -ReportType VMHost
      Write-FluxSummary -InputObject $summaryVMHost

      This example collected summary data points for ESXi hosts by using the ReportType parameter.

  #>

    [CmdletBinding()]
    param (
    
      #String. The IP Address or DNS name of exactly one vCenter Server machine.
      [string]$Server,

      #PSCredential. Optionally, provide a PSCredential containing the login for vCenter Server.
      [PSCredential]$Credential,
    
      #String. Optionally, provide the string path to a PSCredential on disk (i.e. "$HOME/CredsVcLab.enc.xml'). This parameter is not supported on Core Editions of PowerShell.
      [ValidateScript({Test-Path $_ -Type File})]
      [string]$CredentialPath,

      #String. Optionally, enter a user for connecting to vCenter Server. This is exclusive of the PSCredential options.
      [string]$User,

      #String. Optionally, enter a password for connecting to vCenter Server. This is exclusive of the PSCredential options.
      [string]$Password,
    
      #Switch. Optionally, select the report type to return. The default is virtual machine ('VM').
      [ValidateSet('VM','VMHost')]
      [Alias('Type')]
      [string]$ReportType = 'VM',

      #String. Optionally, provide the path to save the outputted results such as $HOME or "$HOME/myfluxLP"
      [ValidateScript({Test-Path $_ -Type Container})]
      [string]$OutputPath,

      #Switch. Optionally, return native vSphere stat objects instead of line protocol.
      [switch]$PassThru,

      #Switch. Optionally, ignore certificate errors when gathering stats from vCenter Server. Should not be needed in most cases.
      [Alias('Ice')]
      [switch]$IgnoreCertificateErrors,

      #Boolean. Optionally, activate this switch to enable PowerShell transcript logging.
      [switch]$Logging,
    
      #Integer. The maximum time in seconds to offset the start of stat collection. Set to 0 for no jitter or keep the default which jitters for a random time up to MaxJitter. Use this to prevent spikes on localhost when running many jobs.
      [ValidateRange(0,120)]
      [int]$MaxJitter = 0,
      
      #Switch. Optionally, activate the Supress switch to prevent Fluxor jobs from running up to the maximium of MaxSupressionWindow.
      [switch]$Supress,
      
      #Switch. Optionally, resume collection if it has been paused with the Supress parameter. Alternatively, wait for MaxSupressionWindow to automatically resume the collection.
      [switch]$Resume,
      
      #Integer. The maximum allowed time in minutes to miss collections due to being supressed with the Supress switch. The default is 20.
      [int]$MaxSupressionWindow = 20,
      
      #Boolean. Prevents fall-back to hard-coded script values for login credential if any.
      [bool]$Strict = $true

    )

    Begin {
        ## Announce cmdlet start
        Write-Verbose -Message ('Starting {0} at {1}' -f ($MyInvocation.Mycommand), (Get-Date -Format o))

        ## Handle PowerShell transcript Logging
        If($Logging){
          [string]$LogDir              = $HOME                                         #PowerShell transcript logging location.  Optionally, set to something like $HOME/logs
          [string]$LogName             = 'flux-summary-ps-transcript'                  #PowerShell transcript name, if any. This is the leaf of the name only; We add extension and date later.
          [string]$dt                  = (Get-Date -Format 'ddMMMyyyy') | Out-String   #Creates one log file per day
        }
        
        ## Output file name leaf (only used when OutputPath is populated)
        [string]$statLeaf              = 'flux-summary'                                #If writing to file, this is the leaf of the stat output file. We add a generated guid and append .txt later
        
        ## Handle spaces in virtual machine names
        [string]$DisplayNameSpacer     = '\ '                                          #We perform a replace ' ', $DisplayNameSpacer later in the script. What you enter here is what we replace spaces with. Using '\ ' maintains the spaces, while '_' results in an underscore.
        
        ## Handle Credential from disk by hard-coded path
        [string]$vcCredentialPath      = "$HOME/CredsLabVC.enc.xml"                    #Not supported on Core editions of PowerShell. This value is ignored if the Credential or CredentialPath parameters are populated. Optionally, enter the Path to encrypted xml Credential file on disk. To create a PSCredential on disk see "help New-FluxCredential".
      
        ## Handle plain text credential
        If($Strict -eq $false){
          [string]$vcUser              = 'flux-read-only@vsphere.local'                #This value is ignored in Strict mode or if we have PSCredential. Optionally, enter an existing read-only user on vCenter Server
          [string]$vcPass              = 'VMware123!!'                                 #This value is ignored in Strict mode or if we have PSCredential. Optionally, enter the password for the desired vCenter Server user.
        }
      
        #######################################
        ## No need to edit beyond this point
        #######################################
      
    } #End Begin

    Process {

      ## Handle name of supress file
      $supressFile = ('{0}/supress-flux.txt' -f $HOME)
        
      ## Handle Supress parameter
      If($Supress){
        $null = New-Item -ItemType File -Path $supressFile -Confirm:$false -Force
        return
      }
        
      If($Resume){
        $null = Remove-Item -Path $supressFile -Confirm:$false -Force
        return
      }
        
      ## Supress collection, if needed.
      [bool]$exists = Test-Path -Path $supressFile -PathType Leaf
      If($exists){
        $item = Get-Item -Path $supressFile | Select-Object -First 1
        $itemAgeMinutes = [int]((Get-Date)-(Get-Date  -Date $item.LastWriteTime) | Select-Object -ExpandProperty Minutes)
        If($itemAgeMinutes -lt $MaxSupressionWindow){
            Write-Verbose -Message 'Fluxor running in supress mode; No stats will be collected!'
            return
        }
        Else{
          Write-Verbose -Message ('Cleaning up old supress file at {0}' -f $supressFile)
          try{
            $null = Remove-Item -Path $supressFile -Confirm:$false -Force -ErrorAction Stop
          }
          catch{
            Write-Warning -Message ('Problem removing supress file at {0}!' -f $supressFile)
            Throw ('{0}' -f $_.Exception.Message)
          }
        }
      }
        
      ## Handle jitter
      If($MaxJitter -ge 1){
        [int]$intRandom = (1..$MaxJitter | Get-Random)
        Write-Verbose -Message ('Awaiting jitter offset of {0} seconds' -f $intRandom)
        Start-Sleep -Seconds $intRandom
      }
        
      If($PSVersionTable.PSVersion.Major -eq 3){
        [bool]$PSv3 = $true
      }
      
      ## Start Logging
      If($Logging){
          Start-Transcript -Append -Path ('{0}/{1}-{2}.log' -f $LogDir, $LogName, $dt)
      }
      
      ## Handle invalid certificate errors, if needed
      If($IgnoreCertificateErrors){
        
        ## Handle PowerShell invalid certificate errors
        $null = Set-SessionAllowInvalidCerts
        
        ## Handle PowerCLI invalid certificate errors
        $cliPref = Get-PowerCLIConfiguration -Scope Session
        [bool]$AlreadyIgnored = ($cliPref).InvalidCertificateAction -match '^Ignore'
        If(-Not($AlreadyIgnored)){
          Write-Verbose -Message 'Setting PowerCLI to allow invalid certs for this session'
          $null = Set-PowerCLIConfiguration -Scope Session -InvalidCertificateAction 'Ignore' -Confirm:$false -wa 0 -ea 0
        }
      }
      
      ## Handle existing connections, if any
      If($Server){
        If($Global:DefaultVIServers.Name -contains $Server){
          Write-Verbose -Message ('Using connection to {0}' -f $Server)
        }
        Else{
          [bool]$needsConnect = $true
        }
      }
      Else{
        ## Use the DefaultVIServer
        If($Global:DefaultVIServer.IsConnected){
          [string]$Server = $Global:DefaultVIServer | Select-Object -ExpandProperty Name
          Write-Verbose -Message ('Using connection to {0}' -f $Server)
        }
        Else{
          Throw 'Server parameter is required if not connected to a VIServer!'
        }
      }

      ## Connect to vCenter, if needed
      If($needsConnect -eq $true){
        If($Server){
          If(!$Credential -and !$User){
            If($IsCoreCLR){
              Write-Verbose -Message 'Running on PowerShell CoreCLR'
            }
            Else{
              If($CredentialPath){
                $Credential = Get-FluxCredential -Path $CredentialPath
              }
              Elseif(Test-Path -Path $vcCredentialPath -ErrorAction SilentlyContinue){
                $Credential = Get-FluxCredential -Path $vcCredentialPath
              }
            }
          }
    
          ## Consume PSCredential, if we have it
          If($Credential){
            try {
              $null = Connect-VIServer -Server $Server -Credential $Credential -WarningAction SilentlyContinue -ErrorAction Stop
              [bool]$runtimeConnection = $true
            }
            Catch {
              Write-Warning -Message ('{0}' -f $_.Exception.Message)
              throw
            }
          }
          Else{
            ## Handle user and Password parameters, if needed.
            If($user -and $Password){
              try {
                $null = Connect-VIServer -Server $Server -User $User -Password $Password -WarningAction SilentlyContinue -ErrorAction Stop
                [bool]$runtimeConnection = $true
              }
              Catch {
                Write-Warning -Message ('{0}' -f $_.Exception.Message)
                throw
              }
            }
            Elseif($vcUser -and $vcPass){
              try {
                ## Use hard-coded defaults, if Strict is false.
                $null = Connect-VIServer -Server $Server -User $vcUser -Password $vcPass -WarningAction SilentlyContinue -ErrorAction Stop
                [bool]$runtimeConnection = $true
              }
              Catch {
                Write-Warning -Message ('{0}' -f $_.Exception.Message)
                throw
              }
            }
            Else{
              ## Passthrough / SSPI
              try {
                $null = Connect-VIServer -Server $Server -WarningAction SilentlyContinue -ErrorAction Stop
                [bool]$runtimeConnection = $true
              }
              Catch {
                Write-Warning -Message ('{0}' -f $_.Exception.Message)
                throw
              }
            }
          }
        }
      }

      ## Announce collection start
      Write-Verbose -Message ('Beginning summary collection on {0}' -f $Server)

    ## Array to hold result objects
    If(-Not($OutputPath)){
        $Script:report = @()
    }
    Else{
      ## Handle output directory, if needed.
      $Script:strPath = Join-Path -Path $OutputPath -ChildPath $statLeaf
      If(-Not(Test-Path -Path $Script:strPath -PathType Container)){
        Write-Verbose -Message ('Creating output directory for stat collection at {0}' -f $Script:strPath)
        try{
          $null = New-Item -ItemType Directory -Path $Script:strPath -Confirm:$false -Force -WarningAction SilentlyContinue -ErrorAction Stop
        }
        catch{
          Write-Warning -Message ('Failed to create required folder at {0}!' -f $Script:strPath)
          throw ('{0}' -f $_.Exception.Message)
        }
      }
    }

    If($ReportType -eq 'VM'){

      ## Start script execution timer
      $vCenterStartDTM = (Get-Date)

      ## Enumerate VM list
      If($PSv3){
        try{
          $VMs = Get-VM -Server $Server -ErrorAction Stop | Where-Object {$_.PowerState -eq 'PoweredOn'} | Sort-Object -Property Name
        }
        catch{
          Write-Warning -Message 'Problem enumerating one or more virtual machines!'
          throw
        }
      }
      Else{
        try{
          $VMs = (Get-VM -Server $Server -ErrorAction Stop).Where{$_.PowerState -eq 'PoweredOn'} | Sort-Object -Property Name
        }
        catch{
          Write-Warning -Message 'Problem enumerating one or more virtual machines!'
          throw
        }
      }
        
      ## Handle PassThru mode
      If($PassThru){
        $Script:report += $VMs
      }
      Else{
        ## Handle file output, if needed
        If($Script:strPath){
          ## Create empty file
          [string]$strGuid = New-Guid | Select-Object -ExpandProperty Guid
          [string]$writeGuid = ('{0}-{1}' -f $statLeaf, $strGuid)
          [string]$outLeaf = Join-Path -Path $Script:strPath -ChildPath $writeGuid
          [string]$outFile = ('{0}.txt' -f $outLeaf)
          $null = New-Item -ItemType File -Path $outFile -Force
        }
      
        ## Handle each virtual machine
        foreach ($vm in $VMs){
            
            ## Handle name
            [string]$name = ($vm | Select-Object -ExpandProperty Name) -replace ' ',$DisplayNameSpacer
            
            ## Handle measurement name
            [string]$measurement = 'flux.summary.vm'
              
            ## Handle general info
            [int]$memorygb = $vm | Select-Object -ExpandProperty MemoryGB
            [string]$numcpu = $vm | Select-Object -ExpandProperty NumCPU
            [string]$type = 'VM' #derived
            [string]$vc = $Server
            
            ## Handle value and timestamp
            [string]$value = $vm.ExtensionData.OverallStatus
            [long]$timestamp = (([datetime]::UtcNow)-(Get-Date -Date '1/1/1970')).TotalMilliseconds * 1000000 #nanoseconds since Unix epoch
            
            ## Build it
            $MetricsString = ''
            $MetricsString += ('{0},host={1},memorygb={2},numcpu={3},type={4},vc={5} value="{6}" {7}' -f $measurement, $name, $memorygb, $numcpu, $type, $vc, $value, $timestamp)
            $MetricsString += "`n"
        
            ## Populate object with line protocol
            If(-Not($OutputPath)){
              $Script:report += $MetricsString
            }
            Else{
                ## Populate output file
                Try {
                  $null = Add-Content -Path $outFile -Value $MetricsString -Force -Confirm:$false
                }
                Catch {
                  Write-Warning -Message ('Problem writing {0} for {1} to file {2} at {3}' -f ($measurement), ($name), $outFile, (Get-Date))
                  Write-Warning -Message ('{0}' -f $_.Exception.Message)
                }
            }
        } #End Foreach

        ## Announce status of object or output file
        If(-Not($OutputPath)){
          If($report){
            Write-Verbose -Message 'Running in object mode; Data points collected successfully!'
          }
          Else{
            Write-Warning -Message 'Problem collecting one or more data points!'
          }
        }
        Else{
          If(Test-Path -Path $outFile -PathType Leaf){
            Write-Verbose -Message ('Write succeeded: {0}' -f $outFile)
          }
        }
        
        ## Runtime Summary
        $vCenterEndDTM = (Get-Date)
        $vmCount = ($VMs | Measure-Object).count
        $ElapsedTotal = ($vCenterEndDTM-$vCenterStartDTM).totalseconds

        ## Show per VM runtimes if, Verbose mode
        If($stats){
          If($PSCmdlet.MyInvocation.BoundParameters['Verbose']){
            Write-Verbose -Message ('Elapsed Processing Time: {0} seconds' -f ($ElapsedTotal))
            If($vmCount -gt 1) {
              $TimePerVM = $ElapsedTotal / $vmCount
              Write-Verbose -Message ('Processing Time Per VM: {0} seconds' -f ($TimePerVM))
            } #End If
          } #End If
        } #End If
      } #End Else
    } #End If
    
    If($ReportType -eq 'VMHost'){
      
      If($PSv3){
        $VMHosts = Get-VMHost -Server $Server | Where-Object {$_.State -eq 'Connected'} | Sort-Object -Property Name
      }
      Else{
        $VMHosts = (Get-VMHost -Server $Server).Where{$_.State -eq 'Connected'} | Sort-Object -Property Name
      }
      
      ## Handle PassThru Mode
      If($PassThru){
        $Script:report += $stats
      }
      Else{
        ## Handle file output, if needed
        If($Script:strPath){
          ## Create empty file
          [string]$strGuid = New-Guid | Select-Object -ExpandProperty Guid
          [string]$writeGuid = ('{0}-{1}' -f $statLeaf, $strGuid)
          [string]$outLeaf = Join-Path -Path $Script:strPath -ChildPath $writeGuid
          [string]$outFile = ('{0}.txt' -f $outLeaf)
          $null = New-Item -ItemType File -Path $outFile -Force
        }
         
        ## Iterate through ESXi Host list
        foreach($esx in $VMHosts){
            
            ## Handle name
            [string]$name = $esx | Select-Object -ExpandProperty Name
            
            ## Handle measurement name
            [string]$measurement = 'flux.summary.vmhost'
              
            ## Handle general info
            [int]$memorygb = $esx | Select-Object -ExpandProperty MemoryTotalGB
            [string]$numcpu = $esx | Select-Object -ExpandProperty NumCPU
            [string]$type = 'VMHost' #derived
            [string]$vc = $Server
            
            ## Handle value and timestamp
            [string]$value = $esx.ExtensionData.OverallStatus
            [long]$timestamp = (([datetime]::UtcNow)-(Get-Date -Date '1/1/1970')).TotalMilliseconds * 1000000  #nanoseconds since Unix epoch

            ## Build it
            $MetricsString = ''
            $MetricsString += ('{0},host={1},memorygb={2},numcpu={3},type={4},vc={5} value="{6}" {7}' -f $measurement, $name, $memorygb, $numcpu, $type, $vc, $value, $timestamp)
            $MetricsString += "`n"
          
            ## Populate object with line protocol
            If(-Not($OutputPath)){
              $Script:report += $MetricsString
            }
            Else{
                ## Populate output file
                Try{
                  $null = Add-Content -Path $outFile -Value $MetricsString -Force -Confirm:$false
                }
                Catch{
                  Write-Warning -Message ('Problem writing {0} for {1} to file {2} at {3}' -f ($measurement), ($name), $outFile, (Get-Date))
                  Write-Warning -Message ('{0}' -f $_.Exception.Message)
                }
            } #End Else
        } #End foreach
        
        ## Announce status of object or output file
        If(-Not($OutputPath)){
          If($report){
            Write-Verbose -Message 'Running in object mode; Data points collected successfully!'
          }
          Else{
            Write-Warning -Message 'Problem collecting one or more data points!'
          }
        }
        Else{
          If(Test-Path -Path $outFile -PathType Leaf){
            Write-Verbose -Message ('Write succeeded: {0}' -f $outFile)
          }
        }
      } #End Else
    } #End If
  } #End Process
    
  End {

      ## Session cleanup, vCenter
      If($runtimeConnection){
          $null = Disconnect-VIServer -Server $Server -Confirm:$false -Force -ErrorAction SilentlyContinue
      }
      
      ## Set PowerCLI certificate settings as they were prior to runtime, if needed.
      If($cliPref){
        $initialSetting = ($cliPref.InvalidCertificateAction) | Out-String
        Write-Debug -Message ('Setting PowerCLI certificate preference back to previous setting of {0}' -f $initialSetting)
        $null = Set-PowerCLIConfiguration -Scope Session -InvalidCertificateAction $initialSetting -Confirm:$false -wa 0 -ea 0
      }
      
      ## Stop transcript logging, if any
      If($Logging){
        Write-Verbose -Message 'Stopping transcript logging for this session'
          Stop-Transcript
      }
    
      ## Announce completion
      Write-Verbose -Message ('Ending {0} at {1}' -f ($MyInvocation.Mycommand), (Get-Date -Format o))
      
      ## Output
      If(-Not($OutputPath)){
        ## Return object
        return $Script:report
      }
      Else{
        ## Return path to output file
        return $outFile
      }
  } #End End
}