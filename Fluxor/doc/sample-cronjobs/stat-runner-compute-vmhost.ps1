#!/snap/bin/pwsh
$vc = 'vcva01.lab.local'
$stats = Get-FluxCompute -Server $vc -ReportType VMHost
Write-FluxCompute -InputObject $stats
