#requires -Module VMware.Vimautomation.Core
Function Get-FluxIOPS {

  <#

      .DESCRIPTION
        Gathers VMware vSphere virtual machine disk performance stats. By default, the output is InfluxDB
        line protocol returned as an object. To output to file instead of returning objects, use the
        OutputPath parameter.
        
        To return pure vSphere stat objects instead of line protocol, use the PassThru switch. Also see
        the sibling cmdlet Write-FluxIOPS to populate InfluxDB with data points collected here.
        
        The cmdlet herein understands NFS, VMFS and vSAN. We automatically gather the appropriate stat
        types accordingly. Also see the sibling cmdlet Write-FluxIOPS to populate the InfluxDB database with
        the data points collected here.

        Note: For Compute performance such as cpu, memory and network, see the Get-FluxCompute cmdlet.

      .NOTES
        Script:     Get-FluxIOPS.ps1
        Version:    1.0.0.1
        Author:     Mike Nisk
        Prior Art:  Based on vFlux Stats Kit
        Supports:   PSEdition Core 6.0, and PowerShell 3.0 to 5.1
        Supports:   PowerCLI 6.5.x or later (10.x preferred)
        Supports:   Windows, Linux, macOS

      .PARAMETER Server
        String. The IP Address or DNS name of exactly one vCenter Server machine.
        For IPv6, enclose address in square brackets, for example [fe80::250:56ff:feb0:74bd%4].
      
      .PARAMETER Credential
        PSCredential. Optionally, provide a PSCredential containing the login for vCenter Server.

      .PARAMETER CredentialPath
        String. Optionally, provide the path to a PSCredential on disk such as "$HOME/CredsVcLab.enc.xml". This parameter is not supported on Core Editions of PowerShell.

      .PARAMETER User
        String. Optionally, enter a user for connecting to vCenter Server.

      .PARAMETER Password
        String. Optionally, enter a password for connecting to vCenter Server.

      .PARAMETER ShowStats
        Switch. Optionally, activate this switch to show a subset of collected stats on-screen.

      .PARAMETER OutputPath
        String. Only needed if saving to file. To use this parameter, enter the path to a folder such as $HOME
        or "$HOME/MyStats". This should be of type container (i.e. a folder). We will automatically create the
        filename for each stat result and save save the results in line protocol.

      .PARAMETER PassThru
        Switch. Optionally, return native vSphere stat objects instead of line protocol.
      
      .PARAMETER IgnoreCertificateErrors
        Switch. Alias Ice. This parameter should not be needed in most cases. Activate to ignore invalid certificate
        errors when connecting to vCenter Server. This switch adds handling for the current PowerCLI Session Scope to
        allow invalid certificates (all client operating systems) and for Windows PowerShell versions 3.0 through 5.1
        we also add a temporary runtime dotnet type to help the current session ignore invalid certificates. f you find
        that you are still having issues, consider downloading the certificate from your vCenter Server instead.

      .PARAMETER IgnoreDatastore
        String. One or more datastores to ignore. For example "*local*", or "exactlythisname", or an array such as
        "dsa","dsb" or @('dsa','dsb',"*iso*","*local*"). Also see IgnoreDsRegEx which is complementary to this
        parameter if you need additional power.
      
      .PARAMETER IgnoreDsRegEx
        String. Ignore datastores using a regular expression. Also see IgnoreDatastore which is complementary to this parameter.
      
      .PARAMETER Cardinality
        String. Changing this is not recommended for most cases. Optionally, increase the Cardinality of data points collected.
        Tab complete through options Standard, Advanced or Overkill. The default is Standard.

      .PARAMETER Strict
        Switch. Optionally, prevent fall-back to hard-coded script values for login.

      .EXAMPLE
      Get-FluxIOPS

      This example gathered IOPS from the currently connected $Default:VIServer.

      .EXAMPLE
      $vc = 'vcsa01.lab.local'
      Get-FluxIOPS -Server $vc

      This example gathers stats from the $vc vcenter server, and returns the output to screen.
      Because credentials were not provided, the script uses passthrough / SSPI.

      .EXAMPLE
      $credsVC = Get-Credential administrator@vsphere.local
      $stats = Get-FluxIOPS -Server $vc -Credential $credsVC
      
      This example used the Credential functionality of the script, and also saved the stats to a variable.

      .EXAMPLE
      Get-FluxIOPS -Server $vc -ShowStats

      This example shows additional info on screen.

      .EXAMPLE
      Get-FluxIOPS -OutputPath $HOME -Verbose
      cat $home/fluxstat/fluxstat*.txt | more

      This example collected stats and wrote them to the specified directory $HOME.
      
      .EXAMPLE
      Get-FluxIOPS | Write-FluxIOPS

      This example collected realtime stats and wrote them to InfluxDB. We do this by taking the object returned from
      Get-FluxIOPS and piping to Write-FluxIOPS. See the next example for preferred strict syntax (no piping).

      .EXAMPLE
      $stats = Get-FluxIOPS
      Write-FluxIOPS -InputObject $stats

      Get the stats and write them to InfluxDB using variable (more performant than the pipeline in our case).

      .EXAMPLE
      1..15 | % { $stats = Get-FluxIOPS; Write-FluxIOPS -InputObject $stats; sleep 20 }

      Gather 5 minutes of stats. Good for initial testing and populating the InfluxDB.
      
      APPENDIX - Writing and viewing stats

        A. To write stat objects to InfluxDB, pipe the output to the sibling cmdlet Write-FluxIOPS:

          Get-FluxIOPS | Write-FluxIOPS
          
        B. For better performance, save stat collection to a variable and then write to influx:
        
            $stats = Get-FluxIOPS
            Write-FluxIOPS -InputObject $stats

          You can also use the ';' character to chain two commands together:

            $stats = Get-FluxIOPS; Write-FluxIOPS -InputObject $stats
        
        C. Optionally, to write line protocol files to disk use the OutputPath parameter:
        
          Get-FluxIOPS -OutputPath $HOME
        
        Note: To write existing text files to InfluxDB you can follow the influxdata documentation.
        We expect you to use objects to write to InfluxDB. We only support creating text files for
        those seeking ultra high performance upstream when writing to InfluxDB in batches (i.e.
        batches of 5k to 16k values per write).

        Tip: In Grafana, When creating each dashboard, be sure to set null values to none or it may
          appear as though you have no stats!

  #>

    [CmdletBinding()]
    param (

      #String. The IP Address or DNS name of exactly one vCenter Server machine.
      [string]$Server,

      #PSCredential. Optionally, provide a PSCredential containing the login for vCenter Server. If not connected to vCenter already we use this Credential (if populated) or we fall-back to SSPI. 
      [PSCredential]$Credential,
      
      #String. Optionally, provide the string path to a PSCredential on disk (i.e. "$HOME/CredsVcLab.enc.xml'). This parameter is not supported on Core Editions of PowerShell.
      [ValidateScript({Test-Path $_ -Type File})]
      [string]$CredentialPath,

      #String. Optionally, enter a user for connecting to vCenter Server. This is exclusive of the PSCredential options.
      [string]$User,

      #String. Optionally, enter a password for connecting to vCenter Server. This is exclusive of the PSCredential options.
      [string]$Password,

      #Switch. Optionally, activate this switch to show the collected stats (or portion thereof) on-screen.
      [switch]$ShowStats,
      
      #String. Optionally, provide the path to save the outputted results (i.e. $HOME). Whatever path you choose, we create a folder inside it to hold the collected stats.
      [ValidateScript({Test-Path $_ -Type Container})]
      [string]$OutputPath,
    
      #Switch. Optionally, return native vSphere stat objects instead of line protocol.
      [switch]$PassThru,
      
      #Switch. Ignore invalid certificate errors when gathering stats from vCenter Server.
      [Alias('Ice')]
      [switch]$IgnoreCertificateErrors,
      
      #String. Ignore one or more datastores by string or array of strings. For example "*local*", or "exactlythisname", or an array such as "dsa","dsb" or @('dsa','dsb',"*iso*","*local*"). Also see IgnoreDsRegEx (ignore using a regular expression) which is complementary to this parameter if you need additional power.
      [string[]]$IgnoreDatastore,

      #String. Ignore datastores using a regular expression. Also see IgnoreDatastore (ignore using strings) which is complementary to this parameter if you need additional power.
      [string]$IgnoreDsRegEx,

      #String. Optionally, increase the Cardinality of data points collected. The default is Standard and changing this is not recommended in most cases.
      [ValidateSet('Standard','Advanced','OverKill')]
      [string]$Cardinality = 'Standard',
      
      #Switch. Optionally, prevent fall-back to hard-coded script values.
      [switch]$Strict
    )

    Begin {
      ## Announce cmdlet start
      Write-Verbose -Message ('Starting {0} at {1}' -f ($MyInvocation.Mycommand), (Get-Date -Format o))

      ## Supress collection, if needed.
      $supressFile = "$HOME/supress-flux.txt"
      [bool]$exists = Test-Path -Path $supressFile -PathType Leaf
      If($exists){
        $item = Get-Item $supressFile | Select-Object -First 1
        $itemAgeMinutes = [int]((Get-Date)-(Get-Date  $item.LastWriteTime) | Select-Object -ExpandProperty Minutes)
        If($itemAgeMinutes -lt 60){
            Write-Verbose -Message 'Fluxor running in supress mode; No stats will be collected!'
            exit
        }
      }

      ## User Prefs
      [string]$Logging             = 'Off'                                         #PowerShell transcript logging 'On' or 'Off'
      [string]$LogDir              = $HOME                                         #PowerShell transcript logging location.  Optionally, set to something like "$HOME/logs" or similar.
      [string]$LogName             = 'flux-iops-ps-transcript'                     #PowerShell transcript name, if any. This is the leaf of the name only; We add extension and date later.
      [string]$statLeaf            = 'fluxstat'                                    #If writing to file, this is the leaf of the stat output file. We add a generated guid and append .txt later
      [string]$dt                  = (Get-Date -Format 'ddMMMyyyy') | Out-String   #Creates one log file per day
      [string]$DisplayNameSpacer   = '\ '                                          #We perform a -replace ' ', $DisplayNameSpacer later in the script. What you enter here is what we replace spaces with. Using '\ ' maintains the spaces, while '_' results in an underscore.
      [string]$vcCredentialPath    = "$HOME/CredsLabVC.enc.xml"                    #Not supported on Core Editions of PowerShell. Enter the path to an encrypted xml Credential file on disk. To create a PSCredential on disk see "help New-FluxCredential".
      
      ## Plain text option
      If(-Not($Strict)){
        [string]$vcUser              = 'flux-read-only@vsphere.local'              #This value is ignored in Strict mode or if we have PSCredential. Optionally, enter an existing read-only user on vCenter Server
        [string]$vcPass              = 'VMware123!!'                               #This value is ignored in Strict mode or if we have PSCredential. Optionally, enter the password for the desired vCenter Server user.
      }
      
      ## Stat preferences block VMs
      $BlockStatTypes = @('disk.maxTotalLatency.latest','disk.numberread.summation','disk.numberwrite.summation')
      
      ## Stat preferences NFS VMs
      $NfsStatTypes   = @('virtualdisk.numberreadaveraged.average','virtualdisk.numberwriteaveraged.average','virtualDisk.readLatencyUS.latest','virtualDisk.writeLatencyUS.latest')
      
      ## Stat preferences vSAN VMs
      $vSanStatTypes = @('Performance.ReadIops','Performance.ReadLatency','Performance.ReadThroughput','Performance.WriteIops','Performance.WriteLatency','Performance.WriteThroughput')
      
      #######################################
      ## No need to edit beyond this point
      #######################################
      
    } #End Begin
 
    Process {
      
      ## Start Logging
      If ($Logging -eq 'On') {
          Start-Transcript -Append -Path ('{0}\{1}-{2}.log' -f $LogDir, $LogName, $dt)
      }
      
      ## Handle invalid certificate errors, if needed
      If($IgnoreCertificateErrors){
        ## Handle PowerShell invalid certificate errors
        $null = Set-SessionAllowInvalidCerts
        
        ## Handle PowerCLI invalid certificate errors
        $cliPref = Get-PowerCLIConfiguration -Scope Session
        [bool]$AlreadyIgnored = ($cliPref).InvalidCertificateAction -match '^Ignore'
        If(-Not($AlreadyIgnored)){
          $null = Set-PowerCLIConfiguration -Scope Session -InvalidCertificateAction Ignore -Confirm:$false -wa 0 -ea 0
        }
      }
      
      ## Connect to vCenter, if needed
      If(-Not($Global:DefaultVIServer)){
        If($Server){
          If(!$Credential -and !$User){
            If($IsCoreCLR){
              Write-Verbose -Message 'Running on PowerShell CoreCLR'
            }
            Else{
              If($CredentialPath){
                $Credential = Get-FluxCredential -Path $CredentialPath
              }
              Elseif(Test-Path -Path $vcCredentialPath -ea 0){
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
                ## Use hard-coded defaults from begin block
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
        Else{
          Throw 'Server parameter is required if not connected to vCenter!'
        }
      }
      Else{
          Write-Verbose -Message ('Using connection to {0}' -f $Global:DefaultVIServer)
      }

      ## Confirm connection or throw
      If(!$Global:DefaultVIServer -or ($Global:DefaultVIServer -and !$Global:DefaultVIServer.IsConnected)){
        Throw 'vCenter Connection Required!'
      }
      Else {
          Write-Verbose -Message ('Beginning daily collection on {0}' -f ($Global:DefaultVIServer))
      }

      ## Datastore Enumeration
      try{
        $dsList = Get-Datastore -ErrorAction Stop
      }
      catch{
        throw
      }
    
      ## In-Scope Datastores
      If($IgnoreDatastore){
        $dsList = $dsList | Where-Object {$IgnoreDatastore -notlike $_.Name}
      }
      If($IgnoreDsRegEx){
        $dsList = $dsList | Where-Object {$_.Name -notmatch $IgnoreDsRegEx}
      }
      
      ## Confirm we have datastore list, or throw
      If($dsList){
        $ds = $dsList
      }
      Else{
        throw 'Problem handling datastore enumeration!'
      }

      ## Handle datastores by type
      $dsVMFS = $ds | Where-Object { $_.Type -eq 'VMFS' }
      $dsNFS = $ds | Where-Object { $_.Type -eq 'NFS' }
      $dsvSAN = $ds | Where-Object { $_.Name -match '^vsanDatastore' }

      ## Running VMs by storage type
      $BlockVMs = $dsVMFS | Get-VM | Where-Object { $_.PowerState -eq 'PoweredOn' } | Sort-Object -Property $_.VMHost
      $NfsVMs = $dsNFS | Get-VM | Where-Object { $_.PowerState -eq 'PoweredOn' } | Sort-Object -Property $_.VMHost
      $vsanVMs = $dsvSAN | Get-VM | Where-Object { $_.PowerState -eq 'PoweredOn' } | Sort-Object -Property $_.VMHost

      ## Datastore and VM counts by type
      $VmfsDsCount = ($dsVMFS).Count
      $NfsDsCount = ($dsNFS).Count
      $VmfsVMsCount = ($BlockVMs).Count
      $NfsVMsCount = ($NfsVMs).Count
      $vsanVMsCount = ($vsanVMs).Count
      If($dsvSAN){
        [bool]$boolVsanDS = $true
      }
      Else{
        [bool]$boolVsanDS = $false
      }

      ## Show summary info, if Verbose mode
      If($PSCmdlet.MyInvocation.BoundParameters['Verbose']){
        Write-Verbose -Message ''
        Write-Verbose -Message ('//{0} Overview' -f $DefaultVIServer)
        Write-Verbose -Message ('VMFS Datastores: {0}' -f $VmfsDsCount)
        Write-Verbose -Message ('NFS Datastores: {0}' -f $NfsDsCount)
        Write-Verbose -Message ('vSAN Datastore: {0}' -f $boolVsanDS)
        Write-Verbose -Message ('Block VMs: {0}' -f $VmfsVMsCount)
        Write-Verbose -Message ('NFS VMs: {0}' -f $NfsVMsCount)
        Write-Verbose -Message ('vSAN VMs: {0}' -f $vsanVMsCount)
      }

      ## Array to hold result objects
      If(-Not($OutputPath)){
        $Script:report = @()
      }
      Else{
        ## Handle output directory, if needed.
        $Script:strPath = Join-Path -Path $OutputPath -ChildPath $statLeaf
        If(-Not(Test-Path -Path $strPath -PathType Container)){
          Write-Verbose -Message ('Creating output directory for stat collection at {0}' -f $Script:strPath)
          try{
            $null = New-Item -ItemType Directory -Path $Script:strPath -wa 0 -Confirm:$false -Force -ErrorAction Stop
          }
          catch{
            Write-Warning -Message ('Failed to create required folder at {0}!' -f $Script:strPath)
            throw ('{0}' -f $_.Exception.Message)
          }
        }
      }

      ## VMFS Block VM Section
      If($BlockVMs) {

        If($Script:strPath){
          ## Create empty file
          [string]$strGuid = New-Guid | Select-Object -ExpandProperty Guid
          [string]$writeGuid = ('{0}-{1}' -f $statLeaf, $strGuid)
          [string]$outLeaf = Join-Path -Path $Script:strPath -ChildPath $writeGuid
          [string]$outFile = ('{0}.txt' -f $outLeaf)
          $null = New-Item -ItemType File -Path $outFile -Force
        }
        
        ## Collect stats
        $stats = Get-Stat -Entity $BlockVMs -Stat $BlockStatTypes -Realtime -MaxSamples 1
        
        ## Handle PassThru mode
        If($PassThru){
          $Script:report += $stats
        }
        Else{
          ## Iterate through VMFS Block VM stats
          foreach ($stat in $stats) {
          
              ## Handle name
              [string]$name = ($BlockVMs | Where-Object {$_.Id -match $stat.EntityId} | Select-Object -ExpandProperty Name) -replace ' ',$DisplayNameSpacer

              ## Handle instance. There may or may not be an instance for VMFS block stats.
              [string]$instance = $stat.Instance

              ## Handle measurement
              switch($Cardinality){
                Advanced{
                  ## Cardinality of Advanced
                  [string]$measurement = ('{0}.{1}' -f $stat.MetricId, $name)
                }
                OverKill{
                  If($instance){
                    ## Cardinality of OverKill
                    [string]$measurement = ('{0}.{1}.{2}' -f $stat.MetricId, $name, $instance)
                  }
                  Else{
                    ## Fall-back to Cardinality of Advanced, if there is no instance
                    [string]$measurement = ('{0}.{1}' -f $stat.MetricId, $name)
                  }
                }
                Default{
                  ## Cardinality of Standard (default)
                  [string]$measurement = $stat.MetricId
                }
              }
              
              ## Handle general info
              [string]$DiskType = 'Block'
              [int]$interval = $stat.IntervalSecs
              [string]$type = 'VM'
              [string]$unit = $stat.Unit
              [string]$vc = $Global:DefaultVIServer | Select-Object -ExpandProperty Name
              
              ## Handle value and timestamp
              $value = $stat.Value
              [long]$timestamp = (([datetime]::UtcNow)-(Get-Date -Date '1/1/1970')).TotalMilliseconds * 1000000 #nanoseconds since Unix epoch
              
              ## Build it. VMFS may or may not have instance, so we handle both.
              If(-Not($instance) -or ($instance -eq '')) {
                #Do not include instance
                $MetricsString = ''
                $MetricsString += ('{0},disktype={1},host={2},interval={3},type={4},unit={5},vc={6} value={7} {8}' -f $measurement, $DiskType, $name, $interval, $type, $unit, $vc, $value, $timestamp)
                $MetricsString += "`n"
              }
              Else {
                #Include instance
                $MetricsString = ''
                $MetricsString += ('{0},disktype={1},host={2},instance={3},interval={4},type={5},unit={6},vc={7} value={8} {9}' -f $measurement, $DiskType, $name, $instance, $interval, $type, $unit, $vc, $value, $timestamp)
                $MetricsString += "`n"
              }
              
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

              ## View it
              If($ShowStats){
                  If(-Not($PSCmdlet.MyInvocation.BoundParameters['Verbose'])) {
                      Write-Output -InputObject ('Measurement: {0}' -f $measurement)
                      Write-Output -InputObject ('Value: {0}' -f $value)
                      Write-Output -InputObject ('Name: {0}' -f $Name)
                      Write-Output -InputObject ('Unix Timestamp: {0}' -f $timestamp)
                      Write-Output -InputObject ''
                  }
                  Else {
                    #verbose
                    Write-Verbose -Message ('Measurement: {0}' -f $measurement)
                    Write-Verbose -Message ('Value: {0}' -f $value)
                    Write-Verbose -Message ('Name: {0}' -f $Name)
                    Write-Verbose -Message ('Unix Timestamp: {0}' -f $timestamp)
                } #End Else verbose
              } #End If showstats
          } #End foreach block vm
          
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
      } #End if block vms

      ## NFS VM Section
      If($NfsVMs) {

          If($Script:strPath){
            ## Create empty file
            [string]$strGuid = New-Guid | Select-Object -ExpandProperty Guid
            [string]$writeGuid = ('{0}-{1}' -f $statLeaf, $strGuid)
            [string]$outLeaf = Join-Path -Path $Script:strPath -ChildPath $writeGuid
            [string]$outFile = ('{0}.txt' -f $outLeaf)
            $null = New-Item -ItemType File -Path $outFile -Force
          }
        
          ## Gather desired stats
          $stats = Get-Stat -Entity $NfsVMs -Stat $NfsStatTypes -Realtime -MaxSamples 1 | Where-Object { $_.Instance -ne ''}
          
          ## Handle PassThru mode
          If($PassThru){
            $Script:report += $stats
          }
          Else{
            ## Iterate through NFS VM Stats
            foreach ($stat in $stats) {
            
              ## Handle name
              [string]$name = ($NfsVMs | Where-Object {$_.Id -match $stat.EntityId} | Select-Object -ExpandProperty Name) -replace ' ',$DisplayNameSpacer

              ## Handle Instance. This always exists for NFS.
              [string]$instance = $stat.Instance

              ## Handle measurement
              switch($Cardinality){
                Advanced{
                  ## Cardinality of Advanced
                  [string]$measurement = ('{0}.{1}' -f $stat.MetricId, $name)
                }
                OverKill{
                  If($instance){
                    ## Cardinality of OverKill
                    [string]$measurement = ('{0}.{1}.{2}' -f $stat.MetricId, $name, $instance)
                  }
                  Else{
                    ## Fall-back to Cardinality of Advanced, if there is no instance
                    [string]$measurement = ('{0}.{1}' -f $stat.MetricId, $name)
                  }
                }
                Default{
                  ## Cardinality of Standard (default)
                  [string]$measurement = $stat.MetricId
                }
              }

              ## Handle general info
              [string]$measurement = $stat.MetricId
              [string]$DiskType = 'NFS' #derived
              [int]$interval = $stat.IntervalSecs
              [string]$type = 'VM' #derived
              [string]$unit = $stat.Unit
              [string]$vc = $Global:DefaultVIServer | Select-Object -ExpandProperty Name
              
              ## Handle value and timestamp
              $value = $stat.Value
              [long]$timestamp = (([datetime]::UtcNow)-(Get-Date -Date '1/1/1970')).TotalMilliseconds * 1000000 #nanoseconds since Unix epoch
              
              ## Build it
              $MetricsString = ''
              $MetricsString += ('{0},disktype={1},host={2},instance={3},interval={4},type={5},unit={6},vc={7} value={8} {9}' -f $measurement, $DiskType, $name, $instance, $interval, $type, $unit, $vc, $value, $timestamp)
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
              
              ## View it
              If($ShowStats){
                If(-Not($PSCmdlet.MyInvocation.BoundParameters['Verbose'])) {
                  Write-Output -InputObject ('Measurement: {0}' -f $measurement)
                  Write-Output -InputObject ('Value: {0}' -f $value)
                  Write-Output -InputObject ('Name: {0}' -f $Name)
                  Write-Output -InputObject ('Unix Timestamp: {0}' -f $timestamp)
                  Write-Output -InputObject ''
                }
                Else {
                  #verbose
                  Write-Verbose -Message ('Measurement: {0}' -f $measurement)
                  Write-Verbose -Message ('Value: {0}' -f $value)
                  Write-Verbose -Message ('Name: {0}' -f $Name)
                  Write-Verbose -Message ('Unix Timestamp: {0}' -f $timestamp)
                } #End Else
              } #End If showstats
            } #End foreach stat
            
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
      } #End If NFS

      ## vSAN VM Section
      If($vsanVMs) {

          If($Script:strPath){
            ## Create empty file
            [string]$strGuid = New-Guid | Select-Object -ExpandProperty Guid
            [string]$writeGuid = ('{0}-{1}' -f $statLeaf, $strGuid)
            [string]$outLeaf = Join-Path -Path $Script:strPath -ChildPath $writeGuid
            [string]$outFile = ('{0}.txt' -f $outLeaf)
            $null = New-Item -ItemType File -Path $outFile -Force
          }
        
          ## Gather stats
          $stats = Get-VsanStat -Entity $vsanVMs -Name $vSanStatTypes -Start (Get-Date).AddMinutes(-59)
          
          ## Handle PassThru mode
          If($PassThru){
            $Script:report += $stats
          }
          Else{
            ## Iterate through vSAN VM Stats
            foreach ($stat in $stats) {
            
                ## Handle name
                [string]$name = ($stat.Entity) -replace ' ',$DisplayNameSpacer

                ## Handle instance (currently none for vSAN VM default report, though we add support for it)
                If($stat.Instance){
                  $instance = $stat.Instance
                }

                ## Handle measurement
                switch($Cardinality){
                  Advanced{
                    ## Cardinality of Advanced
                    [string]$measurement = ('{0}.{1}' -f $stat.MetricId, $name)
                  }
                  OverKill{
                    If($instance){
                      ## Cardinality of OverKill
                      [string]$measurement = ('{0}.{1}.{2}' -f $stat.MetricId, $name, $instance)
                    }
                    Else{
                      ## Fall-back to Cardinality of Advanced, if there is no instance
                      [string]$measurement = ('{0}.{1}' -f $stat.MetricId, $name)
                    }
                  }
                  Default{
                    ## Cardinality of Standard (default)
                    [string]$measurement = $stat.MetricId
                  }
                }

                ## Handle general info
                [string]$DiskType = 'vSAN' #derived
                [int]$interval = 20 #derived. Unlike other intervals, this one is derived, meaning we made it up. Do not change this unless you also change the StartTime parameter of Get-VsanStat.
                [string]$type = 'VM' #derived
                [string]$unit = $stat.Unit
                [string]$vc = $Global:DefaultVIServer| Select-Object -ExpandProperty Name
                
                ## Handle value and timestamp
                $value = $stat.Value
                [long]$timestamp = (([datetime]::UtcNow)-(Get-Date -Date '1/1/1970')).TotalMilliseconds * 1000000 #nanoseconds since Unix epoch
  
                ## Build it
                If(-Not($instance) -or ($instance -eq '')) {
                  #Do not include instance
                  $MetricsString = ''
                  $MetricsString += ('{0},disktype={1},host={2},interval={3},type={4},unit={5},vc={6} value={7} {8}' -f $measurement, $DiskType, $name, $interval, $type, $unit, $vc, $value, $timestamp)
                  $MetricsString += "`n"
                }
                Else{
                  #Include instance. We do not expect this on vSAN virtual machine default stat result, though we add support just in case.
                  $MetricsString = ''
                  $MetricsString += ('{0},disktype={1},host={2},instance={3},interval={4},type={5},unit={6},vc={7} value={8} {9}' -f $measurement, $DiskType, $name, $instance, $interval, $type, $unit, $vc, $value, $timestamp)
                  $MetricsString += "`n"
                }

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
            } #End foreach stat
            
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
      } #End If vSAN
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
      If ($Logging -eq 'On') {
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
    }
}