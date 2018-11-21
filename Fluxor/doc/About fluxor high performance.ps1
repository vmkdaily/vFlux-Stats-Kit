<#

## About Pipeline Support
We support it and it works.  However, for high performance we recommend saving to a PowerShell variable (i.e. $stats = Get-FluxCompute -Server 'myvcenter01').
And then write by populating the InputObject parameter of the write cmdlet (i.e. Write-FluxCompute -InputObject $stats).

## High performance options InfluxDB
- Configure WAL and DATA using SSD
- Ensure config file is pointing to your fast disks if you use SSD
- Sort writes by date (we do that already)
- sort tags alphabetically (we do that already)
- Use VMware paravirtual SCSI adapter
- Add data drives where appropriate. This delivers additional SCSI queues for better throughput to InfluxDB (or high performance writes to local disk for text files if needed).
- Use VMware vmxnet3 NIC

## Default cmdlet output
By default, the output for Fluxor is object based and returns an array of text lines crafted as
line protocol (the InfluxDB-specific technique for writing to their API). With the default there is no need to batch,
Simply send the data points on using the related Fluxor write command (i.e. Write-FluxCompute).

## Batching from text files
The recommendation is to use the default object output. However, users can populate the -OutputPath
parameter to tell Fluxor that they want text files at the specified location. Fluxor automatically names
each stat file collected and saved (only when using OutputPath).

If you decide to use text files, consider the following tips:

- Send a batch of 5000 to 10000 entries (not line numbers) in a single write.
- Because a single line can have 5 or 10 entries, you may hit 5 to 10k faster than you think.
- Test your results to determine the optimal size of your batches.
- In most cases, benefits will diminish at around 8000 to 16000 entries
- Maximum writes to a single stand-alone InfluxDB node peak at around 1 Million writes/sec
- Maximum writes to a InfluxDB raft cluster (paid) are around 11 Million writes/sec
- This is not the default. We never write a text file unless you ask for logging or stat output.

## Adding additional databases
To increase the efficiency of InfluxDB, give it more ways to slice the data.
We can do this by increasing the number of databases that are written to with InfluxDB.

For example, create a database called 'esxcompute' that does not compete with the default 'compute' which is used by VMs and VMHosts.
Optionally, create a database per cluster or something unique or important.

## General / Maintenance
- The InfluxDB database can be backed up from the influx cli.
- You can also shutdown and export your entire stats machine to OVA once in a while
- Be careful not to run out of space over time
- Learn how to expand disk if needed
- Undertand InfluxDB and Grafana releases
- Understand and test impact when you update the operating system
- When patching, don't disable your cron/scheduled tasks; You will forget to turn them back on. Just reboot and let things work themselves out.
- If you added the repo for InfluxDB and Grafana (recommended) then your packages will be updated over time with apt.

  For example, InfluxDB and/or Grafana will likely be updated when you run:

    apt -y update
    apt -y upgrade

  Both companies have a fairly regular cadence, so expect updates every 1 to 3 months at a minumum.
  This is generally good, and the updates are typically well accepted. However, be prepared in case they are not.
  This means having a good backup of your InfluxDB databases or the entire machine.

## Disk Space for InfluxDB
Don't run out.  Plan for growth of about 20% per year, like any other server.

## Going big
If needed, you can step up your availability and performance by scaling InfluxDB with raft clustering.
While the Influxdata products (including InfluxDB) are all open source, you can purchase enterprise
support where it makes sense.

## Additional Links
https://docs.influxdata.com/influxdb/v1.2/concepts/glossary
https://community.influxdata.com/t/what-is-the-highest-performance-method-of-getting-data-in-out-of-influxdb/464/6

## Old Performance Whitepaper (10 pages covering Influx v1.1 on AWS). The current version of InfluxDB is 1.6.3, but the paper is still valid.
https://www.influxdata.com/resources/assessing-write-performance-of-influxdb-clusters-using-amazon-web-services/?ao_campid=70137000000JgNp

## Benchmarking InfluxDB - Open repo illustrating the official methodology used by the Influxdata team: 
https://github.com/influxdata/influxdb-comparisons

#>
