#################
## IOPS
#################

## Step 1 - Launch PowerShell, if needed

  pwsh

## STEP 2 - Set your VC and influxdb server names here
$vc = 'vcva01.lab.local'
$influx = 'localhost'

## STEP 3 - Set the splat params for gathering iops stats
$sIOPS_GET_OPTIONS = @{
  Server    = $vc
  Strict    =$false
  ShowStats =$false
  Logging   = $false
}

## STEP 4 - Get the iops
$iops = Get-FluxIOPS @sIOPS_GET_OPTIONS

## STEP 5 - Set the splat params for writing iops results to InfluxDB
$sIOPS_WRITE_OPTIONS = @{
  Server                =  $influx
  InputObject           =  $iops
  Strict                =  $false
  ShowRestActivity      =  $true
  Logging               =  $false
}

## Step 6 - Write the iops
Write-FluxIOPS @sIOPS_WRITE_OPTIONS
