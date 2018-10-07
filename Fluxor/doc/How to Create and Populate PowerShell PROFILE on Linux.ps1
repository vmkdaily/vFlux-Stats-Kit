<#

###########################################################
## How to Create and Populate PowerShell PROFILE on Linux
###########################################################

## Check If PowerShell Profile Exists
First we will test if our PowerShell $PROFILE exists. If it does not, we will create one. The $PROFILE we create here is per user.

    Test-Path $PROFILE

> For the above (and all PowerShell), use your tab completion where possible. If you have sound, notice that you get a ding on failures to tab complete. This can get annoying and we will add the fix for that to our $PROFILE soon.

## Create PowerShell Profile
If Test-Path $PROFILE returned $false above, then we create one now.

    New-Item -Type File -Path $PROFILE -Force

## Populate PowerShell Profile
Let's add our first entry to the profile. This will stop the console bell.

    Add-Content -Path $PROFILE -Value "Import-Module $HOME/Fluxor"

## Show $PROFILE contents with cat or gc
At a minimum, your $PROFILE should have one line to import the Fluxor module, or place the module in a directory where modules load automatically.
My profile has a single line as we can see from the output.

  #view profile contents
  PS /home/mike> Get-Content $PROFILE
  Import-Module /home/mike/Fluxor

## Reload PowerShell
To reload PowerShell, you can type exit and then relaunch PowerShell, or simply reload profile with:

    & $PROFILE

## List modules with Get-Module
Perform a Get-Module and you should now see Fluxor:

  PS /home/mike> Get-Module

  ModuleType Version    Name
  ---------- -------    ----
  Script     1.0.0.5    Fluxor

## List Fluxor cmdlets

  PS /home/mike> gcm -Module Fluxor

CommandType     Name                                               Version    Source
-----------     ----                                               -------    ------
Function        Get-FluxCompute                                    1.0.0.5    Fluxor
Function        Get-FluxCrontab                                    1.0.0.5    Fluxor
Function        Get-FluxIOPS                                       1.0.0.5    Fluxor
Function        Get-FluxSummary                                    1.0.0.5    Fluxor
Function        Invoke-FluxCLI                                     1.0.0.5    Fluxor
Function        New-FluxCredential                                 1.0.0.5    Fluxor
Function        Write-FluxCompute                                  1.0.0.5    Fluxor
Function        Write-FluxIOPS                                     1.0.0.5    Fluxor
Function        Write-FluxSummary                                  1.0.0.5    Fluxor

## Private Functions
There are currently two 'private' functions that we do not pubish (only to keep it simple).
Feel free to import these manually or add them to be loaded by the psd1 along with the others.
These are consumed behind the scenes automatically by the Fluxor module as needed.

Get-FluxCredential.ps1
Set-SessionAllowInvalidCerts.ps1.

#>