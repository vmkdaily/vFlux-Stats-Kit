#!/snap/bin/pwsh
$vc = 'vcva01.lab.local'
1..25 | ForEach-Object {
  $stats = Get-FluxCompute -Server $vc
  Write-FluxCompute -InputObject $stats
  Start-Sleep 20
}
