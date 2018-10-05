#!/snap/bin/pwsh
$vc = 'vcva01.lab.local'
$summaryVM = Get-FluxSummary -Server $vc -ReportType VM -MaxJitter 73
Write-FluxSummary -InputObject $summaryVM
