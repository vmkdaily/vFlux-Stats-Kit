#!/snap/bin/pwsh
$vc = 'vcva01.lab.local'
$summaryVMHost = Get-FluxSummary -Server $vc -ReportType VMHost
Write-FluxSummary -InputObject $summaryVMHost