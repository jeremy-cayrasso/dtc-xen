#!/usr/bin/python
import sys
import os
import re
import time
from subprocess import Popen,call,PIPE
from glob import glob

def check_call(*args):
	retval = call(*args)
	if retval != 0: raise Exception, "call() failed with error %s: %s"%(retval,args)
	return retval

tabsplitter = re.compile("[\t ]+").split

if len(sys.argv) < 2:
    print "Syntax: %s <rrdbasename> [--test]"%sys.argv[0]
    sys.exit(os.EX_USAGE)

now = "%d"%time.time()
basename = sys.argv[1]
domains = (
		tabsplitter(d.strip())
		for d in Popen(["/usr/sbin/xm","list"], stdout=PIPE).communicate()[0].splitlines()[1:]
		if d.strip()
	)
for domain in domains:

    name,id,mem,cpu,state,cputime=domain[0:6]
    # Log the CPU of each domain
    cputime=long(float(cputime)*1000)
    rrd=os.path.join(basename,"cpu-"+name+".rrd")
    if not os.path.exists(rrd):
	# 10 days of exact archive, 42 days of 1 hr RRD, 1000 days of 1 day RRD
	check_call( [
		"rrdtool",
		"create",
		rrd,
		"--step","60",
		"DS:cpu:COUNTER:666:0:10000",
		"RRA:LAST:0.5:1:15000",
		"RRA:MIN:0.5:60:1000","RRA:MIN:0.5:1440:1000",
		"RRA:MAX:0.5:60:1000","RRA:MAX:0.5:1440:1000",
		"RRA:AVERAGE:0.5:60:1000","RRA:AVERAGE:0.5:1440:1000",
	] )
    check_call( [ "nice","-n+20","rrdtool","update",rrd,"%s:%s"%(now,cputime) ] )

    # if we're dealing with the dom0, neeeext...
    if name == "Domain-0": continue
     
    # Log the network usage of each domU domain
    inbytes,a,a,a,a,a,a,a,outbytes,a,a,a,a,a,a,a=tabsplitter(
	[
		re.sub(".*:","",o).strip()
		for o in file("/proc/net/dev").readlines()
		if o.startswith("vif%s.0:"%id)
	] [0]
    )
    inplusout = long(inbytes) + long(outbytes)
    rrd = os.path.join(basename,"net-"+name+".rrd")
    if not os.path.exists(rrd):
	# 10 days of exact archive, 42 days of 1 hr RRD, 1000 days of 1 day RRD
	check_call( [
		"rrdtool",
		"create",
		rrd,
		"--step","60",
		"DS:bytes:COUNTER:600:0:12500000",
		"RRA:LAST:0.5:1:15000",
		"RRA:MIN:0.5:60:1000","RRA:MIN:0.5:1440:1000",
		"RRA:MAX:0.5:60:1000","RRA:MAX:0.5:1440:1000",
		"RRA:AVERAGE:0.5:60:1000","RRA:AVERAGE:0.5:1440:1000",
	] )
    check_call( [ "nice","-n+20","rrdtool","update",rrd,"%s:%s"%(now,inplusout) ] )

    # Log the block i/o usage of each domU domain
    # FIXME: doesn't differentiate between swap and file i/o, or writes and reads
    # FIXME: # ls /sys/devices/xen-backend/vbd-6-51712/statistics/
    #br_req  oo_req  rd_req  rd_sect  wr_req  wr_sect
    #rd_sect / wr_sect contain sectors, so if we can assume 512 bytes/sector then we could fill in the bytes fields.
    # http://www.redhat.com/archives/libvir-list/2007-August/msg00224.html
    def fixwraparound(negint):
	if negint < 0: return negint + pow(2,32)
	return negint
    iosectors = sum(
    	( fixwraparound(long(file(f).read())) for f in glob(
			os.path.join("/","sys","devices","xen-backend","vbd-%s-*"%id,"statistics","*_sect")
		)
	)
    )
    rrd=os.path.join(basename,"io-"+name+".rrd")
    if not os.path.exists(rrd):
	# 10 days of exact archive, 42 days of 1 hr RRD, 1000 days of 1 day RRD
	check_call( [
		"rrdtool",
		"create",
		rrd,
		"--step","60",
		"DS:bytes:COUNTER:600:0:12500000",
		"RRA:LAST:0.5:1:15000",
		"RRA:MIN:0.5:60:1000","RRA:MIN:0.5:1440:1000",
		"RRA:MAX:0.5:60:1000","RRA:MAX:0.5:1440:1000",
		"RRA:AVERAGE:0.5:60:1000","RRA:AVERAGE:0.5:1440:1000",
	] )
    check_call( [ "nice","-n+20","rrdtool","update",rrd,"%s:%s"%(now,iosectors) ] )
