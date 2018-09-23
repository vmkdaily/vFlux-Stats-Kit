
#### README for the Fluxor PowerShell Module
___

#### Introduction
Welcome to the `Fluxor` module, part of the `vFlux-Stats-Kit`.

#### Purpose
The Fluxor module gathers performance stats from `VMware vSphere` and writes them
to a local or remote `InfluxDB` time series database. Optionally, output to file
using the `OutputPath` parameter or return raw vSphere API objects with the
`PassThru` parameter.

#### Supporting Blog Posts
[Building a Universal vSphere Performance Monitoring Kit with PowerShell Core, InfluxDB, and Grafana on Ubuntu](https://vmkdaily.ghost.io/building-a-universal-vsphere-performance-monitoring-kit-with-powershell-core-influxdb-and-grafana-on-ubuntu/)

[Collecting and Visualizing vSphere Performance Metrics with PowerCLI, InfluxDB and Grafana on CentOS 7](https://vmkdaily.ghost.io/collecting-and-visualizing-vsphere-performance-metrics-with-powercli-influxdb-and-grafana-on-centos-7/)

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

___

###### Getting Started with Fluxor

## Step 1. Download the vFlux-Stats-Kit from from Github.

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

    Import-Module $HOME/Fluxor -Verbose

<br>

## Step 9. Get Fluxor Commands
Use `Get-Command` (or alias `gcm`) to see the available cmdlets.

    gcm -Module Fluxor

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

## Object Output
By default, the `Fluxor` cmdlets that collect data points (i.e. `Get-FluxCompute`, `Get-FluxIOPS` and `Get-FluxSummary`) always return a PowerShell object (a simple array). If you want vSphere stat objects instead, use `PassThru`.

-end-
