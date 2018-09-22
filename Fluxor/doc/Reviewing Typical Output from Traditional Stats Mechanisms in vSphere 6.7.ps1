<#

    ## APPENDIX
    This document is unrelated to any custom modules created or used for performance gathering.
    Here we use the raw vSphere cmdlets or API where designated. It may be helpful to see the
    native cmdlets at work. This is performed using vSphere 6.7.
    
     
    ###############
    ## VSAN STATS
    ###############
    1. Expected output from vSAN, example when using only Get-VSanStat.

        Entity                    Name                      Time                           Value
        ------                    ----                      ----                           -----
        infosec001                Performance.ReadIops      8/28/2018 6:05:00 PM               4


    2. List available vSAN counters for a virtual machine

        PS C:\> $vm = Get-VM jump01
        PS C:\> $stats = Get-VsanStat -Entity $vm
        PS C:\> $stats.count
        1728
        
        PS C:\> $stats | Select-Object Name -Unique

        Name
        ----
        Performance.WriteIops
        Performance.WriteThroughput
        Performance.WriteLatency
        Performance.ReadIops
        Performance.ReadThroughput
        Performance.ReadLatency

        In the above, we used the default time range (did not specify start), and returned all default vSAN stat results for this virtual machine.
        Currently in vSphere 6.7 this will quietly try to return you the past 24 hours. To specify something more like RealTime, use StartTime parameter.

    3. Show only non-zero values:
       Observe the total count of stat objects returned (i.e. each one has a timestamp, metricname and value).
       Many are purely a value of zero, and you can choose to ignore those if desired.
       When using a timeseries database such as InfluxDB, you can choose how you want null or non-existant values to be represented.
       As such, you can save a lot of writes since (at least for this example virtual machine) a large percentage may be zero.
       Out of 1728 total, only 608 are non-zero (or contain useful info).

        PS C:\> $stats | ?{$_.Value -ne 0} | Measure-Object

        Count    : 608
        Average  :
        Sum      :
        Maximum  :
        Minimum  :
        Property :


    ###################
    ## GET-STAT STATS
    ###################

    3. Expected output from Get-Stat:

    Get-Stat -Entity (Get-VM 'MyVM') -Realtime -MaxSamples 1

    Tip: you can also use the PassThru switch of the Fluxor cmdlets to get the vSphere API result object like we get above.
    This is compared the the module default for Fluxor which presents everything in InfluxDB line protocol.
#>