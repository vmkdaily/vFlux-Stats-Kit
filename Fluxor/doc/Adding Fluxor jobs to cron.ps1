<#

#### APPENDIX - Adding Fluxor jobs to cron (a.k.a. scheduled tasks)

## Introduction to cron
Get a basic understanding of cron jobs for Linux:

    https://help.ubuntu.com/community/CronHowto

## Review the users on the system

  sudo cut -d: -f1 /etc/passwd

Note: From the output, decide which user will run the cron jobs

## Add user if needed
https://help.ubuntu.com/lts/serverguide/user-management.html.en


## GETTING STARTED
Login as desired user and perform the following:

Step 1. Install PowerShell if needed:

  snap install powershell --classic

Step 2. Launch PowerShell with pwsh:

  pwsh

Step 3. Create a PowerShell $PROFILE if needed

  ## Test if exists
  Test-Path $PROFILE

  ## If the result above is $false, then:

  New-Item -Type File -Path $PROFILE -Force

Step 4. Add a line to your $PROFILE to import the Fluxor module
Use nano $PROFILE to edit your profile and then add the following:

  Import-Module $HOME/Fluxor

Step 5. Launch PowerShell (pwsh)
Launch (or re-launch) Powershell with pwsh. Now the Fluxor module should have loaded autoamtically.
You should be in the $HOME directory of the user by default.

Note: If this is not the user that will run the stats collections, get logged in!

Step 6. List the contents of your $HOME directory
As expected, we can run linux or PowerShell commands interchangably on Core Edition of PowerShell.
  
  ls -lh $HOME

Or we could:

  Get-ChildItem $HOME

or dir ~/

Note: $HOME is the analog to $env:USERPROFILE of Windows (though $HOME works on Windows too).

## Step 7 - Copy or Create your scripts
Alhough we have this fancy module, we still depend on you to create the scripts to run in cron.
The important bit is the she bang (#!) at the top that tells cron to use PowerShell.

Copy the examples from the module folder, use the touch command (or similar) to create a file on your system.
If you copy the example files, you only need to edit the vCenter and iterations to run.

To create a file manually:

  touch stat-runner-compute-vm.ps1
  touch stat-runner-compute-vmhost.ps1
  etc.
  etc.

## Step 8 - Learn Where PowerShell is located
This is how we determine what to place after the she bang (#!) in our cron scripts.

  which pwsh

## Contents of Example cron script
Since I run the PowerShell snap, my path is /snap/bin/pwsh.
You will see that at the top of the script. Remember to use which to find your path first.

  #!/snap/bin/pwsh
  $vc = 'vcva01.lab.local'
  1..25 | % { $stats = Get-FluxCompute -Server $vc; Write-FluxCompute -InputObject $stats; sleep 20 }

Note 1: This runs 25 times and sleeps for 20 seconds between runs.
Good for initial testing and watching for stats to populate.

Note2: Also see the MaxJitter parameter instead of using sleep statements.

## Step 9. - Setting Permissions for cron scripts (your .ps1 files you create)
To make a cron script executable:

  chmod +x stat-runner-compute-vm.ps1

## Step 10 - Do not skip step 9 (setting permissions)!
You will notice right away that cron jobs will not run if the permissions are missing.
symptoms would be Get and Write functions work manually, but watching the dashboards
(or Get-FluxCrontab) nothing shows up.

## Step 11 - List your scripts
I have created a few scripts for my use (your names may vary). Below is the output of ls.
If you will use the Get-FluxCrontab function, use names that start with 'stat-runner'.
See help Get-FluxCronTab for more detail.

  PS /home/mike> ls -lh
  total 28K
  drwxr-xr-x 5 mike mike 4.0K Sep 29 18:31 Fluxor
  drwxr-xr-x 3 mike mike 4.0K Sep 17 11:07 snap
  -rwxrwxr-x 1 mike mike  144 Sep 29 18:24 stat-runner-compute-vmhost.ps1
  -rwxrwxr-x 1 mike mike  125 Sep 18 11:59 stat-runner-compute-vm.ps1
  -rwxrwxr-x 1 mike mike  117 Sep 18 11:59 stat-runner-iops.ps1
  -rwxrwxr-x 1 mike mike  150 Sep 21 16:41 stat-runner-summary-vmhost.ps1
  -rwxrwxr-x 1 mike mike  123 Sep 21 16:40 stat-runner-summary-vm.ps1
  PS /home/mike>

Tip: Create a user such as fluxorsvc, statty-mcfatty, or similar. However, since the module is named Fluxor do not name the user exactly as fluxor (humans may delete the profile accidentally when trying to delete/replace the module).

Step 12. Create the cron jobs

Login as the user that will run the jobs and:

  crontab -e

Or, to run as root

  sudo crontab -e

Note: The recommendation is not to run as root.

Step 13. Use the editor of your choice when prompted by crontab. By default, you will use nano.
Once in the editor, skip past all of the comments at the top and arrow down to the bottom line.
Finally, enter your desired text. To save changes in nano, press <CTRL + x>, then <y>, and then
press <enter>.

The following cron example gathers performance and summary information every 10 minutes

      # m h  dom mon dow   command
      */10 * * * * ~/stat-runner-compute-vm.ps1
      */10 * * * * ~/stat-runner-compute-vmhost.ps1
      */10 * * * * ~/stat-runner-iops.ps1
      */10 * * * * ~/stat-runner-summary-vm.ps1
      */10 * * * * ~/stat-runner-summary-vmhost.ps1

## Step 14. Prevent dips in stat collection
You need to determine the timing of your systems and how long the jobs take to run.
Use Grafana to review the stats for last hour or 30 minutes to observe the dips.
Also consider running "Get-FluxCrontab -Count 20" or similar to watch your jobs.

Consider that some missing stats may be okay; When looking at the data for past
week, month, etc. over time, you will not notice. However, if you need more precise
views (i.e. down to 5 or 1 minute accuracy) then you may consider tweaking.

If you follow the examples we use a simple technique of passing an array (i.e. 1..15)
of numbers into a foreach loop to kick off 15 stat runs (with a sleep at the end).
What you may notice is stats just dipping down in the chart, say from the 8 minute mark
to the 10 minute mark. This means you need to add a couple more (i.e. 1..20) or instead
run more jobs. 

## Step 15 - Prevent overrun
Use the Get-FluxCrontab function to check for running jobs (i.e at the 8 minute mark) before your next set of runs comes up.
If you notice two of the same script running, taper back the 1..n or just do one at a time.

## APPENDIX - CRON OPTIONS TABLE
Instead of /10 for the minutes field, you could use some other value:

  String | Frequency

  @reboot | Run once, at startup

  @yearly | Run once a year

  @annually | (same as @yearly)

  @monthly | Run once a month

  @weekly | Run once a week

  @daily | Run once a day

  @midnight | (same as @daily)

  @hourly | Run once an hour


#>