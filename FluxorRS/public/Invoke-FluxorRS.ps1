#requires -Version 3
#requires -Modules PoshRSJob,VMware.VimAutomation.Core,Fluxor
Function Invoke-FluxorRS {
  <#

      .DESCRIPTION
        For users of the Fluxor module, FluxorRS allows the use of PowerShell Runspace jobs to connect to one or more vCenter Servers, gather performance stats and write them to InfluxDB. By default, realtime stats are gathered and written. Optionally, use the Repaint switch for past hour. Be aware that Repaint will not return device level or detailed iops, etc. This is determined based on your vCenter configuration for performance rollups. 

      .NOTES
        Script:              Invoke-FluxorRS.ps1
        Author:              Mike Nisk
        Prior Art:           Start-RSJob syntax based on VMTN thread:
                             https://communities.vmware.com/thread/513253

        Supported Versions:  Microsoft PowerShell 3.0 through PowerShell 5.1
                             VMware PowerCLI 6.5.4 or later (PowerCLI 11.x or later preferred)
                             PoshRSJob 1.7.3.9 or later
                             vCenter Server 6.0 or later

      .PARAMETER Server
        String. The IP Address or DNS Name of one or more VMware vCenter Server machines.

      .PARAMETER UseFluxorAuth
        Boolean. Pass the login burden for vCenter Server and InfluxDB to the Fluxor module (required by FluxorRS). By default, the value of the UseFluxorAuth parameter is $true. This is ignored if the Credential or CredentialPath parameter is used for (vCenter login) and is also ignored if the InfluxDBCredential or InfluxDBCredentialPath are populated
      
      .PARAMETER Credential
        PSCredential. The login for vCenter Server.

      .PARAMETER CredentialPath
        String. Optionally, enter the path to a Credential on disk.

      .PARAMETER InfluxDBServer
        String. The IP Address or DNS name of the InfluxDB Server.

      .PARAMETER Repaint
        Switch. Optionally, activate the Repaint switch to gather and write stats for the past Hour instead of the default of realtime.

      .PARAMETER Strict
        Boolean. Prevents fall-back to hard-coded script values for login credential if any. The value of the Strict parameter determines how the sibling Fluxor module performs Get and Write operations such as Get-FluxIOPS and Write-FluxIOPS, etc.
      
      .EXAMPLE
      Invoke-FluxorRS -Server vc01.lab.local -Credential (Get-Credential administrator@vsphere.local)
      
      Get prompted for login information and then return a report for a single vCenter Server.

      .EXAMPLE
      $credsVC = Get-Credential administrator@vsphere.local
      $vcList = @('vc01.lab.local', 'vc02.lab.local', 'vc03.lab.local')
      $report = Invoke-FluxorRS -Server $vcList -Credential $credsVC

      Save a credential to a variable and then operate against several vCenter Servers when returning stats.

      .EXAMPLE
      $credsVC = Get-Credential administrator@vsphere.local
      $report = Invoke-FluxorRS -Server (gc $home/vc-list.txt) -Credential $credsVC

      Use Get-Content to feed the Server parameter by pointing to a text file. The text file should have one vCenter Server name per line.
      This example assumes that the InfluxDBServer and login are handled already by the sibling Fluxor module.

      .Example
      PS C:\> Get-Module -ListAvailable -Name @('PoshRSJob','VMware.PowerCLI','Fluxor','FluxorRS') | select Name,Version

      Name            Version
      ----            -------
      Fluxor          1.0.0.9
      FluxorRS        1.0.0.9
      PoshRSJob       1.7.4.4
      VMware.PowerCLI 11.0.0.10380590

      This example tests the current client for the required modules. The script and parent module does checking for this as well. The version is not too important; latest is greatest. For vSAN, having PowerCLI version 11.0 or better makes lookups more efficient (handled in Get-FluxIOPS of the sibling Fluxor module).

      .INPUTS
      none

      .OUTPUTS
      none
  #>

  [CmdletBinding()]
  Param(

    #String. The IP Address or DNS name of one or more VMware vCenter Server machines.
    $Server,
    
    #Boolean. Pass the login burden for vCenter Server and InfluxDB to the sibling module Fluxor. By default, the value of the UseFluxorAuth parameter is $true, which assumes you have the Fluxor module setup already. This is ignored if the Credential or CredentialPath parameter is used for (vCenter login) and is also ignored if the InfluxDBCredential or InfluxDBCredentialPath are populated.
    [bool]$UseFluxorAuth,
    
    #Boolean. Controls the Strict parameter sent to the sibling module Fluxor. The default value is $true which prevents fall-back to plain text values for login to vCenter Server and InfluxDB in the relevant Get-Flux* and Write-Flux* functions of Fluxor (the sibling module to FluxorRS). By setting the value for Strict to $false, FluxorRS will use the plain text value for login to vCenter Server and/or InfluxDB contained in the sibling Fluxor module, if any.
    [bool]$Strict = $true,

    #PSCredential. The login for vCenter Server.
    [PSCredential]$Credential,

    #String. The default is the expected credential on disk. Optionally, enter the path to the desired Credential on disk, or populate the Credential parameter instead.  The CredentialPath parameter is the best and recommended way to run on Windows, especially when running Scheduled Tasks. This can be created using New-FluxCredential if you do not have it already.
    [string]$CredentialPath,
    
    #String. The IP Address or DNS Name of the local or remote InfluxDB server. The default is localhost.
    [string]$InfluxDBServer,
    
    #PScredential. The login for InfluxDB Server.
    [PSCredential]$InfluxDBCredential,
    
    #String. Optionally, provide the path to InfluxDB login credential on disk. Not supported on Core Editions of PowerShell.
    [string]$InfluxDBCredentialPath,

    #Switch. Optionally, gather and write all stats for the past Hour.
    [switch]$Repaint
    
  )

  Process {

    Start-RSJob -ScriptBlock {
      #requires -Modules VMware.Vimautomation.Core,VMware.VimAutomation.Storage,Fluxor

      <#
          .DESCRIPTION
            Runspace job to run against one or more vCenter Servers.
      #>
      [CmdletBinding()]
      param()
        
        ## Handle Server parameter. This is the IP Address or DNS name of the vCenter Server.
        If($Using:Server){
          $Server = $Using:Server
        }
        Else{
          throw 'Cannot determine vCenter Server!'
        }

        ## Handle InfluxDBServer parameter
        If($Using:InfluxDBServer){
          $InfluxDBServer = $Using:InfluxDBServer
          Write-Verbose -Message ('Using InfluxDB Server of {0}' -f $InfluxDBServer)
        }
        Elseif($Using:UseFluxorAuth){
          ## set as localhost (same as default). The Fluxor module will handle any additional defaults set there, if any.
          $InfluxDBServer = "localhost"
        }
        
        ## Handle Credential for vCenter Server
        If($Using:Credential){
          $credsVC = $Using:Credential
        }
        ## Handle CredentialPath for vCenter Server
        Elseif($Using:CredentialPath){
          try{
            $credsVC = Get-FluxCredential -Path $Using:CredentialPath
          }
          catch{
            Write-Error -Message ('{0}' -f $_.Exception.Message)
            throw
          }
        }
        ## Handle UseFluxorAuth parameter
        Elseif($Using:UseFluxorAuth -eq $true){
          Write-Verbose -Message 'Passing vCenter Server login burden to Fluxor module'
          [bool]$UseFluxorAuth = $Using:UseFluxorAuth
        }
        Else{
          throw 'No Credential or CredentialPath provided for vCenter login!'
        }

        ## Get InfluxDB Credential
        If($null -ne $Using:InfluxDBCredential -and $Using:InfluxDBCredential -is [PSCredential]){
          $credsInfluxDB = $Using:InfluxDBCredential
        }
        Elseif($null -ne $Using:InfluxDBCredentialPath -and (Test-Path -Path $Using:InfluxDBCredentialPath -PathType Leaf)){
          try{
            $credsInfluxDB = Get-FluxCredential -Path $Using:InfluxDBCredentialPath
          }
          catch{
            Write-Error -Message ('{0}' -f $_.Exception.Message)
            throw
          }
        }
        Elseif($UseFluxorAuth -eq $true){
          Write-Verbose -Message 'Passing InfluxDB login burden to Fluxor module'
        }
        Else{
          Write-Warning -Message ('No InfluxDBCredential or InfluxDBCredentialPath provided for login to InfluxDB server {0}!' -f $InfluxDBServer)
          throw
        }

        ## Handle one or more vCenter Servers
        Foreach($vc in $Server){

          ## Connect to vCenter
          If($null -ne $CredsVC){
            try {
              $null = Connect-VIServer -Server $vc -Credential $CredsVC -WarningAction Ignore -ErrorAction Stop
            }
            catch{
              Write-Error -Message ('{0}' -f $_.Exception.Message)
              Write-Warning -Message ('Problem connecting to {0} (skipping)!' -f $vc)
              Continue
            }
          }
          Elseif($UseFluxorAuth -eq $true){
            Write-Verbose -Message 'Passing vCenter Server login burden to Fluxor module'
          }
          Else{
            Write-Warning -Message ('No Credential or CredentialPath provided for {0} (skipping)!' -f $vc)
            Continue
          }
          
          ## Handle Repaint, if needed
          If($Using:Repaint -eq $true){
            [switch]$Repaint = $true
          }Else{
            [switch]$Repaint = $false
          }
        
          #####################
          ## STRICT MODE TRUE
          #####################
          If($Using:Strict -eq $true){
            ## Get VM Compute Stats
            If($Global:DefaultVIServer.IsConnected){
              If($Repaint){
                try{
                  $statsVM = Get-FluxCompute -Server $vc -ReportType VM -Repaint -ErrorAction Stop
                }
                catch{
                  Write-Error $Error[0]
                  throw $_
                }
              }
              Else{
                try{
                  $statsVM = Get-FluxCompute -Server $vc -ReportType VM -ErrorAction Stop
                }
                catch{
                  Write-Error $Error[0]
                  throw $_
                }
              }
            }
            Else{
              throw 'Not connected!'
            }
          
            ## Write VM Compute Stats
            If($UseFluxorAuth){
              try{
                Write-FluxCompute -Server $InfluxDBServer -InputObject $statsVM -ErrorAction Stop
              }
              catch{
                throw $_
              }
            }
            Else{
              try{
                Write-FluxCompute -Server $InfluxDBServer -Credential $credsInfluxDB -InputObject $statsVM -ErrorAction Stop
              }
              catch{
                throw $_
              }
            }
          
            ## Get ESXi Host Stats
            If($Global:DefaultVIServer.IsConnected){
              If($Repaint){
                try{
                  $statsVMHost = Get-FluxCompute -Server $vc -ReportType VMHost -Repaint -ErrorAction Stop
                }
                catch{
                  throw $_
                }
              }
              Else{
                try{
                  $statsVMHost = Get-FluxCompute -Server $vc -ReportType VMHost -ErrorAction Stop
                }
                catch{
                  throw $_
                }
              }
            }
            Else{
              Else{
                throw 'Not connected!'
              }
            }

            ## Write ESXi Host Stats
            If($UseFluxorAuth){
              try{
                Write-FluxCompute -Server $InfluxDBServer -InputObject $statsVMHost -ErrorAction Stop
              }
              catch{
                throw $_
              }
            }
            Else{
              try{
                Write-FluxCompute -Server $InfluxDBServer -Credential $credsInfluxDB -InputObject $statsVMHost -ErrorAction Stop
              }
              catch{
                throw $_
              }
            }
          
            ## Get VM IOPS
            If($Global:DefaultVIServer.IsConnected){
              If($Repaint){
                try{
                  $iops = Get-FluxIOPS -Server $vc -Repaint -ErrorAction Stop
                }
                catch{
                  throw $_
                }
              }
              Else{
                try{
                  $iops = Get-FluxIOPS -Server $vc -ErrorAction Stop
                }
                catch{
                  throw $_
                }
              }
            }
            Else{
              throw 'Not connected!'
            }

            ## Write VM IOPS
            If($UseFluxorAuth){
              try{
                Write-FluxIOPS -Server $InfluxDBServer -InputObject $iops -ErrorAction Stop
              }
              catch{
                throw $_
              }
            }
            Else{
              try{
                Write-FluxIOPS -Server $InfluxDBServer -Credential $credsInfluxDB -InputObject $iops -ErrorAction Stop
              }
              catch{
                throw $_
              }
            }

            ## Get VM Summary Stats
            If($Global:DefaultVIServer.IsConnected){
              try{
                $summaryVM = Get-FluxSummary -Server $vc -ReportType VM -ErrorAction Stop
              }
              catch{
                throw $_
              }
            }
            Else{
              throw 'Not connected!'
            }

            ## Write VM Summary Stats
            If($UseFluxorAuth){
              try{
                Write-FluxSummary -Server $InfluxDBServer -InputObject $summaryVM -ErrorAction Stop
              }
              catch{
                throw $_
              }
            }
            Else{
              try{
                Write-FluxSummary -Server $InfluxDBServer -Credential $credsInfluxDB -InputObject $summaryVM -ErrorAction Stop
              }
              catch{
                throw $_
              }
            }

            ## Get VMHost Summary Stats
            If($Global:DefaultVIServer.IsConnected){
              try{
                $summaryVMHost = Get-FluxSummary -Server $vc -ReportType VMHost -ErrorAction Stop
              }
              catch{
                throw $_
              }
            }
            Else{
              throw 'Not connected!'
            }
          
            ## Write VMHost Summary Stats
            If($UseFluxorAuth){
              try{
                Write-FluxSummary -Server $InfluxDBServer -InputObject $summaryVMHost -ErrorAction Stop
              }
              catch{
                throw $_
              }
            }
            Else{
              try{
                Write-FluxSummary -Server $InfluxDBServer -Credential $credsInfluxDB -InputObject $summaryVMHost -ErrorAction Stop
              }
              catch{
                throw $_
              }
            }
          }
          Else{
            #####################
            ## STRICT MODE FALSE
            #####################
            ## Get VM Compute Stats
            If($Global:DefaultVIServer.IsConnected){
              If($Repaint){
                try{
                  $statsVM = Get-FluxCompute -Server $vc -ReportType VM -Repaint -Strict:$False -ErrorAction Stop
                }
                catch{
                  Write-Error $Error[0]
                  throw $_
                }
              }
              Else{
                try{
                  $statsVM = Get-FluxCompute -Server $vc -ReportType VM -Strict:$False -ErrorAction Stop
                }
                catch{
                  Write-Error $Error[0]
                  throw $_
                }
              }
            }
            Else{
              throw 'Not connected!'
            }
          
            ## Write VM Compute Stats
            If($UseFluxorAuth){
              try{
                Write-FluxCompute -Server $InfluxDBServer -InputObject $statsVM -Strict:$False -ErrorAction Stop
              }
              catch{
                throw $_
              }
            }
            Else{
              try{
                Write-FluxCompute -Server $InfluxDBServer -Credential $credsInfluxDB -InputObject $statsVM -Strict:$False -ErrorAction Stop
              }
              catch{
                throw $_
              }
            }
          
            ## Get ESXi Host Stats
            If($Global:DefaultVIServer.IsConnected){
              If($Repaint){
                try{
                  $statsVMHost = Get-FluxCompute -Server $vc -ReportType VMHost -Repaint -Strict:$False -ErrorAction Stop
                }
                catch{
                  throw $_
                }
              }
              Else{
                try{
                  $statsVMHost = Get-FluxCompute -Server $vc -ReportType VMHost -Strict:$False -ErrorAction Stop
                }
                catch{
                  throw $_
                }
              }
            }
            Else{
              Else{
                throw 'Not connected!'
              }
            }

            ## Write ESXi Host Stats
            If($UseFluxorAuth){
              try{
                Write-FluxCompute -Server $InfluxDBServer -InputObject $statsVMHost -Strict:$False -ErrorAction Stop
              }
              catch{
                throw $_
              }
            }
            Else{
              try{
                Write-FluxCompute -Server $InfluxDBServer -Credential $credsInfluxDB -InputObject $statsVMHost -Strict:$False -ErrorAction Stop
              }
              catch{
                throw $_
              }
            }
          
            ## Get VM IOPS
            If($Global:DefaultVIServer.IsConnected){
              If($Repaint){
                try{
                  $iops = Get-FluxIOPS -Server $vc -Repaint -Strict:$False -ErrorAction Stop
                }
                catch{
                  throw $_
                }
              }
              Else{
                try{
                  $iops = Get-FluxIOPS -Server $vc -Strict:$False -ErrorAction Stop
                }
                catch{
                  throw $_
                }
              }
            }
            Else{
              throw 'Not connected!'
            }

            ## Write VM IOPS
            If($UseFluxorAuth){
              try{
                Write-FluxIOPS -Server $InfluxDBServer -InputObject $iops -Strict:$False -ErrorAction Stop
              }
              catch{
                throw $_
              }
            }
            Else{
              try{
                Write-FluxIOPS -Server $InfluxDBServer -Credential $credsInfluxDB -InputObject $iops -Strict:$False -ErrorAction Stop
              }
              catch{
                throw $_
              }
            }

            ## Get VM Summary Stats
            If($Global:DefaultVIServer.IsConnected){
              try{
                $summaryVM = Get-FluxSummary -Server $vc -ReportType VM -Strict:$False -ErrorAction Stop
              }
              catch{
                throw $_
              }
            }
            Else{
              throw 'Not connected!'
            }

            ## Write VM Summary Stats
            If($UseFluxorAuth){
              try{
                Write-FluxSummary -Server $InfluxDBServer -InputObject $summaryVM -Strict:$False -ErrorAction Stop
              }
              catch{
                throw $_
              }
            }
            Else{
              try{
                Write-FluxSummary -Server $InfluxDBServer -Credential $credsInfluxDB -InputObject $summaryVM -Strict:$False -ErrorAction Stop
              }
              catch{
                throw $_
              }
            }

            ## Get VMHost Summary Stats
            If($Global:DefaultVIServer.IsConnected){
              try{
                $summaryVMHost = Get-FluxSummary -Server $vc -ReportType VMHost -Strict:$False -ErrorAction Stop
              }
              catch{
                throw $_
              }
            }
            Else{
              throw 'Not connected!'
            }
          
            ## Write VMHost Summary Stats
            If($UseFluxorAuth){
              try{
                Write-FluxSummary -Server $InfluxDBServer -InputObject $summaryVMHost -Strict:$False -ErrorAction Stop
              }
              catch{
                throw $_
              }
            }
            Else{
              try{
                Write-FluxSummary -Server $InfluxDBServer -Credential $credsInfluxDB -InputObject $summaryVMHost -Strict:$False -ErrorAction Stop
              }
              catch{
                throw $_
              }
            }
          }
          
          ## Session cleanup
          If($Global:DefaultVIServer.IsConnected -or $UseFluxorAuth -eq $false){
            try{
              $null = Disconnect-VIServer -Server $vc -Confirm:$false -Force -WarningAction Ignore -ErrorAction Ignore
            }
            catch{
              Write-Error -Message ('{0}' -f $_.Exception.Message)
            }
          }
        } #End Foreach VM
    } -ModulesToImport @('VMware.VimAutomation.Core','VMware.VimAutomation.Storage','Fluxor') | Wait-RSJob | Remove-RSJob
  } #End Process
} #End Function