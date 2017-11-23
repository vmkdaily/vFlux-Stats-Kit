#requires -Version 3

<#

    .DESCRIPTION
      Gathers VMware vSphere 'Compute' performance stats and writes them to InfluxDB.
      Use this to get CPU, Memory and Network stats for VMs or ESXi hosts.
      Note:  For disk performance metrics, see my Invoke-vFluxIOPS script.

    .NOTES
      Filename:	      Invoke-vFluxCompute.ps1
      Version:	      0.4
      Author:         Mike Nisk
      Organization:	  vmkdaily
      Tested On:      InfluxDB 1.2.2, Grafana 4.1.2, Powershell 5.1, VMware PowerCLI 6.5.4
      Requires:       PowerShell 3.0 or later (PowerShell 5.1 preferred)
      Requires:       VMware PowerCLI 5.0 or later (PowerCLI 6.5.4 or later preferred)
      Prior Art:      Inspired by, and/or snippets borrowed from:
                      Chris Wahl      -  Initial project idea and PowerCLI loader
                      Luc Dekens      -  Syntax to get datastore names and get-stat handling
                      Matt Hodge      -  Syntax inspired by Graphite-PowerShell-Functions
                      D'Haese Willem  -  Syntax inspired by naf_perfmon_to_influxdb.ps1
                      Jerad Jacob     -  Syntax for Invoke-RestMethod
	    
    CHANGELOG

      version 0.1 - 21Dec2015   -  Initial release
      version 0.2 - community releases
      version 0.3 - 14April2017
      -  Removed dependency on curl.exe and added Invoke-RestMethod (thanks Here-Be-Dragons!)
      -  Added support for PowerCLI 6.5
      -  Changed script name to comply with PowerShell standards
      -  Changed vCenter parameter to Computer
      -  Added better Verbose handling
      version 0.4 - 22Nov2017
      -  Added support for spaces in VM names
      -  Added support for spaces in Cluster names
      -  Updated the PowerCLI loader to quietly do nothing if VMware.PowerCLI exists


    .PARAMETER Computer
    String. The IP Address or DNS name of the vCenter Server machine.
    For IPv6, enclose address in square brackets, for example [fe80::250:56ff:feb0:74bd%4].
    You may connect to one vCenter.  Does not support array of strings intentionally.
    
    .PARAMETER ReportVMs
    Get realtime stats for VMs and write them to InfluxDB
    
    .PARAMETER ReportVMHosts
    Get realtime stats for ESXi hosts and write them to InfluxDB
    
    .PARAMETER ShowStats
    Optionally show some debug info on the writes to InfluxDB

    .PARAMETER Verbose
    Added slightly better support for verbose output.

    .EXAMPLE
    Invoke-vFluxCompute.ps1 -Computer <VC Name or IP> -ReportVMs
    	
    .EXAMPLE
    Invoke-vFluxCompute.ps1 -Computer <VC Name or IP> -ReportVMHosts


    //TODO - Perform get-stat in one go,
    and use Group-Object.

    //TODO - Add params for stat types or a switch to allow autoselect all available stats.
    
#>

[cmdletbinding()]
param (
    
  #String. The IP Address or DNS name of the vCenter Server machine.
  [Parameter(Mandatory,HelpMessage='vCenter Name or IP Address')]
  [String]$Computer,

  #Switch.  Activate this switch to report on VMs
  [switch]$ReportVMs,

  #Switch.  Activate this switch to report on ESX hosts
  [switch]$ReportVMHosts,

  #Switch.  Optionally, activate this switch to show debug info for InfluxDB writes.
  [switch]$ShowStats
)

Begin {

  ## InfluxDB Prefs
  $InfluxStruct = New-Object -TypeName PSObject -Property @{
    InfluxDbServer             = 'localhost'                                   #IP Address,DNS Name, or 'localhost'
    InfluxDbPort               = 8086                                          #default for InfluxDB is 8086
    InfluxDbName               = 'test'                                        #to follow my examples, set to 'compute' here and run "CREATE DATABASE compute" from Influx CLI
    InfluxDbUser               = 'esx'                                         #to follow my examples, set to 'esx' here and run "CREATE USER esx WITH PASSWORD esx WITH ALL PRIVILEGES" from Influx CLI
    InfluxDbPassword           = 'esx'                                         #to follow my examples, set to 'esx' here [see above example to create InfluxDB user and set password at the same time]
    MetricsString              = ''                                            #empty string that we populate later
  }

  ## User Prefs
  [string]$Logging             = 'On'                                          #string.  Options are 'On' or 'Off'
  [string]$LogDir              = $Env:Temp                                     #default is ok.  Optionally, set to something like 'c:\logs'
  [string]$LogName             = 'Invoke-vFluxCompute-log'                     #leaf of the name.  We add extension later.  This is the PowerShell transcript log file to create, if any
  [string]$dt                  = (Get-Date -Format 'ddMMMyyyy') | Out-String   #creates one log file per day
  [bool]$ShowRestConnections   = $true                                         #if true (default), and we're running in verbose mode, REST connection detail is returned
  [string]$DisplayNameSpacer   = '\ '                                          #handle spaces in virtual machine DisplayName by replacing with desired character (i.e. '_' which results in an underscore)
  [string]$ClusterNameSpacer   = '\ '                                          #handle spaces in vSphere cluster name by replacing with desired character (i.e. '\ ' which results in a space)
  
  ## stat preferences
  $VmStatTypes  = 'cpu.usage.average','cpu.usagemhz.average','mem.usage.average','net.usage.average','cpu.ready.summation'  
  $EsxStatTypes = 'cpu.usage.average','cpu.usagemhz.average','mem.usage.average','net.usage.average','cpu.ready.summation','disk.usage.average'
        
  #######################################
  ## No need to edit beyond this point
  #######################################

  If(-Not($PSCmdlet.MyInvocation.BoundParameters['Verbose'])) {
    $ShowRestConnections = $false #do not edit
  }
	
  ## Create the variables that we consume with Invoke-RestMethod later.
  $authheader = 'Basic ' + ([Convert]::ToBase64String([Text.encoding]::ASCII.GetBytes(('{0}:{1}' -f $InfluxStruct.InfluxDbUser, $InfluxStruct.InfluxDbPassword))))
  $uri = ('http://{0}:{1}/write?db={2}' -f $InfluxStruct.InfluxDbServer, $InfluxStruct.InfluxDbPort, $InfluxStruct.InfluxDbName)

  ## Start Logging
  If ($Logging -eq 'On') {
    Start-Transcript -Append -Path "$LogDir\$LogName-$dt.log"
  }

} #End Begin

Process {

  #Import PowerCLI module/snapin if needed.
  If(-Not(Get-Module -Name VMware.PowerCLI -ListAvailable -ErrorAction SilentlyContinue)){
    
    #In case its not autoloading
    try{
      $null = Get-Module -ListAvailable -Name VMware.PowerCLI | Import-Module -ErrorAction Stop
    }
    catch{
      $vMods = Get-Module -Name VMware.* -ListAvailable -Verbose:$false
      If($vMods) {
        foreach ($mod in $vMods) {
          Import-Module -Name $mod -ErrorAction Stop -Verbose:$false
        }
        Write-Verbose -Message 'PowerCLI 6.x Module(s) imported.'
      }
      Else {
        If(!(Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) {
          Try {
            Add-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction Stop
            Write-Verbose -Message 'PowerCLI 5.x Snapin added; recommend upgrading to PowerCLI 6.x'
          }
          Catch {
            Write-Warning -Message 'Could not load PowerCLI'
            Throw 'PowerCLI 5 or later required'
          }
        }
      }
    }
  }

  ## Connect to vCenter
  try {
    $null = Connect-VIServer -Server $Computer -WarningAction Continue -ErrorAction Stop
  }
  Catch {
    Write-Warning -Message ('{0}' -f $_.Exception.Message)
  }

  If (!$Global:DefaultVIServer -or ($Global:DefaultVIServer -and !$Global:DefaultVIServer.IsConnected)) {
    Throw 'vCenter Connection Required!'
  }
  Else {
    Write-Verbose -Message ('Connected to {0}' -f ($Global:DefaultVIServer))
    Write-Verbose -Message 'Beginning stat collection.'
  }

  If($ReportVMs) {

    ## Start script execution timer
    $vCenterStartDTM = (Get-Date)

    ## Enumerate VM list
    $VMs = Get-VM | Where-Object {$_.PowerState -eq 'PoweredOn'} | Sort-Object -Property Name
        
    ## Iterate through VM list
    foreach ($vm in $VMs) {
    
      ## Gather desired stats
      $stats = Get-Stat -Entity $vm -Stat $VMStatTypes -Realtime -MaxSamples 1
      
      foreach ($stat in $stats) {
            
        ## Create and populate variables for the purpose of writing to InfluxDB Line Protocol
        $measurement = $stat.MetricId
        $value = $stat.Value
        $name = ($vm | Select-Object -ExpandProperty Name) -replace ' ',$DisplayNameSpacer
        $type = 'VM'
        $numcpu = $vm.ExtensionData.Config.Hardware.NumCPU
        $memorygb = $vm.ExtensionData.Config.Hardware.MemoryMB/1KB
        $interval = $stat.IntervalSecs
        $unit = $stat.Unit
        $vc = ($global:DefaultVIServer).Name
        $cluster = ($vm.VMHost.Parent | Select-Object -ExpandProperty Name) -replace ' ',$ClusterNameSpacer
        [long]$timestamp = (([datetime]::UtcNow)-(Get-Date -Date '1/1/1970')).TotalMilliseconds * 1000000 #nanoseconds since Unix epoch

        ## handle instance
        $instance = $stat.Instance
                
        ## handle ready stat
        If($stat.MetricID -eq 'cpu.ready.summation') {
          $ready = [math]::Round($(($stat.Value / ($stat.IntervalSecs * 1000)) * 100), 2)
          $value = $ready
        }
                
        ## build it
        If(-Not($instance) -or ($instance -eq '')) {
          #do not return instance
          $InfluxStruct.MetricsString = ''
          $InfluxStruct.MetricsString += ('{0},host={1},type={2},vc={3},cluster={4},unit={5},interval={6},numcpu={7},memorygb={8} value={9} {10}' -f $measurement, $name, $type, $vc, $cluster, $Unit, $interval, $numcpu, $memorygb, $value, $timestamp)
          $InfluxStruct.MetricsString += "`n"
        }
        Else {
          #return instance (i.e. cpucores, vmnics, etc.)
          $InfluxStruct.MetricsString = ''
          $InfluxStruct.MetricsString += ('{0},host={1},type={2},vc={3},cluster={4},unit={5},interval={6},instance={7},numcpu={8},memorygb={9} value={10} {11}' -f $measurement, $name, $type, $vc, $cluster, $Unit, $interval, $instance, $numcpu, $memorygb, $value, $timestamp)
          $InfluxStruct.MetricsString += "`n"
        }

        ## write it
        Try {
          Invoke-RestMethod -Headers @{Authorization=$authheader} -Uri $uri -Method POST -Body $InfluxStruct.MetricsString -Verbose:$ShowRestConnections -ErrorAction Stop
        }
        Catch {
          Write-Warning -Message ('Problem writing {0} for {1} at {2}' -f ($measurement), ($vm), (Get-Date))
          Write-Warning -Message ('{0}' -f $_.Exception.Message)
        }
                           
        ## view it
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
        } #End If show stats
      } #end foreach stat
    } #end reportvm loop

    ## Runtime Summary
    $vCenterEndDTM = (Get-Date)
    $vmCount = ($VMs | Measure-Object).count
    $ElapsedTotal = ($vCenterEndDTM-$vCenterStartDTM).totalseconds

    ## show per VM runtimes if in verbose
    If($stats){
      If($PSCmdlet.MyInvocation.BoundParameters['Verbose']) {
        Write-Verbose -Message ''
        Write-Verbose -Message 'Runtime Summary:'
        Write-Verbose -Message ('Elapsed Processing Time: {0} seconds' -f ($ElapsedTotal))
        If($vmCount -gt 1) {
          $TimePerVM = $ElapsedTotal / $vmCount
          Write-Verbose -Message ('Processing Time Per VM: {0} seconds' -f ($TimePerVM))
        } #End If count
      } #End If verbose
    } #End If stats
  } #End report VMs
    
  If($ReportVMHosts) {

    ## Iterate through ESXi Host list
    foreach ($EsxImpl in (Get-VMhost | Where-Object {$_.State -eq 'Connected'} | Sort-Object -Property Name)) {
    
      ## Gather desired stats
      $stats = Get-Stat -Entity $EsxImpl -Stat $EsxStatTypes -Realtime -MaxSamples 1
      foreach ($stat in $stats) {
            
        ## Create and populate variables for the purpose of writing to InfluxDB Line Protocol
        $measurement = $stat.MetricId
        $value = $stat.Value
        $name = $EsxImpl | Select-Object -ExpandProperty Name
        $type = 'VMHost'
        $interval = $stat.IntervalSecs
        $unit = $stat.Unit
        $vc = ($global:DefaultVIServer).Name
        $cluster = ($EsxImpl.Parent | Select-Object -ExpandProperty Name) -replace ' ',$ClusterNameSpacer
        [long]$timestamp = (([datetime]::UtcNow)-(Get-Date -Date '1/1/1970')).TotalMilliseconds * 1000000 #nanoseconds since Unix epoch

        ##handle instance
        $instance = $stat.Instance
        
        ##handle ready stat
        If($stat.MetricID -eq 'cpu.ready.summation') {
          $ready = [math]::Round($(($stat.Value / ($stat.IntervalSecs * 1000)) * 100), 2)
          $value = $ready
        }
                
        ## build it
        If(-Not($instance) -or ($instance -eq '')) {
          #do not return instance
          $InfluxStruct.MetricsString = ''
          $InfluxStruct.MetricsString += ('{0},host={1},type={2},vc={3},cluster={4},unit={5},interval={6} value={7} {8}' -f $measurement, $name, $type, $vc, $cluster, $Unit, $interval, $value, $timestamp)
          $InfluxStruct.MetricsString += "`n"
        }
        Else {
          #return instance (i.e. cpucores, vmnics, etc.)
          $InfluxStruct.MetricsString = ''
          $InfluxStruct.MetricsString += ('{0},host={1},type={2},vc={3},cluster={4},unit={5},interval={6},instance={7} value={8} {9}' -f $measurement, $name, $type, $vc, $cluster, $Unit, $interval, $instance, $value, $timestamp)
          $InfluxStruct.MetricsString += "`n"
        }
                
        ## write it
        Try {
          Invoke-RestMethod -Headers @{Authorization=$authheader} -Uri $uri -Method POST -Body $InfluxStruct.MetricsString -Verbose:$ShowRestConnections -ErrorAction Stop
        }
        Catch {
          Write-Warning -Message ('Problem writing {0} for {1} at {2}' -f ($measurement), ($vm), (Get-Date))
          Write-Warning -Message ('{0}' -f $_.Exception.Message)
        }

        ## view it
        If($ShowStats) {

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
      } #End foreach
    } #End foreach
  } #End If
} #End Process
    
End {
  $null = Disconnect-VIServer -Server '*' -Confirm:$false -Force -ErrorAction SilentlyContinue
  Write-Verbose -Message 'Script complete.'
  If ($Logging -eq 'On') { Stop-Transcript }
} #End End
