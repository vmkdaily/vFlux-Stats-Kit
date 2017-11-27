#requires -Version 3

<#

    .DESCRIPTION
      Gathers VMware vSphere virtual machine disk stats and writes them to InfluxDB.
      Understands both NFS and VMFS and gathers the appropriate stat type accordingly.
      Does not support returning of vSAN stats. 

    .NOTES
      Filename:	      Invoke-vFluxIOPS.ps1
      Version:	      0.4
      Author:         Mike Nisk
      Organization:	  vmkdaily
      Tested On:      InfluxDB 1.2.2, Grafana 4.1.2, Microsoft Powershell 5.1, VMware PowerCLI 6.5.4
      Requires:       PowerShell 3.0 or later (PowerShell 5.1 preferred)
      Requires:       VMware PowerCLI 5.0 or later (PowerCLI 6.5.4 or later preferred)
      Prior Art:      Inspired by and/or snippets taken from:
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
          -  Changed script name to comply with PowerShell verb-noun standards
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
    
    .PARAMETER ShowStats
      Optionally show some debug info on the writes to InfluxDB

    .EXAMPLE
    Invoke-vFluxIOPS -Computer <VC Name or IP>
    
    .EXAMPLE
    Invoke-vFluxIOPS -Computer <VC Name or IP> -ShowStats


    //TODO - Perform get-stat in one go,
           and use Group-Object.

    //TODO - Add params for stat types

#>

[cmdletbinding()]
param (

    #String. The IP Address or DNS name of the vCenter Server machine.
    [Parameter(Mandatory,HelpMessage='vCenter Name or IP Address')]
    [String]$Computer,

    #Switch.  Optionally, activate this switch to show debug info for InfluxDB writes.
    [switch]$ShowStats
)

Begin {

    ## InfluxDB Prefs
    $InfluxStruct = New-Object -TypeName PSObject -Property @{
        InfluxDbServer           = 'localhost'                                    #IP Address,DNS Name, or 'localhost'
        InfluxDbPort             = 8086                                           #default for InfluxDB is 8086
        InfluxDbName             = 'iops'                                         #to follow my examples, set to 'iops' here and run "CREATE DATABASE iops" from Influx CLI
        InfluxDbUser             = 'esx'                                          #to follow my examples, set to 'esx' here and run "CREATE USER esx WITH PASSWORD esx WITH ALL PRIVILEGES" from Influx CLI
        InfluxDbPassword         = 'esx'                                          #to follow my examples, set to 'esx' [see above example to create InfluxDB user and set password at the same time]
        MetricsString            = ''                                             #empty string that we populate later.
    }

    ## User Prefs
    [string]$Logging             = 'Off'                                          #string. Options are 'On' or 'Off'
    [string]$LogDir              = $Env:Temp                                      #default is ok.  Optionally, set to something like 'c:\logs'
    [string]$LogName             = 'vFlux-IOPS'                                   #leaf of the name.  We add extension later.  This is the PowerShell transcript log file to create, if any
    [string]$dt                  = (Get-Date -Format 'ddMMMyyyy') | Out-String    #creates one log file per day
    [bool]$ShowRestConnections   = $true                                          #if true (default), and we're running in verbose mode, REST connection detail is returned
    [string]$DisplayNameSpacer   = '\ '                                           #handle spaces in virtual machine DisplayName by replacing with desired character (i.e. '_' which results in an underscore)
    [string]$ClusterNameSpacer   = '\ '                                           #handle spaces in vSphere cluster name by replacing with desired character (i.e. '\ ' which results in a space)

    ## stat preferences
    $BlockStatTypes = 'disk.maxTotalLatency.latest','disk.numberread.summation','disk.numberwrite.summation'
    $NfsStatTypes = 'virtualdisk.numberreadaveraged.average','virtualdisk.numberwriteaveraged.average','virtualDisk.readLatencyUS.latest','virtualDisk.writeLatencyUS.latest'

    ## User-defined Datastores to Ignore
    ## The default is to report stats for all VMs, including those running on local and ISO datastores.
    ## To continue reporting on all such VMs, leave the following variables null ('')
    $dasd = ''
    $iso = '' 

    ## Exclusive of the above option, to hide your local and ISO datastores from reporting, customize and uncomment the following.
    ## In this example, stats are not collected for VMs running on datastores with 'local' or 'utils' in the name.
    #$dasd = "*local*"
    #$iso = "*utils*"

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

    
    #Import PowerCLI module/snapin if needed
    If(-Not(Get-Module -Name VMware.PowerCLI -ListAvailable -ErrorAction SilentlyContinue)){
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
        Write-Verbose -Message ('Beginning stat collection on {0}' -f ($Global:DefaultVIServer))
    }

    #Region Datastore Enumeration
    $ds = Get-Datastore

    $dsLocal = $ds | Where-Object { $_.Type -eq 'VMFS' -and $_.Name -like $dasd }
    $dsVMFS = $ds | Where-Object { $_.Type -eq 'VMFS' -and $_.Name -notlike $dasd -and $_.Name -notlike $iso }
    $dsNFS = $ds | Where-Object { $_.Type -eq 'NFS' -and $_.Name -notlike $iso }
    $dsISO = $ds | Where-Object { $_.Name -like $iso }

    ## Running VMs by storage type
    $BlockVMs = $dsVMFS | Get-VM | Where-Object { $_.PowerState -eq 'PoweredOn' } | Sort-Object -Property $_.VMHost
    $NfsVMs = $dsNFS | Get-VM | Where-Object { $_.PowerState -eq 'PoweredOn' } | Sort-Object -Property $_.VMHost

    ## Datastore and VM counts by type
    $localDsCount = ($dsLocal).Count
    $VmfsDsCount = ($dsVMFS).Count
    $NfsDsCount = ($dsNFS).Count
    $VmfsVMsCount = ($BlockVMs).Count
    $NfsVMsCount = ($NfsVMs).Count

    If($ShowStats){
        If(-Not($PSCmdlet.MyInvocation.BoundParameters['Verbose'])) {
            ## debug console output
            Write-Output -InputObject ''
            Write-Output -InputObject ('{0} Overview' -f $DefaultVIServer)
            Write-Output -InputObject ('Local Datastores:{0}' -f $localDsCount)
            Write-Output -InputObject ('VMFS Datastores: {0}' -f $VmfsDsCount)
            Write-Output -InputObject ('NFS Datastores: {0}' -f $NfsDsCount)
            Write-Output -InputObject ('Block VMs: {0}' -f $VmfsVMsCount)
            Write-Output -InputObject ('NFS VMs: {0}' -f $NfsVMsCount)
        }
        Else {
            ## debug console output
            Write-Verbose -Message ''
            Write-Verbose -Message ('{0} Overview' -f $DefaultVIServer)
            Write-Verbose -Message ('Local Datastores:{0}' -f $localDsCount)
            Write-Verbose -Message ('VMFS Datastores: {0}' -f $VmfsDsCount)
            Write-Verbose -Message ('NFS Datastores: {0}' -f $NfsDsCount)
            Write-Verbose -Message ('Block VMs: {0}' -f $VmfsVMsCount)
            Write-Verbose -Message ('NFS VMs: {0}' -f $NfsVMsCount)
        }
    }

    ## VMFS Block VM Section
    If($BlockVMs) {

        ## Iterate through VMFS Block VM list
        foreach ($vm in $BlockVMs) {
            
            ## Gather desired stats
            $stats = Get-Stat -Entity $vm -Stat $BlockStatTypes -Realtime -MaxSamples 1
            foreach ($stat in $stats) {
            
                ## Create and populate variables for the purpose of writing to InfluxDB Line Protocol
                $measurement = $stat.MetricId
                $name = ($vm | Select-Object -ExpandProperty Name) -replace ' ',$DisplayNameSpacer
                $type = 'VM'
                $vc = ($global:DefaultVIServer).Name
                $cluster = ($vm.VMHost.Parent | Select-Object -ExpandProperty Name) -replace ' ',$ClusterNameSpacer
                $unit = $stat.Unit
                $interval = $stat.IntervalSecs
                $DiskType = 'Block'
                $value = $stat.Value
                [long]$timestamp = (([datetime]::UtcNow)-(Get-Date -Date '1/1/1970')).TotalMilliseconds * 1000000 #nanoseconds since Unix epoch

                ## handle instance
                $instance = $stat.Instance
                
                ## build it
                If(-Not($instance) -or ($instance -eq '')) {
                  #do not return instance
                  $InfluxStruct.MetricsString = ''
                  $InfluxStruct.MetricsString += ('{0},host={1},type={2},vc={3},cluster={4},unit={5},interval={6},disktype={7} value={8} {9}' -f $measurement, $name, $type, $vc, $cluster, $Unit, $interval, $DiskType, $value, $timestamp)
                  $InfluxStruct.MetricsString += "`n"
                }
                Else {
                  #return instance
                  $InfluxStruct.MetricsString = ''
                  $InfluxStruct.MetricsString += ('{0},host={1},type={2},vc={3},cluster={4},unit={5},interval={6},disktype={7},instance={8} value={9} {10}' -f $measurement, $name, $type, $vc, $cluster, $Unit, $interval, $DiskType, $instance, $value, $timestamp)
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
            } #End foreach stat
        } #End foreach block vm
    } #End if block vms

    ## NFS VM Section
    If($NfsVMs) {

        ## Iterate through NFS VM list
        foreach ($vm in $NfsVMs) {
    
            ## Gather desired stats
            $stats = Get-Stat -Entity $vm -Stat $NfsStatTypes -Realtime -MaxSamples 1 | Where-Object { $_.Instance -ne ''}
            foreach ($stat in $stats) {
            
                ## Create and populate variables for the purpose of writing to InfluxDB Line Protocol
                $measurement = $stat.MetricId
                $value = $stat.Value
                $name = ($vm | Select-Object -ExpandProperty Name) -replace ' ',$DisplayNameSpacer
                $type = 'VM'
                $DiskType = 'NFS'
                $unit = $stat.Unit
                $interval = $stat.IntervalSecs
                $vc = ($global:DefaultVIServer).Name
                $cluster = ($vm.VMHost.Parent | Select-Object -ExpandProperty Name) -replace ' ',$ClusterNameSpacer
                [long]$timestamp = (([datetime]::UtcNow)-(Get-Date -Date '1/1/1970')).TotalMilliseconds * 1000000 #nanoseconds since Unix epoch

                ## handle instance
                $instance = $stat.Instance
                
                ## build it
                $InfluxStruct.MetricsString = ''
                $InfluxStruct.MetricsString += ('{0},host={1},type={2},vc={3},cluster={4},unit={5},interval={6},disktype={7},instance={8} value={9} {10}' -f $measurement, $name, $type, $vc, $cluster, $Unit, $interval, $DiskType, $instance, $value, $timestamp)
                $InfluxStruct.MetricsString += "`n"
                
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
        } #End foreach vm
    } #End If NFS
} #End Process

End {
  $null = Disconnect-VIServer -Server '*' -Confirm:$false -Force -ErrorAction SilentlyContinue
  Write-Verbose -Message 'Script complete.'
  If ($Logging -eq 'On') { Stop-Transcript }
}
