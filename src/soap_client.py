#!/usr/bin/env python 
import SOAPpy
server = SOAPpy.SOAPProxy("https://JohnDoe:JDsPassword@dtc.xen650202.gplhost.com:8089/")
# server = SOAPpy.SOAPProxy("https://JohnDoe:JDsPassword@mirror.tusker.net:8089/")
print server.listStartedVPS()
