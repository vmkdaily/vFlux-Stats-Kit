#requires -Module VMware.Vimautomation.Core
Function Get-FluxIOPS {

  <#

      .DESCRIPTION
        Gathers VMware vSphere virtual machine disk performance stats. By default, the output is InfluxDB line protocol returned as an object. To output to file instead of returning objects, use the OutputPath parameter. To return pure vSphere stat objects instead of line protocol, use the PassThru switch. Also see the sibling cmdlet Write-FluxIOPS to populate InfluxDB with data points collected here.
        
        This cmdlet understands NFS, VMFS and vSAN and gathers the appropriate stat types accordingly. Also see the sibling cmdlet Write-FluxIOPS to populate the InfluxDB database with the data points collected here.

        Note: For Compute performance such as cpu, memory and network, see the Get-FluxCompute cmdlet.

      .NOTES
        Script:     Get-FluxIOPS.ps1
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

      .PARAMETER ShowStats
        Switch. Optionally, activate this switch to show a subset of collected stats on-screen.

      .PARAMETER OutputPath
        String. Only needed if saving to file. To use this parameter, enter the path to a folder such as $HOME or "$HOME/MyStats". This should be of type container (i.e. a folder). We will automatically create the filename for each stat result and save save the results in line protocol.

      .PARAMETER PassThru
        Switch. Optionally, return native vSphere stat objects instead of line protocol.
      
      .PARAMETER IgnoreCertificateErrors
        Switch. Alias Ice. This parameter should not be needed in most cases. Activate to ignore invalid certificate errors when connecting to vCenter Server. This switch adds handling for the current PowerCLI Session Scope to allow invalid certificates (all client operating systems) and for Windows PowerShell versions 3.0 through 5.1. We also add a temporary runtime dotnet type to help the current session ignore invalid certificates. If you find that you are still having issues, consider downloading the certificate from your vCenter Server instead.

      .PARAMETER IgnoreDatastore
        String. Exactly one string value to ignore. For example "*local*". Also see IgnoreDsRegEx which is complementary to this parameter.
      
      .PARAMETER IgnoreDsRegEx
        String. Ignore datastores using a regular expression. Also see IgnoreDatastore which is complementary to this parameter.
      
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
      $iops = Get-FluxIOPS

      This example gathered IOPS from the currently connected $Default:VIServer.

      .EXAMPLE
      $vc = 'vcsa01.lab.local'
      $iops = Get-FluxIOPS -Server $vc

      This example gathered stats from the $vc vcenter server, and returned the output to screen.
      Because credentials were not provided, the script used passthrough / SSPI.

      .EXAMPLE
      $credsVC = Get-Credential administrator@vsphere.local
      $iops = Get-FluxIOPS -Server $vc -Credential $credsVC
      
      This example used the Credential functionality of the script, and saved the stats to a variable.

      .EXAMPLE
      Get-FluxIOPS -Server $vc -ShowStats

      This example shows additional info on screen.

      .EXAMPLE
      Get-FluxIOPS -OutputPath $HOME -Verbose
      cat $home/fluxstat/fluxstat*.txt | more

      This example collected stats and wrote them to the specified directory $HOME.
      
      .EXAMPLE
      Get-FluxIOPS | Write-FluxIOPS

      This example collected IOPS stats and wrote them to InfluxDB by taking the object returned from Get-FluxIOPS and piping to Write-FluxIOPS. See the next example for preferred strict syntax (no piping).

      .EXAMPLE
      $stats = Get-FluxIOPS
      Write-FluxIOPS -InputObject $stats

      Get the stats and write them to InfluxDB using variable (more performant than the pipeline in our case).

      .EXAMPLE
      1..15 | % { $stats = Get-FluxIOPS; Write-FluxIOPS -InputObject $stats; sleep 20 }

      Gather 5 minutes of stats. Good for initial testing and populating the InfluxDB.

  #>

    [CmdletBinding(DefaultParameterSetName='Default')]
    param (
    
      #String. The IP Address or DNS name of exactly one vCenter Server machine.
      [Parameter(ParameterSetName='Default', Position=0)]
      [string]$Server,

      #PSCredential. Optionally, provide a PSCredential containing the login for vCenter Server.
      [Parameter(ParameterSetName='Default', ValueFromPipeline=$true)]
      [ValidateNotNullOrEmpty()]
      [PSCredential]$Credential,
    
      #String. Optionally, provide the string path to a PSCredential on disk (i.e. "$HOME/CredsVcLab.enc.xml"). This parameter is not supported on Core Editions of PowerShell.
      [Parameter(ParameterSetName='Default')]
      [ValidateScript({Test-Path $_ -Type File})]
      [string]$CredentialPath,

      #String. Optionally, enter a user for connecting to vCenter Server. This is exclusive of the PSCredential options.
      [Parameter(ParameterSetName='Default', ValueFromPipeline=$true)]
      [Alias('Username')]
      [string]$User,

      #String. Optionally, enter a password for connecting to vCenter Server. This is exclusive of the PSCredential options.
      [Parameter(ParameterSetName='Default')]
      [string]$Password,

      #Switch. Optionally, activate this switch to show the collected stats (or portion thereof) on-screen.
      [Parameter(ParameterSetName='Default')]
      [switch]$ShowStats,
      
      #String. Optionally, provide the path to save the outputted results (i.e. $HOME). Whatever path you choose, we create a folder inside it to hold the collected stats.
      [Parameter(ParameterSetName='Default')]
      [ValidateScript({Test-Path $_ -Type Container})]
      [string]$OutputPath,
    
      #Switch. Optionally, return native vSphere stat objects instead of line protocol.
      [Parameter(ParameterSetName='Default')]
      [switch]$PassThru,
      
      #Switch. Ignore invalid certificate errors when gathering stats from vCenter Server.
      [Parameter(ParameterSetName='Default')]
      [Alias('Ice')]
      [switch]$IgnoreCertificateErrors,
      
      #String. Exactly one string value to ignore. For example "*local*". Also see IgnoreDsRegEx (ignore using a regular expression) which is complementary to this parameter if you need additional power.
      [Parameter(ParameterSetName='Default')]
      [string]$IgnoreDatastore,

      #String. Ignore datastores using a regular expression. Also see IgnoreDatastore (ignore using strings) which is complementary to this parameter if you need additional power.
      [Parameter(ParameterSetName='Default')]
      [string]$IgnoreDsRegEx,

      #Boolean. Optionally, activate this switch to enable PowerShell transcript logging.
      [Parameter(ParameterSetName='Default')]
      [switch]$Logging,
      
      #Integer. The maximum time in seconds to offset the start of stat collection. Set to 0 for no jitter or keep the default which jitters for a random time up to MaxJitter. Use this to prevent spikes on localhost when running many jobs.
      [Parameter(ParameterSetName='Default')]
      [ValidateRange(0,120)]
      [int]$MaxJitter = 0,
      
      #Switch. Optionally, activate the Supress switch to prevent Fluxor jobs from running up to the maximium of MaxSupressionWindow.
      [Parameter(ParameterSetName='Supress Set')]
      [switch]$Supress,
      
      #Switch. Optionally, resume collection if it has been paused with the Supress parameter. Alternatively, wait for MaxSupressionWindow to automatically resume the collection.
      [Parameter(ParameterSetName='Resume Set')]
      [switch]$Resume,
      
      #Integer. The maximum allowed time in minutes to miss collections due to being supressed with the Supress switch. The default is 20.
      [Parameter(ParameterSetName='Default')]
      [int]$MaxSupressionWindow = 20,
      
      #Boolean. Prevents fall-back to hard-coded script values for login credential if any.
      [Parameter(ParameterSetName='Default')]
      [bool]$Strict = $true
      
    )

    Begin {
      ## Announce cmdlet start
      Write-Verbose -Message ('Starting {0} at {1}' -f ($MyInvocation.Mycommand), (Get-Date -Format o))
      
      ## Handle PowerShell transcript Logging
      If($Logging){
        [string]$LogDir              = $HOME                                         #PowerShell transcript logging location.  Optionally, set to something like "$HOME/logs" or similar.
        [string]$LogName             = 'flux-iops-ps-transcript'                     #PowerShell transcript name, if any. This is the leaf of the name only; We add extension and date later.
        [string]$dt                  = (Get-Date -Format 'ddMMMyyyy') | Out-String   #Creates one log file per day
      }
      
      ## Output file name leaf (only used when OutputPath is populated)
      [string]$statLeaf              = 'fluxstat'                                    #If writing to file, this is the leaf of the stat output file. We add a generated guid and append .txt later
      
      ## Handle spaces in virtual machine names
      [string]$DisplayNameSpacer     = '\ '                                          #We perform a -replace ' ', $DisplayNameSpacer later in the script. What you enter here is what we replace spaces with. Using '\ ' maintains the spaces, while '_' results in an underscore.
      
      ## Handle Credential from disk by hard-coded path
      [string]$vcCredentialPath      = "$HOME/CredsLabVC.enc.xml"                    #Not supported on Core editions of PowerShell. This value is ignored if the Credential or CredentialPath parameters are populated. Optionally, enter the Path to encrypted xml Credential file on disk. To create a PSCredential on disk see "help New-FluxCredential".
      
      ## Handle plain text credential
      If($Strict -eq $false){
        [string]$vcUser              = 'flux-read-only@vsphere.local'                #This value is ignored by default unless the Strict parameter is set to $false.
        [string]$vcPass              = 'VMware123!!'                                 #This value is ignored by default unless the Strict parameter is set to $false.
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
      
      ## Handle name of supress file
      $supressFile = ('{0}/supress-flux.txt' -f $HOME)
      
      ## Handle Supress parameter
      If($Supress){
        try{
          $null = New-Item -ItemType File -Path $supressFile -Confirm:$false -Force -ErrorAction Stop
          return
        }
        catch{
          Write-Warning -Message 'Problem supressing Fluxor!'
          throw ('{0}' -f $_.Exception.Message)
        }
      }
        
      If($Resume){
        try{
          $null = Remove-Item -Path $supressFile -Confirm:$false -Force -ErrorAction Stop
          Write-Verbose -Message 'Resume operation succeeded'
          return
        }
        catch{
          Write-Warning -Message 'Problem resuming Fluxor!'
          throw ('{0}' -f $_.Exception.Message)
        }
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
      If ($Logging) {
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
          $null = Set-PowerCLIConfiguration -Scope Session -InvalidCertificateAction Ignore -Confirm:$false -wa 0 -ea 0
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
            Elseif($User -and !$Password -and !$IsCoreCLR){
              try {
                ## VI Credential store
                $null = Connect-VIServer -Server $Server -User $User -WarningAction SilentlyContinue -ErrorAction Stop
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
      
      ## Datastore Enumeration
      try{
        $dsList = Get-Datastore -Server $Server -ErrorAction Stop
      }
      catch{
        throw
      }
    
      ## In-Scope Datastores
      If($PSv3){
        If($IgnoreDatastore){
          $dsList = $dsList | Where-Object {$_.Name -notlike $IgnoreDatastore}
        }
        If($IgnoreDsRegEx){
          $dsList = $dsList | Where-Object {$_.Name -notmatch $IgnoreDsRegEx}
        }
      }
      Else{
        If($IgnoreDatastore){
          $dsList = $dsList.Where{$_.Name -notlike $IgnoreDatastore}
        }
        If($IgnoreDsRegEx){
          $dsList = $dsList.Where{$_.Name -notmatch $IgnoreDsRegEx}
        }
      }
      
      ## Confirm we have datastore list, or throw
      If($dsList){
        $ds = $dsList
      }
      Else{
        throw 'Problem handling datastore enumeration!'
      }

      ## Handle datastores by type
      If($PSv3){
        $dsVMFS = $ds | Where-Object { $_.Type -eq 'VMFS' }
        $dsNFS = $ds | Where-Object { $_.Type -eq 'NFS' }
        $dsvSAN = $ds | Where-Object { $_.Name -match '^vsanDatastore' }
      }
      Else{
        $dsVMFS = $ds.Where{$_.Type -eq 'VMFS'}
        $dsNFS = $ds.Where{$_.Type -eq 'NFS'}
        $dsvSAN = $ds.Where{$_.Name -match '^vsanDatastore'}
      }

      ## Get VMFS virtual machines
      If($dsVMFS){
        If($PSv3){
          $BlockVMs = Get-VM -Datastore $dsVMFS -Server $Server | Where-Object { $_.PowerState -eq 'PoweredOn' } | Sort-Object -Property $_.VMHost
        }
        Else{
          $BlockVMs = (Get-VM -Datastore $dsVMFS -Server $Server).Where{$_.PowerState -eq 'PoweredOn'} | Sort-Object -Property $_.VMHost
        }
      }
      Else{
        $BlockVMs = $null
      }
      
      ## Get NFS virtual machines
      If($dsNFS){
        If($PSv3){
          $NfsVMs = Get-VM -Datastore $dsNFS -Server $Server | Where-Object { $_.PowerState -eq 'PoweredOn' } | Sort-Object -Property $_.VMHost
        }
        Else{
          $NfsVMs = (Get-VM -Datastore $dsNFS -Server $Server).Where{$_.PowerState -eq 'PoweredOn'} | Sort-Object -Property $_.VMHost
        }
      }
      Else{
        $NfsVMs = $null
      }
      
      ## Get vSAN virtual machines
      If($dsvSAN){
        If($PSv3){
          $vsanVMs = Get-VM -Datastore $dsvSAN -Server $Server | Where-Object { $_.PowerState -eq 'PoweredOn' } | Sort-Object -Property $_.VMHost
        }
        Else{
          $vsanVMs = (Get-VM -Datastore $dsvSAN -Server $Server).Where{$_.PowerState -eq 'PoweredOn'} | Sort-Object -Property $_.VMHost
        }
      }
      Else{
        $vsanVMs = $null
      }

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
            $null = New-Item -ItemType Directory -Path $Script:strPath -Confirm:$false -Force -WarningAction SilentlyContinue -ErrorAction Stop
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
        
        ## Collect stats (requires virtual machine uptime of 1 hour so we 'Continue' instead of 'throw')
        try{
          $stats = Get-Stat -Entity $BlockVMs -Stat $BlockStatTypes -Realtime -MaxSamples 1 -ErrorAction Continue
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
          ## Iterate through VMFS Block VM stats
          foreach ($stat in $stats) {
          
              ## Handle name
              If($PSv3){
                [string]$name = ($BlockVMs | Where-Object {$_.Id -eq $stat.EntityId} | Select-Object -ExpandProperty Name) -replace ' ',$DisplayNameSpacer
              }
              Else{
                [string]$name = ($BlockVMs.Where{$_.Id -eq $stat.EntityId} | Select-Object -ExpandProperty Name) -replace ' ',$DisplayNameSpacer
              }

              ## Handle instance. There may or may not be an instance for VMFS block stats.
              [string]$instance = $stat.Instance

              ## Handle measurement name
              [string]$measurement = $stat.MetricId
              
              ## Handle general info
              [string]$DiskType = 'Block'
              [int]$interval = $stat.IntervalSecs
              [string]$type = 'VM'
              [string]$unit = $stat.Unit
              [string]$vc = $Server
              
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
        
          ## Gather NFS stats (requires virtual machine uptime of 1 hour so we 'Continue' instead of 'throw')
          If($PSv3){
            try{
            $stats = Get-Stat -Entity $NfsVMs -Stat $NfsStatTypes -Realtime -MaxSamples 1 -ErrorAction Continue | Where-Object { $_.Instance -ne ''}
            }
            catch{
              If($error.Exception.Message){
                Write-Warning -Message ('{0}' -f $_.Exception.Message)
              }
            }
          }
          Else{
            try{
              $stats = (Get-Stat -Entity $NfsVMs -Stat $NfsStatTypes -Realtime -MaxSamples 1 -ErrorAction Continue).Where{$_.Instance -ne ''}
            }
            catch{
              If($error.Exception.Message){
                Write-Warning -Message ('{0}' -f $_.Exception.Message)
              }
            }
          }
          
          ## Handle PassThru mode
          If($PassThru){
            $Script:report += $stats
          }
          Else{
            ## Iterate through NFS VM Stats
            foreach ($stat in $stats) {
            
              ## Handle name
              If($PSv3){
                [string]$name = ($NfsVMs | Where-Object {$_.Id -eq $stat.EntityId} | Select-Object -ExpandProperty Name) -replace ' ',$DisplayNameSpacer
              }
              Else{
                [string]$name = ($NfsVMs.Where{$_.Id -eq $stat.EntityId} | Select-Object -ExpandProperty Name) -replace ' ',$DisplayNameSpacer
              }

              ## Handle Instance. This always exists for NFS.
              [string]$instance = $stat.Instance

              ## Handle measurement name
              [string]$measurement = $stat.MetricId
              
              ## Handle general info
              [string]$measurement = $stat.MetricId
              [string]$DiskType = 'NFS' #derived
              [int]$interval = $stat.IntervalSecs
              [string]$type = 'VM' #derived
              [string]$unit = $stat.Unit
              [string]$vc = $Server
              
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
          try{
            $stats = Get-VsanStat -Entity $vsanVMs -Name $vSanStatTypes -Start (Get-Date).AddMinutes(-59) -ErrorAction Continue
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
            ## Iterate through vSAN VM Stats
            foreach ($stat in $stats) {
            
                ## Handle name
                [string]$name = ($stat.Entity) -replace ' ',$DisplayNameSpacer

                ## Handle instance (currently none for vSAN VM default report, though we add support for it)
                If($stat.Instance){
                  $instance = $stat.Instance
                }

                ## Handle measurement name
                [string]$measurement = $stat.MetricId
                
                ## Handle general info
                [string]$DiskType = 'vSAN' #derived
                [int]$interval = 20 #derived. Unlike other intervals, this one is derived, meaning we made it up. Do not change this unless you also change the StartTime parameter of Get-VsanStat.
                [string]$type = 'VM' #derived
                [string]$unit = $stat.Unit
                [string]$vc = $Server
                
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
      If($Logging){
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