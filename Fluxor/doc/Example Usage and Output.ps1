<#

## Already connected to vCenter

    PS /home/mike> $stats = Get-FluxCompute -Verbose
    VERBOSE: Using connection to vcsa01.lab.local
    VERBOSE: Beginning stat collection on vcsa01.lab.local
    VERBOSE: 9/3/18 3:23:39 PM      Get-VM  Started execution
    VERBOSE: 9/3/18 3:23:41 PM      Get-VM  Finished execution
    VERBOSE: 9/3/18 3:23:41 PM      Get-Stat        Started execution
    VERBOSE: 9/3/18 3:23:46 PM      Get-Stat        Finished execution
    VERBOSE: Running in object mode; Data points collected successfully!
    VERBOSE: Elapsed Processing Time: 7.6352841 seconds
    VERBOSE: Processing Time Per VM: 1.908821025 seconds
    VERBOSE: Ending Get-FluxCompute at 2018-09-03T15:23:47.2320913-05:00
    PS /home/mike>
    PS /home/mike> Write-FluxStat -InputObject $stats -Verbose
    VERBOSE: POST http://localhost:8086/write?db=compute with 7961-byte payload
    VERBOSE: received -byte response of content type application/json
    VERBOSE: Content encoding: iso-8859-1
    VERBOSE: Ending Write-FluxStat at 2018-09-03T15:24:02.5975737-05:00
    PS /home/mike>

## Use a plain text password
    $vc = 'vcsa01.lab.local'
    $stats  = Get-FluxCompute -Server $vc -User 'flux-read-only@vsphere.local' -Password 'VMware123!!'

## Use a PSCredential
    $vc = 'vcsa01.lab.local'
    $credsVC = Get-Credential administrator@vsphere.local
    $stats  = Get-FluxCompute -Server $vc -Credential $credsVC

## Use the official influxdata binary on your system that comes with InfluxDB, but do it from PowerShell without leaving Fluxor with Invoke-FluxCLI.

  PS /home/mike> Invoke-FluxCLI -Version
  PS /home/mike> InfluxDB shell version: 1.6.3


## In this example, we have everything except the 'summary' database, so we add it.
You can also show databases and interact as expected.

    PS /home/mike> Invoke-FluxCLI -ScriptText 'SHOW DATABASES'
    name: databases
    name
    ----
    _internal
    iops
    compute
    skystat

    PS /home/mike> Invoke-FluxCLI -ScriptText 'CREATE DATABASE summary'
    PS /home/mike>
    
    PS /home/mike> Invoke-FluxCLI -ScriptText 'SHOW DATABASES'
    PS /home/mike> name: databases
    name
    ----
    _internal
    iops
    compute
    skystat
    summary

## InfluxDB 'measurements'
When writing to InfluxDB, we always send a measurement name such as 'cpu.usage.average' or sometimes we use a derived value
such as 'flux.summary.vm'. Below we show how to use the Invoke-FluxCLI command to review the available measurements in an
InfluxDB database.

  PS /home/mike> Invoke-FluxCLI -Database iops -ScriptText 'SHOW MEASUREMENTS'
  PS /home/mike> name: measurements
  name
  ----
  disk.maxtotallatency.latest
  disk.numberread.summation
  disk.numberwrite.summation

## No measurements
If a database has not been populated then we will see no results when we query for measurements.

  PS /home/mike> Invoke-FluxCLI -Database summary -ScriptText 'SHOW MEASUREMENTS'
  PS /home/mike>

Once data points have been written you should see the following two measurements for summary:

  PS /home/mike> Invoke-FluxCLI -Database summary -ScriptText 'SHOW MEASUREMENTS'
  name: measurements
  name
  ----
  flux.summary.vm
  flux.summary.vmhost


#>
