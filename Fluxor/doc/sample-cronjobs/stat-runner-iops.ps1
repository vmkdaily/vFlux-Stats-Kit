#!/snap/bin/pwsh
$vc = 'vcva01.lab.local'
$iops = Get-FluxIOPS -Server $vc
Write-FluxIOPS -InputObject $iops
