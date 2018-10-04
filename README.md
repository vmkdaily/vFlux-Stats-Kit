
#### README for the Fluxor PowerShell Module
___

#### Introduction
Welcome to the `Fluxor` module, part of the `vFlux-Stats-Kit`.

#### Purpose
The Fluxor module gathers performance stats from `VMware vSphere` and writes them
to a local or remote `InfluxDB` time series database. Optionally, output to file
using the `OutputPath` parameter, or return raw vSphere API objects with the
`PassThru` parameter.

#### Official Blog Posts
[Building a Universal vSphere Performance Monitoring Kit with PowerShell Core, InfluxDB, and Grafana on Ubuntu](https://vmkdaily.ghost.io/building-a-universal-vsphere-performance-monitoring-kit-with-powershell-core-influxdb-and-grafana-on-ubuntu/)

[Collecting and Visualizing vSphere Performance Metrics with PowerCLI, InfluxDB and Grafana on CentOS 7](https://vmkdaily.ghost.io/collecting-and-visualizing-vsphere-performance-metrics-with-powercli-influxdb-and-grafana-on-centos-7/)

#### Alternatives
The Fluxor module gathers very basic stats and is intended for you to extend.
However, if you just want a ready-made kit, check out the following items.

vSAN - For vSAN done right, see the free sexigraf appliance (deployed as OVA).

<br>

[http://www.sexigraf.fr/](http://www.sexigraf.fr/)

<br>

Telegraf - You can feed InfluxDB with Telegraf, an open source package from Influxdata. You can use
the amazing custom scripts added by influx data community member @prydin. It does more/better than Fluxor
and uses pure api and proper integers when writing line protocol.

<br>

[https://github.com/influxdata/telegraf/blob/release-1.8/plugins/inputs/vsphere/README.md](https://github.com/influxdata/telegraf/blob/release-1.8/plugins/inputs/vsphere/README.md)

<br>

#### Community dashboards
This one is a community dashboard using the old version of the vFlux-Stats-Kit.
<br>

[https://github.com/jorgedlcruz/vmware-grafana](https://github.com/jorgedlcruz/vmware-grafana)

<br>

This one uses the new Telegraf plugin and some excellent custom charts:
<br>

[https://jorgedelacruz.uk/2018/10/01/looking-for-the-perfect-dashboard-influxdb-telegraf-and-grafana-part-xii-native-telegraf-plugin-for-vsphere/](https://jorgedelacruz.uk/2018/10/01/looking-for-the-perfect-dashboard-influxdb-telegraf-and-grafana-part-xii-native-telegraf-plugin-for-vsphere/)

<br>

#### Issues / Ideas
Please open an issue for any creative ideas or feedback (or to share a dashboard or post!).
Of course, if you find an issue or an OS that we cannot handle yet, please do let us know.
There is no need to follow any official format.

#### Twitter / Blog / Github
Twitter DM is open. Reach us at:
<br>
[https://twitter.com/vmkdaily](https://twitter.com/vmkdaily)
<br>
[https://vmkdaily.ghost.io/](https://vmkdaily.ghost.io/)
<br>
[https://github.com/vmkdaily](https://github.com/vmkdaily)
<br>

#### OS Requirements
All required components can be run on a single client, or across multiple clients
of any operating system. Specifically, we support `Windows`, `Linux` and `macOS`.

#### PowerShell Requirements
Full support for Core Editions of `PowerShell` and also
`PowerShell 3.0` through `PowerShell 5.1`.

#### PowerCLI Requirements
`VMware PowerCLI 6.5.4` or greater (`VMware PowerCLI 10.x` or later preferred)

#### Background
Fluxor started out as individual .ps1 scripts and is now a PowerShell module.
Initially, this was intended to run on Windows only, but we now support everything.

#### Contributions
Over time, the techniques we use have evolved with great thanks to the community members.
For example, we started out using curl.exe on Windows only. Now we use `Invoke-RestMethod`
and `Invoke-WebRequest` (since `v0.4`) and can run on anything (as of `v1.0.0.1`). Advanced
topics such as session handling with the webcmdlets were handled by our users. These and
many more advancements are reflected in the latest release.

#### Platform Limitations for Credential on disk
Though we support all operating systems that `PowerShell` and `PowerCLI` run on,
credentials on disk are not available for Core Editions of PowerShell. So this
means all `Linux` and `macOS`, and any `Windows` that are running Core Editions of PowerShell
cannot save or consume `PSCredential` from disk.

#### Platform Limitations for secure string
Core Editions of PowerShell cannot handle secure string, so we leave the Parameters of
`User` and `Password` as `[string]` compared to secure string. If you will run on Windows with
a `PowerShell 3.0` through `PowerShell 5.1`, you can use use secure string without issue (if so
inclined to edit).

#### PSCredentials at runtime
There is no impact to `PSCredential` handling in memory (i.e. `$creds = Get-Credential`) for Core
Editions of PowerShell. This works as expected with all editions of PowerShell.

#### General Password Security
We support, but do not require, the use of plain text passwords.
Never use an important password in plain text. Always create a
read-only account when in doubt. Also, check with your InfoSec
team to ensure that you find the best option (of the many we offer)
for credential handling with the Fluxor module.

#### SSPI / Passthrough (`Strict` parameter)
To use passthrough authentication leave the `Strict` parameter set to $true (the default).

    $iops = Get-FluxIOPS -Server $vc

<br>

#### Using the plain text value in script
Set `Strict` to `$false` to use the plain text value in the script. If using the plain text option (`-Strict:$false`) remember to use it on the `Get` and `Write` functions of the Fluxor module.

    $stats = Get-FluxCompute -Strict:$false

<br>

___

###### Getting Started with Fluxor

## Step 1. Download the vFlux-Stats-Kit from from Github

    https://github.com/vmkdaily/vFlux-Stats-Kit


## Step 2. Scan the download (Optional)
Navigate to Downloads, and right-click the `.zip` file and select scan

## Step 3. Unblock the zip (Optional)
Right-click the `.zip` file and select Properties, and then `unblock`, if available.

## Step 4. List contents
Get familiar with the layout of the module. We use a very common technique of public and private folders
within the module. Any cmdlets in the private folder are used internally by the module. The cmdlets that
you will interact with are located in the public folder. Nothing is truly `public`, this is just module talk.

## Step 5. Copy the `Fluxor` folder
Locate the folder called `Fluxor`. This contains all of the components of the PowerShell module.
Determine which user will be running the stats collections and copy the Fluxor folder to the
`$HOME` directory (or any other location you prefer for your PowerShell modules).

## Step 6. Optional - Open the scripts in an editor
There are preferences sections in the `Begin` block of each script. Customize as desired and then take a backup
of your Fluxor folder (i.e. send to a zip). There is no need to customize values if you use runtime parameters
such as `Server`, `Credential`, etc.

## Step 7.  Launch PowerShell
We support any flavor, so launch-away (`PowerShell.exe`, `pwsh`, `pwsh-preview`, etc.).

## Step 8. Import the Fluxor Module
Point to the Fluxor folder to import the module with Import-Module.

    PS C:\> Import-Module C:\scripts\Fluxor -Verbose
    VERBOSE: Loading module from path 'C:\scripts\Fluxor\Fluxor.psd1'.
    VERBOSE: Loading module from path 'C:\scripts\Fluxor\Fluxor.psm1'.
    VERBOSE: Importing function 'Get-FluxCompute'.
    VERBOSE: Importing function 'Get-FluxCrontab'.
    VERBOSE: Importing function 'Get-FluxIOPS'.
    VERBOSE: Importing function 'Get-FluxSummary'.
    VERBOSE: Importing function 'Invoke-FluxCLI'.
    VERBOSE: Importing function 'New-FluxCredential'.
    VERBOSE: Importing function 'Write-FluxCompute'.
    VERBOSE: Importing function 'Write-FluxIOPS'.
    VERBOSE: Importing function 'Write-FluxSummary'.
    PS C:\>

<br>

## Step 9. Get Fluxor Commands
Use `Get-Command` (or alias `gcm`) to see the available cmdlets.

    PS C:\> gcm -Module Fluxor

    CommandType     Name                                               Version
    -----------     ----                                               -------
    Function        Get-FluxCompute                                    1.0.0.2
    Function        Get-FluxCrontab                                    1.0.0.2
    Function        Get-FluxIOPS                                       1.0.0.2
    Function        Get-FluxSummary                                    1.0.0.2
    Function        Invoke-FluxCLI                                     1.0.0.2
    Function        New-FluxCredential                                 1.0.0.2
    Function        Write-FluxCompute                                  1.0.0.2
    Function        Write-FluxIOPS                                     1.0.0.2
    Function        Write-FluxSummary                                  1.0.0.2

<br>

## Step 10. Get Help
Use the cmdlet help system to learn about parameters and usage.

    help Get-FluxIOPS
    help Get-FluxIOPS -Examples
    help Get-FluxIOPS -Parameter -CredentialPath

<br>

___

## Get Some Stats
Let's start simple and assume you have PowerCLI up and running and you are already
connected to vCenter.

    $stats = Get-FluxCompute

<br>

## View the Stats
By default, we return a PowerShell object. So we can dip into the array with `$stats[0]`, etc.
Here we will just select the first object.

    $stats | Select-Object -First 1

<br>

## Write to InfluxDB
For this step, we assume `InfluxDB` is on `localhost` and you followed our examples thus far.
This means you have at least one or more InfluxDB databases created (i.e. `compute`, `iops`, `summary`).

    Write-FluxCompute -InputObject $stats

<br>

> Tip: The technique shown (using a variable) is for high performance. If you want to pipe
you can also `Get-FluxCompute | Write-FluxCompute`.

<br>

## About InfluxDB Measurements
With `InfluxDB`, each data point we send has a `measurement` name. An example would be something
like `cpu.usage.average`. We can check our success by reviewing the database for these new
measurements. Next, we show a couple of ways to do that.

## Using influx, the native InfluxDB tool
We can use the native InfluxDB commandline tool known as `influx` to interact with the local
InfluxDB database. Just type `influx` from your shell.

## Using Invoke-FluxCLI (part of the Fluxor module)
We placed a wrapper around the native `influx` command just for convenience and optional use.
If you like doing stuff from `PowerShell` and keeping it simple, then this is for you.

First, let's just show the version and exit:

    PS /home/mike> Invoke-FluxCLI -Version
    PS /home/mike> InfluxDB shell version: 1.6.3

<br>

> If you are still with me, great! Now let's look at some InfluxDB `Measurements`!

<br>

## Reviewing measurements
We are still using `Invoke-FluxCLI`, but now we go into more advanced usage
with the `ScriptText` and `Database` parameters. Here we ask InfluxDB to report
back with measurements it has. This means we were successful in performing at
least one write.

    PS /home/fluxor> Invoke-FluxCLI -ScriptText 'SHOW MEASUREMENTS' -Database 'compute'
    name: measurements
    name
    ----
    cpu.ready.summation
    cpu.usage.average
    cpu.usagemhz.average
    mem.usage.average
    net.usage.average


<br>

Great, we are getting all of the measurements that come with `compute` metrics.
Now let's move on to IOPS.

## Getting and Writing IOPS results
Every cmdlet works the same and once you get the hang of one, the others should be easy.
We already worked with `Get-FluxCompute`. Next we use `Get-FluxIOPS` to collect disk
performance results.

Thus far, we assumed you were already logged into vCenter Server. Now let's use a simple
`PSCredential` login (one of many techniques available with `Fluxor`).

    $vc = 'vcsa01.lab.local'
    $credsVC = Get-Credential administrator@vsphere.local
    $iops = Get-FluxIOPS -Server $vc -Credential $credsVC
    Write-FluxIOPS -InputObject $iops

<br>

Next, we can check for results in `Grafana` by creating a dashboard, or
using the `Invoke-FluxCLI` again. Let's use the CLI!

    PS /home/mike> Invoke-FluxCLI -Database iops -ScriptText 'SHOW MEASUREMENTS'
    PS /home/mike> name: measurements
    name
    ----
    disk.maxtotallatency.latest
    disk.numberread.summation
    disk.numberwrite.summation

<br>

## Handling summary results
New in the latest module is a `summary` feature. Formerly, we had only `compute` and `iops`.
Now we add a new database called `summary` to take in basic information such as overallstatus
(i.e. `green`,`red`, etc.) and  things you would expect such as `numcpu` and `memorygb`. We can easily
add a ton of stuff here (think anything you can dot into from `Get-VM`). For now we keep it simple.

## Adding the summary database
In this example, we have everything except the `summary` database:

    PS /home/mike> Invoke-FluxCLI -ScriptText 'SHOW DATABASES'
    name: databases
    name
    ----
    _internal
    iops
    compute

<br>

## Create the summary database
Let's add the summary database to InfluxDB. We will again use `Invoke-FluxCLI`, which is just a wrapper for the `influx` binary.
The nature of `influx` commands is to respond only if something failed. In the below, no response is good.

    PS /home/mike> Invoke-FluxCLI -ScriptText 'CREATE DATABASE summary'
    PS /home/mike>

> Influx commands only return a response on failure.

<br>

## Show databases
Here we use the native `SHOW DATABASES` command via the `ScriptText` parameter of `Invoke-FluxCLI`.

    PS /home/mike> Invoke-FluxCLI -ScriptText 'SHOW DATABASES'
    PS /home/mike> name: databases
    name
    ----
    _internal
    iops
    compute
    summary

<br>

## Show measurements
Let's perform a `SHOW MEASUREMENTS` on the `summary` database. If a database has not been populated, then we see no results when we query for measurements.

    PS /home/mike> Invoke-FluxCLI -Database summary -ScriptText 'SHOW MEASUREMENTS'
    PS /home/mike>

<br>

## Write summary results for VMs
Now let's populate the `summary` database with some stats. For this we will use the `Get-FluxSummary` to collect summary data points, and then we use `Write-FluxSummary` to write the results to InfluxDB. The default value for the `ReportType` switch is `VM` though we populate anyway here for visualization (soon we will do `VMHost` too).


    Get-FluxSummary -ReportType 'VM' | Write-FluxSummary

> Example assumes we are connected to vCenter already and InfluxDB is localhost. Use additional parameters as needed.

<br>

## Write summary results for VMHosts
Here we will use the ReportType of `VMHost` when collecting summary data points.

    Get-FluxSummary -Server $vc -ReportType VMHost | Write-FluxSummary

<br>

## Confirm measurements
Once data points have been written, you should see the following two measurements for summary:

    PS /home/mike> Invoke-FluxCLI -Database summary -ScriptText 'SHOW MEASUREMENTS'
    name: measurements
    name
    ----
    flux.summary.vm
    flux.summary.vmhost

<br>

## Output to File (optional)
We support output of the results to text file when using the `OutputPath` parameter.
Writing to text files is not the cmdlet default, but we make it available. Users could
take these files and then control the push to InfluxDB themselves. The files are crafted
in line protocol, which means they are really just for InfluxDB.

## About Object Output (default)
We always output into pure InfluxDB-style line protocol (unless using the `PassThru` switch).
The `Fluxor` cmdlets that collect data points (i.e. `Get-FluxCompute`, `Get-FluxIOPS` and `Get-FluxSummary`)
always return a PowerShell object (a simple array of line protocol, including the required line breaks).
If you want pure `VMware vSphere` stat objects instead, use `PassThru`.

## About PassThru mode
Use `PassThru` mode to access the raw `Get-Stat` and `Get-VsanStat` and then exit. `Fluxor` will do nothing further with those, except return the array of stat objects, if any. This can be convenient for comparison against what you see in `Grafana` for example.

## Get stats in PassThru
Here, we are already connected to vCenter and just grab some stats in `PassThru` mode.

    $stats = Get-FluxCompute -PassThru

<br>

## Look for a particular VM results
At first glance you might not realize the stat has the virtual machine information too. You can dig into the object as you would expect.

    $stats | ?{$_.Entity -match '^ExactlyThisVmName001'}
    $stats | ?{$_.Entity -match '^nameStartsLikeThis'}
    $stats | ?{$_.Entity -like "*kindalikethis*"

<br>

## Get stat result of a certain type
Let's keep looking at this one VM to keep it simple. Let's also dig into just one metric (or `measurement` as we call it for `InfluxDB`).

    Get-FluxCompute -PassThru | Where-Object {$_.Entity -match '^TESTVM001' -and $_.MetricID -eq 'cpu.usage.average'}

<br>

## Looping in PassThru mode
One last example with PassThru. Remember, this example returns raw vSphere stats, not the default output we normally give you (line protocol).

Here we issue `Get-FluxCompute -PassThru` and limit the results to only `cpu.usage.average`.

    $vm = 'myvm001'
    1..10 | ForEach-Object {Get-Date -Format o; Get-FluxCompute -PassThru | Where-Object { $_.Entity -match $vm -and $_.MetricID -eq 'cpu.usage.average'}; Start-Sleep 20;""}

## Examples using all functions (with verbose output)
Let's summarize by showing all of the main stats cmdlets being used in verbose mode.

    ##########################
    ## Virtual Machine Stats
    ##########################

    PS C:\> $stats = Get-FluxCompute -Verbose
    VERBOSE: Starting Get-FluxCompute at 2018-09-29T20:07:15.0508946-05:00
    VERBOSE: Using connection to vcva01.lab.local
    VERBOSE: Beginning stat collection on vcva01.lab.local
    VERBOSE: 9/29/2018 8:07:15 PM Get-VM Started execution
    VERBOSE: 9/29/2018 8:07:15 PM Get-VM Finished execution
    VERBOSE: 9/29/2018 8:07:15 PM Get-Stat Started execution
    VERBOSE: 9/29/2018 8:07:29 PM Get-Stat Finished execution
    VERBOSE: Running in object mode; Data points collected successfully!
    VERBOSE: Elapsed Processing Time: 29.5228279 seconds
    VERBOSE: Processing Time Per VM: 0.192959659477124 seconds
    VERBOSE: Ending Get-FluxCompute at 2018-09-29T20:07:44.6205228-05:00
    PS C:\>
    PS C:\> $stats[0]
    cpu.usage.average,host=myvm002,interval=20,type=VM,unit=%,vc=vcva01.lab.local value=4.25 1538269649940828928

    PS C:\> $iops = Get-FluxIOPS -Verbose
    VERBOSE: Starting Get-FluxIOPS at 2018-09-29T20:14:20.0161095-05:00
    VERBOSE: Using connection to vcva01.lab.local
    VERBOSE: Beginning stat collection on vcva01.lab.local
    VERBOSE: 9/29/2018 8:14:20 PM Get-Datastore Started execution
    VERBOSE: 9/29/2018 8:14:20 PM Get-Datastore Finished execution
    VERBOSE: 9/29/2018 8:14:20 PM Get-VM Started execution
    VERBOSE: 9/29/2018 8:14:20 PM Get-VM Finished execution
    VERBOSE: 9/29/2018 8:14:21 PM Get-VM Started execution
    VERBOSE: 9/29/2018 8:14:21 PM Get-VM Finished execution
    VERBOSE:
    VERBOSE: //vcva01.lab.local Overview
    VERBOSE: VMFS Datastores: 50
    VERBOSE: NFS Datastores: 2
    VERBOSE: vSAN Datastore: False
    VERBOSE: Block VMs: 153
    VERBOSE: NFS VMs: 0
    VERBOSE: vSAN VMs: 0
    VERBOSE: 9/29/2018 8:14:21 PM Get-Stat Started execution
    VERBOSE: 9/29/2018 8:14:32 PM Get-Stat Finished execution
    VERBOSE: Running in object mode; Data points collected successfully!
    VERBOSE: Ending Get-FluxIOPS at 2018-09-29T20:14:34.5576511-05:00
    PS C:\>
    PS C:\> $iops[0]
    disk.numberwrite.summation,disktype=Block,host=myvm002,instance=naa.6019cb5180a3b07b3eb5b5f4f3045017,interval=20,type=VM,unit=number,vc=vcva01.lab.local value=3 1538270072857240320

    PS C:\> $summary = Get-FluxSummary -Verbose
    VERBOSE: Starting Get-FluxSummary at 2018-09-29T20:18:39.5359640-05:00
    VERBOSE: Using connection to vcva01.lab.local
    VERBOSE: Beginning summary collection on vcva01.lab.local
    VERBOSE: 9/29/2018 8:18:39 PM Get-VM Started execution
    VERBOSE: 9/29/2018 8:18:39 PM Get-VM Finished execution
    VERBOSE: Running in object mode; Data points collected successfully!
    VERBOSE: Elapsed Processing Time: 3.9156251 seconds
    VERBOSE: Processing Time Per VM: 0.0255923209150327 seconds
    VERBOSE: Ending Get-FluxSummary at 2018-09-29T20:18:43.4515891-05:00
    PS C:\>
    PS C:\> $summary[0]
    flux.summary.vm,host=myvm002,memorygb=2,numcpu=2,type=VM,vc=vcva01.lab.local value="green" 1538270320191168256


    ##########################
    ## VMHost Stats
    ##########################

    PS C:\> $EsxStats = Get-FluxCompute -ReportType VMHost -Verbose
    VERBOSE: Starting Get-FluxCompute at 2018-09-29T20:23:06.9010263-05:00
    VERBOSE: Using connection to vcva01.lab.local
    VERBOSE: Beginning stat collection on vcva01.lab.local
    VERBOSE: 9/29/2018 8:23:06 PM Get-VMHost Started execution
    VERBOSE: 9/29/2018 8:23:07 PM Get-VMHost Finished execution
    VERBOSE: 9/29/2018 8:23:07 PM Get-Stat Started execution
    VERBOSE: 9/29/2018 8:23:15 PM Get-Stat Finished execution
    VERBOSE: Running in object mode; Data points collected successfully!
    VERBOSE: Ending Get-FluxCompute at 2018-09-29T20:23:16.6988892-05:00
    PS C:\>
    PS C:\> $EsxStats[0]
    cpu.usage.average,host=esx01.lab.local,instance=20,interval=20,type=VMHost,unit=%,vc=vcva01.lab.local value=21.32 1538270595497681664


    PS C:\> $EsxSummary = Get-FluxSummary -ReportType VMHost -Verbose
    VERBOSE: Starting Get-FluxSummary at 2018-09-29T20:35:33.2989579-05:00
    VERBOSE: Using connection to vcva01.lab.local
    VERBOSE: Beginning summary collection on vcva01.lab.local
    VERBOSE: 9/29/2018 8:35:33 PM Get-VMHost Started execution
    VERBOSE: 9/29/2018 8:35:34 PM Get-VMHost Finished execution
    VERBOSE: Running in object mode; Data points collected successfully!
    VERBOSE: Ending Get-FluxSummary at 2018-09-29T20:35:39.8041996-05:00
    PS C:\>
    PS C:\> $EsxSummary | Select-Object -First 3
    flux.summary.vmhost,host=esx01.lab.local,memorygb=256,numcpu=16,type=VMHost,vc=vcva01.lab.local value="green" 1538271335186569984

    flux.summary.vmhost,host=esx02.lab.local,memorygb=256,numcpu=16,type=VMHost,vc=vcva01.lab.local value="green" 1538271335467371776

    flux.summary.vmhost,host=esx03.lab.local,memorygb=256,numcpu=16,type=VMHost,vc=vcva01.lab.local value="green" 1538271335794974208
    
    ###################
    ## Output to File
    ###################
    Finally, we show the non-standard technique of writing to file. Then we show some of the results.

    PS C:\> Get-FluxCompute -OutputPath $HOME -Verbose
    VERBOSE: Starting Get-FluxCompute at 2018-09-29T21:09:17.3520291-05:00
    VERBOSE: Using connection to vcva01.lab.local
    VERBOSE: Beginning stat collection on vcva01.lab.local
    VERBOSE: Creating output directory for stat collection at C:\Users\mike\fluxstat
    VERBOSE: 9/29/2018 9:09:17 PM Get-VM Started execution
    VERBOSE: 9/29/2018 9:09:17 PM Get-VM Finished execution
    VERBOSE: 9/29/2018 9:09:17 PM Get-Stat Started execution
    VERBOSE: 9/29/2018 9:09:33 PM Get-Stat Finished execution
    VERBOSE: Write succeeded: C:\Users\mike\fluxstat\fluxstat-cca0fdb5-f1fc-437a-ac50-036173cddfea.txt
    VERBOSE: Elapsed Processing Time: 32.4988554 seconds
    VERBOSE: Processing Time Per VM: 0.212410819607843 seconds
    VERBOSE: Ending Get-FluxCompute at 2018-09-29T21:09:49.8508845-05:00
    C:\Users\mike\fluxstat\fluxstat-cca0fdb5-f1fc-437a-ac50-036173cddfea.txt
    PS C:\>
    PS C:\> cat $home\fluxstat\fluxstat-cca0fdb5-f1fc-437a-ac50-036173cddfea.txt | more
    cpu.usage.average,host=myvm002,interval=20,type=VM,unit=%,vc=vcva01.lab.local value=4.12 1538273373796381696

    cpu.ready.summation,host=myvm002,instance=0,interval=20,type=VM,unit=millisecond,vc=vcva01.lab.local value=0.03 1538273373889982208

    net.usage.average,host=myvm002,instance=vmnic3,interval=20,type=VM,unit=KBps,vc=vcva01.lab.local value=1764 1538273376011595776

<br>

-end-
