#!/snap/bin/pwsh
$vc = 'vcva01.lab.local'
$summaryVM = Get-FluxSummary -Server $vc -ReportType VM
Write-FluxSummary -InputObject $summaryVM
