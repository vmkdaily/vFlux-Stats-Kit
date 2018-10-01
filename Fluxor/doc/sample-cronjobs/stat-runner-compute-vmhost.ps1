#!/snap/bin/pwsh
$vc = 'vcva01.lab.local'
1..7 | Foreach-Object {
	$stats = Get-FluxCompute -Server $vc -ReportType VMHost
	Write-FluxCompute -InputObject $stats
}
