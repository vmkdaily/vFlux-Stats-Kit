
<#
    ######################
    How to use FluxorRS
    ######################
    
    Note: When running PowerShell as an approved user, all credentials should be handled automatically.
    To make yourself an approved user, save credentials to disk using the New-FluxCredential cmdlet.
    See the cmdlet help (help Invoke-FluxorRS -Full) for details on using other parameters such as Credential and CredentialPath.

    ## One VC
    Invoke-FluxorRS -Server vcva01.lab.local -InfluxDBServer 'myinfluxserver'

    ## Multiple VCs
    Invoke-FluxorRS -Server @('vcva01.lab.local','vcva02.lab.local') -InfluxDBServer 'myinfluxserver'

    ## All VCs
    $vcList = gc "path-to-vc-list.txt"
    Invoke-FluxorRS -Server $vcList -InfluxDBServer 'myinfluxserver'

    Note: Instead of populating runtime parameters for Server and InfluxDBServer, the script can also use hard-coded values.

#>
