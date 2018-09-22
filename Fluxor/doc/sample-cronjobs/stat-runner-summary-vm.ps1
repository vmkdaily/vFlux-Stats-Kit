#!/snap/bin/pwsh
$vc = 'vcva01.lab.local'
$summaryVM = Get-FluxSummary -Server $vm
Write-FluxSummary -InputObject $summaryVM
