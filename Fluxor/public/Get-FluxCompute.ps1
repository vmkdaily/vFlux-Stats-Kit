#requires -Module VMware.Vimautomation.Core
Function Get-FluxCompute {

  <#

      .DESCRIPTION
        Gathers VMware vSphere 'Compute' performance stats such as cpu, memory and network from virtual machines or ESXi hosts.  By default, the output is InfluxDB line protocol returned as an object. To output to file instead of returning objects, use the OutputPath parameter. To return pure vSphere stat objects (instead of line protocol), use the PassThru switch. Also see the sibling cmdlet Write-FluxCompute to populate InfluxDB with data points collected here.

        Note: For disk performance, see the Get-FluxIOPS cmdlet.

      .NOTES
        Script:     Get-FluxCompute.ps1
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
        String. The entity type to get stats for ('VM' or 'VMHost'). The default is VM which returns stats for all virtual machines. To return host stats instead of virtual machines, tab complete or enter 'VMHost' as the value for the ReportType parameter.
    
      .PARAMETER ShowStats
        Switch. Optionally, activate this switch to show a subset of collected stats on-screen.

      .PARAMETER OutputPath
        String. Only needed if saving to file. To use this parameter, enter the path to a folder such as $HOME or "$HOME/MyStats". This should be of type container (i.e. a folder). We will automatically create the filename for each stat result and save save the results in line protocol.

      .PARAMETER PassThru
        Switch. Optionally, return native vSphere stat objects instead of line protocol.
      
      .PARAMETER IgnoreCertificateErrors
        Switch. Alias Ice. This parameter should not be needed in most cases. Activate to ignore invalid certificate errors when connecting to vCenter Server. This switch adds handling for the current PowerCLI Session Scope to allow invalid certificates (all client operating systems) and for Windows PowerShell versions 3.0 through 5.1. We also add a temporary runtime dotnet type to help the current session ignore invalid certificates. If you find that you are still having issues, consider downloading the certificate from your vCenter Server instead.
    
      .PARAMETER Cardinality
        String. Changing this is not recommended for most cases. Optionally, increase the Cardinality of data points collected. Tab complete through options Standard, Advanced or Overkill. The default is Standard.

      .PARAMETER Logging
        Boolean. Optionally, activate this switch to enable PowerShell transcript logging.

      .PARAMETER MaxJitter 
        Integer. The maximum time in seconds to offset the start of stat collection. The default is 0. Use this to prevent spikes on localhost when running many jobs.

      .PARAMETER Strict
        Boolean. Prevents fall-back to hard-coded script values for login credential if any.
        
      .EXAMPLE
      $vc = 'vcsa01.lab.local'
      Get-FluxCompute -Server $vc -OutputPath $HOME
      cat $home/fluxstat*.txt | more

      This example collected stats and wrote them to a file in line protocol format by populating the OutputPath parameter.
      
      .EXAMPLE
      PS C:\> $stats = Get-FluxCompute
      PS C:\> 
      PS C:\> $stats | more
      PS C:\> $stats | Out-GridView

      This example showed how to review the stats collected in the default mode, which returns PowerShell objects.
      The returned object is an array of crafted line protocol strings including the requisite new line characters.
      The example shows common techniques for reviewing the returned object output.
    
      .EXAMPLE
      Get-FluxCompute | Write-FluxCompute

      This example collected realtime stats and wrote them to InfluxDB. We do this by taking the object returned from
      Get-FluxCompute and piping that to the sibling cmdlet Write-FluxCompute, which allows pipeline input for the 
      InputObject parameter.

      .EXAMPLE
      $stats = Get-FluxCompute
      Write-FluxCompute -InputObject $stats

      Get the stats and write them to InfluxDB in a more performant way than the pipeline.
      
      .EXAMPLE
      1..15 | % { $stats = Get-FluxCompute; Write-FluxCompute -InputObject $stats; sleep 20 }
      Gather 5 minutes of stats. Good for initial testing and populating the InfluxDB.
      
  #>

    [CmdletBinding()]
    param (
    
      #String. The IP Address or DNS name of exactly one vCenter Server machine.
      [string]$Server,

      #PSCredential. Optionally, provide a PSCredential containing the login for vCenter Server.
      [PSCredential]$Credential,
    
      #String. Optionally, provide the string path to a PSCredential on disk (i.e. "$HOME/CredsVcLab.enc.xml"). This parameter is not supported on Core Editions of PowerShell.
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
    
      #Switch. Optionally, activate this switch to show the collected stats (or portion thereof) on-screen.
      [switch]$ShowStats,
    
      #String. Optionally, provide the path to save the outputted results such as $HOME or "$HOME/myfluxLP"
      [ValidateScript({Test-Path $_ -Type Container})]
      [string]$OutputPath,
    
      #Switch. Optionally, return native vSphere stat objects instead of line protocol.
      [switch]$PassThru,

      #Switch. Ignore invalid certificates when gathering stats from vCenter Server.
      [Alias('Ice')]
      [switch]$IgnoreCertificateErrors,

      #String. Optionally, increase the Cardinality of data points collected. The default is Standard and changing this is not recommended in most cases.
      [ValidateSet('Standard','Advanced','OverKill')]
      [string]$Cardinality = 'Standard',
      
      #Boolean. Optionally, activate this switch to enable PowerShell transcript logging.
      [switch]$Logging,
      
      #Integer. The maximum time in seconds to offset the start of stat collection. The default is 0. Use this to prevent spikes on localhost when running many jobs.
      [ValidateRange(0,120)]
      [int]$MaxJitter = 0,
      
      #Boolean. Prevents fall-back to hard-coded script values for login credential if any.
      [bool]$Strict = $true

    )

    Begin {
        ## Announce cmdlet start
        Write-Verbose -Message ('Starting {0} at {1}' -f ($MyInvocation.Mycommand), (Get-Date -Format o))

        ## Supress collection, if needed.
        $supressFile = ('{0}/supress-flux.txt' -f $HOME)
        [bool]$exists = Test-Path -Path $supressFile -PathType Leaf
        If($exists){
          $item = Get-Item -Path $supressFile | Select-Object -First 1
          $itemAgeMinutes = [int]((Get-Date)-(Get-Date  -Date $item.LastWriteTime) | Select-Object -ExpandProperty Minutes)
          If($itemAgeMinutes -lt 60){
              Write-Verbose -Message 'Fluxor running in supress mode; No stats will be collected!'
              exit
          }
        }

        ## Logging (only used if Logging switch is activated)
        [string]$LogDir              = $HOME                                         #PowerShell transcript logging location.  Optionally, set to something like "$HOME/logs" or similar.
        [string]$LogName             = 'flux-compute-ps-transcript'                  #PowerShell transcript name, if any. This is the leaf of the name only; We add extension and date later.
        [string]$dt                  = (Get-Date -Format 'ddMMMyyyy') | Out-String   #Creates one log file per day by default.
        
        ## Output file name leaf (only used when OutputPath is populated)
        [string]$statLeaf            = 'fluxstat'                                    #If writing to file, this is the leaf of the stat output file. We add a generated guid and append .txt later
        
        ## Handle spaces in virtual machine names
        [string]$DisplayNameSpacer   = '\ '                                          #We perform a replace ' ', $DisplayNameSpacer later in the script. What you enter here is what we replace spaces with. Using '\ ' maintains the spaces, while '_' results in an underscore.
        
        ## Handle Credential from disk by hard-coded path
        [string]$vcCredentialPath    = "$HOME/CredsLabVC.enc.xml"                    #Not supported on Core editions of PowerShell. This value is ignored if the Credential or CredentialPath parameters are populated. Optionally, enter the Path to encrypted xml Credential file on disk. To create a PSCredential on disk see "help New-FluxCredential".
    
        ## Handle plain text credential
        If($Strict -eq $false){
          [string]$vcUser              = 'flux-read-only@vsphere.local'              #This value is ignored by default unless the Strict parameter is set to $false.
          [string]$vcPass              = 'VMware123!!'                               #This value is ignored by default unless the Strict parameter is set to $false.
        }
      
        ## stat preferences
        $VmStatTypes  = 'cpu.usage.average','cpu.usagemhz.average','mem.usage.average','net.usage.average','cpu.ready.summation'  
        $EsxStatTypes = 'cpu.usage.average','cpu.usagemhz.average','mem.usage.average','net.usage.average','cpu.ready.summation'
        
        #######################################
        ## No need to edit beyond this point
        #######################################
      
    } #End Begin

    Process {
    
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
        Write-Verbose -Message ('Beginning stat collection on {0}' -f $Server)

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
        
          ## Get the stats (requires virtual machine uptime of 1 hour so we 'Continue' instead of 'throw')
          try{
            $stats = Get-Stat -Entity $VMs -Stat $VMStatTypes -Realtime -MaxSamples 1 -ErrorAction Continue
          }
          catch{
            If($error.Exception.Message){
              Write-Warning -Message ('{0}' -f $_.Exception.Message)
            }
          }
        
          ## Handle PassThru mode
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
        
            ## Handle each stat
            foreach ($vmStat in $stats){

                ## Handle name
                If($PSv3){
                  [string]$name = ($VMs | Where-Object {$_.Id -match $vmstat.EntityId} | Select-Object -ExpandProperty Name) -replace ' ',$DisplayNameSpacer
                }
                Else{
                  [string]$name = ($VMs.Where{$_.Id -match $vmstat.EntityId} | Select-Object -ExpandProperty Name) -replace ' ',$DisplayNameSpacer
                }
              
                ## Handle instance
                [string]$instance = $vmStat.Instance

                ## Handle measurement name
                switch($Cardinality){
                  Advanced{
                    ## Cardinality of Advanced includes metric id and host (i.e. 'cpu.usage.average.testvm001')
                    [string]$measurement = ('{0}.{1}' -f $vmStat.MetricId, $name)
                  }
                  OverKill{
                    If($instance){
                      ## Cardinality of OverKill includes the metric id, host and instance (i.e. 'cpu.usage.average.testvm001.15')
                      [string]$measurement = ('{0}.{1}.{2}' -f $vmStat.MetricId, $name, $instance)
                    }
                    Else{
                      ## Fall-back to Cardinality of Advanced, if there is no instance
                      [string]$measurement = ('{0}.{1}' -f $vmStat.MetricId, $name)
                    }
                  }
                  Default{
                    ## Cardinality of Standard (default) returns metric id only (i.e. 'cpu.usage.average')
                    [string]$measurement = $vmStat.MetricId
                  }
                }
              
                ## Handle general info
                [int]$interval = $vmStat.IntervalSecs
                [string]$type = 'VM' #derived
                [string]$unit = $vmStat.Unit
                [string]$vc = $Server
              
                ## Handle value and timestamp
                $value = $vmStat.Value
                [long]$timestamp = (([datetime]::UtcNow)-(Get-Date -Date '1/1/1970')).TotalMilliseconds * 1000000 #nanoseconds since Unix epoch
      
                ## Handle ready stat
                If($vmStat.MetricID -eq 'cpu.ready.summation') {
                  $ready = [math]::Round($(($vmStat.Value / ($vmStat.IntervalSecs * 1000)) * 100), 2)
                  $value = $ready
                }
              
                ## Build it
                If(-Not($instance) -or ($instance -eq '')) {
                  #Without instance
                  $MetricsString = ''
                  $MetricsString += ('{0},host={1},interval={2},type={3},unit={4},vc={5} value={6} {7}' -f $measurement, $name, $interval, $type, $unit, $vc, $value, $timestamp)
                  $MetricsString += "`n"
                }
                Else {
                  #With instance (i.e. cpucores, vmnics, etc.)
                  $MetricsString = ''
                  $MetricsString += ('{0},host={1},instance={2},interval={3},type={4},unit={5},vc={6} value={7} {8}' -f $measurement, $name, $instance, $interval, $type, $unit, $vc, $value, $timestamp)
                  $MetricsString += "`n"
                }
          
                ## Populate object with line protocol
                If(-Not($OutputPath)){
                  $Script:report += $MetricsString
                }
                Else{
                    ## Populate output file, if needed.
                    Try {
                      $null = Add-Content -Path $outFile -Value $MetricsString -Force -Confirm:$false
                    }
                    Catch {
                      Write-Warning -Message ('Problem writing {0} for {1} to file {2} at {3}' -f ($measurement), ($name), $outFile, (Get-Date))
                      Write-Warning -Message ('{0}' -f $_.Exception.Message)
                    }
                }

                ## View it
                If($ShowStats){
                    If(-Not($PSCmdlet.MyInvocation.BoundParameters['Verbose'])) {
                      Write-Output -InputObject ''
                      Write-Output -InputObject ('Measurement: {0}' -f $measurement)
                      Write-Output -InputObject ('Value: {0}' -f $value)
                      Write-Output -InputObject ('Name: {0}' -f $Name)
                      Write-Output -InputObject ('Unix Timestamp: {0}' -f $timestamp)
                    }
                    Else {
                      #verbose
                      Write-Verbose -Message ''
                      Write-Verbose -Message ('Measurement: {0}' -f $measurement)
                      Write-Verbose -Message ('Value: {0}' -f $value)
                      Write-Verbose -Message ('Name: {0}' -f $Name)
                      Write-Verbose -Message ('Unix Timestamp: {0}' -f $timestamp)
                    } #End Else
                } #End If
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
      
          ## Enumerate VMHost objects
          If($PSv3){
            try{
              $VMHosts = Get-VMHost -Server $Server -ErrorAction Stop | Where-Object {$_.State -eq 'Connected'} | Sort-Object -Property Name
            }
            catch{
              Write-Warning -Message 'Problem enumerating one or more VMHosts!'
              throw
            }
          }
          Else{
            try{
              $VMHosts = (Get-VMHost -Server $Server -ErrorAction Stop).Where{$_.State -eq 'Connected'} | Sort-Object -Property Name
            }
            catch{
              Write-Warning -Message 'Problem enumerating one or more VMHosts!'
              throw
            }
          }
        
          ## Get the stats (requires an entity uptime of 1 hour, so we 'continue' instead of 'throw')
          try{
            $stats = Get-Stat -Entity $VMHosts -Stat $EsxStatTypes -Realtime -MaxSamples 1 -ErrorAction Continue
          }
          catch{
            If($error.Exception.Message){
              Write-Warning -Message ('{0}' -f $_.Exception.Message)
            }
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
            foreach($hostStat in $stats){
              
                ## Handle name
                If($PSv3){
                    [string]$name = $VMHosts | Where-Object {$_.Id -match $hostStat.EntityId} | Select-Object -ExpandProperty Name
                }
                Else{
                  [string]$name = ($VMHosts).Where{$_.Id -match $hostStat.EntityId} | Select-Object -ExpandProperty Name
                }

                ## Handle instance
                [string]$instance = $hostStat.Instance

                ## Handle measurement name
                switch($Cardinality){
                  Advanced{
                    ## Cardinality of Advanced includes metric id and host (i.e. 'cpu.usage.average.host7')
                    [string]$measurement = ('{0}.{1}' -f $hostStat.MetricId, $name)
                  }
                  OverKill{
                    If($instance){
                      ## Cardinality of OverKill includes the metric id, host and instance (i.e. returns 'cpu.usage.average.host7.15' for cpu 16 on host7)
                      [string]$measurement = ('{0}.{1}.{2}' -f $hostStat.MetricId, $name, $instance)
                    }
                    Else{
                      ## Fall-back to Cardinality of Advanced, if there is no instance
                      [string]$measurement = ('{0}.{1}' -f $hostStat.MetricId, $name)
                    }
                  }
                  Default{
                    ## Cardinality of Standard (default) returns metric id only (i.e. 'cpu.usage.average')
                    [string]$measurement = $hostStat.MetricId
                  }
                }

                ## Handle general info
                [int]$interval = $hostStat.IntervalSecs
                [string]$type = 'VMHost' #derived
                [string]$unit = $hostStat.Unit
                [string]$vc = $global:DefaultVIServer
              
                ## Handle value and timestamp
                $value = $hostStat.Value
                [long]$timestamp = (([datetime]::UtcNow)-(Get-Date -Date '1/1/1970')).TotalMilliseconds * 1000000 #nanoseconds since Unix epoch

                ## Handle ready stat
                If($hostStat.MetricID -eq 'cpu.ready.summation') {
                  $ready = [math]::Round($(($hostStat.Value / ($hostStat.IntervalSecs * 1000)) * 100), 2)
                  $value = $ready
                }
              
                ## Build it
                If(-Not($instance) -or ($instance -eq '')) {
                  #Without instance
                  $MetricsString = ''
                  $MetricsString += ('{0},host={1},interval={2},type={3},unit={4},vc={5} value={6} {7}' -f $measurement, $name, $interval, $type, $unit, $vc, $value, $timestamp)
                  $MetricsString += "`n"
                }
                Else{
                  #With instance (i.e. cpucores, vmnics, etc.)
                  $MetricsString = ''
                  $MetricsString += ('{0},host={1},instance={2},interval={3},type={4},unit={5},vc={6} value={7} {8}' -f $measurement, $name, $instance, $interval, $type, $unit, $vc, $value, $timestamp)
                  $MetricsString += "`n"
                }
            
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
        If ($Logging) {
          Write-Verbose -Message 'Stopping transcript logging for this session'
            Stop-Transcript
        }
      
        ## Announce completion
        Write-Verbose -Message ('Ending {0} at {1}' -f ($MyInvocation.Mycommand), (Get-Date -Format o))
        
        ## Handle output of object or file
        If(-Not($OutputPath)){
          return $Script:report
        }
        Else{
          return $outFile
        }
    } #End End
}