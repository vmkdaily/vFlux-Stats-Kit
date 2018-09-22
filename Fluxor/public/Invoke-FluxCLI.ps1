#Requires -Version 3

Function Invoke-FluxCLI {
  <#
      .DESCRIPTION
        Run the influx binary on localhost of an InfluxDB Server using PowerShell.

      .NOTES
        Script:    Invoke-FluxCLI.ps1
        Author:    Mike Nisk
        Requires:  An existing InfluxDB installation on the local system (we require the influx binary)
        Tested on: PowerShell CoreCLR 6.0 and 6.1 On Ubuntu 16.04 LTS

      .PARAMETER ProgramPath
        String. Optionally, enter the full path to your influx binary.
        Type 'which influx' to learn your path if needed.
      
      .PARAMETER Database
        String. The default database to use when connecting to InfluxDB.
        Tab complete through options of '_internal','compute', 'iops', or 'summary'.
      
      .PARAMETER ScriptText
        String. The command to execute via InfluxDB CLI.
      
      .PARAMETER Version
        Switch. Show version of InfluxDB CLI Shell and exit.
      
      .PARAMETER Interactive
        Switch. Interact with the InfluxDB CLI directly. Type quit or exit to return to PowerShell.

  #>

  [CmdletBinding()]
  Param(

      #String. Optionally, enter the full path to your influx binary.
      [ValidateScript({Test-Path $_})]
      [string]$ProgramPath = '/usr/bin/influx',

      #String. The default database to use when connecting to InfluxDB. Tab complete through options of '_internal','compute', 'iops', or 'summary'.
      [ValidateSet('_internal','compute','iops','summary')]
      [string]$Database = '',
      
      #String. The command to execute via influx cli.
      [string]$ScriptText = '',
      
      #Switch. Show version of InfluxDB CLI Shell and exit.
      [switch]$Version,
      
      #Switch. Interact with the InfluxDB CLI directly. Type quit or exit to return to PowerShell.
      [switch]$Interactive
  )

  Process {
        
      If($Version){
        try{
            Start-Process $ProgramPath -ArgumentList '-version' -NoNewWindow -ErrorAction Stop
        }
        catch{
          Write-Warning -Message 'Failed to get version!'
          throw
        }
      }
      Elseif($ScriptText){
        If($Database){
          [string]$wrappedArgs = "-database `"$($Database)`" -execute `"$($ScriptText)`""
          try{
            $result = Start-Process -FilePath $ProgramPath -ArgumentList $wrappedArgs -NoNewWindow -ErrorAction Stop
          }
          catch{
            Write-Warning -Message ('Failed to run: {0} at {1}' -f $wrappedArgs, $ProgramPath)
            throw
          }
        }
        Else{
          [string]$wrappedArgs = "-execute `"$($ScriptText)`""
          try{
            $result = Start-Process $ProgramPath -ArgumentList $wrappedArgs -NoNewWindow -ErrorAction Stop
          }
          catch{
            Write-Warning -Message ('Failed to run: {0} at {1}' -f $wrappedArgs, $ProgramPath)
            throw
          }
        }
      }
      Elseif($Interactive){
        If($Database){
          [string]$wrappedArgs = "-database `"$($Database)`""
          try{
            $result = Start-Process $ProgramPath -ArgumentList $wrappedArgs -NoNewWindow -Wait -ErrorAction Stop
          }
          catch{
            throw
          }
        }
        Else{
          try{
            $result = Start-Process $ProgramPath -NoNewWindow -Wait -ErrorAction Stop
          }
          catch{
            throw
          }
        }
      }
      Else{
        Write-Warning -Message 'Selection could not be determined!'
      }

      ## Output
      If($result){
          return $result
      }
  } #End Process
}