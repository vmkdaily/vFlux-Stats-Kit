#!/snap/bin/pwsh
$vc = 'vcva01.lab.local'
$summaryVMHost = Get-FluxSummary -Server $vc -ReportType VMHost -MaxJitter 73
Write-FluxSummary -InputObject $summaryVMHost