#!/snap/bin/pwsh
$vc = 'vcva01.lab.local'
1..25 | ForEach-Object {
  $iops = Get-FluxIOPS -Server $vc
  Write-FluxIOPS -InputObject $iops
  Start-Sleep -Seconds 20
}
