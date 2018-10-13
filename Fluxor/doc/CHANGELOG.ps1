
<#

  ## Changelog for Fluxor Module

  We are located at:
  https://github.com/vmkdaily/vFlux-Stats-Kit

  ## Version History

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

    version 1.0.0.1 - 21Sept2018
    -  Converted individual scripts into a module called Fluxor
    -  Added support for Core Editions of PowerShell
    -  Support continues for PowerShell versions 3.0 to 5.1 (this will not change)
    -  Started using $HOME instead of $env:USERPROFILE since this is more universal
    -  Added support for vSAN virtual machines
    -  Get-Stat is performed in one shot (compared to once for each virtual machine previously)
    -  Removed support for PowerCLI versions less than 6.5.4 (unless you do your own loading)
    -  Removed PowerCLI Loading since everyone is on modules now
    -  Added Credential handling via a Credential parameter (formerly was passthrough SSPI)
    -  Added the ability to save PSCredential to file with teh Save-FluxCredential cmdlet. This feature not supported on Core Editions of PowerShell.
    -  Added the ability to read in a saved PSCredential from disk for runtime use. This feature not supported on Core Editions of PowerShell.
    -  Added a new measurement called 'summary' that gathers basic health information (green, red,yellow) and amount of cpu, memory.
    -  Added Get and Write cmdlets for each major area (Compute, IOPS and Summary).
    -  Added a CLI facility to interact with influxcli on the local system by running the cmdlet Invoke-FluxCLI (try Invoke-FluxCLI -Version).
    -  Added a cmdlet called Get-FluxCrontab to show cron jobs (related to our stats) that are currently running
    -  Optimized field layout for faster line protocol writes
    -  Added the ability to write output to line protocol in a text file by using the OutputPath parameter. See help for more detail as this is not the default use case.
    -  Added a Cardinality parameter for advanced high performance cases. Not recommeded for most. 
    -  Added a PassThru switch that allows users to get the raw vSphere API stat instead of being formatted into InfluxDB line protocol.

  version 1.0.0.2 - 29Sept2018
    -  Optimized virtual machine enumeration by using the Datastore parameter of Get-VM instead of piping from Get-Datastore.
    -  Changed to using the Where method (compared to Where-Object), unless on version 3 of PowerShell.
    -  Updated help and examples

  version 1.0.0.3 - 04Oct2018
    -  Changed the Strict parameter to a boolean (previously Switch) and made it $true by default. This allows SSPI (passthrough authentication) to work as expected when a login credential is not provided. To use the plain text credential contained in the script set Strict to $false.
    -  Added MaxJitter parameter to the Get functions. MaxJitter is the maximum time in seconds to offset the start of stat collection. Set to 0 for no jitter or keep the default which jitters for a random time up to MaxJitter.
    -  Added handling for users of multiple mode of PowerCLI to ensure only $global:DefaultVIServer results are returned (issue #11 "2 VMs in one post request")
  version 1.0.0.4 - 04Oct2018
    -  Added better handling for existing vCenter connections and multiple mode users.
    -  Updated help and examples
  version 1.0.0.5 - 06Oct2018
    -  Removed the Cardinality parameter which was not used by default.
    -  Added the ability to supress and resume collection with the Supress and Resume parameters. The Fluxor Get-* functions will honor a supress request by creating a lock file; Once the lockfile reaches the default age of 20 minutes (MaxSupressionWindow) we remove it and continue collecting. See the cmdlet help for more detail on these new parameters.
  version 1.0.0.6 - 08Oct2018
    -  Added parameter sets to handle Supress, and Resume functionality on the Get functions (Get-FluxCompute, Get-FluxIOPS, and Get-fluxSummary).
  version 1.0.0.7 - 12Oct2018 (latest!)
    -  Resolved Issue #12 "Unable to Parse" (thanks @linuxmonkey!).
    -  Added support for consumption of PSCredential from the VMware VICredentialStore for vCenter Server connections. Not supported on Core Editions of PowerShell.

#>
