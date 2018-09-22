
<#	
    .NOTES
	=========================================================================================================
        Filename:	vFlux-Compute.ps1
        Version:	0.1c 
        Created:	12/21/2015
	    Updated:	28March2016
        Requires:       curl.exe for Windows (https://curl.haxx.se/download.html)
	    Requires:       InfluxDB 0.9.4 or later.  The latest 0.10.x is preferred.
        Requires:       Grafana 2.5 or later.  The latest 2.6 is preferred.
        Prior Art:      Uses MattHodge's InfluxDB write protocol syntax 
	    Author:         Mike Nisk (a.k.a. 'grasshopper')
	    Twitter:	@vmkdaily
	=========================================================================================================
	
    .SYNOPSIS
	    Gathers VMware vSphere 'Compute' performance stats and writes them to InfluxDB.
        Use this to get CPU, Memory and Network stats for VMs or ESXi hosts.
        Note:  For disk performance metrics, see my vFlux-IOPS script.

    .DESCRIPTION
        This PowerCLI script supports InfluxDB 0.9.4 and later (including the latest 0.10.x).
        The InfluxDB write syntax is based on naf_perfmon_to_influxdb.ps1 by D'Haese Willem,
        which itself is based on MattHodge's Graphite-PowerShell-Functions.
        Please note that we use curl.exe for InfluxDB line protocol writes.  This means you must
        download curl.exe for Windows in order for Powershell to write to InfluxDB.
    
    .PARAMETER vCenter
        The name or IP address of the vCenter Server to connect to
    
    .PARAMETER ReportVMs
        Get realtime stats for VMs and write them to InfluxDB
    
    .PARAMETER ReportVMHosts
        Get realtime stats for ESXi hosts and write them to InfluxDB
    
    .PARAMETER ShowStats
        Optionally show some debug info on the writes to InfluxDB

    .EXAMPLE
    	vFlux-Compute.ps1 -vCenter <VC Name or IP> -ReportVMs
    	
    .EXAMPLE
    	vFlux-Compute.ps1 -vCenter <VC Name or IP> -ReportVMHosts

#>

[cmdletbinding()]
param (
    [Parameter(Mandatory = $True)]
    [String]$vCenter,

    [Parameter(Mandatory = $False)]
    [switch]$ReportVMs,

    [Parameter(Mandatory = $False)]
    [switch]$ReportVMHosts,

    [Parameter(Mandatory = $False)]
    [switch]$ShowStats
)

Begin {

    ## User-Defined Influx Setup
    $InfluxStruct = New-Object -TypeName PSObject -Property @{
	CurlPath = 'C:\Windows\System32\curl.exe';
        InfluxDbServer = '1.2.3.4'; #IP Address
        InfluxDbPort = 8086;
        InfluxDbName = 'compute';
        InfluxDbUser = 'esx';
        InfluxDbPassword = 'esx';
        MetricsString = '' #emtpy string that we populate later.
    }

    ## User-Defined Preferences
    $Logging = 'off'
    $LogDir = 'C:\bin\logs'
    $LogName = 'vFlux-Compute.log'
    $ReadyMaxAllowed = .20  #acceptable %ready time per vCPU.  Typical max is .10 to .20.

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
    
    If (!$Global:DefaultVIServer -or ($Global:DefaultVIServer -and !$Global:DefaultVIServer.IsConnected)) {
    Throw "vCenter Connection Required!"
    }

    Get-Datacenter | Out-Null # clear first slow API access
    Write-Output -InputObject "Connected to $Global:DefaultVIServer"
    Write-Output -InputObject "Beginning stat collection.`n"

    If($ReportVMs) {

        ## Desired vSphere metric counters for virtual machine performance reporting
        $VmStatTypes = 'cpu.usagemhz.average','cpu.usage.average','cpu.ready.summation','mem.usage.average','net.usage.average'
    
        ## Start script execution timer
        $vCenterStartDTM = (Get-Date)

        ## Enumerate VM list
        $VMs = Get-VM | Where-Object {$_.PowerState -eq "PoweredOn"} | Sort-Object -Property Name
        
        ## Iterate through VM list
        foreach ($vm in $VMs) {
    
            ## Gather desired stats
            $stats = Get-Stat -Entity $vm -Stat $VMStatTypes -Realtime -MaxSamples 1
            foreach ($stat in $stats) {
            
                ## Create and populate variables for the purpose of writing to InfluxDB Line Protocol
                $measurement = $stat.MetricId
                $value = $stat.Value
                $name = $vm.Name
                $type = 'VM'
                $numcpu = $vm.ExtensionData.Config.Hardware.NumCPU
                $memorygb = $vm.ExtensionData.Config.Hardware.MemoryMB/1KB
                $interval = $stat.IntervalSecs
                If($stat.MetricID -eq 'cpu.ready.summation') {
                    $ready = [math]::Round($(($stat.Value / ($stat.IntervalSecs * 1000)) * 100), 2)
                    $value = $ready
                    $EffectiveReadyMaxAllowed = $numcpu * $ReadyMaxAllowed
                    $rdyhealth = $numcpu * $ReadyMaxAllowed - $value
                    }
                If($stat.Instance) {$instance = $stat.Instance} Else {$instance -eq $null}
                If($stat.Unit) {$unit = $stat.Unit} Else {$unit -eq $null}
                $vc = ($global:DefaultVIServer).Name
                $cluster = $vm.VMHost.Parent
                [int64]$timestamp = (([datetime]::UtcNow)-(Get-Date -Date "1/1/1970")).TotalMilliseconds * 1000000 #nanoseconds since Unix epoch

                ## Write to InfluxDB for this VM iteration
                $InfluxStruct.MetricsString = ''
                $InfluxStruct.MetricsString += "$measurement,host=$name,type=$type,vc=$vc,cluster=$cluster,instance=$instance,unit=$Unit,interval=$interval,numcpu=$numcpu,memorygb=$memorygb value=$value $timestamp"
                $InfluxStruct.MetricsString += "`n"
                $CurlCommand = "$($InfluxStruct.CurlPath) -u $($InfluxStruct.InfluxDbUser):$($InfluxStruct.InfluxDbPassword) -i -XPOST `"http://$($InfluxStruct.InfluxDbServer):$($InfluxStruct.InfluxDbPort)/write?db=$($InfluxStruct.InfluxDbName)`" --data-binary `'$($InfluxStruct.MetricsString)`'"
                Invoke-Expression -Command $CurlCommand 2>&1
                            
                ## If reporting on %ready, add a derived metric that evaluates the ready health
                If($stat.MetricID -eq 'cpu.ready.summation' -and $rdyhealth) {
                    $measurement = 'cpu.ready.health.derived'
                    $value = $rdyhealth
                    $CurlCommand = ''
                    $InfluxStruct.MetricsString = ''
                    $InfluxStruct.MetricsString += "$measurement,host=$name,type=$type,vc=$vc,cluster=$cluster,instance=$instance,unit=$Unit,interval=$interval,numcpu=$numcpu,memorygb=$memorygb value=$value $timestamp"
                    $InfluxStruct.MetricsString += "`n"
                    $CurlCommand = "$($InfluxStruct.CurlPath) -u $($InfluxStruct.InfluxDbUser):$($InfluxStruct.InfluxDbPassword) -i -XPOST `"http://$($InfluxStruct.InfluxDbServer):$($InfluxStruct.InfluxDbPort)/write?db=$($InfluxStruct.InfluxDbName)`" --data-binary `'$($InfluxStruct.MetricsString)`'"
                    Invoke-Expression -Command $CurlCommand 2>&1
                    }
                            
            ## debug console output
            If($ShowStats){
                Write-Output -InputObject "Measurement: $measurement"
                Write-Output -InputObject "Value: $value"
                Write-Output -InputObject "Name: $Name"
                Write-Output -InputObject "Unix Timestamp: $timestamp`n"
                }
           } #end foreach
     } #end reportvm loop

            ## Runtime Summary
                $vCenterEndDTM = (Get-Date)
                $vmCount = ($VMs | Measure-Object).count
                $ElapsedTotal = ($vCenterEndDTM-$vCenterStartDTM).totalseconds

            If($stats -and $ShowStats){
                Write-Output -InputObject "Runtime Summary:"
                Write-Output -InputObject "Elapsed Processing Time: $($ElapsedTotal) seconds"
	            If($vmCount -gt 1) {
	                $TimePerVM = $ElapsedTotal / $vmCount
	                Write-Output -InputObject "Processing Time Per VM: $TimePerVM seconds"
	                }
               }
    }

    If($ReportVMHosts) {

        ## Desired vSphere metric counters for VMHost performance reporting
        $EsxStatTypes = 'cpu.usagemhz.average','mem.usage.average','cpu.usage.average','cpu.ready.summation','disk.usage.average','net.usage.average'

            ## Iterate through ESXi Host list
            foreach ($vmhost in (Get-VMhost | Where-Object {$_.State -eq "Connected"} | Sort-Object -Property Name)) {
    
                ## Gather desired stats
                $stats = Get-Stat -Entity $vmhost -Stat $EsxStatTypes -Realtime -MaxSamples 1
                    foreach ($stat in $stats) {
            
                        ## Create and populate variables for the purpose of writing to InfluxDB Line Protocol
                        $measurement = $stat.MetricId
                        $value = $stat.Value
                        $name = $vmhost.Name
                        $type = 'VMHost'
                        $interval = $stat.IntervalSecs
                        If($stat.MetricID -eq 'cpu.ready.summation') {$ready = [math]::Round($(($stat.Value / ($stat.IntervalSecs * 1000)) * 100), 2); $value = $ready}
                        If($stat.Instance) {$instance = $stat.Instance} Else {$instance -eq $null}
                        if($stat.Unit) {$unit = $stat.Unit} Else {$unit -eq $null}
                        $vc = ($global:DefaultVIServer).Name
                        $cluster = $vmhost.Parent
                        [int64]$timestamp = (([datetime]::UtcNow)-(Get-Date -Date "1/1/1970")).TotalMilliseconds * 1000000 #nanoseconds since Unix epoch

                        ## Write to InfluxDB for this VMHost iteration
                        $InfluxStruct.MetricsString = ''
                        $InfluxStruct.MetricsString += "$measurement,host=$name,type=$type,vc=$vc,cluster=$cluster,instance=$instance,unit=$Unit,interval=$interval value=$value $timestamp"
                        $InfluxStruct.MetricsString += "`n"
                        $CurlCommand = "$($InfluxStruct.CurlPath) -u $($InfluxStruct.InfluxDbUser):$($InfluxStruct.InfluxDbPassword) -i -XPOST `"http://$($InfluxStruct.InfluxDbServer):$($InfluxStruct.InfluxDbPort)/write?db=$($InfluxStruct.InfluxDbName)`" --data-binary `'$($InfluxStruct.MetricsString)`'"
                        Invoke-Expression -Command $CurlCommand 2>&1

                ## debug console output
                If($ShowStats) {
                Write-Output -InputObject "Measurement: $measurement"
                Write-Output -InputObject "Value: $value"
                Write-Output -InputObject "Name: $Name"
                Write-Output -InputObject "Unix Timestamp: $timestamp`n"
                }
            }
        }
    }

    Disconnect-VIServer '*' -Confirm:$false
    Write-Output -InputObject "Script complete.`n"
    If ($Logging -eq 'On') { Stop-Transcript }
}
