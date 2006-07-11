#!/usr/bin/python
import sys
import os
import re
import time

if len(sys.argv)!=2:
    print "Syntax: %s <rrdbasename>"%sys.argv[0]
    sys.exit(1)

now=str(int(time.time()))
basename=sys.argv[1]
data=os.popen2("/usr/sbin/xm list")[1].read()
domains=data.split("\n")[1:-1]
for domain in domains:
    name,id,mem,cpu,state,cputime,console=re.split("[\t ]+",domain)

    # Log the CPU of each domain
    cputime=int(float(cputime)*1000)
    cpurrd=basename+"/cpu-"+name+".rrd"
    if not os.access(cpurrd,os.F_OK):
      # 10 days of exact archive, 42 days of 1 hr RRD, 1000 days of 1 day RRD
      os.system("rrdtool create "+cpurrd+" --step 60 DS:cpu:COUNTER:666:0:10000"+
        " RRA:LAST:0.5:1:15000"+
        " RRA:MIN:0.5:60:1000 RRA:MIN:0.5:1440:1000"+
        " RRA:MAX:0.5:60:1000 RRA:MAX:0.5:1440:1000"+
        " RRA:AVERAGE:0.5:60:1000 RRA:AVERAGE:0.5:1440:1000")
    os.system("nice -n+20 rrdtool update %s %s:%s"%(cpurrd,now,cputime))

    # Log the network usage of each domain
    if name=="Domain-0":
      continue
#      devinfo=os.popen2("cat /proc/net/dev | grep 'eth0'")[1].read()
    else:
      devinfo=os.popen2("cat /proc/net/dev | grep 'vif"+id+"\.0'")[1].read()
    rows=re.split("\n", devinfo)
    inplusout=0
    for row in rows:
        columns=re.split("[\t ]+",row)
        if (len(columns)==16):
	        one,a,a,a,a,a,a,a,eight,a,a,a,a,a,a,a=columns
	        one=re.split(":",one)[1]
        elif (len(columns)==17):
            a,one,a,a,a,a,a,a,a,eight,a,a,a,a,a,a,a=columns
        elif (len(columns)==1):
            # this is an empty row, continue
            continue
	else:
            # this is an unknown row, continue
	    print str(columns) + str(len(columns))
            continue
        # print name +' '+ id +' '+ one +' '+ eight
        inplusout=inplusout + int(one) + int(eight)
        # print name +' '+ ifname +' '+ str(inplusout)
        netrrd=basename+"/net-"+name+".rrd"
        if not os.access(netrrd,os.F_OK):
           # 10 days of exact archive, 42 days of 1 hr RRD, 1000 days of 1 day RRD
           os.system("rrdtool create "+netrrd+" --step 60 DS:bytes:COUNTER:600:0:12500000"+
                     " RRA:LAST:0.5:1:15000"+
                     " RRA:MIN:0.5:60:1000 RRA:MIN:0.5:1440:1000"+
                     " RRA:MAX:0.5:60:1000 RRA:MAX:0.5:1440:1000"+
                     " RRA:AVERAGE:0.5:60:1000 RRA:AVERAGE:0.5:1440:1000")
        os.system("nice -n+20 rrdtool update %s %s:%s"%(netrrd,now,inplusout))