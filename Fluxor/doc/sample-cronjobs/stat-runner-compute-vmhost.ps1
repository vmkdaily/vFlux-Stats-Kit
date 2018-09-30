#!/snap/bin/pwsh
$vc = 'vcva01.lab.local'
1..25 | % { $stats = Get-FluxCompute -Server $vc -ReportType VMHost; Write-FluxCompute -InputObject $stats; sleep 20 }
