#!/usr/bin/python
import sys
import os
import glob
import time

if len(sys.argv)<2:
    print "Syntax: %s <rrdbasename> [optional destination directory]"%sys.argv[0]
    sys.exit(1)

colors=["000000", "FF0000", "00FF00", "0000FF" ]
colors+=["DEDE00", "00FFFF", "FF90FF", "FF8040", "C040A0", "A0A0A0", "40A0A0", "40A0FF", "FFA040" ]

def graph(basename, subname, seconds):
    rrds=glob.glob(basename+"/cpu*.rrd")
    rrds=[x for x in rrds if os.stat(x)[8] > (time.time()-seconds)]

    # cmdline="--imgformat PNG --unit % --vertical-label CPU%  "
    cmdline="--imgformat PNG --vertical-label CPU%  "
    #cmdline="--imgformat PNG --unit % --vertical-label CPU% --rigid --lower-limit 0 --upper-limit 100 "

    for rrd,id in zip(rrds,range(len(rrds))):
	cmdline+="DEF:id%draw=%s:cpu:LAST "%(id,rrd)
	cmdline+="CDEF:id%dpercent=id%draw,10,/ "%(id,id)
	cmdline+="CDEF:id%dzero=id%dpercent,DUP,UN,EXC,0,EXC,IF "%(id,id)
    for rrd,id in zip(rrds,range(len(rrds))):
	cmdline+="%s:id%dzero#%s:%s "%({0:"AREA"}.get(id,"STACK"),id,colors[id%len(colors)],rrd[len(basename):-4])
	cmdline+="GPRINT:id%dpercent:AVERAGE:\"%s\" "%(id,"Average CPU usage\: %02.0lf%%\\j")

    # print cmdline
    os.system("nice -n+20 rrdtool graph %sxen-cpu-%s.png --start -%d --end -69 %s"%(folder,subname,seconds,cmdline))

basename=sys.argv[1]
folder=basename
if len(sys.argv)==3:
        folder=sys.argv[2]
graph(basename, "hourly", 4000)
graph(basename, "daily", 100000)
graph(basename, "weekly", 800000)
graph(basename, "monthly", 3200000)
graph(basename, "yearly", 40000000)

