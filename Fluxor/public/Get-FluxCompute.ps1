#requires -Modules VMware.Vimautomation.Core
Function Get-FluxCompute {

  <#

      .DESCRIPTION
        Gathers VMware vSphere 'Compute' performance stats such as cpu, memory and network from virtual machines or ESXi hosts.  By default, the output is InfluxDB line protocol returned as an object. To output to file instead of returning objects, use the OutputPath parameter. To return pure vSphere stat objects (instead of line protocol), use the PassThru switch. Also see the sibling cmdlet Write-FluxCompute to populate InfluxDB with data points collected here.

        We return realtime stats with a MaxSamples of 1 by default. To get last hour use the Repaint parameter. 

        Note: For disk performance, see the Get-FluxIOPS cmdlet.

      .NOTES
        Script:    Get-FluxCompute.ps1
        Module:    This function is part of the Fluxor module
        Author:    Mike Nisk
        Website:   Check out our contributors, issues, and docs for the vFlux-Stats-Kit at https://github.com/vmkdaily/vFlux-Stats-Kit/
        Supports:  PSEdition Core 6.x, and PowerShell 3.0 to 5.1
        Supports:  PowerCLI 6.5.4 or later (11.x or later preferred)
        Supports:  Windows, Linux, macOS

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
    
      .PARAMETER Logging
        Boolean. Optionally, activate this switch to enable PowerShell transcript logging.

      .PARAMETER LogFolder
        String. The path to the folder to save PowerShell transcript logs. The default is $HOME.

      .PARAMETER MaxJitter 
        Integer. The maximum time in seconds to offset the start of stat collection. Set to 0 for no jitter or keep the default which jitters for a random time up to MaxJitter. Use this to prevent spikes on localhost when running many jobs.
      
      .PARAMETER Supress
        Switch. Optionally, activate the Supress switch to prevent Fluxor jobs from running up to the maximium of MaxSupressionWindow.
      
      .PARAMETER Resume
        Switch. Optionally, resume collection if it has been paused with the Supress parameter. Alternatively, wait for MaxSupressionWindow to automatically resume the collection.

      .PARAMETER Repaint
        Switch. Optionally, activate this switch to gather and write all stats for the past Hour.
      
      .PARAMETER MaxSupressionWindow
        Integer. The maximum allowed time in minutes to miss collections due to being supressed with the Supress switch. The default is 20.

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

      This example showed how to review the stats collected in the default mode, which returns PowerShell objects. The returned object is an array of crafted line protocol strings including the requisite new line characters. The example shows common techniques for reviewing the returned object output.
    
      .EXAMPLE
      Get-FluxCompute -Server $vc| Write-FluxCompute -Server 'myinfluxserver'

      This example collected realtime stats and wrote them to InfluxDB. We do this by taking the object returned from Get-FluxCompute and piping that to the sibling cmdlet Write-FluxCompute, which allows pipeline input for the InputObject parameter.

      .EXAMPLE
      $stats = Get-FluxCompute -Server $vc
      Write-FluxCompute -InputObject $stats -Server 'myinfluxserver'

      Get the stats and write them to InfluxDB in a more performant way than the pipeline.
      
      .EXAMPLE
      1..15 | % { $stats = Get-FluxCompute; Write-FluxCompute -InputObject $stats; sleep 20 }
      
      In this example we do not specify Server as we expect that is setup already. Then, we gather 5 minutes of stats. This is good for initial testing and populating the InfluxDB database.
      
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
      [ValidateScript({Test-Path $_ -PathType Leaf})]
      [string]$CredentialPath,

      #String. Optionally, enter a user for connecting to vCenter Server. This is exclusive of the PSCredential options.
      [Parameter(ParameterSetName='Default', ValueFromPipeline=$true)]
      [Alias('Username')]
      [string]$User,

      #String. Optionally, enter a password for connecting to vCenter Server. This is exclusive of the PSCredential options.
      [Parameter(ParameterSetName='Default')]
      [string]$Password,
    
      #Switch. Optionally, select the report type to return. The default is virtual machine ('VM').
      [Parameter(ParameterSetName='Default')]
      [ValidateSet('VM','VMHost')]
      [Alias('Type')]
      [string]$ReportType = 'VM',
    
      #Switch. Optionally, activate this switch to show the collected stats (or portion thereof) on-screen.
      [Parameter(ParameterSetName='Default')]
      [switch]$ShowStats,
    
      #String. Optionally, provide the path to save the outputted results such as $HOME or "$HOME/myfluxLP"
      [Parameter(ParameterSetName='Default')]
      [ValidateScript({Test-Path $_ -PathType Container})]
      [string]$OutputPath,
    
      #Switch. Optionally, return native vSphere stat objects instead of line protocol.
      [Parameter(ParameterSetName='Default')]
      [switch]$PassThru,

      #Switch. Ignore invalid certificates when gathering stats from vCenter Server.
      [Parameter(ParameterSetName='Default')]
      [Alias('Ice')]
      [switch]$IgnoreCertificateErrors,

      #Boolean. Optionally, activate this switch to enable PowerShell transcript logging.
      [Parameter(ParameterSetName='Default')]
      [switch]$Logging,

      #String. The path to the folder to save PowerShell transcript logs. The default is $HOME.
      [Parameter(ParameterSetName='Default')]
      [ValidateScript({Test-Path $_ -PathType Container})]
      [string]$LogFolder = $HOME,
      
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

      #Switch. Optionally, activate this switch to gather and write all stats for the past Hour.
      [Parameter(ParameterSetName='Default')]
      [switch]$Repaint,

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
          [string]$LogDir            = $LogFolder
          [string]$LogName           = 'flux-compute-ps-transcript'                    #PowerShell transcript name, if any. This is the leaf of the name only; We add extension and date later.
          [string]$dt                = (Get-Date -Format 'ddMMMyyyy') | Out-String     #Creates one log file per day by default.
        }
        
        ## Output file name leaf (only used when OutputPath is populated)
        [string]$statLeaf            = 'flux_compute'                                  #If writing to file, this is the leaf of the stat output file. We add a generated guid and append .txt later
        
        ## Handle spaces in virtual machine names
        [string]$DisplayNameSpacer   = '\ '                                            #We perform a replace ' ', $DisplayNameSpacer later in the script. What you enter here is what we replace spaces with. Using '\ ' maintains the spaces, while '_' results in an underscore.
        
        ## Handle Credential from disk by hard-coded path
        [string]$vcCredentialPath    = "$HOME\CredsVcProd.enc.xml"                     #Not supported on Core editions of PowerShell. This value is ignored if the Credential or CredentialPath parameters are populated. Optionally, enter the Path to encrypted xml Credential file on disk. To create a PSCredential on disk see "help New-FluxCredential".
    
        ## Handle plain text credential
        If($Strict -eq $false){
          [string]$vcUser            = 'flux-read-only@vsphere.local'                  #This value is ignored by default unless the Strict parameter is set to $false.
          [string]$vcPass            = 'VMware123!!'                                   #This value is ignored by default unless the Strict parameter is set to $false.
        }
      
        ## stat preferences
        $VmStatTypes  = @('cpu.usage.average','cpu.usagemhz.average','mem.usage.average','net.usage.average','cpu.ready.summation') 
        $EsxStatTypes = @('cpu.usage.average','cpu.usagemhz.average','mem.usage.average','net.usage.average','cpu.ready.summation')
        
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
                Elseif(Test-Path -Path $vcCredentialPath -PathType Leaf -ErrorAction Ignore){
                  $Credential = Get-FluxCredential -Path $vcCredentialPath
                }
                Else{
                  Write-Verbose -Message 'No credential from disk available, trying more options.'
                }
              }
            }
          
            ## Consume PSCredential, if we have it by now
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
        
          ## Gather virtual machine stats
          If($Repaint){
            $stats = Get-Stat -Entity $VMs -Stat $VMStatTypes -Start ((Get-Date).AddHours(-1)) -ErrorAction SilentlyContinue
          }
          Else{
            $stats = Get-Stat -Entity $VMs -Stat $VMStatTypes -Realtime -MaxSamples 1 -ErrorAction SilentlyContinue
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
                  [string]$name = ($VMs | Where-Object {$_.Id -eq $vmstat.EntityId} | Select-Object -ExpandProperty Name) -replace ' ',$DisplayNameSpacer
                }
                Else{
                  [string]$name = ($VMs.Where{$_.Id -eq $vmstat.EntityId} | Select-Object -ExpandProperty Name) -replace ' ',$DisplayNameSpacer
                }
              
                ## Handle instance
                [string]$instance = $vmStat.Instance

                ## Handle measurement name (i.e. 'cpu.usage.average')
                [string]$measurement = $vmStat.MetricId
               
                ## Handle general info
                [int]$interval = $vmStat.IntervalSecs
                [string]$type = 'VM' #derived
                [string]$unit = $vmStat.Unit
                [string]$vc = $Server
              
                ## Handle value
                $value = $vmStat.Value
                
                ## Handle timestamp
                If($null -ne $vmStat.TimeStamp -and $Repaint){
                  $stamp = (Get-Date -Date $vmStat.TimeStamp)
                  $stampUTC = $stamp.ToUniversalTime()
                  [long]$timestamp = ([datetime]($stampUTC)-(Get-Date -Date '1/1/1970')).TotalMilliseconds * 1000000 #event time in Unix epoch
                }
                Else{
                  [long]$timestamp = (([datetime]::UtcNow)-(Get-Date -Date '1/1/1970')).TotalMilliseconds * 1000000 #current time in Unix epoch
                }
                
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
                  ## With instance (i.e. cpucores, vmnics, etc.)
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

                ## Handle ShowStats
                If($ShowStats){
                    If(-Not($PSCmdlet.MyInvocation.BoundParameters['Verbose'])) {
                      Write-Output -InputObject ''
                      Write-Output -InputObject ('Measurement: {0}' -f $measurement)
                      Write-Output -InputObject ('Value: {0}' -f $value)
                      Write-Output -InputObject ('Name: {0}' -f $Name)
                      Write-Output -InputObject ('Unix Timestamp: {0}' -f $timestamp)
                      Write-Output -InputObject ('Local time: {0}' -f (Get-Date -Format O))
                    }
                    Else {
                      #verbose
                      Write-Verbose -Message ''
                      Write-Verbose -Message ('Measurement: {0}' -f $measurement)
                      Write-Verbose -Message ('Value: {0}' -f $value)
                      Write-Verbose -Message ('Name: {0}' -f $Name)
                      Write-Verbose -Message ('Unix Timestamp: {0}' -f $timestamp)
                      Write-Verbose -Message ('Local time: {0}' -f (Get-Date -Format O))
                    } #End Else
                } #End If showstats
            } #End Foreach vm stat

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
        
          ## Gather VMHost stats
          If($Repaint){
            $stats = Get-Stat -Entity $VMHosts -Stat $EsxStatTypes -Start ((Get-Date).AddHours(-1)) -ErrorAction SilentlyContinue
          }
          Else{
            $stats = Get-Stat -Entity $VMHosts -Stat $EsxStatTypes -Realtime -MaxSamples 1 -ErrorAction SilentlyContinue
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
                    [string]$name = $VMHosts | Where-Object {$_.Id -eq $hostStat.EntityId} | Select-Object -ExpandProperty Name
                }
                Else{
                  [string]$name = ($VMHosts).Where{$_.Id -eq $hostStat.EntityId} | Select-Object -ExpandProperty Name
                }

                ## Handle instance
                [string]$instance = $hostStat.Instance

                ## Handle measurement name (i.e. 'cpu.usage.average')
                [string]$measurement = $hostStat.MetricId

                ## Handle general info
                [int]$interval = $hostStat.IntervalSecs
                [string]$type = 'VMHost' #derived
                [string]$unit = $hostStat.Unit
                [string]$vc = $global:DefaultVIServer
              
                ## Handle value
                $value = $hostStat.Value
                
                ## Handle timestamp
                If($null -ne $hostStat.TimeStamp -and $Repaint){
                  $stamp = (Get-Date -Date $hostStat.TimeStamp)
                  $stampUTC = $stamp.ToUniversalTime()
                  [long]$timestamp = ([datetime]($stampUTC)-(Get-Date -Date '1/1/1970')).TotalMilliseconds * 1000000 #event time in Unix epoch
                }
                Else{
                  [long]$timestamp = (([datetime]::UtcNow)-(Get-Date -Date '1/1/1970')).TotalMilliseconds * 1000000 #current time in Unix epoch
                }
                
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
                  ## With instance (i.e. cpucores, vmnics, etc.)
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
                
                ## Handle ShowStats
                If($ShowStats){
                  If(-Not($PSCmdlet.MyInvocation.BoundParameters['Verbose'])) {
                    Write-Output -InputObject ''
                    Write-Output -InputObject ('Measurement: {0}' -f $measurement)
                    Write-Output -InputObject ('Value: {0}' -f $value)
                    Write-Output -InputObject ('Name: {0}' -f $Name)
                    Write-Output -InputObject ('Unix Timestamp: {0}' -f $timestamp)
                    Write-Output -InputObject ('Local time: {0}' -f (Get-Date -Format O))
                  }
                  Else {
                    #verbose
                    Write-Verbose -Message ''
                    Write-Verbose -Message ('Measurement: {0}' -f $measurement)
                    Write-Verbose -Message ('Value: {0}' -f $value)
                    Write-Verbose -Message ('Name: {0}' -f $Name)
                    Write-Verbose -Message ('Unix Timestamp: {0}' -f $timestamp)
                    Write-Verbose -Message ('Local time: {0}' -f (Get-Date -Format O))
                  } #End Else
                } #End If showstats
            } #End foreach vmhost stat
          
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