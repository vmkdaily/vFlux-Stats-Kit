
<#	
    .NOTES
	=========================================================================================================
        Filename:	vFlux-IOPS.ps1
        Version:	0.1c 
        Created:	12/21/2015
        Updated:	    27March2016
        Requires:       curl.exe for Windows (https://curl.haxx.se/download.html)
        Requires:       InfluxDB 0.9.4 or later.  The latest 0.10.x is preferred.
        Requires:       Grafana 2.5 or later.  The latest 2.6.x is preferred.
        Prior Art:      Uses MattHodge's InfluxDB write protocol syntax 
        Author:         Mike Nisk (a.k.a. 'grasshopper')
        Twitter:	    @vmkdaily
	=========================================================================================================
	
    .SYNOPSIS
	Gathers VMware vSphere virtual machine disk stats and writes them to InfluxDB.  This script understands
        NFS and VMFS and gathers the appropriate stat type accordingly.

    .DESCRIPTION
        This PowerCLI script supports InfluxDB 0.9.4 and later (including the latest 0.10.x).
        The InfluxDB write syntax is based on naf_perfmon_to_influxdb.ps1 by D'Haese Willem,
        which itself is based on MattHodge's Graphite-PowerShell-Functions.
        Please note that we use curl.exe for InfluxDB line protocol writes.  This means you must
        download curl.exe for Windows in order for Powershell to write to InfluxDB.

    .PARAMETER vCenter
     	The name or IP address of the vCenter Server to connect to
    
    .PARAMETER ShowStats
        Optionally show some debug info on the writes to InfluxDB

    .EXAMPLE
        vFlux-IOPS.ps1 -vCenter <VC Name or IP>
    
    .EXAMPLE
        vFlux-IOPS.ps1 -vCenter <VC Name or IP> -ShowStats

#>

[cmdletbinding()]
param (
    [Parameter(Mandatory = $True)]
    [String]$vCenter,

    [Parameter(Mandatory = $False)]
    [switch]$ShowStats
)

Begin {

    ## User-Defined Influx Setup
    $InfluxStruct = New-Object -TypeName PSObject -Property @{
	CurlPath = 'C:\Windows\System32\curl.exe';
        InfluxDbServer = '1.2.3.4'; #IP Address
        InfluxDbPort = 8086;
        InfluxDbName = 'iops';
        InfluxDbUser = 'esx';
        InfluxDbPassword = 'esx';
        MetricsString = '' #emtpy string that we populate later.
    }

    ##  User-Defined Logging Preferences
    $Logging = 'off'
    $LogDir = 'C:\bin\logs'
    $LogName = 'vFlux-IOPS.log'

    ## User-defined Datastores to Ignore
    ## The default is to report stats for all VMs, including those running on local and ISO datastores.
    ## To continue reporting on all such VMs, leave the following variables null ("")
    $dasd = ""
    $iso = "" 

    ## Exclusive of the above option, to hide your local and ISO datastores from reporting, customize and uncomment the following.
    ## In this example, stats are not collected for VMs running on datastores with 'local' or 'utils' in the name.
    #$dasd = "*local*"
    #$iso = "*utils*"
}

    #####################################
    ## No need to edit beyond this point
    #####################################

Process {

    ## Start Logging
    $dt = Get-Date -Format 'ddMMMyyyy_HHmm'
    If (Test-Path -Path C:\temp) { $TempDir = 'C:\temp' } Else { $TempDir = Get-Path -Path $Env:TEMP }
    If (!(Test-Path -Path $LogDir)) { $LogDir = $TempDir }
    If ($Logging -eq 'On') { Start-Transcript -Append -Path $LogDir\$LogName }

    ## Get the PowerCLI snapin if needed
    if ((Get-PSSnapin -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue) -eq $null) { Add-PSSnapin -Name VMware.VimAutomation.Core }

    ## Connect to vCenter
    Connect-VIServer $vCenter | Out-Null

    If (!$Global:DefaultVIServer -or ($Global:DefaultVIServer -and !$Global:DefaultVIServer.IsConnected)) { Throw "vCenter Connection Required!" }
    Get-Datacenter | Out-Null # clear first slow API access
    Write-Output -InputObject "Connected to $Global:DefaultVIServer"

    ## Start script execution timer
    $vCenterStartDTM = (Get-Date)

    #Region Datastore Enumeration
    $ds = Get-Datastore

    $dsLocal = $ds | Where-Object { $_.Type -eq "VMFS" -and $_.Name -like $dasd }
    $dsVMFS = $ds | Where-Object { $_.Type -eq "VMFS" -and $_.Name -notlike $dasd -and $_.Name -notlike $iso }
    $dsNFS = $ds | Where-Object { $_.Type -eq "NFS" -and $_.Name -notlike $iso }
    $dsISO = $ds | Where-Object { $_.Name -like $iso }

    ## Running VMs by storage type
    $BlockVMs = $dsVMFS | Get-VM | Where-Object { $_.PowerState -eq "PoweredOn" } | Sort-Object -Property $_.VMHost
    $NfsVMs = $dsNFS | Get-VM | Where-Object { $_.PowerState -eq "PoweredOn" } | Sort-Object -Property $_.VMHost

    ## Datastore and VM counts by type
    $localDsCount = ($dsLocal).Count
    $VmfsDsCount = ($dsVMFS).Count
    $NfsDsCount = ($dsNFS).Count
    $VmfsVMsCount = ($BlockVMs).Count
    $NfsVMsCount = ($NfsVMs).Count

    If($ShowStats){
    ## debug console output
    Write-Output -InputObject "`n$DefaultVIServer Overview"
    Write-Output -InputObject "Local Datastores:$localDsCount"
    Write-Output -InputObject "VMFS Datastores: $VmfsDsCount"
    Write-Output -InputObject "NFS Datastores: $NfsDsCount"
    Write-Output -InputObject "Block VMs: $VmfsVMsCount"
    Write-Output -InputObject "NFS VMs: $NfsVMsCount"
    Write-Output -InputObject "`nBeginning stat collection."
    }

    ## VMFS Block VM Section
    If($BlockVMs) {

        ## Desired vSphere metrics for block-based virtual machine performance reporting
        $BlockStatTypes = 'disk.numberwrite.summation','disk.numberread.summation','disk.maxTotalLatency.latest'
    
        ## Iterate through VMFS Block VM list
        foreach ($vm in $BlockVMs) {
            
                ## Gather desired stats
                $stats = Get-Stat -Entity $vm -Stat $BlockStatTypes -Realtime -MaxSamples 1
                    foreach ($stat in $stats) {
            
                        ## Create and populate variables for the purpose of writing to InfluxDB Line Protocol
                        $measurement = $stat.MetricId
                        $value = $stat.Value
                        $name = $vm.Name
                        $type = 'VM'
                        $DiskType = 'Block'
                        If($stat.Instance) {$instance = $stat.Instance} Else {$instance -eq $null}
                        if($stat.Unit) {$unit = $stat.Unit} Else {$unit -eq $null}
                        $vc = ($global:DefaultVIServer).Name
                        $cluster = $vm.VMHost.Parent
                        [int64]$timestamp = (([datetime]::UtcNow)-(Get-Date -Date "1/1/1970")).TotalMilliseconds * 1000000 #nanoseconds since Unix epoch

                        ## Write to InfluxDB for this VMFS Block VM iteration
                        $InfluxStruct.MetricsString = ''
                        $InfluxStruct.MetricsString += "$measurement,host=$name,type=$type,vc=$vc,cluster=$cluster,disktype=$DiskType,instance=$instance,unit=$Unit value=$value $timestamp"
                        $InfluxStruct.MetricsString += "`n"
                        $CurlCommand = "$($InfluxStruct.CurlPath) -u $($InfluxStruct.InfluxDbUser):$($InfluxStruct.InfluxDbPassword) -i -XPOST `"http://$($InfluxStruct.InfluxDbServer):$($InfluxStruct.InfluxDbPort)/write?db=$($InfluxStruct.InfluxDbName)`" --data-binary `'$($InfluxStruct.MetricsString)`'"
                        Invoke-Expression -Command $CurlCommand 2>&1
            
                ## debug output
                If($ShowStats){
                Write-Output -InputObject "Measurement: $measurement"
                Write-Output -InputObject "Value: $value"
                Write-Output -InputObject "Name: $Name"
                Write-Output -InputObject "Unix Timestamp: $timestamp`n"
                Write-Output -InputObject ''
                }
            }
        }
    }

    ## NFS VM Section
    If($NfsVMs) {

        ## Desired vSphere metrics for NFS-based virtual machine performance reporting
        $NfsStatTypes = 'virtualdisk.numberwriteaveraged.average','virtualdisk.numberreadaveraged.average','virtualDisk.readLatencyUS.latest','virtualDisk.writeLatencyUS.latest'

            ## Iterate through NFS VM list
            foreach ($vm in $NfsVMs) {
    
                ## Gather desired stats
                $stats = Get-Stat -Entity $vm -Stat $NfsStatTypes -Realtime -MaxSamples 1
                    foreach ($stat in $stats) {
            
                        ## Create and populate variables for the purpose of writing to InfluxDB Line Protocol
                        $measurement = $stat.MetricId
                        $value = $stat.Value
                        $name = $vm.Name
                        $type = 'VM'
                        $DiskType = 'NFS'
                        If($stat.Instance) {$instance = $stat.Instance} Else {$instance -eq $null}
                        if($stat.Unit) {$unit = $stat.Unit} Else {$unit -eq $null}
                        $vc = ($global:DefaultVIServer).Name
                        $cluster = $vm.VMHost.Parent
                        [int64]$timestamp = (([datetime]::UtcNow)-(Get-Date -Date "1/1/1970")).TotalMilliseconds * 1000000 #nanoseconds since Unix epoch

                        ## Write to InfluxDB for this NFS VM iteration
                        $InfluxStruct.MetricsString = ''
                        $InfluxStruct.MetricsString += "$measurement,host=$name,type=$type,vc=$vc,cluster=$cluster,disktype=$DiskType,instance=$instance,unit=$Unit value=$value $timestamp"
                        $InfluxStruct.MetricsString += "`n"
                        $CurlCommand = "$($InfluxStruct.CurlPath) -u $($InfluxStruct.InfluxDbUser):$($InfluxStruct.InfluxDbPassword) -i -XPOST `"http://$($InfluxStruct.InfluxDbServer):$($InfluxStruct.InfluxDbPort)/write?db=$($InfluxStruct.InfluxDbName)`" --data-binary `'$($InfluxStruct.MetricsString)`'"
                        Invoke-Expression -Command $CurlCommand 2>&1

                ## debug console output
                If($ShowStats){
                Write-Output -InputObject "Measurement: $measurement"
                Write-Output -InputObject "Value: $value"
                Write-Output -InputObject "Name: $Name"
                Write-Output -InputObject "Unix Timestamp: $timestamp`n"
                Write-Output -InputObject ''
                }
            }
        }
    }

    Disconnect-VIServer '*' -Confirm:$false
    Write-Output -InputObject "Script complete.`n"
    If ($Logging -eq 'On') { Stop-Transcript }
}
