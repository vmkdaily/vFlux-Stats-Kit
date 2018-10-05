<#	
    ===========================================================================
    Author:       	Mike Nisk
    Filename:     	Fluxor.psm1
    Version:        1.0.0.4
    Generated on:   04Oct2018
    -------------------------------------------------------------------------
    Module Name:    Fluxor
    ===========================================================================

#>

# Get public and private function files
$Public = @( Get-ChildItem -Path $PSScriptRoot\public\*-*.ps1 -Recurse -ErrorAction SilentlyContinue )
$Private = @( Get-ChildItem -Path $PSScriptRoot\private\*-*.ps1 -Recurse -ErrorAction SilentlyContinue )

# Dot source the files
foreach ($FunctionFile in @($Public + $Private)) {

    try {

        . $FunctionFile.fullname

    }
    catch {
        Write-Error -Message "Failed to import function $($FunctionFile.fullname): $_"
    }
}

# Export the Public modules
Export-ModuleMember -Function $Public.Basename
