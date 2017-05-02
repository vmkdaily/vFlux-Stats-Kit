#requires -Version 3

<#
    .DESCRIPTION
      Uses PowerShell to download the official Windows binaries
      for InfluxDB, Grafana, and/or NSSM to your local machine.
      
      This script provides an easy download of all binaries needed to
      run the vFlux Stats Kit.  However, feel free to use for any purpose
      requiring these official binaries.

    .NOTES
      Filename:	      Get-vFluxBits.ps1
      Version:	      0.3
      Author:         Mike Nisk
      Organization:	  vmkdaily
      Updated:	      22April2017
    
    .PARAMETER DownloadType
      String. What to download. Choose from InfluxDB, Grafana, NSSM, or All.
      The default is None. Tab complete through options.

    .EXAMPLE
    #Example #0 - Download all
     C:\> .\Get-vFluxBits.ps1 -DownloadType All
    Welcome to Get-vFluxBits.ps1
    Main download folder: C:\Users\vmadmin\AppData\Local\Temp
    ..Starting download of InfluxDB for Windows
    Done with InfluxDB download!
    Filename is C:\Users\vmadmin\AppData\Local\Temp\influxdb-1.2.2_windows_amd64.zip
    ..Starting download of Grafana for Windows
    Done with Grafana download!
    Filename is C:\Users\vmadmin\AppData\Local\Temp\grafana-4.2.0.windows-x64.zip
    ..Starting download of NSSM for Windows
    Done with NSSM download!
    Filename is C:\Users\vmadmin\AppData\Local\Temp\nssm-2.24.zip
     C:\>

    .EXAMPLE
    #Example #1 - Download only InfluxDB
    C:\> .\Get-vFluxBits.ps1 -DownloadType InfluxDB -Path c:\temp -Verbose
    VERBOSE: Verbose mode is on
    VERBOSE: Welcome to Get-vFluxBits.ps1
    VERBOSE: Main download folder: c:\temp
    VERBOSE: ..Starting download of InfluxDB for Windows
    VERBOSE: GET https://dl.influxdata.com/influxdb/releases/influxdb-1.2.2_windows_amd64.zip with 0-byte payload
    VERBOSE: received 16946200-byte response of content type application/zip
    VERBOSE: Done with InfluxDB download!
    VERBOSE: Filename is c:\temp\influxdb-1.2.2_windows_amd64.zip
    C:\>
    #Example showing how to download InfluxDB to a custom 'Path' of c:\temp

    .EXAMPLE
    #Example #2 - Get the development build of NSSM.  You have to confirm to accept.
    C:\> .\Get-vFluxBits.ps1 -DownloadType NSSM -UseDevBuildFor NSSM -Verbose
    VERBOSE: Verbose mode is on

    Confirm
    Are you sure you want to perform this action?
    Performing the operation "Download one or more development builds" on target "VFLUX202".
    [Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "Y"):
    VERBOSE: Welcome to Get-vFluxBits.ps1
    VERBOSE: Main download folder: C:\Users\vmadmin\AppData\Local\Temp
    VERBOSE: Development build folder: C:\Users\vmadmin\AppData\Local\Temp.
    VERBOSE: ..Starting download of NSSM for Windows
    VERBOSE: GET http://nssm.cc/ci/nssm-2.24-94-g9c88bc1.zip with 0-byte payload
    VERBOSE: received 423358-byte response of content type application/zip
    VERBOSE: Done with NSSM download!
    VERBOSE: Filename is C:\Users\vmadmin\AppData\Local\Temp\nssm-2.24-94-g9c88bc1.zip
    C:\>
    #This example downloads and saves the dev build of NSSM to the default directory.

    .EXAMPLE
    #Example #3 - You can download a mix of production and development builds.
    #Because this example includes development bits, you must confirm.
    C:\> .\Get-vFluxBits.ps1 -DownloadType All -UseDevBuildFor NSSM -PathDev c:\waffles

    Confirm
    Are you sure you want to perform this action?
    Performing the operation "Download one or more development builds" on target "VFLUX202".
    [Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "Y"): yes
    Welcome to Get-vFluxBits.ps1
    Main download folder: C:\Users\vmadmin\AppData\Local\Temp
    Created folder for Dev Builds C:\waffles
    ..Starting download of InfluxDB for Windows
    Done with InfluxDB download!
    Filename is C:\Users\vmadmin\AppData\Local\Temp\influxdb-1.2.2_windows_amd64.zip
    ..Starting download of Grafana for Windows
    Done with Grafana download!
    Filename is C:\Users\vmadmin\AppData\Local\Temp\grafana-4.2.0.windows-x64.zip
    ..Starting download of NSSM for Windows
    Done with NSSM download!
    Filename is c:\waffles\nssm-2.24-94-g9c88bc1.zip
    C:\>
    #In this example we download the production releases of InfluxDB and Grafana,
    #and the NSSM development build.  We specify a custom directory for the development
    #download, and use the default direcory for the main production releases.
    #If we don't specify paths, all binaries go to the default of $Env:Temp.
    #If a path doesn't exist, we create it (if allowed).

    ABOUT SCRIPT SIGNING

      Ths script has a digital signature to protect it in transit.
      If you modify the script, simply remove the block of text at the very bottom.
      Optionally, you can re-sign the script if desired (not required).

    CONTRIBUTE

      Things you can do for fun or to help out:

        //TODO - Add a sibling script (i.e. Set-vFluxBits) to perform one or more of: (1)unzip
        and copy binaries to target directories; (2)creation of config files;(3)scheduled tasks.

        //TODO - One-shot deploy of vSphere VM to specification (2 vCPU, 8GB RAM), and deploy all bits,
        then finally start collecting stats from an existing vCenter.
        
        //TODO -  Add support for PSRemoting and perhaps linux binaries instead of Windows

        //TODO - Add checksum validation

#>

[CmdletBinding(RemotingCapability='None',
              SupportsShouldProcess=$true,
              HelpUri='https://github.com/vmkdaily')]
Param(

    #String. What to download.  Choices are InfluxDB, Grafana, NSSM, All, or None. Tab complete through options.
    [ValidateSet('InfluxDB','Grafana','NSSM','All','None')]
    [string]$DownloadType = 'None',

    #Use the development build for one or more packages.
    [ValidateSet('InfluxDB','Grafana','NSSM','All','None')]
    [string]$UseDevBuildFor = 'None',

    #String.  Path to save the downloads.  Defaults to $Env:Temp
    #[ValidateScript({Test-Path -Path $_ -PathType Container})] #uncomment for strict validation
    [Alias('DownloadPath','OutPath')]
    [string]$Path,
    
    #String.  Optionally, enter a path to save development builds (if any). Defaults to $Env:Temp
    #[ValidateScript({Test-Path -Path $_ -PathType Container})] #uncomment for strict validation
    [Alias('DownloadPathDev','OutPathDev')]
    [string]$PathDev

)

Begin {

    ## UPDATE YOUR OPTIONS HERE
    $UserPref = New-Object -TypeName PSObject -ArgumentList @{
        OutPath               =  $Env:Temp   #default is ok.  Optionally, set to something like 'c:\mainbuilds' or use the Path parameter.
        InfluxDownloadPath    =  'https://dl.influxdata.com/influxdb/releases/influxdb-1.2.2_windows_amd64.zip'
        GrafanaDownloadPath   =  'https://s3-us-west-2.amazonaws.com/grafana-releases/release/grafana-4.2.0.windows-x64.zip'
        NssmDownloadPath      =  'https://nssm.cc/release/nssm-2.24.zip'
    }
    
    ## OPTIONAL - Add Dev Build Locations
    $DevBuild = New-Object -TypeName PSObject -ArgumentList @{
        OutPath               =  $Env:Temp   #default is ok.  Optionally, set to something like 'c:\testbuilds' or use the PathDev parameter.
        InfluxDevPath         =  ''
        GrafanaDevPath        =  ''
        NssmDevPath           =  'http://nssm.cc/ci/nssm-2.24-94-g9c88bc1.zip'
    }
    
    ## create missing folder if needed.
    ## Only works if validate script is not enforced
    ## on the Path and PathDev parameters (default).
    [bool]$AllowFolderCreation = $true
    
    #######################################
    ## No need to edit beyond this point
    #######################################
    
    #successful downloads
    $downloadOK = @()
    
    ## Here, the script gets the local computername automatically.
    ## If we support PSRemoting in the future, we can add a ComputerName parameter instead
    [string]$Computer = ($env:COMPUTERNAME)
    
    ## download path default
    If($PSCmdlet.MyInvocation.BoundParameters['Path']) {
      [string]$Script:DownloadPathLocal = ($PSCmdlet.MyInvocation.BoundParameters['Path'])
    }
    Else {
      [string]$Script:DownloadPathLocal = ('{0}' -f $UserPref.OutPath)
    }
    
    ## download path dev
    ## For development downloads (if any) the order of preference is:
    ## PathDev parameter, then Path parameter, then script default.
    If($PSCmdlet.MyInvocation.BoundParameters['UseDevBuildFor']) {
    
        #pathdev
        If($PSCmdlet.MyInvocation.BoundParameters['PathDev']) {
          [string]$Script:DownloadPathDev = $PSCmdlet.MyInvocation.BoundParameters['PathDev']
        }
        
        #path
        Elseif($PSCmdlet.MyInvocation.BoundParameters['Path']) {
          [string]$Script:DownloadPathDev = $PSCmdlet.MyInvocation.BoundParameters['Path']
        }
        
        #default
        Else {
          [string]$Script:DownloadPathDev = ('{0}' -f $DevBuild.OutPath)
        }
    }
    
    ## check verbose settings
    If(-Not($PSCmdlet.MyInvocation.BoundParameters['Verbose'])) {
      $Script:VerboseMode = 'off'
    }
    Else {
      $Script:VerboseMode = 'on'
      Write-Verbose -Message 'Verbose mode is on'
    }

    Function Write-Msg {

    <#

        .DESCRIPTION
          Writes messages using Write-Output or Write-Verbose depending on
          the runtime value for the Verbose parameter of the parent script.

        .NOTES
          Script:         Write-Msg.ps1
          Type:           Function
          Author:         Mike Nisk
          Organization:   vmkdaily
          Updated:        23April2017

        .EXAMPLE
        Write-Msg -InputMessage "Hello World"

    #>

        [CmdletBinding(RemotingCapability='None')]
        Param
        (
          #String. The message to input or otherwise pass along the pipeline
          [AllowEmptyString()]
          [Alias('InputObject')]
          [Alias('Message')]
          [PSObject]$InputMessage
        )

        Begin {
      
          ## check VerboseMode
          If(-Not($Script:VerboseMode)) {
            Throw 'Cannot determine verbose mode'
          } #End If
        } #End Begin

        Process {

            #handle verbose mode
            switch($Script:VerboseMode){
        
                'off' {
                    ## verbose mode is off
                    $Msg = Write-Output -InputObject ('{0}' -f $InputMessage)  
                } #End off
          
                'on' {
                    ## verbose mode is on
                    $Msg = Write-Verbose -Message ('{0}' -f $InputMessage)
                } #End on
            } #End Switch
            return $Msg
        }#End Process
    } #End Function
    
    Function Get-InfluxDB {
      [CmdletBinding()]
      Param()
      
      Process {
        Try {
            Write-Msg -InputMessage '..Starting download of InfluxDB for Windows'
            Invoke-WebRequest -Uri $InfluxRemoteDownloadPath -OutFile $OutPathInfluxDB -ErrorAction Stop
            Write-Msg -InputMessage 'Done with InfluxDB download!'
        }
        Catch {
            Write-Warning -Message ('Problem downloading InfluxDB to {0}' -f ($DownloadPathLocal))
            Write-Warning -Message ('{0}' -f $_.Exception.Message)
        } #End Catch
      } #End Process
       
      End {
        If(Test-Path -Path $OutPathInfluxDB -ErrorAction SilentlyContinue){
          Write-Msg -InputMessage ('Filename is {0}' -f ($OutPathInfluxDB))
          $downloadOK += $OutPathInfluxDB
        } #End If
      } #End End
    } #End function

    #region official bits
    ## remote download path for official releases
    [string]$Script:InfluxRemoteDownloadPath             = $UserPref.InfluxDownloadPath
    [string]$Script:GrafanaRemoteDownloadPath            = $UserPref.GrafanaDownloadPath
    [string]$Script:NssmRemoteDownloadPath               = $UserPref.NssmDownloadPath
    
    ##filenames for official releases
    [string]$Script:InfluxFileName                       = ($UserPref.InfluxDownloadPath -split '/')[-1]
    [string]$Script:GrafanaFileName                      = ($UserPref.GrafanaDownloadPath -split '/')[-1]
    [string]$Script:NssmFileName                         = ($UserPref.NssmDownloadPath -split '/')[-1]

    ##output path for official releases
    [string]$Script:OutPathInfluxDB                      = ('{0}\{1}' -f $DownloadPathLocal, $InfluxFileName)
    [string]$Script:OutPathGrafana                       = ('{0}\{1}' -f $DownloadPathLocal, $GrafanaFileName)
    [string]$Script:OutPathNssm                          = ('{0}\{1}' -f $DownloadPathLocal, $NssmFileName)
    #end region

    #region development bits
    ##output path for development builds
    [string]$Script:InfluxRemoteDownloadPathDev          = $DevBuild.InfluxDevPath
    [string]$Script:GrafanaRemoteDownloadPathDev         = $DevBuild.GrafanaDevPath
    [string]$Script:NssmRemoteDownloadPathDev            = $DevBuild.NssmDevPath
    #end region

    Function Get-DevBuild {
    
      <#
        .DESCRIPTION
         Handles runtime setup of paths, etc. so we can consume development downloads
         of InfluxDB, Grafana and/or NSSM (if any).
         
         We also provide a layer of best practice protection by asking user to confirm
         (using ShouldProcess), before we allow downloading of non-production releases.


         .NOTES
          Script:         Get-DevBuild.ps1
          Type:           Function
          Author:         Mike Nisk
          Organization:   vmkdaily
          Updated:        23April2017
      #>
      
      [CmdletBinding(SupportsShouldProcess=$true)]
      param()
      
        Begin {
          $InitialConfirmPref = $ConfirmPreference
          $ConfirmPreference = 'low'
        }
      
        Process {
            If($UseDevBuildFor) {
            
                If($pscmdlet.ShouldProcess("$($Env:ComputerName)", 'Download one or more development builds')) {
            
                    switch($UseDevBuildFor) {

                        Influx {
                          [string]$Script:InfluxRemoteDownloadPath = $DevBuild.InfluxDevPath
                          [string]$Script:InfluxFileName = ($DevBuild.InfluxDevPath -split '/')[-1]
                          [string]$Script:OutPathInflux = ('{0}\{1}' -f $DownloadPathDev, $InfluxFileName)
                        }
                        Grafana {
                          [string]$Script:GrafanaRemoteDownloadPath = $DevBuild.GrafanaDevPath
                          [string]$Script:GrafanaFileName = ($DevBuild.GrafanaDevPath -split '/')[-1]
                          [string]$Script:OutPathGrafana = ('{0}\{1}' -f $DownloadPathDev, $GrafanaFileName)
                        }
                        NSSM {
                          [string]$Script:NssmRemoteDownloadPath = ($DevBuild.NssmDevPath)
                          [string]$Script:NssmFileName = ($DevBuild.NssmDevPath -split '/')[-1]
                          [string]$Script:OutPathNssm = ('{0}\{1}' -f $DownloadPathDev, $NssmFileName)
                        }
                        All {
                          [string]$Script:InfluxRemoteDownloadPath = $DevBuild.InfluxDevPath
                          [string]$Script:InfluxFileName = ($DevBuild.InfluxDevPath -split '/')[-1]
                          [string]$Script:OutPathInflux = ('{0}\{1}' -f $DownloadPathDev, $InfluxFileName)
                          [string]$Script:GrafanaRemoteDownloadPath = $DevBuild.GrafanaDevPath
                          [string]$Script:GrafanaFileName = ($DevBuild.GrafanaDevPath -split '/')[-1]
                          [string]$Script:OutPathGrafana = ('{0}\{1}' -f $DownloadPathDev, $GrafanaFileName)
                          [string]$Script:NssmRemoteDownloadPath = ($DevBuild.NssmDevPath)
                          [string]$Script:NssmFileName = ($DevBuild.NssmDevPath -split '/')[-1]
                          [string]$Script:OutPathNssm = ('{0}\{1}' -f $DownloadPathDev, $NssmFileName)
                        }
                        None {
                          Write-Msg -InputMessage 'No Development Builds selected.'
                        }
                        Default {
                          #nothing
                        }
                    } #End Switch
                 } #End should process
                 Else {
                  Write-Warning -Message 'ShouldProcess settings prevented download of develeopment binaries'
                  Write-Warning -Message 'This is the expected script bahavior.  To allow dev builds you must agree.'
                } #End Else
            } #End If dev builds
        } #End Process
        
        End {
            If($ConfirmPreference -notmatch $InitialConfirmPref){
                $ConfirmPreference = $InitialConfirmPref
            } #End If
        } #End End
    } #End Function
    
    #prepare configuration for dev builds, if needed.
    #user will be warned and must to confirm ('y' or 'yes') to download development releases.
    If($PSCmdlet.MyInvocation.BoundParameters['UseDevBuildFor']){
        Get-DevBuild
    }
    Else {
      #the default, we expect no dev packages
      Write-Debug -Message 'No development packages requested'
    }

    Function Get-Grafana {
      [CmdletBinding()]
      Param()
      
      Process {
        Try {
            Write-Msg -InputMessage '..Starting download of Grafana for Windows'
            Invoke-WebRequest -Uri $GrafanaRemoteDownloadPath -OutFile $OutPathGrafana -ErrorAction Stop
            Write-Msg -InputMessage 'Done with Grafana download!'
        }
        Catch {
            Write-Warning -Message ('Problem downloading Grafana to {0}' -f ($DownloadPathLocal))
            Write-Warning -Message ('{0}' -f $_.Exception.Message)
        } #End Catch
      } #End Process
       
      End {
        If(Test-Path -Path $OutPathGrafana -ErrorAction SilentlyContinue){
          Write-Msg -InputMessage ('Filename is {0}' -f ($OutPathGrafana))
          $downloadOK += $OutPathGrafana
        } #End If
      } #End End
    } #End function

    Function Get-Nssm {
      [CmdletBinding()]
      Param()
      
      Process {
        Try {
            Write-Msg -InputMessage '..Starting download of NSSM for Windows'
            Invoke-WebRequest -Uri $NssmRemoteDownloadPath -OutFile $OutPathNssm -ErrorAction Stop
            Write-Msg -InputMessage 'Done with NSSM download!'
        } #End Try
        Catch {
            Write-Warning -Message ('Problem downloading NSSM to {0}' -f ($DownloadPathLocal))
            Write-Warning -Message ('{0}' -f $_.Exception.Message)
        } #End Catch
      } #End Process
      
      End {
        If(Test-Path -Path $OutPathNssm -ErrorAction SilentlyContinue){
          Write-Msg -InputMessage ('Filename is {0}' -f ($OutPathNssm))
          $downloadOK += $OutPathNssm
        } #End If
      } #End End
    } #End function
} #End Begin

Process {

    #welcome message
    Write-Msg -InputMessage ('Welcome to {0}' -f $MyInvocation.Mycommand)

    ## production releases
    ## check if download path exists, if not create it
    If(-Not(Test-Path -Path $DownloadPathLocal -PathType Container -ErrorAction SilentlyContinue)) {

        If($AllowFolderCreation) {    
            Try {
                $null = New-Item -ItemType Directory -Path $DownloadPathLocal -Force -ErrorAction Stop
                Write-Msg -InputMessage "Created folder for main downloads $($pathAlive = (Get-Item -Path $DownloadPathLocal).FullName; $pathAlive)"
            } #End Try
            Catch {
                Write-Warning -Message 'Problem reaching or creating requested download path on local filesysytem'
                Write-Warning -Message ('{0}' -f $_.Exception.Message)
            } #End Catch
        } #End If allowed
        Else {
          Throw 'Cannot validate path to save main downloads'
        }
    } #End If
    Else {
          Write-Msg -InputMessage "Main download folder: $($DownloadPathLocal)"
    }

    ## development builds
    ## check if download path exists, if not create it
    If($PSCmdlet.MyInvocation.BoundParameters['UseDevBuildFor']) {
        If(-Not(Test-Path -Path $DownloadPathDev -PathType Container -ErrorAction SilentlyContinue)) {
            
            If($AllowFolderCreation){
                Try {
                    $null = New-Item -ItemType Directory -Path $DownloadPathDev -Force -ErrorAction Stop
                    Write-Msg -InputMessage "Created folder for Dev Builds $($pathAlive = (Get-Item -Path $DownloadPathDev).FullName; $pathAlive)"
                } #End Try
                Catch {
                    Write-Warning -Message 'Problem reaching or creating requested download path on local filesysytem'
                    Write-Warning -Message ('{0}' -f $_.Exception.Message)
                } #End Catch
            } #End If allowed
            Else {
              Throw 'Cannot validate path to save development build downloads'
            }
        } #End If
        Else {
          Write-Msg -InputMessage "Development build folder: $($DownloadPathDev)."
        }
    } #End If
    
    ## MAIN
    If((Test-Path -Path $DownloadPathLocal -PathType Container -ErrorAction SilentlyContinue) -or
        (Test-Path -Path $DownloadPathDev -PathType Container -ErrorAction SilentlyContinue)) {
    
        #evaluate DownloadType parameter and perform actions if needed
        switch($DownloadType){

            InfluxDB {
                #download influxdb
                Get-InfluxDB
            }

            Grafana {
                #download grafana
                Get-Grafana
            }

            NSSM {
                #download grafana
                Get-Nssm
            }

            All {
                #get all three
                Get-InfluxDB
                Get-Grafana
                Get-Nssm
            }
            None {
                #Parameter default is None.
                Write-Msg -InputMessage 'No download selected!'
            }
            Default {
                #nothing
            }
        } #End switch
    } #End if
    Else {
        Write-Warning -Message ('Problem with {0}' -f ($DownloadPathLocal))
    } #End else
  } #End Process

  End {
    If(($downloadOK.Count) -gt 1){
      Write-Msg -InputMessage 'Summary of files downloaded:'
      Write-Msg -InputMessage ('{0}' -f ($downloadOK))
    } #End If
  } #End End

