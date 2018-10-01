
<#

## How to install TICK stack on Ubuntu 16.04 (this is old, and good until the part about using beta for Chronograf, which is now GA):
https://www.digitalocean.com/community/tutorials/how-to-monitor-system-metrics-with-the-tick-stack-on-ubuntu-16-04

## To update an existing deploy
If already have the components from vFlux Stats Kit, you will have this already:

  sudo cat /etc/apt/sources.list.d/influxdb.list

## You should see something like

  deb https://repos.influxdata.com/ubuntu xenial stable

  Note: If you do not see something similar to the above, follow the Influxdata documentation or the link first provided at start of article.

## Before getting started, check for updates

  sudo apt -y update
  sudo apt -y upgrade

## Install telegraf
Since we have the repo already, we can just install:

  sudo apt install telegraf

## Configure telegraf

  sudo vi /etc/telegraf/telegraf.conf


## Searching in vi
The file is over 4,000 lines long, but the plugin we need is at the end of the file.
While in vi, use the forward slash to search for vsphere


    /vsphere

## Edit with vi
Customize the lines as needed to reflect the VC, user and pw.

## IMPORTANT
You are not done yet. You must uncomment all lines related to stats by removing the # before each line.

## Save changes and exit vi
Type :wq! to save the changes and exit vi.

  :wq!

## Restart telegraf

  systemctl start telegraf


## Summary
These steps got you up and running with telegraf, which is a great addition to your InfluxDB environment. See the official influxdata documentation to learn more about the TICK stack!

#>