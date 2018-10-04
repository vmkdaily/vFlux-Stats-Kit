#!/snap/bin/pwsh
$vc = 'vcva01.lab.local'
1..7 | ForEach-Object {
  $stats = Get-FluxCompute -Server $vc -ReportType VM
  Write-FluxCompute -InputObject $stats
  Start-Sleep -Seconds 20
}
