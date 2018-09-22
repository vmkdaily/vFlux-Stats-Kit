#Requires -Version 3

Function Get-FluxCrontab {
  
  <#
      .DESCRIPTION
        Display the currently running cron jobs on the local system. By default searches for scripts you create that start with the name 'stat-runner' (since we use thatt in the examples). Optionally, populate the Name parameter to search for a unique string.
        
      .NOTES
        Script:   Get-FluxCrontab.ps1
        Author:   Mike Nisk
        Tested:   PowerShell Core 6.x on Ubuntu LTS 16.04

      .PARAMETER Name
        String. Optionally, enter The name or portion of name of script to search in cron.

      .PARAMETER Count
        Integer. Optionally, enter the number of times to run. The default is 1.

      .PARAMETER SleepSeconds
        Integer. Optionally, enter the number in seconds to sleep between iterations. The default is 60. This parameter is Ignored if Count is not greater than 1.

      .PARAMETER Depth
        Integer. Optionally, enter the number of lines to return. The default is 1 which returns only the script name running in cron.  Increasing this value is not recommended if result accuracy is important.  If the value of the Depth parameter is increased beyond the number of lines in your script (plus 1) you will see additional cron detail that may not be desired or related.
  
      .EXAMPLE
      Get-FluxCrontab

      .EXAMPLE
      Get-FluxCrontab -Name 'my-script.ps1'

      Here we search ps for cron entries that match the provided Name. You can also use the leaf of the name (no need to add file extension).
  
      .EXAMPLE
      PS /home/fluxor> Get-FluxCrontab
      2018-09-21T19:30:36.9097133-05:00

      > 19496 19496  |   \_ /bin/sh -c ~/stat-runner-summary-vmhost.ps1
      > 19498 19496  |       \_ /snap/powershell/11/opt/powershell/pwsh /home/fluxor/stat-runner-summary-vmhost.ps1
        19492   991  \_ /usr/sbin/CRON -f
      > 19495 19495  |   \_ /bin/sh -c ~/stat-runner-summary-vm.ps1
      > 19497 19495  |       \_ /snap/powershell/11/opt/powershell/pwsh /home/fluxor/stat-runner-summary-vm.ps1
        19493   991  \_ /usr/sbin/CRON -f
      > 19500 19500  |   \_ /bin/sh -c ~/stat-runner-iops.ps1
      > 19502 19500  |       \_ /snap/powershell/11/opt/powershell/pwsh /home/fluxor/stat-runner-iops.ps1
        19750 19500  |           \_ /bin/sleep 20
      > 19499 19499      \_ /bin/sh -c ~/stat-runner-compute.ps1
      > 19501 19499          \_ /snap/powershell/11/opt/powershell/pwsh /home/fluxor/stat-runner-compute.ps1
        19751 19499              \_ /bin/sleep 20

      The output returns the pid of each matching result for the default of 'stat-runner' which we use as the leaf name for examples. Remember that 'stat-runner' scripts are not an official name, or anything that the Fluxor module creates for you. However, we recommend keeping that (unless you have a better standard). If you will create a custom script name that does not include 'stat-runner', then populate the Name parameter.

      .EXAMPLE
      PS /home/fluxor> Get-FluxCrontab -Name 'iops'
      2018-09-21T19:37:11.1757284-05:00

      > 19500 19500  |   \_ /bin/sh -c ~/stat-runner-iops.ps1
      > 19502 19500  |       \_ /snap/powershell/11/opt/powershell/pwsh /home/fluxor/stat-runner-iops.ps1
        19494   991  \_ /usr/sbin/CRON -f



  #>

  [CmdletBinding()]
  Param(
  
    #String. The name or portion of name to search in cron.
    [string]$Name = 'stat-runner',
    
    #Integer. Optionally, enter the number of time to run. The default is 1.
    [int]$Count = 1,
      
    #Integer. Optionally, enter the number in seconds to sleep between iterations. The default is 60. Ignored if Count is not greater than 1.
    [int]$SleepSeconds = 60,
    
    #Integer. Optionally, enter the number of lines to return. Ignored if Count is less than 1.
    [int]$Depth = 1
  )

  Process {

    If(-not($IsCoreCLR)){
      Write-Warning -Message 'This feature of the Fluxor module requires Core Edition of PowerShell'
      Throw 'Requires CoreCLR!'
    }
    Else{
      1..$Count | ForEach-Object {
        
          ## Show date
          $(Get-Date -Format o)
        
          ## Show cron
          try{
            Invoke-Command -ScriptBlock {
          
              ps -o pid,sess,cmd afx | Select-String $Name -Context (0,$Depth)
              Write-Host ''
            } -ErrorAction Stop
          }
          Catch{
            throw
          }
        
          ## Sleep timer
          If($Count -gt 1){
            $null = Start-Sleep -Seconds $SleepSeconds
          }
      }
    }
  }
}