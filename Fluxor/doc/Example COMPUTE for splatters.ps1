
#################
## COMPUTE
#################

## Step 1 - Launch PowerShell, if needed

  pwsh

## STEP 2 - Set your VC and influxdb server names here
$vc = 'vcva01.lab.local'
$influx = 'localhost'

## STEP 3 - Set the splat params for gathering compute stats
$sCOMPUTE_GET_OPTIONS = @{
  Server    = $vc
  Strict    = $false
  ShowStats = $false
  Logging   = $false
}

## STEP 4 - Get the stats
$stats = Get-FluxCompute @sCOMPUTE_GET_OPTIONS

## STEP 5 - Set the splat params for writing to InfluxDB
$sCOMPUTE_WRITE_OPTIONS = @{
  Server                =  $influx
  InputObject           =  $stats
  Strict                =  $false
  ShowRestActivity      =  $true
  Logging               =  $false
}

## Step 6 - Write the stats
Write-FluxCompute @sCOMPUTE_WRITE_OPTIONS
