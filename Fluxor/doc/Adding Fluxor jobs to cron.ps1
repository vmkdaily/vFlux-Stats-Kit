<#

APPENDIX - Adding Fluxor jobs to cron (a.k.a. scheduled tasks)

## First
Get a basic understanding of cron jobs for Linux:

    https://help.ubuntu.com/community/CronHowto

## Review the users on the system

  sudo cut -d: -f1 /etc/passwd

Note: From the output, decide which user will run the cron jobs

## Add user if needed
https://help.ubuntu.com/lts/serverguide/user-management.html.en

## HOW TO
Login as desired user and perform the following:

Step 1. Install PowerShell if needed:

  snap install powershell --classic

Step 2. Launch PowerShell with pwsh:

  pwsh
  

Step 3. Create a PowerShell $PROFILE if needed

Step 4. Add a line to your $PROFILE to import the Fluxor module

  Import-Module $HOME/Fluxor


Step 5. Launch PowerShell (pwsh)
If you have not already, launch Powershell with pwsh.
You should be in the $HOME directory of the user by default.

Note: If this is not the user that will run the stats collections, get logged in!

Step 6. List the contents of your $HOME directory
As expected, we can run linux or PowerShell commands interchangably on Core Edition of PowerShell.
  
  ls -lh $HOME

Or we could:

  Get-ChildItem $HOME

or dir ~/

Note: $HOME is the analog to $env:USERPROFILE of Windows (though $HOME works on Windows too).

## Step 7 - Create your scripts
Alhough we have this fancy module, we still depend on you to create the scripts to run in cron.
The important bit is the she bang (#!) at the top that tells cron to use PowwerShell.

## Learn Where PowerShell is located
This is how we determine what to place after the she bang (#!) in our cron scripts.

  which pwsh

## Example cron script

  #!/snap/bin/pwsh
  1..25 | % { $stats = Get-FluxCompute -Server usilchvc801; Write-FluxCompute -InputObject $stats; sleep 20 }

## All Scripts
Here I have created a few scripts:

  PS /home/fluxor> ls -lh
total 28K
drwxr-xr-x 5 fluxor fluxor 4.0K Sep 29 18:31 Fluxor
drwxr-xr-x 3 fluxor fluxor 4.0K Sep 17 11:07 snap
-rwxrwxr-x 1 fluxor fluxor  144 Sep 29 18:24 stat-runner-compute-vmhost.ps1
-rwxrwxr-x 1 fluxor fluxor  125 Sep 18 11:59 stat-runner-compute-vm.ps1
-rwxrwxr-x 1 fluxor fluxor  117 Sep 18 11:59 stat-runner-iops.ps1
-rwxrwxr-x 1 fluxor fluxor  150 Sep 21 16:41 stat-runner-summary-vmhost.ps1
-rwxrwxr-x 1 fluxor fluxor  123 Sep 21 16:40 stat-runner-summary-vm.ps1
PS /home/fluxor>

Note: I don't really use Mike as the job runner. I create a user such as fluxor or fluxorsvc, etc.

Step 8. Create cron jobs

Login as the user that will run the jobs and:

      crontab -e

Or, to run as root

  sudo crontab -e

Note: The recommendation is not to run as root.

Step 9. Use the editor of your choice when prompted by crontab.
By default, you will use nano. This means just arrow down to the bottom and enter your text.
When ready, save changes in nano with <CTRL + x>, press <y> and hit <enter> on your keyboard.

The following cron example gathers performance and summary information every 10 minutes

      # m h  dom mon dow   command
      */10 * * * * ~/stat-runner-compute-vm.ps1
      */10 * * * * ~/stat-runner-compute-vmhost.ps1
      */10 * * * * ~/stat-runner-iops.ps1
      */10 * * * * ~/stat-runner-summary-vm.ps1
      */10 * * * * ~/stat-runner-summary-vmhost.ps1

Step 10. About preventing dip in stat collection
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